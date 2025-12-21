//
//  OnboardingTourManager.swift
//  WellPath
//
//  Manages the onboarding tour state, navigation, and data persistence
//

import Foundation
import SwiftUI
import Supabase

@MainActor
class OnboardingTourManager: ObservableObject {
    // MARK: - Published State

    @Published var isLoading = false
    @Published var error: String?

    // Tour structure
    @Published var allScreens: [TourScreen] = []
    @Published var screensBySection: [TourSection: [TourScreen]] = [:]

    // Current position
    @Published var currentSectionIndex: Int = 0
    @Published var currentScreenIndexInSection: Int = 0
    @Published var progress: TourProgress = TourProgress()

    // Questions for current screen
    @Published var currentQuestions: [TourQuestion] = []
    @Published var responses: [Decimal: TourResponse] = [:] // keyed by question_number

    // Tour mode
    @Published var isInTourMode: Bool = false

    // MARK: - Computed Properties

    var sections: [TourSection] {
        TourSection.allCases.sorted { $0.order < $1.order }
    }

    var currentSection: TourSection? {
        guard currentSectionIndex < sections.count else { return nil }
        return sections[currentSectionIndex]
    }

    var currentScreen: TourScreen? {
        guard let section = currentSection,
              let screens = screensBySection[section],
              currentScreenIndexInSection < screens.count else { return nil }
        return screens[currentScreenIndexInSection]
    }

    var screensInCurrentSection: [TourScreen] {
        guard let section = currentSection else { return [] }
        return screensBySection[section] ?? []
    }

    var totalScreens: Int {
        allScreens.count
    }

    var completedScreens: Int {
        progress.completedScreenIds.count
    }

    var overallProgress: Double {
        guard totalScreens > 0 else { return 0 }
        return Double(completedScreens) / Double(totalScreens)
    }

    var currentScreenNumber: Int {
        var count = 0
        for i in 0..<currentSectionIndex {
            count += screensBySection[sections[i]]?.count ?? 0
        }
        count += currentScreenIndexInSection + 1
        return count
    }

    var isFirstScreen: Bool {
        currentSectionIndex == 0 && currentScreenIndexInSection == 0
    }

    var isLastScreen: Bool {
        guard let section = currentSection,
              let screens = screensBySection[section] else { return false }
        return currentSectionIndex == sections.count - 1 &&
               currentScreenIndexInSection == screens.count - 1
    }

    var hasUnansweredRequiredQuestions: Bool {
        currentQuestions.filter { $0.isRequired }.contains { question in
            guard let response = responses[question.questionNumber] else { return true }
            return !response.hasResponse
        }
    }

    // MARK: - Initialization

    init() {}

    // MARK: - Tour Lifecycle

