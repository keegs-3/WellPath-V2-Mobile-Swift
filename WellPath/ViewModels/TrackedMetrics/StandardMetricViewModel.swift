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

            // Query display_metrics table directly for chart config + About content
            let results: [DisplayMetric] = try await supabase
                .from("display_metrics")
                .select()
                .eq("metric_id", value: metricId)
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
    }
}
