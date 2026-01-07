//
//  DatabaseAssessmentFlowView.swift
//  WellPath
//
//  Generic assessment flow that works with any database-driven assessment.
//  Supports: scale (single), multi_select, multi_select_weighted, single_select
//

import SwiftUI

// MARK: - Database Assessment Flow View

struct DatabaseAssessmentFlowView: View {
    let assessmentData: AssessmentData
    let onComplete: (Int, [String: Int]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var currentQuestionIndex = 0
    @State private var responses: [String: Int] = [:] // questionId -> single value (for scale/single_select)
    @State private var multiResponses: [String: Set<Int>] = [:] // questionId -> set of selected option values (for multi_select)
    @State private var showingSummary = false
    @State private var selectedDate = Date()

    private var questions: [ViewAssessmentQuestion] {
        assessmentData.questions.sorted { $0.questionOrder < $1.questionOrder }
    }

    private var currentQuestion: ViewAssessmentQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }

    private var currentOptions: [ViewAssessmentResponseOption] {
        guard let question = currentQuestion else { return [] }
        return assessmentData.options(for: question.questionId)
    }

    /// Calculate total score based on response type
    private var totalScore: Int {
        var score = 0

        for question in questions {
            let responseType = question.responseType ?? "scale"

            switch responseType {
            case "multi_select_weighted":
                // Sum the weights (option_value) of all selected options
                if let selectedDisplayOrders = multiResponses[question.questionId] {
                    let options = assessmentData.options(for: question.questionId)
                    for displayOrder in selectedDisplayOrders {
                        if let option = options.first(where: { $0.displayOrder == displayOrder }) {
                            score += option.optionValue
                        }
                    }
                }
            case "scale", "single_select":
                // Use the selected option value directly
                if let value = responses[question.questionId] {
                    score += value
                }
            case "multi_select":
                // Multi-select without weight - don't add to score (metadata only)
                break
            default:
                if let value = responses[question.questionId] {
                    score += value
                }
            }
        }

        return score
    }

