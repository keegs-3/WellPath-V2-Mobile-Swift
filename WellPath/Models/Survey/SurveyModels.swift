//
//  SurveyModels.swift
//  WellPath
//
//  Created on 2025-11-27
//

import Foundation

// MARK: - Helper for decoding question_number (comes as number from DB)

extension KeyedDecodingContainer {
    func decodeQuestionNumber(forKey key: Key) throws -> String {
        // Try decoding as String first
        if let stringValue = try? decode(String.self, forKey: key) {
            return stringValue
        }
        // Try as Double (numeric type from DB)
        if let doubleValue = try? decode(Double.self, forKey: key) {
            // Format to preserve decimal places like "4.12"
            if doubleValue.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f", doubleValue)
            } else {
                return String(doubleValue)
            }
        }
        // Try as Int
        if let intValue = try? decode(Int.self, forKey: key) {
            return String(intValue)
        }
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(
            codingPath: codingPath + [key],
            debugDescription: "Expected String or Number for question_number"
        ))
    }
}

// MARK: - Survey Section (Pillar-level grouping)

struct SurveySection: Identifiable, Codable, Hashable {
    let id: UUID
    let sectionId: String
    let pillar: String?
    let displayName: String
    let sectionOrder: Int
    let description: String?

    // Hierarchical data
    var categories: [SurveyCategory] = []

    // Progress tracking
    var questionCount: Int = 0
    var answeredCount: Int = 0

    var completedCategoryCount: Int {
        categories.filter { $0.isComplete }.count
    }

    var completionPercentage: Double {
        guard questionCount > 0 else { return 0 }
        return Double(answeredCount) / Double(questionCount)
    }

    var isComplete: Bool {
        questionCount > 0 && answeredCount >= questionCount
    }

    var estimatedMinutes: Int {
        // ~15 seconds per question
        max(1, questionCount / 4)
    }

    var iconName: String {
        switch sectionId {
        case "introduction": return "hand.wave.fill"
        case "healthful_nutrition": return "leaf.fill"
        case "movement_exercise": return "figure.run"
        case "restorative_sleep": return "moon.zzz.fill"
        case "cognitive_health": return "brain.head.profile"
        case "stress_management": return "heart.circle.fill"
        case "connection_purpose": return "person.2.fill"
        case "core_care": return "cross.case.fill"
        default: return "questionmark.circle.fill"
        }
    }

    var themeColor: String {
        switch sectionId {
        case "introduction": return "blue"
        case "healthful_nutrition": return "green"
        case "movement_exercise": return "orange"
        case "restorative_sleep": return "indigo"
        case "cognitive_health": return "purple"
        case "stress_management": return "pink"
        case "connection_purpose": return "teal"
        case "core_care": return "red"
        default: return "gray"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case sectionId = "section_id"
        case pillar
        case displayName = "display_name"
        case sectionOrder = "section_order"
        case description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sectionId = try container.decode(String.self, forKey: .sectionId)
        pillar = try container.decodeIfPresent(String.self, forKey: .pillar)
        displayName = try container.decode(String.self, forKey: .displayName)
        sectionOrder = try container.decode(Int.self, forKey: .sectionOrder)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        // Initialize non-decoded properties
        categories = []
        questionCount = 0
        answeredCount = 0
    }

    init(id: UUID, sectionId: String, pillar: String?, displayName: String, sectionOrder: Int, description: String? = nil, categories: [SurveyCategory] = [], questionCount: Int = 0, answeredCount: Int = 0) {
        self.id = id
        self.sectionId = sectionId
        self.pillar = pillar
        self.displayName = displayName
        self.sectionOrder = sectionOrder
        self.description = description
        self.categories = categories
        self.questionCount = questionCount
        self.answeredCount = answeredCount
    }
}

// MARK: - Survey Category (within a section)

struct SurveyCategory: Identifiable, Codable, Hashable {
    let id: UUID
    let categoryId: String
    let sectionId: String
    let displayName: String
    let description: String?
    let categoryOrder: Int
    let sectionOrder: Int

    // Computed from groups/questions
    var groups: [SurveyGroup] = []
    var completedGroupCount: Int = 0

    var isComplete: Bool {
        groups.count > 0 && completedGroupCount >= groups.count
    }

