//
//  MedicalHistoryModels.swift
//  WellPath
//
//  Models for personal and family medical history.
//  Used for risk assessment and screening recommendations.
//

import Foundation
import SwiftUI

// MARK: - History Category

enum HistoryCategory: String, CaseIterable, Identifiable {
    case cancer = "cancer"
    case cardiovascular = "cardiovascular"
    case metabolic = "metabolic"
    case neurological = "neurological"
    case respiratory = "respiratory"
    case boneJoint = "bone_joint"
    case gastrointestinal = "gastrointestinal"
    case mentalHealth = "mental_health"
    case genetic = "genetic"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cancer: return "Cancer"
        case .cardiovascular: return "Heart & Vascular"
        case .metabolic: return "Metabolic & Endocrine"
        case .neurological: return "Neurological"
        case .respiratory: return "Respiratory"
        case .boneJoint: return "Bone & Joint"
        case .gastrointestinal: return "Digestive/GI"
        case .mentalHealth: return "Mental Health"
        case .genetic: return "Genetic Conditions"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .cancer: return "cross.circle"
        case .cardiovascular: return "heart.fill"
        case .metabolic: return "drop.degreesign"
        case .neurological: return "brain.head.profile"
        case .respiratory: return "lungs"
        case .boneJoint: return "figure.walk"
        case .gastrointestinal: return "stomach"
        case .mentalHealth: return "brain"
        case .genetic: return "dna"
        case .other: return "cross.case"
        }
    }

    var color: Color {
        switch self {
        case .cancer: return .pink
        case .cardiovascular: return .red
        case .metabolic: return .orange
        case .neurological: return .purple
        case .respiratory: return .cyan
        case .boneJoint: return .brown
        case .gastrointestinal: return .yellow
        case .mentalHealth: return .indigo
        case .genetic: return .teal
        case .other: return .gray
        }
    }

    var displayOrder: Int {
        switch self {
        case .cancer: return 1
        case .cardiovascular: return 2
        case .metabolic: return 3
        case .neurological: return 4
        case .respiratory: return 5
        case .boneJoint: return 6
        case .gastrointestinal: return 7
        case .mentalHealth: return 8
        case .genetic: return 9
        case .other: return 10
        }
    }

    static var sorted: [HistoryCategory] {
        allCases.sorted { $0.displayOrder < $1.displayOrder }
    }
}

// MARK: - History Scope

enum HistoryScope: String, CaseIterable, Identifiable {
    case personal = "personal"
    case family = "family"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .personal: return "Personal"
        case .family: return "Family"
        }
    }

    var icon: String {
        switch self {
        case .personal: return "person.fill"
        case .family: return "person.3.fill"
        }
    }
}

// MARK: - History Type (from sample_history_types)

struct HistoryType: Codable, Identifiable, Hashable {
    let id: UUID
    let historyType: String
    let displayName: String
    let category: String
    let description: String?
    let gender: String?
    let minRelevantAge: Int?
    let screeningRiskImpacts: [String: [String: String]]?
    let iconName: String?
    let displayOrder: Int?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case historyType = "history_type"
        case displayName = "display_name"
        case category
        case description
        case gender
        case minRelevantAge = "min_relevant_age"
        case screeningRiskImpacts = "screening_risk_impacts"
        case iconName = "icon_name"
        case displayOrder = "display_order"
        case isActive = "is_active"
    }

    var categoryEnum: HistoryCategory {
        HistoryCategory(rawValue: category) ?? .other
    }

    var icon: String {
        iconName ?? categoryEnum.icon
    }

    var color: Color {
        categoryEnum.color
    }

    /// Whether this condition applies to a specific gender only
    var genderRestriction: String? {
        gender
    }

    /// Check if condition applies to given patient gender
    func appliesTo(gender patientGender: String?) -> Bool {
        guard let restriction = genderRestriction else { return true }
        return restriction == patientGender
    }

    // Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(historyType)
    }

    static func == (lhs: HistoryType, rhs: HistoryType) -> Bool {
        lhs.historyType == rhs.historyType
    }
}

// MARK: - Relative Type (from sample_relative_types)

struct RelativeType: Codable, Identifiable, Hashable {
    let id: UUID
    let relativeType: String
    let displayName: String
    let displayNamePlural: String?
    let generation: Int
    let isFirstDegree: Bool
    let isBloodRelative: Bool
    let side: String?
    let displayOrder: Int?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case relativeType = "relative_type"
        case displayName = "display_name"
        case displayNamePlural = "display_name_plural"
        case generation
        case isFirstDegree = "is_first_degree"
        case isBloodRelative = "is_blood_relative"
        case side
        case displayOrder = "display_order"
        case isActive = "is_active"
    }

    var icon: String {
        switch relativeType {
        case "mother": return "figure.stand.dress"
        case "father": return "figure.stand"
        case "sister", "brother", "half_sibling": return "person.2"
        case "daughter", "son": return "figure.and.child.holdinghands"
        case _ where relativeType.contains("grandmother"): return "figure.stand.dress"
        case _ where relativeType.contains("grandfather"): return "figure.stand"
        case _ where relativeType.contains("aunt"): return "figure.stand.dress"
        case _ where relativeType.contains("uncle"): return "figure.stand"
        default: return "person"
        }
    }

    var riskLabel: String {
        isFirstDegree ? "First Degree" : "Second Degree"
    }

    // Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(relativeType)
    }

    static func == (lhs: RelativeType, rhs: RelativeType) -> Bool {
        lhs.relativeType == rhs.relativeType
    }
}

// MARK: - Patient History Sample (from patient_history_samples)

