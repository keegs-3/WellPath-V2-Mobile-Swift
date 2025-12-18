//
//  TourQuestionCard.swift
//  WellPath
//
//  Reusable card component that displays survey questions during onboarding tour
//

import SwiftUI

struct TourQuestionCard: View {
    @ObservedObject var tourManager: OnboardingTourManager
    let color: Color
    var showSkip: Bool = true
    var onComplete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "clipboard.fill")
                    .foregroundColor(color)
                Text("Set Your Baseline")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                if showSkip && !tourManager.hasUnansweredRequiredQuestions {
                    Button("Skip") {
                        Task {
                            await tourManager.skipCurrentScreen()
                            onComplete?()
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }

            // Questions
            ForEach(tourManager.currentQuestions) { question in
                TourQuestionRow(
                    question: question,
                    response: Binding(
                        get: { tourManager.responses[question.questionNumber] },
                        set: { tourManager.responses[question.questionNumber] = $0 }
                    ),
                    tourManager: tourManager,
                    color: color
                )

                if question.id != tourManager.currentQuestions.last?.id {
                    Divider()
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                if !tourManager.isFirstScreen {
                    Button {
                        Task { await tourManager.previousScreen() }
                    } label: {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                    }
                }

                Button {
                    Task {
                        await tourManager.nextScreen()
                        onComplete?()
                    }
                } label: {
                    HStack {
                        Text(tourManager.isLastScreen ? "Complete Tour" : "Continue")
                        if !tourManager.isLastScreen {
                            Image(systemName: "chevron.right")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(color)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(tourManager.hasUnansweredRequiredQuestions)
                .opacity(tourManager.hasUnansweredRequiredQuestions ? 0.6 : 1)
            }

            // Optional indicator
            if tourManager.currentQuestions.contains(where: { !$0.isRequired }) {
                Text("Questions marked with * are required for your WellPath Score")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Question Row

struct TourQuestionRow: View {
    let question: TourQuestion
    @Binding var response: TourResponse?
    @ObservedObject var tourManager: OnboardingTourManager
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
                // For now, treat as multi-select
                multiSelectView
            }
        }
    }

    // MARK: - Single Select

    private var singleSelectView: some View {
        VStack(spacing: 8) {
            ForEach(question.options.sorted { $0.optionOrder < $1.optionOrder }) { option in
                Button {
                    tourManager.toggleOption(option.id, for: question)
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

    // MARK: - Multi Select

    private var multiSelectView: some View {
        VStack(spacing: 8) {
            ForEach(question.options.sorted { $0.optionOrder < $1.optionOrder }) { option in
                Button {
                    tourManager.toggleOption(option.id, for: question)
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

            // Other text field for multiSelectWithOther
            if question.questionType == .multiSelectWithOther {
                TextField("Other (please specify)", text: Binding(
                    get: { response?.otherText ?? "" },
                    set: { tourManager.setOtherText($0, for: question) }
                ))
                .textFieldStyle(.roundedBorder)
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Free Response

    private var freeResponseView: some View {
        TextField("Enter your response...", text: Binding(
            get: { response?.freeTextResponse ?? "" },
            set: { tourManager.setFreeText($0, for: question) }
        ))
        .textFieldStyle(.roundedBorder)
    }

    // MARK: - Numeric

    private var numericView: some View {
        HStack {
            TextField("Enter value", value: Binding(
                get: { response?.numericResponse },
                set: { tourManager.setNumeric($0, for: question) }
            ), format: .number)
            .textFieldStyle(.roundedBorder)
            .keyboardType(.decimalPad)
            .frame(width: 120)

            // Common unit shortcuts based on question context
            if question.questionText.lowercased().contains("protein") ||
               question.questionText.lowercased().contains("grams") {
                Text("g")
                    .foregroundColor(.secondary)
            } else if question.questionText.lowercased().contains("calorie") {
                Text("kcal")
                    .foregroundColor(.secondary)
            } else if question.questionText.lowercased().contains("steps") {
                Text("steps")
                    .foregroundColor(.secondary)
            } else if question.questionText.lowercased().contains("minutes") {
                Text("min")
                    .foregroundColor(.secondary)
            } else if question.questionText.lowercased().contains("hours") {
                Text("hrs")
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Helpers

    private func isSelected(_ option: TourQuestionOption) -> Bool {
        response?.selectedOptionIds.contains(option.id) ?? false
    }
}

// MARK: - Tour Progress Indicator

struct TourProgressIndicator: View {
    let current: Int
    let total: Int
    let sectionName: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(sectionName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            HStack(spacing: 2) {
                Text("\(current)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                Text("of")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(total)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Tour Chart Placeholder

struct TourChartPlaceholder: View {
    let metricName: String
    let color: Color

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundColor(color.opacity(0.3))

            Text("Your \(metricName) data will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("Answer the questions below to set your baseline")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        TourQuestionCard(
            tourManager: OnboardingTourManager(),
            color: .green
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
