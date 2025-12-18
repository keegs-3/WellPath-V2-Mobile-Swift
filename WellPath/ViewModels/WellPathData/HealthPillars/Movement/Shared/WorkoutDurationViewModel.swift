//
//  WorkoutDurationViewModel.swift
//  WellPath
//
//  ViewModel for workout duration screens
//  Uses universal pre-aggregated views (patient_quantity_daily/weekly/monthly_summary)
//  Loads ALL data upfront - no pagination needed for small datasets
//

import Foundation
import SwiftUI

/// Chart data point for workout duration
struct WorkoutChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let durationMinutes: Double
    let workoutCount: Int
}

/// Period options for workout charts
enum WorkoutPeriod: String, CaseIterable, Identifiable {
    case day = "D"
    case week = "W"
    case month = "M"
    case sixMonths = "6M"
    case year = "Y"

    var id: String { rawValue }

    var summaryLabel: String {
        switch self {
        case .day: return "TODAY"
        case .week: return "THIS WEEK"
        case .month: return "THIS MONTH"
        case .sixMonths: return "6 MONTHS"
        case .year: return "THIS YEAR"
        }
    }

    var chartUnit: Calendar.Component {
        switch self {
        case .day: return .hour
        case .week, .month: return .day
        case .sixMonths: return .weekOfYear
        case .year: return .month
        }
    }

    var chartComponent: Calendar.Component {
        switch self {
        case .day: return .hour
        case .week, .month: return .day
        case .sixMonths: return .weekOfYear
        case .year: return .month
        }
    }

    var strideCount: Int {
        switch self {
        case .day: return 4
        case .week: return 1
        case .month: return 7
        case .sixMonths: return 4
        case .year: return 2
        }
    }

    var dateFormat: Date.FormatStyle {
        switch self {
        case .day:
            return .dateTime.hour()
        case .week, .month:
            return .dateTime.weekday(.abbreviated)
        case .sixMonths:
            return .dateTime.month(.abbreviated).day()
        case .year:
            return .dateTime.month(.abbreviated)
        }
    }

    /// Visible domain in seconds for scrollable chart
    var visibleDomainSeconds: Int {
        switch self {
        case .day: return 24 * 3600           // 24 hours
        case .week: return 7 * 24 * 3600      // 7 days
        case .month: return 30 * 24 * 3600    // ~30 days
        case .sixMonths: return 26 * 7 * 24 * 3600  // ~26 weeks
        case .year: return 365 * 24 * 3600    // ~365 days
        }
    }

    /// Config for generating placeholder data points (count, component)
    var placeholderConfig: (Int, Calendar.Component) {
        switch self {
        case .day: return (24, .hour)
        case .week: return (7, .day)
        case .month: return (30, .day)
        case .sixMonths: return (26, .weekOfYear)
        case .year: return (12, .month)
        }
    }

    /// Number of bars visible in the chart
    var numberOfBars: Int {
        switch self {
        case .day: return 24
        case .week: return 7
        case .month: return 30
        case .sixMonths: return 26
        case .year: return 12
        }
    }
}

/// Workout event for day timeline view
struct DayWorkoutEvent: Identifiable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    let durationMinutes: Double
}

