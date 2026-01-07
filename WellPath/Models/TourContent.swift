//
//  TourContent.swift
//  WellPath
//
//  Models for database-driven tour content
//

import Foundation

// MARK: - Tour Content Model

/// Represents a single tour step from the database
struct TourContent: Codable, Identifiable {
    let id: String
    let contentKey: String
    let section: TourSection
    let stepOrder: Int
    let chironMessage: String
    let chironSubtext: String?
    let screenType: TourScreenType
    let highlightElements: [HighlightElement]?
    let tapTarget: String?
    let tapDestination: String?
    let allowDeepNavigation: Bool
    let demoDataKey: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case contentKey = "content_key"
        case section
        case stepOrder = "step_order"
        case chironMessage = "chiron_message"
        case chironSubtext = "chiron_subtext"
        case screenType = "screen_type"
        case highlightElements = "highlight_elements"
        case tapTarget = "tap_target"
        case tapDestination = "tap_destination"
        case allowDeepNavigation = "allow_deep_navigation"
        case demoDataKey = "demo_data_key"
        case isActive = "is_active"
    }
}

/// Tour sections matching database schema
enum TourSection: String, Codable, CaseIterable {
    case welcome
    case navigation
    case goals
    case score
    case data
    case onboarding
    case wrapup
}

/// Screen types for different tour displays
enum TourScreenType: String, Codable {
    case custom = "custom"
    case realGoals = "real_goals"
    case realScore = "real_score"
    case realData = "real_data"
}

/// UI element to highlight during a tour step
struct HighlightElement: Codable {
    let type: String  // tab, component, button, tab_bar
    let id: String?   // Optional - some elements like tab_bar don't need an id
}

// MARK: - Demo Data Model

/// Sample data for tour demonstrations
struct TourDemoData: Codable, Identifiable {
    let id: String
    let dataKey: String
    let dataType: String
    let demoContent: TourDemoContent
    let description: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case dataKey = "data_key"
        case dataType = "data_type"
        case demoContent = "demo_content"
        case description
        case isActive = "is_active"
    }
}

/// Union type for different demo content structures
enum TourDemoContent: Codable {
    case goals(TourDemoGoalsContent)
    case score(TourDemoScoreContent)
    case pillars(TourDemoPillarsContent)
    case nudges(TourDemoNudgesContent)
    case challenges(TourDemoChallengesContent)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Try each type in order
        if let goals = try? container.decode(TourDemoGoalsContent.self) {
            self = .goals(goals)
        } else if let score = try? container.decode(TourDemoScoreContent.self) {
            self = .score(score)
        } else if let pillars = try? container.decode(TourDemoPillarsContent.self) {
            self = .pillars(pillars)
        } else if let nudges = try? container.decode(TourDemoNudgesContent.self) {
            self = .nudges(nudges)
        } else if let challenges = try? container.decode(TourDemoChallengesContent.self) {
            self = .challenges(challenges)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown demo content type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .goals(let content): try container.encode(content)
        case .score(let content): try container.encode(content)
        case .pillars(let content): try container.encode(content)
        case .nudges(let content): try container.encode(content)
        case .challenges(let content): try container.encode(content)
        }
    }
}

// MARK: - Tour Demo Content Types
// Note: These use "Tour" prefix to avoid conflicts with DemoDataFixtures.swift

struct TourDemoGoalsContent: Codable {
    let goals: [TourDemoGoal]
    let adherence: TourDemoAdherence
}

struct TourDemoGoal: Codable, Identifiable {
    let id: String
    let displayName: String
    let icon: String
    let pillar: String
    let targetValue: Double
    let unit: String
    let frequency: String
    let currentValue: Double
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case icon
        case pillar
        case targetValue = "target_value"
        case unit
        case frequency
        case currentValue = "current_value"
        case status
    }
}

struct TourDemoAdherence: Codable {
    let currentPercentage: Int
    let maxPossible: Int
    let weekStart: String
    let daysCompleted: Int
    let daysTotal: Int

    enum CodingKeys: String, CodingKey {
        case currentPercentage = "current_percentage"
        case maxPossible = "max_possible"
        case weekStart = "week_start"
        case daysCompleted = "days_completed"
        case daysTotal = "days_total"
    }
}

struct TourDemoScoreContent: Codable {
    let score: Int
    let trend: String
    let previousScore: Int
    let breakdown: TourDemoScoreBreakdown
    let lastUpdated: String

    enum CodingKeys: String, CodingKey {
        case score
        case trend
        case previousScore = "previous_score"
        case breakdown
        case lastUpdated = "last_updated"
    }
}

struct TourDemoScoreBreakdown: Codable {
    let biomarkers: TourDemoBreakdownComponent
    let surveys: TourDemoBreakdownComponent
    let education: TourDemoBreakdownComponent
}

struct TourDemoBreakdownComponent: Codable {
    let weight: Double
    let score: Int
}

struct TourDemoPillarsContent: Codable {
    let pillars: [TourDemoPillar]
}

struct TourDemoPillar: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: String
    let score: Int
    let components: [TourDemoPillarComponent]
}

struct TourDemoPillarComponent: Codable {
    let name: String
    let score: Int
}

struct TourDemoNudgesContent: Codable {
    let nudges: [TourDemoNudge]
}

struct TourDemoNudge: Codable, Identifiable {
    let id: String
    let type: String
    let tone: String
    let message: String
    let icon: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case tone
        case message
        case icon
        case createdAt = "created_at"
    }
}

struct TourDemoChallengesContent: Codable {
    let challenges: [TourDemoChallenge]
    let history: [TourDemoPastChallenge]
}

struct TourDemoChallenge: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let durationDays: Int
    let currentDay: Int
    let dailyProgress: [Bool?]
    let targetValue: Int
    let relatedGoalId: String
    let rationale: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case icon
        case durationDays = "duration_days"
        case currentDay = "current_day"
        case dailyProgress = "daily_progress"
        case targetValue = "target_value"
        case relatedGoalId = "related_goal_id"
        case rationale
        case status
    }
}

struct TourDemoPastChallenge: Codable, Identifiable {
    let id: String
    let title: String
    let completedDays: Int
    let totalDays: Int
    let status: String
    let completedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case completedDays = "completed_days"
        case totalDays = "total_days"
        case status
        case completedAt = "completed_at"
    }
}

// MARK: - Chiron Content Model

/// Reusable Chiron messages from the database
struct ChironContent: Codable, Identifiable {
    let id: String
    let contentKey: String
    let contentType: String
    let category: String?
    let message: String
    let subtext: String?
    let triggerConditions: [String: String]?
    let isActive: Bool
    let priority: Int

    enum CodingKeys: String, CodingKey {
        case id
        case contentKey = "content_key"
        case contentType = "content_type"
        case category
        case message
        case subtext
        case triggerConditions = "trigger_conditions"
        case isActive = "is_active"
        case priority
    }
}

// MARK: - Challenge Content Model

/// Educational content for challenges
struct ChallengeContent: Codable, Identifiable {
    let id: String
    let challengeType: String
    let whyTitle: String
    let whyDescription: String
    let tips: [String]
    let completionMessage: String?
    let partialCompletionMessage: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case challengeType = "challenge_type"
        case whyTitle = "why_title"
        case whyDescription = "why_description"
        case tips
        case completionMessage = "completion_message"
        case partialCompletionMessage = "partial_completion_message"
        case isActive = "is_active"
    }
}
