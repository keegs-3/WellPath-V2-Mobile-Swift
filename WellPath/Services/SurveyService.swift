//
//  SurveyService.swift
//  WellPath
//
//  Created on 2025-11-27
//

import Foundation
import Supabase

class SurveyService {
    static let shared = SurveyService()
    private let client = SupabaseManager.shared.client

    private init() {}

    // MARK: - Fetch Sections

    func fetchSections() async throws -> [SurveySection] {
        let sections: [SurveySection] = try await client
            .from("survey_sections")
            .select()
            .order("section_order")
            .execute()
            .value

        return sections
    }

    // MARK: - Fetch Categories

    func fetchCategories() async throws -> [SurveyCategory] {
        do {
            let response = try await client
                .from("survey_categories")
                .select()
                .order("section_order")
                .order("category_order")
                .execute()

            // Debug: print raw data
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("SurveyService: Raw categories response (first 500 chars): \(String(jsonString.prefix(500)))")
            }

            let decoder = JSONDecoder()
            let categories = try decoder.decode([SurveyCategory].self, from: response.data)
            return categories
        } catch {
            print("SurveyService: Error fetching categories: \(error)")
            throw error
        }
    }

    func fetchCategories(forSection sectionId: String) async throws -> [SurveyCategory] {
        let categories: [SurveyCategory] = try await client
            .from("survey_categories")
            .select()
            .eq("section_id", value: sectionId)
            .order("category_order")
            .execute()
            .value

        return categories
    }

    // MARK: - Fetch Groups

    func fetchGroups() async throws -> [SurveyGroup] {
        let groups: [SurveyGroup] = try await client
            .from("survey_groups")
            .select()
            .order("section_order")
            .order("category_order")
            .order("group_order")
            .execute()
            .value

        return groups
    }

    func fetchGroups(forCategory categoryId: String) async throws -> [SurveyGroup] {
        let groups: [SurveyGroup] = try await client
            .from("survey_groups")
            .select()
            .eq("category_id", value: categoryId)
            .order("group_order")
            .execute()
            .value

        return groups
    }

    // MARK: - Fetch Full Hierarchy

    func fetchSectionsWithHierarchy() async throws -> [SurveySection] {
        // Fetch all data in parallel
        async let sectionsTask = fetchSections()
        async let categoriesTask = fetchCategories()
        async let groupsTask = fetchGroups()

        var sections = try await sectionsTask
        let categories = try await categoriesTask
        let groups = try await groupsTask

        print("SurveyService: Fetched \(sections.count) sections, \(categories.count) categories, \(groups.count) groups")

        // Build hierarchy: groups → categories → sections
        let groupsByCategory = Dictionary(grouping: groups) { $0.categoryId }
        var categoriesWithGroups = categories.map { category -> SurveyCategory in
            var cat = category
            cat.groups = groupsByCategory[category.categoryId]?.sorted { $0.groupOrder < $1.groupOrder } ?? []
            return cat
        }

        let categoriesBySection = Dictionary(grouping: categoriesWithGroups) { $0.sectionId }
        for i in 0..<sections.count {
            sections[i].categories = categoriesBySection[sections[i].sectionId]?.sorted { $0.categoryOrder < $1.categoryOrder } ?? []
        }

        return sections
    }

    // MARK: - Fetch Section Question Counts

    func fetchSectionQuestionCounts() async throws -> [String: Int] {
        struct CountResult: Codable {
            let sectionId: String
            let count: Int

            enum CodingKeys: String, CodingKey {
                case sectionId = "section_id"
                case count
            }
        }

        // Use RPC to get counts grouped by section
        let result: [CountResult] = try await client
            .rpc("get_survey_question_counts_by_section")
            .execute()
            .value

        var counts: [String: Int] = [:]
        for item in result {
            counts[item.sectionId] = item.count
        }
        return counts
    }

    // MARK: - Fetch Questions for Section

    func fetchQuestions(forSection sectionId: String) async throws -> [SurveyQuestion] {
        var questions: [SurveyQuestion] = try await client
            .from("survey_questions_base")
            .select()
            .eq("section_id", value: sectionId)
            .eq("is_active", value: true)
            .order("category_order")
            .order("group_order")
            .order("group_question_order")
            .execute()
            .value

        // Fetch options for these questions
        let questionNumbers = questions.map { $0.questionNumber }
        let options = try await fetchResponseOptions(forQuestionNumbers: questionNumbers)

        // Map options to questions
        let optionsByQuestion = Dictionary(grouping: options) { $0.questionNumber }
        for i in 0..<questions.count {
            questions[i].options = optionsByQuestion[questions[i].questionNumber]?.sorted(by: { $0.questionResponseOrder < $1.questionResponseOrder }) ?? []
        }

        return questions
    }

    // MARK: - Fetch All Questions (for onboarding)

    func fetchAllQuestions() async throws -> [SurveyQuestion] {
        var questions: [SurveyQuestion] = try await client
            .from("survey_questions_base")
            .select()
            .eq("is_active", value: true)
            .order("section_order")
            .order("category_order")
            .order("group_order")
            .order("group_question_order")
            .execute()
            .value

        // Fetch all options
        let options = try await fetchAllResponseOptions()

        // Map options to questions
        let optionsByQuestion = Dictionary(grouping: options) { $0.questionNumber }
        for i in 0..<questions.count {
            questions[i].options = optionsByQuestion[questions[i].questionNumber]?.sorted(by: { $0.questionResponseOrder < $1.questionResponseOrder }) ?? []
        }

        return questions
    }

    // MARK: - Fetch Response Options

    func fetchResponseOptions(forQuestionNumbers questionNumbers: [String]) async throws -> [SurveyResponseOption] {
        guard !questionNumbers.isEmpty else { return [] }

        let options: [SurveyResponseOption] = try await client
            .from("survey_response_options")
            .select()
            .in("question_number", values: questionNumbers)
            .eq("is_active", value: true)
            .order("question_response_order")
            .execute()
            .value

        return options
    }

    func fetchAllResponseOptions() async throws -> [SurveyResponseOption] {
        let options: [SurveyResponseOption] = try await client
            .from("survey_response_options")
            .select()
            .eq("is_active", value: true)
            .order("question_number")
            .order("question_response_order")
            .execute()
            .value

        return options
    }

    // MARK: - Fetch Question Conditions

    func fetchConditions(forQuestionNumbers questionNumbers: [String]) async throws -> [SurveyQuestionCondition] {
        guard !questionNumbers.isEmpty else { return [] }

        let conditions: [SurveyQuestionCondition] = try await client
            .from("survey_question_conditions")
            .select()
            .in("question_number", values: questionNumbers)
            .eq("is_active", value: true)
            .execute()
            .value

        return conditions
    }

    func fetchConditionsForSourceQuestions(sourceQuestionNumbers: [String]) async throws -> [SurveyQuestionCondition] {
        guard !sourceQuestionNumbers.isEmpty else { return [] }

        let conditions: [SurveyQuestionCondition] = try await client
            .from("survey_question_conditions")
            .select()
            .in("source_question_number", values: sourceQuestionNumbers)
            .eq("is_active", value: true)
            .execute()
            .value

        return conditions
    }

    /// Fetch all active conditions for the entire survey
    func fetchAllConditions() async throws -> [SurveyQuestionCondition] {
        let conditions: [SurveyQuestionCondition] = try await client
            .from("survey_question_conditions")
            .select()
            .eq("is_active", value: true)
            .execute()
            .value

        return conditions
    }

    // MARK: - Fetch Patient Responses

    func fetchPatientResponses(patientId: UUID) async throws -> [PatientSurveyResponse] {
        let responses: [PatientSurveyResponse] = try await client
            .from("patient_survey_responses")
            .select()
            .eq("patient_id", value: patientId.uuidString)
            .execute()
            .value

        return responses
    }

    func fetchPatientResponses(patientId: UUID, forSection sectionId: String) async throws -> [PatientSurveyResponse] {
        // Lightweight struct for partial query (handles numeric question_number from DB)
        struct QuestionNumberOnly: Codable {
            let questionNumber: String

            enum CodingKeys: String, CodingKey {
                case questionNumber = "question_number"
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                // Handle both String and Number formats
                if let stringValue = try? container.decode(String.self, forKey: .questionNumber) {
                    questionNumber = stringValue
                } else if let doubleValue = try? container.decode(Double.self, forKey: .questionNumber) {
                    questionNumber = doubleValue.truncatingRemainder(dividingBy: 1) == 0
                        ? String(format: "%.0f", doubleValue)
                        : String(doubleValue)
                } else {
                    throw DecodingError.typeMismatch(String.self, DecodingError.Context(
                        codingPath: container.codingPath,
                        debugDescription: "Expected String or Number for question_number"
                    ))
                }
            }
        }

        // First get question numbers for this section
        let questions: [QuestionNumberOnly] = try await client
            .from("survey_questions_base")
            .select("question_number")
            .eq("section_id", value: sectionId)
            .eq("is_active", value: true)
            .execute()
            .value

        let questionNumbers = questions.map { $0.questionNumber }
        guard !questionNumbers.isEmpty else { return [] }

        let responses: [PatientSurveyResponse] = try await client
            .from("patient_survey_responses")
            .select()
            .eq("patient_id", value: patientId.uuidString)
            .in("question_number", values: questionNumbers)
            .execute()
            .value

        return responses
    }

    // MARK: - Save Response

    func saveResponse(
        patientId: UUID,
        questionNumber: String,
        responseOptionId: UUID?,
        responseText: String?,
        responseValue: Double?
    ) async throws -> PatientSurveyResponse {
        struct ResponseInsert: Encodable {
            let patientId: UUID
            let questionNumber: Double  // Database expects numeric, not string
            let responseOptionId: UUID?
            let responseText: String?
            let responseValue: Double?
            let completedAt: Date

            enum CodingKeys: String, CodingKey {
                case patientId = "patient_id"
                case questionNumber = "question_number"
                case responseOptionId = "response_option_id"
                case responseText = "response_text"
                case responseValue = "response_value"
                case completedAt = "completed_at"
            }
        }

        // Convert string question number to Double for database numeric column
        guard let questionNumberDouble = Double(questionNumber) else {
            throw NSError(domain: "SurveyService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Invalid question number format: \(questionNumber)"
            ])
        }

        let insert = ResponseInsert(
            patientId: patientId,
            questionNumber: questionNumberDouble,
            responseOptionId: responseOptionId,
            responseText: responseText,
            responseValue: responseValue,
            completedAt: Date()
        )

        // Upsert based on patient_id + question_number
        print("SurveyService: Saving response for question \(questionNumber) (as \(questionNumberDouble))")

        do {
            let response: PatientSurveyResponse = try await client
                .from("patient_survey_responses")
                .upsert(insert, onConflict: "patient_id,question_number")
                .select()
                .single()
                .execute()
                .value

            print("SurveyService: Successfully saved response for question \(questionNumber)")
            return response
        } catch {
            print("SurveyService: ERROR saving response for question \(questionNumber): \(error)")
            throw error
        }
    }

    // MARK: - Save Multiple Responses (for multi-select)

    func saveMultiSelectResponse(
        patientId: UUID,
        questionNumber: String,
        selectedOptionIds: [UUID]
    ) async throws -> PatientSurveyResponse {
        // For multi-select, we store as comma-separated option IDs in response_text
        // and first option as response_option_id
        let responseText = selectedOptionIds.map { $0.uuidString }.joined(separator: ",")

        return try await saveResponse(
            patientId: patientId,
            questionNumber: questionNumber,
            responseOptionId: selectedOptionIds.first,
            responseText: responseText,
            responseValue: nil
        )
    }

    // MARK: - Delete Response

    func deleteResponse(patientId: UUID, questionNumber: String) async throws {
        try await client
            .from("patient_survey_responses")
            .delete()
            .eq("patient_id", value: patientId.uuidString)
            .eq("question_number", value: questionNumber)
            .execute()
    }

    // MARK: - Get Survey Progress

    func getSurveyProgress(patientId: UUID) async throws -> SurveyProgress {
        // Lightweight struct for partial query (handles numeric question_number from DB)
        struct QuestionSummary: Codable {
            let questionNumber: String
            let sectionId: String

            enum CodingKeys: String, CodingKey {
                case questionNumber = "question_number"
                case sectionId = "section_id"
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                sectionId = try container.decode(String.self, forKey: .sectionId)
                // Handle both String and Number formats for question_number
                if let stringValue = try? container.decode(String.self, forKey: .questionNumber) {
                    questionNumber = stringValue
                } else if let doubleValue = try? container.decode(Double.self, forKey: .questionNumber) {
                    questionNumber = doubleValue.truncatingRemainder(dividingBy: 1) == 0
                        ? String(format: "%.0f", doubleValue)
                        : String(doubleValue)
                } else {
                    throw DecodingError.typeMismatch(String.self, DecodingError.Context(
                        codingPath: container.codingPath,
                        debugDescription: "Expected String or Number for question_number"
                    ))
                }
            }
        }

        // Get total questions per section
        let sections = try await fetchSections()

        // Get answered count per section
        let responses = try await fetchPatientResponses(patientId: patientId)
        let answeredQuestionNumbers = Set(responses.map { $0.questionNumber })

        // Get all questions to map to sections (using lightweight struct)
        let allQuestions: [QuestionSummary] = try await client
            .from("survey_questions_base")
            .select("question_number, section_id")
            .eq("is_active", value: true)
            .execute()
            .value

        // Build section progress
        var sectionProgress: [String: SurveyProgress.SectionProgress] = [:]
        let questionsBySection = Dictionary(grouping: allQuestions) { $0.sectionId }

        for section in sections {
            let sectionQuestions = questionsBySection[section.sectionId] ?? []
            let answeredInSection = sectionQuestions.filter { answeredQuestionNumbers.contains($0.questionNumber) }.count

            sectionProgress[section.sectionId] = SurveyProgress.SectionProgress(
                sectionId: section.sectionId,
                totalQuestions: sectionQuestions.count,
                answeredQuestions: answeredInSection
            )
        }

        return SurveyProgress(
            totalQuestions: allQuestions.count,
            answeredQuestions: answeredQuestionNumbers.count,
            sectionProgress: sectionProgress
        )
    }

    // MARK: - Survey State (Lifecycle Phase)

    func fetchSurveyState(patientId: UUID) async throws -> PatientSurveyState? {
        let response: [PatientSurveyState] = try await client
            .from("patient_survey_state")
            .select()
            .eq("patient_id", value: patientId.uuidString)
            .limit(1)
            .execute()
            .value

        return response.first
    }

    func createOrUpdateSurveyState(patientId: UUID, phase: SurveyLifecyclePhase, planEndsAt: Date? = nil) async throws -> PatientSurveyState {
        struct StateUpsert: Encodable {
            let patientId: UUID
            let lifecyclePhase: String
            let planStartedAt: Date?
            let planEndsAt: Date?

            enum CodingKeys: String, CodingKey {
                case patientId = "patient_id"
                case lifecyclePhase = "lifecycle_phase"
                case planStartedAt = "plan_started_at"
                case planEndsAt = "plan_ends_at"
            }
        }

        let upsert = StateUpsert(
            patientId: patientId,
            lifecyclePhase: phase.rawValue,
            planStartedAt: phase == .activePlan ? Date() : nil,
            planEndsAt: planEndsAt
        )

        let result: PatientSurveyState = try await client
            .from("patient_survey_state")
            .upsert(upsert, onConflict: "patient_id")
            .select()
            .single()
            .execute()
            .value

        return result
    }

    // MARK: - Response History

    func fetchResponseHistory(patientId: UUID, questionNumber: String) async throws -> [SurveyResponseHistory] {
        let history: [SurveyResponseHistory] = try await client
            .from("patient_survey_response_history")
            .select()
            .eq("patient_id", value: patientId.uuidString)
            .eq("question_number", value: questionNumber)
            .order("changed_at", ascending: false)
            .execute()
            .value

        return history
    }

    func fetchAllResponseHistory(patientId: UUID, limit: Int = 50) async throws -> [SurveyResponseHistory] {
        let history: [SurveyResponseHistory] = try await client
            .from("patient_survey_response_history")
            .select()
            .eq("patient_id", value: patientId.uuidString)
            .order("changed_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return history
    }

    // MARK: - Dependent Questions (for cascade warning)

    func getDependentQuestions(questionNumber: String) async throws -> [String] {
        struct DependentResult: Codable {
            let questionNumber: String

            enum CodingKeys: String, CodingKey {
                case questionNumber = "question_number"
            }
        }

        // Use the database function we created
        let results: [DependentResult] = try await client
            .rpc("get_dependent_questions", params: ["p_question_number": questionNumber])
            .execute()
            .value

        return results.map { $0.questionNumber }
    }

    // MARK: - Plan Exceptions

    func fetchActiveExceptions(patientId: UUID) async throws -> [PlanException] {
        let exceptions: [PlanException] = try await client
            .from("patient_plan_exceptions")
            .select()
            .eq("patient_id", value: patientId.uuidString)
            .eq("is_active", value: true)
            .order("start_date", ascending: false)
            .execute()
            .value

        return exceptions
    }

    func fetchAllExceptions(patientId: UUID) async throws -> [PlanException] {
        let exceptions: [PlanException] = try await client
            .from("patient_plan_exceptions")
            .select()
            .eq("patient_id", value: patientId.uuidString)
            .order("start_date", ascending: false)
            .execute()
            .value

        return exceptions
    }

    func logException(
        patientId: UUID,
        exceptionType: PlanExceptionType,
        reasonText: String,
        affectedPillars: [String]?,
        startDate: Date,
        endDate: Date? = nil
    ) async throws -> PlanException {
        struct ExceptionInsert: Encodable {
            let patientId: UUID
            let exceptionType: String
            let reasonText: String
            let affectedPillars: [String]?
            let startDate: String
            let endDate: String?
            let isActive: Bool

            enum CodingKeys: String, CodingKey {
                case patientId = "patient_id"
                case exceptionType = "exception_type"
                case reasonText = "reason_text"
                case affectedPillars = "affected_pillars"
                case startDate = "start_date"
                case endDate = "end_date"
                case isActive = "is_active"
            }
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let insert = ExceptionInsert(
            patientId: patientId,
            exceptionType: exceptionType.rawValue,
            reasonText: reasonText,
            affectedPillars: affectedPillars,
            startDate: dateFormatter.string(from: startDate),
            endDate: endDate.map { dateFormatter.string(from: $0) },
            isActive: true
        )

        let exception: PlanException = try await client
            .from("patient_plan_exceptions")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        return exception
    }

    func resolveException(exceptionId: UUID, endDate: Date = Date()) async throws -> PlanException {
        struct ExceptionUpdate: Encodable {
            let isActive: Bool
            let endDate: String

            enum CodingKeys: String, CodingKey {
                case isActive = "is_active"
                case endDate = "end_date"
            }
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let update = ExceptionUpdate(
            isActive: false,
            endDate: dateFormatter.string(from: endDate)
        )

        let exception: PlanException = try await client
            .from("patient_plan_exceptions")
            .update(update)
            .eq("id", value: exceptionId.uuidString)
            .select()
            .single()
            .execute()
            .value

        return exception
    }

    func deleteException(exceptionId: UUID) async throws {
        try await client
            .from("patient_plan_exceptions")
            .delete()
            .eq("id", value: exceptionId.uuidString)
            .execute()
    }

    // MARK: - Proposed Changes (Reassessment)

    /// Fetch proposed survey changes based on tracked data
    /// Called during reassessment to show user what would change
    func fetchProposedChanges(patientId: UUID) async throws -> [SurveyProposedChange] {
        let changes: [SurveyProposedChange] = try await client
            .rpc("calculate_proposed_survey_changes", params: ["p_patient_id": patientId.uuidString])
            .execute()
            .value

        return changes
    }

    /// Accept a single proposed change from tracked data
    func acceptProposedChange(
        patientId: UUID,
        questionNumber: String,
        newOptionId: UUID,
        sourceMetricId: String
    ) async throws -> Bool {
        struct AcceptResult: Codable {
            let success: Bool
        }

        // Use numeric question number for the RPC call
        let questionNumeric = Int(Double(questionNumber) ?? 0)

        let result: Bool = try await client
            .rpc("accept_proposed_survey_change", params: [
                "p_patient_id": patientId.uuidString,
                "p_question_number": String(questionNumeric),
                "p_new_option_id": newOptionId.uuidString,
                "p_source_metric_id": sourceMetricId
            ])
            .execute()
            .value

        return result
    }

    /// Accept all proposed changes at once
    func acceptAllProposedChanges(patientId: UUID) async throws -> Int {
        let count: Int = try await client
            .rpc("accept_all_proposed_changes", params: ["p_patient_id": patientId.uuidString])
            .execute()
            .value

        return count
    }

    // MARK: - Medical Conditions (Personal & Family History)

    /// Fetch all conditions for a patient (both personal and family)
    func fetchConditions(patientId: UUID) async throws -> [PatientCondition] {
        let conditions: [PatientCondition] = try await client
            .from("patient_conditions")
            .select()
            .eq("patient_id", value: patientId.uuidString)
            .eq("is_active", value: true)
            .order("history_type")
            .order("condition_name")
            .execute()
            .value

        return conditions
    }

    /// Fetch personal medical history only
    func fetchPersonalConditions(patientId: UUID) async throws -> [PatientCondition] {
        let conditions: [PatientCondition] = try await client
            .from("patient_conditions")
            .select()
            .eq("patient_id", value: patientId.uuidString)
            .eq("history_type", value: "personal")
            .eq("is_active", value: true)
            .order("condition_name")
            .execute()
            .value

        return conditions
    }

    /// Fetch family medical history only
    func fetchFamilyConditions(patientId: UUID) async throws -> [PatientCondition] {
        let conditions: [PatientCondition] = try await client
            .from("patient_conditions")
            .select()
            .eq("patient_id", value: patientId.uuidString)
            .eq("history_type", value: "family")
            .eq("is_active", value: true)
            .order("family_member_relationship")
            .order("condition_name")
            .execute()
            .value

        return conditions
    }

    /// Add a new condition
    func addCondition(
        patientId: UUID,
        conditionId: String,
        conditionName: String,
        conditionCategory: String?,
        historyType: String,
        familyMemberRelationship: String? = nil,
        diagnosisDate: Date? = nil,
        severity: String? = nil,
        notes: String? = nil
    ) async throws -> PatientCondition {
        struct ConditionInsert: Encodable {
            let patientId: UUID
            let conditionId: String
            let conditionName: String
            let conditionCategory: String?
            let historyType: String
            let familyMemberRelationship: String?
            let diagnosisDate: String?
            let severity: String?
            let notes: String?
            let isActive: Bool

            enum CodingKeys: String, CodingKey {
                case patientId = "patient_id"
                case conditionId = "condition_id"
                case conditionName = "condition_name"
                case conditionCategory = "condition_category"
                case historyType = "history_type"
                case familyMemberRelationship = "family_member_relationship"
                case diagnosisDate = "diagnosis_date"
                case severity
                case notes
                case isActive = "is_active"
            }
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let insert = ConditionInsert(
            patientId: patientId,
            conditionId: conditionId,
            conditionName: conditionName,
            conditionCategory: conditionCategory,
            historyType: historyType,
            familyMemberRelationship: familyMemberRelationship,
            diagnosisDate: diagnosisDate.map { dateFormatter.string(from: $0) },
            severity: severity,
            notes: notes,
            isActive: true
        )

        let condition: PatientCondition = try await client
            .from("patient_conditions")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        return condition
    }

    /// Update a condition
    func updateCondition(
        conditionId: UUID,
        severity: String?,
        status: String?,
        notes: String?
    ) async throws -> PatientCondition {
        struct ConditionUpdate: Encodable {
            let severity: String?
            let status: String?
            let notes: String?

            enum CodingKeys: String, CodingKey {
                case severity
                case status
                case notes
            }
        }

        let update = ConditionUpdate(
            severity: severity,
            status: status,
            notes: notes
        )

        let condition: PatientCondition = try await client
            .from("patient_conditions")
            .update(update)
            .eq("id", value: conditionId.uuidString)
            .select()
            .single()
            .execute()
            .value

        return condition
    }

    /// Delete (soft) a condition
    func deleteCondition(conditionId: UUID) async throws {
        struct ConditionDelete: Encodable {
            let isActive: Bool

            enum CodingKeys: String, CodingKey {
                case isActive = "is_active"
            }
        }

        try await client
            .from("patient_conditions")
            .update(ConditionDelete(isActive: false))
            .eq("id", value: conditionId.uuidString)
            .execute()
    }

    // MARK: - Preventive Screenings

    /// Fetch all screenings for a patient
    func fetchScreenings(patientId: UUID) async throws -> [PatientScreening] {
        let screenings: [PatientScreening] = try await client
            .from("patient_screenings")
            .select()
            .eq("patient_id", value: patientId.uuidString)
            .eq("is_active", value: true)
            .order("next_due_date")
            .execute()
            .value

        return screenings
    }

    /// Fetch screening types reference data
    func fetchScreeningTypes() async throws -> [ScreeningType] {
        let types: [ScreeningType] = try await client
            .from("screening_types")
            .select()
            .eq("is_active", value: true)
            .order("category")
            .order("screening_name")
            .execute()
            .value

        return types
    }

    /// Add or update a screening record
    func upsertScreening(
        patientId: UUID,
        screeningTypeId: String,
        screeningStatus: String,
        screeningDate: Date?,
        nextDueDate: Date?,
        resultSummary: String?,
        notes: String?
    ) async throws -> PatientScreening {
        struct ScreeningUpsert: Encodable {
            let patientId: UUID
            let screeningTypeId: String
            let screeningStatus: String
            let screeningDate: Date?
            let nextDueDate: Date?
            let resultSummary: String?
            let notes: String?
            let dataSource: String
            let isActive: Bool

            enum CodingKeys: String, CodingKey {
                case patientId = "patient_id"
                case screeningTypeId = "screening_type_id"
                case screeningStatus = "screening_status"
                case screeningDate = "screening_date"
                case nextDueDate = "next_due_date"
                case resultSummary = "result_summary"
                case notes
                case dataSource = "data_source"
                case isActive = "is_active"
            }
        }

        let upsert = ScreeningUpsert(
            patientId: patientId,
            screeningTypeId: screeningTypeId,
            screeningStatus: screeningStatus,
            screeningDate: screeningDate,
            nextDueDate: nextDueDate,
            resultSummary: resultSummary,
            notes: notes,
            dataSource: "user",
            isActive: true
        )

        let screening: PatientScreening = try await client
            .from("patient_screenings")
            .upsert(upsert, onConflict: "patient_id,screening_type_id")
            .select()
            .single()
            .execute()
            .value

        return screening
    }

    /// Delete (soft) a screening
    func deleteScreening(screeningId: UUID) async throws {
        struct ScreeningDelete: Encodable {
            let isActive: Bool

            enum CodingKeys: String, CodingKey {
                case isActive = "is_active"
            }
        }

        try await client
            .from("patient_screenings")
            .update(ScreeningDelete(isActive: false))
            .eq("id", value: screeningId.uuidString)
            .execute()
    }

    // MARK: - Categories for Reassessment Check-in

    /// Fetch categories that have NO tracked data mapping (need manual check-in)
    /// Used during reassessment to prompt "any changes to X?"
    func fetchCategoriesWithoutTracking() async throws -> [SurveyCategory] {
        // Categories in core_care that don't have tracked metrics:
        // - substance_use
        // - supplementation
        // - mental_wellbeing_assessment
        // Note: personal/family medical history moves to Data tab, not included here

        let nonTrackableCategories = [
            "substance_use",
            "supplementation",
            "mental_wellbeing_assessment",
            "sleep_apnea_risk"
        ]

        let categories: [SurveyCategory] = try await client
            .from("survey_categories")
            .select()
            .in("category_id", values: nonTrackableCategories)
            .order("category_order")
            .execute()
            .value

        return categories
    }
}
