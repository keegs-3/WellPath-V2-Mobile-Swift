//
//  SurveyViewModel.swift
//  WellPath
//
//  Created on 2025-11-27
//

import Foundation
import SwiftUI
import Supabase

@MainActor
class SurveyViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var sections: [SurveySection] = []
    @Published var currentSection: SurveySection?
    @Published var questions: [SurveyQuestion] = []
    @Published var currentQuestionIndex: Int = 0
    @Published var progress: SurveyProgress?

    @Published var isLoading = false
    @Published var isSaving = false
    @Published var error: String?

    // For multi-select questions
    @Published var selectedOptionIds: Set<UUID> = []

    // For free-response questions
    @Published var freeResponseText: String = ""

    // For rank questions
    @Published var rankedOptions: [SurveyResponseOption] = []

    private let service = SurveyService.shared
    private let supabase = SupabaseManager.shared.client
    private var cachedPatientId: UUID?

    // MARK: - Computed Properties

    var mode: SurveyMode {
        progress?.mode ?? .onboarding
    }

    var currentQuestion: SurveyQuestion? {
        guard currentQuestionIndex >= 0, currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }

    var totalQuestions: Int {
        progress?.totalQuestions ?? 348
    }

    var answeredQuestions: Int {
        progress?.answeredQuestions ?? 0
    }

    var overallCompletionPercentage: Double {
        progress?.completionPercentage ?? 0
    }

    var currentSectionProgress: Double {
        guard let section = currentSection,
              let sectionProgress = progress?.sectionProgress[section.sectionId] else { return 0 }
        return sectionProgress.completionPercentage
    }

    var canGoBack: Bool {
        currentQuestionIndex > 0
    }

    var canGoForward: Bool {
        currentQuestionIndex < questions.count - 1
    }

    var isLastQuestion: Bool {
        currentQuestionIndex == questions.count - 1
    }

    var questionsInCurrentSection: Int {
        questions.count
    }

    // Get patient ID from authenticated session
    private func getPatientId() async throws -> UUID {
        if let cached = cachedPatientId {
            return cached
        }
        let userId = try await supabase.auth.session.user.id
        cachedPatientId = userId
        return userId
    }

    // MARK: - Initialization

    func loadInitialData() async {
        isLoading = true
        error = nil

        do {
            // Get patient ID from auth
            let patientId = try await getPatientId()

            // Load sections
            var loadedSections = try await service.fetchSections()

            // Load progress
            let loadedProgress = try await service.getSurveyProgress(patientId: patientId)
            progress = loadedProgress

            // Update sections with question counts
            for i in 0..<loadedSections.count {
                if let sectionProgress = loadedProgress.sectionProgress[loadedSections[i].sectionId] {
                    loadedSections[i].questionCount = sectionProgress.totalQuestions
                    loadedSections[i].answeredCount = sectionProgress.answeredQuestions
                }
            }

            sections = loadedSections.sorted { $0.sectionOrder < $1.sectionOrder }
            isLoading = false
        } catch let decodingError as DecodingError {
            // Provide detailed decoding error info
            switch decodingError {
            case .typeMismatch(let type, let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                self.error = "Type mismatch: expected \(type) at \(path). \(context.debugDescription)"
                print("Survey decode error - Type mismatch: \(type) at path: \(path)")
                print("Debug: \(context.debugDescription)")
            case .valueNotFound(let type, let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                self.error = "Value not found: \(type) at \(path)"
                print("Survey decode error - Value not found: \(type) at path: \(path)")
            case .keyNotFound(let key, let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                self.error = "Key not found: \(key.stringValue) at \(path)"
                print("Survey decode error - Key not found: \(key.stringValue) at path: \(path)")
            case .dataCorrupted(let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                self.error = "Data corrupted at \(path): \(context.debugDescription)"
                print("Survey decode error - Data corrupted at path: \(path)")
            @unknown default:
                self.error = decodingError.localizedDescription
            }
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            print("Survey error: \(error)")
            isLoading = false
        }
    }

    // MARK: - Section Selection

    func selectSection(_ section: SurveySection) async {
        isLoading = true
        error = nil
        currentSection = section

        do {
            let patientId = try await getPatientId()

            // Load questions for this section
            var loadedQuestions = try await service.fetchQuestions(forSection: section.sectionId)

            // Load existing responses
            let responses = try await service.fetchPatientResponses(patientId: patientId, forSection: section.sectionId)
            let responsesByQuestion = Dictionary(grouping: responses) { $0.questionNumber }

            // Map responses to questions
            for i in 0..<loadedQuestions.count {
                loadedQuestions[i].currentResponse = responsesByQuestion[loadedQuestions[i].questionNumber]?.first
            }

            questions = loadedQuestions
            currentQuestionIndex = 0
            resetInputState()
            loadCurrentQuestionState()
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Navigation

    func goToNextQuestion() {
        guard canGoForward else { return }
        currentQuestionIndex += 1
        resetInputState()
        loadCurrentQuestionState()
    }

    func goToPreviousQuestion() {
        guard canGoBack else { return }
        currentQuestionIndex -= 1
        resetInputState()
        loadCurrentQuestionState()
    }

    func goToQuestion(at index: Int) {
        guard index >= 0, index < questions.count else { return }
        currentQuestionIndex = index
        resetInputState()
        loadCurrentQuestionState()
    }

    // MARK: - Response Handling

    func selectOption(_ option: SurveyResponseOption) async {
        guard let question = currentQuestion else { return }

        switch question.type {
        case .singleSelect:
            await saveSingleSelectResponse(option)
        case .multiSelect, .multiSelectTrimmed:
            toggleMultiSelectOption(option)
        case .rank:
            toggleRankOption(option)
        default:
            break
        }
    }

    func toggleMultiSelectOption(_ option: SurveyResponseOption) {
        if selectedOptionIds.contains(option.id) {
            selectedOptionIds.remove(option.id)
        } else {
            selectedOptionIds.insert(option.id)
        }
    }

    func toggleRankOption(_ option: SurveyResponseOption) {
        if let index = rankedOptions.firstIndex(where: { $0.id == option.id }) {
            rankedOptions.remove(at: index)
        } else {
            rankedOptions.append(option)
        }
    }

    func moveRankedOption(from source: IndexSet, to destination: Int) {
        rankedOptions.move(fromOffsets: source, toOffset: destination)
    }

    func isOptionSelected(_ option: SurveyResponseOption) -> Bool {
        guard let question = currentQuestion else { return false }

        switch question.type {
        case .singleSelect:
            return question.currentResponse?.responseOptionId == option.id
        case .multiSelect, .multiSelectTrimmed:
            return selectedOptionIds.contains(option.id)
        case .rank:
            return rankedOptions.contains(where: { $0.id == option.id })
        default:
            return false
        }
    }

    func rankPosition(for option: SurveyResponseOption) -> Int? {
        guard let index = rankedOptions.firstIndex(where: { $0.id == option.id }) else { return nil }
        return index + 1
    }

    // MARK: - Save Responses

    func saveSingleSelectResponse(_ option: SurveyResponseOption) async {
        guard let question = currentQuestion else { return }
        isSaving = true

        do {
            let patientId = try await getPatientId()
            let response = try await service.saveResponse(
                patientId: patientId,
                questionNumber: question.questionNumber,
                responseOptionId: option.id,
                responseText: option.optionText,
                responseValue: option.score
            )

            // Update local state
            if let index = questions.firstIndex(where: { $0.id == question.id }) {
                questions[index].currentResponse = response
            }

            await updateProgress()
            isSaving = false
        } catch {
            self.error = error.localizedDescription
            isSaving = false
        }
    }

    func saveMultiSelectResponse() async {
        guard let question = currentQuestion else { return }
        guard !selectedOptionIds.isEmpty else { return }
        isSaving = true

        do {
            let patientId = try await getPatientId()
            try await service.saveMultiSelectResponse(
                patientId: patientId,
                questionNumber: question.questionNumber,
                selectedOptionIds: Array(selectedOptionIds)
            )

            // Refetch the response to update local state
            let responses = try await service.fetchPatientResponses(patientId: patientId, forSection: question.sectionId)
            if let response = responses.first(where: { $0.questionNumber == question.questionNumber }),
               let index = questions.firstIndex(where: { $0.id == question.id }) {
                questions[index].currentResponse = response
            }

            await updateProgress()
            isSaving = false
        } catch {
            self.error = error.localizedDescription
            isSaving = false
        }
    }

    func saveRankResponse() async {
        guard let question = currentQuestion else { return }
        guard !rankedOptions.isEmpty else { return }
        isSaving = true

        do {
            let patientId = try await getPatientId()
            // Store ranked order as comma-separated option IDs
            let rankedText = rankedOptions.map { $0.optionId }.joined(separator: ",")

            let response = try await service.saveResponse(
                patientId: patientId,
                questionNumber: question.questionNumber,
                responseOptionId: rankedOptions.first?.id,
                responseText: rankedText,
                responseValue: nil
            )

            if let index = questions.firstIndex(where: { $0.id == question.id }) {
                questions[index].currentResponse = response
            }

            await updateProgress()
            isSaving = false
        } catch {
            self.error = error.localizedDescription
            isSaving = false
        }
    }

    func saveFreeResponseAnswer() async {
        guard let question = currentQuestion else { return }
        guard !freeResponseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSaving = true

        do {
            let patientId = try await getPatientId()
            let response = try await service.saveResponse(
                patientId: patientId,
                questionNumber: question.questionNumber,
                responseOptionId: nil,
                responseText: freeResponseText,
                responseValue: nil
            )

            if let index = questions.firstIndex(where: { $0.id == question.id }) {
                questions[index].currentResponse = response
            }

            await updateProgress()
            isSaving = false
        } catch {
            self.error = error.localizedDescription
            isSaving = false
        }
    }

    // MARK: - Helper Methods

    private func resetInputState() {
        selectedOptionIds = []
        freeResponseText = ""
        rankedOptions = []
    }

    private func loadCurrentQuestionState() {
        guard let question = currentQuestion,
              let response = question.currentResponse else { return }

        switch question.type {
        case .multiSelect, .multiSelectTrimmed:
            // Parse stored option IDs
            if let text = response.responseText {
                let ids = text.split(separator: ",").compactMap { UUID(uuidString: String($0)) }
                selectedOptionIds = Set(ids)
            }
        case .rank:
            // Parse ranked order
            if let text = response.responseText {
                let optionIds = text.split(separator: ",").map { String($0) }
                rankedOptions = optionIds.compactMap { optionId in
                    question.options.first { $0.optionId == optionId }
                }
            }
        case .freeResponse:
            freeResponseText = response.responseText ?? ""
        default:
            break
        }
    }

    private func updateProgress() async {
        do {
            let patientId = try await getPatientId()
            let newProgress = try await service.getSurveyProgress(patientId: patientId)
            progress = newProgress

            // Update section counts
            for i in 0..<sections.count {
                if let sectionProgress = newProgress.sectionProgress[sections[i].sectionId] {
                    sections[i].answeredCount = sectionProgress.answeredQuestions
                }
            }
        } catch {
            print("Failed to update progress: \(error)")
        }
    }

    // MARK: - Onboarding Flow

    func loadOnboardingQuestions() async {
        isLoading = true
        error = nil

        do {
            let patientId = try await getPatientId()
            var loadedQuestions = try await service.fetchAllQuestions()

            // Load existing responses
            let responses = try await service.fetchPatientResponses(patientId: patientId)
            let responsesByQuestion = Dictionary(grouping: responses) { $0.questionNumber }

            // Map responses to questions
            for i in 0..<loadedQuestions.count {
                loadedQuestions[i].currentResponse = responsesByQuestion[loadedQuestions[i].questionNumber]?.first
            }

            questions = loadedQuestions

            // Find first unanswered question
            if let firstUnansweredIndex = loadedQuestions.firstIndex(where: { $0.currentResponse == nil }) {
                currentQuestionIndex = firstUnansweredIndex
            } else {
                currentQuestionIndex = 0
            }

            resetInputState()
            loadCurrentQuestionState()
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    func getFirstUnansweredSection() -> SurveySection? {
        return sections.first { !$0.isComplete }
    }
}
