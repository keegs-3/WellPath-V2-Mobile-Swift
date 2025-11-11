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
            metrics = [ProteinPrimaryMetric(id: metric.metricId, metric: metric)]

            print("✅ Loaded Protein primary metric:")
            print("   - Name: \(metric.metricName)")
            print("   - About: \(aboutContent != nil ? "✓" : "✗")")
            print("   - Impact: \(longevityImpact != nil ? "✓" : "✗")")
            print("   - Tips: \(quickTips?.count ?? 0) tips")

        } catch {
            let errorMessage = error.localizedDescription
            self.error = "Failed to load Protein primary screen: \(errorMessage)"
            print("❌ Error loading Protein primary screen: \(error)")
        }

        isLoading = false
    }
}
