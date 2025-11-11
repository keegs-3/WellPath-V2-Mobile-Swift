//
//  SleepAnalysisPrimaryViewModel.swift
//  WellPath
//
//  ViewModel for loading Sleep Analysis primary screen About content
//  Queries display_metrics table for education content
//

import Foundation
import Supabase

@MainActor
class SleepAnalysisPrimaryViewModel: ObservableObject {
    @Published var displayMetric: DisplayMetric?
    @Published var aboutContent: String?
    @Published var longevityImpact: String?
    @Published var quickTips: [String]?
    @Published var isLoading = false
    @Published var error: String?

    private let metricId: String
    private let supabase = SupabaseManager.shared.client

    init(metricId: String = "DISP_SLEEP_ANALYSIS") {
        self.metricId = metricId
    }

    /// Load display metric and About content from display_metrics table
    func loadPrimaryScreen() async {
        isLoading = true
        error = nil

        do {
            print("📊 Loading Sleep Analysis primary screen for metric: \(metricId)")

            // Query display_metrics table directly for About content
            let metrics: [DisplayMetric] = try await supabase
                .from("display_metrics")
                .select()
                .eq("metric_id", value: metricId)
                .eq("is_active", value: true)
                .limit(1)
                .execute()
                .value

            guard let metric = metrics.first else {
                error = "Display metric not found for \(metricId)"
                isLoading = false
                print("❌ No metric found for \(metricId)")
                return
            }

            displayMetric = metric
            aboutContent = metric.aboutContent
            longevityImpact = metric.longevityImpact
            quickTips = metric.quickTips

            print("✅ Loaded Sleep Analysis About content:")
            print("   - About: \(aboutContent != nil ? "✓" : "✗")")
            print("   - Impact: \(longevityImpact != nil ? "✓" : "✗")")
            print("   - Tips: \(quickTips?.count ?? 0) tips")

        } catch {
            let errorMessage = error.localizedDescription
            self.error = "Failed to load Sleep Analysis content: \(errorMessage)"
            print("❌ Error loading Sleep Analysis primary screen: \(error)")
        }

        isLoading = false
    }
}