    var completionPercentage: Double {
        guard groups.count > 0 else { return 0 }
        return Double(completedGroupCount) / Double(groups.count)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case categoryId = "category_id"
        case sectionId = "section_id"
        case displayName = "display_name"
        case description
        case categoryOrder = "category_order"
        case sectionOrder = "section_order"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        categoryId = try container.decode(String.self, forKey: .categoryId)
        sectionId = try container.decode(String.self, forKey: .sectionId)
        displayName = try container.decode(String.self, forKey: .displayName)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        categoryOrder = try container.decode(Int.self, forKey: .categoryOrder)
        sectionOrder = try container.decode(Int.self, forKey: .sectionOrder)
        // Initialize non-decoded properties
        groups = []
        completedGroupCount = 0
    }

    init(id: UUID, categoryId: String, sectionId: String, displayName: String, description: String?, categoryOrder: Int, sectionOrder: Int, groups: [SurveyGroup] = [], completedGroupCount: Int = 0) {
        self.id = id
        self.categoryId = categoryId
        self.sectionId = sectionId
        self.displayName = displayName
        self.description = description
        self.categoryOrder = categoryOrder
        self.sectionOrder = sectionOrder
        self.groups = groups
        self.completedGroupCount = completedGroupCount
    }
}

// MARK: - Survey Group (within a category)

struct SurveyGroup: Identifiable, Codable, Hashable {
    let id: UUID
    let groupId: String
    let categoryId: String
    let sectionId: String
    let displayName: String
    let description: String?
    let groupOrder: Int
    let categoryOrder: Int
    let sectionOrder: Int

    // Computed from questions
    var questionCount: Int = 0
    var answeredCount: Int = 0

    var isComplete: Bool {
        questionCount > 0 && answeredCount >= questionCount
    }

    var completionPercentage: Double {
        guard questionCount > 0 else { return 0 }
        return Double(answeredCount) / Double(questionCount)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case categoryId = "category_id"
        case sectionId = "section_id"
        case displayName = "display_name"
        case description
        case groupOrder = "group_order"
        case categoryOrder = "category_order"
        case sectionOrder = "section_order"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        groupId = try container.decode(String.self, forKey: .groupId)
        categoryId = try container.decode(String.self, forKey: .categoryId)
        sectionId = try container.decode(String.self, forKey: .sectionId)
        displayName = try container.decode(String.self, forKey: .displayName)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        groupOrder = try container.decode(Int.self, forKey: .groupOrder)
        categoryOrder = try container.decode(Int.self, forKey: .categoryOrder)
        sectionOrder = try container.decode(Int.self, forKey: .sectionOrder)
        // Initialize non-decoded properties
        questionCount = 0
        answeredCount = 0
    }

    init(id: UUID, groupId: String, categoryId: String, sectionId: String, displayName: String, description: String?, groupOrder: Int, categoryOrder: Int, sectionOrder: Int, questionCount: Int = 0, answeredCount: Int = 0) {
        self.id = id
        self.groupId = groupId
        self.categoryId = categoryId
        self.sectionId = sectionId
        self.displayName = displayName
        self.description = description
        self.groupOrder = groupOrder
        self.categoryOrder = categoryOrder
        self.sectionOrder = sectionOrder
        self.questionCount = questionCount
        self.answeredCount = answeredCount
    }
}

// MARK: - Survey Question

enum SurveyQuestionType: String, Codable {
    case singleSelect = "single-select"
    case multiSelect = "multi-select"
    case multiSelectTrimmed = "multi-select  " // Database has trailing spaces
    case rank = "rank"
    case freeResponse = "free-response"
    case numeric = "numeric"
    case date = "date"

    var displayName: String {
        switch self {
        case .singleSelect: return "Single Choice"
        case .multiSelect, .multiSelectTrimmed: return "Multiple Choice"
        case .rank: return "Rank Order"
        case .freeResponse: return "Text Response"
        case .numeric: return "Number"
        case .date: return "Date"
        }
    }

