//
//  DailyActivityScoreDetailView.swift
//  WellPath
//
//  Detail view showing daily activity score with 3 tabs:
//  - Today: Score pill + component breakdown
//  - History: Threshold progress + calendar
//  - Baseline: Score pill + goals summary
//
//  Components: Move Minutes, Stand Time, Active Calories, Exercise Snacks
//

import SwiftUI

// MARK: - Daily Activity Summary Data

struct DailyActivitySummaryData {
    let moveMinutes: Int
    let standHours: Int
    let activeCalories: Int
    let exerciseSnacks: Int

    let moveMinutesGoal: Int
    let standHoursGoal: Int
    let activeCaloriesGoal: Int
    let exerciseSnacksGoal: Int

    let moveMinutesScore: Int?
    let standTimeScore: Int?
    let activeCaloriesScore: Int?
    let exerciseSnacksScore: Int?
    let overallScore: Int?

    static let empty = DailyActivitySummaryData(
        moveMinutes: 0, standHours: 0, activeCalories: 0, exerciseSnacks: 0,
        moveMinutesGoal: 30, standHoursGoal: 12, activeCaloriesGoal: 500, exerciseSnacksGoal: 3,
        moveMinutesScore: nil, standTimeScore: nil, activeCaloriesScore: nil,
        exerciseSnacksScore: nil, overallScore: nil
    )
}

// MARK: - Main Detail View

struct DailyActivityScoreDetailView: View {
    @ObservedObject var viewModel: DailyActivityScoreViewModel
    let color: Color
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: ScoreTab = .today
    @State private var scoreHistory: [String: Int] = [:]
    @State private var isLoadingHistory = true
    @State private var selectedHistoryDate: Date?
    @State private var displayedMonth: Date = Date()

    // Today's data
    @State private var todayData: DailyActivitySummaryData = .empty
    @State private var isLoadingToday = true

