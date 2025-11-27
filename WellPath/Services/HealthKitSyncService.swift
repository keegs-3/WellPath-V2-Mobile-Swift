//
//  HealthKitSyncService.swift
//  WellPath
//
//  Automatically syncs HealthKit data to the unified patient_samples table
//

import Foundation
import HealthKit
import Supabase

@MainActor
class HealthKitSyncService: ObservableObject {
    static let shared = HealthKitSyncService()

    private let healthStore = HKHealthStore()
    private let supabase = SupabaseManager.shared.client

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?

    private init() {
        loadLastSyncDate()
    }

    // MARK: - Background Observers

    /// Enable background delivery for automatic syncing when HealthKit data changes
    func enableBackgroundDelivery() async {
        print("🔔 Setting up HealthKit background observers...")

        // Data types to observe
        let typesToObserve: [HKSampleType] = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .dietaryProtein)!,
            HKObjectType.quantityType(forIdentifier: .dietaryWater)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]

        for type in typesToObserve {
            // Enable background delivery
            healthStore.enableBackgroundDelivery(for: type, frequency: .immediate) { success, error in
                if success {
                    print("✅ Background delivery enabled for \(type)")
                } else if let error = error {
                    print("❌ Failed to enable background delivery for \(type): \(error)")
                }
            }

            // Set up observer query
            let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] query, completionHandler, error in
                if let error = error {
                    print("❌ Observer query error for \(type): \(error)")
                    completionHandler()
                    return
                }

                print("🔔 HealthKit data changed for \(type), triggering sync...")
                Task { @MainActor in
                    await self?.performFullSync()
                }

                completionHandler()
            }

            healthStore.execute(query)
            print("👀 Observer query set up for \(type)")
        }
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
        print("🔄 Starting HealthKit sync to patient_samples...")

        do {
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
            print("ℹ️ Aggregations are automatically calculated via database triggers")

        } catch {
            syncError = error.localizedDescription
            print("❌ HealthKit sync failed: \(error)")
        }

        isSyncing = false
    }

    // MARK: - Protein Sync

    private func syncProtein() async throws {
        print("🥩 Syncing protein data...")

        guard let proteinType = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) else {
            throw HealthKitSyncError.dataTypeNotAvailable
        }

        guard let userId = try? await supabase.auth.session.user.id else {
            throw HealthKitSyncError.notAuthenticated
        }

        let samples = try await fetchQuantitySamples(type: proteinType, since: lastSyncDate ?? Date().addingTimeInterval(-7*24*60*60))

        var patientSamples: [PatientSample] = []

        for sample in samples {
            // Skip if already synced
            if try await isAlreadySynced(healthKitUUID: sample.uuid.uuidString) {
                continue
            }

            let proteinGrams = sample.quantity.doubleValue(for: .gram())
            let sampleTimeZone = getOriginalTimeZone(from: sample)

            // Create quantity sample with metadata for type/timing
            // HealthKit doesn't provide protein type/timing, so we use "other" defaults
            let metadata: [String: AnyJSON] = [
                ProteinMetadataKeys.proteinType: .string("other"),
                FoodMetadataKeys.foodTiming: .string("other")
            ]

            patientSamples.append(PatientSample.quantity(
                patientId: userId,
                quantityType: QuantityTypes.proteinGrams,
                value: proteinGrams,
                unit: "gram",
                timestamp: sample.startDate,
                metadata: metadata,
                source: .healthkit,
                timezone: sampleTimeZone.identifier,
                eventInstanceId: UUID(),
                healthKitUUID: sample.uuid.uuidString,
                healthKitSourceName: sample.sourceRevision.source.name
            ))
        }

        if !patientSamples.isEmpty {
            try await supabase
                .from("patient_samples")
                .insert(patientSamples)
                .execute()
        }

        print("✅ Synced \(patientSamples.count) protein samples")
    }

    // MARK: - Steps Sync

    private func syncSteps() async throws {
        print("👣 Syncing steps data...")

        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitSyncError.dataTypeNotAvailable
        }

        guard let userId = try? await supabase.auth.session.user.id else {
            throw HealthKitSyncError.notAuthenticated
        }

        let samples = try await fetchQuantitySamples(type: stepsType, since: lastSyncDate ?? Date().addingTimeInterval(-7*24*60*60))

        var patientSamples: [PatientSample] = []

        for sample in samples {
            if try await isAlreadySynced(healthKitUUID: sample.uuid.uuidString) {
                continue
            }

            let stepCount = sample.quantity.doubleValue(for: .count())
            let sampleTimeZone = getOriginalTimeZone(from: sample)

            patientSamples.append(PatientSample.quantity(
                patientId: userId,
                quantityType: QuantityTypes.steps,
                value: stepCount,
                unit: "count",
                timestamp: sample.startDate,
                endTime: sample.endDate,  // Steps have duration
                source: .healthkit,
                timezone: sampleTimeZone.identifier,
                eventInstanceId: UUID(),
                healthKitUUID: sample.uuid.uuidString,
                healthKitSourceName: sample.sourceRevision.source.name
            ))
        }

        if !patientSamples.isEmpty {
            try await supabase
                .from("patient_samples")
                .insert(patientSamples)
                .execute()
        }

        print("✅ Synced \(patientSamples.count) step samples")
    }

    // MARK: - Water Sync

    private func syncWater() async throws {
        print("💧 Syncing water data...")

        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else {
            throw HealthKitSyncError.dataTypeNotAvailable
        }

        guard let userId = try? await supabase.auth.session.user.id else {
            throw HealthKitSyncError.notAuthenticated
        }

        let samples = try await fetchQuantitySamples(type: waterType, since: lastSyncDate ?? Date().addingTimeInterval(-7*24*60*60))

        var patientSamples: [PatientSample] = []

        for sample in samples {
            if try await isAlreadySynced(healthKitUUID: sample.uuid.uuidString) {
                continue
            }

            // Convert to fluid ounces for consistency
            let waterOunces = sample.quantity.doubleValue(for: .fluidOunceUS())
            let sampleTimeZone = getOriginalTimeZone(from: sample)

            patientSamples.append(PatientSample.quantity(
                patientId: userId,
                quantityType: QuantityTypes.hydrationOunces,
                value: waterOunces,
                unit: "fluid_ounce",
                timestamp: sample.startDate,
                source: .healthkit,
                timezone: sampleTimeZone.identifier,
                eventInstanceId: UUID(),
                healthKitUUID: sample.uuid.uuidString,
                healthKitSourceName: sample.sourceRevision.source.name
            ))
        }

        if !patientSamples.isEmpty {
            try await supabase
                .from("patient_samples")
                .insert(patientSamples)
                .execute()
        }

        print("✅ Synced \(patientSamples.count) water samples")
    }

    // MARK: - Weight Sync

    private func syncWeight() async throws {
        print("⚖️ Syncing weight data...")

        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            throw HealthKitSyncError.dataTypeNotAvailable
        }

        guard let userId = try? await supabase.auth.session.user.id else {
            throw HealthKitSyncError.notAuthenticated
        }

        let samples = try await fetchQuantitySamples(type: weightType, since: lastSyncDate ?? Date().addingTimeInterval(-7*24*60*60))

        var patientSamples: [PatientSample] = []

        for sample in samples {
            if try await isAlreadySynced(healthKitUUID: sample.uuid.uuidString) {
                continue
            }

            let weightKg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
            let sampleTimeZone = getOriginalTimeZone(from: sample)

            patientSamples.append(PatientSample.quantity(
                patientId: userId,
                quantityType: QuantityTypes.weight,
                value: weightKg,
                unit: "kilogram",
                timestamp: sample.startDate,
                source: .healthkit,
                timezone: sampleTimeZone.identifier,
                eventInstanceId: UUID(),
                healthKitUUID: sample.uuid.uuidString,
                healthKitSourceName: sample.sourceRevision.source.name
            ))
        }

        if !patientSamples.isEmpty {
            try await supabase
                .from("patient_samples")
                .insert(patientSamples)
                .execute()
        }

        print("✅ Synced \(patientSamples.count) weight samples")
    }

    // MARK: - Sleep Sync

    private func syncSleep() async throws {
        print("😴 Syncing sleep data...")

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitSyncError.dataTypeNotAvailable
        }

        guard let userId = try? await supabase.auth.session.user.id else {
            throw HealthKitSyncError.notAuthenticated
        }

        let samples = try await fetchCategorySamples(type: sleepType, since: lastSyncDate ?? Date().addingTimeInterval(-7*24*60*60))

        var patientSamples: [PatientSample] = []
        let deviceTimezone = TimeZone.current.identifier

        for sample in samples {
            // Skip if already synced
            if try await isAlreadySynced(healthKitUUID: sample.uuid.uuidString) {
                continue
            }

            let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value)
            let categoryValue = mapSleepValueToCategory(sleepValue)

            // Skip "in bed" periods - we only want actual sleep stages
            // In bed (6) doesn't map to our 0-3 sleep stage values
            if categoryValue == nil {
                continue
            }

            patientSamples.append(PatientSample.category(
                patientId: userId,
                categoryType: CategoryTypes.sleepStage,
                value: categoryValue!,
                startTime: sample.startDate,
                endTime: sample.endDate,
                source: .healthkit,
                timezone: deviceTimezone,
                eventInstanceId: UUID(),
                healthKitUUID: sample.uuid.uuidString,
                healthKitSourceName: sample.sourceRevision.source.name
            ))
        }

        if !patientSamples.isEmpty {
            try await supabase
                .from("patient_samples")
                .insert(patientSamples)
                .execute()
        }

        print("✅ Synced \(patientSamples.count) sleep stage samples")
        print("ℹ️ Sleep sessions and aggregations calculated automatically by database triggers")
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

    // MARK: - Deduplication

    /// Check if a HealthKit sample has already been synced (checks metadata JSONB)
    private func isAlreadySynced(healthKitUUID: String) async throws -> Bool {
        // Query patient_samples for matching healthkit_uuid in metadata
        let response: [PatientSample] = try await supabase
            .from("patient_samples")
            .select()
            .contains("metadata", value: ["healthkit_uuid": .string(healthKitUUID)])
            .limit(1)
            .execute()
            .value

        return !response.isEmpty
    }

    // MARK: - Helper Methods

    /// Extract timezone from HealthKit sample metadata, or fallback to device timezone
    private func getOriginalTimeZone(from sample: HKSample) -> TimeZone {
        // Try to get timezone from HealthKit metadata
        if let tzString = sample.metadata?[HKMetadataKeyTimeZone] as? String,
           let timeZone = TimeZone(identifier: tzString) {
            return timeZone
        }

        // Fallback to device current timezone
        return TimeZone.current
    }

    /// Map HealthKit sleep value to our category integer (0=Awake, 1=REM, 2=Core, 3=Deep)
    private func mapSleepValueToCategory(_ value: HKCategoryValueSleepAnalysis?) -> Int? {
        guard let value = value else { return nil }

        switch value {
        case .awake:
            return SleepStageValues.awake  // 0
        case .asleepREM:
            return SleepStageValues.rem    // 1
        case .asleepCore:
            return SleepStageValues.core   // 2
        case .asleepDeep:
            return SleepStageValues.deep   // 3
        case .asleepUnspecified:
            return SleepStageValues.core   // Default to Core/Light
        case .inBed:
            return nil  // Skip "in bed" - not a sleep stage
        @unknown default:
            return SleepStageValues.core
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

    /// Reset sync state to force a full resync from the last 7 days
    func resetSyncState() {
        lastSyncDate = nil
        UserDefaults.standard.removeObject(forKey: "lastHealthKitSync")
        syncError = nil
        print("🔄 Sync state reset - next sync will fetch last 7 days of data")
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
