//
//  SurveyOnboardingView.swift
//  WellPath
//
//  Created on 2025-11-27
//

import SwiftUI

struct SurveyOnboardingView: View {
    @ObservedObject var viewModel: SurveyViewModel
    let startingSection: SurveySection
    @Environment(\.dismiss) private var dismiss

    @State private var showingSkipAlert = false
    @State private var animateIn = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with progress
            headerView

            // Question content
            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading questions...")
                Spacer()
            } else if let question = viewModel.currentQuestion {
                questionContentView(question)
            } else {
                Spacer()
                Text("No questions available")
                    .foregroundColor(.secondary)
                Spacer()
            }

            // Navigation footer
            navigationFooter
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingSkipAlert = true
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
            }

            ToolbarItem(placement: .principal) {
                Text(viewModel.currentSection?.displayName ?? "Survey")
                    .font(.headline)
            }
        }
        .alert("Exit Survey?", isPresented: $showingSkipAlert) {
            Button("Continue Survey", role: .cancel) {}
            Button("Save & Exit", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("Your progress has been saved. You can continue anytime.")
        }
        .task {
            await viewModel.selectSection(startingSection)
        }
        .onChange(of: viewModel.currentQuestionIndex) { _, _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                animateIn = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    animateIn = true
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3).delay(0.2)) {
                animateIn = true
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            // Section progress
            HStack {
                Text(viewModel.currentSection?.displayName ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(viewModel.currentQuestionIndex + 1) of \(viewModel.questionsInCurrentSection)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                        .cornerRadius(2)

                    Rectangle()
                        .fill(sectionColor)
                        .frame(width: progressWidth(in: geometry.size.width), height: 4)
                        .cornerRadius(2)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.currentQuestionIndex)
                }
            }
            .frame(height: 4)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard viewModel.questionsInCurrentSection > 0 else { return 0 }
        let progress = CGFloat(viewModel.currentQuestionIndex + 1) / CGFloat(viewModel.questionsInCurrentSection)
        return totalWidth * progress
    }

    private var sectionColor: Color {
        guard let section = viewModel.currentSection else { return .blue }
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

    // MARK: - Question Content

    private func questionContentView(_ question: SurveyQuestion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Question text
                Text(question.cleanedQuestionText)
                    .font(.title2)
                    .fontWeight(.medium)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 20)

                // Type hint
                if question.type.allowsMultipleSelections {
                    Label(
                        question.type == .rank ? "Tap to select, then reorder" : "Select all that apply",
                        systemImage: question.type == .rank ? "arrow.up.arrow.down" : "checkmark.square"
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }

                // Answer options
                questionInputView(question)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 30)
            }
            .padding()
        }
    }

    @ViewBuilder
    private func questionInputView(_ question: SurveyQuestion) -> some View {
        switch question.type {
        case .singleSelect:
            singleSelectView(question)
        case .multiSelect, .multiSelectTrimmed:
            multiSelectView(question)
        case .rank:
            rankView(question)
        case .freeResponse:
            freeResponseView(question)
        default:
            Text("Question type not supported")
                .foregroundColor(.secondary)
        }
    }

    private func singleSelectView(_ question: SurveyQuestion) -> some View {
        VStack(spacing: 12) {
            ForEach(question.options) { option in
                Button {
                    Task {
                        await viewModel.selectOption(option)
                        // Auto-advance after selection
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            if viewModel.canGoForward {
                                viewModel.goToNextQuestion()
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(option.cleanedOptionText)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        ZStack {
                            Circle()
                                .stroke(viewModel.isOptionSelected(option) ? sectionColor : Color.gray.opacity(0.4), lineWidth: 2)
                                .frame(width: 24, height: 24)

                            if viewModel.isOptionSelected(option) {
                                Circle()
                                    .fill(sectionColor)
                                    .frame(width: 14, height: 14)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(viewModel.isOptionSelected(option) ? sectionColor.opacity(0.1) : Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(viewModel.isOptionSelected(option) ? sectionColor : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSaving)
            }
        }
    }

    private func multiSelectView(_ question: SurveyQuestion) -> some View {
        VStack(spacing: 12) {
            ForEach(question.options) { option in
                Button {
                    viewModel.toggleMultiSelectOption(option)
                } label: {
                    HStack {
                        Text(option.cleanedOptionText)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        Image(systemName: viewModel.selectedOptionIds.contains(option.id) ? "checkmark.square.fill" : "square")
                            .font(.title2)
                            .foregroundColor(viewModel.selectedOptionIds.contains(option.id) ? sectionColor : .gray.opacity(0.4))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(viewModel.selectedOptionIds.contains(option.id) ? sectionColor.opacity(0.1) : Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(viewModel.selectedOptionIds.contains(option.id) ? sectionColor : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func rankView(_ question: SurveyQuestion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Selected/Ranked items
            if !viewModel.rankedOptions.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(viewModel.rankedOptions.enumerated()), id: \.element.id) { index, option in
                        HStack {
                            Text("\(index + 1)")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(sectionColor)
                                .clipShape(Circle())

                            Text(option.cleanedOptionText)
                                .font(.body)

                            Spacer()

                            Button {
                                viewModel.toggleRankOption(option)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red.opacity(0.6))
                            }
                        }
                        .padding()
                        .background(sectionColor.opacity(0.1))
                        .cornerRadius(12)
                    }
                }

                if !unrankedOptions(question).isEmpty {
                    Divider()
                        .padding(.vertical, 8)
                }
            }

            // Unranked options
            let unranked = unrankedOptions(question)
            if !unranked.isEmpty {
                if !viewModel.rankedOptions.isEmpty {
                    Text("Tap to add:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                ForEach(unranked) { option in
                    Button {
                        viewModel.toggleRankOption(option)
                    } label: {
                        HStack {
                            Text(option.cleanedOptionText)
                                .font(.body)
                                .foregroundColor(.primary)

                            Spacer()

                            Image(systemName: "plus.circle")
                                .foregroundColor(sectionColor)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func unrankedOptions(_ question: SurveyQuestion) -> [SurveyResponseOption] {
        question.options.filter { option in
            !viewModel.rankedOptions.contains(where: { $0.id == option.id })
        }
    }

    private func freeResponseView(_ question: SurveyQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $viewModel.freeResponseText)
                .frame(minHeight: 150)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )

            Text("\(viewModel.freeResponseText.count) characters")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Navigation Footer

    private var navigationFooter: some View {
        VStack(spacing: 12) {
            // Next/Save button for multi-select, rank, free-response
            if let question = viewModel.currentQuestion, needsSaveButton(question) {
                Button {
                    Task {
                        await saveCurrentResponse()
                        if viewModel.canGoForward {
                            viewModel.goToNextQuestion()
                        }
                    }
                } label: {
                    HStack {
                        if viewModel.isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(viewModel.isLastQuestion ? "Complete" : "Next")
                            Image(systemName: "arrow.right")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSave ? sectionColor : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!canSave || viewModel.isSaving)
            }

            // Back/Skip navigation
            HStack {
                Button {
                    viewModel.goToPreviousQuestion()
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(viewModel.canGoBack ? .primary : .gray)
                }
                .disabled(!viewModel.canGoBack)

                Spacer()

                if let question = viewModel.currentQuestion, !needsSaveButton(question) {
                    Button {
                        if viewModel.canGoForward {
                            viewModel.goToNextQuestion()
                        } else {
                            // End of section
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Text("Skip")
                            Image(systemName: "chevron.right")
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 5, y: -5)
    }

    private func needsSaveButton(_ question: SurveyQuestion) -> Bool {
        switch question.type {
        case .multiSelect, .multiSelectTrimmed, .rank, .freeResponse:
            return true
        default:
            return false
        }
    }

    private var canSave: Bool {
        guard let question = viewModel.currentQuestion else { return false }
        switch question.type {
        case .multiSelect, .multiSelectTrimmed:
            return !viewModel.selectedOptionIds.isEmpty
        case .rank:
            return !viewModel.rankedOptions.isEmpty
        case .freeResponse:
            return !viewModel.freeResponseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return false
        }
    }

    private func saveCurrentResponse() async {
        guard let question = viewModel.currentQuestion else { return }
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
        SurveyOnboardingView(
            viewModel: SurveyViewModel(),
            startingSection: SurveySection(
                id: UUID(),
                sectionId: "healthful_nutrition",
                pillar: "Healthful Nutrition",
                displayName: "Healthful Nutrition",
                sectionOrder: 2,
                questionCount: 68,
                answeredCount: 0
            )
        )
    }
}
