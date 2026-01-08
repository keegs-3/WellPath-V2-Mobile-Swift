//
//  MedicalHistoryViewModel.swift
//  WellPath
//
//  ViewModel for personal and family medical history management.
//  Handles loading condition types, relative types, and patient history data.
//

import SwiftUI

@MainActor
class MedicalHistoryViewModel: ObservableObject {
    // MARK: - Published Properties

    // Reference data
    @Published var historyTypes: [HistoryType] = []
    @Published var relativeTypes: [RelativeType] = []

    // Patient data
    @Published var personalHistory: [PatientHistorySample] = []
    @Published var familyHistory: [PatientHistorySample] = []

    // Grouped data for display
    @Published var personalByCategory: [HistoryCategory: [HistoryEntry]] = [:]
    @Published var familyByCategory: [HistoryCategory: [HistoryEntry]] = [:]

    // Completion status
    @Published var isPersonalComplete: Bool = false
    @Published var isFamilyComplete: Bool = false
    @Published var isFullyComplete: Bool = false

    // Loading states
    @Published var isLoading = false
    @Published var error: String?

    // Patient info for filtering
    @Published var patientGender: String?

    // MARK: - Services

    private let supabase = SupabaseManager.shared.client

    // MARK: - Computed Properties

    var allHistory: [PatientHistorySample] {
        personalHistory + familyHistory
    }

    var personalConditionCount: Int {
        personalHistory.count
    }

    var familyConditionCount: Int {
        familyHistory.count
    }

    /// History types grouped by category
    var historyTypesByCategory: [HistoryCategory: [HistoryType]] {
        Dictionary(grouping: historyTypes) { $0.categoryEnum }
    }

    /// History types filtered by patient gender
    func filteredHistoryTypes(for category: HistoryCategory) -> [HistoryType] {
        historyTypes.filter { type in
            type.categoryEnum == category && type.appliesTo(gender: patientGender)
        }
    }

    /// First-degree relatives only
    var firstDegreeRelatives: [RelativeType] {
        relativeTypes.filter { $0.isFirstDegree }
    }

    /// Second-degree relatives only
    var secondDegreeRelatives: [RelativeType] {
        relativeTypes.filter { !$0.isFirstDegree && $0.isBloodRelative }
    }

    // MARK: - Load Data

    func loadAll() async {
        isLoading = true
        error = nil

        do {
            // Load reference data and patient data in parallel
            async let typesTask = loadHistoryTypes()
            async let relativesTask = loadRelativeTypes()
            async let patientTask = loadPatientHistory()
            async let genderTask = loadPatientGender()
            async let statusTask = loadCompletionStatus()

            _ = try await (typesTask, relativesTask, patientTask, genderTask, statusTask)

            // Build grouped data
            buildGroupedData()

        } catch {
            self.error = error.localizedDescription
            print("MedicalHistoryViewModel: Error loading data - \(error)")
        }

        isLoading = false
    }

    private func loadHistoryTypes() async throws {
        historyTypes = try await supabase
            .from("sample_history_types")
            .select()
            .eq("is_active", value: true)
            .order("display_order")
            .execute()
            .value
    }

    private func loadRelativeTypes() async throws {
        relativeTypes = try await supabase
            .from("sample_relative_types")
            .select()
            .eq("is_active", value: true)
            .order("display_order")
            .execute()
            .value
    }

    private func loadPatientHistory() async throws {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        let allHistory: [PatientHistorySample] = try await supabase
            .from("patient_history_samples")
            .select()
            .eq("patient_id", value: userId.uuidString)
            .eq("is_current", value: true)
            .execute()
            .value

        personalHistory = allHistory.filter { $0.historyScope == "personal" }
        familyHistory = allHistory.filter { $0.historyScope == "family" }
    }

    private func loadPatientGender() async throws {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        struct GenderResult: Codable {
            let value: Double?
            let metadata: [String: String]?
        }

        let results: [GenderResult] = try await supabase
            .from("patient_baseline_samples")
            .select("value, metadata")
            .eq("patient_id", value: userId.uuidString)
            .eq("baseline_type", value: "gender")
            .eq("is_current", value: true)
            .limit(1)
            .execute()
            .value

        if let result = results.first {
            // Gender might be stored as value (1=M, 2=F) or in metadata
            if let val = result.value {
                patientGender = val == 1 ? "M" : "F"
            } else if let meta = result.metadata, let g = meta["gender"] {
                patientGender = g
            }
        }
    }

