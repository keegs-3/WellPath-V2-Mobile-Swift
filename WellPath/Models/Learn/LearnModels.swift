//
//  LearnModels.swift
//  WellPath
//
//  Models for the Learn section: articles, quizzes, challenges, and progress tracking
//

import Foundation

// MARK: - Article Models

struct LearnArticle: Codable, Identifiable {
    let articleId: String
    let pillar: String?
    let category: String
    let articleType: String?
    let userType: UserType  // Who can see: patients, practice_users, or all
    let title: String
    let subtitle: String?
    let contentMarkdown: String
    let keyConcepts: [String]?
    let evidenceReferences: [EvidenceReference]?
    let estimatedReadMinutes: Int
    let difficultyLevel: String
    let iconName: String?
    let heroImageUrl: String?
    let relatedMetricIds: [String]?
    let aiContext: String?
    let pointsValue: Int
    let displayOrder: Int
    let isFeatured: Bool
    let isPublished: Bool

    var id: String { articleId }

    /// User type for content visibility
    enum UserType: String, Codable, CaseIterable {
        case patients           // Patient-only content
        case practiceUsers = "practice_users"  // Clinicians, admins, nurses
        case all                // Both patients and practice users
    }

    enum CodingKeys: String, CodingKey {
        case articleId = "article_id"
        case pillar
        case category
        case articleType = "article_type"
        case userType = "user_type"
        case title
        case subtitle
        case contentMarkdown = "content_markdown"
        case keyConcepts = "key_concepts"
        case evidenceReferences = "evidence_references"
        case estimatedReadMinutes = "estimated_read_minutes"
        case difficultyLevel = "difficulty_level"
        case iconName = "icon_name"
        case heroImageUrl = "hero_image_url"
        case relatedMetricIds = "related_metric_ids"
        case aiContext = "ai_context"
        case pointsValue = "points_value"
        case displayOrder = "display_order"
        case isFeatured = "is_featured"
        case isPublished = "is_published"
    }
}

struct EvidenceReference: Codable, Identifiable, Hashable {
    let pmid: String?
    let title: String
    let summary: String?
    let year: Int?
    let url: String?

    var id: String { pmid ?? title }

    func hash(into hasher: inout Hasher) {
        hasher.combine(pmid)
        hasher.combine(title)
    }

    static func == (lhs: EvidenceReference, rhs: EvidenceReference) -> Bool {
        lhs.pmid == rhs.pmid && lhs.title == rhs.title
    }
}

// MARK: - Quiz Models

struct LearnQuiz: Codable, Identifiable {
    let quizId: String
    let articleId: String
    let title: String
    let description: String?
    let passingScore: Int
    let pointsBase: Int
    let pointsFirstTryBonus: Int
    let isActive: Bool

    var id: String { quizId }

    enum CodingKeys: String, CodingKey {
        case quizId = "quiz_id"
        case articleId = "article_id"
        case title
        case description
        case passingScore = "passing_score"
        case pointsBase = "points_base"
        case pointsFirstTryBonus = "points_first_try_bonus"
        case isActive = "is_active"
    }
}

struct QuizQuestion: Codable, Identifiable {
    let questionId: String
    let quizId: String
    let questionText: String
    let questionType: QuestionType
    let options: [QuizOption]
    let explanation: String?
    let displayOrder: Int
    let points: Int

    var id: String { questionId }

    enum QuestionType: String, Codable {
        case multipleChoice = "multiple_choice"
        case trueFalse = "true_false"
        case multiSelect = "multi_select"
    }

    enum CodingKeys: String, CodingKey {
        case questionId = "question_id"
        case quizId = "quiz_id"
        case questionText = "question_text"
        case questionType = "question_type"
        case options
        case explanation
        case displayOrder = "display_order"
        case points
    }
}

struct QuizOption: Codable, Identifiable, Hashable {
    let id: String
    let text: String
    let isCorrect: Bool
    let explanation: String?

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case isCorrect = "is_correct"
        case explanation
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: QuizOption, rhs: QuizOption) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Challenge Models

struct LearnChallenge: Codable, Identifiable {
    let challengeId: String
    let articleId: String?
    let pillar: String?
    let title: String
    let description: String
    let instructions: [String]?
    let durationType: DurationType
    let durationDays: Int?
    let verificationMethod: VerificationMethod
    let targetQuantityType: String?
    let targetValue: Double?
    let pointsValue: Int
    let difficultyLevel: String
    let displayOrder: Int

    var id: String { challengeId }

    enum DurationType: String, Codable {
        case instant
        case daily
        case weekly
    }

    enum VerificationMethod: String, Codable {
        case selfReport = "self_report"
        case dataCheck = "data_check"
    }

    enum CodingKeys: String, CodingKey {
        case challengeId = "challenge_id"
        case articleId = "article_id"
        case pillar
        case title
        case description
        case instructions
        case durationType = "duration_type"
        case durationDays = "duration_days"
        case verificationMethod = "verification_method"
        case targetQuantityType = "target_quantity_type"
        case targetValue = "target_value"
        case pointsValue = "points_value"
        case difficultyLevel = "difficulty_level"
        case displayOrder = "display_order"
    }
}

// MARK: - Progress Models

struct ArticleProgress: Codable, Identifiable {
    let id: UUID
    let patientId: UUID
    let articleId: String
    var status: ProgressStatus
    var startedAt: String?
    var completedAt: String?
    var timeSpentSeconds: Int
    var scrollPercentage: Int
    var pointsEarned: Int
    var isBookmarked: Bool
    var bookmarkNote: String?

