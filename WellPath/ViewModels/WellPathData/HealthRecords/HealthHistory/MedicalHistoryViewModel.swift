//
//  MedicalHistoryViewModel.swift
//  WellPath
//
//  ViewModel for medical history management.
//  Handles personal conditions, family history, and preventive screenings.
//

import SwiftUI
import Supabase

@MainActor
class MedicalHistoryViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var personalConditions: [PatientCondition] = []
    @Published var familyConditions: [PatientCondition] = []
    @Published var screenings: [PatientScreening] = []
    @Published var screeningTypes: [ScreeningType] = []
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Services

    private let supabase = SupabaseManager.shared.client

    // MARK: - Computed Properties

    var allConditions: [PatientCondition] {
        personalConditions + familyConditions
    }

    // MARK: - Load Data

    func loadConditions() async {
        guard let userId = try? await supabase.auth.session.user.id else {
            error = "Not logged in"
            return
        }

        isLoading = true
        error = nil

        do {
            async let personalTask = fetchPersonalConditions(userId: userId)
            async let familyTask = fetchFamilyConditions(userId: userId)

            let (personal, family) = try await (personalTask, familyTask)

            personalConditions = personal
            familyConditions = family

        } catch {
            self.error = error.localizedDescription
            print("MedicalHistoryViewModel: Error loading conditions - \(error)")
        }

        isLoading = false
    }

    private func fetchPersonalConditions(userId: UUID) async throws -> [PatientCondition] {
        try await supabase
            .from("patient_conditions")
            .select()
            .eq("patient_id", value: userId.uuidString)
            .eq("history_type", value: "personal")
            .eq("is_active", value: true)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    private func fetchFamilyConditions(userId: UUID) async throws -> [PatientCondition] {
        try await supabase
            .from("patient_conditions")
            .select()
            .eq("patient_id", value: userId.uuidString)
            .eq("history_type", value: "family")
            .eq("is_active", value: true)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func loadScreenings() async {
        guard let userId = try? await supabase.auth.session.user.id else {
            error = "Not logged in"
            return
        }

        isLoading = true
        error = nil

        do {
            async let screeningsTask = fetchScreenings(userId: userId)
            async let typesTask = fetchScreeningTypes()

            let (fetchedScreenings, fetchedTypes) = try await (screeningsTask, typesTask)

            screenings = fetchedScreenings
            screeningTypes = fetchedTypes

        } catch {
            self.error = error.localizedDescription
            print("MedicalHistoryViewModel: Error loading screenings - \(error)")
        }

        isLoading = false
    }

    private func fetchScreenings(userId: UUID) async throws -> [PatientScreening] {
        try await supabase
            .from("patient_screenings")
            .select()
            .eq("patient_id", value: userId.uuidString)
            .eq("is_active", value: true)
            .order("screening_date", ascending: false)
            .execute()
            .value
    }

    private func fetchScreeningTypes() async throws -> [ScreeningType] {
        try await supabase
            .from("screening_types")
            .select()
            .eq("is_active", value: true)
            .order("screening_name")
            .execute()
            .value
    }

    // MARK: - Condition CRUD

    func addCondition(
        conditionId: String,
        conditionName: String,
        conditionCategory: String?,
        historyType: String,
        familyMemberRelationship: String?,
        diagnosisDate: Date?,
        notes: String?
    ) async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        do {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFullDate]

            var record: [String: AnyJSON] = [
                "patient_id": .string(userId.uuidString),
                "condition_id": .string(conditionId),
                "condition_name": .string(conditionName),
                "history_type": .string(historyType),
                "is_active": .bool(true)
            ]

            if let category = conditionCategory {
                record["condition_category"] = .string(category)
            }
            if let relationship = familyMemberRelationship {
                record["family_member_relationship"] = .string(relationship)
            }
            if let date = diagnosisDate {
                record["diagnosis_date"] = .string(dateFormatter.string(from: date))
            }
            if let notes = notes {
                record["notes"] = .string(notes)
            }

            let newCondition: PatientCondition = try await supabase
                .from("patient_conditions")
                .insert(record)
                .select()
                .single()
                .execute()
                .value

            if historyType == "personal" {
                personalConditions.append(newCondition)
            } else {
                familyConditions.append(newCondition)
            }

        } catch {
            print("MedicalHistoryViewModel: Error adding condition - \(error)")
        }
    }

    func updateCondition(
        conditionId: UUID,
        severity: String?,
        status: String?,
        notes: String?
    ) async {
        do {
            var updates: [String: AnyJSON] = [
                "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]

            if let severity = severity {
                updates["severity"] = .string(severity)
            }
            if let status = status {
                updates["status"] = .string(status)
            }
            if let notes = notes {
                updates["notes"] = .string(notes)
            }

            let updated: PatientCondition = try await supabase
                .from("patient_conditions")
                .update(updates)
                .eq("id", value: conditionId.uuidString)
                .select()
                .single()
                .execute()
                .value

            // Update local state
            if let index = personalConditions.firstIndex(where: { $0.id == conditionId }) {
                personalConditions[index] = updated
            } else if let index = familyConditions.firstIndex(where: { $0.id == conditionId }) {
                familyConditions[index] = updated
            }

        } catch {
            print("MedicalHistoryViewModel: Error updating condition - \(error)")
        }
    }

    func deleteCondition(conditionId: UUID) async {
        do {
            try await supabase
                .from("patient_conditions")
                .update(["is_active": false])
                .eq("id", value: conditionId.uuidString)
                .execute()

            // Remove from local state
            personalConditions.removeAll { $0.id == conditionId }
            familyConditions.removeAll { $0.id == conditionId }

        } catch {
            print("MedicalHistoryViewModel: Error deleting condition - \(error)")
        }
    }

    // MARK: - Screening CRUD

    func upsertScreening(
        screeningTypeId: String,
        screeningStatus: String,
        screeningDate: Date?,
        nextDueDate: Date?,
        resultSummary: String? = nil,
        notes: String?
    ) async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        do {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFullDate]

            var record: [String: AnyJSON] = [
                "patient_id": .string(userId.uuidString),
                "screening_type_id": .string(screeningTypeId),
                "screening_status": .string(screeningStatus),
                "data_source": .string("manual"),
                "is_active": .bool(true)
            ]

            if let date = screeningDate {
                record["screening_date"] = .string(dateFormatter.string(from: date))
            }
            if let dueDate = nextDueDate {
                record["next_due_date"] = .string(dateFormatter.string(from: dueDate))
            }
            if let summary = resultSummary {
                record["result_summary"] = .string(summary)
            }
            if let notes = notes {
                record["notes"] = .string(notes)
            }

            let screening: PatientScreening = try await supabase
                .from("patient_screenings")
                .upsert(record, onConflict: "patient_id,screening_type_id")
                .select()
                .single()
                .execute()
                .value

            if let index = screenings.firstIndex(where: { $0.id == screening.id }) {
                screenings[index] = screening
            } else {
                screenings.append(screening)
            }

        } catch {
            print("MedicalHistoryViewModel: Error upserting screening - \(error)")
        }
    }

    func deleteScreening(screeningId: UUID) async {
        do {
            try await supabase
                .from("patient_screenings")
                .update(["is_active": false])
                .eq("id", value: screeningId.uuidString)
                .execute()

            screenings.removeAll { $0.id == screeningId }
        } catch {
            print("MedicalHistoryViewModel: Error deleting screening - \(error)")
        }
    }
}
