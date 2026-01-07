//
//  GoalDetailView.swift
//  WellPath
//
//  Detailed view for an individual goal showing progress, rationale, and tips
//  Accessed by tapping a goal card in GoalsListView
//

import SwiftUI

struct GoalDetailView: View {
    let goal: PatientGoal
    let progress: GoalProgress?

    // Internal GoalsViewModel for logging entries and refreshing data
    @StateObject private var goalsViewModel = GoalsViewModel()
    @StateObject private var viewModel = GoalDetailViewModel()
    @State private var showingDetailedEntry = false  // Full food log
    @State private var showingQuickEntry = false     // Quick entry with optional type
    @State private var showingPauseSheet = false
    @State private var showingRemoveConfirm = false
    @State private var showingGoalSettings = false
    @State private var isRemoving = false
    @State private var showCalendarExpanded = false
    @State private var showMyGoalExpanded = false
    @State private var showRationaleExpanded = true
    @State private var displayedMonth = Date()
    @State private var currentTrackingMode: TrackingMode
    @State private var selectedWeekStart: Date? = nil  // nil = current week
    @Environment(\.dismiss) private var dismiss

    init(goal: PatientGoal, progress: GoalProgress?) {
        self.goal = goal
        self.progress = progress
        _currentTrackingMode = State(initialValue: TrackingMode(rawValue: goal.trackingMode) ?? .quick)
    }

    private var pillar: HealthPillar {
        HealthPillar(rawValue: goal.pillarId) ?? .core
    }

    private var pillarColor: Color {
        Color(hex: pillar.color) ?? .green
    }

    private var progressPercent: Double {
        progress?.displayProgress ?? 0
    }

