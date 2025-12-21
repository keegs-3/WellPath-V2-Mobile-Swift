//
//  BehavioralScore.swift
//  WellPath
//
//  Model for behavioral scores from patient_behavioral_scores table
//

import Foundation

struct BehavioralScore: Codable, Identifiable {
    let id: UUID
    let patientId: UUID
    let scoreType: String
    let scoreValue: Double
    let scoreSource: ScoreSource
    let cycleId: UUID?
    let isCurrent: Bool
    let thresholdProgress: ThresholdProgress?
    let componentScores: [String: Double]?
    let calculatedAt: Date
    let createdAt: Date
    let updatedAt: Date

    // From joined view (patient_behavioral_scores_current)
    let daysInWindow: Int?
    let minDaysRequired: Int?
    let rollingWindowDays: Int?
    let thresholdMet: Bool?
    let rollingAverage: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case scoreType = "score_type"
        case scoreValue = "score_value"
        case scoreSource = "score_source"
        case cycleId = "cycle_id"
        case isCurrent = "is_current"
        case thresholdProgress = "threshold_progress"
        case componentScores = "component_scores"
        case calculatedAt = "calculated_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case daysInWindow = "days_in_window"
        case minDaysRequired = "min_days_required"
        case rollingWindowDays = "rolling_window_days"
        case thresholdMet = "threshold_met"
        case rollingAverage = "rolling_average"
    }

    enum ScoreSource: String, Codable {
        case baseline
        case tracked
    }

    // Computed properties
    var isBasedOnTrackedData: Bool {
        scoreSource == .tracked
    }

    var thresholdPercentage: Int {
        thresholdProgress?.percentage ?? 0
    }

    var daysTracked: Int {
        thresholdProgress?.daysTracked ?? daysInWindow ?? 0
    }

    var daysRequired: Int {
        thresholdProgress?.daysRequired ?? minDaysRequired ?? 21
    }

    var daysRemaining: Int {
        max(0, daysRequired - daysTracked)
    }

    var sourceDisplayText: String {
        switch scoreSource {
        case .baseline:
            return "Based on Baseline"
        case .tracked:
            return "Based on Tracked Data"
        }
    }
}

struct ThresholdProgress: Codable {
    let daysTracked: Int
    let daysRequired: Int
    let windowDays: Int
    let percentage: Int

    enum CodingKeys: String, CodingKey {
        case daysTracked = "days_tracked"
        case daysRequired = "days_required"
        case windowDays = "window_days"
        case percentage
    }
}

// Extension for score type identification
extension BehavioralScore {
    static let proteinScoreType = "protein_score"
    static let sleepScoreType = "sleep_score"

    var isProteinScore: Bool {
        scoreType == Self.proteinScoreType
    }
}
