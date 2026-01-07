//
//  GoalModels.swift
//  WellPath
//
//  Models for the Goals system
//

import Foundation

// MARK: - Recommendation Type (from sample_recommendation_types)
// This is the catalog of all goal/recommendation types the agent can suggest

struct RecommendationType: Codable, Identifiable {
    let recTypeId: String
    let title: String
    let description: String
    let pillar: String
    let category: String?
    let trackingQuantityTypes: [String]?
    let targetUnit: String?
    let frequency: String?
    let baselineTypes: [String]?
    let biomarkerTypes: [String]?
    let biometricTypes: [String]?
    let impactExplanation: String?
    let evidenceSummary: String?
    let targetCalculation: String?
    let entryMethods: EntryMethodsConfig?
    let progressionTiers: [ProgressionTier]?
    let iconName: String?
    let colorHex: String?
    let isActive: Bool?

    var id: String { recTypeId }

    // Convenience accessors for compatibility
    var trackingQuantityType: String? { trackingQuantityTypes?.first }
    var pillarId: String {
        // Map pillar display names to IDs
        switch pillar {
        case "Movement + Exercise": return "movement"
        case "Healthful Nutrition": return "nutrition"
        case "Restorative Sleep": return "sleep"
        case "Stress Management": return "stress"
        case "Connection + Purpose": return "connection"
        case "Cognitive Health": return "cognitive"
        case "Core Care": return "core"
        default: return pillar.lowercased()
        }
    }

    enum CodingKeys: String, CodingKey {
        case recTypeId = "rec_type_id"
        case title
        case description
        case pillar
        case category
        case trackingQuantityTypes = "tracking_quantity_types"
        case targetUnit = "target_unit"
        case frequency
        case baselineTypes = "baseline_types"
        case biomarkerTypes = "biomarker_types"
        case biometricTypes = "biometric_types"
        case impactExplanation = "impact_explanation"
        case evidenceSummary = "evidence_summary"
        case targetCalculation = "target_calculation"
        case entryMethods = "entry_methods"
        case progressionTiers = "progression_tiers"
        case iconName = "icon_name"
        case colorHex = "color_hex"
        case isActive = "is_active"
    }
}

struct EntryMethodsConfig: Codable {
    let primary: String?
    let alternatives: [String]?
}

struct ProgressionTier: Codable {
    let tier: Int?
    let target: Double?
    let description: String?
}

// MARK: - Legacy GoalTemplate alias for compatibility
// TODO: Remove once all code migrated to RecommendationType
typealias GoalTemplate = RecommendationType

struct QuickEntryConfig: Codable {
    let min: Double?
    let max: Double?
    let step: Double?
    let unit: String?
    let label: String?
    let values: [String: Int]?
}

// MARK: - Patient Goal

struct PatientGoal: Codable, Identifiable {
    let goalId: String
    let patientId: String
    let recTypeId: String?
    let targetValue: Double
    let targetUnit: String
    let targetFrequency: String
    let aiRationale: String?
    let aiTips: [String]?
    let trackingMode: String
    let status: GoalStatus
    let pauseReason: String?
    let cycleStart: String
    let cycleEnd: String?
    let assignedAt: String

    // Joined recommendation type data (from sample_recommendation_types)
    let sampleRecommendationTypes: RecommendationType?

    var id: String { goalId }

    /// The recommendation type this goal is based on
    var recommendationType: RecommendationType? { sampleRecommendationTypes }

    /// Legacy accessor for compatibility
    var template: RecommendationType? { sampleRecommendationTypes }

    var title: String {
        sampleRecommendationTypes?.title ?? "Goal"
    }

    /// Short title for compact displays (e.g., "Protein" instead of "Daily Protein Target")
    var shortTitle: String {
        let fullTitle = title
        // Common simplifications
        let replacements = [
            "Daily ": "",
            "Weekly ": "",
            " Target": "",
            " Sessions": "",
            " Duration": ""
        ]
        var short = fullTitle
        for (pattern, replacement) in replacements {
            short = short.replacingOccurrences(of: pattern, with: replacement)
        }
        // Truncate if still too long
        if short.count > 10 {
            return String(short.prefix(8)) + "..."
        }
        return short
    }

    var pillarId: String {
        sampleRecommendationTypes?.pillarId ?? "unknown"
    }

    var isDaily: Bool {
        sampleRecommendationTypes?.frequency == "daily"
    }

    var isWeekly: Bool {
        sampleRecommendationTypes?.frequency == "weekly"
    }

