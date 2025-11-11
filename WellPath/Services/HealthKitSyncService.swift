//
//  HealthKitSyncService.swift
//  WellPath
//
//  Automatically syncs HealthKit data to the backend
//

import Foundation
import HealthKit

@MainActor
class HealthKitSyncService: ObservableObject {
    static let shared = HealthKitSyncService()

    private let healthStore = HKHealthStore()
    private let supabase = SupabaseManager.shared.client
    private let mapper = HealthKitFieldMapper.shared

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?

    private init() {
        loadLastSyncDate()
    }

    // MARK: - Sync Control

    /// Perform a full sync of all supported HealthKit data
    func performFullSync() async {
        guard !isSyncing else {
            print("⚠️ Sync already in progress")
            return
        }

        isSyncing = true
        syncError = nil
        print("🔄 Starting HealthKit sync...")

        do {
            // Load field mappings
            try await mapper.loadMappings()

            // Sync different data types
            try await syncProtein()
            try await syncSteps()
            try await syncWater()
            try await syncWeight()
            try await syncSleep()

            // Update last sync date
            lastSyncDate = Date()
            saveLastSyncDate()

            print("✅ HealthKit sync completed successfully")

        } catch {
            syncError = error.localizedDescription
            print("❌ HealthKit sync failed: \(error)")
        }

        isSyncing = false
    }

    // MARK: - Individual Data Type Syncs

    private func syncProtein() async throws {
        print("🥩 Syncing protein data...")

        guard let proteinType = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) else {
            throw HealthKitSyncError.dataTypeNotAvailable
        }

        let fieldId = try await mapper.getFieldId(for: "HKQuantityTypeIdentifierDietaryProtein")
        let samples = try await fetchQuantitySamples(type: proteinType, since: lastSyncDate ?? Date().addingTimeInterval(-7*24*60*60))