    var allowsMultipleSelections: Bool {
        switch self {
        case .multiSelect, .multiSelectTrimmed, .rank:
            return true
        default:
            return false
        }
    }
}

struct SurveyQuestion: Identifiable, Codable, Hashable {
    let id: UUID
    let questionNumber: String
    let questionText: String
    let type: SurveyQuestionType
    let categoryId: String
    let sectionId: String
    let groupId: String?
    let categoryOrder: Int
    let sectionOrder: Int
    let groupOrder: Int?
    let groupQuestionOrder: Int
    let gender: String
    let conditionalNote: String?
    let preFill: Bool
    let isActive: Bool

    var options: [SurveyResponseOption] = []
    var currentResponse: PatientSurveyResponse? = nil

    var isAnswered: Bool {
        currentResponse != nil
    }

    var cleanedQuestionText: String {
        questionText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case questionNumber = "question_number"
        case questionText = "question_text"
        case type
        case categoryId = "category_id"
        case sectionId = "section_id"
        case groupId = "group_id"
        case categoryOrder = "category_order"
        case sectionOrder = "section_order"
        case groupOrder = "group_order"
        case groupQuestionOrder = "group_question_order"
        case gender
        case conditionalNote = "conditional_note"
        case preFill = "pre_fill"
        case isActive = "is_active"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        questionNumber = try container.decodeQuestionNumber(forKey: .questionNumber)
        questionText = try container.decode(String.self, forKey: .questionText)
        type = try container.decode(SurveyQuestionType.self, forKey: .type)
        categoryId = try container.decode(String.self, forKey: .categoryId)
        sectionId = try container.decode(String.self, forKey: .sectionId)
        groupId = try container.decodeIfPresent(String.self, forKey: .groupId)
        categoryOrder = try container.decode(Int.self, forKey: .categoryOrder)
        sectionOrder = try container.decode(Int.self, forKey: .sectionOrder)
        groupOrder = try container.decodeIfPresent(Int.self, forKey: .groupOrder)
        groupQuestionOrder = try container.decode(Int.self, forKey: .groupQuestionOrder)
        gender = try container.decode(String.self, forKey: .gender)
        conditionalNote = try container.decodeIfPresent(String.self, forKey: .conditionalNote)
        preFill = try container.decodeIfPresent(Bool.self, forKey: .preFill) ?? false
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        // Initialize non-decoded properties
        options = []
        currentResponse = nil
    }

    init(id: UUID, questionNumber: String, questionText: String, type: SurveyQuestionType, categoryId: String, sectionId: String, groupId: String?, categoryOrder: Int, sectionOrder: Int, groupOrder: Int?, groupQuestionOrder: Int, gender: String, conditionalNote: String? = nil, preFill: Bool = false, isActive: Bool = true, options: [SurveyResponseOption] = [], currentResponse: PatientSurveyResponse? = nil) {
        self.id = id
        self.questionNumber = questionNumber
        self.questionText = questionText
        self.type = type
        self.categoryId = categoryId
        self.sectionId = sectionId
        self.groupId = groupId
        self.categoryOrder = categoryOrder
        self.sectionOrder = sectionOrder
        self.groupOrder = groupOrder
        self.groupQuestionOrder = groupQuestionOrder
        self.gender = gender
        self.conditionalNote = conditionalNote
        self.preFill = preFill
        self.isActive = isActive
        self.options = options
        self.currentResponse = currentResponse
    }
}

// MARK: - Survey Response Option

struct SurveyResponseOption: Identifiable, Codable, Hashable {
    let id: UUID
    let questionNumber: String
    let optionId: String
    let optionText: String
    let score: Double
    let questionResponseOrder: Int
    let categoryId: String
    let sectionId: String
    let isActive: Bool

    var cleanedOptionText: String {
        optionText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case questionNumber = "question_number"
        case optionId = "option_id"
        case optionText = "option_text"
        case score
        case questionResponseOrder = "question_response_order"
        case categoryId = "category_id"
        case sectionId = "section_id"
        case isActive = "is_active"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        questionNumber = try container.decodeQuestionNumber(forKey: .questionNumber)
        optionId = try container.decode(String.self, forKey: .optionId)
        optionText = try container.decode(String.self, forKey: .optionText)
        // Score might come as string or number
        if let scoreString = try? container.decode(String.self, forKey: .score) {
            score = Double(scoreString) ?? 0
        } else {
            score = try container.decodeIfPresent(Double.self, forKey: .score) ?? 0
        }
        questionResponseOrder = try container.decode(Int.self, forKey: .questionResponseOrder)
        categoryId = try container.decode(String.self, forKey: .categoryId)
        sectionId = try container.decode(String.self, forKey: .sectionId)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
    }

