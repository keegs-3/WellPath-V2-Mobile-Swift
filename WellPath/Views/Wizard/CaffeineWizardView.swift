//
//  CaffeineWizardView.swift
//  WellPath
//
//  Specialized wizard view for Caffeine baseline setup.
//  Includes custom card previews for Caffeine Intake and Cutoff Time.
//

import SwiftUI
import Charts
import Supabase

struct CaffeineWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CaffeineWizardViewModel()

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
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 80))
                .foregroundColor(.white)

            if let items = subpage.contentItems, !items.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
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
            cardPreview(for: subpage.displayCardId ?? subpage.subpageId)
        }
    }

    @ViewBuilder
    private func cardPreview(for cardId: String?) -> some View {
        switch cardId {
        case "SUBPAGE_CAFFEINE_CARD_AMOUNT", "CARD_CAFFEINE_AMOUNT":
            CaffeineAmountPreviewCard(color: viewModel.pillarColor)
        case "SUBPAGE_CAFFEINE_CARD_TIMING", "CARD_CAFFEINE_CUTOFF":
            CaffeineCutoffPreviewCard(color: viewModel.pillarColor)
        default:
            CaffeineAmountPreviewCard(color: viewModel.pillarColor)
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
                // Show non-cutoff questions first
                ForEach(viewModel.baselineQuestions.filter { $0.questionId != "BQ_CAFFEINE_CUTOFF" }) { question in
                    switch question.questionId {
                    case "BQ_CAFFEINE_TIER1_PCT":
                        // Slider for source percentage
                        CaffeineSourceSliderCard(
                            question: question,
                            value: Binding(
                                get: { viewModel.getValue(for: question) },
                                set: { viewModel.setValue($0, for: question) }
                            ),
                            color: viewModel.pillarColor
                        )
                    default:
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

                // Timing distribution card (replaces cutoff time picker)
                CaffeineTimingDistributionCard(
                    morningPct: $viewModel.timingMorningPct,
                    earlyAfternoonPct: $viewModel.timingEarlyAfternoonPct,
                    lateAfternoonPct: $viewModel.timingLateAfternoonPct,
                    eveningPct: $viewModel.timingEveningPct,
                    color: viewModel.pillarColor
                )

                // Caffeine reference guide
                caffeineReferenceGuide
            }
        }
    }

    private var caffeineReferenceGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Caffeine Reference")
                .font(.subheadline)
                .fontWeight(.medium)

            VStack(alignment: .leading, spacing: 8) {
                caffeineRow(item: "Cup of coffee", amount: "~95mg")
                caffeineRow(item: "Espresso shot", amount: "~63mg")
                caffeineRow(item: "Cup of black tea", amount: "~47mg")
                caffeineRow(item: "Cup of green tea", amount: "~28mg")
                caffeineRow(item: "Can of cola", amount: "~34mg")
                caffeineRow(item: "Energy drink", amount: "~80-150mg")
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func caffeineRow(item: String, amount: String) -> some View {
        HStack {
            Text(item)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(amount)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(viewModel.pillarColor)
        }
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
                if let mg = viewModel.savedBaselines["daily_caffeine_mg"] {
                    baselineSummaryRow(
                        icon: "cup.and.saucer.fill",
                        title: "Daily Intake",
                        value: mg,
                        unit: "mg"
                    )
                }
                if let tier1Pct = viewModel.savedBaselines["caffeine_tier1_pct"] {
                    baselineSummaryRow(
                        icon: "leaf.fill",
                        title: "Healthy Sources",
                        value: tier1Pct,
                        unit: "%"
                    )
                }

                // Timing distribution summary
                if viewModel.savedBaselines["caffeine_timing_morning_pct"] != nil {
                    timingDistributionSummary
                }
            }

            Text("Your caffeine habits have been recorded.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }

    private var timingDistributionSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.title2)
                    .foregroundColor(viewModel.pillarColor)
                    .frame(width: 32)

                Text("Timing Distribution")
                    .font(.subheadline)

                Spacer()
            }

            HStack(spacing: 12) {
                timingPill(label: "AM", value: viewModel.timingMorningPct, color: .green)
                timingPill(label: "Early PM", value: viewModel.timingEarlyAfternoonPct, color: .yellow)
                timingPill(label: "Late PM", value: viewModel.timingLateAfternoonPct, color: .orange)
                timingPill(label: "Eve", value: viewModel.timingEveningPct, color: .red)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func timingPill(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(value.rounded()))%")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatHour(_ hour: Double) -> String {
        let h = Int(hour)
        if h == 0 { return "12 AM" }
        if h == 12 { return "12 PM" }
        if h < 12 { return "\(h) AM" }
        return "\(h - 12) PM"
    }

    // MARK: - Score Explanation Subpage

    private func scoreExplanationSubpage(_ subpage: BaselineViewSubpage) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 60))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 12) {
                Text("How Caffeine Affects Sleep")
                    .font(.headline)

                Text("Caffeine has a half-life of 5-6 hours. Having caffeine too late in the day can significantly impact your sleep quality, even if you fall asleep easily.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 12) {
                Text("Optimal Caffeine Habits")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    habitRow(icon: "sunrise.fill", text: "Keep caffeine before 2 PM", color: .green)
                    habitRow(icon: "gauge.with.needle.fill", text: "Limit to 400mg daily", color: .green)
                    habitRow(icon: "moon.zzz.fill", text: "Earlier cutoff = better sleep", color: .blue)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 12) {
                Text("Score Components")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    scoreComponentRow(component: "Cutoff Time", weight: "60%", description: "Earlier is better for sleep")
                    scoreComponentRow(component: "Daily Amount", weight: "30%", description: "Moderate intake preferred")
                    scoreComponentRow(component: "Source Quality", weight: "10%", description: "Tea & coffee over energy drinks")
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    private func habitRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }

    private func scoreComponentRow(component: String, weight: String, description: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(component)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(weight)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(viewModel.pillarColor)
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

                Text("You've set your caffeine baseline.")
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
                    nextStepRow(icon: "plus.circle.fill", text: "Log caffeine when you drink it")
                    nextStepRow(icon: "clock.fill", text: "Track your cutoff times")
                    nextStepRow(icon: "moon.zzz.fill", text: "Watch how it affects your sleep")
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

    private func baselineSummaryRow(icon: String, title: String, value: Double, unit: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(viewModel.pillarColor)
                .frame(width: 32)

            Text(title)
                .font(.subheadline)

            Spacer()

            if title == "Cutoff Time" {
                Text(unit)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(viewModel.pillarColor)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.0f", value))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(viewModel.pillarColor)
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
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
            return viewModel.allQuestionsAnswered && !viewModel.isSaving
        default:
            return true
        }
    }
}

// Note: CaffeineAmountPreviewCard and CaffeineTypePreviewCard are in WizardCardPreviews.swift

// MARK: - Caffeine Cutoff Preview Card (with LineMark chart)

struct CaffeineCutoffPreviewCard: View {
    let color: Color

    // Sample data showing caffeine levels throughout day
    private var caffeineData: [(hour: Int, level: Double)] {
        [
            (6, 0), (7, 95), (8, 140), (9, 100), (10, 70),
            (11, 50), (12, 90), (13, 65), (14, 45), (15, 30),
            (16, 20), (17, 14), (18, 10), (19, 7), (20, 5),
            (21, 3), (22, 2)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cutoff Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("2:00")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("PM")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }

            // Caffeine level line chart
            Chart {
                ForEach(caffeineData, id: \.hour) { point in
                    LineMark(
                        x: .value("Hour", point.hour),
                        y: .value("Level", point.level)
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Hour", point.hour),
                        y: .value("Level", point.level)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }

                // Cutoff line at 2 PM (14:00)
                RuleMark(x: .value("Cutoff", 14))
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 2]))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 50)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Caffeine Cutoff Time Picker Card

struct CaffeineCutoffTimePickerCard: View {
    let question: BaselineQuestion
    @Binding var value: Double?
    let color: Color

    @State private var selectedTime: Date
    @State private var isExpanded = false

    init(question: BaselineQuestion, value: Binding<Double?>, color: Color) {
        self.question = question
        self._value = value
        self.color = color

        // Initialize with existing value or 2 PM default
        let hour = Int(value.wrappedValue ?? 14)
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = 0
        _selectedTime = State(initialValue: Calendar.current.date(from: components) ?? Date())
    }

    private var selectedHour: Int {
        Calendar.current.component(.hour, from: selectedTime)
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: selectedTime)
    }

    private var impactInfo: (text: String, color: Color, icon: String) {
        if selectedHour <= 12 {
            return ("Excellent for sleep", .green, "moon.zzz.fill")
        } else if selectedHour <= 14 {
            return ("Good for sleep", .green, "moon.fill")
        } else if selectedHour <= 16 {
            return ("May affect sleep", .yellow, "exclamationmark.triangle.fill")
        } else if selectedHour <= 18 {
            return ("Likely affects sleep", .orange, "exclamationmark.triangle.fill")
        } else {
            return ("Will impact sleep quality", .red, "exclamationmark.circle.fill")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            // Compact time display that expands on tap
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: impactInfo.icon)
                        .foregroundColor(impactInfo.color)

                    Text(formattedTime)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Spacer()

                    Text(impactInfo.text)
                        .font(.caption)
                        .foregroundColor(impactInfo.color)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            // Expandable time picker
            if isExpanded {
                DatePicker(
                    "Cutoff Time",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 120)
                .onChange(of: selectedTime) { _, newTime in
                    let hour = Calendar.current.component(.hour, from: newTime)
                    value = Double(hour)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Caffeine Source Slider Card

struct CaffeineSourceSliderCard: View {
    let question: BaselineQuestion
    @Binding var value: Double?
    let color: Color

    private var sliderValue: Double {
        value ?? 70
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            // Tier explanation
            VStack(alignment: .leading, spacing: 8) {
                tierRow(
                    tier: "Tier 1 (Healthy)",
                    examples: "Green tea, black tea, matcha, brewed coffee",
                    color: .green
                )
                tierRow(
                    tier: "Tier 2 (Limit)",
                    examples: "Espresso, sodas, energy drinks, caffeine pills",
                    color: .orange
                )
            }
            .padding()
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(8)

            // Slider: Left = Tier 2, Right = Tier 1
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Int(100 - sliderValue))%")
                            .font(.headline)
                            .foregroundColor(.orange)
                        Text("Tier 2")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(sliderValue))%")
                            .font(.headline)
                            .foregroundColor(sliderValue >= 70 ? .green : sliderValue >= 50 ? .yellow : .orange)
                        Text("Tier 1")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Slider(
                    value: Binding(
                        get: { sliderValue },
                        set: { value = $0 }
                    ),
                    in: 0...100,
                    step: 5
                )
                .tint(sliderValue >= 70 ? .green : sliderValue >= 50 ? .yellow : .orange)
            }

            // Score impact text
            Text(scoreImpactText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .onAppear {
            if value == nil {
                value = 70
            }
        }
    }

    private func tierRow(tier: String, examples: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(tier)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(examples)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var scoreImpactText: String {
        if sliderValue >= 90 {
            return "Excellent source choices for longevity"
        } else if sliderValue >= 70 {
            return "Good source choices"
        } else if sliderValue >= 50 {
            return "Consider shifting to more Tier 1 sources"
        } else {
            return "Most caffeine from processed sources"
        }
    }
}

// MARK: - Caffeine Wizard ViewModel

@MainActor
class CaffeineWizardViewModel: ObservableObject {
    @Published var currentStep = 1
    @Published var isLoading = true
    @Published var isSaving = false

    @Published var baselineView: BaselineView?
    @Published var subpages: [BaselineViewSubpage] = []

    @Published var baselineQuestions: [BaselineQuestion] = []
    @Published var baselineResponses: [String: Double] = [:]

    @Published var savedBaselines: [String: Double] = [:]
    @Published var isComplete = false

    // Timing distribution percentages
    @Published var timingMorningPct: Double = 90
    @Published var timingEarlyAfternoonPct: Double = 10
    @Published var timingLateAfternoonPct: Double = 0
    @Published var timingEveningPct: Double = 0

    let baselineViewId = "BASELINE_VIEW_CAFFEINE"
    let categoryId = "CAT_CAFFEINE"

    var totalSteps: Int { subpages.count }

    var currentSubpage: BaselineViewSubpage? {
        subpages.first { $0.displayOrder == currentStep }
    }

    var pillarColor: Color {
        MetricsUIConfig.getPillarColor(for: "Healthful Nutrition")
    }

    var hasExistingBaseline: Bool {
        let categoryBaselineTypes = baselineQuestions.compactMap { $0.baselineType }
        guard !categoryBaselineTypes.isEmpty else { return false }
        return categoryBaselineTypes.allSatisfy { savedBaselines[$0] != nil }
    }

    var timingPercentageTotal: Double {
        timingMorningPct + timingEarlyAfternoonPct + timingLateAfternoonPct + timingEveningPct
    }

    var timingPercentagesValid: Bool {
        abs(timingPercentageTotal - 100) < 0.01
    }

    var allQuestionsAnswered: Bool {
        // Filter out cutoff question (we're using timing distribution now)
        let requiredQuestions = baselineQuestions.filter {
            $0.isRequired && $0.questionId != "BQ_CAFFEINE_CUTOFF"
        }
        let baseQuestionsAnswered = requiredQuestions.allSatisfy { question in
            baselineResponses[question.questionId] != nil
        }
        return baseQuestionsAnswered && timingPercentagesValid
    }

    func loadInitialData() async {
        isLoading = true

        async let viewTask: () = loadBaselineView()
        async let questionsTask: () = loadBaselineQuestions()
        async let baselinesTask: () = loadExistingBaselines()

        _ = await (viewTask, questionsTask, baselinesTask)
        await loadSubpages()

        for question in baselineQuestions {
            if let baselineType = question.baselineType,
               let existingValue = savedBaselines[baselineType] {
                baselineResponses[question.questionId] = existingValue
            }
        }

        isLoading = false
    }

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

                // Load timing distribution values
                switch baseline.baselineType {
                case "caffeine_timing_morning_pct":
                    timingMorningPct = baseline.value
                case "caffeine_timing_early_afternoon_pct":
                    timingEarlyAfternoonPct = baseline.value
                case "caffeine_timing_late_afternoon_pct":
                    timingLateAfternoonPct = baseline.value
                case "caffeine_timing_evening_pct":
                    timingEveningPct = baseline.value
                default:
                    break
                }
            }
        } catch {
            print("Error loading baselines: \(error)")
        }
    }

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

    func saveResponses() async -> Bool {
        isSaving = true

        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFullDate]
            let today = dateFormatter.string(from: Date())

            // Save standard question responses (excluding cutoff)
            for question in baselineQuestions {
                guard let baselineType = question.baselineType,
                      question.questionId != "BQ_CAFFEINE_CUTOFF",
                      let value = baselineResponses[question.questionId] else { continue }

                // Determine unit based on baseline type
                let unit: String
                if baselineType.contains("hour") {
                    unit = "hour"
                } else if baselineType.contains("pct") {
                    unit = "percent"
                } else {
                    unit = "mg"
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

            // Save timing distribution baselines
            let timingBaselines: [(String, Double)] = [
                ("caffeine_timing_morning_pct", timingMorningPct),
                ("caffeine_timing_early_afternoon_pct", timingEarlyAfternoonPct),
                ("caffeine_timing_late_afternoon_pct", timingLateAfternoonPct),
                ("caffeine_timing_evening_pct", timingEveningPct)
            ]

            for (baselineType, value) in timingBaselines {
                let record: [String: AnyJSON] = [
                    "patient_id": .string(userId.uuidString),
                    "baseline_type": .string(baselineType),
                    "value": .double(value),
                    "unit": .string("percent"),
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

#Preview {
    CaffeineWizardView()
}
