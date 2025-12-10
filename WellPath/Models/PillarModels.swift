//
//  PillarModels.swift
//  WellPath
//
//  Created on 2025-10-22
//

import Foundation
import SwiftUI

// MARK: - Display Categories (Navigation containers, from display_categories table)
// Simplified structure: categories are just navigation groupings within a pillar

struct DisplayCategory: Codable, Identifiable {
    let id: String
    let categoryId: String
    let name: String
    let overview: String?
    let pillar: String?
    let displayOrder: Int?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case categoryId = "category_id"
        case name
        case overview
        case pillar
        case displayOrder = "display_order"
        case isActive = "is_active"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        categoryId = try container.decode(String.self, forKey: .categoryId)
        name = try container.decode(String.self, forKey: .name)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        pillar = try container.decodeIfPresent(String.self, forKey: .pillar)
        displayOrder = try container.decodeIfPresent(Int.self, forKey: .displayOrder)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
    }

    init(
        id: String,
        categoryId: String,
        name: String,
        overview: String? = nil,
        pillar: String? = nil,
        displayOrder: Int? = nil,
        isActive: Bool? = nil
    ) {
        self.id = id
        self.categoryId = categoryId
        self.name = name
        self.overview = overview
        self.pillar = pillar
        self.displayOrder = displayOrder
        self.isActive = isActive
    }
}

// MARK: - Display Views (Full pages with charts, from display_views table)
// Views contain educational content and chart configuration

struct DisplayView: Codable, Identifiable, Hashable {
    let id: String
    let viewId: String
    let viewName: String
    let categoryId: String?
    let pillar: String?
    let displayOrder: Int?
    let isActive: Bool?
    let chartTypeId: String?
    let defaultTimePeriod: String?
    let description: String?

    // Educational content
    let aboutContent: String?
    let longevityImpact: String?
    let quickTips: [String]?
    let infoSections: [[String: String]]?

    // Goal configuration
    let hasGoal: Bool?
    let goalConfig: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id
        case viewId = "view_id"
        case viewName = "view_name"
        case categoryId = "category_id"
        case pillar
        case displayOrder = "display_order"
        case isActive = "is_active"
        case chartTypeId = "chart_type_id"
        case defaultTimePeriod = "default_time_period"
        case description
        case aboutContent = "about_content"
        case longevityImpact = "longevity_impact"
        case quickTips = "quick_tips"
        case infoSections = "info_sections"
        case hasGoal = "has_goal"
        case goalConfig = "goal_config"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        viewId = try container.decode(String.self, forKey: .viewId)
        viewName = try container.decode(String.self, forKey: .viewName)
        categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
        pillar = try container.decodeIfPresent(String.self, forKey: .pillar)
        displayOrder = try container.decodeIfPresent(Int.self, forKey: .displayOrder)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
        chartTypeId = try container.decodeIfPresent(String.self, forKey: .chartTypeId)
        defaultTimePeriod = try container.decodeIfPresent(String.self, forKey: .defaultTimePeriod)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        aboutContent = try? container.decodeIfPresent(String.self, forKey: .aboutContent)
        longevityImpact = try? container.decodeIfPresent(String.self, forKey: .longevityImpact)
        quickTips = try? container.decodeIfPresent([String].self, forKey: .quickTips)
        infoSections = try? container.decodeIfPresent([[String: String]].self, forKey: .infoSections)
        hasGoal = try? container.decodeIfPresent(Bool.self, forKey: .hasGoal)
        goalConfig = try? container.decodeIfPresent([String: String].self, forKey: .goalConfig)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DisplayView, rhs: DisplayView) -> Bool {
        lhs.id == rhs.id
    }

    init(
        id: String,
        viewId: String,
        viewName: String,
        categoryId: String? = nil,
        pillar: String? = nil,
        displayOrder: Int? = nil,
        isActive: Bool? = nil,
        chartTypeId: String? = nil,
        defaultTimePeriod: String? = nil,
        description: String? = nil,
        aboutContent: String? = nil,
        longevityImpact: String? = nil,
        quickTips: [String]? = nil,
        infoSections: [[String: String]]? = nil,
        hasGoal: Bool? = nil,
        goalConfig: [String: String]? = nil
    ) {
        self.id = id
        self.viewId = viewId
        self.viewName = viewName
        self.categoryId = categoryId
        self.pillar = pillar
        self.displayOrder = displayOrder
        self.isActive = isActive
        self.chartTypeId = chartTypeId
        self.defaultTimePeriod = defaultTimePeriod
        self.description = description
        self.aboutContent = aboutContent
        self.longevityImpact = longevityImpact
        self.quickTips = quickTips
        self.infoSections = infoSections
        self.hasGoal = hasGoal
        self.goalConfig = goalConfig
    }
}

// MARK: - Display Cards (Mini metric cards within views, from display_cards table)
// Cards are small metric displays that appear on view pages

