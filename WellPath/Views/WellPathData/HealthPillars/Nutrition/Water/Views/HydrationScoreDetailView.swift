//
//  HydrationScoreDetailView.swift
//  WellPath
//
//  Detail view showing hydration score with Today/History/Baseline tabs.
//

import SwiftUI

struct HydrationScoreDetailView: View {
    @ObservedObject var viewModel: HydrationScoreViewModel
    let color: Color
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: ScoreTab = .today
    @State private var scoreHistory: [String: Int] = [:]
    @State private var isLoadingHistory = true
    @State private var displayedMonth: Date = Date()
    @StateObject private var unitPrefs = UnitPreferencesViewModel()

    // Selected day for history detail
    @State private var selectedHistoryDate: Date? = nil
    @State private var selectedDayScores: (combined: Int, amount: Int, timing: Int)? = nil
    @State private var isLoadingDayScores = false

    enum ScoreTab: String, CaseIterable {
        case today = "Today"
        case history = "History"
        case baseline = "Baseline"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Score View", selection: $selectedTab) {
                    ForEach(ScoreTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                ScrollView {
                    switch selectedTab {
                    case .today:
                        todayTabContent
                    case .history:
                        historyTabContent
                    case .baseline:
                        baselineTabContent
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Hydration Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadScoreHistory()
                await unitPrefs.loadPreferences()
            }
        }
    }

    // MARK: - Today Tab