    func startTour() async {
        isInTourMode = true
        isLoading = true
        error = nil

        do {
            // Load all tour screens
            try await loadTourScreens()

            // Load progress if any
            await loadProgress()

            // Load questions for current screen
            await loadQuestionsForCurrentScreen()

            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    func endTour() {
        isInTourMode = false
        // Save final progress
        Task {
            await saveProgress()
        }
    }

    // MARK: - Navigation

    func nextScreen() async {
        // Save current responses first
        await saveCurrentResponses()

        // Mark current screen as completed
        if let screen = currentScreen {
            progress.completedScreenIds.insert(screen.screenId)
        }

        // Move to next screen
        guard let section = currentSection,
              let screens = screensBySection[section] else { return }

        if currentScreenIndexInSection < screens.count - 1 {
            // Next screen in current section
            currentScreenIndexInSection += 1
        } else if currentSectionIndex < sections.count - 1 {
            // Move to next section
            if let section = currentSection {
                progress.completedSectionIds.insert(section.rawValue)
            }
            currentSectionIndex += 1
            currentScreenIndexInSection = 0
        } else {
            // Tour complete
            await completeTour()
            return
        }

        // Update progress
        progress.currentSectionIndex = currentSectionIndex
        progress.currentScreenIndex = currentScreenIndexInSection

        // Load questions for new screen
        await loadQuestionsForCurrentScreen()
        await saveProgress()
    }

    func previousScreen() async {
        guard let section = currentSection else { return }

        if currentScreenIndexInSection > 0 {
            // Previous screen in current section
            currentScreenIndexInSection -= 1
        } else if currentSectionIndex > 0 {
            // Move to previous section
            currentSectionIndex -= 1
            if let prevSection = currentSection,
               let screens = screensBySection[prevSection] {
                currentScreenIndexInSection = screens.count - 1
            }
        }

        progress.currentSectionIndex = currentSectionIndex
        progress.currentScreenIndex = currentScreenIndexInSection

        await loadQuestionsForCurrentScreen()
    }

    func skipCurrentScreen() async {
        // Don't mark as completed, just move on
        await nextScreen()
    }

    func jumpToSection(_ section: TourSection) async {
        guard let index = sections.firstIndex(of: section) else { return }
        currentSectionIndex = index
        currentScreenIndexInSection = 0
        await loadQuestionsForCurrentScreen()
    }

    // MARK: - Screen Questions (for embedded mode)

    /// Load questions for a specific screen (used when embedding tour questions in real views)
    func loadQuestionsForScreen(_ screenId: String) async -> [TourQuestion] {
        do {
            let client = SupabaseManager.shared.client

            let questions: [TourQuestion] = try await client
                .from("survey_questions_base")
                .select("""
                    id,
                    question_number,
                    question_text,
                    type,
                    target_screen_id,
                    display_order_in_screen,
                    is_required,
                    baseline_type,
                    survey_response_options(
                        option_id:id,
                        option_text,
                        option_order:question_response_order
                    )
                """)
                .eq("target_screen_id", value: screenId)
                .eq("is_active", value: true)
                .order("display_order_in_screen")
                .execute()
                .value

            // Load existing responses
            await loadExistingResponses(for: questions)

            return questions
        } catch {
            print("Error loading questions for screen \(screenId): \(error)")
            return []
        }
    }

    // MARK: - Data Loading

    private func loadTourScreens() async throws {
        let client = SupabaseManager.shared.client

        let response: [TourScreen] = try await client
            .from("onboarding_tour_screens")
            .select()
            .eq("is_active", value: true)
            .order("display_order")
            .execute()
            .value

        allScreens = response

        // Group by section
        var grouped: [TourSection: [TourScreen]] = [:]
        for screen in response {
            grouped[screen.tourSection, default: []].append(screen)
        }
        screensBySection = grouped
    }

    func loadQuestionsForCurrentScreen() async {
        guard let screen = currentScreen else {
            currentQuestions = []
            return
        }

        do {
            let client = SupabaseManager.shared.client

            // Load questions for this screen
            let questions: [TourQuestion] = try await client
                .from("survey_questions_base")
                .select("""
                    id,
                    question_number,
                    question_text,
                    type,
                    target_screen_id,
                    display_order_in_screen,
                    is_required,
                    baseline_type,
                    survey_response_options(
                        option_id:id,
                        option_text,
                        option_order:question_response_order
                    )
                """)
                .eq("target_screen_id", value: screen.screenId)
                .eq("is_active", value: true)
                .order("display_order_in_screen")
                .execute()
                .value

            currentQuestions = questions

            // Load existing responses for these questions
            await loadExistingResponses(for: questions)

        } catch {
            print("Error loading questions for screen \(screen.screenId): \(error)")
            currentQuestions = []
        }
    }

    private func loadExistingResponses(for questions: [TourQuestion]) async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            // Get existing responses
            struct ExistingResponse: Decodable {
                let questionNumber: Decimal
                let responseOptionId: UUID?
                let responseText: String?
                let responseNumeric: Double?

                enum CodingKeys: String, CodingKey {
                    case questionNumber = "question_number"
                    case responseOptionId = "response_option_id"
                    case responseText = "response_text"
                    case responseNumeric = "response_numeric"
                }
            }

            let questionNumbers = questions.map { $0.questionNumber }

            let existingResponses: [ExistingResponse] = try await client
                .from("patient_survey_responses")
                .select("question_number, response_option_id, response_text, response_numeric")
                .eq("patient_id", value: userId.uuidString)
                .in("question_number", values: questionNumbers.map { "\($0)" })
                .execute()
                .value

            // Build response map
            for existing in existingResponses {
                var response = responses[existing.questionNumber] ?? TourResponse(
                    questionId: questions.first { $0.questionNumber == existing.questionNumber }?.id ?? UUID(),
                    questionNumber: existing.questionNumber
                )

                if let optionId = existing.responseOptionId {
                    response.selectedOptionIds.insert(optionId)
                }
                if let text = existing.responseText {
                    response.freeTextResponse = text
                }
                if let numeric = existing.responseNumeric {
                    response.numericResponse = numeric
                }

                responses[existing.questionNumber] = response
            }

        } catch {
            print("Error loading existing responses: \(error)")
        }
    }

    // MARK: - Response Handling

    func toggleOption(_ optionId: UUID, for question: TourQuestion) {
        var response = responses[question.questionNumber] ?? TourResponse(
            questionId: question.id,
            questionNumber: question.questionNumber
        )

        switch question.questionType {
        case .singleSelect:
            // Clear previous and set new
            response.selectedOptionIds = [optionId]
        case .multiSelect, .multiSelectWithOther:
            // Toggle
            if response.selectedOptionIds.contains(optionId) {
                response.selectedOptionIds.remove(optionId)
            } else {
                response.selectedOptionIds.insert(optionId)
            }
        default:
            break
        }

        responses[question.questionNumber] = response
    }

