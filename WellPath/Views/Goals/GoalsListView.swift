//
//  GoalsListView.swift
//  WellPath
//
//  Tabbed view showing Active goals, Available recommendations, and History
//  Accessed by tapping the hero ring on Goals tab
//

import SwiftUI

enum GoalsListTab: String, CaseIterable {
    case active = "Active"
    case available = "Available"
    case history = "History"
}

struct GoalsListView: View {
    @StateObject private var viewModel = GoalsListViewModel()
    @State private var selectedTab: GoalsListTab = .active

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Goals", selection: $selectedTab) {
                ForEach(GoalsListTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Tab content
            TabView(selection: $selectedTab) {
                activeGoalsTab
                    .tag(GoalsListTab.active)

                availableGoalsTab
                    .tag(GoalsListTab.available)

                historyTab
                    .tag(GoalsListTab.history)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Your Goals")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadData()
        }
    }

    // MARK: - Active Goals Tab

    @ViewBuilder
    private var activeGoalsTab: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .padding(40)
            } else if viewModel.activeGoals.isEmpty && viewModel.pausedGoals.isEmpty {
                emptyActiveState
            } else {
                LazyVStack(spacing: 12) {
                    // Active goals grouped by pillar
                    ForEach(viewModel.goalsByPillar.keys.sorted(), id: \.self) { pillarId in
                        if let goals = viewModel.goalsByPillar[pillarId], !goals.isEmpty {
                            Section {
                                ForEach(goals) { goal in
                                    NavigationLink(destination: GoalDetailView(goal: goal, progress: viewModel.progressByGoal[goal.goalId])) {
                                        GoalCard(
                                            goal: goal,
                                            progress: viewModel.progressByGoal[goal.goalId],
                                            isAvailable: false
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            } header: {
                                pillarHeader(for: pillarId)
                            }
                        }
                    }

                    // Paused goals section
                    if !viewModel.pausedGoals.isEmpty {
                        Section {
                            ForEach(viewModel.pausedGoals) { goal in
                                PausedGoalCard(
                                    goal: goal,
                                    onResume: {
                                        Task {
                                            await viewModel.resumeGoal(goal)
                                        }
                                    }
                                )
                            }
                        } header: {
                            HStack(spacing: 8) {
                                Image(systemName: "pause.circle.fill")
                                    .foregroundColor(.orange)

                                Text("Paused Goals")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)

                                Spacer()
                            }
                            .padding(.top, 16)
                        }
                    }
                }
                .padding()
            }
        }
    }

    private var emptyActiveState: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Active Goals")
                .font(.headline)

            Text("Your clinician will assign personalized goals based on your health data and recommendations.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if !viewModel.availableGoals.isEmpty {
                Text("Check the Available tab to see recommendations you can try as challenges.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }

    // MARK: - Available Goals Tab

    @ViewBuilder
    private var availableGoalsTab: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .padding(40)
            } else if viewModel.availableGoals.isEmpty {
                emptyAvailableState
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    // Explanation
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)

                        Text("These are recommendations from your health analysis that weren't selected as active goals. You can try them as challenges or request to add them to your plan.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)

                    // Available goals
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.availableGoals) { goal in
                            GoalCard(
                                goal: goal,
                                progress: nil,
                                isAvailable: true,
                                onTryAsChallenge: {
                                    Task {
                                        await viewModel.createChallengeFromGoal(goal)
                                    }
                                },
                                onRequestAsGoal: {
                                    Task {
                                        await viewModel.requestGoalActivation(goal)
                                    }
                                }
                            )
                        }
                    }
                }
                .padding()
            }
        }
    }

    private var emptyAvailableState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Additional Recommendations")
                .font(.headline)

            Text("All your personalized recommendations are currently active as goals. Keep up the great work!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - History Tab

    @ViewBuilder
    private var historyTab: some View {
        ScrollView {
            if viewModel.pastCycles.isEmpty {
                emptyHistoryState
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.pastCycles) { cycle in
                        CycleHistoryCard(cycle: cycle)
                    }
                }
                .padding()
            }
        }
    }

    private var emptyHistoryState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No History Yet")
                .font(.headline)

            Text("Your past cycles and goal progress will appear here after you complete your first cycle.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func pillarHeader(for pillarId: String) -> some View {
        let pillar = HealthPillar(rawValue: pillarId) ?? .core
        let pillarColor = Color(hex: pillar.color) ?? .gray

        HStack(spacing: 8) {
            Image(systemName: pillar.icon)
                .foregroundColor(pillarColor)

            Text(pillar.displayName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - Paused Goal Card

struct PausedGoalCard: View {
    let goal: PatientGoal
    let onResume: () -> Void

    private var pillar: HealthPillar {
        HealthPillar(rawValue: goal.pillarId) ?? .core
    }

    private var pillarColor: Color {
        Color(hex: pillar.color) ?? .gray
    }

    var body: some View {
        HStack(spacing: 12) {
            // Pillar icon
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: pillar.icon)
                    .foregroundColor(.gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                if let reason = goal.pauseReason {
                    Text(formatPauseReason(reason))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: onResume) {
                Text("Resume")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(pillarColor)
                    .cornerRadius(16)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private func formatPauseReason(_ reason: String) -> String {
        switch reason {
        case "vacation": return "Paused for vacation"
        case "illness": return "Paused due to illness"
        case "injury": return "Paused due to injury"
        case "too_hard": return "Goal was too challenging"
        case "not_relevant": return "No longer relevant"
        default: return "Paused"
        }
    }
}

// MARK: - Cycle History Card

struct CycleHistoryCard: View {
    let cycle: PatientCycle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Cycle \(cycle.cycleNumber)")
                    .font(.headline)

                Spacer()

                Text(cycle.dateRange)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Stats
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(cycle.goalsCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Goals")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(cycle.adherenceScore))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Adherence")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - ViewModel

@MainActor
class GoalsListViewModel: ObservableObject {
    @Published var activeGoals: [PatientGoal] = []
    @Published var pausedGoals: [PatientGoal] = []
    @Published var availableGoals: [PatientGoal] = []
    @Published var progressByGoal: [String: GoalProgress] = [:]
    @Published var pastCycles: [PatientCycle] = []
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    var goalsByPillar: [String: [PatientGoal]] {
        Dictionary(grouping: activeGoals) { $0.pillarId }
    }

    func loadData() async {
        guard let userId = try? await supabase.auth.session.user.id else { return }
        let patientId = userId.uuidString

        isLoading = true

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadGoals(patientId: patientId) }
            group.addTask { await self.loadAvailableGoals(patientId: patientId) }
            group.addTask { await self.loadPastCycles(patientId: patientId) }
        }

        isLoading = false
    }

    private func loadGoals(patientId: String) async {
        do {
            // Load both active and paused goals
            let goals: [PatientGoal] = try await supabase
                .from("patient_goals")
                .select("""
                    *,
                    sample_recommendation_types (
                        rec_type_id,
                        title,
                        description,
                        pillar,
                        category,
                        tracking_quantity_types,
                        target_unit,
                        frequency,
                        baseline_types,
                        biomarker_types,
                        impact_explanation,
                        entry_methods,
                        icon_name,
                        is_active
                    )
                """)
                .eq("patient_id", value: patientId)
                .in("status", values: ["active", "paused"])
                .order("assigned_at", ascending: false)
                .execute()
                .value

            self.activeGoals = goals.filter { $0.status == .active }
            self.pausedGoals = goals.filter { $0.status == .paused }

            // Load progress for active goals
            await loadProgress(for: activeGoals.map { $0.goalId }, patientId: patientId)
        } catch {
            print("[GoalsList] Error loading goals: \(error)")
        }
    }

    // Mapping from tracking type to sample type
    private static let trackingTypeToSampleType: [String: String] = [
        "steps": "steps",
        "cardio_duration": "cardio",
        "cardio_sessions": "cardio",
        "strength_duration": "strength_training",
        "strength_sessions": "strength_training",
        "hiit_duration": "hiit",
        "mobility_duration": "mobility",
        "protein_grams": "protein_grams",
        "vegetables_servings": "vegetables_servings",
        "fruits_servings": "fruits_servings",
        "legumes_servings": "legumes_servings",
        "whole_grains_servings": "whole_grains_servings",
        "nuts_seeds_servings": "nuts_seeds_servings",
        "water_ml": "water_ml",
        "sleep_duration": "sleep_duration"
    ]

    private let samplesService = PatientSamplesQueryService.shared

    private func loadProgress(for goalIds: [String], patientId: String) async {
        guard !goalIds.isEmpty else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: today)

        var progressMap: [String: GoalProgress] = [:]

        for goal in activeGoals {
            guard let recType = goal.sampleRecommendationTypes,
                  let trackingType = recType.trackingQuantityType else { continue }

            do {
                let actualValue = try await fetchActualValue(for: trackingType, frequency: recType.frequency ?? "daily", date: today)
                let progressPercentage = goal.targetValue > 0 ? min((actualValue / goal.targetValue) * 100, 100) : 0

                let status: ProgressStatus
                if progressPercentage >= 100 { status = .completed }
                else if progressPercentage >= 80 { status = .ahead }
                else if progressPercentage >= 50 { status = .onTrack }
                else if progressPercentage >= 25 { status = .atRisk }
                else { status = .behind }

                let progress = GoalProgress(
                    id: "\(goal.goalId)_\(dateStr)",
                    patientId: patientId,
                    goalId: goal.goalId,
                    progressDate: dateStr,
                    actualValue: actualValue,
                    targetValue: goal.targetValue,
                    progressPercentage: progressPercentage,
                    maxPotential: 100,
                    status: status,
                    aiInsight: nil,
                    periodType: (recType.frequency ?? "daily") == "weekly" ? "weekly" : "daily",
                    periodStart: nil,
                    periodEnd: nil,
                    dataSource: "patient_samples",
                    lastAssessedAt: ISO8601DateFormatter().string(from: Date())
                )
                progressMap[goal.goalId] = progress
            } catch {
                print("[GoalsList] Error loading progress for \(goal.goalId): \(error)")
            }
        }

        self.progressByGoal = progressMap
    }

    private func fetchActualValue(for trackingType: String, frequency: String, date: Date) async throws -> Double {
        let calendar = Calendar.current

        // Determine date range based on frequency
        let (startDate, endDate): (Date, Date)
        if frequency == "weekly" {
            // Get start of current week (Monday)
            let weekday = calendar.component(.weekday, from: date)
            let daysToSubtract = (weekday + 5) % 7
            let weekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: date)!
            startDate = weekStart
            endDate = date
        } else {
            startDate = date
            endDate = date
        }

        // Handle sleep specially
        if trackingType == "sleep_duration" {
            let sleepData = try await samplesService.fetchSleepDurationDaily(startDate: startDate, endDate: endDate)
            let totalMinutes = sleepData.reduce(0.0) { $0 + $1.value }
            return totalMinutes / 60.0  // Convert to hours
        }

        // Map tracking type to sample type
        guard let sampleType = Self.trackingTypeToSampleType[trackingType] else {
            return 0
        }

        let dailyValues = try await samplesService.fetchQuantityDaily(
            quantityType: sampleType,
            startDate: startDate,
            endDate: endDate
        )

        // For session-based goals, count entries
        if trackingType == "cardio_sessions" || trackingType == "strength_sessions" {
            return Double(dailyValues.reduce(0) { $0 + $1.count })
        }

        // For quantity goals, sum values
        return dailyValues.reduce(0.0) { $0 + $1.value }
    }

    private func loadAvailableGoals(patientId: String) async {
        // For now, return empty - this will be populated from patient_recommendations
        // that aren't in patient_goals
        // TODO: Implement when recommendation system is fully built
        self.availableGoals = []
    }

    private func loadPastCycles(patientId: String) async {
        do {
            let cycles: [PatientCycle] = try await supabase
                .from("patient_cycles")
                .select("*")
                .eq("patient_id", value: patientId)
                .not("completed_at", operator: .is, value: "null")
                .order("cycle_number", ascending: false)
                .execute()
                .value

            self.pastCycles = cycles
        } catch {
            print("[GoalsList] Error loading cycles: \(error)")
        }
    }

    func createChallengeFromGoal(_ goal: PatientGoal) async {
        // TODO: Create a 3-day challenge based on this goal
        print("[GoalsList] Creating challenge from goal: \(goal.title)")
    }

    func requestGoalActivation(_ goal: PatientGoal) async {
        // TODO: Create activation request for clinician
        print("[GoalsList] Requesting activation for goal: \(goal.title)")
    }

    func resumeGoal(_ goal: PatientGoal) async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        do {
            try await supabase
                .from("patient_goals")
                .update(["status": "active", "pause_reason": nil as String?])
                .eq("goal_id", value: goal.goalId)
                .execute()

            // Reload goals
            await loadGoals(patientId: userId.uuidString)
            print("[GoalsList] Goal resumed: \(goal.title)")
        } catch {
            print("[GoalsList] Error resuming goal: \(error)")
        }
    }
}

// MARK: - PatientCycle Model

struct PatientCycle: Codable, Identifiable {
    let id: String
    let patientId: String
    let cycleNumber: Int
    let phase: String?
    let startedAt: String?
    let completedAt: String?
    let targetDurationDays: Int?
    let retrospectiveData: CycleRetrospective?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case cycleNumber = "cycle_number"
        case phase
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case targetDurationDays = "target_duration_days"
        case retrospectiveData = "retrospective_data"
    }

    var dateRange: String {
        guard let start = startedAt, let end = completedAt else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM d"

        if let startDate = formatter.date(from: start),
           let endDate = formatter.date(from: end) {
            return "\(displayFormatter.string(from: startDate)) - \(displayFormatter.string(from: endDate))"
        }
        return ""
    }

    var goalsCount: Int {
        retrospectiveData?.goalsCount ?? 0
    }

    var adherenceScore: Double {
        retrospectiveData?.adherenceScore ?? 0
    }
}

struct CycleRetrospective: Codable {
    let goalsCount: Int?
    let adherenceScore: Double?
    let summary: String?

    enum CodingKeys: String, CodingKey {
        case goalsCount = "goals_count"
        case adherenceScore = "adherence_score"
        case summary
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GoalsListView()
    }
}