        try await writeSamplesToBackend(samples: samples, fieldId: fieldId, unit: .gram())
        print("✅ Synced \(samples.count) protein entries")
    }

    private func syncSteps() async throws {
        print("👣 Syncing steps data...")

        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitSyncError.dataTypeNotAvailable
        }

        let fieldId = try await mapper.getFieldId(for: "HKQuantityTypeIdentifierStepCount")
        let samples = try await fetchQuantitySamples(type: stepsType, since: lastSyncDate ?? Date().addingTimeInterval(-7*24*60*60))

        try await writeSamplesToBackend(samples: samples, fieldId: fieldId, unit: .count())
        print("✅ Synced \(samples.count) step entries")
    }

    private func syncWater() async throws {
        print("💧 Syncing water data...")

        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else {
            throw HealthKitSyncError.dataTypeNotAvailable
        }

        let fieldId = try await mapper.getFieldId(for: "HKQuantityTypeIdentifierDietaryWater")
        let samples = try await fetchQuantitySamples(type: waterType, since: lastSyncDate ?? Date().addingTimeInterval(-7*24*60*60))

        try await writeSamplesToBackend(samples: samples, fieldId: fieldId, unit: .literUnit(with: .milli))
        print("✅ Synced \(samples.count) water entries")
    }

    private func syncWeight() async throws {
        print("⚖️ Syncing weight data...")

        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            throw HealthKitSyncError.dataTypeNotAvailable
        }

        let fieldId = try await mapper.getFieldId(for: "HKQuantityTypeIdentifierBodyMass")
        let samples = try await fetchQuantitySamples(type: weightType, since: lastSyncDate ?? Date().addingTimeInterval(-7*24*60*60))

        try await writeSamplesToBackend(samples: samples, fieldId: fieldId, unit: .gramUnit(with: .kilo))
        print("✅ Synced \(samples.count) weight entries")
    }

    private func syncSleep() async throws {
        print("😴 Syncing sleep data...")

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitSyncError.dataTypeNotAvailable
        }

        let samples = try await fetchCategorySamples(type: sleepType, since: lastSyncDate ?? Date().addingTimeInterval(-7*24*60*60))

        // Get field IDs for sleep period fields
        let startFieldId = try await mapper.getFieldId(for: "HKCategoryTypeIdentifierSleepAnalysis")
        let endFieldId = startFieldId // Same for now
        let typeFieldId = startFieldId // Same for now

        // Get reference types for sleep stages
        let sleepStageTypes = try await fetchSleepStageTypes()

        for sample in samples {
            let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value)
            let healthKitIdentifier = mapSleepValueToHealthKitIdentifier(sleepValue)

            // Find matching sleep stage type
            guard let stageType = sleepStageTypes.first(where: { $0.healthkitIdentifier == healthKitIdentifier }) else {
                print("⚠️ No stage type found for \(healthKitIdentifier)")
                continue
            }

            // Write sleep period entry (start, end, type) with same event_instance_id
            try await writeSleepPeriod(
                sample: sample,
                stageTypeId: stageType.id,
                startFieldId: startFieldId,
                endFieldId: endFieldId,
                typeFieldId: typeFieldId
            )
        }

        print("✅ Synced \(samples.count) sleep periods")
    }

    // MARK: - HealthKit Queries

    private func fetchQuantitySamples(type: HKQuantityType, since: Date) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(withStart: since, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let quantitySamples = samples as? [HKQuantitySample] ?? []
                continuation.resume(returning: quantitySamples)
            }

            healthStore.execute(query)
        }
    }

    private func fetchCategorySamples(type: HKCategoryType, since: Date) async throws -> [HKCategorySample] {
        let predicate = HKQuery.predicateForSamples(withStart: since, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let categorySamples = samples as? [HKCategorySample] ?? []
                continuation.resume(returning: categorySamples)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Backend Writes

    private func writeSamplesToBackend(samples: [HKQuantitySample], fieldId: String, unit: HKUnit) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw HealthKitSyncError.notAuthenticated
        }

        var entries: [PatientDataEntry] = []

        for sample in samples {
            // Skip if already synced (check by healthkit_uuid)
            if try await isAlreadySynced(healthKitUUID: sample.uuid.uuidString) {
                continue
            }

            let value = sample.quantity.doubleValue(for: unit)
            let dateFormatter = ISO8601DateFormatter()
            let timestampString = dateFormatter.string(from: sample.startDate)

            // Extract date only using ORIGINAL timezone from HealthKit metadata
            let sampleTimeZone = getOriginalTimeZone(from: sample)
            let dateOnlyFormatter = DateFormatter()
            dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
            dateOnlyFormatter.timeZone = sampleTimeZone  // Use original timezone
            let dateString = dateOnlyFormatter.string(from: sample.startDate)

            entries.append(PatientDataEntry(
                patientId: userId.uuidString,
                fieldId: fieldId,
                entryDate: dateString,
                entryTimestamp: timestampString,
                valueQuantity: value,
                valueTimestamp: nil,
                valueReference: nil,
                source: "healthkit",
                healthkitUuid: sample.uuid.uuidString,
                healthkitSourceName: sample.sourceRevision.source.name,
                eventInstanceId: nil
            ))
        }

        if !entries.isEmpty {
            _ = try await supabase
                .from("patient_data_entries")
                .insert(entries)
                .execute()
        }
    }

    private func writeSleepPeriod(sample: HKCategorySample, stageTypeId: UUID, startFieldId: String, endFieldId: String, typeFieldId: String) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw HealthKitSyncError.notAuthenticated
        }

        // Skip if already synced
        if try await isAlreadySynced(healthKitUUID: sample.uuid.uuidString) {
            return
        }

        let eventInstanceId = UUID().uuidString
        let dateFormatter = ISO8601DateFormatter()

        // Extract date using ORIGINAL timezone from HealthKit metadata
        let sampleTimeZone = getOriginalTimeZone(from: sample)
        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
        dateOnlyFormatter.timeZone = sampleTimeZone  // Use original timezone
        let dateString = dateOnlyFormatter.string(from: sample.startDate)

        let entries: [PatientDataEntry] = [
            PatientDataEntry(
                patientId: userId.uuidString,
                fieldId: startFieldId,
                entryDate: dateString,
                entryTimestamp: dateFormatter.string(from: sample.startDate),
                valueQuantity: nil,
                valueTimestamp: dateFormatter.string(from: sample.startDate),
                valueReference: nil,
                source: "healthkit",
                healthkitUuid: sample.uuid.uuidString + "_start",
                healthkitSourceName: sample.sourceRevision.source.name,
                eventInstanceId: eventInstanceId
            ),
            PatientDataEntry(
                patientId: userId.uuidString,
                fieldId: endFieldId,
                entryDate: dateString,
                entryTimestamp: dateFormatter.string(from: sample.endDate),
                valueQuantity: nil,
                valueTimestamp: dateFormatter.string(from: sample.endDate),
                valueReference: nil,
                source: "healthkit",
                healthkitUuid: sample.uuid.uuidString + "_end",
                healthkitSourceName: sample.sourceRevision.source.name,
                eventInstanceId: eventInstanceId
            ),
            PatientDataEntry(
                patientId: userId.uuidString,
                fieldId: typeFieldId,
                entryDate: dateString,
                entryTimestamp: dateFormatter.string(from: sample.startDate),
                valueQuantity: nil,
                valueTimestamp: nil,
                valueReference: stageTypeId.uuidString,
                source: "healthkit",
                healthkitUuid: sample.uuid.uuidString + "_type",
                healthkitSourceName: sample.sourceRevision.source.name,
                eventInstanceId: eventInstanceId
            )
        ]

        _ = try await supabase
            .from("patient_data_entries")
            .insert(entries)
            .execute()
    }

    private func isAlreadySynced(healthKitUUID: String) async throws -> Bool {
        let count: Int = try await supabase
            .from("patient_data_entries")
            .select("id", head: false, count: .exact)
            .eq("healthkit_uuid", value: healthKitUUID)
            .execute()
            .count ?? 0

        return count > 0
    }

    // MARK: - Helper Methods

    /// Extract timezone from HealthKit sample metadata, or fallback to device timezone
    private func getOriginalTimeZone(from sample: HKSample) -> TimeZone {
        // Try to get timezone from HealthKit metadata
        if let tzString = sample.metadata?[HKMetadataKeyTimeZone] as? String,
           let timeZone = TimeZone(identifier: tzString) {
            print("📍 Using original timezone from HealthKit: \(tzString)")
            return timeZone
        }

        // Fallback to device current timezone
        print("⚠️ No timezone metadata, using device timezone: \(TimeZone.current.identifier)")
        return TimeZone.current
    }

    private func fetchSleepStageTypes() async throws -> [SleepStageType] {
        return try await supabase
            .from("def_ref_sleep_period_types")
            .select()
            .execute()
            .value
    }

    private func mapSleepValueToHealthKitIdentifier(_ value: HKCategoryValueSleepAnalysis?) -> String {
        guard let value = value else { return "HKCategoryValueSleepAnalysisInBed" }

        switch value {
        case .inBed:
            return "HKCategoryValueSleepAnalysisInBed"
        case .asleepUnspecified:
            return "HKCategoryValueSleepAnalysisAsleepUnspecified"
        case .awake:
            return "HKCategoryValueSleepAnalysisAwake"
        case .asleepCore:
            return "HKCategoryValueSleepAnalysisAsleepCore"
        case .asleepDeep:
            return "HKCategoryValueSleepAnalysisAsleepDeep"
        case .asleepREM:
            return "HKCategoryValueSleepAnalysisAsleepREM"
        @unknown default:
            return "HKCategoryValueSleepAnalysisAsleepUnspecified"
        }
    }

    // MARK: - Persistence

    private func loadLastSyncDate() {
        if let timestamp = UserDefaults.standard.object(forKey: "lastHealthKitSync") as? Date {
            lastSyncDate = timestamp
        }
    }

    private func saveLastSyncDate() {
        UserDefaults.standard.set(lastSyncDate, forKey: "lastHealthKitSync")
    }
}

