//
//  WorkoutScoreDetailView.swift
//  WellPath
//
//  Reusable detail view for workout scores (Cardio, Strength, HIIT, Mobility)
//  Shows 3 tabs: Today, History, Baseline
//  All workout categories have frequency + duration components
//

import SwiftUI

// MARK: - Workout Configuration

struct WorkoutScoreConfig {
    let name: String
    let iconName: String
    let category: String
    let scoreType: String
    let frequencyType: String
    let durationType: String
    let sessionType: String
    let baselineSessionsKey: String
    let baselineDurationKey: String

    static let cardio = WorkoutScoreConfig(
        name: "Cardio",
        iconName: "figure.run",
        category: "cardio",
        scoreType: "cardio_score",
        frequencyType: "cardio_frequency_score",
        durationType: "cardio_duration_score",
        sessionType: "cardio_sessions_weekly",
        baselineSessionsKey: "cardio_sessions_weekly",
        baselineDurationKey: "cardio_duration_avg"
    )

    static let strength = WorkoutScoreConfig(
        name: "Strength",
        iconName: "dumbbell.fill",
        category: "strength",
        scoreType: "strength_score",
        frequencyType: "strength_frequency_score",
        durationType: "strength_duration_score",
        sessionType: "strength_sessions_weekly",
        baselineSessionsKey: "strength_sessions_weekly",
        baselineDurationKey: "strength_duration_avg"
    )

    static let hiit = WorkoutScoreConfig(
        name: "HIIT",
        iconName: "bolt.heart.fill",
        category: "hiit",
        scoreType: "hiit_score",
        frequencyType: "hiit_frequency_score",
        durationType: "hiit_duration_score",
        sessionType: "hiit_sessions_weekly",
        baselineSessionsKey: "hiit_sessions_weekly",
        baselineDurationKey: "hiit_duration_avg"
    )

    static let mobility = WorkoutScoreConfig(
        name: "Mobility",
        iconName: "figure.flexibility",
        category: "mobility",
        scoreType: "mobility_score",
        frequencyType: "mobility_frequency_score",
        durationType: "mobility_duration_score",
        sessionType: "mobility_sessions_weekly",
        baselineSessionsKey: "mobility_sessions_weekly",
        baselineDurationKey: "mobility_duration_avg"
    )
}

// MARK: - Workout Summary Data

struct WorkoutSummaryData {
    let sessionsThisWeek: Int
    let totalDurationMin: Int
    let avgDurationMin: Int
    let sessionGoal: Int
    let durationGoal: Int
    let frequencyScore: Int?
    let durationScore: Int?
    let overallScore: Int?

    static let empty = WorkoutSummaryData(
        sessionsThisWeek: 0, totalDurationMin: 0, avgDurationMin: 0,
        sessionGoal: 3, durationGoal: 30,
        frequencyScore: nil, durationScore: nil, overallScore: nil
    )
}

// MARK: - Main Detail View

struct WorkoutScoreDetailView: View {
    @ObservedObject var viewModel: BehavioralScoreViewModel
    let config: WorkoutScoreConfig
    let color: Color
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: ScoreTab = .today
    @State private var scoreHistory: [String: Int] = [:]
    @State private var isLoadingHistory = true
    @State private var selectedHistoryDate: Date?
    @State private var displayedMonth: Date = Date()

    // This week's data
    @State private var weekData: WorkoutSummaryData = .empty
    @State private var isLoadingWeek = true

    // Baseline data
    @State private var baselineData: WorkoutSummaryData = .empty

