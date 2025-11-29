//
//  PillarModels.swift
//  WellPath
//
//  Created on 2025-10-22
//

import Foundation
import SwiftUI

struct DisplayScreen: Codable, Identifiable {
    let id: String
    let screenId: String
    let name: String
    let overview: String?
    let pillar: String?
    let icon: String?
    let displayOrder: Int?
    let isActive: Bool?
    let screenType: String?
    let layoutType: String?
    let defaultTimePeriod: String?

    // New educational content fields (migrated from display_screens_primary)
    let title: String?
    let subtitle: String?
    let description: String?
    let aboutContent: String?
    let longevityImpact: String?
    let quickTips: [String]?
    let hasGoal: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case screenId = "screen_id"
        case name
        case overview
        case pillar
        case icon
        case displayOrder = "display_order"
        case isActive = "is_active"
        case screenType = "screen_type"
        case layoutType = "layout_type"
        case defaultTimePeriod = "default_time_period"
        case title
        case subtitle
        case description
        case aboutContent = "about_content"
        case longevityImpact = "longevity_impact"
        case quickTips = "quick_tips"
        case hasGoal = "has_goal"
    }

    // Custom decoder that handles JSONB arrays gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        screenId = try container.decode(String.self, forKey: .screenId)
        name = try container.decode(String.self, forKey: .name)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        pillar = try container.decodeIfPresent(String.self, forKey: .pillar)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        displayOrder = try container.decodeIfPresent(Int.self, forKey: .displayOrder)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
        screenType = try container.decodeIfPresent(String.self, forKey: .screenType)
        layoutType = try container.decodeIfPresent(String.self, forKey: .layoutType)
        defaultTimePeriod = try container.decodeIfPresent(String.self, forKey: .defaultTimePeriod)

        // New educational content fields - fail silently if columns don't exist
        title = try? container.decodeIfPresent(String.self, forKey: .title)
        subtitle = try? container.decodeIfPresent(String.self, forKey: .subtitle)
        description = try? container.decodeIfPresent(String.self, forKey: .description)
        aboutContent = try? container.decodeIfPresent(String.self, forKey: .aboutContent)
        longevityImpact = try? container.decodeIfPresent(String.self, forKey: .longevityImpact)
        quickTips = try? container.decodeIfPresent([String].self, forKey: .quickTips)
        hasGoal = try? container.decodeIfPresent(Bool.self, forKey: .hasGoal)
    }

    // Direct initializer for manual construction (e.g., previews)
    init(
        id: String,
        screenId: String,
        name: String,
        overview: String? = nil,
        pillar: String? = nil,
        icon: String? = nil,
        displayOrder: Int? = nil,
        isActive: Bool? = nil,
        screenType: String? = nil,
        layoutType: String? = nil,
        defaultTimePeriod: String? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        description: String? = nil,
        aboutContent: String? = nil,
        longevityImpact: String? = nil,
        quickTips: [String]? = nil,
        hasGoal: Bool? = nil
    ) {
        self.id = id
        self.screenId = screenId
        self.name = name
        self.overview = overview
        self.pillar = pillar
        self.icon = icon
        self.displayOrder = displayOrder
        self.isActive = isActive
        self.screenType = screenType
        self.layoutType = layoutType
        self.defaultTimePeriod = defaultTimePeriod
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.aboutContent = aboutContent
        self.longevityImpact = longevityImpact
        self.quickTips = quickTips
        self.hasGoal = hasGoal
    }
}

struct DisplayMetric: Codable, Identifiable {
    let id: String              // Supabase row ID
    let metricId: String        // metric_id (business key)
    let metricName: String      // metric_name
    let description: String?    // description
    let screenId: String?       // screen_id (FK to display_screens)
    let pillar: String?         // pillar (FK to pillars_base)
    let chartTypeId: String?    // chart_type_id (FK to chart_types)
    let isActive: Bool?         // is_active
    let createdAt: Date?        // created_at
    let updatedAt: Date?        // updated_at

    // Education content fields
    let aboutContent: String?       // about_content (education)
    let longevityImpact: String?    // longevity_impact (health impact)
    let quickTips: [String]?        // quick_tips (JSONB array)

    enum CodingKeys: String, CodingKey {
        case id
        case metricId = "metric_id"
        case metricName = "metric_name"
        case description
        case screenId = "screen_id"
        case pillar
        case chartTypeId = "chart_type_id"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case aboutContent = "about_content"
        case longevityImpact = "longevity_impact"
        case quickTips = "quick_tips"
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