    enum CodingKeys: String, CodingKey {
        case goalId = "goal_id"
        case patientId = "patient_id"
        case recTypeId = "rec_type_id"
        case targetValue = "target_value"
        case targetUnit = "target_unit"
        case targetFrequency = "target_frequency"
        case aiRationale = "ai_rationale"
        case aiTips = "ai_tips"
        case trackingMode = "tracking_mode"
        case status
        case pauseReason = "pause_reason"
        case cycleStart = "cycle_start"
        case cycleEnd = "cycle_end"
        case assignedAt = "assigned_at"
        case sampleRecommendationTypes = "sample_recommendation_types"
    }
}

enum GoalStatus: String, Codable {
    case active
    case paused
    case completed
    case abandoned
}

// MARK: - Goal Progress

struct GoalProgress: Codable, Identifiable {
    let id: String
    let patientId: String
    let goalId: String
    let progressDate: String
    let actualValue: Double?
    let targetValue: Double
    let progressPercentage: Double?
    let maxPotential: Double?
    let status: ProgressStatus?
    let aiInsight: String?
    let periodType: String?
    let periodStart: String?
    let periodEnd: String?
    let dataSource: String?
    let lastAssessedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case goalId = "goal_id"
        case progressDate = "progress_date"
        case actualValue = "actual_value"
        case targetValue = "target_value"
        case progressPercentage = "progress_percentage"
        case maxPotential = "max_potential"
        case status
        case aiInsight = "ai_insight"
        case periodType = "period_type"
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case dataSource = "data_source"
        case lastAssessedAt = "last_assessed_at"
    }

    var displayProgress: Double {
        progressPercentage ?? 0
    }

    var displayActual: Double {
        actualValue ?? 0
    }
}

enum ProgressStatus: String, Codable {
    case ahead
    case onTrack = "on_track"
    case atRisk = "at_risk"
    case behind
    case completed
}

// MARK: - Quick Entry

struct GoalQuickEntry: Codable, Identifiable {
    let id: String
    let patientId: String
    let goalId: String
    let entryDate: String
    let entryTime: String
    let value: Double
    let entryType: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case goalId = "goal_id"
        case entryDate = "entry_date"
        case entryTime = "entry_time"
        case value
        case entryType = "entry_type"
        case notes
    }
}

// MARK: - Challenge

struct PatientChallenge: Codable, Identifiable {
    let challengeId: String
    let patientId: String
    let goalId: String?
    let title: String
    let description: String?
    let challengeType: String?
    let targetValue: Double?
    let targetMetric: String?
    let durationDays: Int?
    let currentValue: Double?
    let progressPercentage: Double?
    let status: ChallengeStatus
    let startDate: String
    let endDate: String
    let completedAt: String?
    let aiRationale: String?
    let difficultyLevel: Int?
    let challengeRationale: ChallengeRationale?
    let suggestedTemplateId: String?
    let skipReason: String?
    let skippedAt: String?
    let recTypeId: String?

    var id: String { challengeId }

    enum CodingKeys: String, CodingKey {
        case challengeId = "challenge_id"
        case patientId = "patient_id"
        case goalId = "goal_id"
        case title
        case description
        case challengeType = "challenge_type"
        case targetValue = "target_value"
        case targetMetric = "target_metric"
        case durationDays = "duration_days"
        case currentValue = "current_value"
        case progressPercentage = "progress_percentage"
        case status
        case startDate = "start_date"
        case endDate = "end_date"
        case completedAt = "completed_at"
        case aiRationale = "ai_rationale"
        case difficultyLevel = "difficulty_level"
        case challengeRationale = "challenge_rationale"
        case suggestedTemplateId = "suggested_template_id"
        case skipReason = "skip_reason"
        case skippedAt = "skipped_at"
        case recTypeId = "rec_type_id"
    }

    var displayProgress: Double {
        progressPercentage ?? 0
    }

    var daysRemaining: Int {
        guard let end = ISO8601DateFormatter().date(from: endDate + "T00:00:00Z") else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: end).day ?? 0
        return max(0, days)
    }

    var daysCompleted: Int {
        guard let duration = durationDays else { return 0 }
        return duration - daysRemaining
    }
}

enum ChallengeStatus: String, Codable {
    case suggested  // Chiron proposed, awaiting patient
    case active
    case completed
    case failed
    case skipped    // Patient declined
    case abandoned
}

enum ChallengeSkipReason: String, Codable, CaseIterable {
    case notNow = "not_now"
    case notRelevant = "not_relevant"
    case tooHard = "too_hard"
    case other

    var displayName: String {
        switch self {
        case .notNow: return "Not right now"
        case .notRelevant: return "Not relevant to me"
        case .tooHard: return "Too challenging"
        case .other: return "Other reason"
        }
    }
}

