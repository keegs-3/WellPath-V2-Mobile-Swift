//
//  AssessmentModels.swift
//  WellPath
//
//  Database-driven assessment models for questionnaire-based views.
//  Supports Mental Health, Sleep Routine, Sleep Environment, and other assessments.
//

import Foundation
import SwiftUI

// MARK: - Assessment Definition

struct ViewAssessment: Codable, Identifiable {
    let assessmentId: String
    let viewId: String?
    let assessmentName: String
    let assessmentNameFull: String?
    let description: String?
    let questionCount: Int
    let scoreMin: Int
    let scoreMax: Int
    let frequency: String?
    let timeframeText: String?
    let iconName: String?
    let colorHex: String?
    let pillar: String?
    let categoryId: String?

    var id: String { assessmentId }

    enum CodingKeys: String, CodingKey {
        case assessmentId = "assessment_id"
        case viewId = "view_id"
        case assessmentName = "assessment_name"
        case assessmentNameFull = "assessment_name_full"
        case description
        case questionCount = "question_count"
        case scoreMin = "score_min"
        case scoreMax = "score_max"
        case frequency
        case timeframeText = "timeframe_text"
        case iconName = "icon_name"
        case colorHex = "color_hex"
        case pillar
        case categoryId = "category_id"
    }

    var scoreRange: ClosedRange<Int> {
        scoreMin...scoreMax
    }

    var color: Color {
        guard let hex = colorHex else { return .blue }
        return Color(hex: hex) ?? .blue
    }

    var icon: String {
        iconName ?? "questionmark.circle.fill"
    }

    var isRecurring: Bool {
        frequency == "daily" || frequency == "weekly"
    }
}

// MARK: - Assessment Question

struct ViewAssessmentQuestion: Codable, Identifiable {
    let questionId: String
    let assessmentId: String
    let questionText: String
    let questionSubtext: String?
    let questionOrder: Int
    let responseType: String?

    var id: String { questionId }

    enum CodingKeys: String, CodingKey {
        case questionId = "question_id"
        case assessmentId = "assessment_id"
        case questionText = "question_text"
        case questionSubtext = "question_subtext"
        case questionOrder = "question_order"
        case responseType = "response_type"
    }
}

// MARK: - Response Option

struct ViewAssessmentResponseOption: Codable, Identifiable {
    let questionId: String
    let optionValue: Int
    let optionText: String
    let displayOrder: Int

    var id: String { "\(questionId)_\(displayOrder)" }

    enum CodingKeys: String, CodingKey {
        case questionId = "question_id"
        case optionValue = "option_value"
        case optionText = "option_text"
        case displayOrder = "display_order"
    }
}

// MARK: - Assessment Tier

struct ViewAssessmentTier: Codable, Identifiable {
    let assessmentId: String
    let tierName: String
    let tierKey: String
    let scoreMin: Int
    let scoreMax: Int
    let tierOrder: Int
    let colorHex: String?
    let tierDescription: String?
    let recommendation: String?

    var id: String { "\(assessmentId)_\(tierKey)" }

    enum CodingKeys: String, CodingKey {
        case assessmentId = "assessment_id"
        case tierName = "tier_name"
        case tierKey = "tier_key"
        case scoreMin = "score_min"
        case scoreMax = "score_max"
        case tierOrder = "tier_order"
        case colorHex = "color_hex"
        case tierDescription = "description"
        case recommendation
    }

    var color: Color {
        guard let hex = colorHex else { return .gray }
        return Color(hex: hex) ?? .gray
    }
}

// MARK: - Complete Assessment Data (for UI)

struct AssessmentData {
    let assessment: ViewAssessment
    let questions: [ViewAssessmentQuestion]
    let responseOptions: [String: [ViewAssessmentResponseOption]] // questionId -> options
    let tiers: [ViewAssessmentTier]

    func options(for questionId: String) -> [ViewAssessmentResponseOption] {
        responseOptions[questionId]?.sorted { $0.displayOrder < $1.displayOrder } ?? []
    }

    func tier(for score: Int) -> ViewAssessmentTier? {
        tiers.first { score >= $0.scoreMin && score <= $0.scoreMax }
    }

    func interpretation(for score: Int) -> String {
        tier(for: score)?.tierName ?? "Unknown"
    }

    func interpretationDescription(for score: Int) -> String? {
        tier(for: score)?.tierDescription
    }

    func recommendation(for score: Int) -> String? {
        tier(for: score)?.recommendation
    }

    func scoreProgress(for score: Int) -> Double {
        let range = Double(assessment.scoreMax - assessment.scoreMin)
        guard range > 0 else { return 0 }
        let value = Double(score - assessment.scoreMin)
        return value / range
    }
}

// MARK: - Assessment Result (for history display)

struct AssessmentResult: Identifiable {
    let id: UUID  // Maps to sample_id in patient_quantity_samples
    let date: Date
    let score: Int
    let tierName: String?
    let tierColor: Color?
    let responses: [String: Int]?  // questionId -> selected value(s)
}

// MARK: - Time Period Enum

enum AssessmentTimePeriod: String, CaseIterable {
    case daily = "D"
    case weekly = "W"
    case monthly = "M"
    case sixMonth = "6M"
    case yearly = "Y"

    var shortLabel: String { rawValue }
}

// Note: Color.init(hex:) extension is defined in PillarModels.swift