    init(id: UUID, questionNumber: String, optionId: String, optionText: String, score: Double, questionResponseOrder: Int, categoryId: String, sectionId: String, isActive: Bool = true) {
        self.id = id
        self.questionNumber = questionNumber
        self.optionId = optionId
        self.optionText = optionText
        self.score = score
        self.questionResponseOrder = questionResponseOrder
        self.categoryId = categoryId
        self.sectionId = sectionId
        self.isActive = isActive
    }
}

// MARK: - Patient Survey Response

struct PatientSurveyResponse: Identifiable, Codable, Hashable {
    let id: UUID
    let patientId: UUID
    let questionNumber: String
    let responseOptionId: UUID?
    let responseText: String?
    let responseValue: Double?
    let completedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case questionNumber = "question_number"
        case responseOptionId = "response_option_id"
        case responseText = "response_text"
        case responseValue = "response_value"
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        patientId = try container.decode(UUID.self, forKey: .patientId)
        questionNumber = try container.decodeQuestionNumber(forKey: .questionNumber)
        responseOptionId = try container.decodeIfPresent(UUID.self, forKey: .responseOptionId)
        responseText = try container.decodeIfPresent(String.self, forKey: .responseText)
        responseValue = try container.decodeIfPresent(Double.self, forKey: .responseValue)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

// MARK: - Survey Mode

enum SurveyMode {
    case onboarding  // < 80% complete, show wizard
    case management  // >= 80% complete, show carousel

    static func determine(answeredCount: Int, totalQuestions: Int) -> SurveyMode {
        guard totalQuestions > 0 else { return .onboarding }
        let completionRate = Double(answeredCount) / Double(totalQuestions)
        return completionRate >= 0.8 ? .management : .onboarding
    }
}

// MARK: - Survey Progress

struct SurveyProgress {
    let totalQuestions: Int
    let answeredQuestions: Int
    let sectionProgress: [String: SectionProgress]

    var completionPercentage: Double {
        guard totalQuestions > 0 else { return 0 }
        return Double(answeredQuestions) / Double(totalQuestions)
    }

    var isComplete: Bool {
        answeredQuestions >= totalQuestions
    }

    var mode: SurveyMode {
        SurveyMode.determine(answeredCount: answeredQuestions, totalQuestions: totalQuestions)
    }

    struct SectionProgress {
        let sectionId: String
        let totalQuestions: Int
        let answeredQuestions: Int

        var completionPercentage: Double {
            guard totalQuestions > 0 else { return 0 }
            return Double(answeredQuestions) / Double(totalQuestions)
        }

        var isComplete: Bool {
            answeredQuestions >= totalQuestions
        }
    }
}

// MARK: - Question Counts Response (for initial loading)

struct SectionQuestionCount: Codable {
    let sectionId: String
    let questionCount: Int

    enum CodingKeys: String, CodingKey {
        case sectionId = "section_id"
        case questionCount = "question_count"
    }
}

// MARK: - Survey Question Condition

enum SurveyConditionType: String, Codable {
    case optionsFromSelected = "options_from_selected"
    case optionsFromNotSelected = "options_from_not_selected"
    case showIf = "show_if"
}

struct SurveyQuestionCondition: Identifiable, Codable {
    let id: UUID
    let questionNumber: String
    let conditionType: SurveyConditionType
    let sourceQuestionNumber: String
    let sourceResponseOptionIds: [String]?
    let notes: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case questionNumber = "question_number"
        case conditionType = "condition_type"
        case sourceQuestionNumber = "source_question_number"
        case sourceResponseOptionIds = "source_response_option_ids"
        case notes
        case isActive = "is_active"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        questionNumber = try container.decodeQuestionNumber(forKey: .questionNumber)
        conditionType = try container.decode(SurveyConditionType.self, forKey: .conditionType)
        sourceQuestionNumber = try container.decodeQuestionNumber(forKey: .sourceQuestionNumber)
        sourceResponseOptionIds = try container.decodeIfPresent([String].self, forKey: .sourceResponseOptionIds)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
    }
}

// MARK: - Survey Lifecycle Phase

/// Tracks the survey state through the plan lifecycle
enum SurveyLifecyclePhase: String, Codable {
    case onboarding = "onboarding"       // Initial survey completion - freely editable
    case activePlan = "active_plan"      // Plan running - survey locked to user edits
    case reassessment = "reassessment"   // Plan ended - survey unlocked for review