    private var todayTabContent: some View {
        VStack(spacing: 20) {
            if viewModel.hasDailyScore {
                // Overall score
                ScoreRingPill(
                    score: viewModel.dailyScoreValue,
                    iconName: "drop.fill",
                    label: "Today",
                    size: 90
                )
                .padding(.top, 8)

                Text(scoreLabel(for: viewModel.dailyScoreValue))
                    .font(.headline)
                    .foregroundColor(scoreColor(for: viewModel.dailyScoreValue))

                // Score Components breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Text("Score Components")
                        .font(.headline)

                    HStack(spacing: 24) {
                        // Amount component
                        VStack(spacing: 8) {
                            ScoreRingPill(
                                score: viewModel.dailyAmountScore,
                                iconName: componentIcon(for: "hydration_amount_score"),
                                label: "Amount",
                                size: 60
                            )
                            Text(componentWeight(for: "hydration_amount_score"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        // Timing component
                        VStack(spacing: 8) {
                            ScoreRingPill(
                                score: viewModel.dailyTimingScore,
                                iconName: componentIcon(for: "hydration_timing_score"),
                                label: "Timing",
                                size: 60
                            )
                            Text(componentWeight(for: "hydration_timing_score"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Today's intake amount
                    if let amountScore = viewModel.dailyAmountScore {
                        HStack {
                            Image(systemName: "drop.fill")
                                .foregroundColor(color)
                            Text("Amount Score:")
                                .font(.subheadline)
                            Spacer()
                            Text("\(amountScore)/100")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(amountScore >= 80 ? .green : (amountScore >= 60 ? .yellow : .orange))
                        }
                    }

                    if let timingScore = viewModel.dailyTimingScore {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(color)
                            Text("Timing Score:")
                                .font(.subheadline)
                            Spacer()
                            Text("\(timingScore)/100")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(timingScore >= 80 ? .green : (timingScore >= 60 ? .yellow : .orange))
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)

                if let explanation = viewModel.scoringExplanation {
                    scoringExplanationSection(explanation)
                }
            } else {
                noDataTodayView
            }
        }
        .padding()
    }

    // MARK: - Baseline Tab

    /// The baseline value in mL (canonical) from onboarding
    private var baselineMl: Double? {
        viewModel.baselines["baseline_water_amount"]  // Canonical mL
    }

    /// Convert mL baseline to user's preferred display unit
    private var baselineDisplayValue: String {
        guard let mlValue = baselineMl else { return "--" }
        let displayValue = mlValue / unitPrefs.liquidUnit.mlPerUnit
        if displayValue >= 10 {
            return String(format: "%.0f", displayValue)
        } else {
            return String(format: "%.1f", displayValue)
        }
    }

    /// Timing percentages from baseline
    private var morningPct: Double? { viewModel.baselines["hydration_timing_morning_pct"] }
    private var afternoonPct: Double? { viewModel.baselines["hydration_timing_afternoon_pct"] }
    private var eveningPct: Double? { viewModel.baselines["hydration_timing_evening_pct"] }
    private var nightPct: Double? { viewModel.baselines["hydration_timing_night_pct"] }

    private var hasTimingBaseline: Bool {
        morningPct != nil || afternoonPct != nil || eveningPct != nil || nightPct != nil
    }

    /// Baseline amount score from behavioral_scores VIEW
    private var baselineAmountScore: Int? {
        viewModel.baselineAmountScore
    }

    /// Baseline timing score from behavioral_scores VIEW
    private var baselineTimingScore: Int? {
        viewModel.baselineTimingScore
    }

    /// Composite baseline score from behavioral_scores VIEW
    private var combinedBaselineScore: Int? {
        viewModel.baselineCompositeScore
    }

    /// Get component weight percentage for a component type
    private func componentWeight(for componentType: String) -> String {
        if let component = viewModel.components.first(where: { $0.componentScoreType == componentType }) {
            return component.weightPercentage
        }
        return "--"
    }

    /// Get component icon for a component type
    private func componentIcon(for componentType: String) -> String {
        if let component = viewModel.components.first(where: { $0.componentScoreType == componentType }) {
            return component.iconName ?? "questionmark.circle"
        }
        return "questionmark.circle"
    }

    @State private var showTimingDetails = false
    @State private var showWizard = false

    /// Previous baseline amount in mL
    private var previousBaselineMl: Double? {
        viewModel.previousBaselines["baseline_water_amount"]
    }

    /// Previous baseline display value in user's unit
    private var previousBaselineDisplayValue: String? {
        guard let mlValue = previousBaselineMl else { return nil }
        let displayValue = mlValue / unitPrefs.liquidUnit.mlPerUnit
        if displayValue >= 10 {
            return String(format: "%.0f", displayValue)
        } else {
            return String(format: "%.1f", displayValue)
        }
    }

    /// Has previous baseline to show comparison
    private var hasPreviousBaseline: Bool {
        previousBaselineMl != nil
    }

    private var baselineTabContent: some View {
        VStack(spacing: 20) {
            // Edit button when editable
            if viewModel.isEditable {
                HStack {
                    Spacer()
                    Button {
                        showWizard = true
                    } label: {
                        Label("Edit Baseline", systemImage: "pencil.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(color)
                    }
                }
            }

            // Score ring pill with combined baseline score
            if let score = combinedBaselineScore {
                VStack(spacing: 12) {
                    ScoreRingPill(
                        score: score,
                        iconName: "drop.fill",
                        label: "Current Baseline",
                        size: 100
                    )

                    Text(scoreLabel(for: score))
                        .font(.headline)
                        .foregroundColor(scoreColor(for: score))

                    // Assessment date
                    if let date = viewModel.baselineAssessmentDate {
                        Text("Set on \(formatDate(date))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
            }

            // Component breakdown
            VStack(alignment: .leading, spacing: 12) {
                Text("Score Components")
                    .font(.headline)

                HStack(spacing: 24) {
                    // Amount component
                    VStack(spacing: 8) {
                        ScoreRingPill(
                            score: baselineAmountScore,
                            iconName: componentIcon(for: "hydration_amount_score"),
                            label: "Amount",
                            size: 60
                        )
                        Text(componentWeight(for: "hydration_amount_score"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Timing component
                    VStack(spacing: 8) {
                        ScoreRingPill(
                            score: baselineTimingScore,
                            iconName: componentIcon(for: "hydration_timing_score"),
                            label: "Timing",
                            size: 60
                        )
                        Text(componentWeight(for: "hydration_timing_score"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                // Amount detail - current vs previous
                HStack {
                    Image(systemName: componentIcon(for: "hydration_amount_score"))
                        .foregroundColor(color)
                    Text("Daily Amount:")
                        .font(.subheadline)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(baselineDisplayValue)
                                .font(.title3)
                                .fontWeight(.bold)
                            Text(unitPrefs.liquidUnit.shortLabel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        // Show previous if exists
                        if let prev = previousBaselineDisplayValue {
                            HStack(spacing: 4) {
                                Text("was \(prev) \(unitPrefs.liquidUnit.shortLabel)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                changeIndicator(current: baselineMl ?? 0, previous: previousBaselineMl ?? 0)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)

            // Previous baseline comparison section
            if hasPreviousBaseline {
                previousBaselineSection
            }

            // Timing Distribution Section (collapsible)
            if hasTimingBaseline {
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        withAnimation { showTimingDetails.toggle() }
                    } label: {
                        HStack {
                            Text("Timing Distribution")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: showTimingDetails ? "chevron.up" : "chevron.down")
                                .foregroundColor(.secondary)
                        }
                    }

                    if showTimingDetails {
                        VStack(spacing: 8) {
                            timingRow(label: "Morning (6am-12pm)", value: morningPct, target: 40, icon: "sunrise.fill")
                            timingRow(label: "Afternoon (12pm-6pm)", value: afternoonPct, target: 40, icon: "sun.max.fill")
                            timingRow(label: "Evening (6pm-10pm)", value: eveningPct, target: 15, icon: "sunset.fill")
                            timingRow(label: "Night (10pm-6am)", value: nightPct, target: 5, icon: "moon.fill")
                        }
                        .padding()
                        .background(Color(.tertiarySystemGroupedBackground))
                        .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }

            // Editability status
            HStack(spacing: 8) {
                Image(systemName: viewModel.isEditable ? "pencil.circle" : "lock.fill")
                    .font(.body)
                    .foregroundColor(viewModel.isEditable ? color : .secondary)
                Text(viewModel.editabilityReason ?? "Based on onboarding")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(20)

            if let explanation = viewModel.scoringExplanation {
                scoringExplanationSection(explanation)
            }
        }
        .padding()
        .sheet(isPresented: $showWizard) {
            SimpleBaselineWizardView(
                baselineViewId: "BASELINE_VIEW_HYDRATION",
                categoryId: "CAT_HYDRATION",
                categoryName: "Hydration",
                scoreId: "hydration",
                scoreType: "hydration"
            )
        }
        .onChange(of: showWizard) { _, isShowing in
            if !isShowing {
                Task {
                    await viewModel.refreshBaselines()
                }
            }
        }
    }

    // MARK: - Previous Baseline Section

    @ViewBuilder
    private var previousBaselineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.secondary)
                Text("Previous Baseline")
                    .font(.headline)
                Spacer()
                if let date = viewModel.previousBaselineDate {
                    Text(formatDate(date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Text("Daily Amount:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                if let prev = previousBaselineDisplayValue {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(prev)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(unitPrefs.liquidUnit.shortLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if let prevTiming = viewModel.previousBaselines["hydration_timing_baseline_score"] {
                HStack {
                    Text("Timing Score:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(prevTiming))/100")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground).opacity(0.6))
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private func formatDate(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]

        // Try different date formats
        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.dateFormat = "yyyy-MM-dd"

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium

        if let date = isoFormatter.date(from: dateString) {
            return displayFormatter.string(from: date)
        } else if let date = dateOnlyFormatter.date(from: dateString) {
            return displayFormatter.string(from: date)
        }
        return dateString
    }

    @ViewBuilder
    private func changeIndicator(current: Double, previous: Double) -> some View {
        if current > previous {
            Image(systemName: "arrow.up.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
        } else if current < previous {
            Image(systemName: "arrow.down.circle.fill")
                .font(.caption)
                .foregroundColor(.orange)
        } else {
            Image(systemName: "equal.circle.fill")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func timingRow(label: String, value: Double?, target: Int, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
            Spacer()
            if let pct = value {
                HStack(spacing: 4) {
                    Text("\(Int(pct))%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(timingColor(actual: pct, target: Double(target)))
                    Text("(target: \(target)%)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("--")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func timingColor(actual: Double, target: Double) -> Color {
        let deviation = abs(actual - target)
        if deviation <= 10 { return .green }
        else if deviation <= 20 { return .orange }
        else { return .red }
    }

    // MARK: - History Tab

    private var historyTabContent: some View {
        VStack(spacing: 20) {
            scoreHistoryCalendar

            // Selected day breakdown
            if let selectedDate = selectedHistoryDate {
                selectedDayBreakdown(for: selectedDate)
            }
        }
        .padding()
    }

    private func selectedDayBreakdown(for date: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(formattedDate(date))
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation { selectedHistoryDate = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }

            if isLoadingDayScores {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if let scores = selectedDayScores {
                // Score ring
                HStack {
                    Spacer()
                    ScoreRingPill(
                        score: scores.combined,
                        iconName: "drop.fill",
                        label: formattedDate(date),
                        size: 70
                    )
                    Spacer()
                }

                // Components
                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        ScoreRingPill(
                            score: scores.amount,
                            iconName: componentIcon(for: "hydration_amount_score"),
                            label: "Amount",
                            size: 50
                        )
                        Text(componentWeight(for: "hydration_amount_score"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    VStack(spacing: 4) {
                        ScoreRingPill(
                            score: scores.timing,
                            iconName: componentIcon(for: "hydration_timing_score"),
                            label: "Timing",
                            size: 50
                        )
                        Text(componentWeight(for: "hydration_timing_score"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            } else if let score = scoreHistory[dateString(for: date)] {
                // Fallback - just show combined score
                HStack {
                    Spacer()
                    ScoreRingPill(
                        score: score,
                        iconName: "drop.fill",
                        label: formattedDate(date),
                        size: 70
                    )
                    Spacer()
                }
                Text("Component scores not available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var scoreHistoryCalendar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    withAnimation {
                        displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundColor(color)
                }

                Spacer()
                Text(monthYearString(for: displayedMonth))
                    .font(.headline)
                Spacer()

                Button {
                    withAnimation {
                        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                        if nextMonth <= Date() {
                            displayedMonth = nextMonth
                        }
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundColor(displayedMonth < Calendar.current.startOfMonth(for: Date()) ? color : .secondary.opacity(0.3))
                }
            }
            .padding(.horizontal)

            if isLoadingHistory {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 40)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                    ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, day in
                        Text(day)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(Array(daysInMonth().enumerated()), id: \.offset) { _, date in
                        if let date = date {
                            calendarDayCell(for: date)
                        } else {
                            Color.clear.frame(height: 44)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }

    private func calendarDayCell(for date: Date) -> some View {
        let dateStr = dateString(for: date)
        let score = scoreHistory[dateStr]
        let dayNumber = Calendar.current.component(.day, from: date)
        let isFuture = date > Date()
        let isSelected = selectedHistoryDate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false

        return Button {
            guard score != nil else { return }  // Only allow tap if there's data
            withAnimation {
                selectedHistoryDate = date
            }
            Task {
                await loadDayScores(for: date)
            }
        } label: {
            VStack(spacing: 2) {
                if let score = score {
                    ZStack {
                        Circle()
                            .stroke(isSelected ? color : Color.gray.opacity(0.15), lineWidth: isSelected ? 3 : 2)
                            .frame(width: 28, height: 28)
                        Circle()
                            .trim(from: 0, to: Double(score) / 100.0)
                            .stroke(
                                color.opacity(0.8),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 28, height: 28)
                        Text("\(score)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                } else {
                    Text("\(dayNumber)")
                        .font(.caption)
                        .foregroundColor(isFuture ? .secondary.opacity(0.3) : .secondary)
                        .frame(width: 28, height: 28)
                }
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
        .disabled(score == nil)
    }

    // MARK: - Shared Components

    private var noDataTodayView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No water logged today")
                .font(.headline)
            Text("Log your water intake to see today's hydration score")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func scoringExplanationSection(_ explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How It's Calculated")
                .font(.headline)
            Text(explanation)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
        }
    }

    // MARK: - Helpers

    private func scoreColor(for score: Int?) -> Color {
        guard let score = score else { return .secondary }
        if score >= 80 { return .green }
        else if score >= 60 { return .yellow }
        else if score >= 40 { return .orange }
        else { return .red }
    }

    private func scoreLabel(for score: Int?) -> String {
        guard let score = score else { return "" }
        if score >= 80 { return "Excellent" }
        else if score >= 60 { return "Good" }
        else if score >= 40 { return "Fair" }
        else { return "Needs Improvement" }
    }

    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func daysInMonth() -> [Date?] {
        let calendar = Calendar.current
        let startOfMonth = calendar.startOfMonth(for: displayedMonth)
        let range = calendar.range(of: .day, in: .month, for: displayedMonth)!
        let firstWeekday = calendar.component(.weekday, from: startOfMonth) - 1

        var days: [Date?] = []
        for _ in 0..<firstWeekday { days.append(nil) }
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        return days
    }

    // MARK: - Data Loading

    private func loadScoreHistory() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            guard let startDate = calendar.date(byAdding: .day, value: -90, to: today) else { return }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let startDateString = dateFormatter.string(from: startDate)

            struct ScoreResult: Decodable {
                let scoreDate: String
                let scoreValue: Double

                enum CodingKeys: String, CodingKey {
                    case scoreDate = "score_date"
                    case scoreValue = "score_value"
                }
            }

            // Query from unified behavioral_scores VIEW
            let results: [ScoreResult] = try await client
                .from("behavioral_scores")
                .select("score_date, score_value")
                .eq("patient_id", value: userId.uuidString)
                .eq("score_type", value: "hydration_score")
                .eq("score_context", value: "daily")
                .gte("score_date", value: startDateString)
                .order("score_date", ascending: false)
                .execute()
                .value

            var historyDict: [String: Int] = [:]
            for result in results {
                // Strip time component if present (e.g., "2026-01-06 00:00:00" -> "2026-01-06")
                let dateKey = String(result.scoreDate.prefix(10))
                historyDict[dateKey] = Int(result.scoreValue)
            }
            scoreHistory = historyDict
            isLoadingHistory = false
        } catch {
            print("Error loading score history: \(error)")
            isLoadingHistory = false
        }
    }

    private func loadDayScores(for date: Date) async {
        isLoadingDayScores = true
        selectedDayScores = nil

        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateStr = dateFormatter.string(from: date)

            struct DayScore: Decodable {
                let scoreType: String
                let scoreValue: Double

                enum CodingKeys: String, CodingKey {
                    case scoreType = "score_type"
                    case scoreValue = "score_value"
                }
            }

            let results: [DayScore] = try await client
                .from("behavioral_scores")
                .select("score_type, score_value")
                .eq("patient_id", value: userId.uuidString)
                .eq("score_date", value: dateStr)
                .eq("score_context", value: "daily")
                .in("score_type", values: ["hydration_score", "hydration_amount_score", "hydration_timing_score"])
                .execute()
                .value

            var combined = 0
            var amount = 0
            var timing = 0

            for result in results {
                switch result.scoreType {
                case "hydration_score":
                    combined = Int(result.scoreValue.rounded())
                case "hydration_amount_score":
                    amount = Int(result.scoreValue.rounded())
                case "hydration_timing_score":
                    timing = Int(result.scoreValue.rounded())
                default:
                    break
                }
            }

            selectedDayScores = (combined: combined, amount: amount, timing: timing)
            isLoadingDayScores = false
        } catch {
            print("Error loading day scores: \(error)")
            isLoadingDayScores = false
        }
    }
}

#Preview {
    HydrationScoreDetailView(
        viewModel: HydrationScoreViewModel(),
        color: .cyan
    )
}
