//
//  HealthProfileViewModel.swift
//  WellPath
//
//  ViewModel for the Health Profile experience.
//  Uses SINGLE SOURCE OF TRUTH pattern - all response state in `responses` dictionary.
//

import Foundation
import SwiftUI
import Supabase

// MARK: - Helper struct for loading question summaries with group mapping

private struct GroupQuestionSummary: Codable {
    let questionNumber: String
    let groupId: String?

    enum CodingKeys: String, CodingKey {
        case questionNumber = "question_number"
        case groupId = "group_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        groupId = try container.decodeIfPresent(String.self, forKey: .groupId)
        // Handle numeric question_number
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

@MainActor
class HealthProfileViewModel: ObservableObject {
    // MARK: - SINGLE SOURCE OF TRUTH

    /// All response state lives here - keyed by questionNumber
    @Published private(set) var responses: [String: QuestionResponse] = [:]

    // MARK: - Survey Structure (read-only after load)

    @Published var sections: [SurveySection] = []
    @Published private(set) var allQuestions: [SurveyQuestion] = []
    @Published private(set) var conditions: [String: [SurveyQuestionCondition]] = [:]

    // MARK: - Loading State

    @Published var isLoading = false
    @Published var error: String?
    @Published var isSaving = false

    // MARK: - Navigation State

    @Published var currentSection: SurveySection?
    @Published var currentCategory: SurveyCategory?
    @Published var currentGroup: SurveyGroup?
    @Published var questions: [SurveyQuestion] = []  // Questions for current group
    @Published var currentQuestionIndex: Int = 0

    // MARK: - Survey Lifecycle State

    @Published var surveyState: PatientSurveyState?
    @Published var activeExceptions: [PlanException] = []

    // MARK: - Cascade Warning State

    @Published var pendingCascadeQuestions: [String] = []
    @Published var showCascadeWarning = false

    // MARK: - Response History

    @Published var currentQuestionHistory: [SurveyResponseHistory] = []
    @Published var showHistorySheet = false

    // MARK: - Private

    private let service = SurveyService.shared
    private let supabase = SupabaseManager.shared.client
    private var cachedPatientId: UUID?

    // MARK: - User Defaults Keys

    private let welcomeSeenKey = "healthProfile.hasSeenWelcome"

    // MARK: - Computed Properties

    var hasSeenWelcome: Bool {
        UserDefaults.standard.bool(forKey: welcomeSeenKey)
    }

    /// Whether the survey is currently editable (not locked during active plan)
    var isEditable: Bool {
        guard let state = surveyState else { return true }
        return state.lifecyclePhase.isEditable
    }

    /// Days until survey unlocks (if locked)
    var daysUntilUnlock: Int? {
        surveyState?.daysUntilUnlock
    }

    /// Whether there are active life exceptions
    var hasActiveExceptions: Bool {
        !activeExceptions.isEmpty
    }

    var totalCategoryCount: Int {
        sections.reduce(0) { $0 + $1.categories.count }
    }

    var completedCategoryCount: Int {
        sections.reduce(0) { $0 + $1.completedCategoryCount }
    }

    var overallProgress: Double {
        guard totalCategoryCount > 0 else { return 0 }
        return Double(completedCategoryCount) / Double(totalCategoryCount)
    }

    var isComplete: Bool {
        totalCategoryCount > 0 && completedCategoryCount >= totalCategoryCount
    }

    var nextIncompleteSection: SurveySection? {
        sections.first { !$0.categories.allSatisfy { $0.isComplete } }
    }

    var currentQuestion: SurveyQuestion? {
        guard currentQuestionIndex >= 0, currentQuestionIndex < visibleQuestions.count else { return nil }
        return visibleQuestions[currentQuestionIndex]
    }

    /// Questions filtered by visibility (show_if conditions)
    var visibleQuestions: [SurveyQuestion] {
        questions.filter { isQuestionVisible($0) }
    }

    var canGoBack: Bool {
        currentQuestionIndex > 0
    }

    var canGoForward: Bool {
        currentQuestionIndex < visibleQuestions.count - 1
    }

    // MARK: - Initialization