    var isEditable: Bool {
        self != .activePlan
    }

    var displayName: String {
        switch self {
        case .onboarding: return "Building Profile"
        case .activePlan: return "Plan Active"
        case .reassessment: return "Reassessment"
        }
    }
}

// MARK: - Patient Survey State

/// Tracks the survey lifecycle state for a patient
struct PatientSurveyState: Codable {
    let patientId: UUID
    let lifecyclePhase: SurveyLifecyclePhase
    let planStartedAt: Date?
    let planEndsAt: Date?
    let lastReassessmentAt: Date?
    let createdAt: Date
    let updatedAt: Date

    var isEditable: Bool {
        lifecyclePhase.isEditable
    }

    var daysUntilUnlock: Int? {
        guard lifecyclePhase == .activePlan, let endDate = planEndsAt else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: endDate).day
        return max(0, days ?? 0)
    }

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case lifecyclePhase = "lifecycle_phase"
        case planStartedAt = "plan_started_at"
        case planEndsAt = "plan_ends_at"
        case lastReassessmentAt = "last_reassessment_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Survey Response History

/// Audit trail entry for a survey response change
struct SurveyResponseHistory: Identifiable, Codable {
    let id: UUID
    let patientId: UUID
    let questionNumber: String
    let responseOptionId: UUID?
    let responseText: String?
    let responseValue: Double?
    let changeType: String      // created, updated, deleted, cascade_deleted
    let changeSource: String    // user, tracked_data, system, cascade
    let sourceMetricId: String?
    let sourceQuestionNumber: String?
    let previousResponseText: String?
    let previousResponseValue: Double?
    let changedAt: Date
    let changedBy: UUID?

    var changeTypeDisplay: String {
        switch changeType {
        case "created": return "Created"
        case "updated": return "Updated"
        case "deleted": return "Deleted"
        case "cascade_deleted": return "Auto-cleared"
        default: return changeType.capitalized
        }
    }

    var changeSourceDisplay: String {
        switch changeSource {
        case "user": return "You"
        case "tracked_data": return "Tracked Data"
        case "system": return "System"
        case "cascade": return "Dependent Update"
        default: return changeSource.capitalized
        }
    }

    var iconName: String {
        switch changeType {
        case "created": return "plus.circle.fill"
        case "updated": return "pencil.circle.fill"
        case "deleted": return "minus.circle.fill"
        case "cascade_deleted": return "arrow.triangle.2.circlepath"
        default: return "questionmark.circle"
        }
    }

    var iconColor: String {
        switch changeType {
        case "created": return "green"
        case "updated": return "blue"
        case "deleted", "cascade_deleted": return "orange"
        default: return "gray"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case questionNumber = "question_number"
        case responseOptionId = "response_option_id"
        case responseText = "response_text"
        case responseValue = "response_value"
        case changeType = "change_type"
        case changeSource = "change_source"
        case sourceMetricId = "source_metric_id"
        case sourceQuestionNumber = "source_question_number"
        case previousResponseText = "previous_response_text"
        case previousResponseValue = "previous_response_value"
        case changedAt = "changed_at"
        case changedBy = "changed_by"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        patientId = try container.decode(UUID.self, forKey: .patientId)
        questionNumber = try container.decodeQuestionNumber(forKey: .questionNumber)
        responseOptionId = try container.decodeIfPresent(UUID.self, forKey: .responseOptionId)
        responseText = try container.decodeIfPresent(String.self, forKey: .responseText)
        responseValue = try container.decodeIfPresent(Double.self, forKey: .responseValue)
        changeType = try container.decode(String.self, forKey: .changeType)
        changeSource = try container.decode(String.self, forKey: .changeSource)
        sourceMetricId = try container.decodeIfPresent(String.self, forKey: .sourceMetricId)
        sourceQuestionNumber = try container.decodeIfPresent(String.self, forKey: .sourceQuestionNumber)
        previousResponseText = try container.decodeIfPresent(String.self, forKey: .previousResponseText)
        previousResponseValue = try container.decodeIfPresent(Double.self, forKey: .previousResponseValue)
        changedAt = try container.decode(Date.self, forKey: .changedAt)
        changedBy = try container.decodeIfPresent(UUID.self, forKey: .changedBy)
    }
}

// MARK: - Plan Exception Type

/// Categories of life exceptions that affect plan adherence
enum PlanExceptionType: String, Codable, CaseIterable {
    case medicalCondition = "medical_condition"   // Injury, illness, surgery
    case lifeEvent = "life_event"                 // New baby, family emergency, travel
    case environmentChange = "environment_change" // Moved, lost gym access, season change
    case other = "other"