    func setFreeText(_ text: String, for question: TourQuestion) {
        var response = responses[question.questionNumber] ?? TourResponse(
            questionId: question.id,
            questionNumber: question.questionNumber
        )
        response.freeTextResponse = text
        responses[question.questionNumber] = response
    }

    func setNumeric(_ value: Double?, for question: TourQuestion) {
        var response = responses[question.questionNumber] ?? TourResponse(
            questionId: question.id,
            questionNumber: question.questionNumber
        )
        response.numericResponse = value
        responses[question.questionNumber] = response
    }

    func setOtherText(_ text: String, for question: TourQuestion) {
        var response = responses[question.questionNumber] ?? TourResponse(
            questionId: question.id,
            questionNumber: question.questionNumber
        )
        response.otherText = text
        responses[question.questionNumber] = response
    }

    // MARK: - Persistence

    private func saveCurrentResponses() async {
        let client = SupabaseManager.shared.client

        guard let userId = try? await client.auth.session.user.id else { return }

        for question in currentQuestions {
            guard let response = responses[question.questionNumber],
                  response.hasResponse else { continue }

            do {
                // Build response records
                if !response.selectedOptionIds.isEmpty {
                    for optionId in response.selectedOptionIds {
                        let option = question.options.first { $0.id == optionId }

                        let record: [String: AnyJSON] = [
                            "patient_id": .string(userId.uuidString),
                            "question_number": .double(NSDecimalNumber(decimal: question.questionNumber).doubleValue),
                            "response_option_id": .string(optionId.uuidString),
                            "response_text": .string(option?.optionText ?? ""),
                            "source": .string("onboarding_tour")
                        ]

                        try await client
                            .from("patient_survey_responses")
                            .upsert(record, onConflict: "patient_id,question_number,response_option_id")
                            .execute()
                    }
                } else if let text = response.freeTextResponse, !text.isEmpty {
                    let record: [String: AnyJSON] = [
                        "patient_id": .string(userId.uuidString),
                        "question_number": .double(NSDecimalNumber(decimal: question.questionNumber).doubleValue),
                        "response_text": .string(text),
                        "source": .string("onboarding_tour")
                    ]

                    try await client
                        .from("patient_survey_responses")
                        .upsert(record, onConflict: "patient_id,question_number")
                        .execute()
                } else if let numeric = response.numericResponse {
                    let record: [String: AnyJSON] = [
                        "patient_id": .string(userId.uuidString),
                        "question_number": .double(NSDecimalNumber(decimal: question.questionNumber).doubleValue),
                        "response_numeric": .double(numeric),
                        "source": .string("onboarding_tour")
                    ]

                    try await client
                        .from("patient_survey_responses")
                        .upsert(record, onConflict: "patient_id,question_number")
                        .execute()
                }
            } catch {
                print("Error saving response for question \(question.questionNumber): \(error)")
            }
        }
    }

    private func saveProgress() async {
        // Save progress to UserDefaults for now (could be moved to server)
        if let data = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(data, forKey: "onboarding_tour_progress")
        }
    }

    private func loadProgress() async {
        if let data = UserDefaults.standard.data(forKey: "onboarding_tour_progress"),
           let savedProgress = try? JSONDecoder().decode(TourProgress.self, from: data) {
            progress = savedProgress
            currentSectionIndex = savedProgress.currentSectionIndex
            currentScreenIndexInSection = savedProgress.currentScreenIndex
        }
    }

    private func completeTour() async {
        // Mark tour as completed
        UserDefaults.standard.set(true, forKey: "onboarding_tour_completed")
        UserDefaults.standard.set(Date(), forKey: "onboarding_tour_completed_date")

        // Save all responses
        await saveCurrentResponses()

        // Update patient state
        await updatePatientOnboardingState()

        isInTourMode = false
    }

    private func updatePatientOnboardingState() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            try await client
                .from("patient_survey_state")
                .upsert([
                    "patient_id": userId.uuidString,
                    "lifecycle_phase": "active",
                    "onboarding_completed_at": ISO8601DateFormatter().string(from: Date())
                ] as [String: String])
                .execute()
        } catch {
            print("Error updating patient onboarding state: \(error)")
        }
    }

    // MARK: - Tour Status Check

    static func hasCompletedTour() -> Bool {
        UserDefaults.standard.bool(forKey: "onboarding_tour_completed")
    }

    static func resetTourProgress() {
        UserDefaults.standard.removeObject(forKey: "onboarding_tour_progress")
        UserDefaults.standard.removeObject(forKey: "onboarding_tour_completed")
        UserDefaults.standard.removeObject(forKey: "onboarding_tour_completed_date")
    }
}
