//
//  SurveySectionDetailView.swift
//  WellPath
//
//  Created on 2025-11-27
//

import SwiftUI

struct SurveySectionDetailView: View {
    @ObservedObject var viewModel: SurveyViewModel
    let section: SurveySection
    @State private var showingQuestion: SurveyQuestion?

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading questions...")
            } else {
                questionsList
            }
        }
        .navigationTitle(section.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.selectSection(section)
        }
        .sheet(item: $showingQuestion) { question in
            QuestionAnswerSheet(viewModel: viewModel, question: question)
        }
    }

    private var questionsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Section header
                sectionHeader

                // Questions
                ForEach(Array(viewModel.questions.enumerated()), id: \.element.id) { index, question in
                    QuestionRowView(
                        question: question,
                        index: index + 1,
                        onTap: {
                            viewModel.goToQuestion(at: index)
                            showingQuestion = question
                        }
                    )
                }
            }
            .padding()
        }
    }

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: section.iconName)
                    .font(.title2)

                VStack(alignment: .leading) {
                    Text("\(section.answeredCount) of \(section.questionCount) answered")
                        .font(.subheadline)
                    ProgressView(value: section.completionPercentage)
                        .tint(.blue)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Question Row

struct QuestionRowView: View {
    let question: SurveyQuestion
    let index: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Question number
                Text("\(index)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(question.isAnswered ? Color.green : Color.gray)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 6) {
                    // Question text
                    Text(question.cleanedQuestionText)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)

                    // Type badge
                    HStack(spacing: 8) {
                        Text(question.type.displayName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(4)

                        if question.isAnswered {
                            Label("Answered", systemImage: "checkmark")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }

                    // Current answer preview
                    if let response = question.currentResponse {
                        Text(answerPreview(for: response, question: question))
                            .font(.caption)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func answerPreview(for response: PatientSurveyResponse, question: SurveyQuestion) -> String {
        if let text = response.responseText, !text.isEmpty {
            // For multi-select, show count
            if question.type.allowsMultipleSelections {
                let count = text.split(separator: ",").count
                return "\(count) selected"
            }
            return text
        }
        if let optionId = response.responseOptionId,
           let option = question.options.first(where: { $0.id == optionId }) {
            return option.cleanedOptionText
        }
        return "Response saved"
    }
}

// MARK: - Question Answer Sheet

struct QuestionAnswerSheet: View {
    @ObservedObject var viewModel: SurveyViewModel
    let question: SurveyQuestion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Question text
                    Text(question.cleanedQuestionText)
                        .font(.title3)
                        .fontWeight(.medium)

                    // Type indicator
                    if question.type.allowsMultipleSelections {
                        Text("Select all that apply")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Answer input based on type
                    questionInput
                }
                .padding()
            }
            .navigationTitle("Q\(question.questionNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if needsSaveButton {
                        Button("Save") {
                            Task {
                                await saveResponse()
                                dismiss()
                            }
                        }
                        .disabled(viewModel.isSaving)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var questionInput: some View {
        switch question.type {
        case .singleSelect:
            singleSelectInput
        case .multiSelect, .multiSelectTrimmed:
            multiSelectInput
        case .rank:
            rankInput
        case .freeResponse:
            freeResponseInput
        default:
            Text("Question type not supported")
                .foregroundColor(.secondary)
        }
    }

    private var singleSelectInput: some View {
        VStack(spacing: 10) {
            ForEach(question.options) { option in
                Button {
                    Task {
                        await viewModel.selectOption(option)
                        dismiss()
                    }
                } label: {
                    HStack {
                        Text(option.cleanedOptionText)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        if viewModel.isOptionSelected(option) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(viewModel.isOptionSelected(option) ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(viewModel.isOptionSelected(option) ? Color.blue.opacity(0.1) : Color.clear)
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSaving)
            }
        }
    }

    private var multiSelectInput: some View {
        VStack(spacing: 10) {
            ForEach(question.options) { option in
                Button {
                    viewModel.toggleMultiSelectOption(option)
                } label: {
                    HStack {
                        Text(option.cleanedOptionText)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        if viewModel.selectedOptionIds.contains(option.id) {
                            Image(systemName: "checkmark.square.fill")
                                .foregroundColor(.blue)
                        } else {
                            Image(systemName: "square")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(viewModel.selectedOptionIds.contains(option.id) ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(viewModel.selectedOptionIds.contains(option.id) ? Color.blue.opacity(0.1) : Color.clear)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var rankInput: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tap to select, drag to reorder")
                .font(.caption)
                .foregroundColor(.secondary)

            // Ranked items
            if !viewModel.rankedOptions.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(viewModel.rankedOptions.enumerated()), id: \.element.id) { index, option in
                        HStack {
                            Text("\(index + 1)")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Color.blue)
                                .clipShape(Circle())

                            Text(option.cleanedOptionText)
                                .foregroundColor(.primary)

                            Spacer()

                            Button {
                                viewModel.toggleRankOption(option)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red.opacity(0.7))
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                    }
                }

                Divider()
                    .padding(.vertical)
            }

            // Unranked options
            let unrankedOptions = question.options.filter { option in
                !viewModel.rankedOptions.contains(where: { $0.id == option.id })
            }

            if !unrankedOptions.isEmpty {
                Text("Available options:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(unrankedOptions) { option in
                    Button {
                        viewModel.toggleRankOption(option)
                    } label: {
                        HStack {
                            Text(option.cleanedOptionText)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "plus.circle")
                                .foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var freeResponseInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $viewModel.freeResponseText)
                .frame(minHeight: 150)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)

            Text("\(viewModel.freeResponseText.count) characters")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var needsSaveButton: Bool {
        switch question.type {
        case .multiSelect, .multiSelectTrimmed, .rank, .freeResponse:
            return true
        default:
            return false
        }
    }

    private func saveResponse() async {
        switch question.type {
        case .multiSelect, .multiSelectTrimmed:
            await viewModel.saveMultiSelectResponse()
        case .rank:
            await viewModel.saveRankResponse()
        case .freeResponse:
            await viewModel.saveFreeResponseAnswer()
        default:
            break
        }
    }
}

#Preview {
    NavigationStack {
        SurveySectionDetailView(
            viewModel: SurveyViewModel(),
            section: SurveySection(
                id: UUID(),
                sectionId: "healthful_nutrition",
                pillar: "Healthful Nutrition",
                displayName: "Healthful Nutrition",
                sectionOrder: 2,
                questionCount: 68,
                answeredCount: 15
            )
        )
    }
}