    private func getPatientId() async throws -> UUID {
        if let cached = cachedPatientId {
            return cached
        }
        let userId = try await supabase.auth.session.user.id
        cachedPatientId = userId
        return userId
    }

    // MARK: - Data Loading

    func loadData() async {
        isLoading = true
        error = nil

        do {
            let patientId = try await getPatientId()
            print("HealthProfile: Got patient ID: \(patientId)")

            // Load survey state, exceptions, and hierarchy in parallel
            async let stateTask = service.fetchSurveyState(patientId: patientId)
            async let exceptionsTask = service.fetchActiveExceptions(patientId: patientId)
            async let sectionsTask = service.fetchSectionsWithHierarchy()
            async let conditionsTask = service.fetchAllConditions()

            var loadedSections = try await sectionsTask
            surveyState = try? await stateTask
            activeExceptions = (try? await exceptionsTask) ?? []

            // Load conditions - keyed by question_number for easy lookup
            let loadedConditions = try await conditionsTask
            conditions = Dictionary(grouping: loadedConditions) { $0.questionNumber }

            print("HealthProfile: Loaded \(loadedSections.count) sections")
            print("HealthProfile: Loaded \(conditions.count) question conditions")
            print("HealthProfile: Survey state: \(surveyState?.lifecyclePhase.rawValue ?? "none")")
            print("HealthProfile: Active exceptions: \(activeExceptions.count)")

            // Load all patient responses and convert to QuestionResponse format
            let dbResponses = try await service.fetchPatientResponses(patientId: patientId)
            await loadResponsesFromDatabase(dbResponses)

            let answeredQuestionNumbers = Set(dbResponses.map { $0.questionNumber })

            // Load all questions to map progress
            let allQuestionSummaries = try await loadAllQuestionSummaries()
            let questionsByGroup = Dictionary(grouping: allQuestionSummaries) { $0.groupId ?? "" }

            // Calculate progress for each group → category → section
            for sectionIdx in 0..<loadedSections.count {
                for categoryIdx in 0..<loadedSections[sectionIdx].categories.count {
                    var completedGroups = 0

                    for groupIdx in 0..<loadedSections[sectionIdx].categories[categoryIdx].groups.count {
                        let groupId = loadedSections[sectionIdx].categories[categoryIdx].groups[groupIdx].groupId
                        let groupQuestions = questionsByGroup[groupId] ?? []

                        let totalInGroup = groupQuestions.count
                        let answeredInGroup = groupQuestions.filter { answeredQuestionNumbers.contains($0.questionNumber) }.count

                        loadedSections[sectionIdx].categories[categoryIdx].groups[groupIdx].questionCount = totalInGroup
                        loadedSections[sectionIdx].categories[categoryIdx].groups[groupIdx].answeredCount = answeredInGroup

                        if totalInGroup > 0 && answeredInGroup >= totalInGroup {
                            completedGroups += 1
                        }
                    }

                    loadedSections[sectionIdx].categories[categoryIdx].completedGroupCount = completedGroups
                }
            }

            sections = loadedSections
            isLoading = false
        } catch let decodingError as DecodingError {
            handleDecodingError(decodingError)
            isLoading = false
        } catch let urlError as URLError where urlError.code == .cancelled {
            isLoading = false
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                isLoading = false
                return
            }
            self.error = error.localizedDescription
            print("HealthProfile error: \(error)")
            isLoading = false
        }
    }

