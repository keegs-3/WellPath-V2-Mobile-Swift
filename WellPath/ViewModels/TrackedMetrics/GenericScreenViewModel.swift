//
//  GenericScreenViewModel.swift
//  WellPath
//
//  ViewModel for generic screen that fetches metrics from display_screens_display_metrics
//  Works with the simplified database structure
//

import Foundation
import Supabase

/// Represents a metric linked to a screen with display order
struct ScreenMetric: Identifiable {
    let id: String
    let metricId: String
    let displayOrder: Int
    let overrideTitle: String?
    let metric: DisplayMetric

    var displayName: String {
        overrideTitle ?? metric.metricName
    }
}

/// Screen data with educational content
struct ScreenData {
    let screenId: String
    let name: String
    let title: String?
    let icon: String?
    let aboutContent: String?
    let longevityImpact: String?
    let quickTips: [String]?
}

@MainActor
class GenericScreenViewModel: ObservableObject {
    @Published var screenData: ScreenData?
    @Published var metrics: [ScreenMetric] = []
    @Published var isLoading = false
    @Published var error: String?

    private let screenId: String
    private let supabase = SupabaseManager.shared.client

    init(screenId: String) {
        self.screenId = screenId
    }

    /// Load screen configuration and linked metrics
    func loadScreen() async {
        isLoading = true
        error = nil

        do {
            print("📊 Loading generic screen: \(screenId)")

            // 1. Load screen data from display_screens
            let screenResults: [DisplayScreen] = try await supabase
                .from("display_screens")
                .select()
                .eq("screen_id", value: screenId)
                .limit(1)
                .execute()
                .value

            guard let screen = screenResults.first else {
                error = "Screen not found: \(screenId)"
                isLoading = false
                return
            }

            // Map to ScreenData - educational content now lives in display_screens
            screenData = ScreenData(
                screenId: screen.screenId,
                name: screen.name,
                title: screen.title,
                icon: screen.icon,
                aboutContent: screen.aboutContent,
                longevityImpact: screen.longevityImpact,
                quickTips: screen.quickTips
            )

            print("✅ Loaded screen: \(screen.name)")

            // 2. Load linked metrics from display_screens_display_metrics
            await loadScreenMetrics()

        } catch {
            let errorMessage = error.localizedDescription
            self.error = "Failed to load screen: \(errorMessage)"
            print("❌ Error loading screen \(screenId): \(error)")
        }

        isLoading = false
    }

    /// Load metrics linked to this screen
    private func loadScreenMetrics() async {
        do {
            // Query the junction table for linked metrics
            struct ScreenMetricLink: Codable {
                let metricId: String
                let displayOrder: Int?
                let overrideTitle: String?

                enum CodingKeys: String, CodingKey {
                    case metricId = "metric_id"
                    case displayOrder = "display_order"
                    case overrideTitle = "override_title"
                }
            }

            let links: [ScreenMetricLink] = try await supabase
                .from("display_screens_display_metrics")
                .select("metric_id, display_order, override_title")
                .eq("screen_id", value: screenId)
                .order("display_order", ascending: true)
                .execute()
                .value

            print("📊 Found \(links.count) linked metrics for \(screenId)")

            // Load full metric data for each linked metric
            var loadedMetrics: [ScreenMetric] = []

            for link in links {
                let metricResults: [DisplayMetric] = try await supabase
                    .from("display_metrics")
                    .select()
                    .eq("metric_id", value: link.metricId)
                    .eq("is_active", value: true)
                    .limit(1)
                    .execute()
                    .value

                if let metric = metricResults.first {
                    let screenMetric = ScreenMetric(
                        id: metric.metricId,
                        metricId: metric.metricId,
                        displayOrder: link.displayOrder ?? 0,
                        overrideTitle: link.overrideTitle,
                        metric: metric
                    )
                    loadedMetrics.append(screenMetric)
                    print("   ✅ Loaded metric: \(metric.metricName)")
                }
            }

            // Sort by display order
            metrics = loadedMetrics.sorted { $0.displayOrder < $1.displayOrder }

            print("✅ Total metrics loaded: \(metrics.count)")

        } catch {
            print("⚠️ Failed to load screen metrics: \(error)")
            // Don't fail completely - screen can still show without metrics
        }
    }

    /// Whether this screen has only one metric (can skip card view)
    var isSingleMetric: Bool {
        metrics.count == 1
    }

    /// Get the first metric (for single-metric screens)
    var primaryMetric: ScreenMetric? {
        metrics.first
    }
}
