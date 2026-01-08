//
//  SimpleBaselineWizardView.swift
//  WellPath
//
//  Generic wizard view for simple baseline categories.
//  Works for categories with servings/variety questions without complex calculations.
//

import SwiftUI

struct SimpleBaselineWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SimpleBaselineWizardViewModel
    @StateObject private var unitPrefsViewModel = UnitPreferencesViewModel()
    @State private var selectedLiquidUnit: LiquidDisplayUnit = .cup
    @State private var showingUnitInfo = false

    let categoryName: String

    init(
        baselineViewId: String,
        categoryId: String,
        categoryName: String,
        pillarName: String = "Healthful Nutrition",
        scoreId: String? = nil,
        scoreType: String? = nil
    ) {
        self.categoryName = categoryName
        _viewModel = StateObject(wrappedValue: SimpleBaselineWizardViewModel(
            baselineViewId: baselineViewId,
            categoryId: categoryId,
            pillarName: pillarName,
            scoreId: scoreId,
            scoreType: scoreType
        ))
    }

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
            await unitPrefsViewModel.loadPreferences()
            await viewModel.loadInitialData()

            // Set selected unit from preferences OR from stored baseline
            if viewModel.categoryId == "CAT_HYDRATION" {
                if let storedUnit = viewModel.getStoredUnit(for: "baseline_water_amount"),
                   let unit = LiquidDisplayUnit.fromShortLabel(storedUnit) {
                    selectedLiquidUnit = unit
                } else {
                    selectedLiquidUnit = unitPrefsViewModel.liquidUnit
                }
            }

            viewModel.prepopulateResponses()
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
                subpageContent(subpage)
            }
            .onNext { handleNext(for: subpage) }
            .onBack { viewModel.previousStep() }
            .nextButton(nextButtonTitle(for: subpage))
            .nextEnabled(isNextEnabled(for: subpage))
        } else {
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
        case "unit_preference":
            unitPreferenceSubpage(subpage)
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
        default:
            EmptyView()
        }
    }

    // MARK: - Overview Subpage

    private func overviewSubpage(_ subpage: BaselineViewSubpage) -> some View {
        VStack(spacing: 32) {
            if let icon = subpage.icon ?? viewModel.baselineView?.icon {
                Image(systemName: icon)
                    .font(.system(size: 80))
                    .foregroundColor(.white)
            }

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

    // MARK: - Unit Preference Subpage

    private func unitPreferenceSubpage(_ subpage: BaselineViewSubpage) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "ruler")
                .font(.system(size: 60))
                .foregroundColor(.white)

            Text("Choose Your Preferred Units")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Select how you'd like to track your water intake. You can change this later in Settings.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                ForEach(LiquidDisplayUnit.allCases, id: \.self) { unit in
                    Button {
                        selectedLiquidUnit = unit
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(unit.displayName)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text(exampleForUnit(unit))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if selectedLiquidUnit == unit {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(viewModel.pillarColor)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedLiquidUnit == unit ? viewModel.pillarColor : Color.clear, lineWidth: 2)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func exampleForUnit(_ unit: LiquidDisplayUnit) -> String {
        switch unit {
        case .cup: return "e.g., 8 cups per day"
        case .fluidOunce: return "e.g., 64 oz per day"
        case .milliliter: return "e.g., 2,000 mL per day"
        case .liter: return "e.g., 2 L per day"
        case .glass: return "e.g., 8 glasses per day"
        case .gallon: return "e.g., 0.5 gal per day"
        }
    }

    // MARK: - Card Subpage

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
        // Use static preview cards with sample data matching the actual card layouts
        switch displayCardId {
        // Vegetables
        case "CARD_VEGETABLES_SERVINGS":
            NutrientServingsPreviewCard(title: "Vegetable", color: viewModel.pillarColor, todayValue: 3.5, weeklyAvg: 4.2, unit: "servings")
        case "CARD_VEGETABLES_TYPE":
            NutrientTypePreviewCard(title: "Vegetable", color: viewModel.pillarColor, varietyScore: 78, typesCount: 5)

        // Fruits
        case "CARD_FRUITS_SERVINGS":
            NutrientServingsPreviewCard(title: "Fruit", color: viewModel.pillarColor, todayValue: 2.0, weeklyAvg: 2.5, unit: "servings")
        case "CARD_FRUITS_TYPE":
            NutrientTypePreviewCard(title: "Fruit", color: viewModel.pillarColor, varietyScore: 72, typesCount: 4)

        // Legumes
        case "CARD_LEGUMES_SERVINGS":
            NutrientServingsPreviewCard(title: "Legume", color: viewModel.pillarColor, todayValue: 1.0, weeklyAvg: 0.8, unit: "servings")
        case "CARD_LEGUMES_TYPE":
            NutrientTypePreviewCard(title: "Legume", color: viewModel.pillarColor, varietyScore: 65, typesCount: 3)

        // Whole Grains
        case "CARD_WHOLE_GRAINS_SERVINGS":
            NutrientServingsPreviewCard(title: "Whole Grain", color: viewModel.pillarColor, todayValue: 2.5, weeklyAvg: 3.0, unit: "servings")
        case "CARD_WHOLE_GRAINS_TYPE":
            NutrientTypePreviewCard(title: "Whole Grain", color: viewModel.pillarColor, varietyScore: 70, typesCount: 4)

        // Nuts & Seeds
        case "CARD_NUTS_SEEDS_SERVINGS":
            NutrientServingsPreviewCard(title: "Nuts & Seeds", color: viewModel.pillarColor, todayValue: 1.0, weeklyAvg: 1.2, unit: "servings")
        case "CARD_NUTS_SEEDS_TYPE":
            NutrientTypePreviewCard(title: "Nuts & Seeds", color: viewModel.pillarColor, varietyScore: 68, typesCount: 3)

        // Hydration
        case "CARD_HYDRATION_AMOUNT", "CARD_WATER_AMOUNT", "CARD_WATER_ML":
            WaterAmountPreviewCard(color: viewModel.pillarColor)
        case "CARD_HYDRATION_TIMING", "CARD_WATER_TIMING":
            WaterTimingPreviewCard(color: viewModel.pillarColor)

        // Ultra-Processed
        case "CARD_ULTRA_PROCESSED_SERVINGS":
            UltraProcessedPreviewCard(color: viewModel.pillarColor)

        // Sleep Duration
        case "CARD_SLEEP_DURATION":
            SleepDurationPreviewCard(color: viewModel.pillarColor)

        default:
            // Fallback generic card
            VStack(spacing: 12) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 40))
                    .foregroundColor(viewModel.pillarColor)

                Text(categoryName)
                    .font(.headline)
            }
            .padding()
            .frame(height: 100)
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
                ForEach(viewModel.baselineQuestions) { question in
                    if question.isChecklistQuestion {
                        BaselineChecklistCard(
                            question: question,
                            viewModel: viewModel,
                            color: viewModel.pillarColor
                        )
                    } else if question.isSingleChoiceQuestion {
                        BaselineSingleChoiceCard(
                            question: question,
                            viewModel: viewModel,
                            color: viewModel.pillarColor
                        )
                    } else {
                        // For hydration, only override unit for amount questions, not timing (which uses %)
                        let isTimingQuestion = question.baselineType?.contains("timing") == true
                        let displayUnit: String? = (viewModel.categoryId == "CAT_HYDRATION" && !isTimingQuestion)
                            ? selectedLiquidUnit.shortLabel
                            : nil

                        BaselineQuestionCard(
                            question: question,
                            value: Binding(
                                get: { viewModel.getValue(for: question) },
                                set: { viewModel.setValue($0, for: question) }
                            ),
                            color: viewModel.pillarColor,
                            displayUnit: displayUnit
                        )
                    }
                }

                // Show timing percentage validation for hydration timing questions
                if viewModel.hasTimingQuestions {
                    timingPercentageValidation
                }

                // Show unit conversion info button for hydration category (amount questions only)
                if viewModel.categoryId == "CAT_HYDRATION" && !viewModel.hasTimingQuestions {
                    Button(action: { showingUnitInfo = true }) {
                        Label("Unit conversions", systemImage: "info.circle")
                            .font(.subheadline)
                            .foregroundColor(viewModel.pillarColor)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .sheet(isPresented: $showingUnitInfo) {
            hydrationUnitInfoSheet
        }
    }

    // MARK: - Hydration Unit Info Sheet

    @ViewBuilder
    private var hydrationUnitInfoSheet: some View {
        NavigationStack {
            List {
                Section("Common Serving Sizes") {
                    unitInfoRow(icon: "drop.fill", name: "1 glass", detail: "8 fl oz (237 mL)")
                    unitInfoRow(icon: "cup.and.saucer.fill", name: "1 cup", detail: "8 fl oz (237 mL)")
                    unitInfoRow(icon: "waterbottle.fill", name: "Standard bottle", detail: "16.9 fl oz (500 mL)")
                    unitInfoRow(icon: "waterbottle.fill", name: "Large bottle", detail: "33.8 fl oz (1 L)")
                }

                Section("Unit Conversions") {
                    unitInfoRow(icon: "arrow.left.arrow.right", name: "1 fl oz", detail: "29.6 mL")
                    unitInfoRow(icon: "arrow.left.arrow.right", name: "1 cup", detail: "237 mL")
                    unitInfoRow(icon: "arrow.left.arrow.right", name: "1 liter", detail: "33.8 fl oz")
                    unitInfoRow(icon: "arrow.left.arrow.right", name: "1 gallon", detail: "3.79 L / 128 fl oz")
                }

                Section("Daily Hydration Goal") {
                    unitInfoRow(icon: "target", name: "Recommended", detail: "8 glasses (64 fl oz / ~2 L)")
                }
            }
            .navigationTitle("Water Units")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingUnitInfo = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private func unitInfoRow(icon: String, name: String, detail: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(viewModel.pillarColor)
                .frame(width: 24)
            Text(name)
            Spacer()
            Text(detail)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Timing Percentage Validation View

    @ViewBuilder
    private var timingPercentageValidation: some View {
        let sum = viewModel.timingPercentageSum
        let isValid = viewModel.timingPercentagesValid

        HStack {
            Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(isValid ? .green : .orange)

            Text("Total: \(Int(sum))%")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isValid ? .green : .primary)

            Spacer()

            if !isValid {
                Text("Must equal 100%")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isValid ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isValid ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Summary Card Subpage

    private func summaryCardSubpage(_ subpage: BaselineViewSubpage) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)

                Text("Baselines Saved!")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            VStack(spacing: 12) {
                ForEach(viewModel.baselineQuestions) { question in
                    if let baselineType = question.baselineType,
                       let value = viewModel.savedBaselines[baselineType] {
                        // For hydration, only override unit for amount questions, not timing (which uses %)
                        let isTimingQuestion = baselineType.contains("timing")
                        let displayUnit: String? = (viewModel.categoryId == "CAT_HYDRATION" && !isTimingQuestion)
                            ? selectedLiquidUnit.shortLabel
                            : nil
                        baselineSummaryRow(
                            icon: iconForQuestion(question),
                            title: question.displayText(withUnit: displayUnit),
                            value: value,
                            unit: displayUnit ?? question.unitLabel
                        )
                    }
                }
            }

            Text("Your baselines have been recorded.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }

    private func iconForQuestion(_ question: BaselineQuestion) -> String {
        if let baselineType = question.baselineType {
            if baselineType.contains("servings") {
                return "chart.bar.fill"
            } else if baselineType.contains("variety") {
                return "square.grid.3x3.fill"
            } else if baselineType.contains("timing") {
                return "clock.fill"
            } else if baselineType.contains("cups") || baselineType.contains("water") || baselineType.contains("hydration") {
                return "drop.fill"
            } else if baselineType.contains("caffeine") {
                return "cup.and.saucer.fill"
            }
        }
        return "checkmark.circle.fill"
    }

    // MARK: - Score Explanation Subpage

    private func scoreExplanationSubpage(_ subpage: BaselineViewSubpage) -> some View {
        VStack(spacing: 24) {
            Image(systemName: subpage.icon ?? "chart.pie.fill")
                .font(.system(size: 60))
                .foregroundColor(.white)

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

            if let rangeText = viewModel.scoreDisplayConfig?.optimalRangeText {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Score Ranges")
                        .font(.headline)

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
        }
    }

    private func parseScoreRanges(_ text: String) -> [(range: String, label: String, color: Color)] {
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
            // Score display with ScoreRingPill
            VStack(spacing: 16) {
                ScoreRingPill(
                    score: baselineScore,
                    iconName: iconForCategory,
                    label: "Baseline",
                    size: 100
                )

                Text(scoreLabelText)
                    .font(.headline)
                    .foregroundColor(scoreColor)

                Text("Your \(categoryName.lowercased()) baseline has been set")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)

            // Component breakdown (for categories with multiple components)
            if hasScoreComponents {
                scoreComponentsSection
            }

            // What's next
            VStack(alignment: .leading, spacing: 12) {
                Text("What's Next?")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    nextStepRow(icon: "plus.circle.fill", text: "Log your daily intake")
                    nextStepRow(icon: "chart.line.uptrend.xyaxis", text: "Track your progress over time")
                    nextStepRow(icon: "target", text: "Work towards your goals")
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Score Display Helpers

    /// Icon for the category (from display_card_categories or fallback)
    private var iconForCategory: String {
        switch viewModel.categoryId {
        case "CAT_HYDRATION": return "drop.fill"
        case "CAT_VEGETABLES": return "carrot.fill"
        case "CAT_FRUITS": return "apple.logo"
        case "CAT_LEGUMES": return "leaf.fill"
        case "CAT_WHOLE_GRAINS": return "wheat"
        case "CAT_NUTS_SEEDS": return "tree.fill"
        case "CAT_PROTEIN": return "fish.fill"
        case "CAT_CAFFEINE": return "cup.and.saucer.fill"
        case "CAT_ULTRA_PROCESSED": return "exclamationmark.triangle.fill"
        case "CAT_SLEEP_ROUTINE": return "moon.zzz.fill"
        case "CAT_SLEEP_ENVIRONMENT": return "bed.double.fill"
        default: return "chart.bar.fill"
        }
    }

    /// Calculate baseline score for the category
    private var baselineScore: Int? {
        switch viewModel.categoryId {
        case "CAT_HYDRATION":
            // Hydration combines amount and timing scores
            let amountScore = calculateHydrationAmountScore()
            let timingScore = viewModel.savedBaselines["hydration_timing_baseline_score"]
            if let amount = amountScore, let timing = timingScore {
                // Weight: 60% amount, 40% timing (matches daily scoring)
                return Int((amount * 0.6 + timing * 0.4).rounded())
            }
            return amountScore.map { Int($0) } ?? timingScore.map { Int($0) }

        case "CAT_SLEEP_ROUTINE", "CAT_SLEEP_ENVIRONMENT":
            // These use checklist scores stored directly
            if let score = viewModel.savedBaselines[viewModel.scoreType ?? ""] {
                return Int(score)
            }
            return nil

        default:
            // For other categories, calculate from servings baseline vs target
            return calculateServingsBasedScore()
        }
    }

    /// Calculate hydration amount score based on mL vs target (2000mL = 100%)
    private func calculateHydrationAmountScore() -> Double? {
        // Get the canonical value in mL
        guard let mlValue = viewModel.savedBaselines["baseline_water_amount"] else { return nil }

        // Target: 2000 mL (roughly 8 cups)
        let targetMl: Double = 2000.0
        let ratio = mlValue / targetMl

        // Score: 100 at target, scales down proportionally, cap at 100
        let score = min(100, ratio * 100)
        return score.rounded()
    }

    /// Calculate score for servings-based categories (vegetables, fruits, etc.)
    private func calculateServingsBasedScore() -> Int? {
        // Find the servings baseline for this category
        let servingsKey = viewModel.savedBaselines.keys.first { $0.contains("servings") }
        guard let key = servingsKey, let value = viewModel.savedBaselines[key] else { return nil }

        // Get target from baseline type metadata (or use defaults)
        let target: Double
        switch viewModel.categoryId {
        case "CAT_VEGETABLES": target = 5.0
        case "CAT_FRUITS": target = 3.0
        case "CAT_LEGUMES": target = 1.0
        case "CAT_WHOLE_GRAINS": target = 3.0
        case "CAT_NUTS_SEEDS": target = 1.0
        default: target = 3.0
        }

        let ratio = value / target
        let score = min(100, ratio * 100)
        return Int(score.rounded())
    }

    /// Score label text based on score value
    private var scoreLabelText: String {
        guard let score = baselineScore else { return "" }
        if score >= 80 { return "Excellent" }
        else if score >= 60 { return "Good" }
        else if score >= 40 { return "Fair" }
        else { return "Needs Improvement" }
    }

    /// Score color based on value
    private var scoreColor: Color {
        guard let score = baselineScore else { return .secondary }
        if score >= 80 { return .green }
        else if score >= 60 { return .yellow }
        else if score >= 40 { return .orange }
        else { return .red }
    }

    /// Whether this category has component scores to show
    private var hasScoreComponents: Bool {
        viewModel.categoryId == "CAT_HYDRATION"
    }

    /// Component breakdown section for categories with multiple score components
    @ViewBuilder
    private var scoreComponentsSection: some View {
        if viewModel.categoryId == "CAT_HYDRATION" {
            VStack(alignment: .leading, spacing: 12) {
                Text("Score Components")
                    .font(.headline)

                HStack(spacing: 24) {
                    // Amount component
                    VStack(spacing: 8) {
                        ScoreRingPill(
                            score: calculateHydrationAmountScore().map { Int($0) },
                            iconName: "drop.fill",
                            label: "Amount",
                            size: 60
                        )
                        Text("60%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Timing component
                    VStack(spacing: 8) {
                        ScoreRingPill(
                            score: viewModel.savedBaselines["hydration_timing_baseline_score"].map { Int($0) },
                            iconName: "clock.fill",
                            label: "Timing",
                            size: 60
                        )
                        Text("40%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
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

    private func baselineSummaryRow(icon: String, title: String, value: Double, unit: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(viewModel.pillarColor)
                .frame(width: 32)

            Text(title)
                .font(.subheadline)
                .lineLimit(2)

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(formatValue(value))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(viewModel.pillarColor)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func formatValue(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    // MARK: - Navigation Helpers

    private func handleNext(for subpage: BaselineViewSubpage) {
        switch subpage.subpageType {
        case "unit_preference":
            Task {
                // Save the selected liquid unit preference
                unitPrefsViewModel.liquidUnit = selectedLiquidUnit
                let _ = await unitPrefsViewModel.savePreferences()
                viewModel.nextStep()
            }
        case "questions":
            Task {
                // Pass liquid unit for hydration categories to enable canonical conversion
                let liquidUnit = viewModel.categoryId == "CAT_HYDRATION" ? selectedLiquidUnit : nil
                let success = await viewModel.saveResponses(liquidUnit: liquidUnit)
                if success {
                    viewModel.nextStep()
                }
            }
        case "score_display":
            viewModel.completeWizard()
        default:
            if subpage.displayOrder == viewModel.totalSteps {
                viewModel.completeWizard()
            } else {
                viewModel.nextStep()
            }
        }
    }

    private func nextButtonTitle(for subpage: BaselineViewSubpage) -> String {
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
            return viewModel.allQuestionsAnswered && !viewModel.isSaving
        default:
            return true
        }
    }
}

// MARK: - Convenience Factory Views

struct VegetablesWizardView: View {
    var body: some View {
        SimpleBaselineWizardView(
            baselineViewId: "BASELINE_VIEW_VEGETABLES",
            categoryId: "CAT_VEGETABLES",
            categoryName: "Vegetables"
        )
    }
}

struct FruitsWizardView: View {
    var body: some View {
        SimpleBaselineWizardView(
            baselineViewId: "BASELINE_VIEW_FRUITS",
            categoryId: "CAT_FRUITS",
            categoryName: "Fruits"
        )
    }
}

struct WholeGrainsWizardView: View {
    var body: some View {
        SimpleBaselineWizardView(
            baselineViewId: "BASELINE_VIEW_WHOLE_GRAINS",
            categoryId: "CAT_WHOLE_GRAINS",
            categoryName: "Whole Grains"
        )
    }
}

struct LegumesWizardView: View {
    var body: some View {
        SimpleBaselineWizardView(
            baselineViewId: "BASELINE_VIEW_LEGUMES",
            categoryId: "CAT_LEGUMES",
            categoryName: "Legumes"
        )
    }
}

struct NutsSeedsWizardView: View {
    var body: some View {
        SimpleBaselineWizardView(
            baselineViewId: "BASELINE_VIEW_NUTS_SEEDS",
            categoryId: "CAT_NUTS_SEEDS",
            categoryName: "Nuts & Seeds"
        )
    }
}

struct HydrationWizardView: View {
    var body: some View {
        SimpleBaselineWizardView(
            baselineViewId: "BASELINE_VIEW_HYDRATION",
            categoryId: "CAT_HYDRATION",
            categoryName: "Hydration"
        )
    }
}

struct UltraProcessedWizardView: View {
    var body: some View {
        SimpleBaselineWizardView(
            baselineViewId: "BASELINE_VIEW_ULTRA_PROCESSED",
            categoryId: "CAT_ULTRA_PROCESSED",
            categoryName: "Ultra-Processed Foods"
        )
    }
}

struct MealPatternsWizardView: View {
    var body: some View {
        SimpleBaselineWizardView(
            baselineViewId: "BASELINE_VIEW_MEAL_PATTERNS",
            categoryId: "CAT_MEAL_PATTERNS",
            categoryName: "Meal Patterns"
        )
    }
}

// Note: CaffeineWizardView is in its own file with specialized card views
// Note: SleepDurationWizardView is in its own file at SleepDuration/Views/SleepDurationWizardView.swift

// MARK: - Sleep Wizard Views

struct SleepRoutineWizardView: View {
    var body: some View {
        SimpleBaselineWizardView(
            baselineViewId: "BASELINE_VIEW_SLEEP_ROUTINE",
            categoryId: "CAT_SLEEP_ROUTINE",
            categoryName: "Sleep Routine",
            pillarName: "Restorative Sleep",
            scoreId: "SCORE_SLEEP_ROUTINE",
            scoreType: "sleep_routine_score"
        )
    }
}

struct SleepEnvironmentWizardView: View {
    var body: some View {
        SimpleBaselineWizardView(
            baselineViewId: "BASELINE_VIEW_SLEEP_ENVIRONMENT",
            categoryId: "CAT_SLEEP_ENVIRONMENT",
            categoryName: "Sleep Environment",
            pillarName: "Restorative Sleep",
            scoreId: "SCORE_SLEEP_ENVIRONMENT",
            scoreType: "sleep_environment_score"
        )
    }
}

// MARK: - Baseline Checklist Card

/// Card for multi_select_checklist questions with weighted options
struct BaselineChecklistCard: View {
    let question: BaselineQuestion
    @ObservedObject var viewModel: SimpleBaselineWizardViewModel
    let color: Color

    private var options: [ViewAssessmentResponseOption] {
        viewModel.getOptions(for: question)
    }

    private var currentScore: Int {
        viewModel.calculateChecklistScore(for: question)
    }

    private var maxScore: Int {
        viewModel.getMaxScore(for: question)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            // Options grouped by weight
            let highImpact = options.filter { $0.optionValue == 3 }
            let mediumImpact = options.filter { $0.optionValue == 2 }
            let lowerImpact = options.filter { $0.optionValue == 1 }

            if !highImpact.isEmpty {
                optionSection(title: "High Impact", points: 3, options: highImpact)
            }

            if !mediumImpact.isEmpty {
                optionSection(title: "Medium Impact", points: 2, options: mediumImpact)
            }

            if !lowerImpact.isEmpty {
                optionSection(title: "Lower Impact", points: 1, options: lowerImpact)
            }

            // Score display
            HStack {
                Text("Your score:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(currentScore)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                Text("/ \(maxScore)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func optionSection(title: String, points: Int, options: [ViewAssessmentResponseOption]) -> some View {
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
                optionButton(option)
            }
        }
    }

    @ViewBuilder
    private func optionButton(_ option: ViewAssessmentResponseOption) -> some View {
        let isSelected = viewModel.isOptionSelected(option, for: question)

        Button {
            viewModel.toggleOption(option, for: question)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundColor(isSelected ? color : .secondary)

                Text(option.optionText)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? color.opacity(0.1) : Color(uiColor: .tertiarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Single Choice Card (Radio Button Style)

struct BaselineSingleChoiceCard: View {
    let question: BaselineQuestion
    @ObservedObject var viewModel: SimpleBaselineWizardViewModel
    let color: Color

    private var options: [ViewAssessmentResponseOption] {
        viewModel.getOptions(for: question)
    }

    private var selectedValue: Int? {
        viewModel.getSelectedOption(for: question)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            // Options as radio buttons
            VStack(spacing: 8) {
                ForEach(options) { option in
                    optionRow(option)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func optionRow(_ option: ViewAssessmentResponseOption) -> some View {
        let isSelected = selectedValue == option.optionValue

        Button {
            viewModel.selectOption(option, for: question)
        } label: {
            HStack(spacing: 12) {
                // Radio button style circle
                ZStack {
                    Circle()
                        .stroke(isSelected ? color : Color.secondary.opacity(0.5), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(color)
                            .frame(width: 12, height: 12)
                    }
                }

                Text(option.optionText)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? color.opacity(0.1) : Color(uiColor: .tertiarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Vegetables") {
    VegetablesWizardView()
}

#Preview("Fruits") {
    FruitsWizardView()
}
