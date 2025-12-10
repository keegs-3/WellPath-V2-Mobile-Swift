//
//  MentalHealthModels.swift
//  WellPath
//
//  Models for mental health assessments (SWLS, GAD-2, PHQ-2).
//

import Foundation

// MARK: - Assessment Types

enum MentalHealthAssessmentType: String, Codable, CaseIterable {
    case swls = "SWLS"   // Satisfaction with Life Scale (5 questions)
    case gad2 = "GAD2"   // Generalized Anxiety Disorder 2-item
    case phq2 = "PHQ2"   // Patient Health Questionnaire 2-item

    var displayName: String {
        switch self {
        case .swls: return "Well-Being"
        case .gad2: return "Anxiety"
        case .phq2: return "Depression"
        }
    }

    var fullName: String {
        switch self {
        case .swls: return "Satisfaction with Life Scale"
        case .gad2: return "Generalized Anxiety Disorder (GAD-2)"
        case .phq2: return "Patient Health Questionnaire (PHQ-2)"
        }
    }

    var questionCount: Int {
        switch self {
        case .swls: return 5
        case .gad2, .phq2: return 2
        }
    }

    var scoreRange: ClosedRange<Int> {
        switch self {
        case .swls: return 5...35
        case .gad2, .phq2: return 0...6
        }
    }

    var icon: String {
        switch self {
        case .swls: return "face.smiling.fill"
        case .gad2: return "brain.head.profile"
        case .phq2: return "heart.circle.fill"
        }
    }
}

// MARK: - Assessment Record

struct MentalHealthAssessment: Codable, Identifiable {
    let id: UUID
    let patientId: UUID
    let assessmentType: String
    let totalScore: Int
    let responses: [String: Int]
    let interpretation: String?
    let completedAt: Date
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case assessmentType = "assessment_type"
        case totalScore = "total_score"
        case responses
        case interpretation
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var type: MentalHealthAssessmentType? {
        MentalHealthAssessmentType(rawValue: assessmentType)
    }
}

// MARK: - Insert Model

struct MentalHealthAssessmentInsert: Encodable {
    let patientId: String
    let assessmentType: String
    let totalScore: Int
    let responses: [String: Int]
    let interpretation: String?

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case assessmentType = "assessment_type"
        case totalScore = "total_score"
        case responses
        case interpretation
    }
}

// MARK: - SWLS Assessment

struct SWLSAssessment {
    static let questions = [
        "In most ways my life is close to my ideal.",
        "The conditions of my life are excellent.",
        "I am satisfied with my life.",
        "So far I have gotten the important things I want in life.",
        "If I could live my life over, I would change almost nothing."
    ]

    static let responseOptions = [
        (1, "Strongly Disagree"),
        (2, "Disagree"),
        (3, "Slightly Disagree"),
        (4, "Neither Agree nor Disagree"),
        (5, "Slightly Agree"),
        (6, "Agree"),
        (7, "Strongly Agree")
    ]

    static func interpretation(for score: Int) -> String {
        switch score {
        case 31...35: return "Extremely Satisfied"
        case 26...30: return "Satisfied"
        case 21...25: return "Slightly Satisfied"
        case 20: return "Neutral"
        case 15...19: return "Slightly Dissatisfied"
        case 10...14: return "Dissatisfied"
        case 5...9: return "Extremely Dissatisfied"
        default: return "Unknown"
        }
    }

    static func interpretationDescription(for score: Int) -> String {
        switch score {
        case 31...35:
            return "You feel your life is going extremely well. You experience high satisfaction across most areas of your life."
        case 26...30:
            return "You feel things are going well in your life. While there may be areas for improvement, you're generally content."
        case 21...25:
            return "You're slightly satisfied with your life overall. There may be several areas where you'd like to see improvement."
        case 20:
            return "You feel neutral about your life satisfaction. You may be re-evaluating aspects of your life."
        case 15...19:
            return "You're experiencing some dissatisfaction with life. Consider what areas might benefit from attention."
        case 10...14:
            return "You're dissatisfied with several areas of your life. Speaking with a professional may help identify positive changes."
        case 5...9:
            return "You're experiencing significant life dissatisfaction. We recommend speaking with a healthcare provider."
        default:
            return "Unable to interpret score."
        }
    }
}

// MARK: - GAD-2 Assessment

struct GAD2Assessment {
    static let questions = [
        "Feeling nervous, anxious, or on edge",
        "Not being able to stop or control worrying"
    ]

    static let responseOptions = [
        (0, "Not at all"),
        (1, "Several days"),
        (2, "More than half the days"),
        (3, "Nearly every day")
    ]

    static let timeframe = "Over the last 2 weeks, how often have you been bothered by the following problems?"

    static func interpretation(for score: Int) -> String {
        switch score {
        case 0...2: return "Minimal Anxiety"
        case 3...6: return "Possible Anxiety Disorder"
        default: return "Unknown"
        }
    }

    static func interpretationDescription(for score: Int) -> String {
        switch score {
        case 0...2:
            return "Your responses suggest minimal anxiety symptoms. Continue with healthy coping strategies."
        case 3...6:
            return "Your responses suggest you may be experiencing anxiety. Consider speaking with a healthcare provider for further evaluation."
        default:
            return "Unable to interpret score."
        }
    }

    /// Threshold for positive screening (suggests further evaluation needed)
    static let positiveScreeningThreshold = 3
}

// MARK: - PHQ-2 Assessment

struct PHQ2Assessment {
    static let questions = [
        "Little interest or pleasure in doing things",
        "Feeling down, depressed, or hopeless"
    ]

    static let responseOptions = [
        (0, "Not at all"),
        (1, "Several days"),
        (2, "More than half the days"),
        (3, "Nearly every day")
    ]

    static let timeframe = "Over the last 2 weeks, how often have you been bothered by the following problems?"

    static func interpretation(for score: Int) -> String {
        switch score {
        case 0...2: return "Minimal Depression"
        case 3...6: return "Possible Depression"
        default: return "Unknown"
        }
    }

    static func interpretationDescription(for score: Int) -> String {
        switch score {
        case 0...2:
            return "Your responses suggest minimal depression symptoms. Continue with healthy habits and self-care."
        case 3...6:
            return "Your responses suggest you may be experiencing depressive symptoms. Consider speaking with a healthcare provider for further evaluation."
        default:
            return "Unable to interpret score."
        }
    }

    /// Threshold for positive screening (suggests further evaluation needed)
    static let positiveScreeningThreshold = 3
}

// MARK: - Assessment Summary (for list display)

struct AssessmentSummary: Identifiable {
    let id = UUID()
    let type: MentalHealthAssessmentType
    let lastScore: Int?
    let lastDate: Date?
    let interpretation: String?

    var hasData: Bool {
        lastScore != nil
    }
}