// MARK: - Models

struct PatientDataEntry: Codable {
    let patientId: String
    let fieldId: String
    let entryDate: String
    let entryTimestamp: String?
    let valueQuantity: Double?
    let valueTimestamp: String?
    let valueReference: String?
    let source: String
    let healthkitUuid: String
    let healthkitSourceName: String
    let eventInstanceId: String?

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case fieldId = "field_id"
        case entryDate = "entry_date"
        case entryTimestamp = "entry_timestamp"
        case valueQuantity = "value_quantity"
        case valueTimestamp = "value_timestamp"
        case valueReference = "value_reference"
        case source
        case healthkitUuid = "healthkit_uuid"
        case healthkitSourceName = "healthkit_source_name"
        case eventInstanceId = "event_instance_id"
    }
}

struct SleepStageType: Codable {
    let id: UUID
    let periodName: String
    let healthkitIdentifier: String

    enum CodingKeys: String, CodingKey {
        case id
        case periodName = "period_name"
        case healthkitIdentifier = "healthkit_identifier"
    }
}

// MARK: - Errors

enum HealthKitSyncError: Error, LocalizedError {
    case dataTypeNotAvailable
    case notAuthenticated
    case syncInProgress

    var errorDescription: String? {
        switch self {
        case .dataTypeNotAvailable:
            return "HealthKit data type not available"
        case .notAuthenticated:
            return "User not authenticated"
        case .syncInProgress:
            return "Sync already in progress"
        }
    }
}
