//
//  EducationService.swift
//  WellPath
//
//  Service for AI-powered education content via generate-education edge function
//  Supports static content, personalized insights, and Q&A
//

import Foundation
import Supabase

// MARK: - Education Service

@MainActor
class EducationService: ObservableObject {
    static let shared = EducationService()

    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    private init() {}

    // MARK: - Public Methods

    /// Get static education content for a view
    func getStaticContent(viewId: String) async throws -> EducationStaticContent? {
        isLoading = true
        error = nil
        defer { isLoading = false }

        let request = EducationRequest(
            action: .getStatic,
            viewId: viewId,
            patientId: nil,
            question: nil,
            forceRefresh: nil
        )

        let response: EducationResponse = try await invokeEducationFunction(request)

        guard response.success else {
            throw EducationError.apiError(response.error ?? "Unknown error")
        }

        return response.content
    }

    /// Ask a question about a health metric (personalized, on-demand)
    func askQuestion(viewId: String, question: String) async throws -> EducationQAResponse {
        isLoading = true
        error = nil
        defer { isLoading = false }

        let patientId = try await supabase.auth.session.user.id

        let request = EducationRequest(
            action: .askQuestion,
            viewId: viewId,
            patientId: patientId,
            question: question,
            forceRefresh: nil
        )

        let response: EducationResponse = try await invokeEducationFunction(request)

        guard response.success, let answer = response.answer else {
            throw EducationError.apiError(response.error ?? "No answer received")
        }

        return EducationQAResponse(
            answer: answer,
            tokensUsed: response.tokensUsed,
            responseTimeMs: response.responseTimeMs
        )
    }

    // MARK: - Private Methods

    private func invokeEducationFunction(_ request: EducationRequest) async throws -> EducationResponse {
        do {
            // Supabase Swift SDK decodes directly to the specified type
            let educationResponse: EducationResponse = try await supabase.functions.invoke(
                "generate-education",
                options: FunctionInvokeOptions(body: request)
            )

            return educationResponse

        } catch let decodingError as DecodingError {
            print("❌ EducationService decode error: \(decodingError)")
            throw EducationError.decodingError(decodingError.localizedDescription)
        } catch {
            print("❌ EducationService invoke error: \(error)")
            throw EducationError.networkError(error.localizedDescription)
        }
    }
}

// MARK: - Q&A Response

struct EducationQAResponse {
    let answer: String
    let tokensUsed: Int?
    let responseTimeMs: Int?
}

// MARK: - Education Error

enum EducationError: LocalizedError {
    case apiError(String)
    case networkError(String)
    case decodingError(String)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .apiError(let message):
            return "API Error: \(message)"
        case .networkError(let message):
            return "Network Error: \(message)"
        case .decodingError(let message):
            return "Decoding Error: \(message)"
        case .notAuthenticated:
            return "Not authenticated"
        }
    }
}

// MARK: - Education Q&A View Model

@MainActor
class EducationQAViewModel: ObservableObject {
    @Published var question: String = ""
    @Published var answer: String?
    @Published var isLoading = false
    @Published var error: String?
    @Published var conversationHistory: [QAMessage] = []
    @Published var suggestedQuestions: [String] = []

    private let service = EducationService.shared
    let viewId: String
    let viewName: String

    // Default questions (used if database doesn't have custom ones)
    private let defaultQuestions = [
        "What does my current value mean?",
        "How can I improve this metric?",
        "What's the ideal range for my age?"
    ]

    init(viewId: String, viewName: String) {
        self.viewId = viewId
        self.viewName = viewName
        self.suggestedQuestions = defaultQuestions
    }

    /// Load suggested questions from database (call on appear)
    func loadSuggestedQuestions() async {
        do {
            if let staticContent = try await service.getStaticContent(viewId: viewId),
               let dbQuestions = staticContent.suggestedQuestions,
               !dbQuestions.isEmpty {
                self.suggestedQuestions = dbQuestions
            }
        } catch {
            // Keep default questions on error
            print("Failed to load suggested questions: \(error)")
        }
    }

    func askQuestion() async {
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isLoading = true
        error = nil

        let userQuestion = question
        question = ""  // Clear input

        // Add user message to history
        conversationHistory.append(QAMessage(role: .user, content: userQuestion))

        do {
            let response = try await service.askQuestion(viewId: viewId, question: userQuestion)
            answer = response.answer

            // Add assistant response to history
            conversationHistory.append(QAMessage(role: .assistant, content: response.answer))

        } catch {
            self.error = error.localizedDescription
            // Remove the user message if there was an error
            conversationHistory.removeLast()
        }

        isLoading = false
    }

    func clearConversation() {
        conversationHistory.removeAll()
        answer = nil
        error = nil
    }
}

// MARK: - Q&A Message

struct QAMessage: Identifiable {
    let id = UUID()
    let role: QARole
    let content: String
    let timestamp = Date()

    enum QARole {
        case user
        case assistant
    }
}
