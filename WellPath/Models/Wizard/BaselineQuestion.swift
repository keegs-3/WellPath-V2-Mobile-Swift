//
//  BaselineQuestion.swift
//  WellPath
//
//  Model for baseline questions loaded from baseline_questions table.
//

import Foundation

struct BaselineQuestion: Identifiable, Codable {
    let id: UUID
    let questionId: String
    let categoryId: String?
    let questionText: String
    let questionSubtext: String?
    let baselineType: String?
    let quantityType: String?
    let categoryTypeReference: String?
    let unitLabel: String
    let unitId: String?
    let questionType: String?
    let placeholder: String?
    let minValue: Double?
    let maxValue: Double?
    let stepValue: Double?
    let displayOrder: Int
    let isRequired: Bool
    let isActive: Bool
    let baselineSubpageId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case questionId = "question_id"
        case categoryId = "category_id"
        case questionText = "question_text"
        case questionSubtext = "question_subtext"
        case baselineType = "baseline_type"
        case quantityType = "quantity_type"
        case categoryTypeReference = "category_type_reference"
        case unitLabel = "unit_label"
        case unitId = "unit_id"
        case questionType = "question_type"
        case placeholder
        case minValue = "min_value"
        case maxValue = "max_value"
        case stepValue = "step_value"
        case displayOrder = "display_order"
        case isRequired = "is_required"
        case isActive = "is_active"
        case baselineSubpageId = "baseline_subpage_id"
    }
}

/// Tracks user's response to a baseline question
struct BaselineResponse {
    let questionId: String
    let baselineType: String
    var value: Double?

    var hasValue: Bool {
        value != nil
    }
}

/// Category with its questions for the wizard
struct WizardCategory: Identifiable {
    let id: String  // category_id like "CAT_PROTEIN"
    let displayName: String
    let pillar: String
    let iconName: String
    let color: String
    var questions: [BaselineQuestion]
    var isComplete: Bool

    var questionCount: Int { questions.count }
}