    enum ScoreTab: String, CaseIterable {
        case today = "This Week"
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
                        weekTabContent
                    case .history:
                        historyTabContent
                    case .baseline:
                        baselineTabContent
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(viewModel.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadWeekData()
                await loadBaselineData()
                await loadScoreHistory()
            }
            .sheet(item: $selectedHistoryDate) { date in
                WorkoutWeekDetailView(
                    date: date,
                    score: scoreHistory[weekString(for: date)],
                    color: color,
                    config: config,
                    viewModel: viewModel
                )
            }
        }
    }

    // MARK: - This Week Tab

    private var weekTabContent: some View {
        VStack(spacing: 20) {
            ScoreRingPill(
                score: viewModel.scoreValue,
                iconName: config.iconName,
                label: "This Week",
                size: 90
            )
            .padding(.top, 8)

            Text(scoreLabel(for: viewModel.scoreValue))
                .font(.headline)
                .foregroundColor(scoreColor(for: viewModel.scoreValue))

            if isLoadingWeek {
                ProgressView().padding(.vertical, 40)
            } else {
                WorkoutSummaryCard(
                    title: "This Week's \(config.name)",
                    data: weekData,
                    color: color,
                    config: config,
                    viewModel: viewModel
                )
            }

            if let explanation = viewModel.scoringExplanation {
                scoringExplanationSection(explanation)
            }
        }
        .padding()
    }

    // MARK: - Baseline Tab

    private var baselineTabContent: some View {
        VStack(spacing: 20) {
            ScoreRingPill(
                score: viewModel.scoreValue,
                iconName: config.iconName,
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

            WorkoutSummaryCard(
                title: "Your Baseline",
                data: baselineData,
                color: color,
                config: config,
                viewModel: viewModel,
                showIcon: true
            )

            if let explanation = viewModel.scoringExplanation {
                scoringExplanationSection(explanation)
            }
        }
        .padding()
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
                    Text("\(viewModel.daysTracked) of \(viewModel.daysRequired) weeks")
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
            // Month navigation
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
                // Weekly score list for the month
                weeklyScoresList
            }
        }
    }

    private var weeklyScoresList: some View {
        VStack(spacing: 8) {
            ForEach(weeksInMonth(), id: \.self) { weekStart in
                let weekStr = weekString(for: weekStart)
                let score = scoreHistory[weekStr]

                Button {
                    if score != nil {
                        selectedHistoryDate = weekStart
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(weekRangeString(for: weekStart))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Text("Week of \(weekStartString(for: weekStart))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if let score = score {
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.15), lineWidth: 2)
                                    .frame(width: 36, height: 36)
                                Circle()
                                    .trim(from: 0, to: Double(score) / 100.0)
                                    .stroke(
                                        color.opacity(0.8),
                                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 36, height: 36)
                                Text("\(score)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                        } else {
                            Text("No data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(score == nil)
            }
        }
    }

    // MARK: - Shared Components

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

    private func weekString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-'W'ww"
        return formatter.string(from: date)
    }

    private func weekStartString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func weekRangeString(for weekStart: Date) -> String {
        let calendar = Calendar.current
        guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else {
            return weekStartString(for: weekStart)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
    }

    private func weeksInMonth() -> [Date] {
        let calendar = Calendar.current
        let startOfMonth = calendar.startOfMonth(for: displayedMonth)
        guard let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return []
        }

        var weeks: [Date] = []
        var currentDate = startOfMonth

        // Find the start of the first week
        let weekday = calendar.component(.weekday, from: currentDate)
        if let adjustedStart = calendar.date(byAdding: .day, value: -(weekday - 1), to: currentDate) {
            currentDate = adjustedStart
        }

        while currentDate <= endOfMonth {
            weeks.append(currentDate)
            if let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) {
                currentDate = nextWeek
            } else {
                break
            }
        }

        return weeks
    }

    // MARK: - Data Loading

    private func loadWeekData() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            // Get start of current week
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let weekday = calendar.component(.weekday, from: today)
            guard let weekStart = calendar.date(byAdding: .day, value: -(weekday - 1), to: today) else { return }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let weekStartString = dateFormatter.string(from: weekStart)

            // Load workout data for this week
            struct WorkoutSample: Decodable {
                let canonicalValue: Double
                let metadata: [String: String]?

                enum CodingKeys: String, CodingKey {
                    case canonicalValue = "canonical_value"
                    case metadata
                }
            }

            let samples: [WorkoutSample] = try await client
                .from("patient_quantity_samples")
                .select("canonical_value, metadata")
                .eq("patient_id", value: userId.uuidString)
                .eq("quantity_type", value: "workout_duration_min")
                .gte("aggregation_date", value: weekStartString)
                .in("source", values: ["wellpath_input", "healthkit"])
                .execute()
                .value

            // Filter by category
            let categorySamples = samples.filter {
                $0.metadata?["category"] == config.category
            }

            let sessionCount = categorySamples.count
            let totalDuration = categorySamples.reduce(0) { $0 + Int($1.canonicalValue) }
            let avgDuration = sessionCount > 0 ? totalDuration / sessionCount : 0

            let sessionGoal = Int(viewModel.baselines[config.baselineSessionsKey] ?? 3)
            let durationGoal = Int(viewModel.baselines[config.baselineDurationKey] ?? 30)

            weekData = WorkoutSummaryData(
                sessionsThisWeek: sessionCount,
                totalDurationMin: totalDuration,
                avgDurationMin: avgDuration,
                sessionGoal: sessionGoal,
                durationGoal: durationGoal,
                frequencyScore: frequencyScore,
                durationScore: durationScore,
                overallScore: viewModel.scoreValue
            )

            isLoadingWeek = false
        } catch {
            print("Error loading week data: \(error)")
            isLoadingWeek = false
        }
    }

    private var frequencyScore: Int? {
        viewModel.componentScores[config.frequencyType].map { Int($0) }
    }

    private var durationScore: Int? {
        viewModel.componentScores[config.durationType].map { Int($0) }
    }

    private func loadBaselineData() async {
        let sessionGoal = Int(viewModel.baselines[config.baselineSessionsKey] ?? 3)
        let durationGoal = Int(viewModel.baselines[config.baselineDurationKey] ?? 30)

        baselineData = WorkoutSummaryData(
            sessionsThisWeek: sessionGoal,
            totalDurationMin: sessionGoal * durationGoal,
            avgDurationMin: durationGoal,
            sessionGoal: sessionGoal,
            durationGoal: durationGoal,
            frequencyScore: frequencyScore,
            durationScore: durationScore,
            overallScore: viewModel.scoreValue
        )
    }

    private func loadScoreHistory() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            guard let startDate = calendar.date(byAdding: .day, value: -180, to: today) else { return }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let startDateString = dateFormatter.string(from: startDate)

            struct ScoreResult: Decodable {
                let aggregationDate: String
                let canonicalValue: Double

                enum CodingKeys: String, CodingKey {
                    case aggregationDate = "aggregation_date"
                    case canonicalValue = "canonical_value"
                }
            }

            let results: [ScoreResult] = try await client
                .from("patient_quantity_samples")
                .select("aggregation_date, canonical_value")
                .eq("patient_id", value: userId.uuidString)
                .eq("quantity_type", value: config.scoreType)
                .eq("source", value: "calculated")
                .gte("aggregation_date", value: startDateString)
                .order("aggregation_date", ascending: false)
                .execute()
                .value

            // Group by week
            var historyDict: [String: Int] = [:]
            let weekFormatter = DateFormatter()
            weekFormatter.dateFormat = "yyyy-'W'ww"

            for result in results {
                dateFormatter.dateFormat = "yyyy-MM-dd"
                if let date = dateFormatter.date(from: result.aggregationDate) {
                    let weekStr = weekFormatter.string(from: date)
                    // Take the latest score for each week
                    if historyDict[weekStr] == nil {
                        historyDict[weekStr] = Int(result.canonicalValue)
                    }
                }
            }

            scoreHistory = historyDict
            isLoadingHistory = false
        } catch {
            print("Error loading score history: \(error)")
            isLoadingHistory = false
        }
    }
}