struct PatientHistorySample: Codable, Identifiable {
    let id: UUID
    let patientId: UUID
    let historyType: String
    let historyScope: String
    let relativeType: String?
    let relativeCount: Int?
    let ageAtDiagnosis: Int?
    let diagnosisYear: Int?
    let isConfirmed: Bool?
    let isDeceasedFromCondition: Bool?
    let notes: String?
    let source: String?
    let isCurrent: Bool?
    let supersededAt: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case historyType = "history_type"
        case historyScope = "history_scope"
        case relativeType = "relative_type"
        case relativeCount = "relative_count"
        case ageAtDiagnosis = "age_at_diagnosis"
        case diagnosisYear = "diagnosis_year"
        case isConfirmed = "is_confirmed"
        case isDeceasedFromCondition = "is_deceased_from_condition"
        case notes
        case source
        case isCurrent = "is_current"
        case supersededAt = "superseded_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var scope: HistoryScope {
        HistoryScope(rawValue: historyScope) ?? .personal
    }

    var isPersonal: Bool {
        historyScope == "personal"
    }

    var isFamily: Bool {
        historyScope == "family"
    }

    var diagnosisDescription: String {
        if let age = ageAtDiagnosis {
            return "Diagnosed at age \(age)"
        } else if let year = diagnosisYear {
            return "Diagnosed in \(year)"
        }
        return ""
    }

    var relativeDescription: String {
        guard let relType = relativeType else { return "" }
        let count = relativeCount ?? 1
        if count > 1 {
            return "\(count) relatives (\(relType))"
        }
        return relType.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// MARK: - History Entry (Combined model for display)

struct HistoryEntry: Identifiable {
    let id: UUID
    let sample: PatientHistorySample
    let type: HistoryType
    let relative: RelativeType?

    var displayName: String {
        type.displayName
    }

    var category: HistoryCategory {
        type.categoryEnum
    }

    var icon: String {
        type.icon
    }

    var color: Color {
        type.color
    }

    var subtitle: String {
        if sample.isFamily, let rel = relative {
            var parts: [String] = [rel.displayName]
            if let age = sample.ageAtDiagnosis {
                parts.append("age \(age)")
            }
            return parts.joined(separator: " - ")
        } else {
            return sample.diagnosisDescription
        }
    }

    var isFirstDegreeFamily: Bool {
        sample.isFamily && (relative?.isFirstDegree ?? false)
    }
}

// MARK: - Insert/Update Models

struct PatientHistoryInsert: Encodable {
    let patientId: String
    let historyType: String
    let historyScope: String
    let relativeType: String?
    let relativeCount: Int?
    let ageAtDiagnosis: Int?
    let diagnosisYear: Int?
    let isConfirmed: Bool
    let isDeceasedFromCondition: Bool?
    let notes: String?
    let source: String
    let isCurrent: Bool

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case historyType = "history_type"
        case historyScope = "history_scope"
        case relativeType = "relative_type"
        case relativeCount = "relative_count"
        case ageAtDiagnosis = "age_at_diagnosis"
        case diagnosisYear = "diagnosis_year"
        case isConfirmed = "is_confirmed"
        case isDeceasedFromCondition = "is_deceased_from_condition"
        case notes
        case source
        case isCurrent = "is_current"
    }
}

struct PatientHistoryUpdate: Encodable {
    let relativeType: String?
    let relativeCount: Int?
    let ageAtDiagnosis: Int?
    let diagnosisYear: Int?
    let isConfirmed: Bool?
    let isDeceasedFromCondition: Bool?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case relativeType = "relative_type"
        case relativeCount = "relative_count"
        case ageAtDiagnosis = "age_at_diagnosis"
        case diagnosisYear = "diagnosis_year"
        case isConfirmed = "is_confirmed"
        case isDeceasedFromCondition = "is_deceased_from_condition"
        case notes
    }
}

// MARK: - Risk Calculation Result

struct ScreeningRiskResult: Codable {
    let riskLevel: String
    let riskFactors: [RiskFactor]

    enum CodingKeys: String, CodingKey {
        case riskLevel = "risk_level"
        case riskFactors = "risk_factors"
    }

    var level: RiskLevel {
        RiskLevel(rawValue: riskLevel) ?? .average
    }
}

struct RiskFactor: Codable {
    let condition: String
    let scope: String
    let relative: String?
    let isFirstDegree: Bool?
    let impact: String

    enum CodingKeys: String, CodingKey {
        case condition
        case scope
        case relative
        case isFirstDegree = "is_first_degree"
        case impact
    }
}

enum RiskLevel: String, CaseIterable {
    case average = "average"
    case moderateRisk = "moderate_risk"
    case highRisk = "high_risk"

    var displayName: String {
        switch self {
        case .average: return "Average"
        case .moderateRisk: return "Moderate"
        case .highRisk: return "High"
        }
    }

    var color: Color {
        switch self {
        case .average: return .green
        case .moderateRisk: return .orange
        case .highRisk: return .red
        }
    }

    var icon: String {
        switch self {
        case .average: return "checkmark.circle"
        case .moderateRisk: return "exclamationmark.triangle"
        case .highRisk: return "exclamationmark.octagon"
        }
    }
}

// MARK: - Baseline Prerequisite

struct BaselinePrerequisite: Codable {
    let id: UUID
    let baselineViewId: String
    let requiredBaselineViewId: String
    let requiredBaselineType: String?
    let displayMessage: String
    let actionLabel: String?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case baselineViewId = "baseline_view_id"
        case requiredBaselineViewId = "required_baseline_view_id"
        case requiredBaselineType = "required_baseline_type"
        case displayMessage = "display_message"
        case actionLabel = "action_label"
        case isActive = "is_active"
    }
}
