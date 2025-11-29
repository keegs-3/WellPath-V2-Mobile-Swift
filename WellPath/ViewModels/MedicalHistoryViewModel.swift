//
//  MedicalHistoryViewModel.swift
//  WellPath
//
//  ViewModel for medical history management.
//  Handles personal conditions, family history, and preventive screenings.
//

import SwiftUI

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

    private let surveyService = SurveyService.shared
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
            async let personalTask = surveyService.fetchPersonalConditions(patientId: userId)
            async let familyTask = surveyService.fetchFamilyConditions(patientId: userId)

            let (personal, family) = try await (personalTask, familyTask)

            personalConditions = personal
            familyConditions = family

        } catch {
            self.error = error.localizedDescription
            print("MedicalHistoryViewModel: Error loading conditions - \(error)")
        }

        isLoading = false
    }

    func loadScreenings() async {
        guard let userId = try? await supabase.auth.session.user.id else {
            error = "Not logged in"
            return
        }

        isLoading = true
        error = nil

        do {
            async let screeningsTask = surveyService.fetchScreenings(patientId: userId)
            async let typesTask = surveyService.fetchScreeningTypes()

            let (fetchedScreenings, fetchedTypes) = try await (screeningsTask, typesTask)

            screenings = fetchedScreenings
            screeningTypes = fetchedTypes

        } catch {
            self.error = error.localizedDescription
            print("MedicalHistoryViewModel: Error loading screenings - \(error)")
        }

        isLoading = false
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
            let newCondition = try await surveyService.addCondition(
                patientId: userId,
                conditionId: conditionId,
                conditionName: conditionName,
                conditionCategory: conditionCategory,
                historyType: historyType,
                familyMemberRelationship: familyMemberRelationship,
                diagnosisDate: diagnosisDate,
                notes: notes
            )

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
            let updated = try await surveyService.updateCondition(
                conditionId: conditionId,
                severity: severity,
                status: status,
                notes: notes
            )

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
            try await surveyService.deleteCondition(conditionId: conditionId)

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
            let screening = try await surveyService.upsertScreening(
                patientId: userId,
                screeningTypeId: screeningTypeId,
                screeningStatus: screeningStatus,
                screeningDate: screeningDate,
                nextDueDate: nextDueDate,
                resultSummary: resultSummary,
                notes: notes
            )

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
            try await surveyService.deleteScreening(screeningId: screeningId)
            screenings.removeAll { $0.id == screeningId }
        } catch {
            print("MedicalHistoryViewModel: Error deleting screening - \(error)")
        }
    }
}
