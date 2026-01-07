//
//  BehavioralScoreDisplay.swift
//  WellPath
//
//  Display configuration models for behavioral scores.
//  Loaded from display_behavioral_scores and display_behavioral_score_components tables.
//

import Foundation

// MARK: - Score Display Configuration

struct BehavioralScoreDisplay: Codable, Identifiable {
    let id: UUID
    let scoreId: String
    let scoreType: String
    let displayName: String
    let displayNameShort: String?
    let description: String?
    let iconName: String?
    let pillar: String?
    let categoryId: String?

    // Threshold config
    let thresholdDaysRequired: Int
    let thresholdWindowDays: Int
    let thresholdExplanation: String?

    // Scoring
    let scoringExplanation: String?
    let optimalRangeText: String?

    // UI
    let colorHex: String?
    let displayOrder: Int
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case scoreId = "score_id"
        case scoreType = "score_type"
        case displayName = "display_name"
        case displayNameShort = "display_name_short"
        case description
        case iconName = "icon_name"
        case pillar
        case categoryId = "category_id"
        case thresholdDaysRequired = "threshold_days_required"
        case thresholdWindowDays = "threshold_window_days"
        case thresholdExplanation = "threshold_explanation"
        case scoringExplanation = "scoring_explanation"
        case optimalRangeText = "optimal_range_text"
        case colorHex = "color_hex"
        case displayOrder = "display_order"
        case isActive = "is_active"
    }
}

// MARK: - Score Component Configuration
// Now loaded from scoring_component_weights table (consolidated from display_behavioral_score_components)

struct BehavioralScoreComponent: Codable, Identifiable {
    let id: UUID
    let outputScoreType: String    // The composite score (e.g., "hydration_score")
    let componentScoreType: String // The component score (e.g., "hydration_amount_score")
    let weight: Double
    let displayName: String?
    let description: String?
    let iconName: String?
    let optimalRangeText: String?
    let displayOrder: Int
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case outputScoreType = "output_score_type"
        case componentScoreType = "component_score_type"
        case weight
        case displayName = "display_name"
        case description
        case iconName = "icon_name"
        case optimalRangeText = "optimal_range_text"
        case displayOrder = "display_order"
        case isActive = "is_active"
    }

    // Convenience aliases for backwards compatibility
    var scoreId: String { outputScoreType }
    var componentId: String { componentScoreType }
    var componentType: String { componentScoreType }

    /// Weight as percentage string (e.g., "80%")
    var weightPercentage: String {
        "\(Int(weight * 100))%"
    }
}
