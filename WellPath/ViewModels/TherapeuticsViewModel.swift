//
//  TherapeuticsViewModel.swift
//  WellPath
//
//  ViewModel for therapeutics management.
//  Handles medications, supplements, and peptides CRUD operations.
//  Adherence tracking is handled separately via patient_samples.
//

import SwiftUI

// MARK: - Encodable Structs for Supabase Operations

private struct TherapeuticInsertData: Encodable {
    let patient_id: String
    let therapeutic_name: String
    let therapeutic_type: String
    let category: String?
    let dose_amount: Double?
    let dose_unit: String?
    let doses_per_day: Int?
    let timing_morning: Bool
    let timing_midday: Bool
    let timing_evening: Bool
    let timing_bedtime: Bool
    let timing_with_food: Bool?
    let timing_instructions: String?
    let start_date: String?
    let prescriber_name: String?
    let reason_for_taking: String?
    let notes: String?
    let track_adherence: Bool
    let is_active: Bool
    let data_source: String
}

private struct TherapeuticUpdateData: Encodable {
    let dose_amount: Double?
    let dose_unit: String?
    let doses_per_day: Int?
    let timing_morning: Bool
    let timing_midday: Bool
    let timing_evening: Bool
    let timing_bedtime: Bool
    let timing_with_food: Bool?
    let timing_instructions: String?
    let prescriber_name: String?
    let reason_for_taking: String?
    let notes: String?
    let track_adherence: Bool
}

private struct TherapeuticDiscontinueData: Encodable {
    let is_active: Bool
    let discontinued_reason: String?
    let discontinued_date: String
    let end_date: String
}

private struct TherapeuticReactivateData: Encodable {
    let is_active: Bool
    let discontinued_reason: String?
    let discontinued_date: String?
    let end_date: String?
}

