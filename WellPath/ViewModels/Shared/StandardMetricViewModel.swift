//
//  StandardMetricViewModel.swift
//  WellPath
//
//  Generic ViewModel for standard metrics (bar/line charts)
//  Loads display_metric config and About content for any metric_id
//  Use this for simple metrics that use ParentMetricBarChart
//

import Foundation
import Supabase

// Generic metric wrapper for display
struct StandardMetric: Identifiable {
    let id: String
    let metric: DisplayMetric

    // Computed properties for display
    var displayName: String {
        metric.metricName
    }

    var displayDescription: String? {
        metric.description
    }

    var chartType: String? {
        metric.chartTypeId
    }
}

@MainActor
class StandardMetricViewModel: ObservableObject {
    @Published var displayMetric: DisplayMetric?
    @Published var metrics: [StandardMetric] = []
    @Published var aboutContent: String?
    @Published var longevityImpact: String?
    @Published var quickTips: [String]?
    @Published var isLoading = false
    @Published var error: String?

    // Summary values for mini cards
    @Published var todayValue: Double?
    @Published var weeklyAverageValue: Double?
    @Published var displayUnit: String = "servings"
    @Published var chartData: [(date: Date, value: Double)] = []  // Last 7 days for mini charts

    private let metricId: String
    private let supabase = SupabaseManager.shared.client

    init(metricId: String) {
        self.metricId = metricId
    }

    /// Load display metric and About content from display_metrics table
    func loadPrimaryScreen() async {
        isLoading = true
        error = nil

        do {
            print("📊 Loading standard metric: \(metricId)")

            // Query display_views table directly for chart config + About content
            let results: [DisplayMetric] = try await supabase
                .from("display_views")
                .select()
                .eq("view_id", value: metricId)
                .eq("is_active", value: true)
                .limit(1)
                .execute()
                .value

            guard let metric = results.first else {
                error = "Display metric not found for \(metricId)"
                isLoading = false
                print("❌ No metric found for \(metricId)")
                return
            }

            displayMetric = metric
            aboutContent = metric.aboutContent
            longevityImpact = metric.longevityImpact
            quickTips = metric.quickTips

            // Create single metric item for chart display
            metrics = [StandardMetric(id: metric.metricId, metric: metric)]

            print("✅ Loaded standard metric: \(metric.metricName)")
            print("   - About: \(aboutContent != nil ? "✓" : "✗")")
            print("   - Impact: \(longevityImpact != nil ? "✓" : "✗")")
            print("   - Tips: \(quickTips?.count ?? 0) tips")

        } catch {
            let errorMessage = error.localizedDescription
            self.error = "Failed to load metric: \(errorMessage)"
            print("❌ Error loading metric \(metricId): \(error)")
        }

        isLoading = false

        // Also load summary values for mini cards
        await loadSummaryValues()
    }

    /// Load today's value and weekly average from patient_quantity_samples/patient_category_samples
    func loadSummaryValues() async {
        do {
            // First, get the sample type from display_views_dependencies
            struct DependencyResult: Codable {
                let sampleQuantityType: String?
                let sampleCategoryType: String?
                let sampleClinicalType: String?
                enum CodingKeys: String, CodingKey {
                    case sampleQuantityType = "sample_quantity_type"
                    case sampleCategoryType = "sample_category_type"
                    case sampleClinicalType = "sample_clinical_type"
                }
            }

            let depResults: [DependencyResult] = try await supabase
                .from("display_views_dependencies")
                .select("sample_quantity_type, sample_category_type, sample_clinical_type")
                .eq("view_id", value: metricId)
                .eq("is_primary", value: true)
                .execute()
                .value

            guard let dep = depResults.first else {
                print("⚠️ No dependency found for \(metricId)")
                return
            }

            // Display unit will be set by the specific load method if needed

            let localCalendar = Calendar.current
            let todayStart = localCalendar.startOfDay(for: Date())
            let weekAgo = localCalendar.date(byAdding: .day, value: -7, to: todayStart) ?? todayStart

            // Use direct patient_samples query if sample type is available
            if let quantityType = dep.sampleQuantityType {
                // Direct query to patient_samples
                try await loadFromPatientSamples(quantityType: quantityType, startDate: weekAgo, endDate: todayStart)
            } else if let categoryType = dep.sampleCategoryType, categoryType == "sleep_period_types" {
                // Sleep data - use PatientSamplesQueryService
                try await loadSleepFromPatientSamples(startDate: weekAgo, endDate: todayStart)
            } else {
                // No sample_type configured - this metric needs migration
                print("⚠️ No sample_type configured for \(metricId)")
            }

        } catch {
            print("❌ Error loading summary values: \(error)")
        }
    }

