//
//  TourQuestionsSection.swift
//  WellPath
//
//  Embeddable component that shows baseline survey questions on metric screens.
//  Can be added to any screen to collect baseline data for that metric.
//

import SwiftUI
import Supabase

/// A section that displays baseline survey questions for a specific metric screen.
/// Add this to any metric view to show tour questions when they haven't been answered.
struct TourQuestionsSection: View {
    let screenId: String
    let color: Color

    @StateObject private var viewModel = TourQuestionsSectionViewModel()
    @State private var isExpanded = true

    var body: some View {
        if viewModel.isLoading {
            loadingView
        } else if !viewModel.questions.isEmpty && !viewModel.hasAnsweredAllQuestions {
            questionsCard
        }
        // If no questions or all answered, show nothing
    }

    // MARK: - Loading

    private var loadingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading baseline questions...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .task {
            await viewModel.loadQuestions(for: screenId)
        }
    }

    // MARK: - Questions Card

    private var questionsCard: some View {
        VStack(spacing: 0) {
            // Header (always visible, tappable to expand/collapse)
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "clipboard.fill")
                        .foregroundColor(color)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Set Your Baseline")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("\(viewModel.answeredCount)/\(viewModel.questions.count) questions answered")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
            }
            .buttonStyle(.plain)

            // Expandable content
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()

                    ForEach(viewModel.questions) { question in
                        EmbeddedQuestionRow(
                            question: question,
                            response: Binding(
                                get: { viewModel.responses[question.questionNumber] },
                                set: { viewModel.responses[question.questionNumber] = $0 }
                            ),
                            viewModel: viewModel,
                            color: color
                        )

                        if question.id != viewModel.questions.last?.id {
                            Divider()
                        }
                    }

                    // Save button
                    Button {
                        Task {
                            await viewModel.saveResponses()
                        }
                    } label: {
                        HStack {
                            if viewModel.isSaving {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }
                            Text(viewModel.isSaving ? "Saving..." : "Save Baseline")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(viewModel.hasAnsweredAny ? color : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!viewModel.hasAnsweredAny || viewModel.isSaving)

                    if viewModel.saveSuccess {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Baseline saved!")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        .transition(.opacity)
                    }
                }
                .padding([.horizontal, .bottom])
                .background(Color(.secondarySystemGroupedBackground))
            }
        }
        .cornerRadius(12)
        .task {
            await viewModel.loadQuestions(for: screenId)
        }
    }
}

// MARK: - ViewModel

@MainActor
class TourQuestionsSectionViewModel: ObservableObject {
    @Published var questions: [TourQuestion] = []
    @Published var responses: [Decimal: TourResponse] = [:]
    @Published var isLoading = true
    @Published var isSaving = false
    @Published var saveSuccess = false

    var hasAnsweredAny: Bool {
        responses.values.contains { $0.hasResponse }
    }

    var hasAnsweredAllQuestions: Bool {
        guard !questions.isEmpty else { return false }
        return questions.allSatisfy { question in
            responses[question.questionNumber]?.hasResponse ?? false
        }
    }

    var answeredCount: Int {
        questions.filter { question in
            responses[question.questionNumber]?.hasResponse ?? false
        }.count
    }

    func loadQuestions(for screenId: String) async {
        isLoading = true

        let manager = OnboardingTourManager()
        questions = await manager.loadQuestionsForScreen(screenId)

        // Also load existing responses
        await loadExistingResponses()

        isLoading = false
    }

    private func loadExistingResponses() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

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
            guard !questionNumbers.isEmpty else { return }

            let existingResponses: [ExistingResponse] = try await client
                .from("patient_survey_responses")
                .select("question_number, response_option_id, response_text, response_numeric")
                .eq("patient_id", value: userId.uuidString)
                .in("question_number", values: questionNumbers.map { "\($0)" })
                .execute()
                .value

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

