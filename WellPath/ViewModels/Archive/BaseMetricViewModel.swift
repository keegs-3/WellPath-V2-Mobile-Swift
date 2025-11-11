//
//  BaseMetricViewModel.swift
//  WellPath
//
//  Base view model for custom metric screens
//  Provides common functionality for loading metrics from database
//

import Foundation
import Supabase

@MainActor
class BaseMetricViewModel: ObservableObject {
    @Published var primaryMetric: DisplayMetric?
    @Published var childMetrics: [DisplayMetric] = []
    @Published var isLoading = false
    @Published var error: String?

    let screenId: String
    private let supabase = SupabaseManager.shared.client

    init(screenId: String) {
        self.screenId = screenId
    }

    /// Load metrics for this screen from the database
    func loadMetrics() async {
        isLoading = true
        error = nil

        do {
            print("📊 Loading metrics for screen: \(screenId)")

            // Query display_metrics table for this screen
            let metrics: [DisplayMetric] = try await supabase
                .from("display_metrics")
                .select()
                .eq("screen_id", value: screenId)
                .eq("is_active", value: true)
                .execute()
                .value

            print("✅ Loaded \(metrics.count) metrics for \(screenId)")

            // Use first metric as primary (isPrimary field doesn't exist in new model)
            if let first = metrics.first {
                primaryMetric = first
                print("   Using first metric: \(first.metricName) (chart: \(first.chartTypeId ?? "none"))")
            }

            // All remaining metrics are children (parentMetricId doesn't exist in new model)
            childMetrics = Array(metrics.dropFirst())
            print("   Child metrics: \(childMetrics.count)")

        } catch {
            let errorMessage = error.localizedDescription
            self.error = "Failed to load metrics: \(errorMessage)"
            print("❌ Error loading metrics: \(error)")
        }

        isLoading = false
    }

    /// Get child metrics for a specific parent
    /// NOTE: Parent/child relationships don't exist in simplified DisplayMetric model
    func getChildMetrics(forParent parentMetricId: String) -> [DisplayMetric] {
        return childMetrics  // Just return all child metrics
    }
}
