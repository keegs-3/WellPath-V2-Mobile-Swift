//
//  BiometricsViewModel.swift
//  WellPath
//
//  Database-driven ViewModel for Biometrics section
//  Loads categories and metrics dynamically from display_card_categories and display_views
//

import Foundation
import SwiftUI
import Supabase

/// Category data from display_card_categories
struct BiometricCategoryData: Codable, Identifiable {
    let id: UUID
    let categoryId: String
    let name: String
    let overview: String?
    let iconName: String?
    let displayOrder: Int?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case categoryId = "category_id"
        case name
        case overview
        case iconName = "icon_name"
        case displayOrder = "display_order"
        case isActive = "is_active"
    }

    var icon: String { iconName ?? "circle.fill" }
}

/// Metric data from display_views
struct BiometricMetricData: Codable, Identifiable {
    let id: UUID
    let viewId: String
    let viewName: String
    let categoryId: String?
    let iconName: String?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case viewId = "view_id"
        case viewName = "view_name"
        case categoryId = "category_id"
        case iconName = "icon_name"
        case isActive = "is_active"
    }

    var icon: String { iconName ?? "circle.fill" }

    /// Bridge to DisplayMetric for existing card views
    var asDisplayMetric: DisplayMetric {
        DisplayMetric(
            id: id.uuidString,
            metricId: viewId,
            metricName: viewName,
            description: nil,
            pillar: nil,
            chartTypeId: nil,
            isActive: isActive,
            aboutContent: nil,
            longevityImpact: nil,
            quickTips: nil
        )
    }
}

@MainActor
class BiometricsViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Categories from display_card_categories
    @Published var categories: [BiometricCategoryData] = []

    /// Metrics grouped by category_id
    @Published var metricsByCategory: [String: [BiometricMetricData]] = [:]

    /// Loading state
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Private Properties

    private let supabase = SupabaseManager.shared.client
    private let sectionId = "NAV_BIOMETRICS"

    // MARK: - Computed Properties

    /// Get metrics for a specific category
    func metrics(for categoryId: String) -> [BiometricMetricData] {
        metricsByCategory[categoryId] ?? []
    }

    /// Get DisplayMetric array for a category (for existing card views)
    func displayMetrics(for categoryId: String) -> [DisplayMetric] {
        metrics(for: categoryId).map { $0.asDisplayMetric }
    }

    // MARK: - Load Data

    func loadAll() async {
        isLoading = true
        error = nil

        do {
            // Load categories for biometrics section
            let cats: [BiometricCategoryData] = try await supabase
                .from("display_card_categories")
                .select()
                .eq("section_id", value: sectionId)
                .eq("is_active", value: true)
                .order("display_order", ascending: true)
                .execute()
                .value

            categories = cats
            print("📊 BiometricsViewModel: Loaded \(cats.count) categories")

            // Load all metrics for these categories
            let categoryIds = cats.map { $0.categoryId }
            let allMetrics: [BiometricMetricData] = try await supabase
                .from("display_views")
                .select("id, view_id, view_name, category_id, icon_name, is_active")
                .in("category_id", values: categoryIds)
                .eq("is_active", value: true)
                .execute()
                .value

            // Group metrics by category
            metricsByCategory = Dictionary(grouping: allMetrics) { $0.categoryId ?? "" }

            print("📊 BiometricsViewModel: Loaded \(allMetrics.count) metrics across \(categoryIds.count) categories")
            for cat in cats {
                let count = metricsByCategory[cat.categoryId]?.count ?? 0
                print("   - \(cat.name): \(count) metrics")
            }

        } catch {
            self.error = error.localizedDescription
            print("❌ BiometricsViewModel error: \(error)")
        }

        isLoading = false
    }
}