    var displayName: String {
        switch self {
        case .medicalCondition: return "Medical/Health"
        case .lifeEvent: return "Life Event"
        case .environmentChange: return "Environment Change"
        case .other: return "Other"
        }
    }

    var iconName: String {
        switch self {
        case .medicalCondition: return "cross.case.fill"
        case .lifeEvent: return "figure.2.and.child.holdinghands"
        case .environmentChange: return "house.and.flag.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var examples: String {
        switch self {
        case .medicalCondition: return "Injury, illness, surgery, recovery"
        case .lifeEvent: return "New baby, family emergency, travel, major life change"
        case .environmentChange: return "Moved, lost gym access, weather, work schedule change"
        case .other: return "Anything else affecting your routine"
        }
    }
}

// MARK: - Question Response (Single Source of Truth for UI state)

/// Represents the current response state for a question
/// This is the SINGLE SOURCE OF TRUTH - no separate selectedOptionIds/freeText/rankedOptions
struct QuestionResponse: Equatable {
    let questionNumber: String
    var selectedOptionIds: Set<String>  // Using optionId strings (e.g., "RO_8.01-1") or UUIDs
    var selectedOptionTexts: Set<String>  // Option display texts for cross-question matching
    var freeText: String?
    var rankedOptionIds: [String]?
    var savedToDatabase: Bool
    var databaseId: UUID?

    var isEmpty: Bool {
        selectedOptionIds.isEmpty && (freeText?.isEmpty ?? true) && (rankedOptionIds?.isEmpty ?? true)
    }

    init(questionNumber: String, selectedOptionIds: Set<String> = [], selectedOptionTexts: Set<String> = [], freeText: String? = nil, rankedOptionIds: [String]? = nil, savedToDatabase: Bool = false, databaseId: UUID? = nil) {
        self.questionNumber = questionNumber
        self.selectedOptionIds = selectedOptionIds
        self.selectedOptionTexts = selectedOptionTexts
        self.freeText = freeText
        self.rankedOptionIds = rankedOptionIds
        self.savedToDatabase = savedToDatabase
        self.databaseId = databaseId
    }
}

extension Set where Element == String {
    /// Toggle membership of an element in the set
    mutating func toggle(_ element: Element) {
        if contains(element) {
            remove(element)
        } else {
            insert(element)
        }
    }
}

// MARK: - Survey Proposed Change

/// Represents a proposed survey response change based on tracked data
/// Used during reassessment to show user what would change
struct SurveyProposedChange: Identifiable, Codable {
    var id: String { "\(questionNumber)-\(sourceMetricId ?? "unknown")" }

    let questionNumber: String
    let questionText: String
    let sectionId: String
    let currentOptionId: UUID?
    let currentOptionText: String?
    let proposedOptionId: UUID
    let proposedOptionText: String
    let sourceMetricId: String?
    let trackedValue: Double
    let periodType: String

    var trackedValueFormatted: String {
        if trackedValue.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", trackedValue)
        } else {
            return String(format: "%.1f", trackedValue)
        }
    }