    private func loadCompletionStatus() async throws {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        struct CompletionResult: Codable {
            let baselineType: String

            enum CodingKeys: String, CodingKey {
                case baselineType = "baseline_type"
            }
        }

        let results: [CompletionResult] = try await supabase
            .from("patient_baseline_samples")
            .select("baseline_type")
            .eq("patient_id", value: userId.uuidString)
            .in("baseline_type", values: [
                "medical_history_personal_complete",
                "medical_history_family_complete",
                "medical_history_complete"
            ])
            .eq("is_current", value: true)
            .execute()
            .value

        let completedTypes = Set(results.map { $0.baselineType })
        isPersonalComplete = completedTypes.contains("medical_history_personal_complete")
        isFamilyComplete = completedTypes.contains("medical_history_family_complete")
        isFullyComplete = completedTypes.contains("medical_history_complete")
    }

    private func buildGroupedData() {
        // Build lookup dictionaries
        let typesByKey = Dictionary(uniqueKeysWithValues: historyTypes.map { ($0.historyType, $0) })
        let relativesByKey = Dictionary(uniqueKeysWithValues: relativeTypes.map { ($0.relativeType, $0) })

        // Build personal entries
        var personalGroups: [HistoryCategory: [HistoryEntry]] = [:]
        for sample in personalHistory {
            guard let type = typesByKey[sample.historyType] else { continue }
            let entry = HistoryEntry(id: sample.id, sample: sample, type: type, relative: nil)
            personalGroups[type.categoryEnum, default: []].append(entry)
        }
        personalByCategory = personalGroups

        // Build family entries
        var familyGroups: [HistoryCategory: [HistoryEntry]] = [:]
        for sample in familyHistory {
            guard let type = typesByKey[sample.historyType] else { continue }
            let relative = sample.relativeType.flatMap { relativesByKey[$0] }
            let entry = HistoryEntry(id: sample.id, sample: sample, type: type, relative: relative)
            familyGroups[type.categoryEnum, default: []].append(entry)
        }
        familyByCategory = familyGroups
    }

    // MARK: - CRUD Operations

    func addPersonalCondition(
        historyType: String,
        ageAtDiagnosis: Int?,
        diagnosisYear: Int?,
        isConfirmed: Bool = true,
        notes: String?
    ) async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        let insert = PatientHistoryInsert(
            patientId: userId.uuidString,
            historyType: historyType,
            historyScope: "personal",
            relativeType: nil,
            relativeCount: nil,
            ageAtDiagnosis: ageAtDiagnosis,
            diagnosisYear: diagnosisYear,
            isConfirmed: isConfirmed,
            isDeceasedFromCondition: nil,
            notes: notes,
            source: "manual",
            isCurrent: true
        )

