//
//  SectionQuestionFlowView.swift
//  WellPath
//
//  Flattened question flow - shows ALL questions for a section sequentially.
//  Eliminates the Category → Group navigation layers.
//

import SwiftUI

struct SectionQuestionFlowView: View {
    let section: SurveySection
    @ObservedObject var viewModel: HealthProfileViewModel
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var sectionColor: Color {
        switch section.themeColor {
        case "green": return .green
        case "orange": return .orange
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink": return .pink
        case "teal": return .teal
        case "red": return .red
        default: return .blue
        }
    }

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
            .navigationTitle(section.displayName)
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
        VStack(spacing: 2) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                        .cornerRadius(2)

                    Rectangle()
                        .fill(sectionColor)
                        .frame(width: geometry.size.width * progressFraction, height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(width: 120, height: 4)

            Text("\(viewModel.currentQuestionIndex + 1) of \(viewModel.visibleQuestions.count)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var progressFraction: Double {
        guard viewModel.visibleQuestions.count > 0 else { return 0 }
        return Double(viewModel.currentQuestionIndex + 1) / Double(viewModel.visibleQuestions.count)
    }

    // MARK: - Question Content

    private var questionContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Question header with context
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
                                .foregroundColor(sectionColor)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.gray.opacity(0.5))
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(viewModel.isOptionSelected(option) ? sectionColor.opacity(0.1) : Color(.secondarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(viewModel.isOptionSelected(option) ? sectionColor : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSaving)
            }

            // Show text field if "Other" option is selected
            if viewModel.hasOtherOptionSelected {
                otherTextField
            }
        }
    }

    // MARK: - Multi Select Options

    private func multiSelectOptions(question: SurveyQuestion) -> some View {
        let displayOptions = viewModel.availableOptions(for: question)

        return VStack(spacing: 12) {
            if displayOptions.isEmpty {
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
                                    .foregroundColor(sectionColor)
                            } else {
                                Image(systemName: "square")
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(viewModel.isOptionSelected(option) ? sectionColor.opacity(0.1) : Color(.secondarySystemGroupedBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(viewModel.isOptionSelected(option) ? sectionColor : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Show text field if "Other" option is selected
                if viewModel.hasOtherOptionSelected {
                    otherTextField
                }
            }
        }
    }

    // MARK: - Other Text Field

    private var otherTextField: some View {
        let currentText = viewModel.currentOtherText

        return VStack(alignment: .leading, spacing: 8) {
            Text("Please specify:")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("Enter your response...", text: Binding(
                get: { viewModel.currentOtherText },
                set: { viewModel.updateOtherText($0) }
            ))
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(currentText.isEmpty ? Color.gray.opacity(0.2) : sectionColor.opacity(0.5), lineWidth: 1)
            )
        }
        .padding(.top, 8)
    }

    // MARK: - Free Response Input

    private func freeResponseInput(question: SurveyQuestion) -> some View {
        let currentText = viewModel.currentFreeText

        return VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                // Placeholder
                if currentText.isEmpty {
                    Text("Type your answer here...")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                }

                TextEditor(text: Binding(
                    get: { viewModel.currentFreeText },
                    set: { viewModel.updateFreeText($0) }
                ))
                .scrollContentBackground(.hidden)
                .padding(12)
            }
            .frame(minHeight: 150)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(currentText.isEmpty ? Color.gray.opacity(0.2) : sectionColor.opacity(0.5), lineWidth: 1)
            )

            HStack {
                Spacer()
                Text("\(currentText.count) characters")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Rank Options

    private func rankOptions(question: SurveyQuestion) -> some View {
        let displayOptions = viewModel.availableOptions(for: question)
        let rankedOptionIds = viewModel.responses[question.questionNumber]?.rankedOptionIds ?? []
        let rankedOptions = rankedOptionIds.compactMap { optionId in
            displayOptions.first { $0.optionId == optionId }
        }

        return VStack(spacing: 12) {
            if displayOptions.isEmpty {
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
                                    .background(sectionColor)
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
                            .background(sectionColor.opacity(0.1))
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
                                .foregroundColor(sectionColor)
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
        let currentText = viewModel.currentFreeText

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "number")
                    .foregroundColor(sectionColor)
                    .font(.title2)

                TextField("Enter a number", text: Binding(
                    get: { viewModel.currentFreeText },
                    set: { viewModel.updateFreeText($0) }
                ))
                .keyboardType(.decimalPad)
                .font(.title2)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(currentText.isEmpty ? Color.gray.opacity(0.2) : sectionColor.opacity(0.5), lineWidth: 1)
            )
        }
    }

    // MARK: - Date Input

    private func dateInput(question: SurveyQuestion) -> some View {
        let currentText = viewModel.currentFreeText

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(sectionColor)
                    .font(.title2)

                TextField("MM/DD/YYYY", text: Binding(
                    get: { viewModel.currentFreeText },
                    set: { viewModel.updateFreeText($0) }
                ))
                .keyboardType(.numbersAndPunctuation)
                .font(.title2)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(currentText.isEmpty ? Color.gray.opacity(0.2) : sectionColor.opacity(0.5), lineWidth: 1)
            )
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
                .foregroundColor(viewModel.canGoBack ? sectionColor : .gray)
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
                    .background(sectionColor)
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
            Text("No questions in this section")
                .font(.headline)
            Button("Go Back") {
                onDismiss()
            }
            .buttonStyle(.bordered)
        }
    }
}

#Preview {
    SectionQuestionFlowView(
        section: SurveySection(
            id: UUID(),
            sectionId: "introduction",
            pillar: nil,
            displayName: "Introduction",
            sectionOrder: 1,
            description: "Get started with your health profile"
        ),
        viewModel: HealthProfileViewModel()
    ) {
        print("Dismissed")
    }
}
