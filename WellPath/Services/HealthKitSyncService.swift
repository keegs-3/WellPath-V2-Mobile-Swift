//
//  HealthKitSyncService.swift
//  WellPath
//
//  Comprehensive HealthKit sync service supporting:
//  - 30+ quantity types (vitals, body, activity, nutrition)
//  - Category types (sleep, mindful sessions)
//  - Correlation types (blood pressure)
//  - Workouts with duration mapping
//  - 5-year historical sync with monthly chunks
//  - Progress tracking and resume capability
//

import Foundation
import HealthKit
import Supabase

@MainActor
class HealthKitSyncService: ObservableObject {
    static let shared = HealthKitSyncService()

    private let healthStore = HKHealthStore()
    private let supabase = SupabaseManager.shared.client

    /// Progress tracker for UI updates
    let progress = HealthKitSyncProgress.shared

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?

    // MARK: - Configuration

    private let batchSize = 100  // Samples per batch insert
    private let maxRetries = 3   // Retry attempts for failed batches
    private let defaultHistoricalYears = 5  // Years of historical data to sync

    private init() {
        loadLastSyncDate()
    }

    // MARK: - Background Observers

    /// Enable background delivery for ALL supported HealthKit types
    func enableBackgroundDelivery() async {
        print("🔔 Setting up HealthKit background observers for ALL types...")

        // Get all sample types from registry
        let typesToObserve = HealthKitTypeRegistry.getAllSampleTypes()

        for type in typesToObserve {
            healthStore.enableBackgroundDelivery(for: type, frequency: .immediate) { success, error in
                if success {
                    print("✅ Background delivery enabled for \(type)")
                } else if let error = error {
                    print("❌ Failed to enable background delivery for \(type): \(error)")
                }
            }

            let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completionHandler, error in
                if let error = error {
                    print("❌ Observer query error for \(type): \(error)")
                    completionHandler()
                    return
                }

                print("🔔 HealthKit data changed for \(type), triggering incremental sync...")
                Task { @MainActor in
                    await self?.performIncrementalSync()
                }

                completionHandler()
            }

            healthStore.execute(query)
        }

