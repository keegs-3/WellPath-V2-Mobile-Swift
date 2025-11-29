//
//  QuestionFlowView.swift
//  WellPath
//
//  Question wizard for answering questions within a group.
//  Shows one question at a time with back/next navigation.
//  Uses the ViewModel's single source of truth for all response state.
//

import SwiftUI

struct QuestionFlowView: View {
    let group: SurveyGroup
    @ObservedObject var viewModel: HealthProfileViewModel
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    loadingView
                } else if viewModel.visibleQuestions.isEmpty {
                    emptyView
                } else {
                    questionContent
                }
            }
            .navigationTitle(group.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        onDismiss()
                    }
                }

                ToolbarItem(placement: .principal) {
                    progressIndicator
                }
            }
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<viewModel.visibleQuestions.count, id: \.self) { index in
                Circle()
                    .fill(progressDotColor(for: index))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private func progressDotColor(for index: Int) -> Color {
        let questions = viewModel.visibleQuestions
        guard index < questions.count else { return .gray.opacity(0.3) }

        if index == viewModel.currentQuestionIndex {
            return .blue
        }

        // Check if answered using the single source of truth
        let questionNumber = questions[index].questionNumber
        if let response = viewModel.responses[questionNumber], !response.isEmpty {
            return .green
        }

        return .gray.opacity(0.3)
    }

    // MARK: - Question Content

    private var questionContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Question number and text
                    questionHeader

                    // Options based on question type
                    if let question = viewModel.currentQuestion {
                        optionsView(for: question)
                    }
                }
                .padding()
            }

            // Navigation buttons
            navigationButtons
        }
    }

    // MARK: - Question Header

    private var questionHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question counter
            Text("Question \(viewModel.currentQuestionIndex + 1) of \(viewModel.visibleQuestions.count)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            // Question text
            if let question = viewModel.currentQuestion {
                Text(question.questionText)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                // Conditional note if available
                if let note = question.conditionalNote, !note.isEmpty {
                    Text(note)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Options View

    @ViewBuilder
    private func optionsView(for question: SurveyQuestion) -> some View {
        switch question.type {
        case .singleSelect:
            singleSelectOptions(question: question)
        case .multiSelect, .multiSelectTrimmed:
            multiSelectOptions(question: question)
        case .freeResponse:
            freeResponseInput(question: question)
        case .rank:
            rankOptions(question: question)
        case .numeric:
            numericInput(question: question)
        case .date:
            dateInput(question: question)
        }
    }

    // MARK: - Single Select Options

    private func singleSelectOptions(question: SurveyQuestion) -> some View {
        let displayOptions = viewModel.availableOptions(for: question)

        return VStack(spacing: 12) {
            ForEach(displayOptions) { option in
                Button {
                    Task {
                        await viewModel.selectOption(option)
                    }
                } label: {
                    HStack {
                        Text(option.optionText)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        if viewModel.isOptionSelected(option) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.gray.opacity(0.5))
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(viewModel.isOptionSelected(option) ? Color.blue.opacity(0.1) : Color(.secondarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(viewModel.isOptionSelected(option) ? Color.blue : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSaving)
            }
        }
    }

    // MARK: - Multi Select Options

    private func multiSelectOptions(question: SurveyQuestion) -> some View {
        // Get available options using conditional logic
        let displayOptions = viewModel.availableOptions(for: question)

        return VStack(spacing: 12) {
            if displayOptions.isEmpty {
                // Conditional question but source not answered yet
                VStack(spacing: 12) {
                    Image(systemName: "arrow.left.circle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Please answer the previous question first")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                Text("Select all that apply")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(displayOptions) { option in
                    Button {
                        Task {
                            await viewModel.selectOption(option)
                        }
                    } label: {
                        HStack {
                            Text(option.optionText)
                                .font(.body)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)

                            Spacer()

                            if viewModel.isOptionSelected(option) {
                                Image(systemName: "checkmark.square.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "square")
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(viewModel.isOptionSelected(option) ? Color.blue.opacity(0.1) : Color(.secondarySystemGroupedBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(viewModel.isOptionSelected(option) ? Color.blue : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Free Response Input

    private func freeResponseInput(question: SurveyQuestion) -> some View {
        let currentText = viewModel.currentFreeText

        return VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: Binding(
                get: { viewModel.currentFreeText },
                set: { viewModel.updateFreeText($0) }
            ))
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            Text("\(currentText.count) characters")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Rank Options

    private func rankOptions(question: SurveyQuestion) -> some View {
        // Get available options using conditional logic
        let displayOptions = viewModel.availableOptions(for: question)

        // Get ranked options from the response
        let rankedOptionIds = viewModel.responses[question.questionNumber]?.rankedOptionIds ?? []
        let rankedOptions = rankedOptionIds.compactMap { optionId in
            displayOptions.first { $0.optionId == optionId }
        }

        return VStack(spacing: 12) {
            if displayOptions.isEmpty {
                // No options available - source question not answered
                VStack(spacing: 12) {
                    Image(systemName: "arrow.left.circle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Please answer the previous question first")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Text("The ranking options will come from your selections.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                Text("Tap options in order of preference (1st = most preferred)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Selected items with rank numbers
                if !rankedOptions.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(Array(rankedOptions.enumerated()), id: \.element.id) { index, option in
                            HStack {
                                Text("\(index + 1)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Color.blue)
                                    .cornerRadius(12)

                                Text(option.optionText)
                                    .font(.body)

                                Spacer()

                                Button {
                                    Task {
                                        await viewModel.selectOption(option)
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.bottom, 8)
                }

                // Remaining options not yet ranked
                ForEach(displayOptions.filter { !viewModel.isOptionSelected($0) }) { option in
                    Button {
                        Task {
                            await viewModel.selectOption(option)
                        }
                    } label: {
                        HStack {
                            Text(option.optionText)
                                .font(.body)
                                .foregroundColor(.primary)

                            Spacer()

                            Image(systemName: "plus.circle")
                                .foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Numeric Input

    private func numericInput(question: SurveyQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Enter a number", text: Binding(
                get: { viewModel.currentFreeText },
                set: { viewModel.updateFreeText($0) }
            ))
                .keyboardType(.decimalPad)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(10)
        }
    }

    // MARK: - Date Input

    private func dateInput(question: SurveyQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Enter date (MM/DD/YYYY)", text: Binding(
                get: { viewModel.currentFreeText },
                set: { viewModel.updateFreeText($0) }
            ))
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(10)
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            // Back button
            Button {
                viewModel.goToPreviousQuestion()
            } label: {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.headline)
                .foregroundColor(viewModel.canGoBack ? .blue : .gray)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
            .disabled(!viewModel.canGoBack)

            // Next/Done button
            if viewModel.canGoForward {
                Button {
                    saveAndAdvance()
                } label: {
                    HStack {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isSaving)
            } else {
                Button {
                    saveAndFinish()
                } label: {
                    HStack {
                        Text("Done")
                        Image(systemName: "checkmark")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isSaving)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Actions

    private func saveAndAdvance() {
        Task {
            await viewModel.saveCurrentResponse()
            viewModel.goToNextQuestion()
        }
    }

    private func saveAndFinish() {
        Task {
            await viewModel.saveCurrentResponse()
            onDismiss()
        }
    }

    // MARK: - Loading & Empty Views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading questions...")
                .foregroundColor(.secondary)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundColor(.green)
            Text("No questions in this group")
                .font(.headline)
            Button("Go Back") {
                onDismiss()
            }
            .buttonStyle(.bordered)
        }
    }
}

#Preview {
    QuestionFlowView(
        group: SurveyGroup(
            id: UUID(),
            groupId: "test",
            categoryId: "cat",
            sectionId: "sec",
            displayName: "General Diet",
            description: "Your typical eating patterns",
            groupOrder: 1,
            categoryOrder: 1,
            sectionOrder: 1
        ),
        viewModel: HealthProfileViewModel()
    ) {
        print("Dismissed")
    }
}