    // Baseline data
    @State private var baselineData: DailyActivitySummaryData = .empty

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
            .navigationTitle(viewModel.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadTodayData()
                await loadBaselineData()
                await loadScoreHistory()
            }
            .sheet(item: $selectedHistoryDate) { date in
                DailyActivityDayDetailView(
                    date: date,
                    score: scoreHistory[dateString(for: date)],
                    color: color,
                    viewModel: viewModel
                )
            }
        }
    }

    // MARK: - Today Tab

    private var todayTabContent: some View {
        VStack(spacing: 20) {
            if viewModel.hasDailyScore {
                ScoreRingPill(
                    score: viewModel.dailyScoreValue,
                    iconName: "figure.stand",
                    label: "Today",
                    size: 90
                )
                .padding(.top, 8)

                Text(scoreLabel(for: viewModel.dailyScoreValue))
                    .font(.headline)
                    .foregroundColor(scoreColor(for: viewModel.dailyScoreValue))

                if isLoadingToday {
                    ProgressView().padding(.vertical, 40)
                } else {
                    DailyActivitySummaryCard(
                        title: "Today's Activity",
                        data: todayData,
                        color: color,
                        viewModel: viewModel
                    )
                }

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

    private var baselineTabContent: some View {
        VStack(spacing: 20) {
            ScoreRingPill(
                score: viewModel.scoreValue,
                iconName: "figure.stand",
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

            DailyActivitySummaryCard(
                title: "Your Goals",
                data: baselineData,
                color: color,
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
                // Day headers
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                    ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                        Text(day)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(daysInMonth(), id: \.self) { date in
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

        return Button {
            if score != nil {
                selectedHistoryDate = date
            }
        } label: {
            VStack(spacing: 2) {
                if let score = score {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.15), lineWidth: 2)
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
            Text("No activity data today")
                .font(.headline)
            Text("Move around to see today's activity metrics")
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

    private func loadTodayData() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            let today = Calendar.current.startOfDay(for: Date())
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let todayString = dateFormatter.string(from: today)

            // Load activity metrics for today
            struct ActivitySample: Decodable {
                let quantityType: String
                let canonicalValue: Double

                enum CodingKeys: String, CodingKey {
                    case quantityType = "quantity_type"
                    case canonicalValue = "canonical_value"
                }
            }

            let samples: [ActivitySample] = try await client
                .from("patient_quantity_samples")
                .select("quantity_type, canonical_value")
                .eq("patient_id", value: userId.uuidString)
                .in("quantity_type", values: ["apple_move_time_min", "apple_stand_hours", "active_energy_kcal", "exercise_snack_count"])
                .eq("aggregation_date", value: todayString)
                .in("source", values: ["wellpath_input", "healthkit", "calculated"])
                .execute()
                .value

            var moveMinutes = 0
            var standHours = 0
            var activeCalories = 0
            var exerciseSnacks = 0

            for sample in samples {
                switch sample.quantityType {
                case "apple_move_time_min":
                    moveMinutes = Int(sample.canonicalValue)
                case "apple_stand_hours":
                    standHours = Int(sample.canonicalValue)
                case "active_energy_kcal":
                    activeCalories = Int(sample.canonicalValue)
                case "exercise_snack_count":
                    exerciseSnacks = Int(sample.canonicalValue)
                default:
                    break
                }
            }

            let moveGoal = Int(viewModel.baselines["daily_move_minutes_goal"] ?? 30)
            let standGoal = Int(viewModel.baselines["daily_stand_hours_goal"] ?? 12)
            let caloriesGoal = Int(viewModel.baselines["daily_active_calories_goal"] ?? 500)
            let snacksGoal = Int(viewModel.baselines["daily_exercise_snacks_goal"] ?? 3)

            todayData = DailyActivitySummaryData(
                moveMinutes: moveMinutes,
                standHours: standHours,
                activeCalories: activeCalories,
                exerciseSnacks: exerciseSnacks,
                moveMinutesGoal: moveGoal,
                standHoursGoal: standGoal,
                activeCaloriesGoal: caloriesGoal,
                exerciseSnacksGoal: snacksGoal,
                moveMinutesScore: viewModel.moveMinutesScore,
                standTimeScore: viewModel.standTimeScore,
                activeCaloriesScore: viewModel.activeCaloriesScore,
                exerciseSnacksScore: viewModel.exerciseSnacksScore,
                overallScore: viewModel.dailyScoreValue
            )

            isLoadingToday = false
        } catch {
            print("Error loading today's data: \(error)")
            isLoadingToday = false
        }
    }

    private func loadBaselineData() async {
        let moveGoal = Int(viewModel.baselines["daily_move_minutes_goal"] ?? 30)
        let standGoal = Int(viewModel.baselines["daily_stand_hours_goal"] ?? 12)
        let caloriesGoal = Int(viewModel.baselines["daily_active_calories_goal"] ?? 500)
        let snacksGoal = Int(viewModel.baselines["daily_exercise_snacks_goal"] ?? 3)

        baselineData = DailyActivitySummaryData(
            moveMinutes: moveGoal,
            standHours: standGoal,
            activeCalories: caloriesGoal,
            exerciseSnacks: snacksGoal,
            moveMinutesGoal: moveGoal,
            standHoursGoal: standGoal,
            activeCaloriesGoal: caloriesGoal,
            exerciseSnacksGoal: snacksGoal,
            moveMinutesScore: viewModel.moveMinutesScore,
            standTimeScore: viewModel.standTimeScore,
            activeCaloriesScore: viewModel.activeCaloriesScore,
            exerciseSnacksScore: viewModel.exerciseSnacksScore,
            overallScore: viewModel.scoreValue
        )
    }

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
                .eq("quantity_type", value: "daily_activity_score")
                .eq("source", value: "calculated")
                .gte("aggregation_date", value: startDateString)
                .order("aggregation_date", ascending: false)
                .execute()
                .value

            var historyDict: [String: Int] = [:]
            for result in results {
                historyDict[result.aggregationDate] = Int(result.canonicalValue)
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

struct DailyActivitySummaryCard: View {
    let title: String
    let data: DailyActivitySummaryData
    let color: Color
    let viewModel: DailyActivityScoreViewModel
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

            // Summary grid (always visible)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                activityMetricCell(
                    icon: "flame.fill",
                    value: "\(data.moveMinutes)",
                    goal: "\(data.moveMinutesGoal)",
                    unit: "min",
                    label: "Move Minutes"
                )

                activityMetricCell(
                    icon: "figure.stand",
                    value: "\(data.standHours)",
                    goal: "\(data.standHoursGoal)",
                    unit: "hrs",
                    label: "Stand Hours"
                )

                activityMetricCell(
                    icon: "bolt.fill",
                    value: "\(data.activeCalories)",
                    goal: "\(data.activeCaloriesGoal)",
                    unit: "kcal",
                    label: "Active Calories"
                )

                activityMetricCell(
                    icon: "sparkles",
                    value: "\(data.exerciseSnacks)",
                    goal: "\(data.exerciseSnacksGoal)",
                    unit: "",
                    label: "Exercise Snacks"
                )
            }
            .padding()

            // Expanded details
            if isExpanded {
                Divider().padding(.horizontal)

                VStack(spacing: 16) {
                    componentScoresSection
                }
                .padding()
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func activityMetricCell(icon: String, value: String, goal: String, unit: String, label: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                Text("/ \(goal) \(unit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }

    private var componentScoresSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Score Components")
                .font(.subheadline)
                .fontWeight(.medium)

            // Move Minutes Score
            componentRow(
                icon: "flame.fill",
                name: "Move Minutes",
                description: "Daily active movement time",
                score: data.moveMinutesScore,
                weight: "25%"
            )

            Divider()

            // Stand Time Score
            componentRow(
                icon: "figure.stand",
                name: "Stand Time",
                description: "Hours with standing activity",
                score: data.standTimeScore,
                weight: "25%"
            )

            Divider()

            // Active Calories Score
            componentRow(
                icon: "bolt.fill",
                name: "Active Calories",
                description: "Energy from activity",
                score: data.activeCaloriesScore,
                weight: "25%"
            )

            Divider()

            // Exercise Snacks Score
            componentRow(
                icon: "sparkles",
                name: "Exercise Snacks",
                description: "Brief movement breaks",
                score: data.exerciseSnacksScore,
                weight: "25%"
            )
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }

    private func componentRow(icon: String, name: String, description: String, score: Int?, weight: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                if let score = score {
                    Text("\(score)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor(for: score))
                } else {
                    Text("--")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Text(weight)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func scoreColor(for score: Int) -> Color {
        if score >= 80 { return .green }
        else if score >= 60 { return .yellow }
        else if score >= 40 { return .orange }
        else { return .red }
    }
}

// MARK: - Day Detail View (for History)

struct DailyActivityDayDetailView: View {
    let date: Date
    let score: Int?
    let color: Color
    @ObservedObject var viewModel: DailyActivityScoreViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var dayData: DailyActivitySummaryData = .empty
    @State private var isLoading = true

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ScoreRingPill(
                        score: score,
                        iconName: "figure.stand",
                        label: formattedDate,
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
                        DailyActivitySummaryCard(
                            title: "Activity Summary",
                            data: dayData,
                            color: color,
                            viewModel: viewModel
                        )
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(formattedDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadDayData()
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

    private func loadDayData() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            // Load activity metrics for the day
            struct ActivitySample: Decodable {
                let quantityType: String
                let canonicalValue: Double

                enum CodingKeys: String, CodingKey {
                    case quantityType = "quantity_type"
                    case canonicalValue = "canonical_value"
                }
            }

            let samples: [ActivitySample] = try await client
                .from("patient_quantity_samples")
                .select("quantity_type, canonical_value")
                .eq("patient_id", value: userId.uuidString)
                .in("quantity_type", values: ["apple_move_time_min", "apple_stand_hours", "active_energy_kcal", "exercise_snack_count"])
                .eq("aggregation_date", value: dateString)
                .in("source", values: ["wellpath_input", "healthkit", "calculated"])
                .execute()
                .value

            var moveMinutes = 0
            var standHours = 0
            var activeCalories = 0
            var exerciseSnacks = 0

            for sample in samples {
                switch sample.quantityType {
                case "apple_move_time_min":
                    moveMinutes = Int(sample.canonicalValue)
                case "apple_stand_hours":
                    standHours = Int(sample.canonicalValue)
                case "active_energy_kcal":
                    activeCalories = Int(sample.canonicalValue)
                case "exercise_snack_count":
                    exerciseSnacks = Int(sample.canonicalValue)
                default:
                    break
                }
            }

            let moveGoal = Int(viewModel.baselines["daily_move_minutes_goal"] ?? 30)
            let standGoal = Int(viewModel.baselines["daily_stand_hours_goal"] ?? 12)
            let caloriesGoal = Int(viewModel.baselines["daily_active_calories_goal"] ?? 500)
            let snacksGoal = Int(viewModel.baselines["daily_exercise_snacks_goal"] ?? 3)

            dayData = DailyActivitySummaryData(
                moveMinutes: moveMinutes,
                standHours: standHours,
                activeCalories: activeCalories,
                exerciseSnacks: exerciseSnacks,
                moveMinutesGoal: moveGoal,
                standHoursGoal: standGoal,
                activeCaloriesGoal: caloriesGoal,
                exerciseSnacksGoal: snacksGoal,
                moveMinutesScore: nil,
                standTimeScore: nil,
                activeCaloriesScore: nil,
                exerciseSnacksScore: nil,
                overallScore: score
            )

            isLoading = false
        } catch {
            print("Error loading day data: \(error)")
            isLoading = false
        }
    }
}

#Preview {
    DailyActivityScoreDetailView(
        viewModel: DailyActivityScoreViewModel(),
        color: .orange
    )
}