        print("👀 Background observers set up for \(typesToObserve.count) types")
    }

    // MARK: - Sync Entry Points

    /// Perform incremental sync (recent data only - last 7 days or since last sync)
    func performIncrementalSync() async {
        guard !isSyncing else {
            print("⚠️ Sync already in progress")
            return
        }

        isSyncing = true
        syncError = nil

        let since = lastSyncDate ?? Date().addingTimeInterval(-7*24*60*60)
        print("🔄 Starting incremental sync from \(since)...")

        do {
            guard let userId = try? await supabase.auth.session.user.id else {
                throw HealthKitSyncError.notAuthenticated
            }

            // Optimized sync order: workouts first, heart rate last
            // 1. Workouts - most important for user visibility
            try await syncWorkouts(since: since, userId: userId)

            // 2. Sleep
            try await syncSleep(since: since, userId: userId)

            // 3. Mindful sessions
            try await syncMindfulSessions(since: since, userId: userId)

            // 4. Blood pressure
            try await syncBloodPressure(since: since, userId: userId)

            // 5. Normal quantity types (excluding heart rate)
            for config in HealthKitTypeRegistry.quantityConfigsExcludingHighVolume {
                try await syncQuantityType(config: config, since: since, userId: userId)
            }

            // 6. High-volume types last (heart rate)
            for config in HealthKitTypeRegistry.highVolumeQuantityConfigs {
                try await syncQuantityType(config: config, since: since, userId: userId)
            }

            lastSyncDate = Date()
            saveLastSyncDate()
            print("✅ Incremental sync completed")

        } catch {
            syncError = error.localizedDescription
            print("❌ Incremental sync failed: \(error)")
        }

        isSyncing = false
    }

    /// Perform historical sync (5 years of data with progress tracking)
    func performHistoricalSync(years: Int = 5) async {
        guard !isSyncing else {
            print("⚠️ Sync already in progress")
            return
        }

        isSyncing = true
        syncError = nil
        progress.isHistoricalSyncActive = true
        progress.resetProgress()

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .year, value: -years, to: endDate)!

        print("📚 Starting \(years)-year historical sync from \(startDate) to \(endDate)...")
        progress.currentPhase = "Preparing historical sync..."

        do {
            guard let userId = try? await supabase.auth.session.user.id else {
                throw HealthKitSyncError.notAuthenticated
            }

            // Create monthly chunks
            let chunks = createDateChunks(from: startDate, to: endDate)
            let totalChunks = chunks.count

            // Separate normal and high-volume quantity types
            let normalQuantityConfigs = HealthKitTypeRegistry.quantityConfigsExcludingHighVolume
            let highVolumeConfigs = HealthKitTypeRegistry.highVolumeQuantityConfigs

            let totalTypes = normalQuantityConfigs.count + highVolumeConfigs.count + 4 // +4 for workouts, sleep, mindful, BP
            let totalOperations = totalChunks * totalTypes
            var completedOperations = 0

            print("📊 Processing \(totalChunks) monthly chunks for \(totalTypes) data types")
            print("🏋️ Sync order: Workouts → Sleep → Mindful → BP → \(normalQuantityConfigs.count) quantity types → Heart Rate (last)")

            // 1. WORKOUTS FIRST - most important for user visibility
            progress.currentPhase = "Syncing Workouts..."
            progress.updateTypeStatus(type: "workouts", displayName: "Workouts", status: .syncing)
            try await syncWorkoutsHistorical(from: startDate, to: endDate, userId: userId)
            progress.updateTypeStatus(type: "workouts", displayName: "Workouts", status: .completed)
            completedOperations += totalChunks
            progress.overallProgress = Double(completedOperations) / Double(totalOperations)

            // 2. Sleep
            progress.currentPhase = "Syncing Sleep..."
            progress.updateTypeStatus(type: "sleep", displayName: "Sleep", status: .syncing)
            try await syncSleepHistorical(from: startDate, to: endDate, userId: userId)
            progress.updateTypeStatus(type: "sleep", displayName: "Sleep", status: .completed)
            completedOperations += totalChunks
            progress.overallProgress = Double(completedOperations) / Double(totalOperations)

            // 3. Mindful sessions
            progress.currentPhase = "Syncing Mindful Sessions..."
            progress.updateTypeStatus(type: "mindful", displayName: "Mindful Sessions", status: .syncing)
            try await syncMindfulSessions(since: startDate, userId: userId)
            progress.updateTypeStatus(type: "mindful", displayName: "Mindful Sessions", status: .completed)
            completedOperations += totalChunks
            progress.overallProgress = Double(completedOperations) / Double(totalOperations)

            // 4. Blood pressure
            progress.currentPhase = "Syncing Blood Pressure..."
            progress.updateTypeStatus(type: "blood_pressure", displayName: "Blood Pressure", status: .syncing)
            try await syncBloodPressure(since: startDate, userId: userId)
            progress.updateTypeStatus(type: "blood_pressure", displayName: "Blood Pressure", status: .completed)
            completedOperations += totalChunks
            progress.overallProgress = Double(completedOperations) / Double(totalOperations)

            // 5. Normal quantity types (excluding heart rate)
            for config in normalQuantityConfigs {
                progress.currentPhase = "Syncing \(config.displayName)..."
                progress.updateTypeStatus(
                    type: config.dbQuantityType,
                    displayName: config.displayName,
                    status: .syncing
                )

                var totalSamplesForType = 0

                for (chunkIndex, chunk) in chunks.enumerated() {
                    if let checkpoint = progress.getCheckpoint(for: config.dbQuantityType),
                       checkpoint >= chunk.end {
                        completedOperations += 1
                        continue
                    }

                    let samples = try await syncQuantityTypeChunk(
                        config: config,
                        startDate: chunk.start,
                        endDate: chunk.end,
                        userId: userId
                    )

                    totalSamplesForType += samples
                    completedOperations += 1

                    progress.overallProgress = Double(completedOperations) / Double(totalOperations)
                    progress.updateTypeStatus(
                        type: config.dbQuantityType,
                        displayName: config.displayName,
                        status: .syncing,
                        progress: Double(chunkIndex + 1) / Double(totalChunks),
                        samplesProcessed: totalSamplesForType
                    )

                    progress.saveCheckpoint(for: config.dbQuantityType, date: chunk.end)
                }

                progress.updateTypeStatus(
                    type: config.dbQuantityType,
                    displayName: config.displayName,
                    status: .completed,
                    progress: 1.0,
                    samplesProcessed: totalSamplesForType
                )
            }

            // 6. HIGH-VOLUME TYPES LAST (heart rate) - can take 10+ minutes
            for config in highVolumeConfigs {
                progress.currentPhase = "Syncing \(config.displayName) (this may take a while)..."
                progress.updateTypeStatus(
                    type: config.dbQuantityType,
                    displayName: config.displayName,
                    status: .syncing
                )

                var totalSamplesForType = 0

                for (chunkIndex, chunk) in chunks.enumerated() {
                    if let checkpoint = progress.getCheckpoint(for: config.dbQuantityType),
                       checkpoint >= chunk.end {
                        completedOperations += 1
                        continue
                    }

                    let samples = try await syncQuantityTypeChunk(
                        config: config,
                        startDate: chunk.start,
                        endDate: chunk.end,
                        userId: userId
                    )

                    totalSamplesForType += samples
                    completedOperations += 1

                    progress.overallProgress = Double(completedOperations) / Double(totalOperations)
                    progress.updateTypeStatus(
                        type: config.dbQuantityType,
                        displayName: config.displayName,
                        status: .syncing,
                        progress: Double(chunkIndex + 1) / Double(totalChunks),
                        samplesProcessed: totalSamplesForType
                    )

                    progress.saveCheckpoint(for: config.dbQuantityType, date: chunk.end)
                }

                progress.updateTypeStatus(
                    type: config.dbQuantityType,
                    displayName: config.displayName,
                    status: .completed,
                    progress: 1.0,
                    samplesProcessed: totalSamplesForType
                )
            }

            progress.overallProgress = 1.0

            // Mark complete
            progress.markInitialSyncComplete()
            progress.currentPhase = "Sync complete!"
            lastSyncDate = Date()
            saveLastSyncDate()

            print("✅ Historical sync completed - \(progress.totalSamplesProcessed) total samples synced")

        } catch {
            syncError = error.localizedDescription
            progress.lastError = error.localizedDescription
            progress.currentPhase = "Sync failed"
            print("❌ Historical sync failed: \(error)")
        }

        isSyncing = false
        progress.isHistoricalSyncActive = false
    }

    // MARK: - Generic Quantity Type Sync

    /// Sync a single quantity type using config (for incremental sync)
    private func syncQuantityType(config: HealthKitQuantityConfig, since: Date, userId: UUID) async throws {
        guard let hkType = config.hkQuantityType else { return }

        let samples = try await fetchQuantitySamples(type: hkType, since: since)
        if samples.isEmpty { return }

        var writeSamples: [QuantitySampleWrite] = []

        for sample in samples {
            if try await isAlreadySynced(healthKitUUID: sample.uuid.uuidString, table: "patient_quantity_samples") {
                continue
            }

            let value = sample.quantity.doubleValue(for: config.hkUnit)
            let timezone = getOriginalTimeZone(from: sample)

            writeSamples.append(QuantitySampleWrite.create(
                patientId: userId,
                quantityType: config.dbQuantityType,
                value: value,
                unit: config.dbUnit,
                timestamp: sample.startDate,
                endTime: sample.endDate,
                source: .healthkit,
                timezone: timezone.identifier,
                healthKitUUID: sample.uuid.uuidString,
                healthKitSourceName: sample.sourceRevision.source.name,
                healthKitBundleId: sample.sourceRevision.source.bundleIdentifier
            ))
        }

        if !writeSamples.isEmpty {
            try await batchInsertWithRetry(table: "patient_quantity_samples", samples: writeSamples)
            print("✅ Synced \(writeSamples.count) \(config.displayName) samples")
        }
    }

    /// Sync a quantity type chunk (for historical sync)
    private func syncQuantityTypeChunk(
        config: HealthKitQuantityConfig,
        startDate: Date,
        endDate: Date,
        userId: UUID
    ) async throws -> Int {
        guard let hkType = config.hkQuantityType else { return 0 }

        let samples = try await fetchQuantitySamplesRange(type: hkType, start: startDate, end: endDate)
        if samples.isEmpty { return 0 }

        var writeSamples: [QuantitySampleWrite] = []

        for sample in samples {
            // Batch UUID check is more efficient for large datasets
            let value = sample.quantity.doubleValue(for: config.hkUnit)
            let timezone = getOriginalTimeZone(from: sample)

            writeSamples.append(QuantitySampleWrite.create(
                patientId: userId,
                quantityType: config.dbQuantityType,
                value: value,
                unit: config.dbUnit,
                timestamp: sample.startDate,
                endTime: sample.endDate,
                source: .healthkit,
                timezone: timezone.identifier,
                healthKitUUID: sample.uuid.uuidString,
                healthKitSourceName: sample.sourceRevision.source.name,
                healthKitBundleId: sample.sourceRevision.source.bundleIdentifier
            ))
        }

        if !writeSamples.isEmpty {
            try await batchInsertWithRetry(table: "patient_quantity_samples", samples: writeSamples)
        }

        return writeSamples.count
    }

    // MARK: - Sleep Sync

    private func syncSleep(since: Date, userId: UUID) async throws {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        let samples = try await fetchCategorySamples(type: sleepType, since: since)
        if samples.isEmpty { return }

        var categorySamples: [CategorySampleWrite] = []
        let deviceTimezone = TimeZone.current.identifier

        for sample in samples {
            if try await isAlreadySynced(healthKitUUID: sample.uuid.uuidString, table: "patient_category_samples") {
                continue
            }

            let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value)
            guard let categoryValue = mapSleepValueToCategory(sleepValue) else { continue }

            if try await isCategorySampleDuplicate(
                patientId: userId,
                categoryType: CategoryTypes.sleepPeriodTypes,
                categoryValue: categoryValue,
                startTime: sample.startDate,
                endTime: sample.endDate
            ) {
                continue
            }

            categorySamples.append(CategorySampleWrite.create(
                patientId: userId,
                categoryType: CategoryTypes.sleepPeriodTypes,
                value: categoryValue,
                startTime: sample.startDate,
                endTime: sample.endDate,
                source: .healthkit,
                timezone: deviceTimezone,
                healthKitUUID: sample.uuid.uuidString,
                healthKitSourceName: sample.sourceRevision.source.name,
                healthKitBundleId: sample.sourceRevision.source.bundleIdentifier
            ))
        }

        if !categorySamples.isEmpty {
            try await batchInsertWithRetry(table: "patient_category_samples", samples: categorySamples)
            print("✅ Synced \(categorySamples.count) sleep samples")
        }
    }

    private func syncSleepHistorical(from startDate: Date, to endDate: Date, userId: UUID) async throws {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        let samples = try await fetchCategorySamplesRange(type: sleepType, start: startDate, end: endDate)
        if samples.isEmpty { return }

        var categorySamples: [CategorySampleWrite] = []
        let deviceTimezone = TimeZone.current.identifier

        for sample in samples {
            let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value)
            guard let categoryValue = mapSleepValueToCategory(sleepValue) else { continue }

            categorySamples.append(CategorySampleWrite.create(
                patientId: userId,
                categoryType: CategoryTypes.sleepPeriodTypes,
                value: categoryValue,
                startTime: sample.startDate,
                endTime: sample.endDate,
                source: .healthkit,
                timezone: deviceTimezone,
                healthKitUUID: sample.uuid.uuidString,
                healthKitSourceName: sample.sourceRevision.source.name,
                healthKitBundleId: sample.sourceRevision.source.bundleIdentifier
            ))
        }

        if !categorySamples.isEmpty {
            try await batchInsertWithRetry(table: "patient_category_samples", samples: categorySamples)
            print("✅ Synced \(categorySamples.count) historical sleep samples")
        }
    }

    // MARK: - Mindful Session Sync

    private func syncMindfulSessions(since: Date, userId: UUID) async throws {
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return }

        let samples = try await fetchCategorySamples(type: mindfulType, since: since)
        if samples.isEmpty { return }

        var categorySamples: [CategorySampleWrite] = []
        let deviceTimezone = TimeZone.current.identifier

        for sample in samples {
            if try await isAlreadySynced(healthKitUUID: sample.uuid.uuidString, table: "patient_category_samples") {
                continue
            }

            // For mindful sessions, we track duration - store "session" as value
            categorySamples.append(CategorySampleWrite.create(
                patientId: userId,
                categoryType: CategoryTypes.mindfulSession,
                value: "session",
                startTime: sample.startDate,
                endTime: sample.endDate,
                source: .healthkit,
                timezone: deviceTimezone,
                healthKitUUID: sample.uuid.uuidString,
                healthKitSourceName: sample.sourceRevision.source.name,
                healthKitBundleId: sample.sourceRevision.source.bundleIdentifier
            ))
        }

        if !categorySamples.isEmpty {
            try await batchInsertWithRetry(table: "patient_category_samples", samples: categorySamples)
            print("✅ Synced \(categorySamples.count) mindful session samples")
        }
    }

    // MARK: - Blood Pressure Sync

    private func syncBloodPressure(since: Date, userId: UUID) async throws {
        guard let correlationType = HKCorrelationType.correlationType(forIdentifier: .bloodPressure),
              let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) else {
            return
        }

        let correlationSamples = try await fetchCorrelationSamples(type: correlationType, since: since)
        if correlationSamples.isEmpty { return }

        var bpSamples: [CorrelationSampleWrite] = []
        let deviceTimezone = TimeZone.current.identifier

        for correlation in correlationSamples {
            if try await isAlreadySynced(healthKitUUID: correlation.uuid.uuidString, table: "patient_correlation_samples") {
                continue
            }

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

            guard let systolic = systolicValue, let diastolic = diastolicValue else { continue }

            let components: [String: AnyJSON] = [
                "systolic": .double(systolic),
                "diastolic": .double(diastolic)
            ]

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
            try await batchInsertWithRetry(table: "patient_correlation_samples", samples: bpSamples)
            print("✅ Synced \(bpSamples.count) blood pressure samples")
        }
    }

    // MARK: - Workout Sync

    private func syncWorkouts(since: Date, userId: UUID) async throws {
        let workouts = try await fetchWorkouts(since: since)
        if workouts.isEmpty { return }

        try await processWorkouts(workouts: workouts, userId: userId)
    }

    private func syncWorkoutsHistorical(from startDate: Date, to endDate: Date, userId: UUID) async throws {
        let workouts = try await fetchWorkoutsRange(start: startDate, end: endDate)
        if workouts.isEmpty { return }

        try await processWorkouts(workouts: workouts, userId: userId)
    }

    private func processWorkouts(workouts: [HKWorkout], userId: UUID) async throws {
        var samples: [QuantitySampleWrite] = []
        let deviceTimezone = TimeZone.current.identifier

        for workout in workouts {
            // Get workout mapping - all workouts have a quantity type now
            let mapping = HealthKitTypeRegistry.getWorkoutMapping(for: workout.workoutActivityType)
            let defaults = HealthKitTypeRegistry.getDefaultWorkoutMapping()

            let quantityType = mapping?.quantityType ?? defaults.quantityType
            let category = mapping?.wellpathCategory ?? defaults.category
            let workoutSubtype = mapping?.workoutSubtype ?? defaults.workoutSubtype
            let displayName = mapping?.displayName ?? "Other"

            let durationMinutes = workout.endDate.timeIntervalSince(workout.startDate) / 60.0
            let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
            let distanceMeters = workout.totalDistance?.doubleValue(for: .meter())

            // Build rich metadata (same pattern as protein/nutrition)
            var metadata: [String: AnyJSON] = [
                "workout_category": .string(category),
                "workout_activity": .string(displayName),
                "workout_activity_type_raw": .integer(Int(workout.workoutActivityType.rawValue))
            ]

            if let subtype = workoutSubtype {
                metadata["workout_subtype"] = .string(subtype)
            }
            if let cal = calories {
                metadata["calories_burned"] = .double(cal)
            }
            if let dist = distanceMeters, dist > 0 {
                metadata["distance_meters"] = .double(dist)
            }
            if let deviceName = workout.device?.name {
                metadata["device_name"] = .string(deviceName)
            }

            // Create quantity sample - this is now the ONLY place workout data goes
            samples.append(QuantitySampleWrite.create(
                patientId: userId,
                quantityType: quantityType,
                value: durationMinutes,
                unit: "minutes",
                timestamp: workout.startDate,
                endTime: workout.endDate,
                source: .healthkit,
                timezone: deviceTimezone,
                metadata: metadata,
                healthKitUUID: workout.uuid.uuidString,
                healthKitSourceName: workout.sourceRevision.source.name,
                healthKitBundleId: workout.sourceRevision.source.bundleIdentifier
            ))
        }

        // Insert workout samples to patient_quantity_samples
        if !samples.isEmpty {
            try await batchInsertWithRetry(table: "patient_quantity_samples", samples: samples)
            print("✅ Synced \(samples.count) workout samples to patient_quantity_samples")
        }
    }

    // MARK: - Series Data Sync (Heart Rate during Workouts)

    /// Sync heart rate series data for a specific workout
    func syncWorkoutHeartRateSeries(workoutId: UUID, workout: HKWorkout, userId: UUID) async throws {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        // Fetch heart rate samples during workout time range
        let hrSamples = try await fetchQuantitySamplesRange(
            type: hrType,
            start: workout.startDate,
            end: workout.endDate
        )

        if hrSamples.isEmpty { return }

        var seriesSamples: [SeriesSampleWrite] = []

        for (index, sample) in hrSamples.enumerated() {
            let hrValue = sample.quantity.doubleValue(for: .count().unitDivided(by: .minute()))

            seriesSamples.append(SeriesSampleWrite(
                patientId: userId,
                parentSampleId: workoutId,
                seriesType: "heart_rate_series",
                timestamp: sample.startDate,
                value: hrValue,
                valueSecondary: nil,
                sequenceIndex: index,
                source: "healthkit",
                metadata: [
                    "healthkit_uuid": .string(sample.uuid.uuidString),
                    "workout_uuid": .string(workout.uuid.uuidString)
                ]
            ))
        }

        if !seriesSamples.isEmpty {
            try await batchInsertWithRetry(table: "patient_series_samples", samples: seriesSamples)
            print("✅ Synced \(seriesSamples.count) HR series samples for workout")
        }
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
                continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func fetchQuantitySamplesRange(type: HKQuantityType, start: Date, end: Date) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
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
                continuation.resume(returning: samples as? [HKCategorySample] ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func fetchCategorySamplesRange(type: HKCategoryType, start: Date, end: Date) async throws -> [HKCategorySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples as? [HKCategorySample] ?? [])
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
                continuation.resume(returning: samples as? [HKCorrelation] ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func fetchWorkouts(since: Date) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: since, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples as? [HKWorkout] ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func fetchWorkoutsRange(start: Date, end: Date) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples as? [HKWorkout] ?? [])
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Batch Insert with Retry

    private func batchInsertWithRetry<T: Encodable>(table: String, samples: [T]) async throws {
        // Split into batches
        let batches = samples.chunked(into: batchSize)

        for batch in batches {
            var lastError: Error?

            for attempt in 1...maxRetries {
                do {
                    // Use upsert with ignoreDuplicates to skip existing records
                    // This prevents duplicate inserts when re-syncing HealthKit data
                    try await supabase
                        .from(table)
                        .upsert(batch, returning: .minimal, ignoreDuplicates: true)
                        .execute()
                    lastError = nil
                    break
                } catch {
                    lastError = error
                    if attempt < maxRetries {
                        // Exponential backoff: 1s, 2s, 4s
                        let delay = UInt64(pow(2.0, Double(attempt - 1)) * 1_000_000_000)
                        try await Task.sleep(nanoseconds: delay)
                    }
                }
            }

            if let error = lastError {
                print("⚠️ Batch insert failed after \(maxRetries) attempts: \(error)")
                // Continue with other batches instead of failing completely
            }
        }
    }

    // MARK: - Date Chunking

    private func createDateChunks(from startDate: Date, to endDate: Date) -> [(start: Date, end: Date)] {
        var chunks: [(start: Date, end: Date)] = []
        var currentStart = startDate
        let calendar = Calendar.current

        while currentStart < endDate {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentStart) ?? endDate
            let chunkEnd = min(nextMonth, endDate)
            chunks.append((start: currentStart, end: chunkEnd))
            currentStart = chunkEnd
        }

        return chunks
    }

    // MARK: - Deduplication

    private func isAlreadySynced(healthKitUUID: String, table: String) async throws -> Bool {
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

    private func getOriginalTimeZone(from sample: HKSample) -> TimeZone {
        if let tzString = sample.metadata?[HKMetadataKeyTimeZone] as? String,
           let timeZone = TimeZone(identifier: tzString) {
            return timeZone
        }
        return TimeZone.current
    }

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
            return "core"
        case .inBed:
            return nil
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

    /// Backwards compatibility - maps to incremental sync
    func performFullSync() async {
        await performIncrementalSync()
    }

    /// Reset sync state to force full historical resync
    func resetSyncState() {
        lastSyncDate = nil
        UserDefaults.standard.removeObject(forKey: "lastHealthKitSync")
        progress.clearAllCheckpoints()
        syncError = nil
        print("🔄 Sync state reset - ready for historical sync")
    }
}

// MARK: - Workout Event Write Model

struct WorkoutEventWrite: Codable {
    let patientId: UUID
    let healthkitUuid: String?
    let workoutActivityType: String
    let workoutActivityTypeRaw: Int?
    let startTime: Date
    let endTime: Date
    let totalEnergyBurned: Double?
    let totalDistance: Double?
    let wellpathCategory: String?
    let source: String
    let sourceName: String?
    let sourceBundleId: String?
    let deviceName: String?
    let userTimezone: String?

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case healthkitUuid = "healthkit_uuid"
        case workoutActivityType = "workout_activity_type"
        case workoutActivityTypeRaw = "workout_activity_type_raw"
        case startTime = "start_time"
        case endTime = "end_time"
        case totalEnergyBurned = "total_energy_burned"
        case totalDistance = "total_distance"
        case wellpathCategory = "wellpath_category"
        case source
        case sourceName = "source_name"
        case sourceBundleId = "source_bundle_id"
        case deviceName = "device_name"
        case userTimezone = "user_timezone"
    }
}

// MARK: - Series Sample Write Model

struct SeriesSampleWrite: Codable {
    let patientId: UUID
    let parentSampleId: UUID?
    let seriesType: String
    let timestamp: Date
    let value: Double
    let valueSecondary: Double?
    let sequenceIndex: Int?
    let source: String
    let metadata: [String: AnyJSON]?

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case parentSampleId = "parent_sample_id"
        case seriesType = "series_type"
        case timestamp
        case value
        case valueSecondary = "value_secondary"
        case sequenceIndex = "sequence_index"
        case source
        case metadata
    }
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
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
