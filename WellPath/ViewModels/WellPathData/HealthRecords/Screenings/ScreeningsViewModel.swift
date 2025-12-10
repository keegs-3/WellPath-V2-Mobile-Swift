//
//  ScreeningsViewModel.swift
//  WellPath
//
//  ViewModel for Screenings & Immunizations tracking.
//  Handles loading/saving screening records and immunization data.
//

import Foundation
import Supabase
import SwiftUI

// MARK: - Screenings ViewModel

@MainActor
class ScreeningsViewModel: ObservableObject {
    @Published var screeningTypes: [ScreeningType] = []
    @Published var screenings: [PatientScreening] = []
    @Published var immunizations: [PatientImmunization] = []
    @Published var vaccineTypes: [VaccineType] = []

    @Published var upToDateScreenings: [PatientScreening] = []
    @Published var dueSoonScreenings: [PatientScreening] = []
    @Published var overdueScreenings: [PatientScreening] = []

    @Published var isLoading = false
    @Published var error: Error?

    private let supabase = SupabaseManager.shared.client

    func loadAllData() async {
        guard let userId = try? await supabase.auth.session.user.id else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Load screening types
            screeningTypes = try await supabase
                .from("screening_types")
                .select()
                .eq("is_active", value: true)
                .order("screening_name")
                .execute()
                .value

            // Load patient screenings
            screenings = try await supabase
                .from("patient_screenings")
                .select()
                .eq("patient_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .order("next_due_date")
                .execute()
                .value

            // Load vaccine types
            vaccineTypes = try await supabase
                .from("vaccine_types")
                .select()
                .eq("is_active", value: true)
                .order("vaccine_name")
                .execute()
                .value

            // Load immunizations
            immunizations = try await supabase
                .from("patient_immunizations")
                .select()
                .eq("patient_id", value: userId.uuidString)
                .order("administration_date", ascending: false)
                .execute()
                .value

            // Categorize screenings by status
            categorizeScreenings()

        } catch {
            self.error = error
            print("Error loading screenings data: \(error)")
        }
    }

    private func categorizeScreenings() {
        upToDateScreenings = []
        dueSoonScreenings = []
        overdueScreenings = []

        for screening in screenings {
            if screening.isOverdue {
                overdueScreenings.append(screening)
            } else if screening.isDueSoon {
                dueSoonScreenings.append(screening)
            } else {
                upToDateScreenings.append(screening)
            }
        }
    }

    func addScreening(
        screeningTypeId: String,
        screeningDate: Date,
        nextDueDate: Date?,
        notes: String?
    ) async {
        guard let userId = try? await supabase.auth.session.user.id else {
            return
        }

        do {
            let insert = PatientScreeningInsert(
                patientId: userId.uuidString,
                screeningTypeId: screeningTypeId,
                screeningStatus: "completed",
                screeningDate: screeningDate,
                nextDueDate: nextDueDate,
                notes: notes,
                dataSource: "manual_entry"
            )

            try await supabase
                .from("patient_screenings")
                .insert(insert)
                .execute()

            await loadAllData()
        } catch {
            self.error = error
            print("Error adding screening: \(error)")
        }
    }

    func updateScreening(id: UUID, nextDueDate: Date?, notes: String?) async {
        do {
            let update = ScreeningUpdatePayload(
                nextDueDate: nextDueDate,
                notes: notes,
                updatedAt: Date()
            )

            try await supabase
                .from("patient_screenings")
                .update(update)
                .eq("id", value: id.uuidString)
                .execute()

            await loadAllData()
        } catch {
            self.error = error
            print("Error updating screening: \(error)")
        }
    }

    func deleteScreening(id: UUID) async {
        do {
            try await supabase
                .from("patient_screenings")
                .update(["is_active": false])
                .eq("id", value: id.uuidString)
                .execute()

            await loadAllData()
        } catch {
            self.error = error
            print("Error deleting screening: \(error)")
        }
    }

    func addImmunization(
        vaccineTypeId: String,
        vaccineName: String,
        administrationDate: Date,
        doseNumber: Int,
        totalDoses: Int,
        provider: String?,
        location: String?,
        lotNumber: String?,
        notes: String?
    ) async {
        guard let userId = try? await supabase.auth.session.user.id else {
            return
        }

        do {
            let insert = PatientImmunizationInsert(
                patientId: userId.uuidString,
                vaccineTypeId: vaccineTypeId,
                vaccineName: vaccineName,
                administrationDate: administrationDate,
                doseNumber: doseNumber,
                totalDoses: totalDoses,
                provider: provider,
                location: location,
                lotNumber: lotNumber,
                notes: notes
            )

            try await supabase
                .from("patient_immunizations")
                .insert(insert)
                .execute()

            await loadAllData()
        } catch {
            self.error = error
            print("Error adding immunization: \(error)")
        }
    }