    /// Get the primary score (for assessments like Stress where only first question counts)
    private var primaryScore: Int {
        guard let firstQuestion = questions.first else { return totalScore }
        let responseType = firstQuestion.responseType ?? "scale"

        if responseType == "scale" || responseType == "single_select" {
            return responses[firstQuestion.questionId] ?? 0
        }

        return totalScore
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress Bar
                ProgressView(value: Double(currentQuestionIndex + 1), total: Double(questions.count))
                    .tint(assessmentData.assessment.color)
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Question Counter
                Text("Question \(currentQuestionIndex + 1) of \(questions.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 24) {
                        // Date picker on first question
                        if currentQuestionIndex == 0 {
                            DatePicker(
                                "Date",
                                selection: $selectedDate,
                                in: ...Date(),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                        }

                        // Timeframe (shown on first question if available)
                        if let timeframe = assessmentData.assessment.timeframeText, currentQuestionIndex == 0 {
                            Text(timeframe)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        // Question Text
                        if let question = currentQuestion {
                            VStack(spacing: 8) {
                                Text(question.questionText)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)

                                if let subtext = question.questionSubtext {
                                    Text(subtext)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 24)
                                }
                            }
                            .padding(.top, 16)
                        }

                        // Response Options - different UI based on response type
                        if let question = currentQuestion {
                            let responseType = question.responseType ?? "scale"

                            switch responseType {
                            case "multi_select_weighted", "multi_select":
                                multiSelectOptions(for: question.questionId)
                            default:
                                singleSelectOptions(for: question.questionId)
                            }
                        }

                        Spacer(minLength: 100)
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(assessmentData.assessment.assessmentName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if currentQuestionIndex > 0 {
                        Button("Back") {
                            withAnimation {
                                currentQuestionIndex -= 1
                            }
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showingSummary) {
                DatabaseAssessmentSummaryView(
                    assessmentData: assessmentData,
                    totalScore: primaryScore,
                    onDone: {
                        // Combine all responses into the flat dictionary for storage
                        var allResponses = responses
                        for (questionId, selectedValues) in multiResponses {
                            // Encode selected displayOrders as a bitmask for reversible storage
                            // displayOrder 1 → bit 0, displayOrder 2 → bit 1, etc.
                            let bitmask = selectedValues.reduce(0) { result, displayOrder in
                                result | (1 << (displayOrder - 1))
                            }
                            allResponses[questionId] = bitmask
                        }
                        onComplete(primaryScore, allResponses)
                        dismiss()
                    }
                )
            }
        }
    }

    // MARK: - Single Select Options (scale, single_select)

    @ViewBuilder
    private func singleSelectOptions(for questionId: String) -> some View {
        VStack(spacing: 12) {
            ForEach(currentOptions) { option in
                DatabaseAssessmentOptionButton(
                    option: option,
                    isSelected: responses[questionId] == option.optionValue,
                    color: assessmentData.assessment.color
                ) {
                    selectSingleResponse(option, for: questionId)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    // MARK: - Multi Select Options (multi_select, multi_select_weighted)

    @ViewBuilder
    private func multiSelectOptions(for questionId: String) -> some View {
        let selectedDisplayOrders = multiResponses[questionId] ?? []
        let isWeighted = currentQuestion?.responseType == "multi_select_weighted"

        VStack(spacing: 16) {
            // Option checkboxes grouped by weight
            if isWeighted {
                // Group options by weight for better visual hierarchy
                let highWeight = currentOptions.filter { $0.optionValue == 3 }
                let mediumWeight = currentOptions.filter { $0.optionValue == 2 }
                let lowWeight = currentOptions.filter { $0.optionValue == 1 }

                if !highWeight.isEmpty {
                    weightSection(title: "High Impact", points: 3, options: highWeight, selectedDisplayOrders: selectedDisplayOrders, questionId: questionId)
                }

                if !mediumWeight.isEmpty {
                    weightSection(title: "Medium Impact", points: 2, options: mediumWeight, selectedDisplayOrders: selectedDisplayOrders, questionId: questionId)
                }

                if !lowWeight.isEmpty {
                    weightSection(title: "Lower Impact", points: 1, options: lowWeight, selectedDisplayOrders: selectedDisplayOrders, questionId: questionId)
                }
            } else {
                // Simple multi-select without weight grouping
                ForEach(currentOptions) { option in
                    multiSelectButton(option: option, isSelected: selectedDisplayOrders.contains(option.displayOrder), questionId: questionId)
                }
            }

            // Current score display for weighted
            if isWeighted {
                // Calculate current score by summing weights of selected options
                let currentScore = currentOptions
                    .filter { selectedDisplayOrders.contains($0.displayOrder) }
                    .reduce(0) { $0 + $1.optionValue }
                Text("Current score: \(currentScore) / 25")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }

            // Continue button
            Button {
                advanceToNextQuestion()
            } label: {
                Text(currentQuestionIndex < questions.count - 1 ? "Continue" : "See Results")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(assessmentData.assessment.color)
                    .cornerRadius(12)
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    @ViewBuilder
    private func weightSection(title: String, points: Int, options: [ViewAssessmentResponseOption], selectedDisplayOrders: Set<Int>, questionId: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(points) pts each")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }

            ForEach(options) { option in
                multiSelectButton(option: option, isSelected: selectedDisplayOrders.contains(option.displayOrder), questionId: questionId, showWeight: false)
            }
        }
    }

    @ViewBuilder
    private func multiSelectButton(option: ViewAssessmentResponseOption, isSelected: Bool, questionId: String, showWeight: Bool = false) -> some View {
        Button {
            toggleMultiSelectOption(option, for: questionId)
        } label: {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundColor(isSelected ? assessmentData.assessment.color : .secondary)

                Text(option.optionText)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)

                Spacer()

                if showWeight {
                    Text("+\(option.optionValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(uiColor: .systemGray5))
                        .cornerRadius(6)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? assessmentData.assessment.color.opacity(0.1) : Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? assessmentData.assessment.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Response Actions

    private func selectSingleResponse(_ option: ViewAssessmentResponseOption, for questionId: String) {
        responses[questionId] = option.optionValue

        // Small delay then advance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            advanceToNextQuestion()
        }
    }

    private func toggleMultiSelectOption(_ option: ViewAssessmentResponseOption, for questionId: String) {
        var selected = multiResponses[questionId] ?? []

        // For weighted multi-select, we track which options are selected
        // Since multiple options can have the same weight, we need to track by display_order instead
        // Actually, let's use a different approach - track the full option

        // Simple toggle based on option_value (weight)
        // But wait - multiple options can have same weight!
        // We need to track by display_order or option_text

        // Let me fix this - we should track display_order not option_value
        if selected.contains(option.displayOrder) {
            selected.remove(option.displayOrder)
        } else {
            selected.insert(option.displayOrder)
        }

        multiResponses[questionId] = selected
    }

    private func advanceToNextQuestion() {
        withAnimation {
            if currentQuestionIndex < questions.count - 1 {
                currentQuestionIndex += 1
            } else {
                showingSummary = true
            }
        }
    }
}

// MARK: - Option Button

struct DatabaseAssessmentOptionButton: View {
    let option: ViewAssessmentResponseOption
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(option.optionText)
                    .font(.body)
                    .foregroundColor(isSelected ? .white : .primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color : Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Summary View

struct DatabaseAssessmentSummaryView: View {
    let assessmentData: AssessmentData
    let totalScore: Int
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var tier: ViewAssessmentTier? {
        assessmentData.tier(for: totalScore)
    }

    private var scoreProgress: Double {
        assessmentData.scoreProgress(for: totalScore)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Success Icon
                ZStack {
                    Circle()
                        .fill(assessmentData.assessment.color.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(assessmentData.assessment.color)
                }
                .padding(.top, 40)

                // Score Display
                VStack(spacing: 8) {
                    Text("Your Score")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("\(totalScore)")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(tier?.color ?? assessmentData.assessment.color)

                    Text("out of \(assessmentData.assessment.scoreMax)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Score Bar
                VStack(spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(uiColor: .systemGray5))
                                .frame(height: 16)

                            RoundedRectangle(cornerRadius: 8)
                                .fill(tier?.color ?? assessmentData.assessment.color)
                                .frame(width: geometry.size.width * scoreProgress, height: 16)
                        }
                    }
                    .frame(height: 16)

                    HStack {
                        Text("\(assessmentData.assessment.scoreMin)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(assessmentData.assessment.scoreMax)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 32)

                // Interpretation
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: assessmentData.assessment.icon)
                            .foregroundColor(tier?.color ?? assessmentData.assessment.color)
                        Text(tier?.tierName ?? "Unknown")
                            .font(.headline)
                    }

                    if let description = tier?.tierDescription {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    if let recommendation = tier?.recommendation {
                        Divider()
                        Text("Recommendation")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(recommendation)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                // Disclaimer (only for mental health assessments)
                if assessmentData.assessment.categoryId == "CAT_MENTAL_HEALTH" {
                    Text("This screening tool is not a diagnosis. If you have concerns about your mental health, please consult with a healthcare provider.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Done Button
                Button(action: onDone) {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(assessmentData.assessment.color)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Loading View for Assessment

struct DatabaseAssessmentLoadingView: View {
    let assessmentId: String
    let onComplete: (Int, [String: Int]) -> Void

    @State private var assessmentData: AssessmentData?
    @State private var error: Error?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading assessment...")
            } else if let data = assessmentData {
                DatabaseAssessmentFlowView(assessmentData: data, onComplete: onComplete)
            } else if let error = error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Failed to load assessment")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .task {
            await loadAssessment()
        }
    }

    private func loadAssessment() async {
        isLoading = true
        do {
            assessmentData = try await AssessmentService.shared.fetchAssessmentData(assessmentId: assessmentId)
        } catch {
            self.error = error
        }
        isLoading = false
    }
}