        do {
            let newSample: PatientHistorySample = try await supabase
                .from("patient_history_samples")
                .insert(insert)
                .select()
                .single()
                .execute()
                .value

            personalHistory.append(newSample)
            buildGroupedData()
        } catch {
            print("MedicalHistoryViewModel: Error adding personal condition - \(error)")
        }
    }

    func addFamilyCondition(
        historyType: String,
        relativeType: String,
        relativeCount: Int = 1,
        ageAtDiagnosis: Int?,
        isDeceasedFromCondition: Bool?,
        notes: String?
    ) async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        let insert = PatientHistoryInsert(
            patientId: userId.uuidString,
            historyType: historyType,
            historyScope: "family",
            relativeType: relativeType,
            relativeCount: relativeCount,
            ageAtDiagnosis: ageAtDiagnosis,
            diagnosisYear: nil,
            isConfirmed: true,
            isDeceasedFromCondition: isDeceasedFromCondition,
            notes: notes,
            source: "manual",
            isCurrent: true
        )

        do {
            let newSample: PatientHistorySample = try await supabase
                .from("patient_history_samples")
                .insert(insert)
                .select()
                .single()
                .execute()
                .value

            familyHistory.append(newSample)
            buildGroupedData()
        } catch {
            print("MedicalHistoryViewModel: Error adding family condition - \(error)")
        }
    }

    func updateCondition(
        id: UUID,
        relativeType: String? = nil,
        relativeCount: Int? = nil,
        ageAtDiagnosis: Int? = nil,
        diagnosisYear: Int? = nil,
        isConfirmed: Bool? = nil,
        isDeceasedFromCondition: Bool? = nil,
        notes: String? = nil
    ) async {
        let update = PatientHistoryUpdate(
            relativeType: relativeType,
            relativeCount: relativeCount,
            ageAtDiagnosis: ageAtDiagnosis,
            diagnosisYear: diagnosisYear,
            isConfirmed: isConfirmed,
            isDeceasedFromCondition: isDeceasedFromCondition,
            notes: notes
        )

        do {
            let updated: PatientHistorySample = try await supabase
                .from("patient_history_samples")
                .update(update)
                .eq("id", value: id.uuidString)
                .select()
                .single()
                .execute()
                .value

            // Update local state
            if updated.historyScope == "personal" {
                if let index = personalHistory.firstIndex(where: { $0.id == id }) {
                    personalHistory[index] = updated
                }
            } else {
                if let index = familyHistory.firstIndex(where: { $0.id == id }) {
                    familyHistory[index] = updated
                }
            }
            buildGroupedData()
        } catch {
            print("MedicalHistoryViewModel: Error updating condition - \(error)")
        }
    }

    func deleteCondition(id: UUID) async {
        do {
            // Soft delete by setting is_current = false
            struct SoftDelete: Encodable {
                let isCurrent: Bool
                let supersededAt: String

                enum CodingKeys: String, CodingKey {
                    case isCurrent = "is_current"
                    case supersededAt = "superseded_at"
                }
            }

            try await supabase
                .from("patient_history_samples")
                .update(SoftDelete(
                    isCurrent: false,
                    supersededAt: ISO8601DateFormatter().string(from: Date())
                ))
                .eq("id", value: id.uuidString)
                .execute()

            // Remove from local state
            personalHistory.removeAll { $0.id == id }
            familyHistory.removeAll { $0.id == id }
            buildGroupedData()
        } catch {
            print("MedicalHistoryViewModel: Error deleting condition - \(error)")
        }
    }

    // MARK: - Completion Management

    func markPersonalComplete() async {
        await markComplete(type: "medical_history_personal_complete")
        isPersonalComplete = true
        await checkAndMarkFullyComplete()
    }

    func markFamilyComplete() async {
        await markComplete(type: "medical_history_family_complete")
        isFamilyComplete = true
        await checkAndMarkFullyComplete()
    }

    private func checkAndMarkFullyComplete() async {
        if isPersonalComplete && isFamilyComplete && !isFullyComplete {
            await markComplete(type: "medical_history_complete")
            isFullyComplete = true
        }
    }

    private func markComplete(type: String) async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        struct BaselineInsert: Encodable {
            let patientId: String
            let baselineType: String
            let value: Double
            let source: String
            let isCurrent: Bool

            enum CodingKeys: String, CodingKey {
                case patientId = "patient_id"
                case baselineType = "baseline_type"
                case value
                case source
                case isCurrent = "is_current"
            }
        }

        do {
            try await supabase
                .from("patient_baseline_samples")
                .insert(BaselineInsert(
                    patientId: userId.uuidString,
                    baselineType: type,
                    value: 1,
                    source: "onboarding",
                    isCurrent: true
                ))
                .execute()
        } catch {
            print("MedicalHistoryViewModel: Error marking complete - \(error)")
        }
    }

    // MARK: - Risk Calculation

    func getScreeningRisk(for screeningType: String) async -> ScreeningRiskResult? {
        guard let userId = try? await supabase.auth.session.user.id else { return nil }

        do {
            let result: [ScreeningRiskResult] = try await supabase
                .rpc("calculate_screening_risk", params: [
                    "p_patient_id": userId.uuidString,
                    "p_screening_type": screeningType
                ])
                .execute()
                .value

            return result.first
        } catch {
            print("MedicalHistoryViewModel: Error getting screening risk - \(error)")
            return nil
        }
    }

    // MARK: - Helpers

    func historyType(for key: String) -> HistoryType? {
        historyTypes.first { $0.historyType == key }
    }

    func relativeType(for key: String) -> RelativeType? {
        relativeTypes.first { $0.relativeType == key }
    }

    func hasCondition(_ historyType: String, scope: HistoryScope) -> Bool {
        let samples = scope == .personal ? personalHistory : familyHistory
        return samples.contains { $0.historyType == historyType }
    }

    func getConditions(for historyType: String, scope: HistoryScope) -> [PatientHistorySample] {
        let samples = scope == .personal ? personalHistory : familyHistory
        return samples.filter { $0.historyType == historyType }
    }
}
