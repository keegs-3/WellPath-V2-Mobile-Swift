//
//  PrimaryScreenViewModel.swift
//  WellPath
//
//  ViewModel for loading primary screen configuration and metrics
//

import Foundation
import Supabase

// Combined metric data for display
struct PrimaryMetric: Identifiable {
    let id: String
    let metric: DisplayMetric
    let link: PrimaryMetricLink

    // Computed properties for display
    var displayName: String {
        link.contextLabel ?? metric.metricName
    }

    var displayDescription: String? {
        link.overrideDescription ?? metric.description
    }

    var chartType: String? {
        link.overrideChartType ?? metric.chartTypeId
    }
}

@MainActor
class PrimaryScreenViewModel: ObservableObject {
    @Published var primaryScreen: PrimaryScreen?
    @Published var displayScreen: DisplayScreen?
    @Published var metrics: [PrimaryMetric] = []
    @Published var isLoading = false
    @Published var error: String?

    let screenId: String
    private let supabase = SupabaseManager.shared.client

    init(screenId: String) {
        self.screenId = screenId
    }

    /// Load primary screen configuration and metrics
    func loadPrimaryScreen() async {
        isLoading = true
        error = nil

        do {
            print("📊 Loading primary screen for: \(screenId)")

            // Step 0: Load display_screens for icon and pillar
            let displayScreens: [DisplayScreen] = try await supabase
                .from("display_screens")
                .select()
                .eq("screen_id", value: screenId)
                .limit(1)
                .execute()
                .value

            displayScreen = displayScreens.first
            print("📱 Loaded display screen: icon=\(displayScreen?.icon ?? "none"), pillar=\(displayScreen?.pillar ?? "none")")

            // Step 1: Get primary screen configuration
            let screens: [PrimaryScreen] = try await supabase
                .from("display_screens_primary")
                .select()
                .eq("display_screen_id", value: screenId)
                .eq("is_active", value: true)
                .limit(1)
                .execute()
                .value

            guard let screen = screens.first else {
                error = "Primary screen not found for \(screenId)"
                isLoading = false
                return
            }

            primaryScreen = screen
            print("✅ Loaded primary screen: \(screen.title ?? screenId)")

            // Step 2: Get junction links with metrics
            let links: [PrimaryMetricLink] = try await supabase
                .from("display_screens_primary_display_metrics")
                .select()
                .eq("primary_screen_id", value: screen.primaryScreenId)
                .order("display_order", ascending: true)
                .execute()
                .value

            print("📎 Found \(links.count) metric links")

            // Step 3: Get all metrics referenced by links
            let metricIds = links.map { $0.metricId }
            guard !metricIds.isEmpty else {
                metrics = []
                isLoading = false
                return
            }

            let displayMetrics: [DisplayMetric] = try await supabase
                .from("display_metrics")
                .select()
                .in("metric_id", values: metricIds)
                .eq("is_active", value: true)
                .execute()
                .value

            print("📈 Loaded \(displayMetrics.count) metrics")

            // Step 4: Combine links and metrics
            var combined: [PrimaryMetric] = []
            for link in links {
                if let metric = displayMetrics.first(where: { $0.metricId == link.metricId }) {
                    combined.append(PrimaryMetric(
                        id: link.id,
                        metric: metric,
                        link: link
                    ))
                    print("   - \(metric.metricName) (chart: \(link.overrideChartType ?? metric.chartTypeId ?? "none"))")
                }
            }

            metrics = combined
            print("✅ Loaded \(metrics.count) primary metrics for \(screenId)")

        } catch {
            let errorMessage = error.localizedDescription
            self.error = "Failed to load primary screen: \(errorMessage)"
            print("❌ Error loading primary screen: \(error)")
        }

        isLoading = false
    }
}
