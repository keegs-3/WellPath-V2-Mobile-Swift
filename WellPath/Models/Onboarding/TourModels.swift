//
//  TourModels.swift
//  WellPath
//
//  Models for the onboarding tour system
//

import Foundation
import SwiftUI

// MARK: - Tour Screen

struct TourScreen: Identifiable, Codable, Hashable {
    let id: UUID
    let screenId: String
    let pillarName: String
    let tourSection: TourSection
    let displayName: String
    let displayOrder: Int
    let iosViewName: String
    let iconName: String?
    let description: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case screenId = "screen_id"
        case pillarName = "pillar_name"
        case tourSection = "tour_section"
        case displayName = "display_name"
        case displayOrder = "display_order"
        case iosViewName = "ios_view_name"
        case iconName = "icon_name"
        case description
        case isActive = "is_active"
    }

    var icon: String {
        iconName ?? "circle.fill"
    }

    var sectionColor: Color {
        tourSection.color
    }
}

// MARK: - Tour Section

enum TourSection: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    case nutrition
    case movement
    case sleep
    case substances
    case stress
    case cognitive
    case connection
    case healthHistory = "health_history"

    var displayName: String {
        switch self {
        case .nutrition: return "Nutrition"
        case .movement: return "Movement"
        case .sleep: return "Sleep"
        case .substances: return "Substances"
        case .stress: return "Stress & Mental Health"
        case .cognitive: return "Cognitive Health"
        case .connection: return "Connection"
        case .healthHistory: return "Health History"
        }
    }

    var icon: String {
        switch self {
        case .nutrition: return "leaf.fill"
        case .movement: return "figure.run"
        case .sleep: return "moon.fill"
        case .substances: return "pills.fill"
        case .stress: return "brain.head.profile"
        case .cognitive: return "brain"
        case .connection: return "person.2.fill"
        case .healthHistory: return "heart.text.square.fill"
        }
    }

    var color: Color {
        switch self {
        case .nutrition: return .green
        case .movement: return .orange
        case .sleep: return .indigo
        case .substances: return .red
        case .stress: return .purple
        case .cognitive: return .cyan
        case .connection: return .pink
        case .healthHistory: return .blue
        }
    }

    var order: Int {
        switch self {
        case .nutrition: return 0
        case .movement: return 1
        case .sleep: return 2
        case .substances: return 3
        case .stress: return 4
        case .cognitive: return 5
        case .connection: return 6
        case .healthHistory: return 7
        }
    }
}

// MARK: - Tour Question (extends existing SurveyQuestion)

struct TourQuestion: Identifiable, Codable {
    let id: UUID
    let questionNumber: Decimal
    let questionText: String
    let type: String
    let targetScreenId: String?
    let displayOrderInScreen: Int?
    let isRequired: Bool
    let options: [TourQuestionOption]

    enum CodingKeys: String, CodingKey {
        case id
        case questionNumber = "question_number"
        case questionText = "question_text"
        case type
        case targetScreenId = "target_screen_id"
        case displayOrderInScreen = "display_order_in_screen"
        case isRequired = "is_required"
        case options = "survey_response_options"
    }

    var questionType: QuestionType {
        switch type.lowercased().trimmingCharacters(in: .whitespaces) {
        case "single-select": return .singleSelect
        case "multi-select", "multi-select  ": return .multiSelect
        case "multi-select w/ other (free response)": return .multiSelectWithOther
        case "free-response": return .freeResponse
        case "numeric": return .numeric
        case "rank": return .rank
        default: return .singleSelect
        }
    }

    enum QuestionType {
        case singleSelect
        case multiSelect
        case multiSelectWithOther
        case freeResponse
        case numeric
        case rank
    }
}

struct TourQuestionOption: Identifiable, Codable, Hashable {
    let id: UUID
    let optionText: String
    let optionOrder: Int

    enum CodingKeys: String, CodingKey {
        case id = "option_id"
        case optionText = "option_text"
        case optionOrder = "option_order"
    }
}

// MARK: - Tour Response

struct TourResponse {
    let questionId: UUID
    let questionNumber: Decimal
    var selectedOptionIds: Set<UUID> = []
    var freeTextResponse: String?
    var numericResponse: Double?
    var otherText: String?

    var hasResponse: Bool {
        !selectedOptionIds.isEmpty ||
        (freeTextResponse != nil && !freeTextResponse!.isEmpty) ||
        numericResponse != nil
    }
}

// MARK: - Tour Progress

struct TourProgress: Codable {
    var currentSectionIndex: Int = 0
    var currentScreenIndex: Int = 0
    var completedScreenIds: Set<String> = []
    var completedSectionIds: Set<String> = []

    var totalScreensCompleted: Int {
        completedScreenIds.count
    }
}

// MARK: - Patient Baseline

struct PatientBaseline: Codable, Identifiable {
    let id: UUID
    let patientId: UUID
    let metricId: String
    let baselineValue: Double
    let baselineUnit: String?
    let baselineDate: Date
    let source: BaselineSource
    let questionNumber: Decimal?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case metricId = "metric_id"
        case baselineValue = "baseline_value"
        case baselineUnit = "baseline_unit"
        case baselineDate = "baseline_date"
        case source
        case questionNumber = "question_number"
    }
}

enum BaselineSource: String, Codable {
    case survey
    case healthKit = "health_kit"
    case manual
}

enum BaselineComparison {
    case noBaseline
    case atBaseline
    case aboveBaseline(percent: Double)
    case belowBaseline(percent: Double)

    var description: String {
        switch self {
        case .noBaseline: return "No baseline set"
        case .atBaseline: return "At baseline"
        case .aboveBaseline(let percent): return String(format: "%.0f%% above baseline", percent)
        case .belowBaseline(let percent): return String(format: "%.0f%% below baseline", percent)
        }
    }

    var color: Color {
        switch self {
        case .noBaseline: return .secondary
        case .atBaseline: return .green
        case .aboveBaseline: return .blue
        case .belowBaseline: return .orange
        }
    }
}