@MainActor
class TherapeuticsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var medications: [PatientTherapeutic] = []
    @Published var supplements: [PatientTherapeutic] = []
    @Published var peptides: [PatientTherapeutic] = []
    @Published var therapeuticsBase: [TherapeuticsBase] = []
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Services

    private let supabase = SupabaseManager.shared.client

    // MARK: - Computed Properties

    var allTherapeutics: [PatientTherapeutic] {
        medications + supplements + peptides
    }

    var activeTherapeutics: [PatientTherapeutic] {
        allTherapeutics.filter { $0.isActive == true }
    }

    var activeMedications: [PatientTherapeutic] {
        medications.filter { $0.isActive == true }
    }

    var activeSupplements: [PatientTherapeutic] {
        supplements.filter { $0.isActive == true }
    }

    var activePeptides: [PatientTherapeutic] {
        peptides.filter { $0.isActive == true }
    }

    // MARK: - Load Data

    func loadTherapeutics() async {
        guard let userId = try? await supabase.auth.session.user.id else {
            error = "Not logged in"
            return
        }

        isLoading = true
        error = nil

        do {
            let allTherapeutics: [PatientTherapeutic] = try await supabase
                .from("patient_therapeutics")
                .select()
                .eq("patient_id", value: userId.uuidString)
                .order("therapeutic_name")
                .execute()
                .value

            // Separate by type
            medications = allTherapeutics.filter { $0.therapeuticType == "medication" }
            supplements = allTherapeutics.filter { $0.therapeuticType == "supplement" }
            peptides = allTherapeutics.filter { $0.therapeuticType == "peptide" }

        } catch {
            self.error = error.localizedDescription
            print("TherapeuticsViewModel: Error loading therapeutics - \(error)")
        }

        isLoading = false
    }

    func loadTherapeuticsBase() async {
        do {
            therapeuticsBase = try await supabase
                .from("therapeutics_base")
                .select()
                .eq("is_active", value: true)
                .order("therapeutic_name")
                .execute()
                .value
        } catch {
            print("TherapeuticsViewModel: Error loading therapeutics base - \(error)")
        }
    }

    // MARK: - CRUD Operations

    func addTherapeutic(
        therapeuticName: String,
        therapeuticType: TherapeuticType,
        category: String?,
        doseAmount: Double?,
        doseUnit: String?,
        dosesPerDay: Int?,
        timingMorning: Bool,
        timingMidday: Bool,
        timingEvening: Bool,
        timingBedtime: Bool,
        timingWithFood: Bool?,
        timingInstructions: String?,
        startDate: Date?,
        prescriberName: String?,
        reasonForTaking: String?,
        notes: String?,
        trackAdherence: Bool = true
    ) async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let insertData = TherapeuticInsertData(
            patient_id: userId.uuidString,
            therapeutic_name: therapeuticName,
            therapeutic_type: therapeuticType.rawValue,
            category: category,
            dose_amount: doseAmount,
            dose_unit: doseUnit,
            doses_per_day: dosesPerDay,
            timing_morning: timingMorning,
            timing_midday: timingMidday,
            timing_evening: timingEvening,
            timing_bedtime: timingBedtime,
            timing_with_food: timingWithFood,
            timing_instructions: timingInstructions,
            start_date: startDate.map { dateFormatter.string(from: $0) },
            prescriber_name: prescriberName,
            reason_for_taking: reasonForTaking,
            notes: notes,
            track_adherence: trackAdherence,
            is_active: true,
            data_source: "manual"
        )

        do {
            let newTherapeutic: PatientTherapeutic = try await supabase
                .from("patient_therapeutics")
                .insert(insertData)
                .select()
                .single()
                .execute()
                .value

            // Add to appropriate list
            switch therapeuticType {
            case .medication:
                medications.append(newTherapeutic)
                medications.sort { $0.therapeuticName < $1.therapeuticName }
            case .supplement:
                supplements.append(newTherapeutic)
                supplements.sort { $0.therapeuticName < $1.therapeuticName }
            case .peptide:
                peptides.append(newTherapeutic)
                peptides.sort { $0.therapeuticName < $1.therapeuticName }
            case .other:
                // Add to supplements as fallback
                supplements.append(newTherapeutic)
                supplements.sort { $0.therapeuticName < $1.therapeuticName }
            }

        } catch {
            print("TherapeuticsViewModel: Error adding therapeutic - \(error)")
        }
    }

    func updateTherapeutic(
        therapeuticId: UUID,
        doseAmount: Double?,
        doseUnit: String?,
        dosesPerDay: Int?,
        timingMorning: Bool,
        timingMidday: Bool,
        timingEvening: Bool,
        timingBedtime: Bool,
        timingWithFood: Bool?,
        timingInstructions: String?,
        prescriberName: String?,
        reasonForTaking: String?,
        notes: String?,
        trackAdherence: Bool
    ) async {
        let updateData = TherapeuticUpdateData(
            dose_amount: doseAmount,
            dose_unit: doseUnit,
            doses_per_day: dosesPerDay,
            timing_morning: timingMorning,
            timing_midday: timingMidday,
            timing_evening: timingEvening,
            timing_bedtime: timingBedtime,
            timing_with_food: timingWithFood,
            timing_instructions: timingInstructions,
            prescriber_name: prescriberName,
            reason_for_taking: reasonForTaking,
            notes: notes,
            track_adherence: trackAdherence
        )

        do {
            let updated: PatientTherapeutic = try await supabase
                .from("patient_therapeutics")
                .update(updateData)
                .eq("id", value: therapeuticId.uuidString)
                .select()
                .single()
                .execute()
                .value

            // Update local state
            updateLocalState(with: updated)

        } catch {
            print("TherapeuticsViewModel: Error updating therapeutic - \(error)")
        }
    }

    func discontinueTherapeutic(
        therapeuticId: UUID,
        reason: String?,
        date: Date = Date()
    ) async {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)

        let discontinueData = TherapeuticDiscontinueData(
            is_active: false,
            discontinued_reason: reason,
            discontinued_date: dateString,
            end_date: dateString
        )

        do {
            let updated: PatientTherapeutic = try await supabase
                .from("patient_therapeutics")
                .update(discontinueData)
                .eq("id", value: therapeuticId.uuidString)
                .select()
                .single()
                .execute()
                .value

            updateLocalState(with: updated)

        } catch {
            print("TherapeuticsViewModel: Error discontinuing therapeutic - \(error)")
        }
    }

    func reactivateTherapeutic(therapeuticId: UUID) async {
        let reactivateData = TherapeuticReactivateData(
            is_active: true,
            discontinued_reason: nil,
            discontinued_date: nil,
            end_date: nil
        )

        do {
            let updated: PatientTherapeutic = try await supabase
                .from("patient_therapeutics")
                .update(reactivateData)
                .eq("id", value: therapeuticId.uuidString)
                .select()
                .single()
                .execute()
                .value

            updateLocalState(with: updated)

        } catch {
            print("TherapeuticsViewModel: Error reactivating therapeutic - \(error)")
        }
    }

    func deleteTherapeutic(therapeuticId: UUID) async {
        do {
            try await supabase
                .from("patient_therapeutics")
                .delete()
                .eq("id", value: therapeuticId.uuidString)
                .execute()

            // Remove from local state
            medications.removeAll { $0.id == therapeuticId }
            supplements.removeAll { $0.id == therapeuticId }
            peptides.removeAll { $0.id == therapeuticId }

        } catch {
            print("TherapeuticsViewModel: Error deleting therapeutic - \(error)")
        }
    }

    // MARK: - Helpers

    private func updateLocalState(with therapeutic: PatientTherapeutic) {
        // Update in the appropriate list based on type
        switch therapeutic.type {
        case .medication:
            if let index = medications.firstIndex(where: { $0.id == therapeutic.id }) {
                medications[index] = therapeutic
            }
        case .supplement:
            if let index = supplements.firstIndex(where: { $0.id == therapeutic.id }) {
                supplements[index] = therapeutic
            }
        case .peptide:
            if let index = peptides.firstIndex(where: { $0.id == therapeutic.id }) {
                peptides[index] = therapeutic
            }
        case .other:
            // Check all lists
            if let index = medications.firstIndex(where: { $0.id == therapeutic.id }) {
                medications[index] = therapeutic
            } else if let index = supplements.firstIndex(where: { $0.id == therapeutic.id }) {
                supplements[index] = therapeutic
            } else if let index = peptides.firstIndex(where: { $0.id == therapeutic.id }) {
                peptides[index] = therapeutic
            }
        }
    }

    // MARK: - Search/Filter

    func searchTherapeuticsBase(query: String, type: TherapeuticType? = nil) -> [TherapeuticsBase] {
        var results = therapeuticsBase

        if let type = type {
            results = results.filter { $0.therapeuticType == type.rawValue }
        }

        if !query.isEmpty {
            results = results.filter {
                $0.therapeuticName.localizedCaseInsensitiveContains(query)
            }
        }

        return results
    }
}
