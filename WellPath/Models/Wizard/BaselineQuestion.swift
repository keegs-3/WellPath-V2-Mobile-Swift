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
    let questionTextTemplate: String?
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
    let optionsQuestionId: String?  // Links to view_assessment_response_options for checklist questions

    enum CodingKeys: String, CodingKey {
        case id
        case questionId = "question_id"
        case categoryId = "category_id"
        case questionText = "question_text"
        case questionTextTemplate = "question_text_template"
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
        case optionsQuestionId = "options_question_id"
    }

    /// Whether this question uses a multi-select checklist with weighted options
    var isChecklistQuestion: Bool {
        questionType == "multi_select_checklist" && optionsQuestionId != nil
    }

    /// Whether this question uses single-choice radio buttons
    var isSingleChoiceQuestion: Bool {
        questionType == "single_choice" && optionsQuestionId != nil
    }

    /// Returns the question text with unit placeholder replaced
    /// - Parameter unit: The display name of the unit to substitute (e.g., "cups", "mL", "glasses")
    func displayText(withUnit unit: String? = nil) -> String {
        if let template = questionTextTemplate, let unit = unit {
            return template.replacingOccurrences(of: "{unit}", with: unit)
        }
        return questionText
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