// MARK: - Expandable Summary Card

struct WorkoutSummaryCard: View {
    let title: String
    let data: WorkoutSummaryData
    let color: Color
    let config: WorkoutScoreConfig
    let viewModel: BehavioralScoreViewModel
    var showIcon: Bool = false

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    if showIcon {
                        Image(systemName: "flag.fill")
                            .font(.headline)
                            .foregroundColor(color)
                    }
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding()
            }
            .buttonStyle(.plain)

            Divider().padding(.horizontal)

            // Summary row (always visible)
            HStack(spacing: 0) {
                // Sessions
                summaryColumn(
                    icon: "calendar",
                    value: "\(data.sessionsThisWeek)",
                    unit: "/ \(data.sessionGoal)",
                    label: "Sessions"
                )

                Divider().frame(height: 55)

                // Duration
                summaryColumn(
                    icon: "clock",
                    value: "\(data.totalDurationMin)",
                    unit: "min",
                    label: "Total Time"
                )

                Divider().frame(height: 55)

                // Average
                summaryColumn(
                    icon: "chart.bar",
                    value: "\(data.avgDurationMin)",
                    unit: "min",
                    label: "Avg/Session"
                )
            }
            .padding(.vertical, 12)

            // Expanded details
            if isExpanded {
                Divider().padding(.horizontal)

                VStack(spacing: 16) {
                    // Component scores
                    componentScoresSection

                    // Goals section
                    goalsSection
                }
                .padding()
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func summaryColumn(icon: String, value: String, unit: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color.opacity(0.7))

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var componentScoresSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Score Components")
                .font(.subheadline)
                .fontWeight(.medium)

            // Frequency score
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Frequency")
                        .font(.subheadline)
                    Text("Weekly session count")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    if let score = data.frequencyScore {
                        Text("\(score)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(scoreColor(for: score))
                    } else {
                        Text("--")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Text("70%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Duration score
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Duration")
                        .font(.subheadline)
                    Text("Average session length")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    if let score = data.durationScore {
                        Text("\(score)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(scoreColor(for: score))
                    } else {
                        Text("--")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Text("30%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Baseline Routine")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(color.opacity(0.7))
                Text("Sessions/week:")
                    .font(.subheadline)
                Spacer()
                Text("\(data.sessionGoal)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(color.opacity(0.7))
                Text("Avg duration:")
                    .font(.subheadline)
                Spacer()
                Text("\(data.durationGoal) min")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }

    private func scoreColor(for score: Int) -> Color {
        if score >= 80 { return .green }
        else if score >= 60 { return .yellow }
        else if score >= 40 { return .orange }
        else { return .red }
    }
}

// MARK: - Week Detail View (for History)

struct WorkoutWeekDetailView: View {
    let date: Date
    let score: Int?
    let color: Color
    let config: WorkoutScoreConfig
    @ObservedObject var viewModel: BehavioralScoreViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var weekData: WorkoutSummaryData = .empty
    @State private var isLoading = true

    private var formattedWeek: String {
        let calendar = Calendar.current
        guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: date) else {
            return weekStartString
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: date)) - \(formatter.string(from: weekEnd))"
    }

    private var weekStartString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ScoreRingPill(
                        score: score,
                        iconName: config.iconName,
                        label: formattedWeek,
                        size: 90
                    )
                    .padding(.top, 8)

                    if let score = score {
                        Text(scoreLabel(for: score))
                            .font(.headline)
                            .foregroundColor(scoreColor(for: score))
                    }

                    if isLoading {
                        ProgressView().padding(.vertical, 40)
                    } else {
                        WorkoutSummaryCard(
                            title: "\(config.name) Summary",
                            data: weekData,
                            color: color,
                            config: config,
                            viewModel: viewModel
                        )
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Week of \(weekStartString)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadWeekData()
            }
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

    private func loadWeekData() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            let calendar = Calendar.current
            guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: date) else { return }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let weekStartString = dateFormatter.string(from: date)
            let weekEndString = dateFormatter.string(from: weekEnd)

            // Load workout data for the week
            struct WorkoutSample: Decodable {
                let canonicalValue: Double
                let metadata: [String: String]?

                enum CodingKeys: String, CodingKey {
                    case canonicalValue = "canonical_value"
                    case metadata
                }
            }

            let samples: [WorkoutSample] = try await client
                .from("patient_quantity_samples")
                .select("canonical_value, metadata")
                .eq("patient_id", value: userId.uuidString)
                .eq("quantity_type", value: "workout_duration_min")
                .gte("aggregation_date", value: weekStartString)
                .lte("aggregation_date", value: weekEndString)
                .in("source", values: ["wellpath_input", "healthkit"])
                .execute()
                .value

            // Filter by category
            let categorySamples = samples.filter {
                $0.metadata?["category"] == config.category
            }

            let sessionCount = categorySamples.count
            let totalDuration = categorySamples.reduce(0) { $0 + Int($1.canonicalValue) }
            let avgDuration = sessionCount > 0 ? totalDuration / sessionCount : 0

            let sessionGoal = Int(viewModel.baselines[config.baselineSessionsKey] ?? 3)
            let durationGoal = Int(viewModel.baselines[config.baselineDurationKey] ?? 30)

            weekData = WorkoutSummaryData(
                sessionsThisWeek: sessionCount,
                totalDurationMin: totalDuration,
                avgDurationMin: avgDuration,
                sessionGoal: sessionGoal,
                durationGoal: durationGoal,
                frequencyScore: nil,
                durationScore: nil,
                overallScore: score
            )

            isLoading = false
        } catch {
            print("Error loading week data: \(error)")
            isLoading = false
        }
    }
}

#Preview {
    WorkoutScoreDetailView(
        viewModel: CardioScoreViewModel(),
        config: .cardio,
        color: .orange
    )
}
