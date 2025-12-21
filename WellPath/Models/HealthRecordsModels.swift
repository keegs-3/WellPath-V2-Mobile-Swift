//
//  HealthRecordsModels.swift
//  WellPath
//
//  Models for health records: conditions, screenings, etc.
//

import Foundation

// MARK: - Patient Condition

struct PatientCondition: Identifiable, Codable {
    let id: UUID
    let patientId: UUID?
    let conditionId: String
    let conditionName: String
    let conditionCategory: String?
    let historyType: String  // "personal" or "family"
    let familyMemberRelationship: String?
    let diagnosisDate: Date?
    let severity: String?
    let status: String?
    let notes: String?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    var isPersonal: Bool {
        historyType == "personal"
    }

    var isFamily: Bool {
        historyType == "family"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case conditionId = "condition_id"
        case conditionName = "condition_name"
        case conditionCategory = "condition_category"
        case historyType = "history_type"
        case familyMemberRelationship = "family_member_relationship"
        case diagnosisDate = "diagnosis_date"
        case severity
        case status
        case notes
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        patientId = try container.decodeIfPresent(UUID.self, forKey: .patientId)
        conditionId = try container.decode(String.self, forKey: .conditionId)
        conditionName = try container.decode(String.self, forKey: .conditionName)
        conditionCategory = try container.decodeIfPresent(String.self, forKey: .conditionCategory)
        historyType = try container.decodeIfPresent(String.self, forKey: .historyType) ?? "personal"
        familyMemberRelationship = try container.decodeIfPresent(String.self, forKey: .familyMemberRelationship)

        // Handle date-only strings
        if let dateString = try? container.decode(String.self, forKey: .diagnosisDate) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            diagnosisDate = formatter.date(from: dateString)
        } else {
            diagnosisDate = try container.decodeIfPresent(Date.self, forKey: .diagnosisDate)
        }

        severity = try container.decodeIfPresent(String.self, forKey: .severity)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

// MARK: - Patient Screening

struct PatientScreening: Identifiable, Codable {
    let id: UUID
    let patientId: UUID
    let screeningTypeId: String
    let screeningStatus: String
    let screeningDate: Date?
    let nextDueDate: Date?
    let resultSummary: String?
    let dataSource: String
    let notes: String?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    var isOverdue: Bool {
        guard let dueDate = nextDueDate else { return false }
        return dueDate < Date()
    }

    var isDueSoon: Bool {
        guard let dueDate = nextDueDate else { return false }
        let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
        return daysUntilDue <= 30 && daysUntilDue >= 0
    }

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case screeningTypeId = "screening_type_id"
        case screeningStatus = "screening_status"
        case screeningDate = "screening_date"
        case nextDueDate = "next_due_date"
        case resultSummary = "result_summary"
        case dataSource = "data_source"
        case notes
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Screening Type

struct ScreeningType: Identifiable, Codable {
    let id: UUID
    let screeningTypeId: String
    let screeningName: String
    let description: String?
    let recommendedFrequencyMonths: Int?
    let category: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case screeningTypeId = "screening_type_id"
        case screeningName = "screening_name"
        case description
        case recommendedFrequencyMonths = "recommended_frequency_months"
        case category
        case isActive = "is_active"
    }
}
