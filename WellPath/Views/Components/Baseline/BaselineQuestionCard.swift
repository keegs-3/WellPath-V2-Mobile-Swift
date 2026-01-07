//
//  BaselineQuestionCard.swift
//  WellPath
//
//  Reusable card component for baseline numeric questions.
//  Used by both wizard flows and edit sheets.
//

import SwiftUI

/// Card component for numeric baseline questions with text field and +/- buttons
struct BaselineQuestionCard: View {
    let question: BaselineQuestion
    @Binding var value: Double?
    let color: Color
    var displayUnit: String?  // Optional unit override for dynamic unit display

    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    /// The unit label to display (uses override if provided, otherwise question's unit)
    private var unitLabel: String {
        displayUnit ?? question.unitLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question text (supports templated text with {unit} placeholder)
            HStack(alignment: .top) {
                Text(question.displayText(withUnit: displayUnit))
                    .font(.subheadline)
                    .fontWeight(.medium)

                if question.isRequired {
                    Text("*")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            // Subtext/helper
            if let subtext = question.questionSubtext {
                Text(subtext)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Numeric input row
            HStack(spacing: 12) {
                // Text field with better styling
                HStack {
                    TextField(question.placeholder ?? "0", text: $textValue)
                        .keyboardType(.decimalPad)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .focused($isFocused)
                        .frame(minWidth: 80)
                        .onChange(of: textValue) { _, newValue in
                            if let doubleValue = Double(newValue) {
                                value = doubleValue
                            } else if newValue.isEmpty {
                                value = nil
                            }
                        }

                    // Unit label
                    Text(unitLabel)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isFocused ? color : Color.clear, lineWidth: 2)
                )

                Spacer()

                // Quick increment/decrement buttons
                HStack(spacing: 8) {
                    quickButton(delta: -(question.stepValue ?? 1))
                    quickButton(delta: question.stepValue ?? 1)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .onAppear {
            if let existingValue = value {
                textValue = formatValue(existingValue)
            }
        }
    }

    private func quickButton(delta: Double) -> some View {
        Button {
            let current = value ?? 0
            let newValue = max(question.minValue ?? 0, current + delta)
            if let maxValue = question.maxValue {
                value = min(maxValue, newValue)
            } else {
                value = newValue
            }
            textValue = formatValue(value ?? 0)
        } label: {
            Image(systemName: delta > 0 ? "plus" : "minus")
                .font(.headline)
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.1))
                .cornerRadius(10)
        }
    }

    private func formatValue(_ val: Double) -> String {
        if val == floor(val) {
            return String(format: "%.0f", val)
        } else {
            return String(format: "%.1f", val)
        }
    }
}

/// Card component for single-choice baseline questions (edit sheet version with bindings)
struct BaselineEditSingleChoiceCard: View {
    let question: BaselineQuestion
    let options: [BaselineEditQuestionOption]
    @Binding var selectedValue: String?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question text
            HStack(alignment: .top) {
                Text(question.questionText)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if question.isRequired {
                    Text("*")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            // Subtext/helper
            if let subtext = question.questionSubtext {
                Text(subtext)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Options
            VStack(spacing: 8) {
                ForEach(options) { option in
                    Button {
                        selectedValue = option.optionValue
                    } label: {
                        HStack {
                            Image(systemName: selectedValue == option.optionValue ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedValue == option.optionValue ? color : .secondary)

                            Text(option.optionLabel)
                                .font(.subheadline)
                                .foregroundColor(.primary)

                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(
                            selectedValue == option.optionValue
                                ? color.opacity(0.1)
                                : Color(.tertiarySystemGroupedBackground)
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

/// Card component for boolean baseline questions (edit sheet version with bindings)
struct BaselineEditBooleanCard: View {
    let question: BaselineQuestion
    @Binding var value: Bool?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question text
            HStack(alignment: .top) {
                Text(question.questionText)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if question.isRequired {
                    Text("*")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            // Subtext/helper
            if let subtext = question.questionSubtext {
                Text(subtext)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Yes/No buttons
            HStack(spacing: 12) {
                Button {
                    value = true
                } label: {
                    HStack {
                        Image(systemName: value == true ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(value == true ? .green : .secondary)
                        Text("Yes")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(value == true ? Color.green.opacity(0.1) : Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button {
                    value = false
                } label: {
                    HStack {
                        Image(systemName: value == false ? "xmark.circle.fill" : "circle")
                            .foregroundColor(value == false ? .red : .secondary)
                        Text("No")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(value == false ? Color.red.opacity(0.1) : Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

/// Card component for text baseline questions (edit sheet version with bindings)
struct BaselineEditTextCard: View {
    let question: BaselineQuestion
    @Binding var value: String
    let color: Color

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question text
            HStack(alignment: .top) {
                Text(question.questionText)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if question.isRequired {
                    Text("*")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            // Subtext/helper
            if let subtext = question.questionSubtext {
                Text(subtext)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Text input
            TextField(question.placeholder ?? "Enter value", text: $value)
                .font(.body)
                .padding()
                .focused($isFocused)
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isFocused ? color : Color.clear, lineWidth: 2)
                )
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

/// Card component for water/liquid baseline questions with unit picker
struct BaselineEditWaterCard: View {
    let question: BaselineQuestion
    @Binding var value: Double?
    @Binding var selectedUnit: LiquidDisplayUnit
    let color: Color

    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question text - simplified, no {unit} templating
            HStack(alignment: .top) {
                Text("How much water do you typically drink per day?")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if question.isRequired {
                    Text("*")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            // Subtext
            if let subtext = question.questionSubtext {
                Text(subtext)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Amount input with unit picker
            HStack(spacing: 12) {
                // Text field for amount
                HStack {
                    TextField("0", text: $textValue)
                        .keyboardType(.decimalPad)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .focused($isFocused)
                        .frame(minWidth: 60)
                        .onChange(of: textValue) { _, newValue in
                            if let doubleValue = Double(newValue) {
                                value = doubleValue
                            } else if newValue.isEmpty {
                                value = nil
                            }
                        }

                    // Unit picker - using Menu for reliable touch handling
                    Menu {
                        ForEach(LiquidDisplayUnit.allCases) { unit in
                            Button {
                                selectedUnit = unit
                            } label: {
                                HStack {
                                    Text(unit.displayName)
                                    if unit == selectedUnit {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedUnit.shortLabel)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                        }
                        .foregroundColor(color)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isFocused ? color : Color.clear, lineWidth: 2)
                )

                Spacer()

                // Quick increment/decrement buttons
                HStack(spacing: 8) {
                    quickButton(delta: -1)
                    quickButton(delta: 1)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .onAppear {
            if let existingValue = value {
                textValue = formatValue(existingValue)
            }
        }
    }

    private func quickButton(delta: Double) -> some View {
        Button {
            let current = value ?? 0
            let newValue = max(0, current + delta)
            value = newValue
            textValue = formatValue(newValue)
        } label: {
            Image(systemName: delta > 0 ? "plus" : "minus")
                .font(.headline)
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.1))
                .cornerRadius(10)
        }
    }

    private func formatValue(_ val: Double) -> String {
        if val == floor(val) {
            return String(format: "%.0f", val)
        } else {
            return String(format: "%.1f", val)
        }
    }
}

#Preview("Numeric Question") {
    let question = BaselineQuestion(
        id: UUID(),
        questionId: "test",
        categoryId: nil,
        questionText: "How many grams of protein do you typically eat per day?",
        questionTextTemplate: nil,
        questionSubtext: "Include all protein sources",
        baselineType: "daily_protein_g",
        quantityType: nil,
        categoryTypeReference: nil,
        unitLabel: "g",
        unitId: nil,
        questionType: "numeric",
        placeholder: "0",
        minValue: 0,
        maxValue: 300,
        stepValue: 5,
        displayOrder: 1,
        isRequired: true,
        isActive: true,
        baselineSubpageId: nil,
        optionsQuestionId: nil
    )

    BaselineQuestionCard(
        question: question,
        value: .constant(120),
        color: .green
    )
    .padding()
}