    private var statusColor: Color {
        guard let status = progress?.status else { return .gray }
        switch status {
        case .ahead, .completed: return .green
        case .onTrack: return pillarColor
        case .atRisk: return .orange
        case .behind: return .red
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero Section
                heroSection

                // My Goal
                myGoalSection

                // This Week Progress
                weekProgressSection

                // AI Insight (if available)
                if let insight = progress?.aiInsight, !insight.isEmpty {
                    insightSection(insight: insight)
                }

                // Why This Recommendation
                if let rationale = goal.aiRationale, !rationale.isEmpty {
                    rationaleSection(rationale: rationale)
                }

                // Tips to Get Started
                if let tips = goal.aiTips, !tips.isEmpty {
                    tipsSection(tips: tips)
                }

                // Actions
                actionsSection
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(goal.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    // Goal Settings
                    Button {
                        showingGoalSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }

                    // More options menu
                    Menu {
                        Button {
                            showingPauseSheet = true
                        } label: {
                            Label("Pause Goal", systemImage: "pause.circle")
                        }

                        Button(role: .destructive) {
                            showingRemoveConfirm = true
                        } label: {
                            Label("Request to Remove", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        // Detailed Entry - Full food log (nutrition only)
        .sheet(isPresented: $showingDetailedEntry) {
            NavigationStack {
                FoodEntryView()
            }
        }
        // Quick Entry - Routes to appropriate entry view based on goal type
        .sheet(isPresented: $showingQuickEntry) {
            quickEntryDestination
        }
        .sheet(isPresented: $showingPauseSheet) {
            GoalPauseSheet(goal: goal, onPause: { reason, resumeDate in
                Task {
                    await viewModel.pauseGoal(goalId: goal.goalId, reason: reason, resumeDate: resumeDate)
                    await goalsViewModel.loadGoals()
                    dismiss()
                }
            })
        }
        .sheet(isPresented: $showingGoalSettings) {
            GoalSettingsSheet(goal: goal, pillarColor: pillarColor) { newMode in
                currentTrackingMode = newMode
            }
        }
        .alert("Remove Goal?", isPresented: $showingRemoveConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                Task {
                    isRemoving = true
                    await viewModel.requestRemoval(goalId: goal.goalId)
                    await goalsViewModel.loadGoals()
                    dismiss()
                }
            }
        } message: {
            Text("This will request to remove the goal from your active goals. Your care team will be notified.")
        }
        .task {
            await viewModel.loadWeeklyProgress(
                goalId: goal.goalId,
                trackingType: goal.template?.trackingQuantityType,
                targetValue: goal.targetValue
            )
        }
    }

    // MARK: - Hero Section

    /// Today's value from weekDays
    private var todayValue: Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return viewModel.weekDays.first { calendar.isDate($0.date, inSameDayAs: today) }?.value ?? 0
    }

    /// Week total from all weekDays
    private var weekTotal: Double {
        viewModel.weekDays.reduce(0) { $0 + $1.value }
    }

    /// Weekly target (daily target × 7 for daily goals, or target for weekly goals)
    private var weeklyTarget: Double {
        goal.isWeekly ? goal.targetValue : (goal.targetValue * 7)
    }

    /// Today's progress percentage (0-100)
    private var todayProgressPercent: Double {
        guard goal.targetValue > 0 else { return 0 }
        let dailyTarget = goal.isWeekly ? (goal.targetValue / 7) : goal.targetValue
        return min((todayValue / dailyTarget) * 100, 100)
    }

    /// Week's progress percentage (0-100)
    private var weekProgressPercent: Double {
        guard weeklyTarget > 0 else { return 0 }
        return min((weekTotal / weeklyTarget) * 100, 100)
    }

    /// Whether viewing a historical week (not the current week)
    private var isViewingHistoricalWeek: Bool {
        guard let selected = selectedWeekStart else { return false }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysToSubtract = (weekday + 5) % 7
        guard let currentWeekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) else { return false }
        return !calendar.isDate(selected, inSameDayAs: currentWeekStart)
    }

    /// Days elapsed this week (Mon=1, ..., Sun=7)
    /// For historical weeks, returns 7 (full week)
    private var daysElapsedThisWeek: Int {
        if isViewingHistoricalWeek {
            return 7  // Historical weeks are complete
        }
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        return (weekday + 5) % 7 + 1  // Mon=1, ..., Sun=7
    }

    /// Max potential for the week (current progress + remaining days at 100%)
    /// Today can still hit 100%, so we include today in the remaining potential
    /// For historical weeks, returns the actual progress (no potential remaining)
    private var weekMaxPotential: Double {
        // Historical weeks have no remaining potential
        if isViewingHistoricalWeek {
            return weekProgressPercent
        }
        // Days fully completed (not including today)
        let completedDays = max(0, daysElapsedThisWeek - 1)
        // Today + future days can all hit 100%
        let daysWithPotential = 7 - completedDays
        // Max = progress from completed days + 100% for remaining days (including today)
        let progressFromCompletedDays = completedDays > 0 ? (weekProgressPercent * Double(daysElapsedThisWeek) / Double(completedDays + 1)) : 0
        let remainingPotential = (Double(daysWithPotential) / 7.0) * 100
        return min(progressFromCompletedDays + remainingPotential, 100)
    }

    /// Weekly status based on current progress
    private var weeklyStatus: ProgressStatus {
        if weekProgressPercent >= 100 { return .completed }
        else if weekProgressPercent >= 80 { return .ahead }
        else if weekProgressPercent >= 50 { return .onTrack }
        else if weekProgressPercent >= 25 { return .atRisk }
        else { return .behind }
    }

    private let wellPathGreen = Color(red: 0.56, green: 0.82, blue: 0.31)

    /// Formatted label for the selected week (e.g., "Week of Dec 30")
    private var selectedWeekLabel: String? {
        guard let weekStart = selectedWeekStart, isViewingHistoricalWeek else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "Week of \(formatter.string(from: weekStart))"
    }

    private var heroSection: some View {
        VStack(spacing: 0) {
            // Dark hero section matching Goals page
            ZStack {
                // Background - same as Goals page
                GoalDetailHeroBackground(accentColor: pillarColor)

                VStack(spacing: 4) {
                    // Historical week indicator (when viewing past week)
                    if let weekLabel = selectedWeekLabel {
                        Button {
                            // Return to current week
                            withAnimation {
                                selectedWeekStart = nil
                                Task {
                                    await viewModel.loadWeeklyProgress(
                                        goalId: goal.goalId,
                                        trackingType: goal.template?.trackingQuantityType,
                                        targetValue: goal.targetValue
                                    )
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption2)
                                Text(weekLabel)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("• Tap for current week")
                                    .font(.caption2)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(16)
                        }
                        .padding(.top, 8)
                    }

                    // Pillar badge (glass style)
                    HStack(spacing: 6) {
                        Image(systemName: pillar.icon)
                            .foregroundColor(pillarColor)
                        Text(pillar.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial.opacity(0.6))
                    .background(pillarColor.opacity(0.2))
                    .cornerRadius(16)
                    .padding(.top, isViewingHistoricalWeek ? 8 : 16)

                    // Arc gauge (same as Goals page)
                    AdherenceArcGauge(
                        progress: weekProgressPercent,
                        maxPotential: weekMaxPotential
                    )
                    .frame(height: 85)
                    .padding(.top, 8)

                    // Large score (no % - matches Goals page)
                    Text("\(Int(weekProgressPercent))")
                        .font(.system(size: 72, weight: .thin, design: .rounded))
                        .foregroundColor(.white)

                    // Label
                    Text("WEEKLY ADHERENCE")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(2)

                    // Max potential (still achievable) - ABOVE day rings
                    if weekMaxPotential > weekProgressPercent {
                        Text("\(Int(weekMaxPotential))% still achievable")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(wellPathGreen)
                            .padding(.top, 4)
                    }

                    // 7-day week dots (Mon-Sun)
                    WeekProgressDots(
                        weekDays: viewModel.weekDays,
                        targetValue: goal.targetValue,
                        isWeeklyGoal: goal.isWeekly,
                        accentColor: wellPathGreen
                    )
                    .padding(.top, 12)

                    Spacer().frame(height: 16)
                }
            }
            .frame(height: 340)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    // MARK: - My Goal Section

    private var myGoalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "My Goal", icon: "target")

            VStack(alignment: .leading, spacing: 8) {
                // Target display
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(goal.targetValue))")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(pillarColor)

                    Text(goal.targetUnit)
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text(goal.isWeekly ? "per week" : "per day")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Description
                if let description = goal.template?.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Current progress
                HStack {
                    Text("Current:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(Int(progress?.displayActual ?? 0)) \(goal.targetUnit)")
                        .font(.caption)
                        .fontWeight(.semibold)

                    Spacer()

                    Text("Remaining:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    let remaining = max(0, goal.targetValue - (progress?.displayActual ?? 0))
                    Text("\(Int(remaining)) \(goal.targetUnit)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(remaining > 0 ? .orange : .green)
                }
                .padding(.top, 4)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Week Progress Section (Expandable Calendar)

    private var weekProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tappable header to expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showCalendarExpanded.toggle()
                }
            } label: {
                HStack {
                    SectionHeader(title: "Progress History", icon: "calendar")
                    Spacer()
                    Image(systemName: showCalendarExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if showCalendarExpanded {
                GoalCalendarView(
                    goal: goal,
                    weekDays: viewModel.weekDays,
                    monthDays: viewModel.monthDays,
                    accentColor: pillarColor,
                    displayedMonth: $displayedMonth,
                    onLoadMonth: { month in
                        Task {
                            await viewModel.loadMonthProgress(
                                goalId: goal.goalId,
                                trackingType: goal.template?.trackingQuantityType,
                                targetValue: goal.targetValue,
                                month: month
                            )
                        }
                    },
                    onDayTapped: { tappedDate in
                        // Calculate Monday of the tapped date's week
                        let calendar = Calendar.current
                        let weekday = calendar.component(.weekday, from: tappedDate)
                        let daysToSubtract = (weekday + 5) % 7  // Mon=0, Tue=1, ..., Sun=6
                        guard let weekMonday = calendar.date(byAdding: .day, value: -daysToSubtract, to: calendar.startOfDay(for: tappedDate)) else { return }

                        // Update selected week and load data
                        withAnimation {
                            selectedWeekStart = weekMonday
                        }
                        Task {
                            await viewModel.loadWeeklyProgress(
                                goalId: goal.goalId,
                                trackingType: goal.template?.trackingQuantityType,
                                targetValue: goal.targetValue,
                                weekStart: weekMonday
                            )
                        }
                    }
                )
                .task {
                    // Load current month data when calendar expands
                    await viewModel.loadMonthProgress(
                        goalId: goal.goalId,
                        trackingType: goal.template?.trackingQuantityType,
                        targetValue: goal.targetValue,
                        month: displayedMonth
                    )
                }
            } else {
                // Collapsed summary
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("This Week")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(viewModel.daysCompleted)/7 days")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    Spacer()

                    Text("Tap to expand")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Insight Section

    private func insightSection(insight: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Today's Insight", icon: "sparkles")

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                    .font(.title3)

                Text(insight)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)
        }
    }

    // MARK: - Rationale Section

    private func rationaleSection(rationale: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tappable header
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showRationaleExpanded.toggle()
                }
            } label: {
                HStack(alignment: .center) {
                    Image(systemName: "lightbulb.fill")
                        .font(.subheadline)
                        .foregroundColor(.yellow)
                    Text("Why This Recommendation")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: showRationaleExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if showRationaleExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Text(rationale)
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Potential impact section (placeholder for agent-written content)
                    if let _ = goal.aiRationale {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Potential Impact")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            HStack(spacing: 16) {
                                ImpactPill(icon: "heart.fill", label: "Heart Health", color: .red)
                                ImpactPill(icon: "figure.walk", label: "Longevity", color: .green)
                            }
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

    // MARK: - Tips Section

    private func tipsSection(tips: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Tips to Get Started", icon: "checkmark.circle.fill")

            VStack(alignment: .leading, spacing: 8) {
                ForEach(tips.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(pillarColor)
                            .clipShape(Circle())

                        Text(tips[index])
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Primary log button - routes based on tracking mode for nutrition, or quick entry for others
            Button {
                if goal.pillarId == "nutrition" {
                    switch currentTrackingMode {
                    case .detailed:
                        showingDetailedEntry = true
                    case .quick:
                        showingQuickEntry = true
                    }
                } else {
                    // Non-nutrition goals always use quick entry
                    showingQuickEntry = true
                }
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Log Progress")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(pillarColor)
                .cornerRadius(12)
            }

            // View Data - navigates to WellPath Data screen
            NavigationLink {
                historyDestination
            } label: {
                HStack {
                    Image(systemName: "chart.bar.xaxis")
                    Text("View Data")
                }
                .font(.subheadline)
                .foregroundColor(pillarColor)
                .frame(maxWidth: .infinity)
                .padding()
                .background(pillarColor.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Quick Entry Destination

    /// Routes to appropriate entry view based on goal tracking type
    @ViewBuilder
    private var quickEntryDestination: some View {
        switch goal.template?.trackingQuantityType {
        // Nutrition - use ProteinEntryView for protein, others need their own entry views
        case "protein_grams":
            ProteinEntryView()

        // Movement - session-based entry views
        case "strength_duration":
            // TODO: Create StrengthEntryView
            Text("Strength training entry coming soon")
        case "cardio_duration":
            // TODO: Create CardioEntryView
            Text("Cardio entry coming soon")
        case "hiit_duration":
            // TODO: Create HIITEntryView
            Text("HIIT entry coming soon")
        case "mobility_duration":
            // TODO: Create MobilityEntryView
            Text("Mobility entry coming soon")

        // Steps - can be tracked via HealthKit or manual entry
        case "steps":
            StepsEntryView()

        // Sleep
        case "sleep_duration":
            SleepEntryView()

        default:
            // Fallback for unhandled types
            VStack(spacing: 16) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("Entry view not available")
                    .font(.headline)
                if let trackingType = goal.template?.trackingQuantityType {
                    Text("(\(trackingType))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }

    // MARK: - History Destination

    /// Maps goal tracking type to the appropriate WellPath Data screen
    /// Tracking types come from sample_quantity_types (updated 2026-01-03)
    @ViewBuilder
    private var historyDestination: some View {
        switch goal.template?.trackingQuantityType {
        // Movement
        case "steps":
            StepsScreen(pillar: goal.pillarId, color: pillarColor, sectionId: "SECT_STEPS")
        case "cardio_duration":
            CardioScreen(pillar: goal.pillarId, color: pillarColor, sectionId: "SECT_CARDIO")
        case "strength_duration":
            StrengthScreen(pillar: goal.pillarId, color: pillarColor, sectionId: "SECT_STRENGTH")
        case "hiit_duration":
            // HIIT shares Cardio screen for now
            CardioScreen(pillar: goal.pillarId, color: pillarColor, sectionId: "SECT_CARDIO")
        case "mobility_duration":
            MobilityScreen(pillar: goal.pillarId, color: pillarColor, sectionId: "SECT_MOBILITY")
        case "stand_time":
            StandTimeScreen(pillar: goal.pillarId, color: pillarColor, sectionId: "SECT_STAND_TIME")
        case "active_calories":
            ActiveCaloriesScreen(pillar: goal.pillarId, color: pillarColor, sectionId: "SECT_ACTIVE_CALORIES")
        case "exercise_snacks":
            ExerciseSnacksScreen(pillar: goal.pillarId, color: pillarColor, sectionId: "SECT_EXERCISE_SNACKS")

        // Nutrition (NutrientScreen pattern - no sectionId)
        case "protein_grams":
            ProteinScreen(pillar: goal.pillarId, color: pillarColor)
        case "vegetables_servings":
            VegetablesScreen(pillar: goal.pillarId, color: pillarColor)
        case "fruits_servings":
            FruitsScreen(pillar: goal.pillarId, color: pillarColor)
        case "legumes_servings":
            LegumesScreen(pillar: goal.pillarId, color: pillarColor)
        case "whole_grains_servings":
            WholeGrainsScreen(pillar: goal.pillarId, color: pillarColor)
        case "nuts_seeds_servings":
            NutsSeedsScreen(pillar: goal.pillarId, color: pillarColor)
        case "water_ml":
            WaterScreen(pillar: goal.pillarId, color: pillarColor)
        case "caffeine_mg":
            CaffeineScreen(pillar: goal.pillarId, color: pillarColor)
        case "fiber_grams":
            FiberScreen(pillar: goal.pillarId, color: pillarColor)
        case "fat_grams", "saturated_fat_grams":
            FatsScreen(pillar: goal.pillarId, color: pillarColor)
        // Note: sugar_grams not routed - REC_SUGARS_LIMIT deactivated until SugarScreen built
        case "ultra_processed_servings":
            UltraProcessedScreen(pillar: goal.pillarId, color: pillarColor)

        // Sleep
        case "sleep_duration":
            SleepDurationScreen(pillar: goal.pillarId, color: pillarColor)
        case "in_bed_start", "in_bed_end":
            // Sleep consistency uses sleep consistency screen
            SleepConsistencyScreen(pillar: goal.pillarId, color: pillarColor)

        default:
            // Fallback - show a message that history is not available
            VStack(spacing: 16) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("History not available for this goal type")
                    .font(.headline)
                    .foregroundColor(.secondary)
                if let trackingType = goal.template?.trackingQuantityType {
                    Text("(\(trackingType))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Day Progress Bar

struct DayProgressBar: View {
    let day: DayProgress
    let targetValue: Double
    let accentColor: Color

    private var fillPercent: Double {
        guard targetValue > 0 else { return 0 }
        return min(day.value / targetValue, 1.0)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(day.date)
    }

    var body: some View {
        VStack(spacing: 4) {
            // Bar
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(fillPercent >= 1.0 ? Color.green : accentColor)
                        .frame(height: geometry.size.height * fillPercent)
                }
            }

            // Day label
            Text(day.dayLabel)
                .font(.caption2)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundColor(isToday ? accentColor : .secondary)
        }
    }
}

// MARK: - Day Progress Model

struct DayProgress {
    let date: Date
    let value: Double

    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: date).prefix(1))
    }
}

// MARK: - Week Progress Dots (7-day view)

struct WeekProgressDots: View {
    let weekDays: [DayProgress]
    let targetValue: Double
    let isWeeklyGoal: Bool
    let accentColor: Color

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    private var sortedDays: [DayProgress] {
        // Ensure days are Mon-Sun ordered
        let calendar = Calendar.current
        return weekDays.sorted { day1, day2 in
            let weekday1 = calendar.component(.weekday, from: day1.date)
            let weekday2 = calendar.component(.weekday, from: day2.date)
            // Convert to Mon=0, Tue=1, ..., Sun=6
            let adjusted1 = (weekday1 + 5) % 7
            let adjusted2 = (weekday2 + 5) % 7
            return adjusted1 < adjusted2
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(sortedDays.enumerated()), id: \.offset) { index, day in
                VStack(spacing: 4) {
                    // Day dot/ring
                    dayDot(for: day)

                    // Day label
                    Text(dayLabels[index % 7])
                        .font(.caption2)
                        .fontWeight(isToday(day.date) ? .bold : .regular)
                        .foregroundColor(isToday(day.date) ? accentColor : .secondary)
                }
            }
        }
    }

    private func dayDot(for day: DayProgress) -> some View {
        let isComplete = isWeeklyGoal ? day.value > 0 : (targetValue > 0 && day.value >= targetValue)
        let hasProgress = day.value > 0
        let progress = targetValue > 0 ? min(day.value / targetValue, 1.0) : 0

        return ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                .frame(width: 28, height: 28)

            // Progress ring (for daily goals with partial progress)
            if !isWeeklyGoal && hasProgress && !isComplete {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(-90))
            }

            // Fill for completed
            if isComplete {
                Circle()
                    .fill(accentColor)
                    .frame(width: 22, height: 22)

                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            } else if isToday(day.date) {
                // Highlight today
                Circle()
                    .stroke(accentColor, lineWidth: 2)
                    .frame(width: 22, height: 22)
            }
        }
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}

// MARK: - Goal Calendar View (Expanded)

struct GoalCalendarView: View {
    let goal: PatientGoal
    let weekDays: [DayProgress]
    let monthDays: [DayProgress]  // Full month data for calendar lookup
    let accentColor: Color
    @Binding var displayedMonth: Date
    let onLoadMonth: (Date) -> Void
    var onDayTapped: ((Date) -> Void)? = nil  // Callback when a day is tapped

    var body: some View {
        VStack(spacing: 16) {
            // Month navigation
            HStack {
                Button {
                    withAnimation {
                        if let newMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) {
                            displayedMonth = newMonth
                            onLoadMonth(newMonth)
                        }
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundColor(accentColor)
                }

                Spacer()
                Text(monthYearString(for: displayedMonth))
                    .font(.headline)
                Spacer()

                Button {
                    withAnimation {
                        if let newMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth),
                           newMonth <= Date() {
                            displayedMonth = newMonth
                            onLoadMonth(newMonth)
                        }
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundColor(displayedMonth < Calendar.current.startOfMonth(for: Date()) ? accentColor : .secondary.opacity(0.3))
                }
            }

            // Day headers (Mon-Sun)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
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
                        Button {
                            // Only allow tapping past dates (not future)
                            if date <= Date() {
                                onDayTapped?(date)
                            }
                        } label: {
                            calendarDayCell(for: date)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }
            }

            // Week summary
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("This Week")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    let completed = weekDays.filter { day in
                        goal.isWeekly ? day.value > 0 : (goal.targetValue > 0 && day.value >= goal.targetValue)
                    }.count
                    Text("\(completed)/7 days completed")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func calendarDayCell(for date: Date) -> some View {
        let calendar = Calendar.current
        let dayNumber = calendar.component(.day, from: date)
        let isFuture = date > Date()
        let isCurrentMonth = calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)

        // Find matching day data - check monthDays first, then weekDays as fallback
        let dayData = monthDays.first { calendar.isDate($0.date, inSameDayAs: date) }
            ?? weekDays.first { calendar.isDate($0.date, inSameDayAs: date) }
        let value = dayData?.value ?? 0
        let hasData = value > 0

        // Calculate daily target (for weekly goals, divide by 7)
        let dailyTarget = goal.isWeekly ? (goal.targetValue / 7) : goal.targetValue
        let progressPercent = dailyTarget > 0 ? min(value / dailyTarget, 1.0) : 0
        let isComplete = progressPercent >= 1.0

        return VStack(spacing: 2) {
            if isComplete {
                // Full circle - goal met
                ZStack {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 28, height: 28)
                    Text("\(dayNumber)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
            } else if hasData {
                // Partial ring showing progress percentage
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(accentColor.opacity(0.2), lineWidth: 2.5)
                        .frame(width: 28, height: 28)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: progressPercent)
                        .stroke(accentColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(-90))

                    Text("\(dayNumber)")
                        .font(.caption)
                        .foregroundColor(accentColor)
                }
            } else {
                // No data - plain number
                Text("\(dayNumber)")
                    .font(.caption)
                    .foregroundColor(isFuture || !isCurrentMonth ? .secondary.opacity(0.3) : .secondary)
                    .frame(width: 28, height: 28)
            }
        }
        .frame(height: 36)
    }

    private func daysInMonth() -> [Date?] {
        let calendar = Calendar.current

        // Get first day of month
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)),
              let monthRange = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return []
        }

        // Get weekday of first day (adjusted for Mon-Sun, where Mon=0)
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let adjustedFirstWeekday = (firstWeekday + 5) % 7 // Mon=0, Tue=1, ..., Sun=6

        var days: [Date?] = []

        // Add empty cells for days before month start
        for _ in 0..<adjustedFirstWeekday {
            days.append(nil)
        }

        // Add days of month
        for day in monthRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(date)
            }
        }

        return days
    }

    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Impact Pill

struct ImpactPill: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Goal Detail ViewModel

@MainActor
class GoalDetailViewModel: ObservableObject {
    @Published var weekDays: [DayProgress] = []
    @Published var monthDays: [DayProgress] = []  // Full month data for calendar view
    @Published var isLoading = false
    @Published var targetValue: Double = 0
    private var loadedMonths: Set<String> = []  // Track which months have been loaded

    private let supabase = SupabaseManager.shared.client
    private let samplesService = PatientSamplesQueryService.shared

    /// Maps tracking types to sample query types
    /// Updated 2026-01-03 to match sample_quantity_types
    private static let trackingTypeToSampleType: [String: String] = [
        // Movement
        "steps": "steps",
        "cardio_duration": "cardio",
        "strength_duration": "strength_training",
        "hiit_duration": "hiit",
        "mobility_duration": "mobility",
        "stand_time": "stand_time",
        "active_calories": "active_calories",
        "exercise_snacks": "exercise_snacks",
        "exercise_time": "exercise_time",

        // Nutrition
        "protein_grams": "protein_grams",
        "vegetables_servings": "vegetables_servings",
        "fruits_servings": "fruits_servings",
        "legumes_servings": "legumes_servings",
        "whole_grains_servings": "whole_grains_servings",
        "nuts_seeds_servings": "nuts_seeds_servings",
        "water_ml": "water_ml",
        "caffeine_mg": "caffeine_mg",
        "fiber_grams": "fiber_grams",
        "fat_grams": "fat_grams",
        "saturated_fat_grams": "saturated_fat_grams",
        // sugar_grams removed - REC_SUGARS_LIMIT deactivated until SugarScreen built
        "ultra_processed_servings": "ultra_processed_servings",

        // Sleep
        "sleep_duration": "sleep_duration",
        "in_bed_start": "in_bed_start",
        "in_bed_end": "in_bed_end"
    ]

    var weeklyAverage: Double {
        let daysWithData = weekDays.filter { $0.value > 0 }
        guard !daysWithData.isEmpty else { return 0 }
        return daysWithData.reduce(0) { $0 + $1.value } / Double(daysWithData.count)
    }

    var daysCompleted: Int {
        guard targetValue > 0 else {
            return weekDays.filter { $0.value > 0 }.count
        }
        return weekDays.filter { $0.value >= targetValue }.count
    }

    func loadWeeklyProgress(goalId: String, trackingType: String?, targetValue: Double, weekStart: Date? = nil) async {
        self.targetValue = targetValue
        isLoading = true
        defer { isLoading = false }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Use provided weekStart, or calculate current week's Monday
        let weekStartDate: Date
        if let provided = weekStart {
            weekStartDate = calendar.startOfDay(for: provided)
        } else {
            // Get start of current week (Monday) - ISO 8601 week
            // Sunday=1, Monday=2, ..., Saturday=7
            // For Monday start: if today is Sunday (1), go back 6 days; if Monday (2), go back 0 days
            let weekday = calendar.component(.weekday, from: today)
            let daysToSubtract = (weekday + 5) % 7  // Mon=0, Tue=1, ..., Sun=6
            guard let start = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) else {
                return
            }
            weekStartDate = start
        }

        // Generate 7 days for the week
        var days: [DayProgress] = []
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: weekStartDate) {
                days.append(DayProgress(date: date, value: 0))
            }
        }

        // Calculate end date for this week (min of week end or today)
        let weekEndDate = calendar.date(byAdding: .day, value: 6, to: weekStartDate) ?? weekStartDate
        let endDate = min(weekEndDate, today)

        // Load real data from patient samples
        guard let trackingType = trackingType else {
            weekDays = days
            return
        }

        do {
            if trackingType == "sleep_duration" {
                // Sleep uses special query - returns minutes, convert to hours
                let sleepData = try await samplesService.fetchSleepDurationDaily(
                    startDate: weekStartDate,
                    endDate: endDate
                )
                weekDays = days.map { day in
                    let dayData = sleepData.first { calendar.isDate($0.date, inSameDayAs: day.date) }
                    return DayProgress(date: day.date, value: (dayData?.value ?? 0) / 60.0)
                }
            } else if let sampleType = Self.trackingTypeToSampleType[trackingType] {
                // Standard quantity samples
                let dailyValues = try await samplesService.fetchQuantityDaily(
                    quantityType: sampleType,
                    startDate: weekStartDate,
                    endDate: endDate
                )

                // For duration goals, we sum duration values; for session counts, we count entries
                let isSessionCount = trackingType.contains("_sessions_weekly")

                weekDays = days.map { day in
                    let dayData = dailyValues.first { calendar.isDate($0.date, inSameDayAs: day.date) }
                    let value = isSessionCount ? Double(dayData?.count ?? 0) : (dayData?.value ?? 0)
                    return DayProgress(date: day.date, value: value)
                }
            } else {
                weekDays = days
            }
        } catch {
            print("[GoalDetail] Error loading weekly progress: \(error)")
            weekDays = days
        }
    }

    // MARK: - Month Progress (for calendar view)

    func loadMonthProgress(goalId: String, trackingType: String?, targetValue: Double, month: Date) async {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let monthKey = formatter.string(from: month)

        // Skip if already loaded this month
        if loadedMonths.contains(monthKey) {
            return
        }

        // Get start and end of month
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            return
        }

        // Cap end date at today
        let today = calendar.startOfDay(for: Date())
        let endDate = min(monthEnd, today)

        guard let trackingType = trackingType else { return }

        do {
            var newDays: [DayProgress] = []

            if trackingType == "sleep_duration" {
                let sleepData = try await samplesService.fetchSleepDurationDaily(
                    startDate: monthStart,
                    endDate: endDate
                )
                // Generate all days in the month
                var currentDate = monthStart
                while currentDate <= endDate {
                    let dayData = sleepData.first { calendar.isDate($0.date, inSameDayAs: currentDate) }
                    newDays.append(DayProgress(date: currentDate, value: (dayData?.value ?? 0) / 60.0))
                    currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
                }
            } else if let sampleType = Self.trackingTypeToSampleType[trackingType] {
                let dailyValues = try await samplesService.fetchQuantityDaily(
                    quantityType: sampleType,
                    startDate: monthStart,
                    endDate: endDate
                )

                let isSessionCount = trackingType.contains("_sessions_weekly")

                var currentDate = monthStart
                while currentDate <= endDate {
                    let dayData = dailyValues.first { calendar.isDate($0.date, inSameDayAs: currentDate) }
                    let value = isSessionCount ? Double(dayData?.count ?? 0) : (dayData?.value ?? 0)
                    newDays.append(DayProgress(date: currentDate, value: value))
                    currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
                }
            }

            // Merge new days into monthDays (don't duplicate)
            for newDay in newDays {
                if !monthDays.contains(where: { calendar.isDate($0.date, inSameDayAs: newDay.date) }) {
                    monthDays.append(newDay)
                }
            }

            // Also update weekDays with any matching data
            for (index, weekDay) in weekDays.enumerated() {
                if let monthDay = newDays.first(where: { calendar.isDate($0.date, inSameDayAs: weekDay.date) }) {
                    weekDays[index] = monthDay
                }
            }

            loadedMonths.insert(monthKey)

        } catch {
            print("[GoalDetail] Error loading month progress: \(error)")
        }
    }

    // MARK: - Goal Actions

    func pauseGoal(goalId: String, reason: PauseReason, resumeDate: Date) async {
        let isoFormatter = ISO8601DateFormatter()
        let resumeDateStr = isoFormatter.string(from: resumeDate)
        let reasonStr = reason == .other ? reason.rawValue : reason.rawValue

        do {
            try await supabase
                .from("patient_goals")
                .update([
                    "status": "paused",
                    "pause_reason": reasonStr
                ])
                .eq("goal_id", value: goalId)
                .execute()

            print("[GoalDetail] Goal paused successfully")
        } catch {
            print("[GoalDetail] Error pausing goal: \(error)")
        }
    }

    func requestRemoval(goalId: String) async {
        do {
            try await supabase
                .from("patient_goals")
                .update(["status": "abandoned"])
                .eq("goal_id", value: goalId)
                .execute()

            print("[GoalDetail] Goal removal requested")
        } catch {
            print("[GoalDetail] Error requesting removal: \(error)")
        }
    }
}

// MARK: - Goal Pause Sheet

struct GoalPauseSheet: View {
    let goal: PatientGoal
    let onPause: (PauseReason, Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: PauseReason = .vacation
    @State private var customReason: String = ""
    @State private var resumeDate: Date = Date().addingTimeInterval(7 * 24 * 3600)
    @State private var isPausing = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Reason", selection: $selectedReason) {
                        ForEach(PauseReason.allCases, id: \.self) { reason in
                            Text(reason.displayName).tag(reason)
                        }
                    }

                    if selectedReason == .other {
                        TextField("Please specify...", text: $customReason)
                    }
                } header: {
                    Text("Why are you pausing this goal?")
                }

                Section {
                    DatePicker("Resume on", selection: $resumeDate, in: Date()..., displayedComponents: .date)
                } header: {
                    Text("When should we resume?")
                }

                Section {
                    Text("Your care team will be notified of this pause. This helps them understand your journey and adjust recommendations if needed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Pause Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Pause") {
                        isPausing = true
                        onPause(selectedReason, resumeDate)
                    }
                    .disabled(isPausing)
                }
            }
        }
    }
}

// MARK: - Goal Settings Sheet

struct GoalSettingsSheet: View {
    let goal: PatientGoal
    let pillarColor: Color
    let onSave: (TrackingMode) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTrackingMode: TrackingMode
    @State private var isSaving = false

    private let supabase = SupabaseManager.shared.client

    init(goal: PatientGoal, pillarColor: Color, onSave: @escaping (TrackingMode) -> Void = { _ in }) {
        self.goal = goal
        self.pillarColor = pillarColor
        self.onSave = onSave
        _selectedTrackingMode = State(initialValue: TrackingMode(rawValue: goal.trackingMode) ?? .detailed)
    }

    private var isNutritionGoal: Bool {
        goal.pillarId == "nutrition"
    }

    var body: some View {
        NavigationStack {
            Form {
                // Only show Logging Preference for nutrition goals
                if isNutritionGoal {
                    Section {
                        ForEach(TrackingMode.allCases, id: \.self) { mode in
                            Button {
                                selectedTrackingMode = mode
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(mode.displayName)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text(mode.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if selectedTrackingMode == mode {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(pillarColor)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Logging Preference")
                    } footer: {
                        Text("Choose how detailed you want to log progress for this goal.")
                    }
                }

                Section {
                    HStack {
                        Text("Goal Type")
                        Spacer()
                        Text(goal.isWeekly ? "Weekly" : "Daily")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Target")
                        Spacer()
                        Text("\(Int(goal.targetValue)) \(goal.targetUnit)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Started")
                        Spacer()
                        Text(formatDate(goal.cycleStart))
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Goal Info")
                }
            }
            .navigationTitle("Goal Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isNutritionGoal {
                        Button("Save") {
                            Task {
                                await saveSettings()
                            }
                        }
                        .disabled(isSaving || selectedTrackingMode.rawValue == goal.trackingMode)
                    } else {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private func saveSettings() async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await supabase
                .from("patient_goals")
                .update(["tracking_mode": selectedTrackingMode.rawValue])
                .eq("goal_id", value: goal.goalId)
                .execute()

            await MainActor.run {
                onSave(selectedTrackingMode)
                dismiss()
            }
        } catch {
            print("[GoalSettings] Error saving: \(error)")
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let inputFormatter = ISO8601DateFormatter()
        inputFormatter.formatOptions = [.withFullDate]

        let outputFormatter = DateFormatter()
        outputFormatter.dateStyle = .medium

        if let date = inputFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Tracking Mode

enum TrackingMode: String, CaseIterable {
    case detailed = "detailed"
    case quick = "quick"

    var displayName: String {
        switch self {
        case .detailed: return "Full Entry"
        case .quick: return "Quick Entry"
        }
    }

    var description: String {
        switch self {
        case .detailed: return "Full food log with meals, ingredients, and photos"
        case .quick: return "Quick entry with amount and optional type"
        }
    }
}

// MARK: - Pause Reason

enum PauseReason: String, CaseIterable {
    case vacation = "vacation"
    case illness = "illness"
    case injury = "injury"
    case tooHard = "too_hard"
    case notRelevant = "not_relevant"
    case other = "other"

    var displayName: String {
        switch self {
        case .vacation: return "Vacation/Travel"
        case .illness: return "Illness"
        case .injury: return "Injury"
        case .tooHard: return "Goal is too challenging"
        case .notRelevant: return "No longer relevant to me"
        case .other: return "Other reason"
        }
    }
}

// MARK: - Goal Detail Hero Background

/// Dark hero background for goal detail view, matching the Goals page style
struct GoalDetailHeroBackground: View {
    let accentColor: Color

    private let imageName = "goals_hero_background"

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Try image first, fallback to gradient
                if let uiImage = UIImage(named: imageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()

                    // Dark overlay for text readability
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.4),
                            Color.black.opacity(0.2),
                            Color.black.opacity(0.5)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    // Fallback gradient
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.12, blue: 0.18),
                            Color(red: 0.12, green: 0.18, blue: 0.24),
                            accentColor.opacity(0.3)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GoalDetailView(
            goal: PatientGoal.mockProteinGoal(),
            progress: GoalProgress.mockProgress()
        )
    }
}