struct DisplayCard: Codable, Identifiable, Hashable {
    let id: String
    let cardId: String
    let cardName: String
    let description: String?
    let parentViewId: String
    let displayOrder: Int?
    let cardType: String?
    let miniChartType: String?
    let primaryAggregationId: String?
    let aboutContent: String?
    let longevityImpact: String?
    let quickTips: [String]?
    let canFavorite: Bool?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case cardId = "card_id"
        case cardName = "card_name"
        case description
        case parentViewId = "parent_view_id"
        case displayOrder = "display_order"
        case cardType = "card_type"
        case miniChartType = "mini_chart_type"
        case primaryAggregationId = "primary_aggregation_id"
        case aboutContent = "about_content"
        case longevityImpact = "longevity_impact"
        case quickTips = "quick_tips"
        case canFavorite = "can_favorite"
        case isActive = "is_active"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        cardId = try container.decode(String.self, forKey: .cardId)
        cardName = try container.decode(String.self, forKey: .cardName)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        parentViewId = try container.decode(String.self, forKey: .parentViewId)
        displayOrder = try container.decodeIfPresent(Int.self, forKey: .displayOrder)
        cardType = try container.decodeIfPresent(String.self, forKey: .cardType)
        miniChartType = try container.decodeIfPresent(String.self, forKey: .miniChartType)
        primaryAggregationId = try container.decodeIfPresent(String.self, forKey: .primaryAggregationId)
        aboutContent = try? container.decodeIfPresent(String.self, forKey: .aboutContent)
        longevityImpact = try? container.decodeIfPresent(String.self, forKey: .longevityImpact)
        quickTips = try? container.decodeIfPresent([String].self, forKey: .quickTips)
        canFavorite = try container.decodeIfPresent(Bool.self, forKey: .canFavorite)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DisplayCard, rhs: DisplayCard) -> Bool {
        lhs.id == rhs.id
    }

    init(
        id: String,
        cardId: String,
        cardName: String,
        description: String? = nil,
        parentViewId: String,
        displayOrder: Int? = nil,
        cardType: String? = nil,
        miniChartType: String? = nil,
        primaryAggregationId: String? = nil,
        aboutContent: String? = nil,
        longevityImpact: String? = nil,
        quickTips: [String]? = nil,
        canFavorite: Bool? = nil,
        isActive: Bool? = nil
    ) {
        self.id = id
        self.cardId = cardId
        self.cardName = cardName
        self.description = description
        self.parentViewId = parentViewId
        self.displayOrder = displayOrder
        self.cardType = cardType
        self.miniChartType = miniChartType
        self.primaryAggregationId = primaryAggregationId
        self.aboutContent = aboutContent
        self.longevityImpact = longevityImpact
        self.quickTips = quickTips
        self.canFavorite = canFavorite
        self.isActive = isActive
    }
}

// MARK: - Legacy Models (backward compatibility during migration)
// These query new tables but expose old property names for existing code

/// DisplayScreen queries display_categories table - used by TrackedMetricsViewModel
/// Maps: screenId → category_id, name, overview, pillar, displayOrder, isActive
/// NOTE: Educational fields (title, icon, aboutContent, etc.) always decode as nil
/// from display_categories since that content now lives in display_views/display_cards
struct DisplayScreen: Codable, Identifiable {
    let id: String
    let screenId: String          // Maps to category_id
    let name: String
    let overview: String?
    let pillar: String?
    let displayOrder: Int?
    let isActive: Bool?

    // Legacy fields - not in display_categories, always nil when decoded
    // Kept for backward compatibility with existing views
    let icon: String?
    let title: String?
    let aboutContent: String?
    let longevityImpact: String?
    let quickTips: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case screenId = "category_id"  // Query new column, expose as screenId
        case name
        case overview
        case pillar
        case displayOrder = "display_order"
        case isActive = "is_active"
        // These map to non-existent columns - will decode as nil
        case icon
        case title
        case aboutContent = "about_content"
        case longevityImpact = "longevity_impact"
        case quickTips = "quick_tips"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        screenId = try container.decode(String.self, forKey: .screenId)
        name = try container.decode(String.self, forKey: .name)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        pillar = try container.decodeIfPresent(String.self, forKey: .pillar)
        displayOrder = try container.decodeIfPresent(Int.self, forKey: .displayOrder)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
        // Legacy fields - try to decode but expect nil
        icon = try? container.decodeIfPresent(String.self, forKey: .icon)
        title = try? container.decodeIfPresent(String.self, forKey: .title)
        aboutContent = try? container.decodeIfPresent(String.self, forKey: .aboutContent)
        longevityImpact = try? container.decodeIfPresent(String.self, forKey: .longevityImpact)
        quickTips = try? container.decodeIfPresent([String].self, forKey: .quickTips)
    }

    init(
        id: String,
        screenId: String,
        name: String,
        overview: String? = nil,
        pillar: String? = nil,
        displayOrder: Int? = nil,
        isActive: Bool? = nil,
        icon: String? = nil,
        title: String? = nil,
        aboutContent: String? = nil,
        longevityImpact: String? = nil,
        quickTips: [String]? = nil
    ) {
        self.id = id
        self.screenId = screenId
        self.name = name
        self.overview = overview
        self.pillar = pillar
        self.displayOrder = displayOrder
        self.isActive = isActive
        self.icon = icon
        self.title = title
        self.aboutContent = aboutContent
        self.longevityImpact = longevityImpact
        self.quickTips = quickTips
    }
}

