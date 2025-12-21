//
//  ProteinWizardView.swift
//  WellPath
//
//  Database-driven guided wizard for baseline setup.
//  Config loaded from display_baseline_views and display_baseline_view_subpages.
//  Questions loaded from baseline_questions.
//

import SwiftUI

struct ProteinWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ProteinWizardViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else {
                    wizardContent
                }
            }
            .modifier(MetricScreenBackground(color: viewModel.pillarColor))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Exit") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .task {
            await viewModel.loadInitialData()
        }
        .onChange(of: viewModel.isComplete) { _, isComplete in
            if isComplete {
                dismiss()
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            Text("Loading...")
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Wizard Content

    @ViewBuilder
    private var wizardContent: some View {
        if let subpage = viewModel.currentSubpage {
            WizardStepView(
                stepNumber: viewModel.currentStep,
                totalSteps: viewModel.totalSteps,
                title: subpage.title ?? "",
                subtitle: subpage.subtitle ?? "",
                color: viewModel.pillarColor
            ) {
                // Render content for this subpage
                subpageContent(subpage)
            }
            .onNext { handleNext(for: subpage) }
            .onBack { viewModel.previousStep() }
            .nextButton(nextButtonTitle(for: subpage))
            .nextEnabled(isNextEnabled(for: subpage))
        } else {
            // Fallback if no subpage found
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text("Loading wizard...")
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }

    // MARK: - Subpage Rendering

    @ViewBuilder
    private func subpageContent(_ subpage: BaselineViewSubpage) -> some View {
        switch subpage.subpageType {
        case "overview":
            overviewSubpage(subpage)
        case "card":
            cardSubpage(subpage)
        case "questions":
            questionsSubpage(subpage)
        case "summary_card":
            summaryCardSubpage(subpage)
        case "next_steps":
            nextStepsSubpage(subpage)
        default:
            EmptyView()
        }
    }

    // MARK: - Overview Subpage (intro benefits)

    private func overviewSubpage(_ subpage: BaselineViewSubpage) -> some View {
        VStack(spacing: 32) {
            // Icon from subpage or baseline view
            if let icon = subpage.icon ?? viewModel.baselineView?.icon {
                Image(systemName: icon)
                    .font(.system(size: 80))
                    .foregroundColor(.white)
            }

            // Content items
            if let items = subpage.contentItems, !items.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    if let title = subpage.title {
                        Text(title)
                            .font(.headline)
                            .padding(.bottom, 4)
                    }

                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: item.icon)
                                .font(.title3)
                                .foregroundColor(viewModel.pillarColor)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(item.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Card Subpage (metric card preview)

    private func cardSubpage(_ subpage: BaselineViewSubpage) -> some View {
        WizardCardPreview(
            explanation: subpage.cardExplanation ?? "",
            highlightPoints: subpage.highlightPoints ?? [],
            color: viewModel.pillarColor
        ) {
            cardPreview(for: subpage.displayCardId)
        }
    }

    @ViewBuilder
    private func cardPreview(for displayCardId: String?) -> some View {
        // Use static preview cards with sample data (non-interactive)
        switch displayCardId {
        case "CARD_PROTEIN_AMOUNT":
            ProteinAmountPreviewCard(color: viewModel.pillarColor)
        case "CARD_PROTEIN_TYPE":
            ProteinTypePreviewCard(color: viewModel.pillarColor)
        case "CARD_PROTEIN_RATIO":
            ProteinRatioPreviewCard(color: viewModel.pillarColor)
        default:
            // Generic placeholder
            VStack {
                Image(systemName: "fish.fill")
                    .font(.largeTitle)
                    .foregroundColor(viewModel.pillarColor)
                Text("Card Preview")
                    .font(.headline)
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Questions Subpage

    private func questionsSubpage(_ subpage: BaselineViewSubpage) -> some View {
        VStack(spacing: 20) {
            if viewModel.baselineQuestions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("No additional questions")
                        .font(.headline)
                    Text("Your baseline has already been set")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                // Questions
                ForEach(viewModel.baselineQuestions) { question in
                    BaselineQuestionCard(
                        question: question,
                        value: Binding(
                            get: { viewModel.getValue(for: question) },
                            set: { viewModel.setValue($0, for: question) }
                        ),
                        color: viewModel.pillarColor
                    )
                }

                // Tier validation and calculated values
                tierValidationView
            }
        }
    }

    // MARK: - Tier Validation View

    private var tierValidationView: some View {
        VStack(spacing: 16) {
            // Tier percentage validation
            HStack {
                Text("Tier Total:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(viewModel.tierPercentageSum))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(viewModel.tierPercentagesValid ? .green : .orange)
                if viewModel.tierPercentagesValid {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Text("(should be 100%)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            // Calculated Type Score
            if let typeScore = viewModel.calculatedTypeScore {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(viewModel.pillarColor)
                    Text("Type Score:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.0f", typeScore))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(viewModel.pillarColor)
                    Text("/ 100")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Calculated Ratio (if we have weight)
            if let ratio = viewModel.calculatedRatio {
                HStack {
                    Image(systemName: "scalemass.fill")
                        .foregroundColor(viewModel.pillarColor)
                    Text("Protein Ratio:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.2f", ratio))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(viewModel.ratioIsOptimal ? .green : viewModel.pillarColor)
                    Text("g/kg")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if viewModel.ratioIsOptimal {
                    Text("In optimal range (1.2-1.6 g/kg)")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if ratio < 1.2 {
                    Text("Below optimal (target: 1.2-1.6 g/kg)")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text("Above optimal (target: 1.2-1.6 g/kg)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            } else if viewModel.patientWeightKg == nil {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("Add your weight in Health Profile to calculate protein ratio")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Summary Card Subpage

    private func summaryCardSubpage(_ subpage: BaselineViewSubpage) -> some View {
        VStack(spacing: 20) {
            // Amount Baseline
            baselineSummaryRow(
                icon: "chart.bar.fill",
                title: "Daily Amount",
                value: viewModel.savedBaselines["daily_protein_g"],
                unit: "g",
                subtitle: "Your typical daily protein intake"
            )

            // Type Score Baseline
            baselineSummaryRow(
                icon: "star.fill",
                title: "Type Score",
                value: viewModel.savedBaselines["protein_type_score"],
                unit: "/ 100",
                subtitle: "Based on your protein source mix"
            )

            // Ratio Baseline
            if let ratio = viewModel.savedBaselines["daily_protein_ratio"] {
                baselineSummaryRow(
                    icon: "scalemass.fill",
                    title: "Protein Ratio",
                    value: ratio,
                    unit: "g/kg",
                    subtitle: viewModel.ratioIsOptimal ? "In optimal range!" : "Target: 1.2-1.6 g/kg"
                )
            } else {
                HStack {
                    Image(systemName: "scalemass.fill")
                        .foregroundColor(.secondary)
                    Text("Ratio baseline requires weight data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(12)
            }

            // Success message
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)

                Text("Baselines Saved!")
                    .font(.headline)

                Text("Your baselines will appear on the Protein screen. As you track, you'll see how your intake compares.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    private func baselineSummaryRow(icon: String, title: String, value: Double?, unit: String, subtitle: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(viewModel.pillarColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let value = value {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(formatBaselineValue(value))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(viewModel.pillarColor)
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("--")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func formatBaselineValue(_ value: Double) -> String {
        if value >= 10 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    // MARK: - Next Steps Subpage

    private func nextStepsSubpage(_ subpage: BaselineViewSubpage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = subpage.title {
                Text(title)
                    .font(.headline)
            }

            if let items = subpage.contentItems {
                ForEach(items) { step in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: step.icon)
                            .foregroundColor(viewModel.pillarColor)
                        VStack(alignment: .leading) {
                            Text(step.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(step.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Navigation Helpers

    private func handleNext(for subpage: BaselineViewSubpage) {
        switch subpage.subpageType {
        case "questions":
            // Save before advancing
            Task {
                let success = await viewModel.saveResponses()
                if success {
                    viewModel.nextStep()
                }
            }
        case "summary_card", "next_steps":
            // Last steps - complete the wizard
            if subpage.displayOrder == viewModel.totalSteps {
                viewModel.completeWizard()
            } else {
                viewModel.nextStep()
            }
        default:
            viewModel.nextStep()
        }
    }

    private func nextButtonTitle(for subpage: BaselineViewSubpage) -> String {
        // Check if this is the last step
        if subpage.displayOrder == viewModel.totalSteps {
            return "Complete Setup"
        }

        switch subpage.subpageType {
        case "questions":
            return viewModel.isSaving ? "Saving..." : "Save & Continue"
        default:
            return "Continue"
        }
    }

    private func isNextEnabled(for subpage: BaselineViewSubpage) -> Bool {
        switch subpage.subpageType {
        case "questions":
            // Require daily protein amount AND valid tier percentages
            let hasDailyProtein = viewModel.baselineResponses["BQ_PROTEIN_TOTAL"] != nil
            return hasDailyProtein && viewModel.tierPercentagesValid && !viewModel.isSaving
        default:
            return true
        }
    }
}

// MARK: - Baseline Question Card (Numeric Input)

struct BaselineQuestionCard: View {
    let question: BaselineQuestion
    @Binding var value: Double?
    let color: Color

    @State private var textValue: String = ""
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
                    Text(question.unitLabel)
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

// MARK: - Preview

#Preview("Protein Wizard") {
    ProteinWizardView()
}
