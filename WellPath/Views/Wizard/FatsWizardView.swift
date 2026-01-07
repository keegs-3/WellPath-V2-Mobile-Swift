//
//  FatsWizardView.swift
//  WellPath
//
//  Wizard view for Fats baseline setup.
//  Has tier percentages (good fats vs limit fats) that must add to 100%.
//

import SwiftUI
import Supabase

struct FatsWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FatsWizardViewModel()

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
        switch displayCardId {
        case "CARD_FATS_AMOUNT":
            FatsAmountPreviewCard(color: viewModel.pillarColor)
        case "CARD_FATS_TYPE":
            FatsTypePreviewCard(color: viewModel.pillarColor)
        default:
            // Fallback
            VStack(spacing: 12) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 40))
                    .foregroundColor(viewModel.pillarColor)
                Text("Fat Sources")
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
                // Questions - use custom card for total grams, standard for percentages
                ForEach(viewModel.baselineQuestions) { question in
                    if question.baselineType == "daily_fat_g" {
                        FatGramsQuestionCard(
                            question: question,
                            value: Binding(
                                get: { viewModel.getValue(for: question) },
                                set: { viewModel.setValue($0, for: question) }
                            ),
                            color: viewModel.pillarColor
                        )
                    } else {
                        BaselineQuestionCard(
                            question: question,
                            value: Binding(
                                get: { viewModel.getValue(for: question) },
                                set: { viewModel.setValue($0, for: question) }
                            ),
                            color: viewModel.pillarColor
                        )
                    }
                }

                // Tier validation view (only show if percentage questions are visible)
                if viewModel.hasPercentageQuestions {
                    tierValidationView
                }
            }
        }
    }

    // MARK: - Tier Validation View

    private var tierValidationView: some View {
        VStack(spacing: 16) {
            // Percentage validation
            HStack {
                Text("Total:")
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

            // Visual breakdown
            if viewModel.tierPercentagesValid {
                HStack(spacing: 2) {
                    // Good fats
                    let goodPct = viewModel.baselineResponses["BQ_FATS_GOOD"] ?? 0
                    if goodPct > 0 {
                        Rectangle()
                            .fill(Color.green)
                            .frame(height: 12)
                            .frame(width: CGFloat(goodPct) * 2)
                    }
                    // Limit fats
                    let limitPct = viewModel.baselineResponses["BQ_FATS_LIMIT"] ?? 0
                    if limitPct > 0 {
                        Rectangle()
                            .fill(Color.orange)
                            .frame(height: 12)
                            .frame(width: CGFloat(limitPct) * 2)
                    }
                }
                .cornerRadius(6)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
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

            // Saved values
            VStack(spacing: 12) {
                if let totalGrams = viewModel.savedBaselines["daily_fat_g"] {
                    baselineSummaryRow(
                        icon: "scalemass.fill",
                        title: "Daily Fat Intake",
                        value: totalGrams,
                        unit: "g",
                        color: viewModel.pillarColor
                    )
                }
                if let goodPct = viewModel.savedBaselines["fats_good_pct"] {
                    baselineSummaryRow(
                        icon: "hand.thumbsup.fill",
                        title: "Good Fats",
                        value: goodPct,
                        unit: "%",
                        color: .green
                    )
                }
                if let limitPct = viewModel.savedBaselines["fats_limit_pct"] {
                    baselineSummaryRow(
                        icon: "exclamationmark.triangle.fill",
                        title: "Limit Fats",
                        value: limitPct,
                        unit: "%",
                        color: .orange
                    )
                }
            }

            Text("Now you can track your fat sources over time.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }

    // MARK: - Score Explanation Subpage

    private func scoreExplanationSubpage(_ subpage: BaselineViewSubpage) -> some View {
        VStack(spacing: 24) {
            Image(systemName: subpage.icon ?? "chart.pie.fill")
                .font(.system(size: 60))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 12) {
                Text("Fat Quality Matters")
                    .font(.headline)

                Text("Your fat score is based on the ratio of healthy unsaturated fats to saturated and trans fats. Higher percentages of good fats lead to better scores.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 12) {
                Text("Good Fats (Maximize)")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    fatTypeRow(name: "Monounsaturated", examples: "Olive oil, avocados, nuts", color: .green)
                    fatTypeRow(name: "Polyunsaturated", examples: "Fish, walnuts, flaxseed", color: .green)
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 12) {
                Text("Fats to Limit")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    fatTypeRow(name: "Saturated", examples: "Butter, red meat, cheese", color: .orange)
                    fatTypeRow(name: "Trans", examples: "Fried foods, baked goods", color: .red)
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    private func fatTypeRow(name: String, examples: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(examples)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Score Display Subpage

    private func scoreDisplaySubpage(_ subpage: BaselineViewSubpage) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)

                Text("Setup Complete!")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("You've set your fats baseline.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)

            VStack(alignment: .leading, spacing: 12) {
                Text("What's Next?")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    nextStepRow(icon: "plus.circle.fill", text: "Log your meals to track fat sources")
                    nextStepRow(icon: "chart.line.uptrend.xyaxis", text: "See how your fat ratio changes")
                    nextStepRow(icon: "heart.fill", text: "Aim for 70%+ from good sources")
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

    private func baselineSummaryRow(icon: String, title: String, value: Double, unit: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)

            Text(title)
                .font(.subheadline)

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.0f", value))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
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
            Task {
                let success = await viewModel.saveResponses()
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
            return viewModel.allResponsesValid && !viewModel.isSaving
        default:
            return true
        }
    }
}

// MARK: - Fats Wizard ViewModel

@MainActor
class FatsWizardViewModel: ObservableObject {
    @Published var currentStep = 1
    @Published var isLoading = true
    @Published var isSaving = false

    @Published var baselineView: BaselineView?
    @Published var subpages: [BaselineViewSubpage] = []

    @Published var baselineQuestions: [BaselineQuestion] = []
    @Published var baselineResponses: [String: Double] = [:]

    @Published var savedBaselines: [String: Double] = [:]
    @Published var isComplete = false

    let baselineViewId = "BASELINE_VIEW_FATS"
    let categoryId = "CAT_FATS"

    // MARK: - Computed Properties

    var totalSteps: Int { subpages.count }

    var currentSubpage: BaselineViewSubpage? {
        subpages.first { $0.displayOrder == currentStep }
    }

    var pillarColor: Color {
        MetricsUIConfig.getPillarColor(for: "Healthful Nutrition")
    }

    /// Check if THIS category has existing baselines (not any baseline)
    var hasExistingBaseline: Bool {
        let categoryBaselineTypes = baselineQuestions.compactMap { $0.baselineType }
        guard !categoryBaselineTypes.isEmpty else { return false }
        return categoryBaselineTypes.allSatisfy { savedBaselines[$0] != nil }
    }

    var hasPercentageQuestions: Bool {
        baselineQuestions.contains { $0.baselineType == "fats_good_pct" || $0.baselineType == "fats_limit_pct" }
    }

    var hasTotalGramsQuestion: Bool {
        baselineQuestions.contains { $0.baselineType == "daily_fat_g" }
    }

    var tierPercentageSum: Double {
        let good = baselineResponses["BQ_FATS_GOOD"] ?? 0
        let limit = baselineResponses["BQ_FATS_LIMIT"] ?? 0
        return good + limit
    }

    var tierPercentagesValid: Bool {
        abs(tierPercentageSum - 100) < 0.01
    }

    var totalGramsValid: Bool {
        if let gramsValue = baselineResponses["BQ_FATS_TOTAL"] {
            return gramsValue > 0
        }
        return true // If question not present, consider valid
    }

    var allResponsesValid: Bool {
        let percentagesOk = !hasPercentageQuestions || tierPercentagesValid
        let gramsOk = !hasTotalGramsQuestion || totalGramsValid
        return percentagesOk && gramsOk
    }

    // MARK: - Lifecycle

    func loadInitialData() async {
        isLoading = true

        async let viewTask: () = loadBaselineView()
        async let questionsTask: () = loadBaselineQuestions()
        async let baselinesTask: () = loadExistingBaselines()

        _ = await (viewTask, questionsTask, baselinesTask)
        await loadSubpages()

        // Pre-populate responses
        for question in baselineQuestions {
            if let baselineType = question.baselineType,
               let existingValue = savedBaselines[baselineType] {
                baselineResponses[question.questionId] = existingValue
            }
        }

        isLoading = false
    }

    // MARK: - Data Loading

    private func loadBaselineView() async {
        do {
            let client = SupabaseManager.shared.client
            let views: [BaselineView] = try await client
                .from("display_baseline_views")
                .select()
                .eq("view_id", value: baselineViewId)
                .eq("is_active", value: true)
                .limit(1)
                .execute()
                .value
            baselineView = views.first
        } catch {
            print("Error loading baseline view: \(error)")
        }
    }

    private func loadSubpages() async {
        guard baselineView != nil else { return }

        do {
            let client = SupabaseManager.shared.client
            let loadedSubpages: [BaselineViewSubpage] = try await client
                .from("display_baseline_view_subpages")
                .select()
                .eq("baseline_view_id", value: baselineViewId)
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            if hasExistingBaseline {
                let tourSubpages = loadedSubpages.filter { subpage in
                    subpage.subpageType != "questions" && subpage.subpageType != "summary_card"
                }
                subpages = tourSubpages.enumerated().map { index, subpage in
                    var modified = subpage
                    modified.displayOrder = index + 1
                    return modified
                }
            } else {
                subpages = loadedSubpages
            }
        } catch {
            print("Error loading subpages: \(error)")
        }
    }

    private func loadBaselineQuestions() async {
        do {
            let client = SupabaseManager.shared.client
            let questions: [BaselineQuestion] = try await client
                .from("baseline_questions")
                .select()
                .eq("category_id", value: categoryId)
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value
            baselineQuestions = questions
        } catch {
            print("Error loading baseline questions: \(error)")
        }
    }

    private func loadExistingBaselines() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            struct BaselineData: Decodable {
                let baselineType: String
                let value: Double
                enum CodingKeys: String, CodingKey {
                    case baselineType = "baseline_type"
                    case value
                }
            }

            let baselines: [BaselineData] = try await client
                .from("patient_baseline_samples")
                .select("baseline_type, value")
                .eq("patient_id", value: userId.uuidString)
                .eq("is_current", value: true)
                .execute()
                .value

            for baseline in baselines {
                savedBaselines[baseline.baselineType] = baseline.value
            }
        } catch {
            print("Error loading baselines: \(error)")
        }
    }

    // MARK: - Response Handler

    func setValue(_ value: Double?, for question: BaselineQuestion) {
        if let value = value {
            baselineResponses[question.questionId] = value
        } else {
            baselineResponses.removeValue(forKey: question.questionId)
        }
    }

    func getValue(for question: BaselineQuestion) -> Double? {
        baselineResponses[question.questionId]
    }

    // MARK: - Save Responses

    func saveResponses() async -> Bool {
        isSaving = true

        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFullDate]
            let today = dateFormatter.string(from: Date())

            for question in baselineQuestions {
                guard let baselineType = question.baselineType,
                      let value = baselineResponses[question.questionId] else { continue }

                // Determine unit based on baseline type
                let unit: String
                if baselineType == "daily_fat_g" {
                    unit = "gram"
                } else {
                    unit = "percent"
                }

                let record: [String: AnyJSON] = [
                    "patient_id": .string(userId.uuidString),
                    "baseline_type": .string(baselineType),
                    "value": .double(value),
                    "unit": .string(unit),
                    "source": .string("onboarding"),
                    "assessment_date": .string(today),
                    "is_current": .bool(true)
                ]

                try await client
                    .from("patient_baseline_samples")
                    .insert(record)
                    .execute()

                savedBaselines[baselineType] = value
            }

            isSaving = false
            return true

        } catch {
            print("Error saving baselines: \(error)")
            isSaving = false
            return false
        }
    }

    // MARK: - Navigation

    func nextStep() {
        if currentStep < totalSteps {
            withAnimation { currentStep += 1 }
        }
    }

    func previousStep() {
        if currentStep > 1 {
            withAnimation { currentStep -= 1 }
        }
    }

    func completeWizard() {
        UserDefaults.standard.set(true, forKey: "baseline_wizard_\(categoryId)_completed")
        isComplete = true
    }
}

// MARK: - Fat Grams Question Card

struct FatGramsQuestionCard: View {
    let question: BaselineQuestion
    @Binding var value: Double?
    let color: Color

    // Visual guides for different fat gram amounts
    private let fatExamples: [(grams: Int, description: String, foods: String)] = [
        (30, "Light", "1 tbsp olive oil + 1 oz nuts"),
        (50, "Moderate", "2 tbsp oil + avocado half"),
        (65, "Average", "Typical balanced diet"),
        (80, "Hearty", "Higher fat meals"),
        (100, "High", "Keto or high-fat diet"),
        (120, "Very High", "Very high fat intake")
    ]

    private var selectedGrams: Int {
        Int(value ?? 65)
    }

    private var nearestExample: (grams: Int, description: String, foods: String) {
        fatExamples.min(by: { abs($0.grams - selectedGrams) < abs($1.grams - selectedGrams) }) ?? fatExamples[2]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Question
            Text(question.questionText)
                .font(.headline)

            if let subtext = question.questionSubtext {
                Text(subtext)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Current value display
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Text("\(selectedGrams)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(color)
                    Text("grams/day")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 8)

            // Slider
            Slider(
                value: Binding(
                    get: { value ?? 65 },
                    set: { value = $0 }
                ),
                in: 20...150,
                step: 5
            )
            .tint(color)

            // Scale markers
            HStack {
                Text("20g")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("65g")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("150g")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Visual guide cards
            VStack(alignment: .leading, spacing: 8) {
                Text("What does this look like?")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    ForEach(fatExamples.prefix(4), id: \.grams) { example in
                        fatGuideChip(example: example)
                    }
                }

                // Show selected example detail
                HStack(spacing: 12) {
                    Image(systemName: "fork.knife")
                        .font(.title2)
                        .foregroundColor(color)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(nearestExample.grams)g - \(nearestExample.description)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(nearestExample.foods)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(color.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func fatGuideChip(example: (grams: Int, description: String, foods: String)) -> some View {
        let isSelected = abs(selectedGrams - example.grams) <= 10

        return Button {
            value = Double(example.grams)
        } label: {
            VStack(spacing: 2) {
                Text("\(example.grams)g")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(example.description)
                    .font(.system(size: 9))
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? color : color.opacity(0.15))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    FatsWizardView()
}