    enum CodingKeys: String, CodingKey {
        case questionNumber = "question_number"
        case questionText = "question_text"
        case sectionId = "section_id"
        case currentOptionId = "current_option_id"
        case currentOptionText = "current_option_text"
        case proposedOptionId = "proposed_option_id"
        case proposedOptionText = "proposed_option_text"
        case sourceMetricId = "source_metric_id"
        case trackedValue = "tracked_value"
        case periodType = "period_type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        questionNumber = try container.decodeQuestionNumber(forKey: .questionNumber)
        questionText = try container.decode(String.self, forKey: .questionText)
        sectionId = try container.decode(String.self, forKey: .sectionId)
        currentOptionId = try container.decodeIfPresent(UUID.self, forKey: .currentOptionId)
        currentOptionText = try container.decodeIfPresent(String.self, forKey: .currentOptionText)
        proposedOptionId = try container.decode(UUID.self, forKey: .proposedOptionId)
        proposedOptionText = try container.decode(String.self, forKey: .proposedOptionText)
        sourceMetricId = try container.decodeIfPresent(String.self, forKey: .sourceMetricId)
        trackedValue = try container.decode(Double.self, forKey: .trackedValue)
        periodType = try container.decode(String.self, forKey: .periodType)
    }
}

// MARK: - Patient Condition (Medical History)

/// A medical condition for the patient or their family member
struct PatientCondition: Identifiable, Codable {
    let id: UUID
    let patientId: UUID?
    let conditionId: String
    let conditionName: String
    let conditionCategory: String?
    let historyType: String  // "personal" or "family"
    let familyMemberRelationship: String?  // "mother", "father", "sibling", etc.
    let diagnosisDate: Date?
    let severity: String?
    let status: String?
    let notes: String?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    var isPersonal: Bool {
        historyType == "personal"
    }

    var isFamily: Bool {
        historyType == "family"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case conditionId = "condition_id"
        case conditionName = "condition_name"
        case conditionCategory = "condition_category"
        case historyType = "history_type"
        case familyMemberRelationship = "family_member_relationship"
        case diagnosisDate = "diagnosis_date"
        case severity
        case status
        case notes
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        patientId = try container.decodeIfPresent(UUID.self, forKey: .patientId)
        conditionId = try container.decode(String.self, forKey: .conditionId)
        conditionName = try container.decode(String.self, forKey: .conditionName)
        conditionCategory = try container.decodeIfPresent(String.self, forKey: .conditionCategory)
        historyType = try container.decodeIfPresent(String.self, forKey: .historyType) ?? "personal"
        familyMemberRelationship = try container.decodeIfPresent(String.self, forKey: .familyMemberRelationship)
        // Handle date-only strings
        if let dateString = try? container.decode(String.self, forKey: .diagnosisDate) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            diagnosisDate = formatter.date(from: dateString)
        } else {
            diagnosisDate = try container.decodeIfPresent(Date.self, forKey: .diagnosisDate)
        }
        severity = try container.decodeIfPresent(String.self, forKey: .severity)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

// MARK: - Patient Screening (Preventive Care)

/// A preventive screening record for the patient
struct PatientScreening: Identifiable, Codable {
    let id: UUID
    let patientId: UUID
    let screeningTypeId: String
    let screeningStatus: String
    let screeningDate: Date?
    let nextDueDate: Date?
    let resultSummary: String?
    let resultDetails: [String: Any]?
    let dataSource: String
    let notes: String?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    var isOverdue: Bool {
        guard let dueDate = nextDueDate else { return false }
        return dueDate < Date()
    }

