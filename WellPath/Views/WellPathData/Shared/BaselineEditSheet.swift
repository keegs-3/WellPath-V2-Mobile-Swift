//
//  BaselineEditSheet.swift
//  WellPath
//
//  Sheet for editing baseline values.
//  Uses reusable BaselineQuestionCard components (same as wizard flow).
//

import SwiftUI

struct BaselineEditSheet: View {
    let title: String
    let baselineTypes: [String]
    let color: Color
    var onSave: (() -> Void)?

    @StateObject private var viewModel: BaselineEditViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        title: String,
        baselineTypes: [String],
        color: Color = .blue,
        onSave: (() -> Void)? = nil
    ) {
        self.title = title
        self.baselineTypes = baselineTypes
        self.color = color
        self.onSave = onSave
        self._viewModel = StateObject(wrappedValue: BaselineEditViewModel(baselineTypes: baselineTypes))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.isLoading {
                        ProgressView()
                            .padding(.vertical, 40)
                    } else if viewModel.questions.isEmpty {
                        noQuestionsView
                    } else {
                        ForEach(viewModel.questions) { question in
                            questionCard(for: question)
                        }
                    }

                    // Timing validation message
                    if let timingMessage = viewModel.timingValidationMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(timingMessage)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }

                    if let error = viewModel.error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isSaving ? "Saving..." : "Save") {
                        Task {
                            if await viewModel.saveAll() {
                                onSave?()
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canSave || viewModel.isSaving)
                }
            }
            .task {
                await viewModel.loadAll()
            }
        }
    }

    // MARK: - Question Card (uses reusable components)

    /// Whether this is the water amount question (needs unit picker)
    private func isWaterAmountQuestion(_ baselineType: String) -> Bool {
        baselineType == "baseline_water_amount"
    }

    @ViewBuilder
    private func questionCard(for question: BaselineQuestion) -> some View {
        let baselineType = question.baselineType ?? ""

        switch question.questionType {
        case "slider", "numeric":
            // Special handling for water amount question - use unit picker
            if isWaterAmountQuestion(baselineType) {
                BaselineEditWaterCard(
                    question: question,
                    value: numericBinding(for: baselineType),
                    selectedUnit: liquidUnitBinding,
                    color: color
                )
            } else {
                BaselineQuestionCard(
                    question: question,
                    value: numericBinding(for: baselineType),
                    color: color
                )
            }

        case "single_choice":
            // Use reusable single choice card (edit sheet version)
            BaselineEditSingleChoiceCard(
                question: question,
                options: viewModel.options(for: question),
                selectedValue: stringBinding(for: baselineType),
                color: color
            )

        case "boolean":
            // Use reusable boolean card (edit sheet version)
            BaselineEditBooleanCard(
                question: question,
                value: booleanBinding(for: baselineType),
                color: color
            )

        case "text":
            // Use reusable text card (edit sheet version)
            BaselineEditTextCard(
                question: question,
                value: textBinding(for: baselineType),
                color: color
            )

        case "multiple_choice":
            // Multiple choice still inline (less common)
            multipleChoiceCard(for: question)

        default:
            unknownTypeCard(for: question)
        }
    }

    // MARK: - Bindings

    private func numericBinding(for baselineType: String) -> Binding<Double?> {
        Binding(
            get: { viewModel.currentValue(for: baselineType)?.numericValue },
            set: { newValue in
                if let val = newValue {
                    viewModel.updateNumericValue(val, for: baselineType)
                }
            }
        )
    }

    private func stringBinding(for baselineType: String) -> Binding<String?> {
        Binding(
            get: { viewModel.currentValue(for: baselineType)?.stringValue },
            set: { newValue in
                if let val = newValue {
                    viewModel.updateStringValue(val, for: baselineType)
                }
            }
        )
    }

    private func booleanBinding(for baselineType: String) -> Binding<Bool?> {
        Binding(
            get: {
                guard let stringVal = viewModel.currentValue(for: baselineType)?.stringValue else { return nil }
                return stringVal == "true" || stringVal == "yes"
            },
            set: { newValue in
                if let val = newValue {
                    viewModel.updateStringValue(val ? "true" : "false", for: baselineType)
                }
            }
        )
    }

    private func textBinding(for baselineType: String) -> Binding<String> {
        Binding(
            get: { viewModel.currentValue(for: baselineType)?.stringValue ?? "" },
            set: { viewModel.updateStringValue($0, for: baselineType) }
        )
    }

    /// Binding for liquid unit picker (pre-set to patient's preference)
    private var liquidUnitBinding: Binding<LiquidDisplayUnit> {
        Binding(
            get: { viewModel.liquidUnit },
            set: { viewModel.liquidUnit = $0 }
        )
    }

    // MARK: - Multiple Choice (inline implementation)

    @ViewBuilder
    private func multipleChoiceCard(for question: BaselineQuestion) -> some View {
        let options = viewModel.options(for: question)
        let baselineType = question.baselineType ?? ""
        let currentValues = (viewModel.currentValue(for: baselineType)?.stringValue ?? "")
            .split(separator: ",")
            .map { String($0) }

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

            // Subtext
            if let subtext = question.questionSubtext {
                Text(subtext)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Options
            VStack(spacing: 8) {
                ForEach(options) { option in
                    let isSelected = currentValues.contains(option.optionValue)

                    Button {
                        var newValues = currentValues
                        if isSelected {
                            newValues.removeAll { $0 == option.optionValue }
                        } else {
                            newValues.append(option.optionValue)
                        }
                        viewModel.updateStringValue(newValues.joined(separator: ","), for: baselineType)
                    } label: {
                        HStack {
                            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                .foregroundColor(isSelected ? color : .secondary)

                            Text(option.optionLabel)
                                .font(.subheadline)
                                .foregroundColor(.primary)

                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(
                            isSelected
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

    // MARK: - Unknown Type Card

    @ViewBuilder
    private func unknownTypeCard(for question: BaselineQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question.questionText)
                .font(.subheadline)
                .fontWeight(.medium)

            Text("Unknown question type: \(question.questionType)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private var noQuestionsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No questions available")
                .font(.headline)
            Text("Baseline questions have not been configured for this category")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Preview

#Preview {
    BaselineEditSheet(
        title: "Edit Hydration Baseline",
        baselineTypes: ["baseline_water_amount", "hydration_timing_morning_pct"],
        color: .cyan
    )
}
