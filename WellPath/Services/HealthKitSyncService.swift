//
//  HealthKitSyncService.swift
//  WellPath
//
//  Automatically syncs HealthKit data to the specific sample tables:
//  - patient_quantity_samples: steps, weight, protein, water, etc.
//  - patient_category_samples: sleep stages, etc.
//  - patient_correlation_samples: blood pressure, etc.
//
//  Note: patient_samples VIEW is READ-ONLY for backwards compatibility
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
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!
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
            try await syncBloodPressure()

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

        var quantitySamples: [QuantitySampleWrite] = []

        for sample in samples {
            // Skip if already synced
            if try await isAlreadySynced(healthKitUUID: sample.uuid.uuidString, table: "patient_quantity_samples") {
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

            quantitySamples.append(QuantitySampleWrite.create(
                patientId: userId,
                quantityType: QuantityTypes.proteinGrams,
                value: proteinGrams,
                unit: "gram",
                timestamp: sample.startDate,
                source: .healthkit,
                timezone: sampleTimeZone.identifier,
                metadata: metadata,
                eventInstanceId: UUID(),
                healthKitUUID: sample.uuid.uuidString,
                healthKitSourceName: sample.sourceRevision.source.name,
                healthKitBundleId: sample.sourceRevision.source.bundleIdentifier
            ))
        }

        if !quantitySamples.isEmpty {
            try await supabase
                .from("patient_quantity_samples")
                .insert(quantitySamples)
                .execute()
        }

        print("✅ Synced \(quantitySamples.count) protein samples")
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

        var quantitySamples: [QuantitySampleWrite] = []

        for sample in samples {
            if try await isAlreadySynced(healthKitUUID: sample.uuid.uuidString, table: "patient_quantity_samples") {
                continue
            }

            let stepCount = sample.quantity.doubleValue(for: .count())
            let sampleTimeZone = getOriginalTimeZone(from: sample)

            quantitySamples.append(QuantitySampleWrite.create(
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
                healthKitSourceName: sample.sourceRevision.source.name,
                healthKitBundleId: sample.sourceRevision.source.bundleIdentifier
            ))
        }

        if !quantitySamples.isEmpty {
            try await supabase
                .from("patient_quantity_samples")
                .insert(quantitySamples)
                .execute()
        }

        print("✅ Synced \(quantitySamples.count) step samples")
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

        var quantitySamples: [QuantitySampleWrite] = []

        for sample in samples {
            if try await isAlreadySynced(healthKitUUID: sample.uuid.uuidString, table: "patient_quantity_samples") {
                continue
            }

            // Convert to fluid ounces for consistency
            let waterOunces = sample.quantity.doubleValue(for: .fluidOunceUS())
            let sampleTimeZone = getOriginalTimeZone(from: sample)

            quantitySamples.append(QuantitySampleWrite.create(
                patientId: userId,
                quantityType: QuantityTypes.hydrationOunces,
                value: waterOunces,
                unit: "fluid_ounce",
                timestamp: sample.startDate,
                source: .healthkit,
                timezone: sampleTimeZone.identifier,
                eventInstanceId: UUID(),
                healthKitUUID: sample.uuid.uuidString,
                healthKitSourceName: sample.sourceRevision.source.name,
                healthKitBundleId: sample.sourceRevision.source.bundleIdentifier
            ))
        }

        if !quantitySamples.isEmpty {
            try await supabase
                .from("patient_quantity_samples")
                .insert(quantitySamples)
                .execute()
        }

        print("✅ Synced \(quantitySamples.count) water samples")
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

        var quantitySamples: [QuantitySampleWrite] = []

        for sample in samples {
            if try await isAlreadySynced(healthKitUUID: sample.uuid.uuidString, table: "patient_quantity_samples") {
                continue
            }

            let weightKg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
            let sampleTimeZone = getOriginalTimeZone(from: sample)

            quantitySamples.append(QuantitySampleWrite.create(
                patientId: userId,
                quantityType: QuantityTypes.weight,
                value: weightKg,
                unit: "kilogram",
                timestamp: sample.startDate,
                source: .healthkit,
                timezone: sampleTimeZone.identifier,
                eventInstanceId: UUID(),
                healthKitUUID: sample.uuid.uuidString,
                healthKitSourceName: sample.sourceRevision.source.name,
                healthKitBundleId: sample.sourceRevision.source.bundleIdentifier
            ))
        }

        if !quantitySamples.isEmpty {
            try await supabase
                .from("patient_quantity_samples")
                .insert(quantitySamples)
                .execute()
        }

        print("✅ Synced \(quantitySamples.count) weight samples")
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

        var categorySamples: [CategorySampleWrite] = []
        let deviceTimezone = TimeZone.current.identifier

        for sample in samples {
            // Skip if already synced by HealthKit UUID
            if try await isAlreadySynced(healthKitUUID: sample.uuid.uuidString, table: "patient_category_samples") {
                continue
            }

            let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value)
            let categoryValue = mapSleepValueToCategory(sleepValue)

            // Skip "in bed" periods - we only want actual sleep stages
            // In bed returns nil from mapSleepValueToCategory
            if categoryValue == nil {
                continue
            }

            // Also check for time-based duplicates (HealthKit sometimes returns same data with different UUIDs)
            if try await isCategorySampleDuplicate(
                patientId: userId,
                categoryType: CategoryTypes.sleepPeriodTypes,
                categoryValue: categoryValue!,
                startTime: sample.startDate,
                endTime: sample.endDate
            ) {
                continue
            }

            categorySamples.append(CategorySampleWrite.create(
                patientId: userId,
                categoryType: CategoryTypes.sleepPeriodTypes,
                value: categoryValue!,
                startTime: sample.startDate,
                endTime: sample.endDate,
                source: .healthkit,
                timezone: deviceTimezone,
                eventInstanceId: UUID(),
                healthKitUUID: sample.uuid.uuidString,
                healthKitSourceName: sample.sourceRevision.source.name,
                healthKitBundleId: sample.sourceRevision.source.bundleIdentifier
            ))
        }

        if !categorySamples.isEmpty {
            try await supabase
                .from("patient_category_samples")
                .insert(categorySamples)
                .execute()
        }

        print("✅ Synced \(categorySamples.count) sleep stage samples")
        print("ℹ️ Sleep sessions and aggregations calculated automatically by database triggers")
    }

    // MARK: - Blood Pressure Sync

    private func syncBloodPressure() async throws {
        print("🩺 Syncing blood pressure data...")

        guard let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) else {
            throw HealthKitSyncError.dataTypeNotAvailable
        }

        guard let userId = try? await supabase.auth.session.user.id else {
            throw HealthKitSyncError.notAuthenticated
        }

        // Blood pressure in HealthKit is stored as a correlation type
        // We need to fetch the correlation samples to get paired systolic/diastolic readings
        guard let correlationType = HKCorrelationType.correlationType(forIdentifier: .bloodPressure) else {
            throw HealthKitSyncError.dataTypeNotAvailable
        }

        let correlationSamples = try await fetchCorrelationSamples(
            type: correlationType,
            since: lastSyncDate ?? Date().addingTimeInterval(-7*24*60*60)
        )

        var bpSamples: [CorrelationSampleWrite] = []
        let deviceTimezone = TimeZone.current.identifier

        for correlation in correlationSamples {
            // Skip if already synced
            if try await isAlreadySynced(healthKitUUID: correlation.uuid.uuidString, table: "patient_correlation_samples") {
                continue
            }

            // Extract systolic and diastolic values from the correlation
            var systolicValue: Double?
            var diastolicValue: Double?

            for sample in correlation.objects {
                if let quantitySample = sample as? HKQuantitySample {
                    if quantitySample.quantityType == systolicType {
                        systolicValue = quantitySample.quantity.doubleValue(for: .millimeterOfMercury())
                    } else if quantitySample.quantityType == diastolicType {
                        diastolicValue = quantitySample.quantity.doubleValue(for: .millimeterOfMercury())
                    }
                }
            }

            guard let systolic = systolicValue, let diastolic = diastolicValue else {
                print("⚠️ Skipping incomplete blood pressure reading")
                continue
            }

            // Create components JSONB
            let components: [String: AnyJSON] = [
                "systolic": .double(systolic),
                "diastolic": .double(diastolic)
            ]

            // Add HealthKit tracking metadata
            let metadata: [String: AnyJSON] = [
                "healthkit_uuid": .string(correlation.uuid.uuidString),
                "healthkit_source_name": .string(correlation.sourceRevision.source.name)
            ]

            bpSamples.append(CorrelationSampleWrite(
                patientId: userId,
                correlationType: CorrelationTypes.bloodPressure,
                components: components,
                sampleTime: correlation.startDate,
                source: .healthkit,
                deviceInfo: nil,
                metadata: metadata,
                userTimezone: deviceTimezone
            ))
        }

        if !bpSamples.isEmpty {
            try await supabase
                .from("patient_correlation_samples")
                .insert(bpSamples)
                .execute()
        }

        print("✅ Synced \(bpSamples.count) blood pressure samples")
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

    private func fetchCorrelationSamples(type: HKCorrelationType, since: Date) async throws -> [HKCorrelation] {
        let predicate = HKQuery.predicateForSamples(withStart: since, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let correlationSamples = samples as? [HKCorrelation] ?? []
                continuation.resume(returning: correlationSamples)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Deduplication

    /// Check if a HealthKit sample has already been synced (checks metadata JSONB)
    /// - Parameters:
    ///   - healthKitUUID: The HealthKit sample UUID to check
    ///   - table: The specific table to check (patient_quantity_samples, patient_category_samples, etc.)
    private func isAlreadySynced(healthKitUUID: String, table: String) async throws -> Bool {
        // Query the specific table for matching healthkit_uuid in metadata
        // We only need to check if count > 0, so just select id
        struct IdOnly: Codable { let id: UUID }
        let response: [IdOnly] = try await supabase
            .from(table)
            .select("id")
            .contains("metadata", value: ["healthkit_uuid": .string(healthKitUUID)])
            .limit(1)
            .execute()
            .value

        return !response.isEmpty
    }

    /// Check if a category sample already exists by time range and value
    /// This catches duplicates from HealthKit where the same data has different UUIDs
    private func isCategorySampleDuplicate(
        patientId: UUID,
        categoryType: String,
        categoryValue: String,
        startTime: Date,
        endTime: Date
    ) async throws -> Bool {
        struct IdOnly: Codable { let id: UUID }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let response: [IdOnly] = try await supabase
            .from("patient_category_samples")
            .select("id")
            .eq("patient_id", value: patientId)
            .eq("category_type", value: categoryType)
            .eq("category_value", value: categoryValue)
            .eq("start_time", value: formatter.string(from: startTime))
            .eq("end_time", value: formatter.string(from: endTime))
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

    /// Map HealthKit sleep value to our category string key (awake, rem, core, deep)
    /// These match the reference_key values in sample_category_types_reference
    private func mapSleepValueToCategory(_ value: HKCategoryValueSleepAnalysis?) -> String? {
        guard let value = value else { return nil }

        switch value {
        case .awake:
            return "awake"
        case .asleepREM:
            return "rem"
        case .asleepCore:
            return "core"
        case .asleepDeep:
            return "deep"
        case .asleepUnspecified:
            return "core"  // Default to Core/Light
        case .inBed:
            return nil  // Skip "in bed" - not a sleep stage
        @unknown default:
            return "core"
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
