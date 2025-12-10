//
//  TrackedMetricsViewModel.swift
//  WellPath
//
//  Created on 2025-10-22
//  Updated 2025-12-01: Simplified - navigation now handled by DisplayConfigurationService
//

import Foundation
import Supabase
import SwiftUI

@MainActor
class TrackedMetricsViewModel: ObservableObject {
    @Published var allMetrics: [DisplayMetric] = []  // For search
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    func loadMetricsData() async {
        isLoading = true
        error = nil

        do {
            // Load display views for search functionality
            await loadAllMetrics()
        } catch {
            self.error = "Failed to load data: \(error.localizedDescription)"
            print("❌ Error loading data: \(error)")
        }

        isLoading = false
    }

    /// Load all display views for search functionality
    private func loadAllMetrics() async {
        do {
            let fetchedMetrics: [DisplayMetric] = try await supabase
                .from("display_views")
                .select()
                .eq("is_active", value: true)
                .order("view_name", ascending: true)
                .execute()
                .value

            allMetrics = fetchedMetrics
            print("✅ Loaded \(fetchedMetrics.count) display views for search")

        } catch {
            print("❌ Failed to load display views: \(error)")
        }
    }
}
