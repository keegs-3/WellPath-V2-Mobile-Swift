//
//  DetailScreenViewModel.swift
//  WellPath
//
//  ViewModel for loading detail screen configuration and metrics
//

import Foundation
import Supabase

// Combined metric data for display
struct DetailMetric: Identifiable {
    let id: String
    let metric: DisplayMetric
    let link: DetailMetricLink

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
class DetailScreenViewModel: ObservableObject {
    @Published var detailScreen: DetailScreen?
    @Published var metrics: [DetailMetric] = []
    @Published var isLoading = false
    @Published var error: String?

    let screenId: String
    private let supabase = SupabaseManager.shared.client

    init(screenId: String) {
        self.screenId = screenId
    }

    /// Load detail screen configuration and metrics
    func loadDetailScreen() async {
        isLoading = true
        error = nil

        do {
            print("📊 Loading detail screen for: \(screenId)")

            // Step 1: Get detail screen configuration
            let screens: [DetailScreen] = try await supabase
                .from("display_screens_detail")
                .select()
                .eq("display_screen_id", value: screenId)
                .eq("is_active", value: true)
                .limit(1)
                .execute()
                .value

            guard let screen = screens.first else {
                error = "Detail screen not found for \(screenId)"
                isLoading = false
                return
            }

            detailScreen = screen
            print("✅ Loaded detail screen: \(screen.title ?? screenId)")

            // Step 2: Get junction links with metrics
            let links: [DetailMetricLink] = try await supabase
                .from("display_screens_detail_display_metrics")
                .select()
                .eq("detail_screen_id", value: screen.detailScreenId)
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
            var combined: [DetailMetric] = []
            for link in links {
                if let metric = displayMetrics.first(where: { $0.metricId == link.metricId }) {
                    combined.append(DetailMetric(
                        id: link.id,
                        metric: metric,
                        link: link
                    ))
                    print("   - \(metric.metricName) (chart: \(link.overrideChartType ?? metric.chartTypeId ?? "none"))")
                }
            }

            metrics = combined
            print("✅ Loaded \(metrics.count) detail metrics for \(screenId)")

        } catch {
            let errorMessage = error.localizedDescription
            self.error = "Failed to load detail screen: \(errorMessage)"
            print("❌ Error loading detail screen: \(error)")
        }

        isLoading = false
    }
}