enum ChallengeRationale: String, Codable {
    case recovery   // Patient struggling - reduced target
    case growth     // Patient succeeding - stretch target
    case expansion  // Patient maxed out - new complementary goal
}

// MARK: - Coach Nudge

struct CoachNudge: Codable, Identifiable {
    let nudgeId: String
    let patientId: String
    let goalId: String?
    let title: String
    let message: String
    let tone: String?
    let nudgeType: String?
    let scheduledFor: String?
    let deliveredAt: String?
    let readAt: String?
    let deliveryChannel: String?
    let userResponse: String?
    let createdAt: String

    var id: String { nudgeId }

    enum CodingKeys: String, CodingKey {
        case nudgeId = "nudge_id"
        case patientId = "patient_id"
        case goalId = "goal_id"
        case title
        case message
        case tone
        case nudgeType = "nudge_type"
        case scheduledFor = "scheduled_for"
        case deliveredAt = "delivered_at"
        case readAt = "read_at"
        case deliveryChannel = "delivery_channel"
        case userResponse = "user_response"
        case createdAt = "created_at"
    }

    var isRead: Bool {
        readAt != nil
    }
}

// MARK: - Patient Goal Settings

struct PatientGoalSettings: Codable {
    let patientId: UUID
    let nutritionEntryMode: NutritionEntryMode
    let movementEntryMode: MovementEntryMode
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case nutritionEntryMode = "nutrition_entry_mode"
        case movementEntryMode = "movement_entry_mode"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        patientId: UUID,
        nutritionEntryMode: NutritionEntryMode = .foodLog,
        movementEntryMode: MovementEntryMode = .auto,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.patientId = patientId
        self.nutritionEntryMode = nutritionEntryMode
        self.movementEntryMode = movementEntryMode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum NutritionEntryMode: String, Codable, CaseIterable {
    case foodLog = "food_log"   // Full food logging wizard (most detailed)
    case quick                   // Quick entry with time/amount/type
    case simple                  // Just amount (simplest)

    var displayName: String {
        switch self {
        case .foodLog: return "Detailed Food Log"
        case .quick: return "Quick Entry"
        case .simple: return "Simple Entry"
        }
    }

    var description: String {
        switch self {
        case .foodLog: return "Log full meals with ingredients, timing, and photos"
        case .quick: return "Log protein with time, amount, and type"
        case .simple: return "Just enter grams - quick and easy"
        }
    }

    var icon: String {
        switch self {
        case .foodLog: return "list.bullet.clipboard"
        case .quick: return "bolt.fill"
        case .simple: return "checkmark.circle"
        }
    }
}

enum MovementEntryMode: String, Codable, CaseIterable {
    case auto       // HealthKit syncs automatically
    case manual     // Manual entry only

    var displayName: String {
        switch self {
        case .auto: return "Automatic (Apple Health)"
        case .manual: return "Manual Entry"
        }
    }

    var description: String {
        switch self {
        case .auto: return "Steps and workouts sync from Apple Health"
        case .manual: return "Log workouts and activity manually"
        }
    }

    var icon: String {
        switch self {
        case .auto: return "applewatch"
        case .manual: return "hand.tap"
        }
    }
}

// MARK: - Pillar Helper

enum HealthPillar: String, CaseIterable {
    case movement
    case nutrition
    case sleep
    case stress
    case connection
    case cognitive
    case core

    var displayName: String {
        switch self {
        case .movement: return "Movement & Exercise"
        case .nutrition: return "Healthful Nutrition"
        case .sleep: return "Restorative Sleep"
        case .stress: return "Stress Management"
        case .connection: return "Connection & Purpose"
        case .cognitive: return "Cognitive Health"
        case .core: return "Core Care"
        }
    }

    var color: String {
        switch self {
        case .movement: return "#4ECDC4"    // Teal
        case .nutrition: return "#95E879"   // Green
        case .sleep: return "#7B68EE"       // Purple
        case .stress: return "#FFB347"      // Orange
        case .connection: return "#FF6B9D"  // Pink
        case .cognitive: return "#64B5F6"   // Blue
        case .core: return "#A0A0A0"        // Gray
        }
    }

    var icon: String {
        switch self {
        case .movement: return "figure.run"
        case .nutrition: return "leaf.fill"
        case .sleep: return "moon.fill"
        case .stress: return "brain.head.profile"
        case .connection: return "heart.fill"
        case .cognitive: return "lightbulb.fill"
        case .core: return "cross.fill"
        }
    }
}
