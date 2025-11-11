//
//  TrackedMetricsViewModel.swift
//  WellPath
//
//  Created on 2025-10-22
//

import Foundation
import Supabase
import SwiftUI

@MainActor
class TrackedMetricsViewModel: ObservableObject {
    @Published var pillars: [String] = []
    @Published var screensByPillar: [String: [DisplayScreen]] = [:]
    @Published var metricCountsByScreen: [String: Int] = [:]
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    // Pillar order from pillars_base.display_order
    private let pillarOrder = [
        "Healthful Nutrition",
        "Movement + Exercise",
        "Restorative Sleep",
        "Stress Management",
        "Cognitive Health",
        "Connection + Purpose",
        "Core Care"
    ]

    func loadMetricsData() async {
        isLoading = true
        error = nil

        do {
            print("🔍 Starting to load display screens from display_screens table...")

            // Fetch all active display screens
            let fetchedScreens: [DisplayScreen] = try await supabase
                .from("display_screens")
                .select()
                .eq("is_active", value: true)
                .order("display_order", ascending: true)
                .execute()
                .value

            print("✅ Loaded \(fetchedScreens.count) display screens")

            // Group by pillar
            var grouped: [String: [DisplayScreen]] = [:]
            var uniquePillars: Set<String> = []

            for screen in fetchedScreens {
                let pillar = screen.pillar ?? "Other"
                uniquePillars.insert(pillar)

                if grouped[pillar] == nil {
                    grouped[pillar] = []
                }
                grouped[pillar]?.append(screen)

                print("  - \(screen.name) → \(pillar)")
            }

            // Sort pillars by predefined order
            pillars = pillarOrder.filter { uniquePillars.contains($0) }
            screensByPillar = grouped

            print("✅ Found \(pillars.count) pillars: \(pillars.joined(separator: ", "))")

            // Load metric counts for each screen
            await loadMetricCounts()

        } catch {
            let errorMessage = error.localizedDescription
            self.error = "Failed to load display screens: \(errorMessage)"
            print("❌ Error loading display screens: \(error)")
            print("❌ Error details: \(String(describing: error))")
        }

        isLoading = false
    }

    func loadMetricCounts() async {
        // NOTE: Legacy code - screen_id doesn't exist in display_metrics table anymore
        // Metrics are now linked via junction tables (display_screens_primary_display_metrics, etc.)
        // TODO: Query junction tables if metric counts are needed
        do {
            print("🔍 Loading metric counts (skipped - legacy code)...")

            // Commented out - screen_id column doesn't exist in new schema
            // struct MetricCount: Codable {
            //     let displayScreenId: String?
            //     enum CodingKeys: String, CodingKey {
            //         case displayScreenId = "screen_id"
            //     }
            // }
            // let metrics: [MetricCount] = try await supabase
            //     .from("display_metrics")
            //     .select("screen_id")
            //     .eq("is_active", value: true)
            //     .execute()
            //     .value

            // Count metrics per screen
            var counts: [String: Int] = [:]
            // Placeholder - no metrics counted for now
            // for metric in metrics {
            //     if let screenId = metric.displayScreenId {
            //         counts[screenId, default: 0] += 1
            //     }
            // }

            metricCountsByScreen = counts

            print("✅ Counted metrics for \(counts.count) screens")

        } catch {
            print("⚠️ Failed to load metric counts: \(error)")
            // Don't fail the whole load if metric counts fail
        }
    }

    func getScreens(forPillar pillar: String) -> [DisplayScreen] {
        return screensByPillar[pillar] ?? []
    }

    func getMetricCount(forScreen screenId: String) -> Int {
        return metricCountsByScreen[screenId] ?? 0
    }
}
