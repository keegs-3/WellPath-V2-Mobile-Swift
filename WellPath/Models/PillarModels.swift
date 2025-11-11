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

// Primary screen configuration
struct PrimaryScreen: Codable, Identifiable {
    let id: String                      // Supabase row ID
    let primaryScreenId: String         // primary_screen_id (business key)
    let displayScreenId: String         // display_screen_id (FK to display_screens)
    let title: String?                  // title
    let subtitle: String?               // subtitle
    let description: String?            // description
    let displayOrder: Int?              // display_order
    let layoutType: String?             // layout_type
    let hasDetailScreen: Bool?          // has_detail_screen
    let detailButtonText: String?       // detail_button_text
    let detailButtonIcon: String?       // detail_button_icon
    let educationContentId: String?     // education_content_id
    let hasGoal: Bool?                  // has_goal
    let isActive: Bool?                 // is_active
    let createdAt: Date?                // created_at
    let updatedAt: Date?                // updated_at

    // Education content fields
    let aboutContent: String?           // about_content
    let longevityImpact: String?        // longevity_impact
    let quickTips: [String]?            // quick_tips (JSONB array)

    enum CodingKeys: String, CodingKey {
        case id
        case primaryScreenId = "primary_screen_id"
        case displayScreenId = "display_screen_id"
        case title
        case subtitle
        case description
        case displayOrder = "display_order"
        case layoutType = "layout_type"
        case hasDetailScreen = "has_detail_screen"
        case detailButtonText = "detail_button_text"
        case detailButtonIcon = "detail_button_icon"
        case educationContentId = "education_content_id"
        case hasGoal = "has_goal"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case aboutContent = "about_content"
        case longevityImpact = "longevity_impact"
        case quickTips = "quick_tips"
    }

    // Custom decoder that handles JSONB arrays
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        primaryScreenId = try container.decode(String.self, forKey: .primaryScreenId)
        displayScreenId = try container.decode(String.self, forKey: .displayScreenId)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        displayOrder = try container.decodeIfPresent(Int.self, forKey: .displayOrder)
        layoutType = try container.decodeIfPresent(String.self, forKey: .layoutType)
        hasDetailScreen = try container.decodeIfPresent(Bool.self, forKey: .hasDetailScreen)
        detailButtonText = try container.decodeIfPresent(String.self, forKey: .detailButtonText)
        detailButtonIcon = try container.decodeIfPresent(String.self, forKey: .detailButtonIcon)
        educationContentId = try container.decodeIfPresent(String.self, forKey: .educationContentId)
        hasGoal = try container.decodeIfPresent(Bool.self, forKey: .hasGoal)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
        createdAt = try? container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try? container.decodeIfPresent(Date.self, forKey: .updatedAt)

        // Education content - fail silently if columns don't exist
        aboutContent = try? container.decodeIfPresent(String.self, forKey: .aboutContent)
        longevityImpact = try? container.decodeIfPresent(String.self, forKey: .longevityImpact)
        quickTips = try? container.decodeIfPresent([String].self, forKey: .quickTips)

        print("✅ Decoded PrimaryScreen: about=\(aboutContent != nil), longevity=\(longevityImpact != nil), tips=\(quickTips != nil)")
    }
}

// Detail screen configuration
struct DetailScreen: Codable, Identifiable {
    let id: String                      // Supabase row ID
    let detailScreenId: String          // detail_screen_id (business key)
    let displayScreenId: String         // display_screen_id (FK to display_screens)
    let title: String?                  // title
    let subtitle: String?               // subtitle
    let description: String?            // description
    let layoutType: String?             // layout_type
    let educationContentId: String?     // education_content_id
    let showInsights: Bool?             // show_insights
    let isActive: Bool?                 // is_active
    let createdAt: Date?                // created_at
    let updatedAt: Date?                // updated_at

    // JSONB fields - skipped for now as they're arrays/objects
    // let sectionConfig: [String: Any]?
    // let tabConfig: [String: Any]?
    // let detailedInfo: [String: Any]?
    // let faq: [Any]?
    // let relatedArticles: [Any]?
    // let insightsConfig: [String: Any]?
    // let metadata: [String: Any]?

    enum CodingKeys: String, CodingKey {
        case id
        case detailScreenId = "detail_screen_id"
        case displayScreenId = "display_screen_id"
        case title
        case subtitle
        case description
        case layoutType = "layout_type"
        case educationContentId = "education_content_id"
        case showInsights = "show_insights"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        // JSONB fields not included in CodingKeys - will be ignored during decoding
    }
}

// Junction table: Primary Screen → Display Metric
struct PrimaryMetricLink: Codable, Identifiable {
    let id: String                      // Supabase row ID
    let primaryScreenId: String         // primary_screen_id (FK)
    let metricId: String                // metric_id (FK to display_metrics)
    let displayOrder: Int?              // display_order
    let isFeatured: Bool?               // is_featured
    let isComparison: Bool?             // is_comparison
    let overrideTitle: String?          // override_title
    let overrideDescription: String?    // override_description
    let overrideChartType: String?      // override_chart_type
    let contextLabel: String?           // context_label
    let contextDescription: String?     // context_description
    let createdAt: Date?                // created_at
    let updatedAt: Date?                // updated_at
    // metadata is JSONB - skipped

    enum CodingKeys: String, CodingKey {
        case id
        case primaryScreenId = "primary_screen_id"
        case metricId = "metric_id"
        case displayOrder = "display_order"
        case isFeatured = "is_featured"
        case isComparison = "is_comparison"
        case overrideTitle = "override_title"
        case overrideDescription = "override_description"
        case overrideChartType = "override_chart_type"
        case contextLabel = "context_label"
        case contextDescription = "context_description"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        // metadata NOT included - it's JSONB
    }
}

// Junction table: Detail Screen → Display Metric
struct DetailMetricLink: Codable, Identifiable {
    let id: String                      // Supabase row ID
    let detailScreenId: String          // detail_screen_id (FK)
    let metricId: String                // metric_id (FK to display_metrics)
    let displayOrder: Int?              // display_order
    let isFeatured: Bool?               // is_featured
    let isComparison: Bool?             // is_comparison
    let overrideDescription: String?    // override_description
    let overrideChartType: String?      // override_chart_type
    let contextLabel: String?           // context_label
    let contextDescription: String?     // context_description
    let metadata: String?               // metadata (JSONB)

    enum CodingKeys: String, CodingKey {
        case id
        case detailScreenId = "detail_screen_id"
        case metricId = "metric_id"
        case displayOrder = "display_order"
        case isFeatured = "is_featured"
        case isComparison = "is_comparison"
        case overrideDescription = "override_description"
        case overrideChartType = "override_chart_type"
        case contextLabel = "context_label"
        case contextDescription = "context_description"
        case metadata
    }
}

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

// Junction table link with extended properties
struct ScreenMetricLink: Codable {
    let primaryScreenId: String
    let metricId: String
    let displayOrder: Int?

    enum CodingKeys: String, CodingKey {
        case primaryScreenId = "primary_screen_id"
        case metricId = "metric_id"
        case displayOrder = "display_order"
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