    func saveResponses() async {
        isSaving = true
        saveSuccess = false

        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            for question in questions {
                guard let response = responses[question.questionNumber],
                      response.hasResponse else { continue }

                if !response.selectedOptionIds.isEmpty {
                    for optionId in response.selectedOptionIds {
                        let option = question.options.first { $0.id == optionId }

                        let record: [String: AnyJSON] = [
                            "patient_id": .string(userId.uuidString),
                            "question_number": .double(NSDecimalNumber(decimal: question.questionNumber).doubleValue),
                            "response_option_id": .string(optionId.uuidString),
                            "response_text": .string(option?.optionText ?? ""),
                            "source": .string("metric_screen")
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
                        "source": .string("metric_screen")
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
                        "source": .string("metric_screen")
                    ]

                    try await client
                        .from("patient_survey_responses")
                        .upsert(record, onConflict: "patient_id,question_number")
                        .execute()
                }
            }

            saveSuccess = true

            // Hide success message after delay
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            saveSuccess = false

        } catch {
            print("Error saving responses: \(error)")
        }

        isSaving = false
    }

    // MARK: - Response Handlers

    func toggleOption(_ optionId: UUID, for question: TourQuestion) {
        var response = responses[question.questionNumber] ?? TourResponse(
            questionId: question.id,
            questionNumber: question.questionNumber
        )

        switch question.questionType {
        case .singleSelect:
            response.selectedOptionIds = [optionId]
        case .multiSelect, .multiSelectWithOther:
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
}

// MARK: - Embedded Question Row

struct EmbeddedQuestionRow: View {
    let question: TourQuestion
    @Binding var response: TourResponse?
    @ObservedObject var viewModel: TourQuestionsSectionViewModel
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question text
            HStack(alignment: .top) {
                Text(question.questionText.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.subheadline)
                    .foregroundColor(.primary)

                if question.isRequired {
                    Text("*")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            // Answer input based on type
            switch question.questionType {
            case .singleSelect:
                singleSelectView
            case .multiSelect, .multiSelectWithOther:
                multiSelectView
            case .freeResponse:
                freeResponseView
            case .numeric:
                numericView
            case .rank:
                multiSelectView
            }
        }
    }

    private var singleSelectView: some View {
        VStack(spacing: 8) {
            ForEach(question.options.sorted { $0.optionOrder < $1.optionOrder }) { option in
                Button {
                    viewModel.toggleOption(option.id, for: question)
                } label: {
                    HStack {
                        Image(systemName: isSelected(option) ? "circle.fill" : "circle")
                            .foregroundColor(isSelected(option) ? color : .secondary)

                        Text(option.optionText)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)

                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(isSelected(option) ? color.opacity(0.1) : Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var multiSelectView: some View {
        VStack(spacing: 8) {
            ForEach(question.options.sorted { $0.optionOrder < $1.optionOrder }) { option in
                Button {
                    viewModel.toggleOption(option.id, for: question)
                } label: {
                    HStack {
                        Image(systemName: isSelected(option) ? "checkmark.square.fill" : "square")
                            .foregroundColor(isSelected(option) ? color : .secondary)

                        Text(option.optionText)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)

                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(isSelected(option) ? color.opacity(0.1) : Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var freeResponseView: some View {
        TextField("Enter your response...", text: Binding(
            get: { response?.freeTextResponse ?? "" },
            set: { viewModel.setFreeText($0, for: question) }
        ))
        .textFieldStyle(.roundedBorder)
    }

    private var numericView: some View {
        HStack {
            TextField("Enter value", value: Binding(
                get: { response?.numericResponse },
                set: { viewModel.setNumeric($0, for: question) }
            ), format: .number)
            .textFieldStyle(.roundedBorder)
            .keyboardType(.decimalPad)
            .frame(width: 120)

            Spacer()
        }
    }

    private func isSelected(_ option: TourQuestionOption) -> Bool {
        response?.selectedOptionIds.contains(option.id) ?? false
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            TourQuestionsSection(screenId: "SCREEN_PROTEIN", color: .green)
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