    var isDueSoon: Bool {
        guard let dueDate = nextDueDate else { return false }
        let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
        return daysUntilDue <= 30 && daysUntilDue >= 0
    }

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case screeningTypeId = "screening_type_id"
        case screeningStatus = "screening_status"
        case screeningDate = "screening_date"
        case nextDueDate = "next_due_date"
        case resultSummary = "result_summary"
        case resultDetails = "result_details"
        case dataSource = "data_source"
        case notes
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        patientId = try container.decode(UUID.self, forKey: .patientId)
        screeningTypeId = try container.decode(String.self, forKey: .screeningTypeId)
        screeningStatus = try container.decode(String.self, forKey: .screeningStatus)
        screeningDate = try container.decodeIfPresent(Date.self, forKey: .screeningDate)
        nextDueDate = try container.decodeIfPresent(Date.self, forKey: .nextDueDate)
        resultSummary = try container.decodeIfPresent(String.self, forKey: .resultSummary)
        resultDetails = nil  // JSONB decoding handled separately if needed
        dataSource = try container.decode(String.self, forKey: .dataSource)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(patientId, forKey: .patientId)
        try container.encode(screeningTypeId, forKey: .screeningTypeId)
        try container.encode(screeningStatus, forKey: .screeningStatus)
        try container.encodeIfPresent(screeningDate, forKey: .screeningDate)
        try container.encodeIfPresent(nextDueDate, forKey: .nextDueDate)
        try container.encodeIfPresent(resultSummary, forKey: .resultSummary)
        // resultDetails is [String: Any]? which isn't Codable - skip encoding
        try container.encode(dataSource, forKey: .dataSource)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - Screening Type Reference

/// Reference data for screening types
struct ScreeningType: Identifiable, Codable {
    let id: UUID
    let screeningTypeId: String
    let screeningName: String
    let description: String?
    let surveyQuestionNumber: String?
    let recommendedFrequencyMonths: Int?
    let category: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case screeningTypeId = "screening_type_id"
        case screeningName = "screening_name"
        case description
        case surveyQuestionNumber = "survey_question_number"
        case recommendedFrequencyMonths = "recommended_frequency_months"
        case category
        case isActive = "is_active"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        screeningTypeId = try container.decode(String.self, forKey: .screeningTypeId)
        screeningName = try container.decode(String.self, forKey: .screeningName)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        if let qNum = try? container.decodeQuestionNumber(forKey: .surveyQuestionNumber) {
            surveyQuestionNumber = qNum
        } else {
            surveyQuestionNumber = nil
        }
        recommendedFrequencyMonths = try container.decodeIfPresent(Int.self, forKey: .recommendedFrequencyMonths)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        isActive = try container.decode(Bool.self, forKey: .isActive)
    }
}

// MARK: - Plan Exception

/// Documents a life event that affects a user's ability to follow their health plan
struct PlanException: Identifiable, Codable {
    let id: UUID
    let patientId: UUID
    let exceptionType: PlanExceptionType
    let reasonText: String
    let affectedPillars: [String]?
    let startDate: Date
    var endDate: Date?
    var isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    var resolvedAt: Date?

    var daysActive: Int {
        let end = endDate ?? Date()
        return Calendar.current.dateComponents([.day], from: startDate, to: end).day ?? 0
    }

    var affectedPillarsDisplay: String {
        guard let pillars = affectedPillars, !pillars.isEmpty else {
            return "All areas"
        }
        return pillars.map { $0.capitalized }.joined(separator: ", ")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case exceptionType = "exception_type"
        case reasonText = "reason_text"
        case affectedPillars = "affected_pillars"
        case startDate = "start_date"
        case endDate = "end_date"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case resolvedAt = "resolved_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        patientId = try container.decode(UUID.self, forKey: .patientId)
        exceptionType = try container.decode(PlanExceptionType.self, forKey: .exceptionType)
        reasonText = try container.decode(String.self, forKey: .reasonText)
        affectedPillars = try container.decodeIfPresent([String].self, forKey: .affectedPillars)
        // Handle date-only strings from database
        if let dateString = try? container.decode(String.self, forKey: .startDate) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            startDate = formatter.date(from: dateString) ?? Date()
        } else {
            startDate = try container.decode(Date.self, forKey: .startDate)
        }
        if let dateString = try? container.decode(String.self, forKey: .endDate) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            endDate = formatter.date(from: dateString)
        } else {
            endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        }
        isActive = try container.decode(Bool.self, forKey: .isActive)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        resolvedAt = try container.decodeIfPresent(Date.self, forKey: .resolvedAt)
    }

    init(id: UUID = UUID(), patientId: UUID, exceptionType: PlanExceptionType, reasonText: String, affectedPillars: [String]?, startDate: Date, endDate: Date? = nil, isActive: Bool = true) {
        self.id = id
        self.patientId = patientId
        self.exceptionType = exceptionType
        self.reasonText = reasonText
        self.affectedPillars = affectedPillars
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = isActive
        self.createdAt = Date()
        self.updatedAt = Date()
        self.resolvedAt = nil
    }
}
