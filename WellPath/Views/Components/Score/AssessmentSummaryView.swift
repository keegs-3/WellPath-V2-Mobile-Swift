//
//  AssessmentSummaryView.swift
//  WellPath
//
//  Database-driven assessment summary visualization.
//  Shows Q&A summary with questions and patient responses.
//  Used for: assessment scores (sleep_apnea_management_score, etc.)
//

import SwiftUI
import Supabase

// MARK: - Models

struct AssessmentQuestionData: Identifiable, Codable {
    let id: UUID
    let questionId: String
    let questionText: String
    let questionType: String  // single_choice, multiple_choice, slider, boolean
    let baselineType: String
    let displayOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case questionId = "question_id"
        case questionText = "question_text"
        case questionType = "question_type"
        case baselineType = "baseline_type"
        case displayOrder = "display_order"
    }
}

struct AssessmentResponseOption: Identifiable, Codable {
    let id: UUID
    let optionValue: String
    let optionLabel: String
    let scoreImpact: Double?
    let displayOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case optionValue = "option_value"
        case optionLabel = "option_label"
        case scoreImpact = "score_impact"
        case displayOrder = "display_order"
    }
}

/// Patient's response to a question
struct PatientResponse: Codable {
    let baselineType: String
    let stringValue: String?
    let numericValue: Double?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case baselineType = "baseline_type"
        case stringValue = "string_value"
        case numericValue = "numeric_value"
        case createdAt = "created_at"
    }
}

/// Combined question + response for display
struct QuestionResponsePair: Identifiable {
    let id: String
    let question: AssessmentQuestionData
    let responseLabel: String
    let responseValue: String?
    let isAnswered: Bool
}

// MARK: - ViewModel

@MainActor
class AssessmentSummaryViewModel: ObservableObject {
    @Published var questions: [AssessmentQuestionData] = []
    @Published var responseOptions: [String: [AssessmentResponseOption]] = [:]  // questionId -> options
    @Published var patientResponses: [String: PatientResponse] = [:]  // baselineType -> response
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    /// Load assessment questions and patient responses for baseline types
    func loadAssessment(baselineTypes: [String]) async {
        isLoading = true
        error = nil

        do {
            // Load questions for these baseline types
            let questionResults: [AssessmentQuestionData] = try await supabase
                .from("baseline_questions")
                .select("id, question_id, question_text, question_type, baseline_type, display_order")
                .in("baseline_type", values: baselineTypes)
                .eq("is_active", value: true)
                .order("display_order", ascending: true)
                .execute()
                .value

            questions = questionResults

            // Load response options for choice questions
            let choiceQuestionIds = questionResults
                .filter { ["single_choice", "multiple_choice"].contains($0.questionType) }
                .map { $0.questionId }

            if !choiceQuestionIds.isEmpty {
                struct ResponseOptionRow: Codable {
                    let id: UUID
                    let questionId: String
                    let optionValue: String
                    let optionLabel: String
                    let scoreImpact: Double?
                    let displayOrder: Int?

                    enum CodingKeys: String, CodingKey {
                        case id
                        case questionId = "question_id"
                        case optionValue = "option_value"
                        case optionLabel = "option_label"
                        case scoreImpact = "score_impact"
                        case displayOrder = "display_order"
                    }
                }

                let optionResults: [ResponseOptionRow] = try await supabase
                    .from("baseline_question_options")
                    .select("id, question_id, option_value, option_label, score_impact, display_order")
                    .in("question_id", values: choiceQuestionIds)
                    .eq("is_active", value: true)
                    .order("display_order", ascending: true)
                    .execute()
                    .value

                var optionsMap: [String: [AssessmentResponseOption]] = [:]
                for row in optionResults {
                    let option = AssessmentResponseOption(
                        id: row.id,
                        optionValue: row.optionValue,
                        optionLabel: row.optionLabel,
                        scoreImpact: row.scoreImpact,
                        displayOrder: row.displayOrder
                    )
                    optionsMap[row.questionId, default: []].append(option)
                }
                responseOptions = optionsMap
            }

            // Load patient responses
            let userId = try await supabase.auth.session.user.id

            let responseResults: [PatientResponse] = try await supabase
                .from("patient_baseline_samples")
                .select("baseline_type, string_value, numeric_value, created_at")
                .eq("patient_id", value: userId.uuidString)
                .in("baseline_type", values: baselineTypes)
                .eq("is_current", value: true)
                .execute()
                .value

            var responsesMap: [String: PatientResponse] = [:]
            for response in responseResults {
                responsesMap[response.baselineType] = response
            }
            patientResponses = responsesMap

        } catch {
            self.error = error.localizedDescription
            print("Error loading assessment: \(error)")
        }

        isLoading = false
    }

