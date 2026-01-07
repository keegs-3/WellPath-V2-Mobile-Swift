//
//  GoalsViewModel.swift
//  WellPath
//
//  ViewModel for the Goals tab - manages goals, progress, challenges, and nudges
//

import Foundation
import Combine

// MARK: - Journey State

enum PatientJourneyState: Equatable {
    case loading
    case baselineCollection(completed: Int, total: Int)
    case awaitingLabs
    case awaitingBiometrics
    case awaitingClinicianReview
    case activeGoals
}

// MARK: - Patient Status

struct PatientOnboardingStatus: Codable {
    let questionnaireComplete: Bool
    let biomarkersEntered: Bool
    let biometricsEntered: Bool
    let recommendationsGenerated: Bool

    enum CodingKeys: String, CodingKey {
        case questionnaireComplete = "questionnaire_complete"
        case biomarkersEntered = "biomarkers_entered"
        case biometricsEntered = "biometrics_entered"
        case recommendationsGenerated = "recommendations_generated"
    }
}

@MainActor
class GoalsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var journeyState: PatientJourneyState = .loading
    @Published var onboardingStatus: PatientOnboardingStatus?

    @Published var goals: [PatientGoal] = []
    @Published var progressByGoal: [String: GoalProgress] = [:]
    @Published var weeklyProgressByGoal: [String: GoalProgress] = [:]
    @Published var activeChallenge: PatientChallenge?
    @Published var recommendedChallengeCount: Int = 0

    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Computed Properties

    var activeGoals: [PatientGoal] {
        goals.filter { $0.status == .active }
    }

    var pausedGoals: [PatientGoal] {
        goals.filter { $0.status == .paused }
    }

    var goalsByPillar: [String: [PatientGoal]] {
        Dictionary(grouping: activeGoals) { $0.pillarId }
    }

    var dailyGoals: [PatientGoal] {
        activeGoals.filter { $0.isDaily }
    }

    var weeklyGoals: [PatientGoal] {
        activeGoals.filter { $0.isWeekly }
    }

    /// Overall weekly progress across all active goals (0-100)
    var overallWeeklyProgress: Double {
        guard !activeGoals.isEmpty else { return 0 }

        var totalProgress: Double = 0
        var count = 0

        for goal in activeGoals {
            if let progress = weeklyProgressByGoal[goal.goalId] ?? progressByGoal[goal.goalId] {
                totalProgress += progress.displayProgress
                count += 1
            }
        }

        guard count > 0 else { return 0 }
        return totalProgress / Double(count)
    }

    /// Overall max potential across all active goals (0-100)
    var overallMaxPotential: Double {
        guard !activeGoals.isEmpty else { return 100 }

        var totalMaxPotential: Double = 0
        var count = 0

        for goal in activeGoals {
            if let progress = weeklyProgressByGoal[goal.goalId] ?? progressByGoal[goal.goalId] {
                totalMaxPotential += progress.maxPotential ?? 100
                count += 1
            } else {
                // No progress data yet, assume max potential is 100%
                totalMaxPotential += 100
                count += 1
            }
        }

        guard count > 0 else { return 100 }
        return totalMaxPotential / Double(count)
    }

    // MARK: - Private

    private let supabase = SupabaseManager.shared.client
    private let samplesService = PatientSamplesQueryService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Tracking Type Mapping

    /// Maps goal template tracking_quantity_type to patient_quantity_samples quantity_type
    /// Maps goal tracking types to sample query types
    /// Updated 2026-01-05 to match sample_quantity_types
    private static let trackingTypeToSampleType: [String: String] = [
        // Movement
        "steps": "steps",
        "cardio_duration": "cardio",
        "cardio_sessions": "cardio",
        "strength_duration": "strength_training",
        "strength_sessions": "strength_training",
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
        "ultra_processed_servings": "ultra_processed_servings",

        // Sleep - special handling
        "sleep_duration": "sleep_duration",
        "sleep_duration_hours": "sleep_duration",
        "in_bed_start": "in_bed_start",
        "in_bed_end": "in_bed_end"
    ]

    // MARK: - Load Data

    func loadGoals() async {
        guard let userId = try? await supabase.auth.session.user.id else {
            error = "Not logged in"
            return
        }
        let patientId = userId.uuidString

        isLoading = true
        journeyState = .loading
        error = nil

        // First, load patient onboarding status to determine journey state
        await loadJourneyStatus(patientId: patientId)

        do {
            // Fetch goals with recommendation types (active and paused)
            let goalsResponse: [PatientGoal] = try await supabase
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
                        biometric_types,
                        impact_explanation,
                        evidence_summary,
                        entry_methods,
                        icon_name,
                        color_hex,
                        is_active
                    )
                """)
                .eq("patient_id", value: patientId)
                .in("status", values: ["active", "paused"])
                .order("assigned_at", ascending: false)
                .execute()
                .value

            self.goals = goalsResponse

            // Fetch today's progress for each goal
            await loadProgress(for: goalsResponse.map { $0.goalId }, patientId: patientId)

            // Fetch weekly progress for overall adherence
            await loadWeeklyProgress(for: goalsResponse.map { $0.goalId }, patientId: patientId)

            // Fetch active challenge and recommended count
            await loadActiveChallenge(patientId: patientId)
            await loadRecommendedChallengeCount(patientId: patientId)

        } catch {
            self.error = error.localizedDescription
            print("[Goals] Error loading goals: \(error)")
        }

        isLoading = false
    }

    private func loadJourneyStatus(patientId: String) async {
        do {
            // Fetch patient onboarding status
            let statusResponse: [PatientOnboardingStatus] = try await supabase
                .from("patients")
                .select("questionnaire_complete, biomarkers_entered, biometrics_entered, recommendations_generated")
                .eq("patient_id", value: patientId)
                .limit(1)
                .execute()
                .value

            guard let status = statusResponse.first else {
                journeyState = .baselineCollection(completed: 0, total: 7)
                return
            }

            self.onboardingStatus = status

            // Determine journey state based on status flags
            if status.recommendationsGenerated {
                // Clinician has generated recommendations - show active goals
                journeyState = .activeGoals
            } else if !status.questionnaireComplete {
                // Still collecting baseline questionnaires
                // Count actual completed baselines
                let baselineProgress = await loadBaselineProgress(patientId: patientId)
                journeyState = .baselineCollection(completed: baselineProgress.completed, total: baselineProgress.total)
            } else if !status.biomarkersEntered {
                // Baselines done, waiting for lab results
                journeyState = .awaitingLabs
            } else if !status.biometricsEntered {
                // Labs done, waiting for biometric screening
                journeyState = .awaitingBiometrics
            } else {
                // All data in, waiting for clinician to generate recommendations
                journeyState = .awaitingClinicianReview
            }

        } catch {
            print("[Goals] Error loading journey status: \(error)")
            // Default to showing goals view on error
            journeyState = .activeGoals
        }
    }

    private func loadBaselineProgress(patientId: String) async -> (completed: Int, total: Int) {
        do {
            // Get all baseline categories from baseline_questions
            struct CategoryInfo: Decodable {
                let categoryId: String?
                let baselineType: String?

                enum CodingKeys: String, CodingKey {
                    case categoryId = "category_id"
                    case baselineType = "baseline_type"
                }
            }

            let questions: [CategoryInfo] = try await supabase
                .from("baseline_questions")
                .select("category_id, baseline_type")
                .eq("is_active", value: true)
                .execute()
                .value

            // Get unique categories
            let categories = Set(questions.compactMap { $0.categoryId })
            let total = categories.count

            // Get completed baselines for this patient
            struct CompletedBaseline: Decodable {
                let baselineType: String

                enum CodingKeys: String, CodingKey {
                    case baselineType = "baseline_type"
                }
            }

            let completedBaselines: [CompletedBaseline] = try await supabase
                .from("patient_baseline_samples")
                .select("baseline_type")
                .eq("patient_id", value: patientId)
                .eq("is_current", value: true)
                .execute()
                .value

            let completedTypes = Set(completedBaselines.map { $0.baselineType })

            // Count categories where all baselines are complete
            var completedCategories = 0
            for categoryId in categories {
                let categoryBaselineTypes = questions
                    .filter { $0.categoryId == categoryId }
                    .compactMap { $0.baselineType }

                if !categoryBaselineTypes.isEmpty && categoryBaselineTypes.allSatisfy({ completedTypes.contains($0) }) {
                    completedCategories += 1
                }
            }

            return (completed: completedCategories, total: max(total, 1))

        } catch {
            print("[Goals] Error loading baseline progress: \(error)")
            return (completed: 0, total: 7)
        }
    }

    private func loadProgress(for goalIds: [String], patientId: String) async {
        guard !goalIds.isEmpty else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var progressMap: [String: GoalProgress] = [:]

        for goal in goals {
            guard let template = goal.template,
                  let trackingType = template.trackingQuantityType else { continue }

            do {
                let actualValue = try await fetchActualValue(
                    for: trackingType,
                    frequency: template.frequency ?? "daily",
                    date: today
                )

                let progress = calculateProgress(
                    actualValue: actualValue,
                    targetValue: goal.targetValue,
                    goalId: goal.goalId,
                    patientId: patientId,
                    date: today,
                    periodType: (template.frequency ?? "daily") == "weekly" ? "weekly" : "daily"
                )

                progressMap[goal.goalId] = progress

            } catch {
                print("[Goals] Error loading progress for \(goal.goalId): \(error)")
            }
        }

        self.progressByGoal = progressMap
    }

    /// Fetches the actual tracked value from patient sample tables
    private func fetchActualValue(for trackingType: String, frequency: String, date: Date) async throws -> Double {
        let calendar = Calendar.current

        // Determine date range based on frequency
        let (startDate, endDate): (Date, Date)
        if frequency == "weekly" {
            // Get start of current week (Monday) - ISO 8601 week
            // Sunday=1, Monday=2, ..., Saturday=7
            let weekday = calendar.component(.weekday, from: date)
            let daysToSubtract = (weekday + 5) % 7  // Mon=0, Tue=1, ..., Sun=6
            let weekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: date)!
            startDate = weekStart
            endDate = date
        } else {
            // Daily - just today
            startDate = date
            endDate = date
        }

        // Handle sleep specially - uses sleep summary view
        if trackingType == "sleep_duration" || trackingType == "sleep_duration_hours" {
            let sleepData = try await samplesService.fetchSleepDurationDaily(
                startDate: startDate,
                endDate: endDate
            )
            // Convert total minutes to hours
            let totalMinutes = sleepData.reduce(0.0) { $0 + $1.value }
            return totalMinutes / 60.0
        }

        // Map tracking type to sample type
        guard let sampleType = Self.trackingTypeToSampleType[trackingType] else {
            print("[Goals] Unknown tracking type: \(trackingType)")
            return 0
        }

        // Fetch from patient_quantity_samples
        let dailyValues = try await samplesService.fetchQuantityDaily(
            quantityType: sampleType,
            startDate: startDate,
            endDate: endDate
        )

        // For session-based goals (cardio, strength), count entries
        if trackingType == "cardio_sessions" || trackingType == "strength_sessions" {
            // Each entry is one session
            return Double(dailyValues.reduce(0) { $0 + $1.count })
        }

        // For quantity goals (protein, steps), sum values
        return dailyValues.reduce(0.0) { $0 + $1.value }
    }

    /// Simple progress calculation for daily view (today's progress only)
    private func calculateProgress(
        actualValue: Double,
        targetValue: Double,
        goalId: String,
        patientId: String,
        date: Date,
        periodType: String
    ) -> GoalProgress {
        let progressPercentage = targetValue > 0 ? min((actualValue / targetValue) * 100, 100) : 0

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: date)

        let status: ProgressStatus
        if progressPercentage >= 100 { status = .completed }
        else if progressPercentage >= 80 { status = .ahead }
        else if progressPercentage >= 50 { status = .onTrack }
        else if progressPercentage >= 25 { status = .atRisk }
        else { status = .behind }

        return GoalProgress(
            id: "\(goalId)_\(dateStr)",
            patientId: patientId,
            goalId: goalId,
            progressDate: dateStr,
            actualValue: actualValue,
            targetValue: targetValue,
            progressPercentage: progressPercentage,
            maxPotential: 100,
            status: status,
            aiInsight: nil,
            periodType: periodType,
            periodStart: nil,
            periodEnd: nil,
            dataSource: "patient_samples",
            lastAssessedAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    /// Creates a GoalProgress object using weekly adherence formula
    /// - Daily goals: progress = (days_elapsed/7) × avg_daily_completion
    /// - Weekly goals: progress = sessions_completed / target_sessions
    private func calculateWeeklyAdherence(
        goal: PatientGoal,
        dailyCompletions: [Double], // Array of daily completion percentages (0-1) for days with data
        daysElapsed: Int,
        patientId: String,
        weekStart: Date
    ) -> GoalProgress {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: weekStart)

        let daysRemaining = 7 - daysElapsed
        let progressPercentage: Double
        let maxPotential: Double

        if goal.isDaily {
            // Daily goal (e.g., 10k steps/day)
            // Progress = (days_elapsed / 7) × average_daily_completion
            let avgCompletion = dailyCompletions.isEmpty ? 0 : dailyCompletions.reduce(0, +) / Double(dailyCompletions.count)
            progressPercentage = (Double(daysElapsed) / 7.0) * avgCompletion * 100

            // Max potential = (days_remaining / 7 × 100%) + (days_elapsed / 7 × avg_completion)
            maxPotential = ((Double(daysRemaining) / 7.0) * 100) + ((Double(daysElapsed) / 7.0) * avgCompletion * 100)
        } else {
            // Weekly goal (e.g., 3 strength sessions/week)
            // Progress = sessions_completed / target_sessions
            let sessionsCompleted = dailyCompletions.reduce(0, +) // Sum of sessions
            progressPercentage = goal.targetValue > 0 ? min((sessionsCompleted / goal.targetValue) * 100, 100) : 0

            // Max potential = can we still hit the target?
            // Assume 1 session per remaining day is possible
            let maxSessions = min(sessionsCompleted + Double(daysRemaining), goal.targetValue)
            maxPotential = goal.targetValue > 0 ? (maxSessions / goal.targetValue) * 100 : 100
        }

        // Determine status based on progress
        let status: ProgressStatus
        if progressPercentage >= 100 {
            status = .completed
        } else if progressPercentage >= 80 {
            status = .ahead
        } else if progressPercentage >= 50 {
            status = .onTrack
        } else if progressPercentage >= 25 {
            status = .atRisk
        } else {
            status = .behind
        }

        return GoalProgress(
            id: "\(goal.goalId)_\(dateStr)",
            patientId: patientId,
            goalId: goal.goalId,
            progressDate: dateStr,
            actualValue: dailyCompletions.reduce(0, +),
            targetValue: goal.targetValue,
            progressPercentage: min(progressPercentage, 100),
            maxPotential: min(maxPotential, 100),
            status: status,
            aiInsight: nil,
            periodType: goal.isDaily ? "daily" : "weekly",
            periodStart: nil,
            periodEnd: nil,
            dataSource: "patient_samples",
            lastAssessedAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    private func loadWeeklyProgress(for goalIds: [String], patientId: String) async {
        guard !goalIds.isEmpty else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Get start of current week (Monday) - ISO 8601 week
        // Sunday=1, Monday=2, ..., Saturday=7
        let weekday = calendar.component(.weekday, from: today)
        let daysToSubtract = (weekday + 5) % 7  // Mon=0, Tue=1, ..., Sun=6
        guard let weekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) else {
            return
        }

        // Days elapsed this week (1 = Monday only, 7 = Mon-Sun complete)
        let daysElapsed = daysToSubtract + 1

        var progressMap: [String: GoalProgress] = [:]

        for goal in goals {
            guard let template = goal.template,
                  let trackingType = template.trackingQuantityType else { continue }

            do {
                var dailyCompletions: [Double] = []

                if goal.isDaily {
                    // Daily goal: get completion for each day
                    for dayOffset in 0..<daysElapsed {
                        guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }

                        let dailyValue = try await fetchActualValue(
                            for: trackingType,
                            frequency: "daily",
                            date: dayDate
                        )

                        // Daily completion as fraction (0-1)
                        let dailyCompletion = goal.targetValue > 0 ? min(dailyValue / goal.targetValue, 1.0) : 0
                        dailyCompletions.append(dailyCompletion)
                    }
                } else {
                    // Weekly goal: count sessions completed
                    let totalSessions = try await fetchActualValue(
                        for: trackingType,
                        frequency: "weekly",
                        date: today
                    )
                    dailyCompletions = [totalSessions] // Store raw count for weekly goals
                }

                let progress = calculateWeeklyAdherence(
                    goal: goal,
                    dailyCompletions: dailyCompletions,
                    daysElapsed: daysElapsed,
                    patientId: patientId,
                    weekStart: weekStart
                )

                progressMap[goal.goalId] = progress

            } catch {
                print("[Goals] Error loading weekly progress for \(goal.goalId): \(error)")
            }
        }

        self.weeklyProgressByGoal = progressMap
    }

    private func loadActiveChallenge(patientId: String) async {
        do {
            let challenges: [PatientChallenge] = try await supabase
                .from("patient_challenges")
                .select("*")
                .eq("patient_id", value: patientId)
                .eq("status", value: "active")
                .order("start_date", ascending: false)
                .limit(1)
                .execute()
                .value

            self.activeChallenge = challenges.first

        } catch {
            print("[Goals] Error loading challenge: \(error)")
        }
    }

    private func loadRecommendedChallengeCount(patientId: String) async {
        do {
            // Count suggested challenges
            struct CountResult: Decodable {
                let count: Int
            }

            let challenges: [PatientChallenge] = try await supabase
                .from("patient_challenges")
                .select("challenge_id")
                .eq("patient_id", value: patientId)
                .eq("status", value: "suggested")
                .execute()
                .value

            self.recommendedChallengeCount = challenges.count

        } catch {
            print("[Goals] Error loading recommended challenge count: \(error)")
        }
    }

    // MARK: - Quick Entry

    func logQuickEntry(goalId: String, value: Double) async -> Bool {
        guard let userId = try? await supabase.auth.session.user.id else { return false }

        // Find the goal to get its tracking type
        guard let goal = goals.first(where: { $0.goalId == goalId }),
              let template = goal.template,
              let trackingType = template.trackingQuantityType,
              let sampleType = Self.trackingTypeToSampleType[trackingType] else {
            print("[Goals] Could not find tracking type for goal: \(goalId)")
            return false
        }

        let now = Date()
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let nowStr = isoFormatter.string(from: now)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: now)

        let timezone = TimeZone.current.identifier

        do {
            // Insert into patient_quantity_samples (same table as other metrics)
            try await supabase
                .from("patient_quantity_samples")
                .insert([
                    "patient_id": userId.uuidString,
                    "quantity_type": sampleType,
                    "quantity_value": String(value),
                    "quantity_unit": goal.targetUnit,
                    "start_time": nowStr,
                    "end_time": nowStr,
                    "source": "manual",
                    "user_timezone": timezone,
                    "aggregation_date": today,
                    "is_primary": "true"
                ])
                .execute()

            // Reload progress to reflect new data
            await loadProgress(for: [goalId], patientId: userId.uuidString)
            await loadWeeklyProgress(for: [goalId], patientId: userId.uuidString)

            return true

        } catch {
            print("[Goals] Error logging quick entry: \(error)")
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Helpers

    func progress(for goalId: String) -> GoalProgress? {
        progressByGoal[goalId]
    }

    func progressPercentage(for goalId: String) -> Double {
        progressByGoal[goalId]?.displayProgress ?? 0
    }

    func actualValue(for goalId: String) -> Double {
        progressByGoal[goalId]?.displayActual ?? 0
    }
}