    /// Convert database responses to QuestionResponse format
    private func loadResponsesFromDatabase(_ dbResponses: [PatientSurveyResponse]) async {
        var loadedResponses: [String: QuestionResponse] = [:]

        // Group responses by question_number (for multi-select)
        let responsesByQuestion = Dictionary(grouping: dbResponses) { $0.questionNumber }

        for (questionNumber, questionResponses) in responsesByQuestion {
            // Get the first response to determine question type
            guard let firstResponse = questionResponses.first else { continue }

            // Parse the response text to extract selected option IDs
            var selectedOptionIds = Set<String>()
            var rankedOptionIds: [String]? = nil
            var freeText: String? = nil

            if let responseText = firstResponse.responseText {
                // Check if this looks like comma-separated UUIDs (multi-select)
                // or option IDs, or free text
                let parts = responseText.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }

                // If all parts look like UUIDs or optionIds, treat as selection
                let allLookLikeIds = parts.allSatisfy { part in
                    UUID(uuidString: part) != nil || part.hasPrefix("RO_")
                }

                if allLookLikeIds && !parts.isEmpty {
                    // These are option IDs or UUIDs - need to map to optionIds
                    // For now, store as-is and we'll resolve when we load the question
                    selectedOptionIds = Set(parts)
                } else {
                    // This is free text
                    freeText = responseText
                }
            }

            // If we have a responseOptionId, we need to look up the optionId
            // This will be resolved when we load questions for a group

            loadedResponses[questionNumber] = QuestionResponse(
                questionNumber: questionNumber,
                selectedOptionIds: selectedOptionIds,
                freeText: freeText,
                rankedOptionIds: rankedOptionIds,
                savedToDatabase: true,
                databaseId: firstResponse.id
            )
        }

        responses = loadedResponses
        print("HealthProfile: Loaded \(responses.count) responses from database")
    }

    private func loadAllQuestionSummaries() async throws -> [GroupQuestionSummary] {
        let questions: [GroupQuestionSummary] = try await supabase
            .from("survey_questions_base")
            .select("question_number, group_id")
            .eq("is_active", value: true)
            .execute()
            .value

        return questions
    }

    // MARK: - Welcome

    func markWelcomeSeen() {
        UserDefaults.standard.set(true, forKey: welcomeSeenKey)
    }

    // MARK: - Navigation

    func selectSection(_ section: SurveySection) {
        currentSection = section
    }

    func selectCategory(_ category: SurveyCategory) {
        currentCategory = category
    }

    func selectGroup(_ group: SurveyGroup) async {
        currentGroup = group
        await loadQuestionsForGroup(group)
    }

