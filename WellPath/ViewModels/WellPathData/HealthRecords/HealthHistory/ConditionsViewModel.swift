//
//  ConditionsViewModel.swift
//  WellPath
//
//  ViewModel for conditions and functional limitations tracking.
//  Combines personal conditions, family history, and physical limitations.
//

import Foundation
import SwiftUI
import Supabase

// MARK: - Conditions ViewModel

@MainActor
class ConditionsViewModel: ObservableObject {
    @Published var personalConditions: [PatientCondition] = []
    @Published var familyConditions: [PatientCondition] = []
    @Published var limitations: [FunctionalLimitation] = []

    @Published var isLoading = false
    @Published var error: Error?

    private let supabase = SupabaseManager.shared.client

    // MARK: - Load All Data

    func loadAllData() async {
        guard let userId = try? await supabase.auth.session.user.id else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            async let personalTask = fetchPersonalConditions(userId: userId)
            async let familyTask = fetchFamilyConditions(userId: userId)
            async let limitationsTask = fetchLimitations(userId: userId)

            let (personal, family, limits) = try await (personalTask, familyTask, limitationsTask)

            personalConditions = personal
            familyConditions = family
            limitations = limits

        } catch {
            self.error = error
            print("Error loading conditions data: \(error)")
        }
    }

    // MARK: - Fetch Conditions

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

    // MARK: - Limitations CRUD

    private func fetchLimitations(userId: UUID) async throws -> [FunctionalLimitation] {
        try await supabase
            .from("functional_limitations")
            .select()
            .eq("patient_id", value: userId.uuidString)
            .eq("is_active", value: true)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func addLimitation(
        limitationType: String,
        limitationName: String,
        description: String?,
        severity: String?,
        onsetDate: Date?,
        isTemporary: Bool,
        expectedDurationMonths: Int?,
        affectsActivities: [String],
        accommodationsNeeded: String?,
        notes: String?
    ) async {
        guard let userId = try? await supabase.auth.session.user.id else {
            return
        }

        do {
            let insert = FunctionalLimitationInsert(
                patientId: userId.uuidString,
                limitationType: limitationType,
                limitationName: limitationName,
                description: description,
                severity: severity,
                onsetDate: onsetDate,
                isTemporary: isTemporary,
                expectedDurationMonths: expectedDurationMonths,
                affectsActivities: affectsActivities,
                accommodationsNeeded: accommodationsNeeded,
                notes: notes
            )

            try await supabase
                .from("functional_limitations")
                .insert(insert)
                .execute()

            await loadAllData()
        } catch {
            self.error = error
            print("Error adding limitation: \(error)")
        }
    }

    func updateLimitation(id: UUID, severity: String?, notes: String?, isActive: Bool) async {
        do {
            let update = LimitationUpdatePayload(
                severity: severity,
                notes: notes,
                isActive: isActive,
                updatedAt: Date()
            )

            try await supabase
                .from("functional_limitations")
                .update(update)
                .eq("id", value: id.uuidString)
                .execute()

            await loadAllData()
        } catch {
            self.error = error
            print("Error updating limitation: \(error)")
        }
    }

    func deleteLimitation(id: UUID) async {
        do {
            try await supabase
                .from("functional_limitations")
                .update(["is_active": false])
                .eq("id", value: id.uuidString)
                .execute()

            await loadAllData()
        } catch {
            self.error = error
            print("Error deleting limitation: \(error)")
        }
    }

    // MARK: - Condition Management

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

            try await supabase
                .from("patient_conditions")
                .insert(record)
                .execute()

            await loadAllData()
        } catch {
            print("Error adding condition: \(error)")
        }
    }

    func deleteCondition(conditionId: UUID) async {
        do {
            try await supabase
                .from("patient_conditions")
                .update(["is_active": false])
                .eq("id", value: conditionId.uuidString)
                .execute()

            await loadAllData()
        } catch {
            print("Error deleting condition: \(error)")
        }
    }

    // MARK: - Helper Methods

    func getConditionCategoryCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        for condition in personalConditions {
            let category = condition.conditionCategory ?? "Other"
            counts[category, default: 0] += 1
        }
        return counts
    }

    func getLimitationTypeCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        for limitation in limitations {
            counts[limitation.limitationType, default: 0] += 1
        }
        return counts
    }
}

// MARK: - Functional Limitation Model

struct FunctionalLimitation: Codable, Identifiable {
    let id: UUID
    let patientId: UUID
    let limitationType: String
    let limitationName: String
    let description: String?
    let severity: String?
    let onsetDate: Date?
    let isTemporary: Bool
    let expectedDurationMonths: Int?
    let affectsActivities: [String]?
    let accommodationsNeeded: String?
    let notes: String?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case limitationType = "limitation_type"
        case limitationName = "limitation_name"
        case description
        case severity
        case onsetDate = "onset_date"
        case isTemporary = "is_temporary"
        case expectedDurationMonths = "expected_duration_months"
        case affectsActivities = "affects_activities"
        case accommodationsNeeded = "accommodations_needed"
        case notes
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var severityLevel: SeverityLevel {
        switch severity?.lowercased() {
        case "mild": return .mild
        case "moderate": return .moderate
        case "severe": return .severe
        default: return .mild
        }
    }

    var limitationTypeInfo: LimitationType {
        LimitationType(rawValue: limitationType) ?? .other
    }
}

struct FunctionalLimitationInsert: Encodable {
    let patientId: String
    let limitationType: String
    let limitationName: String
    let description: String?
    let severity: String?
    let onsetDate: Date?
    let isTemporary: Bool
    let expectedDurationMonths: Int?
    let affectsActivities: [String]
    let accommodationsNeeded: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case limitationType = "limitation_type"
        case limitationName = "limitation_name"
        case description
        case severity
        case onsetDate = "onset_date"
        case isTemporary = "is_temporary"
        case expectedDurationMonths = "expected_duration_months"
        case affectsActivities = "affects_activities"
        case accommodationsNeeded = "accommodations_needed"
        case notes
    }
}

struct LimitationUpdatePayload: Encodable {
    let severity: String?
    let notes: String?
    let isActive: Bool
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case severity
        case notes
        case isActive = "is_active"
        case updatedAt = "updated_at"
    }
}

// MARK: - Supporting Enums

enum LimitationType: String, CaseIterable, Identifiable {
    case mobility = "mobility"
    case vision = "vision"
    case hearing = "hearing"
    case cognitive = "cognitive"
    case pain = "pain"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mobility: return "Mobility"
        case .vision: return "Vision"
        case .hearing: return "Hearing"
        case .cognitive: return "Cognitive"
        case .pain: return "Chronic Pain"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .mobility: return "figure.walk"
        case .vision: return "eye"
        case .hearing: return "ear"
        case .cognitive: return "brain.head.profile"
        case .pain: return "bolt.heart"
        case .other: return "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .mobility: return .blue
        case .vision: return .purple
        case .hearing: return .orange
        case .cognitive: return .pink
        case .pain: return .red
        case .other: return .gray
        }
    }
}

enum SeverityLevel: String, CaseIterable {
    case mild = "mild"
    case moderate = "moderate"
    case severe = "severe"

    var displayName: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .mild: return .green
        case .moderate: return .orange
        case .severe: return .red
        }
    }
}
