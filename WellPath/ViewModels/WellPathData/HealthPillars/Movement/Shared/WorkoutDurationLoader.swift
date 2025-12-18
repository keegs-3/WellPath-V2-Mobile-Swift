//
//  WorkoutDurationLoader.swift
//  WellPath
//
//  Loads workout duration data for mini cards and charts
//  Queries patient_quantity_samples filtered by quantity_type
//

import Foundation
import SwiftUI

/// Data point for workout duration sparkline
struct WorkoutSparklinePoint: Identifiable {
    let id = UUID()
    let date: Date
    let durationMinutes: Double
    let isLatest: Bool

    init(date: Date, durationMinutes: Double, isLatest: Bool = false) {
        self.date = date
        self.durationMinutes = durationMinutes
        self.isLatest = isLatest
    }
}

/// Loads workout duration data for a specific category
@MainActor
class WorkoutDurationLoader: ObservableObject {
    @Published var totalDuration: Double?
    @Published var lastWorkoutDate: Date?
    @Published var sparklinePoints: [WorkoutSparklinePoint] = []
    @Published var isLoading = false
    @Published var error: String?

    private let quantityType: String
    private let supabase = SupabaseManager.shared.client

    /// Initialize with quantity type (cardio, strength_training, hiit, mobility)
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

    /// Smart date display: Shows actual date like "Nov 11, 2024"
    /// Only show relative dates (Today/Yesterday) if within last 2 days
    var formattedDate: String {
        guard let date = lastWorkoutDate else { return "" }

        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        }

        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        // Show actual date with year for older data
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    /// Formatted duration string
    var formattedDuration: String {
        guard let duration = totalDuration else { return "--" }

        if duration < 60 {
            return "\(Int(duration))m"
        } else {
            let hours = Int(duration) / 60
            let minutes = Int(duration) % 60
            if minutes == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(minutes)m"
        }
    }

    /// Load workout data:
    /// 1. Fetch the MOST RECENT workout (any date) for main display
    /// 2. Fetch last 7 days for sparkline (may be empty)
    func loadData() async {
        isLoading = true
        error = nil

        do {
            guard let patientId = try? await supabase.auth.session.user.id else {
                isLoading = false
                return
            }

            let calendar = Calendar.current
            let now = Date()

            struct SampleRow: Codable {
                let startTime: Date
                let quantityValue: Double?

                enum CodingKeys: String, CodingKey {
                    case startTime = "start_time"
                    case quantityValue = "quantity_value"
                }
            }

            // 1. Query the MOST RECENT workout (limit 1, no date filter)
            let recentRows: [SampleRow] = try await supabase
                .from("patient_quantity_samples")
                .select("start_time, quantity_value")
                .eq("patient_id", value: patientId.uuidString)
                .eq("quantity_type", value: quantityType)
                .order("start_time", ascending: false)
                .limit(1)
                .execute()
                .value

            // Set the most recent workout data (even if from years ago)
            if let latestRow = recentRows.first {
                lastWorkoutDate = latestRow.startTime
                totalDuration = latestRow.quantityValue
            }

            // 2. Query last 7 days for sparkline
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

            let sparkRows: [SampleRow] = try await supabase
                .from("patient_quantity_samples")
                .select("start_time, quantity_value")
                .eq("patient_id", value: patientId.uuidString)
                .eq("quantity_type", value: quantityType)
                .gte("start_time", value: ISO8601DateFormatter().string(from: weekAgo))
                .order("start_time", ascending: false)
                .execute()
                .value

            // Build 7-day spark chart (with empty days showing as gaps)
            // Generate all 7 calendar days first
            var durationByDay: [Date: Double] = [:]

            // Initialize all 7 days with zero
            for daysBack in 0..<7 {
                if let date = calendar.date(byAdding: .day, value: -daysBack, to: now) {
                    let dayStart = calendar.startOfDay(for: date)
                    durationByDay[dayStart] = 0
                }
            }

            // Fill in actual data
            for row in sparkRows {
                let dayStart = calendar.startOfDay(for: row.startTime)
                durationByDay[dayStart, default: 0] += row.quantityValue ?? 0
            }

            // Convert to sparkline points (sorted by date, oldest to newest)
            let sortedDays = durationByDay.keys.sorted()
            let today = calendar.startOfDay(for: now)

            sparklinePoints = sortedDays.map { date in
                WorkoutSparklinePoint(
                    date: date,
                    durationMinutes: durationByDay[date] ?? 0,
                    isLatest: calendar.isDate(date, inSameDayAs: today)
                )
            }

        } catch {
            self.error = error.localizedDescription
            print("❌ WorkoutDurationLoader error: \(error)")
        }

        isLoading = false
    }
}
