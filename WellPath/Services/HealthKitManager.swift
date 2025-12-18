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
        restoreAuthorizationStatus()
    }

    /// Restore authorization status from UserDefaults on app launch
    private func restoreAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        // Check if we previously granted authorization
        if UserDefaults.standard.bool(forKey: "healthKitAuthorizationGranted") {
            // Verify we still have access by checking a common type
            if let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) {
                let status = healthStore.authorizationStatus(for: stepsType)
                if status == .sharingAuthorized {
                    authorizationStatus = .authorized
                    print("✅ HealthKit authorization restored from previous session")
                    return
                }
            }
        }
        // Otherwise leave as .notDetermined
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
                if authorized {
                    UserDefaults.standard.set(true, forKey: "healthKitAuthorizationGranted")
                }
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

    /// Save test sleep data for the last 7 days (BATCHED) - uses patient_category_samples
    func saveTestSleepData() async throws {
        print("📝 Creating test sleep data in database (BATCHED)...")

        let supabase = SupabaseManager.shared.client
        let userId = try await supabase.auth.session.user.id
        let calendar = Calendar.current
        let deviceTimezone = TimeZone.current.identifier

        // Sleep period type keys: awake, rem, core, deep

        // Batch all sleep samples for bulk insert
        var allSleepSamples: [CategorySampleWrite] = []

        // Helper to create a sleep period sample
        func createSleepSample(stageValue: String, startTime: Date, endTime: Date, eventInstanceId: UUID) -> CategorySampleWrite {
            CategorySampleWrite.create(
                patientId: userId,
                categoryType: CategoryTypes.sleepPeriodTypes,
                value: stageValue,
                startTime: startTime,
                endTime: endTime,
                source: .wellpathInput,
                timezone: deviceTimezone,
                metadata: ["test_data": .bool(true)],
                eventInstanceId: eventInstanceId
            )
        }

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

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let entryDate = dateFormatter.string(from: sleepDate)

            print("  Creating sleep data for \(entryDate) (night session ID: \(nightSessionId))")

            // Create realistic sleep stages for this night
            // Stage values: awake, rem, core, deep
            var currentTime = sleepStart

            // Stage 1: Core sleep (11:00 PM - 11:30 PM) - 30 min
            let stage1End = calendar.date(byAdding: .minute, value: 30, to: currentTime)!
            allSleepSamples.append(createSleepSample(stageValue: SleepPeriodTypeKeys.core, startTime: currentTime, endTime: stage1End, eventInstanceId: nightSessionId))
            currentTime = stage1End

            // Stage 2: Deep sleep (11:30 PM - 1:00 AM) - 90 min
            let stage2End = calendar.date(byAdding: .minute, value: 90, to: currentTime)!
            allSleepSamples.append(createSleepSample(stageValue: SleepPeriodTypeKeys.deep, startTime: currentTime, endTime: stage2End, eventInstanceId: nightSessionId))
            currentTime = stage2End

            // Stage 3: Core sleep (1:00 AM - 1:45 AM) - 45 min
            let stage3End = calendar.date(byAdding: .minute, value: 45, to: currentTime)!
            allSleepSamples.append(createSleepSample(stageValue: SleepPeriodTypeKeys.core, startTime: currentTime, endTime: stage3End, eventInstanceId: nightSessionId))
            currentTime = stage3End

            // Stage 4: REM sleep (1:45 AM - 2:30 AM) - 45 min
            let stage4End = calendar.date(byAdding: .minute, value: 45, to: currentTime)!
            allSleepSamples.append(createSleepSample(stageValue: SleepPeriodTypeKeys.rem, startTime: currentTime, endTime: stage4End, eventInstanceId: nightSessionId))
            currentTime = stage4End

            // Stage 5: Core sleep (2:30 AM - 3:15 AM) - 45 min
            let stage5End = calendar.date(byAdding: .minute, value: 45, to: currentTime)!
            allSleepSamples.append(createSleepSample(stageValue: SleepPeriodTypeKeys.core, startTime: currentTime, endTime: stage5End, eventInstanceId: nightSessionId))
            currentTime = stage5End

            // Stage 6: Deep sleep (3:15 AM - 4:00 AM) - 45 min
            let stage6End = calendar.date(byAdding: .minute, value: 45, to: currentTime)!
            allSleepSamples.append(createSleepSample(stageValue: SleepPeriodTypeKeys.deep, startTime: currentTime, endTime: stage6End, eventInstanceId: nightSessionId))
            currentTime = stage6End

            // Stage 7: REM sleep (4:00 AM - 5:00 AM) - 60 min
            let stage7End = calendar.date(byAdding: .minute, value: 60, to: currentTime)!
            allSleepSamples.append(createSleepSample(stageValue: SleepPeriodTypeKeys.rem, startTime: currentTime, endTime: stage7End, eventInstanceId: nightSessionId))
            currentTime = stage7End

            // Stage 8: Core sleep (5:00 AM - 5:30 AM) - 30 min
            let stage8End = calendar.date(byAdding: .minute, value: 30, to: currentTime)!
            allSleepSamples.append(createSleepSample(stageValue: SleepPeriodTypeKeys.core, startTime: currentTime, endTime: stage8End, eventInstanceId: nightSessionId))
            currentTime = stage8End

            // Stage 9: Awake (5:30 AM - 5:35 AM) - 5 min brief awakening
            let stage9End = calendar.date(byAdding: .minute, value: 5, to: currentTime)!
            allSleepSamples.append(createSleepSample(stageValue: SleepPeriodTypeKeys.awake, startTime: currentTime, endTime: stage9End, eventInstanceId: nightSessionId))
            currentTime = stage9End

            // Stage 10: REM sleep (5:35 AM - 6:30 AM) - 55 min
            let stage10End = calendar.date(byAdding: .minute, value: 55, to: currentTime)!
            allSleepSamples.append(createSleepSample(stageValue: SleepPeriodTypeKeys.rem, startTime: currentTime, endTime: stage10End, eventInstanceId: nightSessionId))
            currentTime = stage10End

            // Stage 11: Awake (6:30 AM - 6:35 AM) - 5 min brief awakening
            let stage11End = calendar.date(byAdding: .minute, value: 5, to: currentTime)!
            allSleepSamples.append(createSleepSample(stageValue: SleepPeriodTypeKeys.awake, startTime: currentTime, endTime: stage11End, eventInstanceId: nightSessionId))
            currentTime = stage11End

            // Stage 12: Core sleep (6:35 AM - 7:00 AM) - 25 min (light sleep before waking)
            allSleepSamples.append(createSleepSample(stageValue: SleepPeriodTypeKeys.core, startTime: currentTime, endTime: sleepEnd, eventInstanceId: nightSessionId))

            print("  ✅ Created 12 sleep stages for \(entryDate)")

            // Add nap on day 4 with Core + REM
            if daysAgo == 4 {
                let napSessionId = UUID()
                let napStart = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: sleepDate) ?? sleepDate
                let napMid = calendar.date(byAdding: .minute, value: 60, to: napStart)!
                let napEnd = calendar.date(byAdding: .minute, value: 90, to: napStart)!

                allSleepSamples.append(createSleepSample(stageValue: SleepPeriodTypeKeys.core, startTime: napStart, endTime: napMid, eventInstanceId: napSessionId))
                allSleepSamples.append(createSleepSample(stageValue: SleepPeriodTypeKeys.rem, startTime: napMid, endTime: napEnd, eventInstanceId: napSessionId))

                print("  ✨ Added 90-min nap (1:00 PM - 2:30 PM) with Core + REM stages")
            }

            // Add nap on day 5 with Core + REM
            if daysAgo == 5 {
                let napSessionId = UUID()
                let napStart = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: sleepDate) ?? sleepDate
                let napMid = calendar.date(byAdding: .hour, value: 2, to: napStart)!
                let napEnd = calendar.date(byAdding: .hour, value: 3, to: napStart)!

                allSleepSamples.append(createSleepSample(stageValue: SleepPeriodTypeKeys.core, startTime: napStart, endTime: napMid, eventInstanceId: napSessionId))
                allSleepSamples.append(createSleepSample(stageValue: SleepPeriodTypeKeys.rem, startTime: napMid, endTime: napEnd, eventInstanceId: napSessionId))

                print("  ✨ Added 3-hour nap (11 AM - 2 PM) with Core + REM stages")
            }
        }

        // Bulk insert all samples into patient_category_samples
        print("📦 Inserting \(allSleepSamples.count) sleep samples...")

        try await supabase
            .from("patient_category_samples")
            .insert(allSleepSamples)
            .execute()

        print("✅ Successfully created test sleep data for 7 nights (\(allSleepSamples.count) total samples)!")
        print("ℹ️ Sleep sessions and aggregations calculated automatically by database triggers")
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
