//
//  AssessmentFlowView.swift
//  WellPath
//
//  Multi-step questionnaire flow for mental health assessments.
//  Follows Apple Health-inspired UI pattern: one question per page,
//  progress indicator, summary on completion.
//

import SwiftUI

// MARK: - Assessment Flow View

struct AssessmentFlowView: View {
    let assessmentType: MentalHealthAssessmentType
    let onComplete: (Int, [String: Int]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var currentQuestionIndex = 0
    @State private var responses: [Int] = []
    @State private var showingSummary = false

    private var questions: [String] {
        switch assessmentType {
        case .swls: return SWLSAssessment.questions
        case .gad2: return GAD2Assessment.questions
        case .phq2: return PHQ2Assessment.questions
        }
    }

    private var responseOptions: [(Int, String)] {
        switch assessmentType {
        case .swls: return SWLSAssessment.responseOptions
        case .gad2: return GAD2Assessment.responseOptions
        case .phq2: return PHQ2Assessment.responseOptions
        }
    }

    private var timeframe: String? {
        switch assessmentType {
        case .swls: return nil
        case .gad2: return GAD2Assessment.timeframe
        case .phq2: return PHQ2Assessment.timeframe
        }
    }

    private var color: Color {
        switch assessmentType {
        case .swls: return .yellow
        case .gad2: return .mint
        case .phq2: return .indigo
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress Bar
                ProgressView(value: Double(currentQuestionIndex + 1), total: Double(questions.count))
                    .tint(color)
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Question Counter
                Text("Question \(currentQuestionIndex + 1) of \(questions.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 32) {
                        // Timeframe (for GAD-2 and PHQ-2)
                        if let timeframe = timeframe, currentQuestionIndex == 0 {
                            Text(timeframe)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.top, 24)
                        }

                        // Question Text
                        Text(questions[currentQuestionIndex])
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, timeframe == nil || currentQuestionIndex > 0 ? 40 : 16)

                        // Response Options
                        VStack(spacing: 12) {
                            ForEach(responseOptions, id: \.0) { option in
                                AssessmentOptionButton(
                                    value: option.0,
                                    label: option.1,
                                    isSelected: responses.count > currentQuestionIndex && responses[currentQuestionIndex] == option.0,
                                    color: color
                                ) {
                                    selectResponse(option.0)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                        Spacer(minLength: 100)
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(assessmentType.displayName)
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
                AssessmentSummaryView(
                    assessmentType: assessmentType,
                    totalScore: responses.reduce(0, +),
                    responses: responses,
                    onDone: {
                        // Convert responses to dictionary format
                        var responsesDict: [String: Int] = [:]
                        for (index, value) in responses.enumerated() {
                            responsesDict["q\(index + 1)"] = value
                        }
                        onComplete(responses.reduce(0, +), responsesDict)
                        dismiss()
                    }
                )
            }
        }
    }

    private func selectResponse(_ value: Int) {
        // Add or update response
        if responses.count > currentQuestionIndex {
            responses[currentQuestionIndex] = value
        } else {
            responses.append(value)
        }

        // Small delay then advance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                if currentQuestionIndex < questions.count - 1 {
                    currentQuestionIndex += 1
                } else {
                    showingSummary = true
                }
            }
        }
    }
}

// MARK: - Assessment Option Button

struct AssessmentOptionButton: View {
    let value: Int
    let label: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
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

// MARK: - Assessment Summary View

struct AssessmentSummaryView: View {
    let assessmentType: MentalHealthAssessmentType
    let totalScore: Int
    let responses: [Int]
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var interpretation: String {
        switch assessmentType {
        case .swls: return SWLSAssessment.interpretation(for: totalScore)
        case .gad2: return GAD2Assessment.interpretation(for: totalScore)
        case .phq2: return PHQ2Assessment.interpretation(for: totalScore)
        }
    }

    private var interpretationDescription: String {
        switch assessmentType {
        case .swls: return SWLSAssessment.interpretationDescription(for: totalScore)
        case .gad2: return GAD2Assessment.interpretationDescription(for: totalScore)
        case .phq2: return PHQ2Assessment.interpretationDescription(for: totalScore)
        }
    }

    private var color: Color {
        switch assessmentType {
        case .swls: return .yellow
        case .gad2: return .mint
        case .phq2: return .indigo
        }
    }

    private var scoreRange: ClosedRange<Int> {
        assessmentType.scoreRange
    }

    private var scoreProgress: Double {
        let range = Double(scoreRange.upperBound - scoreRange.lowerBound)
        let value = Double(totalScore - scoreRange.lowerBound)
        return value / range
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Success Icon
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(color)
                }
                .padding(.top, 40)

                // Score Display
                VStack(spacing: 8) {
                    Text("Your Score")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("\(totalScore)")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(color)

                    Text("out of \(scoreRange.upperBound)")
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
                                .fill(color)
                                .frame(width: geometry.size.width * scoreProgress, height: 16)
                        }
                    }
                    .frame(height: 16)

                    HStack {
                        Text("\(scoreRange.lowerBound)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(scoreRange.upperBound)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 32)

                // Interpretation
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: assessmentType.icon)
                            .foregroundColor(color)
                        Text(interpretation)
                            .font(.headline)
                    }

                    Text(interpretationDescription)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                // Disclaimer
                Text("This screening tool is not a diagnosis. If you have concerns about your mental health, please consult with a healthcare provider.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Done Button
                Button(action: onDone) {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(color)
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

#Preview("Assessment Flow - SWLS") {
    AssessmentFlowView(assessmentType: .swls) { score, responses in
        print("Score: \(score), Responses: \(responses)")
    }
}

#Preview("Assessment Flow - GAD2") {
    AssessmentFlowView(assessmentType: .gad2) { score, responses in
        print("Score: \(score), Responses: \(responses)")
    }
}