    enum ProgressStatus: String, Codable {
        case notStarted = "not_started"
        case inProgress = "in_progress"
        case completed
    }

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case articleId = "article_id"
        case status
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case timeSpentSeconds = "time_spent_seconds"
        case scrollPercentage = "scroll_percentage"
        case pointsEarned = "points_earned"
        case isBookmarked = "is_bookmarked"
        case bookmarkNote = "bookmark_note"
    }
}

struct QuizAttempt: Codable, Identifiable {
    let attemptId: UUID
    let patientId: UUID
    let quizId: String
    let attemptNumber: Int
    let startedAt: String
    var completedAt: String?
    var scorePercentage: Double?
    var passed: Bool?
    var pointsEarned: Int
    var isFirstAttempt: Bool
    var timeSpentSeconds: Int?

    var id: UUID { attemptId }

    enum CodingKeys: String, CodingKey {
        case attemptId = "attempt_id"
        case patientId = "patient_id"
        case quizId = "quiz_id"
        case attemptNumber = "attempt_number"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case scorePercentage = "score_percentage"
        case passed
        case pointsEarned = "points_earned"
        case isFirstAttempt = "is_first_attempt"
        case timeSpentSeconds = "time_spent_seconds"
    }
}

struct QuizResponse: Codable, Identifiable {
    let id: UUID
    let attemptId: UUID
    let questionId: String
    let selectedOptions: [String]
    let isCorrect: Bool
    let timeSpentSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case attemptId = "attempt_id"
        case questionId = "question_id"
        case selectedOptions = "selected_options"
        case isCorrect = "is_correct"
        case timeSpentSeconds = "time_spent_seconds"
    }
}

struct ChallengeProgress: Codable, Identifiable {
    let id: UUID
    let patientId: UUID
    let challengeId: String
    var status: ChallengeStatus
    var startedAt: String?
    var completedAt: String?
    var expiresAt: String?
    var currentValue: Double?
    var targetValue: Double?
    var progressPercentage: Double?
    var pointsEarned: Int

    enum ChallengeStatus: String, Codable {
        case notStarted = "not_started"
        case inProgress = "in_progress"
        case completed
        case failed
    }

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case challengeId = "challenge_id"
        case status
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case expiresAt = "expires_at"
        case currentValue = "current_value"
        case targetValue = "target_value"
        case progressPercentage = "progress_percentage"
        case pointsEarned = "points_earned"
    }
}

// MARK: - Chiron Suggestion Model

struct ChironArticleSuggestion: Codable, Identifiable {
    let id: UUID
    let patientId: UUID
    let articleId: String
    let suggestionReason: String
    let relevanceScore: Double?
    let triggerType: String?
    var isDismissed: Bool
    var isRead: Bool
    let createdAt: String

    // Joined article (optional, populated when fetching with join)
    var article: LearnArticle?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case articleId = "article_id"
        case suggestionReason = "suggestion_reason"
        case relevanceScore = "relevance_score"
        case triggerType = "trigger_type"
        case isDismissed = "is_dismissed"
        case isRead = "is_read"
        case createdAt = "created_at"
        case article = "learn_articles"
    }
}

// MARK: - Aggregate/Helper Models

struct PillarLearnProgress {
    let pillar: String
    let articlesCompleted: Int
    let articlesTotal: Int
    let quizzesPassed: Int
    let quizzesTotal: Int
    let challengesCompleted: Int
    let challengesTotal: Int
    let totalPoints: Int

    var overallPercentage: Double {
        let total = articlesTotal + quizzesTotal + challengesTotal
        guard total > 0 else { return 0 }
        return Double(articlesCompleted + quizzesPassed + challengesCompleted) / Double(total) * 100
    }
}

/// Categories for Learn content
enum LearnCategory: String, CaseIterable {
    case pillarContent = "pillar_content"
    case longevityResearch = "longevity_research"
    case appGuides = "app_guides"
    case quickTips = "quick_tips"
    case deepDives = "deep_dives"

    var displayName: String {
        switch self {
        case .pillarContent: return "Pillar Education"
        case .longevityResearch: return "Longevity Research"
        case .appGuides: return "App Guides"
        case .quickTips: return "Quick Tips"
        case .deepDives: return "Deep Dives"
        }
    }

    var icon: String {
        switch self {
        case .pillarContent: return "book.fill"
        case .longevityResearch: return "chart.line.uptrend.xyaxis"
        case .appGuides: return "iphone"
        case .quickTips: return "lightbulb.fill"
        case .deepDives: return "magnifyingglass"
        }
    }
}

/// Article types within pillar content
enum ArticleType: String, CaseIterable {
    case about
    case why
    case how
    case challenges

    var displayName: String {
        switch self {
        case .about: return "About"
        case .why: return "Why It Matters"
        case .how: return "How To"
        case .challenges: return "Challenges"
        }
    }

    var displayOrder: Int {
        switch self {
        case .about: return 1
        case .why: return 2
        case .how: return 3
        case .challenges: return 4
        }
    }
}

/// Difficulty levels
enum DifficultyLevel: String, CaseIterable {
    case beginner
    case intermediate
    case advanced

    var displayName: String {
        rawValue.capitalized
    }

    var color: String {
        switch self {
        case .beginner: return "green"
        case .intermediate: return "orange"
        case .advanced: return "red"
        }
    }
}
