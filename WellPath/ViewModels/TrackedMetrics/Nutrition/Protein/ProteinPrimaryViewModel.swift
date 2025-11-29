//
//  ProteinPrimaryViewModel.swift
//  WellPath
//
//  ViewModel for loading Protein primary screen with chart data and About content
//  Simplified to query display_metrics directly
//

import Foundation
import Supabase

// Combined metric data for display
struct ProteinPrimaryMetric: Identifiable {
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
class ProteinPrimaryViewModel: ObservableObject {
    @Published var displayMetric: DisplayMetric?
    @Published var metrics: [ProteinPrimaryMetric] = []
    @Published var aboutContent: String?
    @Published var longevityImpact: String?
    @Published var quickTips: [String]?
    @Published var isLoading = false
    @Published var error: String?

    // Summary data for mini cards
    @Published var todayValue: Double?
    @Published var weeklyAverage: Double?

    // Card titles from display_metrics (loaded dynamically)
    @Published var amountTitle: String = "Protein Amount"
    @Published var timingTitle: String = "Protein Timing"
    @Published var typeTitle: String = "Protein Type"
    @Published var ratioTitle: String = "Protein Ratio"

    // All protein display metrics
    @Published var allProteinMetrics: [String: DisplayMetric] = [:]

    private let metricId: String
    private let supabase = SupabaseManager.shared.client

    init(metricId: String = "DISP_PROTEIN_GRAMS") {
        self.metricId = metricId
    }

    /// Load display metric and About content from display_metrics table
    func loadPrimaryScreen() async {
        isLoading = true
        error = nil

        do {
            print("📊 Loading Protein primary screen for metric: \(metricId)")

            // Query ALL protein display_metrics for card titles
            let allResults: [DisplayMetric] = try await supabase
                .from("display_metrics")
                .select()
                .like("metric_id", pattern: "DISP_PROTEIN%")
                .eq("is_active", value: true)
                .execute()
                .value

            // Store all metrics and set titles dynamically
            for metric in allResults {
                allProteinMetrics[metric.metricId] = metric

                switch metric.metricId {
                case "DISP_PROTEIN_GRAMS":
                    amountTitle = metric.metricName
                case "DISP_PROTEIN_MEAL_TIMING":
                    timingTitle = metric.metricName
                case "DISP_PROTEIN_TYPE":
                    typeTitle = metric.metricName
                case "DISP_PROTEIN_PER_KG":
                    ratioTitle = metric.metricName
                default:
                    break
                }
            }

            print("📊 Loaded \(allResults.count) protein display metrics")
            print("   - Amount: \(amountTitle)")
            print("   - Timing: \(timingTitle)")
            print("   - Type: \(typeTitle)")
            print("   - Ratio: \(ratioTitle)")

            // Get the primary metric for the main chart
            guard let metric = allProteinMetrics[metricId] else {
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
            metrics = [ProteinPrimaryMetric(id: metric.metricId, metric: metric)]

            print("✅ Loaded Protein primary metric:")
            print("   - Name: \(metric.metricName)")
            print("   - About: \(aboutContent != nil ? "✓" : "✗")")
            print("   - Impact: \(longevityImpact != nil ? "✓" : "✗")")
            print("   - Tips: \(quickTips?.count ?? 0) tips")

            // Load summary data for mini cards
            await loadSummaryData()

        } catch {
            let errorMessage = error.localizedDescription
            self.error = "Failed to load Protein primary screen: \(errorMessage)"
            print("❌ Error loading Protein primary screen: \(error)")
        }

        isLoading = false
    }

    /// Load today's value and weekly average from aggregation_results_cache
    private func loadSummaryData() async {
        do {
            let patientId = try await supabase.auth.session.user.id
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            // Get today's value (daily SUM aggregation)
            struct AggResult: Codable {
                let value: Double
                let periodStart: Date

                enum CodingKeys: String, CodingKey {
                    case value
                    case periodStart = "period_start"
                }
            }

            let todayResults: [AggResult] = try await supabase
                .from("aggregation_results_cache")
                .select("value, period_start")
                .eq("patient_id", value: patientId)
                .eq("agg_metric_id", value: "AGG_PROTEIN_GRAMS")
                .eq("period_type", value: "daily")
                .eq("calculation_type_id", value: "SUM")
                .gte("period_start", value: ISO8601DateFormatter().string(from: today))
                .lt("period_start", value: ISO8601DateFormatter().string(from: calendar.date(byAdding: .day, value: 1, to: today)!))
                .limit(1)
                .execute()
                .value

            todayValue = todayResults.first?.value

            // Get weekly average (last 7 days of daily SUM values, including today)
            let weekAgo = calendar.date(byAdding: .day, value: -6, to: today)!
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

            let weekResults: [AggResult] = try await supabase
                .from("aggregation_results_cache")
                .select("value, period_start")
                .eq("patient_id", value: patientId)
                .eq("agg_metric_id", value: "AGG_PROTEIN_GRAMS")
                .eq("period_type", value: "daily")
                .eq("calculation_type_id", value: "SUM")
                .gte("period_start", value: ISO8601DateFormatter().string(from: weekAgo))
                .lt("period_start", value: ISO8601DateFormatter().string(from: tomorrow))
                .execute()
                .value

            if !weekResults.isEmpty {
                let sum = weekResults.reduce(0.0) { $0 + $1.value }
                weeklyAverage = sum / Double(weekResults.count)
            }

            print("📊 Summary data: today=\(todayValue ?? 0), weeklyAvg=\(weeklyAverage ?? 0)")

        } catch {
            print("⚠️ Failed to load summary data: \(error)")
        }
    }
}
