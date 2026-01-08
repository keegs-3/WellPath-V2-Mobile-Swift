//
//  HealthRecordsModels.swift
//  WellPath
//
//  Models for health records: screenings.
//  Note: Medical history models are in MedicalHistoryModels.swift
//

import Foundation

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