    private func loadQuestionsForGroup(_ group: SurveyGroup) async {
        isLoading = true

        do {
            let patientId = try await getPatientId()

            // Fetch questions for this group
            var loadedQuestions: [SurveyQuestion] = try await supabase
                .from("survey_questions_base")
                .select()
                .eq("group_id", value: group.groupId)
                .eq("is_active", value: true)
                .order("group_question_order")
                .execute()
                .value

            // Fetch options
            let questionNumbers = loadedQuestions.map { $0.questionNumber }
            let options = try await service.fetchResponseOptions(forQuestionNumbers: questionNumbers)
            let optionsByQuestion = Dictionary(grouping: options) { $0.questionNumber }

            // Also fetch conditions for these questions
            let questionConditions = try await service.fetchConditions(forQuestionNumbers: questionNumbers)
            for condition in questionConditions {
                if conditions[condition.questionNumber] == nil {
                    conditions[condition.questionNumber] = []
                }
                if !conditions[condition.questionNumber]!.contains(where: { $0.id == condition.id }) {
                    conditions[condition.questionNumber]!.append(condition)
                }
            }

            // Map options to questions
            for i in 0..<loadedQuestions.count {
                loadedQuestions[i].options = optionsByQuestion[loadedQuestions[i].questionNumber]?.sorted { $0.questionResponseOrder < $1.questionResponseOrder } ?? []

                // Update responses to use optionId strings if we have UUID-based responses
                let qNum = loadedQuestions[i].questionNumber
                if var response = responses[qNum] {
                    // Convert any UUID-based selections to optionId strings
                    var updatedOptionIds = Set<String>()
                    for selectedId in response.selectedOptionIds {
                        // If it's a UUID, look up the optionId
                        if let uuid = UUID(uuidString: selectedId) {
                            if let option = loadedQuestions[i].options.first(where: { $0.id == uuid }) {
                                updatedOptionIds.insert(option.optionId)
                            }
                        } else {
                            // Already an optionId string
                            updatedOptionIds.insert(selectedId)
                        }
                    }
                    response.selectedOptionIds = updatedOptionIds
                    responses[qNum] = response
                }
            }

            questions = loadedQuestions
            currentQuestionIndex = findFirstUnansweredIndex()

            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    /// Find the first question that hasn't been answered
    private func findFirstUnansweredIndex() -> Int {
        for (index, question) in visibleQuestions.enumerated() {
            if responses[question.questionNumber] == nil || responses[question.questionNumber]!.isEmpty {
                return index
            }
        }
        return 0
    }

    // MARK: - Conditional Logic

    /// Check if a question should be visible based on show_if conditions
    func isQuestionVisible(_ question: SurveyQuestion) -> Bool {
        guard let conds = conditions[question.questionNumber] else { return true }

        for cond in conds where cond.conditionType == .showIf {
            // Check if source question has been answered with required options
            guard let sourceResponse = responses[cond.sourceQuestionNumber] else {
                return false  // Source not answered = hide
            }

            guard let requiredOptionIds = cond.sourceResponseOptionIds else {
                return false
            }

            // Check if any of the required options are selected
            let hasRequiredSelection = requiredOptionIds.contains { requiredId in
                sourceResponse.selectedOptionIds.contains(requiredId)
            }

            if !hasRequiredSelection {
                return false
            }
        }

        return true
    }

    /// Get available options for a question, filtering based on conditional logic
    func availableOptions(for question: SurveyQuestion) -> [SurveyResponseOption] {
        guard let conds = conditions[question.questionNumber] else {
            return question.options
        }

        for cond in conds {
            switch cond.conditionType {
            case .optionsFromSelected:
                guard let sourceResponse = responses[cond.sourceQuestionNumber] else {
                    return []  // Can't show "selected" if nothing selected
                }
                // Return only options whose optionId was selected in source
                return question.options.filter { option in
                    sourceResponse.selectedOptionIds.contains(option.optionId)
                }

            case .optionsFromNotSelected:
                guard let sourceResponse = responses[cond.sourceQuestionNumber] else {
                    return question.options  // Show ALL if source not answered yet
                }
                // Return options whose optionId was NOT selected in source
                return question.options.filter { option in
                    !sourceResponse.selectedOptionIds.contains(option.optionId)
                }

            case .showIf:
                // show_if doesn't affect available options, just visibility
                break
            }
        }

        return question.options
    }

    // MARK: - Question Navigation

    func goToNextQuestion() {
        guard canGoForward else { return }
        currentQuestionIndex += 1
    }

    func goToPreviousQuestion() {
        guard canGoBack else { return }
        currentQuestionIndex -= 1
    }

    // MARK: - Response Handling (SINGLE SOURCE OF TRUTH)

    /// Check if an option is selected - reads from single source
    func isOptionSelected(_ option: SurveyResponseOption) -> Bool {
        guard let question = currentQuestion else { return false }
        guard let response = responses[question.questionNumber] else { return false }
        return response.selectedOptionIds.contains(option.optionId)
    }

    /// Get the rank position for an option (1-based, 0 if not ranked)
    func rankPosition(for option: SurveyResponseOption) -> Int {
        guard let question = currentQuestion else { return 0 }
        guard let response = responses[question.questionNumber],
              let rankedIds = response.rankedOptionIds else { return 0 }
        if let index = rankedIds.firstIndex(of: option.optionId) {
            return index + 1
        }
        return 0
    }

    /// Select an option - updates single source of truth
    func selectOption(_ option: SurveyResponseOption) async {
        guard let question = currentQuestion else {
            print("selectOption: No current question!")
            return
        }

        print("selectOption: question type = \(question.type), option = \(option.optionText)")

        // Get or create response
        var response = responses[question.questionNumber] ?? QuestionResponse(questionNumber: question.questionNumber)

        switch question.type {
        case .singleSelect:
            // Single select: set to this option only and auto-save
            response.selectedOptionIds = [option.optionId]
            responses[question.questionNumber] = response
            await saveCurrentResponse()

        case .multiSelect, .multiSelectTrimmed:
            // Multi-select: toggle this option
            response.selectedOptionIds.toggle(option.optionId)
            responses[question.questionNumber] = response
            // Don't auto-save, wait for explicit save (Next button)

        case .rank:
            // Rank: add to end of ranked list if not present, remove if present
            var rankedIds = response.rankedOptionIds ?? []
            if let index = rankedIds.firstIndex(of: option.optionId) {
                rankedIds.remove(at: index)
            } else {
                rankedIds.append(option.optionId)
            }
            response.rankedOptionIds = rankedIds
            response.selectedOptionIds = Set(rankedIds)  // Keep in sync
            responses[question.questionNumber] = response
            // Don't auto-save, wait for explicit save

        case .freeResponse, .numeric, .date:
            // These don't use selectOption
            break
        }

        // Force UI update
        objectWillChange.send()
    }

    /// Update free text response
    func updateFreeText(_ text: String) {
        guard let question = currentQuestion else { return }
        var response = responses[question.questionNumber] ?? QuestionResponse(questionNumber: question.questionNumber)
        response.freeText = text
        responses[question.questionNumber] = response
    }

    /// Get free text for current question
    var currentFreeText: String {
        guard let question = currentQuestion else { return "" }
        return responses[question.questionNumber]?.freeText ?? ""
    }

    // MARK: - Save Responses

    /// Save the current question's response to the database
    func saveCurrentResponse() async {
        guard let question = currentQuestion else { return }
        guard let response = responses[question.questionNumber], !response.isEmpty else { return }

        isSaving = true

        do {
            let patientId = try await getPatientId()

            switch question.type {
            case .singleSelect:
                // Find the option for the selected optionId
                guard let selectedOptionId = response.selectedOptionIds.first,
                      let option = question.options.first(where: { $0.optionId == selectedOptionId }) else {
                    isSaving = false
                    return
                }

                let dbResponse = try await service.saveResponse(
                    patientId: patientId,
                    questionNumber: question.questionNumber,
                    responseOptionId: option.id,
                    responseText: option.optionText,
                    responseValue: option.score
                )

                // Update local state
                var updatedResponse = response
                updatedResponse.savedToDatabase = true
                updatedResponse.databaseId = dbResponse.id
                responses[question.questionNumber] = updatedResponse

                print("Saved single-select: \(option.optionText)")

            case .multiSelect, .multiSelectTrimmed:
                // Save comma-separated option IDs
                let selectedIds = response.selectedOptionIds.compactMap { optionId -> UUID? in
                    question.options.first { $0.optionId == optionId }?.id
                }

                let dbResponse = try await service.saveMultiSelectResponse(
                    patientId: patientId,
                    questionNumber: question.questionNumber,
                    selectedOptionIds: selectedIds
                )

                var updatedResponse = response
                updatedResponse.savedToDatabase = true
                updatedResponse.databaseId = dbResponse.id
                responses[question.questionNumber] = updatedResponse

                print("Saved multi-select: \(selectedIds.count) options")

            case .rank:
                // Save ranked option IDs as comma-separated string
                let rankedIds = response.rankedOptionIds ?? []
                let responseText = rankedIds.joined(separator: ",")

                let dbResponse = try await service.saveResponse(
                    patientId: patientId,
                    questionNumber: question.questionNumber,
                    responseOptionId: nil,
                    responseText: responseText,
                    responseValue: nil
                )

                var updatedResponse = response
                updatedResponse.savedToDatabase = true
                updatedResponse.databaseId = dbResponse.id
                responses[question.questionNumber] = updatedResponse

                print("Saved rank: \(rankedIds.count) items")

            case .freeResponse:
                guard let text = response.freeText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    isSaving = false
                    return
                }

                let dbResponse = try await service.saveResponse(
                    patientId: patientId,
                    questionNumber: question.questionNumber,
                    responseOptionId: nil,
                    responseText: text,
                    responseValue: nil
                )

                var updatedResponse = response
                updatedResponse.savedToDatabase = true
                updatedResponse.databaseId = dbResponse.id
                responses[question.questionNumber] = updatedResponse

                print("Saved free response")

            case .numeric, .date:
                // Similar to free response
                guard let text = response.freeText else {
                    isSaving = false
                    return
                }

                let dbResponse = try await service.saveResponse(
                    patientId: patientId,
                    questionNumber: question.questionNumber,
                    responseOptionId: nil,
                    responseText: text,
                    responseValue: Double(text)
                )

                var updatedResponse = response
                updatedResponse.savedToDatabase = true
                updatedResponse.databaseId = dbResponse.id
                responses[question.questionNumber] = updatedResponse
            }

            isSaving = false
        } catch {
            print("Error saving response: \(error)")
            self.error = error.localizedDescription
            isSaving = false
        }
    }

    /// Save multi-select response (called from Next button)
    func saveMultiSelectResponse() async {
        await saveCurrentResponse()
    }

    /// Save free response (called from Next button)
    func saveFreeResponse() async {
        await saveCurrentResponse()
    }

    // MARK: - Helper Methods

    private func handleDecodingError(_ error: DecodingError) {
        switch error {
        case .typeMismatch(let type, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            self.error = "Type mismatch: expected \(type) at \(path)"
            print("HealthProfile decode error - Type mismatch: \(type) at path: \(path)")
        case .valueNotFound(let type, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            self.error = "Value not found: \(type) at \(path)"
        case .keyNotFound(let key, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            self.error = "Key not found: \(key.stringValue) at \(path)"
        case .dataCorrupted(let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            self.error = "Data corrupted at \(path)"
        @unknown default:
            self.error = error.localizedDescription
        }
    }

    // MARK: - Cascade Impact

    /// Check if changing the current question will cascade-delete dependent responses
    func checkCascadeImpact() async -> [String] {
        guard let question = currentQuestion else { return [] }

        do {
            let dependentQuestions = try await service.getDependentQuestions(questionNumber: question.questionNumber)
            pendingCascadeQuestions = dependentQuestions
            return dependentQuestions
        } catch {
            print("Error checking cascade impact: \(error)")
            return []
        }
    }

    /// Called before changing a source question response - warns user about cascade
    func prepareForSourceQuestionChange() async -> Bool {
        let impactedQuestions = await checkCascadeImpact()
        if !impactedQuestions.isEmpty {
            showCascadeWarning = true
            return true
        }
        return false
    }

    /// Clear cascade warning state
    func dismissCascadeWarning() {
        showCascadeWarning = false
        pendingCascadeQuestions = []
    }

    // MARK: - Response History

    /// Load history for the current question
    func loadCurrentQuestionHistory() async {
        guard let question = currentQuestion else {
            currentQuestionHistory = []
            return
        }

        do {
            let patientId = try await getPatientId()
            currentQuestionHistory = try await service.fetchResponseHistory(
                patientId: patientId,
                questionNumber: question.questionNumber
            )
        } catch {
            print("Error loading question history: \(error)")
            currentQuestionHistory = []
        }
    }

    /// Show history sheet for current question
    func showHistory() async {
        await loadCurrentQuestionHistory()
        showHistorySheet = true
    }

    // MARK: - Exception Handling

    /// Log a new life exception
    func logException(
        type: PlanExceptionType,
        reason: String,
        affectedPillars: [String]?,
        startDate: Date,
        endDate: Date? = nil
    ) async throws {
        let patientId = try await getPatientId()
        let exception = try await service.logException(
            patientId: patientId,
            exceptionType: type,
            reasonText: reason,
            affectedPillars: affectedPillars,
            startDate: startDate,
            endDate: endDate
        )
        activeExceptions.insert(exception, at: 0)
    }

    /// Resolve an active exception
    func resolveException(_ exception: PlanException) async throws {
        _ = try await service.resolveException(exceptionId: exception.id)

        if let index = activeExceptions.firstIndex(where: { $0.id == exception.id }) {
            activeExceptions.remove(at: index)
        }
    }

    /// Delete an exception (if user made a mistake)
    func deleteException(_ exception: PlanException) async throws {
        try await service.deleteException(exceptionId: exception.id)

        if let index = activeExceptions.firstIndex(where: { $0.id == exception.id }) {
            activeExceptions.remove(at: index)
        }
    }

    /// Refresh active exceptions
    func refreshExceptions() async {
        do {
            let patientId = try await getPatientId()
            activeExceptions = try await service.fetchActiveExceptions(patientId: patientId)
        } catch {
            print("Error refreshing exceptions: \(error)")
        }
    }
}
