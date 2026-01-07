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
        case "score_explanation":
            scoreExplanationSubpage(subpage)
        case "score_display":
            scoreDisplaySubpage(subpage)
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
                    Text("In optimal range (\(viewModel.optimalRatioRangeText))")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if let optimalRange = viewModel.ratioScoringRanges.first(where: { $0.isOptimal }),
                          ratio < optimalRange.rangeLow {
                    Text("Below optimal (target: \(viewModel.optimalRatioRangeText))")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text("Above optimal (target: \(viewModel.optimalRatioRangeText))")
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

    // MARK: - Summary Card Subpage (Baselines Only)

    private func summaryCardSubpage(_ subpage: BaselineViewSubpage) -> some View {
        VStack(spacing: 20) {
            // Success header
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)

                Text("Baselines Saved!")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            // Baseline values
            VStack(spacing: 12) {
                // Amount Baseline
                baselineSummaryRow(
                    icon: "chart.bar.fill",
                    title: "Daily Amount",
                    value: viewModel.savedBaselines["daily_protein_g"],
                    unit: "g",
                    subtitle: "Your typical daily intake"
                )

                // Type Score Baseline
                baselineSummaryRow(
                    icon: "star.fill",
                    title: "Type Score",
                    value: viewModel.savedBaselines["protein_type_score"],
                    unit: "/ 100",
                    subtitle: "Quality of your protein sources"
                )

                // Ratio Baseline
                if let ratio = viewModel.savedBaselines["daily_protein_ratio"] {
                    baselineSummaryRow(
                        icon: "scalemass.fill",
                        title: "Protein Ratio",
                        value: ratio,
                        unit: "g/kg",
                        subtitle: viewModel.ratioIsOptimal ? "In optimal range!" : "Target: \(viewModel.optimalRatioRangeText)"
                    )
                }
            }

            // Next info
            Text("Next, let's see how your score is calculated...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }

    // MARK: - Score Explanation Subpage

    private func scoreExplanationSubpage(_ subpage: BaselineViewSubpage) -> some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: subpage.icon ?? "chart.pie.fill")
                .font(.system(size: 60))
                .foregroundColor(.white)

            // How score is calculated
            if let explanation = viewModel.scoreDisplayConfig?.scoringExplanation {
                VStack(alignment: .leading, spacing: 12) {
                    Text("How It's Calculated")
                        .font(.headline)

                    Text(explanation)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
            }

            // Score ranges
            if let rangeText = viewModel.scoreDisplayConfig?.optimalRangeText {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Score Ranges")
                        .font(.headline)

                    // Parse the range text (format: "80-100: Excellent | 60-79: Good...")
                    ForEach(parseScoreRanges(rangeText), id: \.range) { item in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 12, height: 12)
                            Text(item.range)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text(item.label)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
            }

            // Threshold explanation
            if let thresholdText = viewModel.scoreDisplayConfig?.thresholdExplanation {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(viewModel.pillarColor)
                        Text("Unlocking Tracked Scores")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    Text(thresholdText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }

    private func parseScoreRanges(_ text: String) -> [(range: String, label: String, color: Color)] {
        // Parse "80-100: Excellent protein habits | 60-79: Good..."
        let parts = text.components(separatedBy: " | ")
        return parts.compactMap { part in
            let components = part.components(separatedBy: ": ")
            guard components.count == 2 else { return nil }
            let range = components[0].trimmingCharacters(in: .whitespaces)
            let label = components[1].trimmingCharacters(in: .whitespaces)

            let color: Color
            if range.hasPrefix("80") { color = .green }
            else if range.hasPrefix("60") { color = .yellow }
            else if range.hasPrefix("40") { color = .orange }
            else { color = .red }

            return (range: range, label: label, color: color)
        }
    }

    // MARK: - Score Display Subpage

    private func scoreDisplaySubpage(_ subpage: BaselineViewSubpage) -> some View {
        VStack(spacing: 24) {
            // Score ring
            if let score = viewModel.proteinScore {
                VStack(spacing: 12) {
                    ScoreRingView(
                        score: Double(score),
                        maxScore: 100,
                        size: 160,
                        lineWidth: 16,
                        color: scoreColor(for: score)
                    ) {
                        AnyView(
                            Text("\(score)")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.primary)
                        )
                    }

                    Text(scoreLabel(for: score))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(scoreColor(for: score))
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(16)
            }

            // Source indicator
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(viewModel.pillarColor)
                Text("Based on your baseline")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(20)

            // What's next
            VStack(alignment: .leading, spacing: 12) {
                Text("What's Next?")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    nextStepRow(icon: "plus.circle.fill", text: "Log your protein intake daily")
                    nextStepRow(icon: "chart.line.uptrend.xyaxis", text: "Watch your score update over time")
                    nextStepRow(icon: "target", text: "Aim for the optimal range")
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    private func nextStepRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(viewModel.pillarColor)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }

    private func scoreColor(for score: Int) -> Color {
        if score >= 80 { return .green }
        else if score >= 60 { return .yellow }
        else if score >= 40 { return .orange }
        else { return .red }
    }

    private func scoreLabel(for score: Int) -> String {
        if score >= 80 { return "Excellent" }
        else if score >= 60 { return "Good" }
        else if score >= 40 { return "Fair" }
        else { return "Needs Improvement" }
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

// MARK: - Preview
// Note: BaselineQuestionCard is now in WellPath/Views/Components/Baseline/BaselineQuestionCard.swift

#Preview("Protein Wizard") {
    ProteinWizardView()
}