@MainActor
class WorkoutDurationViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Daily aggregated data (for W/M views)
    @Published var dailyData: [WorkoutChartPoint] = []
    /// Weekly aggregated data (for 6M view)
    @Published var weeklyData: [WorkoutChartPoint] = []
    /// Monthly aggregated data (for Y view)
    @Published var monthlyData: [WorkoutChartPoint] = []
    /// Raw workout events (for D view timeline)
    @Published var dayWorkouts: [DayWorkoutEvent] = []

    /// Current chart data based on period
    @Published var chartData: [WorkoutChartPoint] = []

    /// Oldest date with data - for placeholder generation
    @Published var oldestLoadedDate: Date = Date()

    @Published var totalDuration: Double = 0
    @Published var workoutCount: Int = 0
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Cached Day Counts (computed once, used for daily average calculations)

    /// Pre-computed day counts per week (keyed by week_start date matching DB format)
    /// Used for 6M view daily average calculations
    private(set) var daysPerWeek: [Date: Int] = [:]

    /// Pre-computed day counts per month (keyed by month_start date matching DB format)
    /// Used for Y view daily average calculations
    private(set) var daysPerMonth: [Date: Int] = [:]

    /// The quantity type to query (cardio, strength_training, hiit, mobility)
    private let quantityType: String
    private let supabase = SupabaseManager.shared.client
    private var currentPeriod: WorkoutPeriod = .week
    private var hasLoadedAllData = false

    /// Initialize with quantity type
    /// - Parameter quantityType: One of: cardio, strength_training, hiit, mobility
    init(quantityType: String) {
        self.quantityType = quantityType
    }

    /// Convenience init for backwards compatibility with category names
    convenience init(category: String) {
        // Map old category names to new quantity types
        let quantityType: String
        switch category {
        case "cardio": quantityType = "cardio"
        case "strength": quantityType = "strength_training"
        case "hiit": quantityType = "hiit"
        case "mobility", "yoga", "flexibility": quantityType = "mobility"
        default: quantityType = "cardio"
        }
        self.init(quantityType: quantityType)
    }

    var formattedTotalDuration: String {
        if totalDuration < 60 {
            return "\(Int(totalDuration))m"
        } else {
            let hours = Int(totalDuration) / 60
            let minutes = Int(totalDuration) % 60
            if minutes == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(minutes)m"
        }
    }

    // MARK: - Data Loading

    /// Load all workout data upfront using pre-aggregated views
    /// This is efficient because views are pre-computed on the database
    func loadData(period: WorkoutPeriod) async {
        currentPeriod = period

        // Only load all data once, then just switch which dataset to display
        if !hasLoadedAllData {
            isLoading = true
            error = nil
            await loadAllData()
            hasLoadedAllData = true
            isLoading = false
        }

        // Set chartData based on current period
        updateChartDataForPeriod(period)
    }

    /// Load all aggregation levels at once
    private func loadAllData() async {
        do {
            guard let patientId = try? await supabase.auth.session.user.id else {
                return
            }

            // Load all three aggregation levels in parallel
            async let dailyTask = loadDailyData(patientId: patientId)
            async let weeklyTask = loadWeeklyData(patientId: patientId)
            async let monthlyTask = loadMonthlyData(patientId: patientId)
            async let rawTask = loadRawEvents(patientId: patientId)

            let (daily, weekly, monthly, raw) = await (dailyTask, weeklyTask, monthlyTask, rawTask)

            dailyData = daily
            weeklyData = weekly
            monthlyData = monthly
            dayWorkouts = raw

            // Set oldest date from daily data (most granular)
            if let oldest = daily.map({ $0.date }).min() {
                oldestLoadedDate = oldest
            } else {
                // Default to 10 years back if no data
                oldestLoadedDate = Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date()
            }

            // Calculate totals from daily data
            workoutCount = daily.reduce(0) { $0 + $1.workoutCount }
            totalDuration = daily.reduce(0) { $0 + $1.durationMinutes }

            // Pre-compute day counts for daily average calculations (done ONCE here)
            computeDayCountCaches()

            print("📊 WorkoutDurationViewModel: Loaded \(daily.count) daily, \(weekly.count) weekly, \(monthly.count) monthly, \(raw.count) raw events")

        } catch {
            self.error = error.localizedDescription
            print("❌ WorkoutDurationViewModel error: \(error)")
        }
    }

    /// Load daily aggregated data from universal view
    private func loadDailyData(patientId: UUID) async -> [WorkoutChartPoint] {
        struct DailyRow: Codable {
            let sampleDate: String
            let sampleCount: Int
            let totalValue: Double?

            enum CodingKeys: String, CodingKey {
                case sampleDate = "sample_date"
                case sampleCount = "sample_count"
                case totalValue = "total_value"
            }
        }

        do {
            let rows: [DailyRow] = try await supabase
                .from("patient_quantity_daily_summary")
                .select("sample_date, sample_count, total_value")
                .eq("patient_id", value: patientId.uuidString)
                .eq("quantity_type", value: quantityType)
                .order("sample_date", ascending: true)
                .execute()
                .value

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            return rows.compactMap { row -> WorkoutChartPoint? in
                guard let date = dateFormatter.date(from: row.sampleDate) else { return nil }
                return WorkoutChartPoint(
                    date: date,
                    durationMinutes: row.totalValue ?? 0,
                    workoutCount: row.sampleCount
                )
            }
        } catch {
            print("❌ Error loading daily data: \(error)")
            return []
        }
    }

    /// Load weekly aggregated data from universal view
    private func loadWeeklyData(patientId: UUID) async -> [WorkoutChartPoint] {
        struct WeeklyRow: Codable {
            let weekStart: String
            let sampleCount: Int
            let totalValue: Double?

            enum CodingKeys: String, CodingKey {
                case weekStart = "week_start"
                case sampleCount = "sample_count"
                case totalValue = "total_value"
            }
        }

        do {
            let rows: [WeeklyRow] = try await supabase
                .from("patient_quantity_weekly_summary")
                .select("week_start, sample_count, total_value")
                .eq("patient_id", value: patientId.uuidString)
                .eq("quantity_type", value: quantityType)
                .order("week_start", ascending: true)
                .execute()
                .value

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            return rows.compactMap { row -> WorkoutChartPoint? in
                guard let date = dateFormatter.date(from: row.weekStart) else { return nil }
                return WorkoutChartPoint(
                    date: date,
                    durationMinutes: row.totalValue ?? 0,
                    workoutCount: row.sampleCount
                )
            }
        } catch {
            print("❌ Error loading weekly data: \(error)")
            return []
        }
    }

    /// Load monthly aggregated data from universal view
    private func loadMonthlyData(patientId: UUID) async -> [WorkoutChartPoint] {
        struct MonthlyRow: Codable {
            let monthStart: String
            let sampleCount: Int
            let totalValue: Double?

            enum CodingKeys: String, CodingKey {
                case monthStart = "month_start"
                case sampleCount = "sample_count"
                case totalValue = "total_value"
            }
        }

        do {
            let rows: [MonthlyRow] = try await supabase
                .from("patient_quantity_monthly_summary")
                .select("month_start, sample_count, total_value")
                .eq("patient_id", value: patientId.uuidString)
                .eq("quantity_type", value: quantityType)
                .order("month_start", ascending: true)
                .execute()
                .value

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            return rows.compactMap { row -> WorkoutChartPoint? in
                guard let date = dateFormatter.date(from: row.monthStart) else { return nil }
                return WorkoutChartPoint(
                    date: date,
                    durationMinutes: row.totalValue ?? 0,
                    workoutCount: row.sampleCount
                )
            }
        } catch {
            print("❌ Error loading monthly data: \(error)")
            return []
        }
    }

    /// Load raw workout samples for day timeline view
    private func loadRawEvents(patientId: UUID) async -> [DayWorkoutEvent] {
        struct RawRow: Codable {
            let startTime: Date
            let endTime: Date
            let quantityValue: Double?

            enum CodingKeys: String, CodingKey {
                case startTime = "start_time"
                case endTime = "end_time"
                case quantityValue = "quantity_value"
            }
        }

        do {
            let rows: [RawRow] = try await supabase
                .from("patient_quantity_samples")
                .select("start_time, end_time, quantity_value")
                .eq("patient_id", value: patientId.uuidString)
                .eq("quantity_type", value: quantityType)
                .order("start_time", ascending: true)
                .execute()
                .value

            return rows.map { row in
                DayWorkoutEvent(
                    startTime: row.startTime,
                    endTime: row.endTime,
                    durationMinutes: row.quantityValue ?? 0
                )
            }
        } catch {
            print("❌ Error loading raw events: \(error)")
            return []
        }
    }

    /// Update chartData to point to the right dataset for current period
    private func updateChartDataForPeriod(_ period: WorkoutPeriod) {
        switch period {
        case .day:
            // For day view, we use raw events directly in the timeline
            // But still need chartData for any bar displays
            chartData = dailyData
        case .week, .month:
            chartData = dailyData
        case .sixMonths:
            chartData = weeklyData
        case .year:
            chartData = monthlyData
        }
    }

    // MARK: - Deprecated methods (no longer needed with pre-aggregated data)

    /// No longer needed - data is loaded upfront
    func loadOlderData() {
        // No-op: All data is loaded upfront now
    }

    /// No longer needed - data is loaded upfront
    func loadNewerData() {
        // No-op: All data is loaded upfront now
    }

    // MARK: - Day Count Cache Computation

    /// Compute day count caches for daily average calculations
    /// Called ONCE after data loads - matches database week_start/month_start dates
    private func computeDayCountCaches() {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Build daysPerWeek: count days with data for each week
        // Key must match week_start dates from patient_quantity_weekly_summary
        var weekCounts: [Date: Int] = [:]
        for day in dailyData where day.durationMinutes > 0 {
            // Calculate week start using ISO 8601 (Monday start) to match Postgres date_trunc('week', ...)
            var isoCalendar = Calendar(identifier: .iso8601)
            isoCalendar.firstWeekday = 2  // Monday
            if let weekStart = isoCalendar.dateInterval(of: .weekOfYear, for: day.date)?.start {
                // Normalize to midnight for consistent key matching
                let normalizedStart = calendar.startOfDay(for: weekStart)
                weekCounts[normalizedStart, default: 0] += 1
            }
        }
        daysPerWeek = weekCounts

        // Build daysPerMonth: count days with data for each month
        // Key must match month_start dates from patient_quantity_monthly_summary
        var monthCounts: [Date: Int] = [:]
        for day in dailyData where day.durationMinutes > 0 {
            // Get first day of month
            let components = calendar.dateComponents([.year, .month], from: day.date)
            if let monthStart = calendar.date(from: components) {
                monthCounts[monthStart, default: 0] += 1
            }
        }
        daysPerMonth = monthCounts

        print("📊 Computed day caches: \(daysPerWeek.count) weeks, \(daysPerMonth.count) months")
    }
}
