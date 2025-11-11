//
//  HealthKitManager.swift
//  WellPath
//
//  Manages HealthKit authorization and data access
//

import Foundation
import HealthKit

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

    /// Save test sleep data for the last 7 days
    func saveTestSleepData() async throws {
        print("📝 Creating test sleep data in database...")

        let supabase = SupabaseManager.shared.client
        let userId = try await supabase.auth.session.user.id
        let calendar = Calendar.current

        // Fetch sleep period types from universal reference table
        let decoder = JSONDecoder()
        let typesResponse = try await supabase
            .from("data_entry_fields_reference")
            .select("id, reference_key, display_name")
            .eq("reference_category", value: "sleep_period_types")
            .execute()

        struct SleepPeriodType: Codable {
            let id: String
            let referenceKey: String
            let displayName: String

            enum CodingKeys: String, CodingKey {
                case id
                case referenceKey = "reference_key"
                case displayName = "display_name"
            }

            var healthkitIdentifier: String {
                return "HKCategoryValueSleepAnalysis" + referenceKey.prefix(1).uppercased() + referenceKey.dropFirst()
            }
        }

        let sleepPeriodTypes = try decoder.decode([SleepPeriodType].self, from: typesResponse.data)
        print("📋 Loaded \(sleepPeriodTypes.count) sleep period types")

        // Create mappings for both UUID (FK) and text key (readability)
        var stageTypeIdMap: [String: String] = [:]     // UUID for FK
        var stageTypeKeyMap: [String: String] = [:]    // Text for readability

        for type in sleepPeriodTypes {
            // Map both UUID and reference_key for each stage type
            switch type.referenceKey.lowercased() {
            case "in_bed":
                stageTypeIdMap["INBED"] = type.id
                stageTypeKeyMap["INBED"] = type.referenceKey
            case "core":
                stageTypeIdMap["CORE"] = type.id
                stageTypeKeyMap["CORE"] = type.referenceKey
            case "deep":
                stageTypeIdMap["DEEP"] = type.id
                stageTypeKeyMap["DEEP"] = type.referenceKey
            case "rem":
                stageTypeIdMap["REM"] = type.id
                stageTypeKeyMap["REM"] = type.referenceKey
            case "awake":
                stageTypeIdMap["AWAKE"] = type.id
                stageTypeKeyMap["AWAKE"] = type.referenceKey
            case "unspecified":
                stageTypeIdMap["ASLEEP_UNSPECIFIED"] = type.id
                stageTypeKeyMap["ASLEEP_UNSPECIFIED"] = type.referenceKey
            default:
                break
            }
        }

        // Create sleep data for the last 7 nights
        for daysAgo in 1...7 {
            guard let sleepDate = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) else { continue }

            // Entry date in ISO format
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFullDate]
            let entryDate = dateFormatter.string(from: sleepDate)

            // Sleep from 11 PM to 7 AM (8 hours)
            var startComponents = calendar.dateComponents([.year, .month, .day], from: sleepDate)
            startComponents.hour = 23
            startComponents.minute = 0
            guard let sleepStart = calendar.date(from: startComponents) else { continue }

            var endComponents = calendar.dateComponents([.year, .month, .day], from: sleepDate)
            endComponents.day! += 1
            endComponents.hour = 7
            endComponents.minute = 0
            guard let sleepEnd = calendar.date(from: endComponents) else { continue }

            print("  Creating sleep data for \(entryDate)")

            // TEST SCENARIO 3 (Day 6): Only create in_bed and asleep_unspecified (no detailed stages)
            if daysAgo == 6 {
                var entries: [PatientDataEntry] = []

                // In Bed period (11 PM - 7 AM)
                entries.append(contentsOf: createSleepStageEntry(
                    patientId: userId,
                    entryDate: entryDate,
                    stageType: "INBED",
                    startTime: sleepStart,
                    endTime: sleepEnd,
                    stageTypeIdMap: stageTypeIdMap,
                    stageTypeKeyMap: stageTypeKeyMap
                ))

                // Asleep period (slightly shorter than in bed)
                let asleepStart = calendar.date(byAdding: .minute, value: 15, to: sleepStart)!
                let asleepEnd = calendar.date(byAdding: .minute, value: -10, to: sleepEnd)!
                entries.append(contentsOf: createSleepStageEntry(
                    patientId: userId,
                    entryDate: entryDate,
                    stageType: "ASLEEP_UNSPECIFIED",
                    startTime: asleepStart,
                    endTime: asleepEnd,
                    stageTypeIdMap: stageTypeIdMap,
                    stageTypeKeyMap: stageTypeKeyMap
                ))

                // Insert entries
                do {
                    _ = try await supabase
                        .from("patient_data_entries")
                        .insert(entries)
                        .execute()

                    print("  ✅ [SCENARIO 3] Created simple overnight (in_bed + asleep only) for \(entryDate)")
                } catch {
                    print("  ❌ Failed to insert sleep data for \(entryDate): \(error)")
                    throw error
                }

                // Skip the detailed stage creation for this day
                continue
            }

            // Create realistic sleep stages for this night
            var entries: [PatientDataEntry] = []
            var currentTime = sleepStart

            // First, create the "In Bed" period covering the entire sleep session
            entries.append(contentsOf: createSleepStageEntry(
                patientId: userId,
                entryDate: entryDate,
                stageType: "INBED",
                startTime: sleepStart,
                endTime: sleepEnd,
                stageTypeIdMap: stageTypeIdMap,
                stageTypeKeyMap: stageTypeKeyMap
            ))

            // Stage 1: Core sleep (11:00 PM - 11:30 PM) - 30 min
            let stage1End = calendar.date(byAdding: .minute, value: 30, to: currentTime)!
            entries.append(contentsOf: createSleepStageEntry(
                patientId: userId,
                entryDate: entryDate,
                stageType: "CORE",
                startTime: currentTime,
                endTime: stage1End,
                stageTypeIdMap: stageTypeIdMap,
                stageTypeKeyMap: stageTypeKeyMap
            ))
            currentTime = stage1End

            // Stage 2: Deep sleep (11:30 PM - 1:00 AM) - 90 min
            let stage2End = calendar.date(byAdding: .minute, value: 90, to: currentTime)!
            entries.append(contentsOf: createSleepStageEntry(
                patientId: userId,
                entryDate: entryDate,
                stageType: "DEEP",
                startTime: currentTime,
                endTime: stage2End,
                stageTypeIdMap: stageTypeIdMap,
                stageTypeKeyMap: stageTypeKeyMap
            ))
            currentTime = stage2End

            // Stage 3: Core sleep (1:00 AM - 1:45 AM) - 45 min
            let stage3End = calendar.date(byAdding: .minute, value: 45, to: currentTime)!
            entries.append(contentsOf: createSleepStageEntry(
                patientId: userId,
                entryDate: entryDate,
                stageType: "CORE",
                startTime: currentTime,
                endTime: stage3End,
                stageTypeIdMap: stageTypeIdMap,
                stageTypeKeyMap: stageTypeKeyMap
            ))
            currentTime = stage3End

            // Stage 4: REM sleep (1:45 AM - 2:30 AM) - 45 min
            let stage4End = calendar.date(byAdding: .minute, value: 45, to: currentTime)!
            entries.append(contentsOf: createSleepStageEntry(
                patientId: userId,
                entryDate: entryDate,
                stageType: "REM",
                startTime: currentTime,
                endTime: stage4End,
                stageTypeIdMap: stageTypeIdMap,
                stageTypeKeyMap: stageTypeKeyMap
            ))
            currentTime = stage4End

            // Stage 5: Core sleep (2:30 AM - 3:15 AM) - 45 min
            let stage5End = calendar.date(byAdding: .minute, value: 45, to: currentTime)!
            entries.append(contentsOf: createSleepStageEntry(
                patientId: userId,
                entryDate: entryDate,
                stageType: "CORE",
                startTime: currentTime,
                endTime: stage5End,
                stageTypeIdMap: stageTypeIdMap,
                stageTypeKeyMap: stageTypeKeyMap
            ))
            currentTime = stage5End

            // Stage 6: Deep sleep (3:15 AM - 4:00 AM) - 45 min
            let stage6End = calendar.date(byAdding: .minute, value: 45, to: currentTime)!
            entries.append(contentsOf: createSleepStageEntry(
                patientId: userId,
                entryDate: entryDate,
                stageType: "DEEP",
                startTime: currentTime,
                endTime: stage6End,
                stageTypeIdMap: stageTypeIdMap,
                stageTypeKeyMap: stageTypeKeyMap
            ))
            currentTime = stage6End

            // Stage 7: REM sleep (4:00 AM - 5:00 AM) - 60 min
            let stage7End = calendar.date(byAdding: .minute, value: 60, to: currentTime)!
            entries.append(contentsOf: createSleepStageEntry(
                patientId: userId,
                entryDate: entryDate,
                stageType: "REM",
                startTime: currentTime,
                endTime: stage7End,
                stageTypeIdMap: stageTypeIdMap,
                stageTypeKeyMap: stageTypeKeyMap
            ))
            currentTime = stage7End

            // Stage 8: Core sleep (5:00 AM - 5:30 AM) - 30 min
            let stage8End = calendar.date(byAdding: .minute, value: 30, to: currentTime)!
            entries.append(contentsOf: createSleepStageEntry(
                patientId: userId,
                entryDate: entryDate,
                stageType: "CORE",
                startTime: currentTime,
                endTime: stage8End,
                stageTypeIdMap: stageTypeIdMap,
                stageTypeKeyMap: stageTypeKeyMap
            ))
            currentTime = stage8End

            // Stage 9: Awake (5:30 AM - 5:35 AM) - 5 min brief awakening
            let stage9End = calendar.date(byAdding: .minute, value: 5, to: currentTime)!
            entries.append(contentsOf: createSleepStageEntry(
                patientId: userId,
                entryDate: entryDate,
                stageType: "AWAKE",
                startTime: currentTime,
                endTime: stage9End,
                stageTypeIdMap: stageTypeIdMap,
                stageTypeKeyMap: stageTypeKeyMap
            ))
            currentTime = stage9End

            // Stage 10: REM sleep (5:35 AM - 6:30 AM) - 55 min
            let stage10End = calendar.date(byAdding: .minute, value: 55, to: currentTime)!
            entries.append(contentsOf: createSleepStageEntry(
                patientId: userId,
                entryDate: entryDate,
                stageType: "REM",
                startTime: currentTime,
                endTime: stage10End,
                stageTypeIdMap: stageTypeIdMap,
                stageTypeKeyMap: stageTypeKeyMap
            ))
            currentTime = stage10End

            // Stage 11: Awake (6:30 AM - 6:35 AM) - 5 min brief awakening
            let stage11End = calendar.date(byAdding: .minute, value: 5, to: currentTime)!
            entries.append(contentsOf: createSleepStageEntry(
                patientId: userId,
                entryDate: entryDate,
                stageType: "AWAKE",
                startTime: currentTime,
                endTime: stage11End,
                stageTypeIdMap: stageTypeIdMap,
                stageTypeKeyMap: stageTypeKeyMap
            ))
            currentTime = stage11End

            // Stage 12: Core sleep (6:35 AM - 7:00 AM) - 25 min (light sleep before waking)
            entries.append(contentsOf: createSleepStageEntry(
                patientId: userId,
                entryDate: entryDate,
                stageType: "CORE",
                startTime: currentTime,
                endTime: sleepEnd,
                stageTypeIdMap: stageTypeIdMap,
                stageTypeKeyMap: stageTypeKeyMap
            ))

            // Insert all entries for this night
            do {
                _ = try await supabase
                    .from("patient_data_entries")
                    .insert(entries)
                    .execute()

                print("  ✅ Created \(entries.count / 3) sleep stages for \(entryDate)")
            } catch {
                print("  ❌ Failed to insert sleep data for \(entryDate): \(error)")
                throw error
            }

            // TEST SCENARIOS FOR DIFFERENT SLEEP DATA TYPES

            // Scenario 1 (Day 2): Add a nap with ONLY asleep period (no detailed stages)
            if daysAgo == 2 {
                let napStart = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: sleepDate) ?? sleepDate
                let napEnd = calendar.date(byAdding: .minute, value: 45, to: napStart)!

                var napEntries: [PatientDataEntry] = []

                // Only add asleep_unspecified period (no detailed stages)
                napEntries.append(contentsOf: createSleepStageEntry(
                    patientId: userId,
                    entryDate: entryDate,
                    stageType: "ASLEEP_UNSPECIFIED",
                    startTime: napStart,
                    endTime: napEnd,
                    stageTypeIdMap: stageTypeIdMap,
                    stageTypeKeyMap: stageTypeKeyMap
                ))

                try await supabase.from("patient_data_entries").insert(napEntries).execute()
                print("  ✨ [SCENARIO 1] Added 45-min nap (2:00 PM - 2:45 PM) with ONLY asleep period")
            }

            // Scenario 2 (Day 4): Add a nap with detailed stages (Core + REM)
            if daysAgo == 4 {
                let napStart = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: sleepDate) ?? sleepDate
                let napMid = calendar.date(byAdding: .minute, value: 60, to: napStart)!
                let napEnd = calendar.date(byAdding: .minute, value: 90, to: napStart)!

                var napEntries: [PatientDataEntry] = []

                // Core sleep (60 min)
                napEntries.append(contentsOf: createSleepStageEntry(
                    patientId: userId,
                    entryDate: entryDate,
                    stageType: "CORE",
                    startTime: napStart,
                    endTime: napMid,
                    stageTypeIdMap: stageTypeIdMap,
                    stageTypeKeyMap: stageTypeKeyMap
                ))

                // REM sleep (30 min)
                napEntries.append(contentsOf: createSleepStageEntry(
                    patientId: userId,
                    entryDate: entryDate,
                    stageType: "REM",
                    startTime: napMid,
                    endTime: napEnd,
                    stageTypeIdMap: stageTypeIdMap,
                    stageTypeKeyMap: stageTypeKeyMap
                ))

                try await supabase.from("patient_data_entries").insert(napEntries).execute()
                print("  ✨ [SCENARIO 2] Added 90-min nap (1:00 PM - 2:30 PM) with Core + REM stages")
            }

            // Original nap on day 5 (kept for compatibility)
            if daysAgo == 5 {
                let napStart = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: sleepDate) ?? sleepDate
                let napMid = calendar.date(byAdding: .hour, value: 2, to: napStart)!
                let napEnd = calendar.date(byAdding: .hour, value: 3, to: napStart)!

                var napEntries: [PatientDataEntry] = []

                // Core sleep (2 hours)
                napEntries.append(contentsOf: createSleepStageEntry(
                    patientId: userId,
                    entryDate: entryDate,
                    stageType: "CORE",
                    startTime: napStart,
                    endTime: napMid,
                    stageTypeIdMap: stageTypeIdMap,
                stageTypeKeyMap: stageTypeKeyMap
                ))

                // REM sleep (1 hour)
                napEntries.append(contentsOf: createSleepStageEntry(
                    patientId: userId,
                    entryDate: entryDate,
                    stageType: "REM",
                    startTime: napMid,
                    endTime: napEnd,
                    stageTypeIdMap: stageTypeIdMap,
                stageTypeKeyMap: stageTypeKeyMap
                ))

                try await supabase.from("patient_data_entries").insert(napEntries).execute()
                print("  ✨ Added 3-hour nap (11 AM - 2 PM) with Core + REM stages")
            }
        }

        print("✅ Successfully created test sleep data for 7 nights!")
    }

    private func createSleepStageEntry(
        patientId: UUID,
        entryDate: String,
        stageType: String,
        startTime: Date,
        endTime: Date,
        stageTypeIdMap: [String: String],
        stageTypeKeyMap: [String: String]
    ) -> [PatientDataEntry] {
        let eventId = UUID()

        // Get both UUID and text key for this stage type
        let stageReferenceId = stageTypeIdMap[stageType]      // UUID for FK
        let stageReferenceKey = stageTypeKeyMap[stageType]    // Text for filtering

        // Calculate entry_date using 6PM rule: DATE(endTime + 6 hours)
        let calendar = Calendar.current
        let adjustedEndTime = endTime.addingTimeInterval(6 * 3600) // +6 hours
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        let calculatedEntryDate = dateFormatter.string(from: calendar.startOfDay(for: adjustedEndTime))

        // Create 3 entries: START, END, and TYPE
        return [
            // Start time entry
            PatientDataEntry(
                patientId: patientId,
                entryDate: calculatedEntryDate,
                fieldId: "DEF_SLEEP_PERIOD_START",
                valueTimestamp: startTime,
                valueText: nil,
                valueReference: nil,
                valueCategory: nil,
                metadata: nil,
                eventInstanceId: eventId,
                source: "healthkit"
            ),
            // End time entry
            PatientDataEntry(
                patientId: patientId,
                entryDate: calculatedEntryDate,
                fieldId: "DEF_SLEEP_PERIOD_END",
                valueTimestamp: endTime,
                valueText: nil,
                valueReference: nil,
                valueCategory: nil,
                metadata: nil,
                eventInstanceId: eventId,
                source: "healthkit"
            ),
            // Type entry - stores UUID (FK) with text/category in metadata for auditing
            PatientDataEntry(
                patientId: patientId,
                entryDate: calculatedEntryDate,
                fieldId: "DEF_SLEEP_PERIOD_TYPE",
                valueTimestamp: nil,
                valueText: nil,
                valueReference: stageReferenceId,   // UUID - FK to data_entry_fields_reference
                valueCategory: nil,  // Can't use due to one_value constraint
                metadata: stageReferenceKey != nil ? [
                    "reference_key": stageReferenceKey!,  // "rem" for debugging
                    "reference_category": "sleep_period_types"
                ] : nil,
                eventInstanceId: eventId,
                source: "healthkit"
            )
        ]
    }

    // Data model for patient_data_entries table
    private struct PatientDataEntry: Codable {
        let patientId: UUID
        let entryDate: String
        let fieldId: String
        let valueTimestamp: Date?
        let valueText: String?        // For text values
        let valueReference: String?   // For UUID FKs
        let valueCategory: String?    // Can't use (violates one_value constraint)
        let metadata: [String: String]?  // Store extra info like readable text
        let eventInstanceId: UUID
        let source: String

        enum CodingKeys: String, CodingKey {
            case patientId = "patient_id"
            case entryDate = "entry_date"
            case fieldId = "field_id"
            case valueTimestamp = "value_timestamp"
            case valueText = "value_text"
            case valueReference = "value_reference"
            case valueCategory = "value_category"
            case metadata
            case eventInstanceId = "event_instance_id"
            case source
        }

        // Custom encoding to omit nil values (prevents one_value_check constraint violation)
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(patientId, forKey: .patientId)
            try container.encode(entryDate, forKey: .entryDate)
            try container.encode(fieldId, forKey: .fieldId)
            try container.encode(eventInstanceId, forKey: .eventInstanceId)
            try container.encode(source, forKey: .source)

            // Only encode non-nil value fields
            if let valueTimestamp = valueTimestamp {
                try container.encode(valueTimestamp, forKey: .valueTimestamp)
            }
            if let valueText = valueText {
                try container.encode(valueText, forKey: .valueText)
            }
            if let valueReference = valueReference {
                try container.encode(valueReference, forKey: .valueReference)
            }
            if let valueCategory = valueCategory {
                try container.encode(valueCategory, forKey: .valueCategory)
            }
            if let metadata = metadata {
                try container.encode(metadata, forKey: .metadata)
            }
        }
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
