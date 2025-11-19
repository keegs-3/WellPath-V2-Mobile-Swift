//
//  HealthKitManager.swift
//  WellPath
//
//  Manages HealthKit authorization and data access
//

import Foundation
import HealthKit
import Supabase

class HealthKitManager: ObservableObject {

    // MARK: - Singleton

    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()

    @Published var authorizationStatus: AuthorizationStatus = .notDetermined

    enum AuthorizationStatus {
        case notDetermined
        case authorized
        case denied
        case notAvailable
    }

    // MARK: - Initialization

    private init() {
        checkAvailability()
    }

    // MARK: - Availability

    func checkAvailability() {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = .notAvailable
            print("❌ HealthKit is not available on this device")
            return
        }
        print("✅ HealthKit is available")
    }

    // MARK: - Data Types

    /// Health data types the app needs to READ
    var typesToRead: Set<HKObjectType> {
        var types = Set<HKObjectType>()

        // Sleep Analysis
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }

        // Activity & Exercise
        if let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepsType)
        }
        if let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergyType)
        }
        if let basalEnergyType = HKObjectType.quantityType(forIdentifier: .basalEnergyBurned) {
            types.insert(basalEnergyType)
        }
        if let exerciseTimeType = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) {
            types.insert(exerciseTimeType)
        }
        if let standTimeType = HKObjectType.quantityType(forIdentifier: .appleStandTime) {
            types.insert(standTimeType)
        }
        if let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distanceType)
        }
        if let cyclingType = HKObjectType.quantityType(forIdentifier: .distanceCycling) {
            types.insert(cyclingType)
        }
        if let flightsType = HKObjectType.quantityType(forIdentifier: .flightsClimbed) {
            types.insert(flightsType)
        }

        // Workouts
        types.insert(HKObjectType.workoutType())

        // Heart Health
        if let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRateType)
        }
        if let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrvType)
        }
        if let restingHeartRateType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(restingHeartRateType)
        }
        if let walkingHeartRateType = HKObjectType.quantityType(forIdentifier: .walkingHeartRateAverage) {
            types.insert(walkingHeartRateType)
        }
        if let vo2MaxType = HKObjectType.quantityType(forIdentifier: .vo2Max) {
            types.insert(vo2MaxType)
        }

        // Body Measurements
        if let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.insert(bodyMassType)
        }
        if let heightType = HKObjectType.quantityType(forIdentifier: .height) {
            types.insert(heightType)
        }
        if let bmiType = HKObjectType.quantityType(forIdentifier: .bodyMassIndex) {
            types.insert(bmiType)
        }
        if let bodyFatType = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) {
            types.insert(bodyFatType)
        }
        if let leanBodyMassType = HKObjectType.quantityType(forIdentifier: .leanBodyMass) {
            types.insert(leanBodyMassType)
        }
        if let waistType = HKObjectType.quantityType(forIdentifier: .waistCircumference) {
            types.insert(waistType)
        }

        // Vitals
        if let bloodPressureSystolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic) {
            types.insert(bloodPressureSystolicType)
        }
        if let bloodPressureDiastolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic) {
            types.insert(bloodPressureDiastolicType)
        }
        if let respiratoryRateType = HKObjectType.quantityType(forIdentifier: .respiratoryRate) {
            types.insert(respiratoryRateType)
        }
        if let bodyTempType = HKObjectType.quantityType(forIdentifier: .bodyTemperature) {
            types.insert(bodyTempType)
        }
        if let oxygenSatType = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) {
            types.insert(oxygenSatType)
        }
        if let bloodGlucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) {
            types.insert(bloodGlucoseType)
        }

        // Nutrition (comprehensive)
        if let waterType = HKObjectType.quantityType(forIdentifier: .dietaryWater) {
            types.insert(waterType)
        }
        if let proteinType = HKObjectType.quantityType(forIdentifier: .dietaryProtein) {
            types.insert(proteinType)
        }
        if let carbsType = HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates) {
            types.insert(carbsType)
        }
        if let fiberType = HKObjectType.quantityType(forIdentifier: .dietaryFiber) {
            types.insert(fiberType)
        }
        if let sugarType = HKObjectType.quantityType(forIdentifier: .dietarySugar) {
            types.insert(sugarType)
        }
        if let fatTotalType = HKObjectType.quantityType(forIdentifier: .dietaryFatTotal) {
            types.insert(fatTotalType)
        }
        if let fatSaturatedType = HKObjectType.quantityType(forIdentifier: .dietaryFatSaturated) {
            types.insert(fatSaturatedType)
        }
        if let cholesterolType = HKObjectType.quantityType(forIdentifier: .dietaryCholesterol) {
            types.insert(cholesterolType)
        }
        if let sodiumType = HKObjectType.quantityType(forIdentifier: .dietarySodium) {
            types.insert(sodiumType)
        }
        if let caloriesType = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            types.insert(caloriesType)
        }
        if let caffeineType = HKObjectType.quantityType(forIdentifier: .dietaryCaffeine) {
            types.insert(caffeineType)
        }

        // Mindfulness & Mental Health
        if let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
            types.insert(mindfulType)
        }

        return types
    }

    /// Health data types the app might WRITE (optional - can write user-tracked data)
    var typesToWrite: Set<HKSampleType> {
        var types = Set<HKSampleType>()

        // Sleep
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }

        // Activity
        if let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepsType)
        }
        if let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergyType)
        }
        if let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distanceType)
        }
        if let cyclingType = HKObjectType.quantityType(forIdentifier: .distanceCycling) {
            types.insert(cyclingType)
        }
        if let flightsType = HKObjectType.quantityType(forIdentifier: .flightsClimbed) {
            types.insert(flightsType)
        }

        // Workouts
        types.insert(HKObjectType.workoutType())

        // Body Measurements
        if let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.insert(bodyMassType)
        }
        if let heightType = HKObjectType.quantityType(forIdentifier: .height) {
            types.insert(heightType)
        }
        if let bmiType = HKObjectType.quantityType(forIdentifier: .bodyMassIndex) {
            types.insert(bmiType)
        }
        if let bodyFatType = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) {
            types.insert(bodyFatType)
        }
        if let leanBodyMassType = HKObjectType.quantityType(forIdentifier: .leanBodyMass) {
            types.insert(leanBodyMassType)
        }
        if let waistType = HKObjectType.quantityType(forIdentifier: .waistCircumference) {
            types.insert(waistType)
        }

        // Vitals
        if let bloodPressureSystolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic) {
            types.insert(bloodPressureSystolicType)
        }
        if let bloodPressureDiastolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic) {
            types.insert(bloodPressureDiastolicType)
        }
        if let respiratoryRateType = HKObjectType.quantityType(forIdentifier: .respiratoryRate) {
            types.insert(respiratoryRateType)
        }
        if let bodyTempType = HKObjectType.quantityType(forIdentifier: .bodyTemperature) {
            types.insert(bodyTempType)
        }
        if let oxygenSatType = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) {
            types.insert(oxygenSatType)
        }
        if let bloodGlucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) {
            types.insert(bloodGlucoseType)
        }

        // Nutrition (comprehensive)
        if let waterType = HKObjectType.quantityType(forIdentifier: .dietaryWater) {
            types.insert(waterType)
        }
        if let proteinType = HKObjectType.quantityType(forIdentifier: .dietaryProtein) {
            types.insert(proteinType)
        }
        if let carbsType = HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates) {
            types.insert(carbsType)
        }
        if let fiberType = HKObjectType.quantityType(forIdentifier: .dietaryFiber) {
            types.insert(fiberType)
        }
        if let sugarType = HKObjectType.quantityType(forIdentifier: .dietarySugar) {
            types.insert(sugarType)
        }
        if let fatTotalType = HKObjectType.quantityType(forIdentifier: .dietaryFatTotal) {
            types.insert(fatTotalType)
        }
        if let fatSaturatedType = HKObjectType.quantityType(forIdentifier: .dietaryFatSaturated) {
            types.insert(fatSaturatedType)
        }
        if let cholesterolType = HKObjectType.quantityType(forIdentifier: .dietaryCholesterol) {
            types.insert(cholesterolType)
        }
        if let sodiumType = HKObjectType.quantityType(forIdentifier: .dietarySodium) {
            types.insert(sodiumType)
        }
        if let caloriesType = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            types.insert(caloriesType)
        }
        if let caffeineType = HKObjectType.quantityType(forIdentifier: .dietaryCaffeine) {
            types.insert(caffeineType)
        }

        // Mindfulness
        if let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
            types.insert(mindfulType)
        }

        return types
    }

    // MARK: - Authorization

    /// Request authorization to access HealthKit data
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = .notAvailable
            throw HealthKitError.notAvailable
        }

        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)

            // Check if we got authorization for at least some types
            let authorized = typesToRead.contains { type in
                let status = healthStore.authorizationStatus(for: type)
                return status == .sharingAuthorized
            }

            await MainActor.run {
                authorizationStatus = authorized ? .authorized : .denied
            }

            print("✅ HealthKit authorization completed. Status: \(authorizationStatus)")

        } catch {
            await MainActor.run {
                authorizationStatus = .denied
            }
            print("❌ HealthKit authorization failed: \(error.localizedDescription)")
            throw HealthKitError.authorizationFailed(error)
        }
    }

    /// Check authorization status for a specific type
    func checkAuthorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        return healthStore.authorizationStatus(for: type)
    }

    // MARK: - Data Reading (Examples)

    /// Fetch recent sleep data
    func fetchSleepData(from startDate: Date, to endDate: Date) async throws -> [HKCategorySample] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitError.dataTypeNotAvailable
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let sleepSamples = samples as? [HKCategorySample] ?? []
                continuation.resume(returning: sleepSamples)
            }

            healthStore.execute(query)
        }
    }

    /// Fetch recent step count
    func fetchStepCount(from startDate: Date, to endDate: Date) async throws -> Double {
        guard let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitError.dataTypeNotAvailable
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepsType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let sum = statistics?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                continuation.resume(returning: sum)
            }

            healthStore.execute(query)
        }
    }

    /// Fetch recent workouts
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let workouts = samples as? [HKWorkout] ?? []
                continuation.resume(returning: workouts)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Data Writing (Example)

    /// Save a water intake sample
    func saveWaterIntake(milliliters: Double, date: Date = Date()) async throws {
        guard let waterType = HKObjectType.quantityType(forIdentifier: .dietaryWater) else {
            throw HealthKitError.dataTypeNotAvailable
        }

        let quantity = HKQuantity(unit: HKUnit.literUnit(with: .milli), doubleValue: milliliters)
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: date, end: date)

        try await healthStore.save(sample)
        print("✅ Saved water intake: \(milliliters)ml")
    }

    /// Save test sleep data for the last 7 days (BATCHED)
    func saveTestSleepData() async throws {
        print("📝 Creating test sleep data in database (BATCHED)...")

        let supabase = SupabaseManager.shared.client
        let userId = try await supabase.auth.session.user.id
        let calendar = Calendar.current

        // Fetch sleep period types from universal reference table
        let decoder = JSONDecoder()
        let typesResponse = try await supabase
            .from("data_entry_fields_reference")
            .select("id, reference_key")
            .eq("reference_category", value: "sleep_period_types")
            .execute()

        struct SleepPeriodType: Codable {
            let id: String
            let referenceKey: String

            enum CodingKeys: String, CodingKey {
                case id
                case referenceKey = "reference_key"
            }
        }

        let sleepPeriodTypes = try decoder.decode([SleepPeriodType].self, from: typesResponse.data)
        print("📋 Loaded \(sleepPeriodTypes.count) sleep period types")

        // Create mapping from stage type to UUID
        var stageTypeIdMap: [String: String] = [:]

        for type in sleepPeriodTypes {
            switch type.referenceKey.lowercased() {
            case "in_bed":
                stageTypeIdMap["INBED"] = type.id
            case "core":
                stageTypeIdMap["CORE"] = type.id
            case "deep":
                stageTypeIdMap["DEEP"] = type.id
            case "rem":
                stageTypeIdMap["REM"] = type.id
            case "awake":
                stageTypeIdMap["AWAKE"] = type.id
            case "asleep":
                stageTypeIdMap["ASLEEP_UNSPECIFIED"] = type.id
            default:
                break
            }
        }

        // Batch all sleep entries for bulk insert
        var allSleepEntries: [PatientSleepDataEntry] = []

        // Create sleep data for the last 7 nights
        for daysAgo in 1...7 {
            guard let sleepDate = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) else { continue }

            // ONE event_instance_id per sleep session (main nighttime session)
            let nightSessionId = UUID()

            // Sleep from 11 PM to 7 AM (8 hours)
            var startComponents = calendar.dateComponents([.year, .month, .day], from: sleepDate)
            startComponents.hour = 23
            startComponents.minute = 0
            guard let sleepStart = calendar.date(from: startComponents) else { continue }

            // Wake time next morning
            guard let sleepEnd = calendar.date(byAdding: .hour, value: 8, to: sleepStart) else { continue }

            // Calculate entry_date using 6PM rule: DATE(endTime - 6 hours)
            let adjustedEnd = sleepEnd.addingTimeInterval(-6 * 3600) // -6 hours
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFullDate]
            let entryDate = dateFormatter.string(from: calendar.startOfDay(for: adjustedEnd))

            print("  Creating sleep data for \(entryDate) (night session ID: \(nightSessionId))")

            // TEST SCENARIO 3 (Day 6): Only create in_bed and asleep_unspecified (no detailed stages)
            if daysAgo == 6 {
                // In Bed period (11 PM - 7 AM)
                allSleepEntries.append(
                    createSleepStageEntryData(
                        patientId: userId,
                        eventInstanceId: nightSessionId,
                        stageType: "INBED",
                        startTime: sleepStart,
                        endTime: sleepEnd,
                        stageTypeIdMap: stageTypeIdMap
                    )
                )

                // Asleep period (slightly shorter than in bed)
                let asleepStart = calendar.date(byAdding: .minute, value: 15, to: sleepStart)!
                let asleepEnd = calendar.date(byAdding: .minute, value: -10, to: sleepEnd)!
                allSleepEntries.append(
                    createSleepStageEntryData(
                        patientId: userId,
                        eventInstanceId: nightSessionId,
                        stageType: "ASLEEP_UNSPECIFIED",
                        startTime: asleepStart,
                        endTime: asleepEnd,
                        stageTypeIdMap: stageTypeIdMap
                    )
                )

                print("  ✅ [SCENARIO 3] Prepared simple overnight (in_bed + asleep only) for \(entryDate)")

                // Skip the detailed stage creation for this day
                continue
            }

            // Create realistic sleep stages for this night
            var currentTime = sleepStart
            var stageCount = 0

            // First, create the "In Bed" period covering the entire sleep session
            allSleepEntries.append(createSleepStageEntryData(
                patientId: userId,
                eventInstanceId: nightSessionId,
                stageType: "INBED",
                startTime: sleepStart,
                endTime: sleepEnd,
                stageTypeIdMap: stageTypeIdMap
            ))
            stageCount += 1

            // Stage 1: Core sleep (11:00 PM - 11:30 PM) - 30 min
            let stage1End = calendar.date(byAdding: .minute, value: 30, to: currentTime)!
            allSleepEntries.append(createSleepStageEntryData(
                patientId: userId,
                eventInstanceId: nightSessionId,
                stageType: "CORE",
                startTime: currentTime,
                endTime: stage1End,
                stageTypeIdMap: stageTypeIdMap
            ))
            currentTime = stage1End
            stageCount += 1

            // Stage 2: Deep sleep (11:30 PM - 1:00 AM) - 90 min
            let stage2End = calendar.date(byAdding: .minute, value: 90, to: currentTime)!
            allSleepEntries.append(createSleepStageEntryData(
                patientId: userId,
                eventInstanceId: nightSessionId,
                stageType: "DEEP",
                startTime: currentTime,
                endTime: stage2End,
                stageTypeIdMap: stageTypeIdMap
            ))
            currentTime = stage2End
            stageCount += 1

            // Stage 3: Core sleep (1:00 AM - 1:45 AM) - 45 min
            let stage3End = calendar.date(byAdding: .minute, value: 45, to: currentTime)!
            allSleepEntries.append(createSleepStageEntryData(
                patientId: userId,
                eventInstanceId: nightSessionId,
                stageType: "CORE",
                startTime: currentTime,
                endTime: stage3End,
                stageTypeIdMap: stageTypeIdMap
            ))
            currentTime = stage3End
            stageCount += 1

            // Stage 4: REM sleep (1:45 AM - 2:30 AM) - 45 min
            let stage4End = calendar.date(byAdding: .minute, value: 45, to: currentTime)!
            allSleepEntries.append(createSleepStageEntryData(
                patientId: userId,
                eventInstanceId: nightSessionId,
                stageType: "REM",
                startTime: currentTime,
                endTime: stage4End,
                stageTypeIdMap: stageTypeIdMap
            ))
            currentTime = stage4End
            stageCount += 1

            // Stage 5: Core sleep (2:30 AM - 3:15 AM) - 45 min
            let stage5End = calendar.date(byAdding: .minute, value: 45, to: currentTime)!
            allSleepEntries.append(createSleepStageEntryData(
                patientId: userId,
                eventInstanceId: nightSessionId,
                stageType: "CORE",
                startTime: currentTime,
                endTime: stage5End,
                stageTypeIdMap: stageTypeIdMap
            ))
            currentTime = stage5End
            stageCount += 1

            // Stage 6: Deep sleep (3:15 AM - 4:00 AM) - 45 min
            let stage6End = calendar.date(byAdding: .minute, value: 45, to: currentTime)!
            allSleepEntries.append(createSleepStageEntryData(
                patientId: userId,
                eventInstanceId: nightSessionId,
                stageType: "DEEP",
                startTime: currentTime,
                endTime: stage6End,
                stageTypeIdMap: stageTypeIdMap
            ))
            currentTime = stage6End
            stageCount += 1

            // Stage 7: REM sleep (4:00 AM - 5:00 AM) - 60 min
            let stage7End = calendar.date(byAdding: .minute, value: 60, to: currentTime)!
            allSleepEntries.append(createSleepStageEntryData(
                patientId: userId,
                eventInstanceId: nightSessionId,
                stageType: "REM",
                startTime: currentTime,
                endTime: stage7End,
                stageTypeIdMap: stageTypeIdMap
            ))
            currentTime = stage7End
            stageCount += 1

            // Stage 8: Core sleep (5:00 AM - 5:30 AM) - 30 min
            let stage8End = calendar.date(byAdding: .minute, value: 30, to: currentTime)!
            allSleepEntries.append(createSleepStageEntryData(
                patientId: userId,
                eventInstanceId: nightSessionId,
                stageType: "CORE",
                startTime: currentTime,
                endTime: stage8End,
                stageTypeIdMap: stageTypeIdMap
            ))
            currentTime = stage8End
            stageCount += 1

            // Stage 9: Awake (5:30 AM - 5:35 AM) - 5 min brief awakening
            let stage9End = calendar.date(byAdding: .minute, value: 5, to: currentTime)!
            allSleepEntries.append(createSleepStageEntryData(
                patientId: userId,
                eventInstanceId: nightSessionId,
                stageType: "AWAKE",
                startTime: currentTime,
                endTime: stage9End,
                stageTypeIdMap: stageTypeIdMap
            ))
            currentTime = stage9End
            stageCount += 1

            // Stage 10: REM sleep (5:35 AM - 6:30 AM) - 55 min
            let stage10End = calendar.date(byAdding: .minute, value: 55, to: currentTime)!
            allSleepEntries.append(createSleepStageEntryData(
                patientId: userId,
                eventInstanceId: nightSessionId,
                stageType: "REM",
                startTime: currentTime,
                endTime: stage10End,
                stageTypeIdMap: stageTypeIdMap
            ))
            currentTime = stage10End
            stageCount += 1

            // Stage 11: Awake (6:30 AM - 6:35 AM) - 5 min brief awakening
            let stage11End = calendar.date(byAdding: .minute, value: 5, to: currentTime)!
            allSleepEntries.append(createSleepStageEntryData(
                patientId: userId,
                eventInstanceId: nightSessionId,
                stageType: "AWAKE",
                startTime: currentTime,
                endTime: stage11End,
                stageTypeIdMap: stageTypeIdMap
            ))
            currentTime = stage11End
            stageCount += 1

            // Stage 12: Core sleep (6:35 AM - 7:00 AM) - 25 min (light sleep before waking)
            allSleepEntries.append(createSleepStageEntryData(
                patientId: userId,
                eventInstanceId: nightSessionId,
                stageType: "CORE",
                startTime: currentTime,
                endTime: sleepEnd,
                stageTypeIdMap: stageTypeIdMap
            ))
            stageCount += 1

            print("  ✅ Created \(stageCount) sleep stages for \(entryDate)")

            // TEST SCENARIOS FOR DIFFERENT SLEEP DATA TYPES

            // Scenario 1 (Day 2): Add a nap with ONLY asleep period (no detailed stages)
            if daysAgo == 2 {
                let nap1SessionId = UUID() // Separate session for this nap
                let napStart = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: sleepDate) ?? sleepDate
                let napEnd = calendar.date(byAdding: .minute, value: 45, to: napStart)!

                // Only add asleep_unspecified period (no detailed stages)
                allSleepEntries.append(createSleepStageEntryData(
                patientId: userId,
                eventInstanceId: nap1SessionId,
                stageType: "ASLEEP_UNSPECIFIED",
                startTime: napStart,
                endTime: napEnd,
                stageTypeIdMap: stageTypeIdMap
            ))

                print("  ✨ [SCENARIO 1] Added 45-min nap (2:00 PM - 2:45 PM) with ONLY asleep period")
            }

            // Scenario 2 (Day 4): Add a nap with detailed stages (Core + REM)
            if daysAgo == 4 {
                let nap2SessionId = UUID() // Separate session for this nap
                let napStart = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: sleepDate) ?? sleepDate
                let napMid = calendar.date(byAdding: .minute, value: 60, to: napStart)!
                let napEnd = calendar.date(byAdding: .minute, value: 90, to: napStart)!

                // Core sleep (60 min)
                allSleepEntries.append(createSleepStageEntryData(
                patientId: userId,
                eventInstanceId: nap2SessionId,
                stageType: "CORE",
                startTime: napStart,
                endTime: napMid,
                stageTypeIdMap: stageTypeIdMap
            ))

                // REM sleep (30 min)
                allSleepEntries.append(createSleepStageEntryData(
                patientId: userId,
                eventInstanceId: nap2SessionId,
                stageType: "REM",
                startTime: napMid,
                endTime: napEnd,
                stageTypeIdMap: stageTypeIdMap
            ))

                print("  ✨ [SCENARIO 2] Added 90-min nap (1:00 PM - 2:30 PM) with Core + REM stages")
            }

            // Original nap on day 5 (kept for compatibility)
            if daysAgo == 5 {
                let nap3SessionId = UUID() // Separate session for this nap
                let napStart = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: sleepDate) ?? sleepDate
                let napMid = calendar.date(byAdding: .hour, value: 2, to: napStart)!
                let napEnd = calendar.date(byAdding: .hour, value: 3, to: napStart)!

                // Core sleep (2 hours)
                allSleepEntries.append(createSleepStageEntryData(
                patientId: userId,
                eventInstanceId: nap3SessionId,
                stageType: "CORE",
                startTime: napStart,
                endTime: napMid,
                stageTypeIdMap: stageTypeIdMap
            ))

                // REM sleep (1 hour)
                allSleepEntries.append(createSleepStageEntryData(
                patientId: userId,
                eventInstanceId: nap3SessionId,
                stageType: "REM",
                startTime: napMid,
                endTime: napEnd,
                stageTypeIdMap: stageTypeIdMap
            ))

                print("  ✨ Added 3-hour nap (11 AM - 2 PM) with Core + REM stages")
            }
        }

        // Bulk insert all entries - statement-level trigger processes them in batch
        print("📦 Inserting \(allSleepEntries.count) sleep entries...")

        try await supabase
            .from("patient_sleep_data_entries")
            .insert(allSleepEntries)
            .execute()

        print("✅ Successfully created test sleep data for 7 nights (\(allSleepEntries.count) total entries)!")
        print("ℹ️ Events, sessions, and aggregations calculated automatically by database triggers")
    }

    // Helper function to create sleep entry data without inserting (UNUSED - for future batched implementation)
    private func createSleepStageEntryData(
        patientId: UUID,
        eventInstanceId: UUID,
        stageType: String,
        startTime: Date,
        endTime: Date,
        stageTypeIdMap: [String: String]
    ) -> PatientSleepDataEntry {
        guard let stageReferenceId = stageTypeIdMap[stageType] else {
            fatalError("Missing stage type mapping for \(stageType)")
        }

        let deviceTimezone = TimeZone.current.identifier

        return PatientSleepDataEntry(
            patientId: patientId,
            eventInstanceId: eventInstanceId,
            periodStart: startTime,
            periodEnd: endTime,
            periodTypeId: stageReferenceId,
            source: "healthkit",
            userTimezone: deviceTimezone,
            metadata: [
                "test_data": .bool(true),
                "stage_type": .string(stageType)
            ]
        )
    }


    // MARK: - Errors

    enum HealthKitError: Error, LocalizedError {
        case notAvailable
        case authorizationFailed(Error)
        case dataTypeNotAvailable
        case queryFailed(Error)

        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "HealthKit is not available on this device"
            case .authorizationFailed(let error):
                return "Authorization failed: \(error.localizedDescription)"
            case .dataTypeNotAvailable:
                return "The requested data type is not available"
            case .queryFailed(let error):
                return "Query failed: \(error.localizedDescription)"
            }
        }
    }
}