    /// Load data directly from patient_quantity_samples
    private func loadFromPatientSamples(quantityType: String, startDate: Date, endDate: Date) async throws {
        let service = PatientSamplesQueryService.shared

        let dailyValues = try await service.fetchQuantityDaily(
            quantityType: quantityType,
            startDate: startDate,
            endDate: endDate
        )

        print("📊 Direct patient_quantity_samples for \(metricId) (\(quantityType)): \(dailyValues.count) days")

        // Use local calendar to get today's date components
        let localCalendar = Calendar.current
        let todayComponents = localCalendar.dateComponents([.year, .month, .day], from: Date())

        // Use UTC calendar for database dates (aggregation_date is a DATE stored as UTC midnight)
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        // Find today's value by comparing UTC date components
        for daily in dailyValues {
            // Extract UTC components from the database date
            let resultComponents = utcCalendar.dateComponents([.year, .month, .day], from: daily.date)
            if resultComponents.year == todayComponents.year &&
               resultComponents.month == todayComponents.month &&
               resultComponents.day == todayComponents.day {
                todayValue = daily.value
                print("   ✅ Today: \(daily.value)")
                break
            }
        }

        // Calculate weekly average
        if !dailyValues.isEmpty {
            let total = dailyValues.reduce(0) { $0 + $1.value }
            weeklyAverageValue = total / Double(dailyValues.count)
            print("   Weekly avg: \(weeklyAverageValue ?? 0) from \(dailyValues.count) days")
        }

        // Populate chartData for mini charts
        chartData = dailyValues.map { (date: $0.date, value: $0.value) }
    }

    /// Load sleep data directly from patient_category_samples
    private func loadSleepFromPatientSamples(startDate: Date, endDate: Date) async throws {
        let service = PatientSamplesQueryService.shared

        let dailyValues = try await service.fetchSleepDurationDaily(
            startDate: startDate,
            endDate: endDate
        )

        print("📊 Direct patient_category_samples sleep for \(metricId): \(dailyValues.count) days")

        // Use local calendar to get today's date components
        let localCalendar = Calendar.current
        let todayComponents = localCalendar.dateComponents([.year, .month, .day], from: Date())

        // Use UTC calendar for database dates (aggregation_date is a DATE stored as UTC midnight)
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        // Find today's value (sleep duration in minutes)
        for daily in dailyValues {
            // Extract UTC components from the database date
            let resultComponents = utcCalendar.dateComponents([.year, .month, .day], from: daily.date)
            if resultComponents.year == todayComponents.year &&
               resultComponents.month == todayComponents.month &&
               resultComponents.day == todayComponents.day {
                todayValue = daily.value  // Minutes
                print("   ✅ Today sleep: \(daily.value) minutes")
                break
            }
        }

        // Calculate weekly average
        if !dailyValues.isEmpty {
            let total = dailyValues.reduce(0) { $0 + $1.value }
            weeklyAverageValue = total / Double(dailyValues.count)
            print("   Weekly avg: \(weeklyAverageValue ?? 0) minutes from \(dailyValues.count) days")
        }

        // Populate chartData for mini charts
        chartData = dailyValues.map { (date: $0.date, value: $0.value) }
        displayUnit = "min"
    }

}