/// DisplayMetric queries display_views table - used by TrackedMetricsViewModel for search
/// Maps: metricId → view_id, metricName → view_name
struct DisplayMetric: Codable, Identifiable, Hashable {
    let id: String
    let metricId: String          // Maps to view_id
    let metricName: String        // Maps to view_name
    let description: String?
    let pillar: String?
    let chartTypeId: String?
    let isActive: Bool?
    let aboutContent: String?
    let longevityImpact: String?
    let quickTips: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case metricId = "view_id"       // Query new column, expose as metricId
        case metricName = "view_name"   // Query new column, expose as metricName
        case description
        case pillar
        case chartTypeId = "chart_type_id"
        case isActive = "is_active"
        case aboutContent = "about_content"
        case longevityImpact = "longevity_impact"
        case quickTips = "quick_tips"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        metricId = try container.decode(String.self, forKey: .metricId)
        metricName = try container.decode(String.self, forKey: .metricName)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        pillar = try container.decodeIfPresent(String.self, forKey: .pillar)
        chartTypeId = try container.decodeIfPresent(String.self, forKey: .chartTypeId)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
        aboutContent = try? container.decodeIfPresent(String.self, forKey: .aboutContent)
        longevityImpact = try? container.decodeIfPresent(String.self, forKey: .longevityImpact)
        quickTips = try? container.decodeIfPresent([String].self, forKey: .quickTips)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DisplayMetric, rhs: DisplayMetric) -> Bool {
        lhs.id == rhs.id
    }

    init(
        id: String,
        metricId: String,
        metricName: String,
        description: String? = nil,
        pillar: String? = nil,
        chartTypeId: String? = nil,
        isActive: Bool? = nil,
        aboutContent: String? = nil,
        longevityImpact: String? = nil,
        quickTips: [String]? = nil
    ) {
        self.id = id
        self.metricId = metricId
        self.metricName = metricName
        self.description = description
        self.pillar = pillar
        self.chartTypeId = chartTypeId
        self.isActive = isActive
        self.aboutContent = aboutContent
        self.longevityImpact = longevityImpact
        self.quickTips = quickTips
    }
}

// LEGACY MODELS REMOVED:
// - PrimaryScreen (table display_screens_primary dropped)
// - DetailScreen (table display_screens_detail dropped)
// - PrimaryMetricLink (table display_screens_primary_display_metrics dropped)
// - DetailMetricLink (table display_screens_detail_display_metrics dropped)
//
// New simplified structure uses:
// - display_screens (with educational content fields)
// - display_screens_display_metrics (links screens to metrics with display_order)

// Parent detail section (tabs in modal)
struct ParentDetailSection: Codable, Identifiable {
    var id: String { sectionId }
    let sectionId: String
    let parentMetricId: String
    let sectionName: String
    let sectionDescription: String?
    let sectionIcon: String?
    let sectionChartTypeId: String
    let displayOrder: Int
    let isDefaultTab: Bool
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case sectionId = "section_id"
        case parentMetricId = "parent_metric_id"
        case sectionName = "section_name"
        case sectionDescription = "section_description"
        case sectionIcon = "section_icon"
        case sectionChartTypeId = "section_chart_type_id"
        case displayOrder = "display_order"
        case isDefaultTab = "is_default_tab"
        case isActive = "is_active"
    }
}

// User's unit preference for a metric
struct UserMetricPreference: Codable {
    let patientId: String
    let displayMetricId: String
    let preferredUnit: String?

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case displayMetricId = "display_metric_id"
        case preferredUnit = "preferred_unit"
    }
}

// Junction table link with extended properties (display_screens_display_metrics)
struct ScreenMetricLink: Codable {
    let screenId: String
    let metricId: String
    let displayOrder: Int?
    let overrideTitle: String?
    let overrideDescription: String?
    let overrideChartType: String?
    let contextLabel: String?

    enum CodingKeys: String, CodingKey {
        case screenId = "screen_id"
        case metricId = "metric_id"
        case displayOrder = "display_order"
        case overrideTitle = "override_title"
        case overrideDescription = "override_description"
        case overrideChartType = "override_chart_type"
        case contextLabel = "context_label"
    }
}

// Helper extension to create Color from hex string
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let length = hexSanitized.count
        let r, g, b, a: Double

        if length == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b, opacity: a)
    }
}
