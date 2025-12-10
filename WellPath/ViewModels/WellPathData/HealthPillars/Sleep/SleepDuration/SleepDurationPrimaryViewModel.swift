//
//  SleepDurationPrimaryViewModel.swift
//  WellPath
//
//  ViewModel for loading Sleep Duration primary screen with chart data and About content
//  Simplified to query display_views directly
//

import Foundation
import Supabase

// Combined metric data for display
struct SleepDurationPrimaryMetric: Identifiable {
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
class SleepDurationPrimaryViewModel: ObservableObject {
    @Published var displayMetric: DisplayMetric?
    @Published var metrics: [SleepDurationPrimaryMetric] = []
    @Published var aboutContent: String?
    @Published var longevityImpact: String?
    @Published var quickTips: [String]?
    @Published var isLoading = false
    @Published var error: String?

    private let viewId: String
    private let supabase = SupabaseManager.shared.client

    init(viewId: String = "DISP_SLEEP_DURATION") {
        self.viewId = viewId
    }

    /// Load display view and About content from display_views table
    func loadPrimaryScreen() async {
        isLoading = true
        error = nil

        do {
            print("📊 Loading Sleep Duration primary screen for view: \(viewId)")

            // Query display_views table directly for chart config + About content
            let results: [DisplayMetric] = try await supabase
                .from("display_views")
                .select()
                .eq("view_id", value: viewId)
                .eq("is_active", value: true)
                .limit(1)
                .execute()
                .value

            guard let view = results.first else {
                error = "Display view not found for \(viewId)"
                isLoading = false
                print("❌ No view found for \(viewId)")
                return
            }

            displayMetric = view
            aboutContent = view.aboutContent
            longevityImpact = view.longevityImpact
            quickTips = view.quickTips

            // Create single metric item for chart display
            metrics = [SleepDurationPrimaryMetric(id: view.metricId, metric: view)]

            print("✅ Loaded Sleep Duration primary view:")
            print("   - Name: \(view.metricName)")
            print("   - About: \(aboutContent != nil ? "✓" : "✗")")
            print("   - Impact: \(longevityImpact != nil ? "✓" : "✗")")
            print("   - Tips: \(quickTips?.count ?? 0) tips")

        } catch {
            let errorMessage = error.localizedDescription
            self.error = "Failed to load Sleep Duration primary screen: \(errorMessage)"
            print("❌ Error loading Sleep Duration primary screen: \(error)")
        }

        isLoading = false
    }
}