    /// Build question-response pairs for display
    func buildQuestionResponsePairs() -> [QuestionResponsePair] {
        questions.map { question in
            let response = patientResponses[question.baselineType]
            let (label, value) = formatResponse(for: question, response: response)

            return QuestionResponsePair(
                id: question.questionId,
                question: question,
                responseLabel: label,
                responseValue: value,
                isAnswered: response != nil
            )
        }
    }

    private func formatResponse(
        for question: AssessmentQuestionData,
        response: PatientResponse?
    ) -> (label: String, value: String?) {
        guard let response = response else {
            return ("Not answered", nil)
        }

        switch question.questionType {
        case "single_choice", "multiple_choice":
            // Look up option label
            if let stringValue = response.stringValue,
               let options = responseOptions[question.questionId],
               let option = options.first(where: { $0.optionValue == stringValue }) {
                return (option.optionLabel, stringValue)
            }
            return (response.stringValue ?? "Unknown", response.stringValue)

        case "boolean":
            if let stringValue = response.stringValue {
                let isYes = ["true", "yes", "1"].contains(stringValue.lowercased())
                return (isYes ? "Yes" : "No", stringValue)
            }
            return ("Not answered", nil)

        case "slider", "numeric":
            if let numericValue = response.numericValue {
                return (String(format: "%.0f", numericValue), String(numericValue))
            }
            return ("Not answered", nil)

        case "text":
            if let stringValue = response.stringValue {
                return (stringValue, stringValue)
            }
            return ("Not answered", nil)

        default:
            return (response.stringValue ?? "Unknown", response.stringValue)
        }
    }
}

// MARK: - View

struct AssessmentSummaryView: View {
    let title: String
    let baselineTypes: [String]
    let score: Int?
    let color: Color

    @StateObject private var viewModel = AssessmentSummaryViewModel()

    init(
        title: String,
        baselineTypes: [String],
        score: Int? = nil,
        color: Color = .purple
    ) {
        self.title = title
        self.baselineTypes = baselineTypes
        self.score = score
        self.color = color
    }

    private var questionResponsePairs: [QuestionResponsePair] {
        viewModel.buildQuestionResponsePairs()
    }

    private var answeredCount: Int {
        questionResponsePairs.filter { $0.isAnswered }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with progress
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if !questionResponsePairs.isEmpty {
                    Text("\(answeredCount)/\(questionResponsePairs.count) answered")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if questionResponsePairs.isEmpty {
                Text("No assessment questions available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                // Q&A list
                VStack(spacing: 12) {
                    ForEach(questionResponsePairs) { pair in
                        questionResponseRow(pair)
                    }
                }

                // Score display
                if let score = score {
                    HStack {
                        Spacer()
                        Text("Assessment Score: \(score)/100")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(scoreColor(for: score))
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .task {
            await viewModel.loadAssessment(baselineTypes: baselineTypes)
        }
    }

    @ViewBuilder
    private func questionResponseRow(_ pair: QuestionResponsePair) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Question
            HStack(alignment: .top, spacing: 8) {
                Text("Q:")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                Text(pair.question.questionText)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }

            // Answer
            HStack(alignment: .top, spacing: 8) {
                Text("A:")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(pair.isAnswered ? .green : .secondary)
                Text(pair.responseLabel)
                    .font(.subheadline)
                    .foregroundColor(pair.isAnswered ? .primary : .secondary)
                    .italic(!pair.isAnswered)
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }

    private func scoreColor(for score: Int) -> Color {
        if score >= 80 { return .green }
        else if score >= 60 { return .yellow }
        else if score >= 40 { return .orange }
        else { return .red }
    }
}

// MARK: - Compact Variant

struct AssessmentCompactView: View {
    let answeredCount: Int
    let totalCount: Int
    let score: Int?

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text("\(answeredCount)/\(totalCount)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(answeredCount == totalCount ? .green : .orange)
                Text("answered")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let score = score {
                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(scoreColor(for: score))
                    Text("score")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func scoreColor(for score: Int) -> Color {
        if score >= 80 { return .green }
        else if score >= 60 { return .yellow }
        else if score >= 40 { return .orange }
        else { return .red }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            AssessmentSummaryView(
                title: "Sleep Apnea Management",
                baselineTypes: [
                    "sleep_apnea_cpap_usage",
                    "sleep_apnea_mask_cleaning",
                    "sleep_apnea_recent_study"
                ],
                score: 85,
                color: .purple
            )
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
