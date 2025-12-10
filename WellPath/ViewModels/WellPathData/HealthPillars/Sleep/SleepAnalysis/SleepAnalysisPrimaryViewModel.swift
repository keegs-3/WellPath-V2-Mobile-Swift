//
//  SleepAnalysisPrimaryViewModel.swift
//  WellPath
//
//  ViewModel for loading Sleep Analysis primary screen About content
//  Queries display_views table for education content
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

    let viewId: String
    private let supabase = SupabaseManager.shared.client

    init(viewId: String = "DISP_SLEEP_ANALYSIS") {
        self.viewId = viewId
    }

    /// Load display view and About content from display_views table
    func loadPrimaryScreen() async {
        isLoading = true
        error = nil

        do {
            print("📊 Loading Sleep Analysis primary screen for view: \(viewId)")

            // Query display_views table directly for About content
            let views: [DisplayMetric] = try await supabase
                .from("display_views")
                .select()
                .eq("view_id", value: viewId)
                .eq("is_active", value: true)
                .limit(1)
                .execute()
                .value

            guard let view = views.first else {
                error = "Display view not found for \(viewId)"
                isLoading = false
                print("❌ No view found for \(viewId)")
                return
            }

            displayMetric = view
            aboutContent = view.aboutContent
            longevityImpact = view.longevityImpact
            quickTips = view.quickTips

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