    func deleteImmunization(id: UUID) async {
        do {
            try await supabase
                .from("patient_immunizations")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()

            await loadAllData()
        } catch {
            self.error = error
            print("Error deleting immunization: \(error)")
        }
    }

    func getScreeningName(for typeId: String) -> String {
        screeningTypes.first(where: { $0.screeningTypeId == typeId })?.screeningName ?? typeId
    }

    func getVaccineName(for typeId: String) -> String {
        vaccineTypes.first(where: { $0.vaccineTypeId == typeId })?.vaccineName ?? typeId
    }

    // Get upcoming screenings for calendar
    func getUpcomingScreenings(in range: ClosedRange<Date>) -> [PatientScreening] {
        screenings.filter { screening in
            guard let nextDue = screening.nextDueDate else { return false }
            return range.contains(nextDue)
        }
    }

    // Get screenings due in a specific month
    func getScreeningsDueInMonth(_ date: Date) -> [PatientScreening] {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        return getUpcomingScreenings(in: startOfMonth...endOfMonth)
    }
}

// MARK: - Update Payload

struct ScreeningUpdatePayload: Encodable {
    let nextDueDate: Date?
    let notes: String?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case nextDueDate = "next_due_date"
        case notes
        case updatedAt = "updated_at"
    }
}

// MARK: - Insert Models

struct PatientScreeningInsert: Encodable {
    let patientId: String
    let screeningTypeId: String
    let screeningStatus: String
    let screeningDate: Date
    let nextDueDate: Date?
    let notes: String?
    let dataSource: String

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case screeningTypeId = "screening_type_id"
        case screeningStatus = "screening_status"
        case screeningDate = "screening_date"
        case nextDueDate = "next_due_date"
        case notes
        case dataSource = "data_source"
    }
}

// MARK: - Vaccine Types (not in SurveyModels)

struct VaccineType: Codable, Identifiable {
    let id: UUID
    let vaccineTypeId: String
    let vaccineName: String
    let description: String?
    let totalDoses: Int
    let recommendedFrequencyMonths: Int?
    let minAge: Int?
    let icon: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case vaccineTypeId = "vaccine_type_id"
        case vaccineName = "vaccine_name"
        case description
        case totalDoses = "total_doses"
        case recommendedFrequencyMonths = "recommended_frequency_months"
        case minAge = "min_age"
        case icon
        case isActive = "is_active"
    }
}

// MARK: - Patient Immunization

struct PatientImmunization: Codable, Identifiable {
    let id: UUID
    let patientId: UUID
    let vaccineTypeId: String
    let vaccineName: String
    let administrationDate: Date
    let doseNumber: Int
    let totalDoses: Int
    let provider: String?
    let location: String?
    let lotNumber: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case vaccineTypeId = "vaccine_type_id"
        case vaccineName = "vaccine_name"
        case administrationDate = "administration_date"
        case doseNumber = "dose_number"
        case totalDoses = "total_doses"
        case provider
        case location
        case lotNumber = "lot_number"
        case notes
    }
}

struct PatientImmunizationInsert: Encodable {
    let patientId: String
    let vaccineTypeId: String
    let vaccineName: String
    let administrationDate: Date
    let doseNumber: Int
    let totalDoses: Int
    let provider: String?
    let location: String?
    let lotNumber: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case vaccineTypeId = "vaccine_type_id"
        case vaccineName = "vaccine_name"
        case administrationDate = "administration_date"
        case doseNumber = "dose_number"
        case totalDoses = "total_doses"
        case provider
        case location
        case lotNumber = "lot_number"
        case notes
    }
}

// MARK: - Screening Status Type

enum ScreeningStatus {
    case upToDate, dueSoon, overdue, scheduled

    var color: Color {
        switch self {
        case .upToDate: return .green
        case .dueSoon: return .orange
        case .overdue: return .red
        case .scheduled: return .blue
        }
    }

    var icon: String {
        switch self {
        case .upToDate: return "checkmark.circle.fill"
        case .dueSoon: return "exclamationmark.circle.fill"
        case .overdue: return "xmark.circle.fill"
        case .scheduled: return "calendar.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .upToDate: return "Up to Date"
        case .dueSoon: return "Due Soon"
        case .overdue: return "Overdue"
        case .scheduled: return "Scheduled"
        }
    }
}

// MARK: - PatientScreening Extension for Status

extension PatientScreening {
    var status: ScreeningStatus {
        if isOverdue {
            return .overdue
        } else if isDueSoon {
            return .dueSoon
        } else {
            return .upToDate
        }
    }
}
