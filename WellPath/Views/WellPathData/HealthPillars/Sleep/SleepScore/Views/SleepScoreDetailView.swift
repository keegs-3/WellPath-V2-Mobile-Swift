//
//  SleepScoreDetailView.swift
//  WellPath
//
//  Detail view showing unified Sleep Score with Today/History/Baseline tabs.
//  Components: Duration (40%), Consistency (30%), Stage Amounts (30%)
//

import SwiftUI

struct SleepScoreDetailView: View {
    @ObservedObject var viewModel: SleepScoreViewModel
    let color: Color
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: ScoreTab = .today
    @State private var scoreHistory: [String: Int] = [:]
    @State private var isLoadingHistory = true
    @State private var displayedMonth: Date = Date()

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
            .navigationTitle("Sleep Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadScoreHistory()
            }
        }
    }

    // MARK: - Today Tab

    private var todayTabContent: some View {
        VStack(spacing: 20) {
            if viewModel.hasDailyScore {
                ScoreRingPill(
                    score: viewModel.dailyScoreValue,
                    iconName: "moon.fill",
                    label: "Today",
                    size: 90
                )
                .padding(.top, 8)

                Text(scoreLabel(for: viewModel.dailyScoreValue))
                    .font(.headline)
                    .foregroundColor(scoreColor(for: viewModel.dailyScoreValue))

                componentBreakdownSection

                if let explanation = viewModel.scoringExplanation {
                    scoringExplanationSection(explanation)
                }
            } else {
                noDataTodayView
            }
        }
        .padding()
    }

    private var componentBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Score Components")
                .font(.headline)

            // Duration (40%)
            componentRow(
                icon: "clock.fill",
                title: "Duration",
                subtitle: "40% weight",
                score: viewModel.durationScore
            )

            // Consistency (30%)
            componentRow(
                icon: "arrow.triangle.2.circlepath",
                title: "Consistency",
                subtitle: "30% weight",
                score: viewModel.consistencyScore
            )

            // Stage Amounts (30%)
            componentRow(
                icon: "waveform.path.ecg",
                title: "Stage Amounts",
                subtitle: viewModel.hasTracker ? "30% weight" : "Requires tracker",
                score: viewModel.hasTracker ? viewModel.stagesScore : nil
            )
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func componentRow(icon: String, title: String, subtitle: String, score: Int?) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let score = score {
                Text("\(score)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(scoreColor(for: score))
            } else {
                Text("--")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Baseline Tab

    private var baselineTabContent: some View {
        VStack(spacing: 20) {
            ScoreRingPill(
                score: viewModel.scoreValue,
                iconName: "moon.fill",
                label: "Baseline",
                size: 90
            )
            .padding(.top, 8)

            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.body)
                    .foregroundColor(color)
                Text("Based on questionnaire")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(20)

            baselineSummaryCard

            if let explanation = viewModel.scoringExplanation {
                scoringExplanationSection(explanation)
            }
        }
        .padding()
    }

    private var baselineSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Baseline")
                .font(.headline)

            if let sleepHours = viewModel.baselines["baseline_sleep_hours"] {
                baselineRow(icon: "moon.zzz.fill", title: "Typical Sleep", value: String(format: "%.1f hours", sleepHours))
            }

            if let bedtime = viewModel.baselines["baseline_bedtime"] {
                baselineRow(icon: "moon.fill", title: "Typical Bedtime", value: formatTime(minutesSinceMidnight: bedtime))
            }

            if let wakeTime = viewModel.baselines["baseline_wake_time"] {
                baselineRow(icon: "sun.max.fill", title: "Typical Wake Time", value: formatTime(minutesSinceMidnight: wakeTime))
            }

            if viewModel.hasTracker {
                Divider()
                Text("Sleep Stages (from tracker)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let deep = viewModel.baselines["baseline_deep_sleep_hours"] {
                    baselineRow(icon: "powersleep", title: "Deep Sleep", value: String(format: "%.2f hours", deep))
                }
                if let rem = viewModel.baselines["baseline_rem_sleep_hours"] {
                    baselineRow(icon: "brain.head.profile", title: "REM Sleep", value: String(format: "%.2f hours", rem))
                }
                if let core = viewModel.baselines["baseline_core_sleep_hours"] {
                    baselineRow(icon: "sleep", title: "Core Sleep", value: String(format: "%.2f hours", core))
                }
                if let awake = viewModel.baselines["baseline_awake_hours"] {
                    baselineRow(icon: "eye.fill", title: "Awake Time", value: String(format: "%.2f hours", awake))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func baselineRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }

    private func formatTime(minutesSinceMidnight: Double) -> String {
        let totalMinutes = Int(minutesSinceMidnight)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        let period = hours >= 12 ? "PM" : "AM"
        let displayHour = hours > 12 ? hours - 12 : (hours == 0 ? 12 : hours)
        return String(format: "%d:%02d %@", displayHour, minutes, period)
    }

    // MARK: - History Tab

    private var historyTabContent: some View {
        VStack(spacing: 20) {
            thresholdProgressSection
            scoreHistoryCalendar
        }
        .padding()
    }

    private var thresholdProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(viewModel.isBaseline ? "Unlock Tracked Score" : "Tracking Complete")
                    .font(.headline)
                Spacer()
                if !viewModel.isBaseline {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(viewModel.isBaseline ? color : .green)
                            .frame(width: geometry.size.width * min(viewModel.thresholdProgress, 1.0), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(viewModel.daysTracked) of \(viewModel.daysRequired) days")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(Int(min(viewModel.thresholdProgress, 1.0) * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let explanation = viewModel.thresholdExplanation {
                    Text(explanation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
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
                        .foregroundColor(color)
                }
            }
            .padding(.horizontal)

            if isLoadingHistory {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                calendarGrid
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var calendarGrid: some View {
        let daysInMonth = daysInMonth(for: displayedMonth)
        let firstWeekday = firstWeekdayOfMonth(for: displayedMonth)
        let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

        return VStack(spacing: 8) {
            HStack {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            let totalCells = firstWeekday + daysInMonth
            let rows = (totalCells + 6) / 7

            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { col in
                        let dayIndex = row * 7 + col - firstWeekday + 1
                        if dayIndex > 0 && dayIndex <= daysInMonth {
                            let dateString = dateString(for: dayIndex, in: displayedMonth)
                            let score = scoreHistory[dateString]
                            dayCell(day: dayIndex, score: score)
                        } else {
                            Color.clear
                                .frame(width: 36, height: 36)
                        }
                    }
                }
            }
        }
    }

    private func dayCell(day: Int, score: Int?) -> some View {
        ZStack {
            if let score = score {
                Circle()
                    .stroke(scoreColor(for: score), lineWidth: 3)
                    .frame(width: 36, height: 36)
                Text("\(day)")
                    .font(.caption)
                    .fontWeight(.medium)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 36, height: 36)
                Text("\(day)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Helper Views

    private var noDataTodayView: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No Sleep Data Today")
                .font(.headline)

            Text("Log your sleep or sync from a sleep tracker to see your score")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }

    private func scoringExplanationSection(_ explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How Your Score Works")
                .font(.headline)

            Text(explanation)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Helper Functions

    private func scoreLabel(for score: Int?) -> String {
        guard let score = score else { return "" }
        if score >= 80 { return "Excellent" }
        else if score >= 60 { return "Good" }
        else if score >= 40 { return "Fair" }
        else { return "Needs Work" }
    }

    private func scoreColor(for score: Int?) -> Color {
        guard let score = score else { return .secondary }
        if score >= 80 { return .green }
        else if score >= 60 { return .yellow }
        else if score >= 40 { return .orange }
        else { return .red }
    }

    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func daysInMonth(for date: Date) -> Int {
        Calendar.current.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    private func firstWeekdayOfMonth(for date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let firstDay = calendar.date(from: components) else { return 0 }
        return calendar.component(.weekday, from: firstDay) - 1
    }

    private func dateString(for day: Int, in month: Date) -> String {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: month)
        components.day = day
        guard let date = calendar.date(from: components) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - Data Loading

    private func loadScoreHistory() async {
        isLoadingHistory = true

        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            struct ScoreSample: Decodable {
                let aggregationDate: String
                let canonicalValue: Double

                enum CodingKeys: String, CodingKey {
                    case aggregationDate = "aggregation_date"
                    case canonicalValue = "canonical_value"
                }
            }

            let results: [ScoreSample] = try await client
                .from("patient_quantity_samples")
                .select("aggregation_date, canonical_value")
                .eq("patient_id", value: userId.uuidString)
                .eq("quantity_type", value: "sleep_score")
                .eq("source", value: "calculated")
                .order("aggregation_date", ascending: false)
                .limit(90)
                .execute()
                .value

            var history: [String: Int] = [:]
            for sample in results {
                history[sample.aggregationDate] = Int(sample.canonicalValue)
            }
            scoreHistory = history
        } catch {
            print("Error loading score history: \(error)")
        }

        isLoadingHistory = false
    }
}

#Preview {
    SleepScoreDetailView(
        viewModel: SleepScoreViewModel(),
        color: .teal
    )
}
