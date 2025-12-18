//
//  HealthKitTypeConfig.swift
//  WellPath
//
//  Configuration registry mapping HealthKit types to WellPath database types.
//  Used by HealthKitSyncService for comprehensive data syncing.
//

import Foundation
import HealthKit

// MARK: - Quantity Type Configuration

/// Configuration for mapping HealthKit quantity types to WellPath database
struct HealthKitQuantityConfig {
    let hkIdentifier: HKQuantityTypeIdentifier
    let dbQuantityType: String
    let hkUnit: HKUnit
    let dbUnit: String
    let displayName: String
    let category: SyncCategory

    enum SyncCategory: String {
        case vitals
        case body
        case activity
        case nutrition
        case mental
    }

    /// Get the HKQuantityType for this config
    var hkQuantityType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: hkIdentifier)
    }
}

// MARK: - Workout Category Mapping

/// Maps HKWorkoutActivityType to WellPath quantity types
/// Uses patient_quantity_samples with quantity_type: cardio, strength_training, hiit, mobility
struct WorkoutCategoryMapping {
    let activityType: HKWorkoutActivityType
    let wellpathCategory: String          // cardio, strength, hiit, mobility
    let quantityType: String              // cardio, strength_training, hiit, mobility
    let displayName: String
    let workoutSubtype: String?           // Maps to sample_category_types_reference.reference_key
}

// MARK: - Type Registry

/// Central registry of all HealthKit types to sync
struct HealthKitTypeRegistry {

    // MARK: - Quantity Types

    /// All quantity types to sync from HealthKit
    static let quantityConfigs: [HealthKitQuantityConfig] = [
        // Vitals
        .init(hkIdentifier: .heartRate, dbQuantityType: QuantityTypes.heartRate, hkUnit: .count().unitDivided(by: .minute()), dbUnit: "beats_per_minute", displayName: "Heart Rate", category: .vitals),
        .init(hkIdentifier: .heartRateVariabilitySDNN, dbQuantityType: QuantityTypes.hrv, hkUnit: .secondUnit(with: .milli), dbUnit: "millisecond", displayName: "HRV", category: .vitals),
        .init(hkIdentifier: .restingHeartRate, dbQuantityType: QuantityTypes.restingHeartRate, hkUnit: .count().unitDivided(by: .minute()), dbUnit: "beats_per_minute", displayName: "Resting Heart Rate", category: .vitals),
        .init(hkIdentifier: .walkingHeartRateAverage, dbQuantityType: QuantityTypes.walkingHeartRate, hkUnit: .count().unitDivided(by: .minute()), dbUnit: "beats_per_minute", displayName: "Walking Heart Rate", category: .vitals),
        .init(hkIdentifier: .vo2Max, dbQuantityType: QuantityTypes.vo2Max, hkUnit: HKUnit(from: "mL/kg*min"), dbUnit: "milliliters_per_kilogram_per_minute", displayName: "VO2 Max", category: .vitals),
        .init(hkIdentifier: .oxygenSaturation, dbQuantityType: QuantityTypes.oxygenSaturation, hkUnit: .percent(), dbUnit: "percent", displayName: "Blood Oxygen", category: .vitals),
        .init(hkIdentifier: .respiratoryRate, dbQuantityType: QuantityTypes.respiratoryRate, hkUnit: .count().unitDivided(by: .minute()), dbUnit: "breaths_per_minute", displayName: "Respiratory Rate", category: .vitals),
        .init(hkIdentifier: .bodyTemperature, dbQuantityType: QuantityTypes.bodyTemperature, hkUnit: .degreeCelsius(), dbUnit: "degrees_celsius", displayName: "Body Temperature", category: .vitals),
        .init(hkIdentifier: .bloodGlucose, dbQuantityType: QuantityTypes.bloodGlucose, hkUnit: HKUnit(from: "mg/dL"), dbUnit: "milligrams_per_deciliter", displayName: "Blood Glucose", category: .vitals),

        // Body Measurements
        .init(hkIdentifier: .bodyMass, dbQuantityType: QuantityTypes.weight, hkUnit: .gramUnit(with: .kilo), dbUnit: "kilogram", displayName: "Weight", category: .body),
        .init(hkIdentifier: .height, dbQuantityType: QuantityTypes.height, hkUnit: .meterUnit(with: .centi), dbUnit: "centimeter", displayName: "Height", category: .body),
        .init(hkIdentifier: .bodyMassIndex, dbQuantityType: QuantityTypes.bmi, hkUnit: .count(), dbUnit: "kilograms_per_square_meter", displayName: "BMI", category: .body),
        .init(hkIdentifier: .bodyFatPercentage, dbQuantityType: QuantityTypes.bodyFatPercent, hkUnit: .percent(), dbUnit: "percent", displayName: "Body Fat %", category: .body),
        .init(hkIdentifier: .leanBodyMass, dbQuantityType: QuantityTypes.leanBodyMass, hkUnit: .gramUnit(with: .kilo), dbUnit: "kilogram", displayName: "Lean Body Mass", category: .body),
        .init(hkIdentifier: .waistCircumference, dbQuantityType: QuantityTypes.waistCircumference, hkUnit: .meterUnit(with: .centi), dbUnit: "centimeter", displayName: "Waist Circumference", category: .body),

        // Activity
        .init(hkIdentifier: .stepCount, dbQuantityType: QuantityTypes.steps, hkUnit: .count(), dbUnit: "count", displayName: "Steps", category: .activity),
        .init(hkIdentifier: .activeEnergyBurned, dbQuantityType: QuantityTypes.activeCalories, hkUnit: .kilocalorie(), dbUnit: "kilocalorie", displayName: "Active Calories", category: .activity),
        .init(hkIdentifier: .basalEnergyBurned, dbQuantityType: QuantityTypes.basalCalories, hkUnit: .kilocalorie(), dbUnit: "kilocalorie", displayName: "Basal Calories", category: .activity),
        .init(hkIdentifier: .appleExerciseTime, dbQuantityType: QuantityTypes.exerciseTime, hkUnit: .minute(), dbUnit: "minute", displayName: "Exercise Time", category: .activity),
        .init(hkIdentifier: .appleStandTime, dbQuantityType: QuantityTypes.standTime, hkUnit: .minute(), dbUnit: "minute", displayName: "Stand Time", category: .activity),
        .init(hkIdentifier: .distanceWalkingRunning, dbQuantityType: QuantityTypes.distanceWalkingRunning, hkUnit: .meter(), dbUnit: "meter", displayName: "Walking/Running Distance", category: .activity),
        .init(hkIdentifier: .distanceCycling, dbQuantityType: QuantityTypes.distanceCycling, hkUnit: .meter(), dbUnit: "meter", displayName: "Cycling Distance", category: .activity),
        .init(hkIdentifier: .flightsClimbed, dbQuantityType: QuantityTypes.flightsClimbed, hkUnit: .count(), dbUnit: "count", displayName: "Flights Climbed", category: .activity),

        // Nutrition
        .init(hkIdentifier: .dietaryProtein, dbQuantityType: QuantityTypes.proteinGrams, hkUnit: .gram(), dbUnit: "gram", displayName: "Protein", category: .nutrition),
        .init(hkIdentifier: .dietaryWater, dbQuantityType: QuantityTypes.waterMl, hkUnit: .literUnit(with: .milli), dbUnit: "milliliter", displayName: "Water", category: .nutrition),
        .init(hkIdentifier: .dietaryCarbohydrates, dbQuantityType: QuantityTypes.carbGrams, hkUnit: .gram(), dbUnit: "gram", displayName: "Carbohydrates", category: .nutrition),
        .init(hkIdentifier: .dietaryFiber, dbQuantityType: QuantityTypes.fiberGrams, hkUnit: .gram(), dbUnit: "gram", displayName: "Fiber", category: .nutrition),
        .init(hkIdentifier: .dietarySugar, dbQuantityType: QuantityTypes.sugarGrams, hkUnit: .gram(), dbUnit: "gram", displayName: "Sugar", category: .nutrition),
        .init(hkIdentifier: .dietaryFatTotal, dbQuantityType: QuantityTypes.fatGrams, hkUnit: .gram(), dbUnit: "gram", displayName: "Total Fat", category: .nutrition),
        .init(hkIdentifier: .dietaryFatSaturated, dbQuantityType: QuantityTypes.saturatedFatGrams, hkUnit: .gram(), dbUnit: "gram", displayName: "Saturated Fat", category: .nutrition),
        .init(hkIdentifier: .dietaryCholesterol, dbQuantityType: QuantityTypes.cholesterolMg, hkUnit: .gramUnit(with: .milli), dbUnit: "milligram", displayName: "Cholesterol", category: .nutrition),
        .init(hkIdentifier: .dietarySodium, dbQuantityType: QuantityTypes.sodiumMg, hkUnit: .gramUnit(with: .milli), dbUnit: "milligram", displayName: "Sodium", category: .nutrition),
        .init(hkIdentifier: .dietaryEnergyConsumed, dbQuantityType: QuantityTypes.calorieIntake, hkUnit: .kilocalorie(), dbUnit: "kilocalorie", displayName: "Calories Consumed", category: .nutrition),
        .init(hkIdentifier: .dietaryCaffeine, dbQuantityType: QuantityTypes.caffeineMg, hkUnit: .gramUnit(with: .milli), dbUnit: "milligram", displayName: "Caffeine", category: .nutrition),
    ]

    // MARK: - Workout Mappings

    /// Maps HKWorkoutActivityType to WellPath quantity types
    /// Data goes to patient_quantity_samples with quantity_type + metadata
    static let workoutMappings: [WorkoutCategoryMapping] = [
        // Cardio - common types
        .init(activityType: .running, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Running", workoutSubtype: "running"),
        .init(activityType: .cycling, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Cycling", workoutSubtype: "cycling"),
        .init(activityType: .walking, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Walking", workoutSubtype: "walking"),
        .init(activityType: .swimming, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Swimming", workoutSubtype: "swimming"),
        .init(activityType: .rowing, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Rowing", workoutSubtype: "rowing"),
        .init(activityType: .elliptical, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Elliptical", workoutSubtype: "elliptical"),
        .init(activityType: .stairClimbing, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Stair Climbing", workoutSubtype: "stair_climbing"),
        .init(activityType: .hiking, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Hiking", workoutSubtype: "hiking"),
        .init(activityType: .jumpRope, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Jump Rope", workoutSubtype: "jump_rope"),
        .init(activityType: .mixedCardio, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Mixed Cardio", workoutSubtype: "mixed_cardio"),

        // Cardio - team sports
        .init(activityType: .soccer, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Soccer", workoutSubtype: "soccer"),
        .init(activityType: .basketball, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Basketball", workoutSubtype: "basketball"),
        .init(activityType: .tennis, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Tennis", workoutSubtype: "tennis"),
        .init(activityType: .dance, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Dance", workoutSubtype: "dancing"),
        .init(activityType: .baseball, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Baseball", workoutSubtype: "baseball"),
        .init(activityType: .volleyball, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Volleyball", workoutSubtype: "volleyball"),
        .init(activityType: .hockey, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Hockey", workoutSubtype: "hockey"),
        .init(activityType: .golf, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Golf", workoutSubtype: "golf"),
        .init(activityType: .badminton, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Badminton", workoutSubtype: "badminton"),
        .init(activityType: .tableTennis, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Table Tennis", workoutSubtype: "table_tennis"),
        .init(activityType: .racquetball, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Racquetball", workoutSubtype: "racquetball"),
        .init(activityType: .squash, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Squash", workoutSubtype: "squash"),

        // Cardio - snow/water/outdoor
        .init(activityType: .crossCountrySkiing, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Cross Country Skiing", workoutSubtype: "cross_country_skiing"),
        .init(activityType: .downhillSkiing, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Downhill Skiing", workoutSubtype: "downhill_skiing"),
        .init(activityType: .snowboarding, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Snowboarding", workoutSubtype: "snowboarding"),
        .init(activityType: .surfingSports, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Surfing", workoutSubtype: "surfing"),
        .init(activityType: .paddleSports, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Paddle Sports", workoutSubtype: "paddle_sports"),
        .init(activityType: .skatingSports, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Skating", workoutSubtype: "skating"),
        .init(activityType: .climbing, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Climbing", workoutSubtype: "climbing"),

        // Cardio - martial arts (except tai chi)
        .init(activityType: .boxing, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Boxing", workoutSubtype: "boxing_cardio"),
        .init(activityType: .kickboxing, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Kickboxing", workoutSubtype: "kickboxing_cardio"),
        .init(activityType: .martialArts, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Martial Arts", workoutSubtype: "martial_arts_cardio"),
        .init(activityType: .wrestling, wellpathCategory: "cardio", quantityType: "cardio", displayName: "Wrestling", workoutSubtype: "wrestling"),

        // Strength
        .init(activityType: .traditionalStrengthTraining, wellpathCategory: "strength", quantityType: "strength_training", displayName: "Strength Training", workoutSubtype: "traditional"),
        .init(activityType: .functionalStrengthTraining, wellpathCategory: "strength", quantityType: "strength_training", displayName: "Functional Strength", workoutSubtype: "functional"),
        .init(activityType: .coreTraining, wellpathCategory: "strength", quantityType: "strength_training", displayName: "Core Training", workoutSubtype: "core_training"),
        .init(activityType: .crossTraining, wellpathCategory: "strength", quantityType: "strength_training", displayName: "Cross Training", workoutSubtype: "cross_training"),
        .init(activityType: .barre, wellpathCategory: "strength", quantityType: "strength_training", displayName: "Barre", workoutSubtype: "barre"),

        // HIIT
        .init(activityType: .highIntensityIntervalTraining, wellpathCategory: "hiit", quantityType: "hiit", displayName: "HIIT", workoutSubtype: nil),

        // Mobility (yoga, pilates, flexibility, recovery)
        .init(activityType: .yoga, wellpathCategory: "mobility", quantityType: "mobility", displayName: "Yoga", workoutSubtype: "yoga"),
        .init(activityType: .pilates, wellpathCategory: "mobility", quantityType: "mobility", displayName: "Pilates", workoutSubtype: "pilates"),
        .init(activityType: .mindAndBody, wellpathCategory: "mobility", quantityType: "mobility", displayName: "Mind and Body", workoutSubtype: nil),
        .init(activityType: .taiChi, wellpathCategory: "mobility", quantityType: "mobility", displayName: "Tai Chi", workoutSubtype: "tai_chi"),
        .init(activityType: .flexibility, wellpathCategory: "mobility", quantityType: "mobility", displayName: "Flexibility", workoutSubtype: "static_stretching"),
        .init(activityType: .cooldown, wellpathCategory: "mobility", quantityType: "mobility", displayName: "Cooldown", workoutSubtype: nil),
        .init(activityType: .preparationAndRecovery, wellpathCategory: "mobility", quantityType: "mobility", displayName: "Recovery", workoutSubtype: "foam_rolling"),
    ]

    // MARK: - Lookup Methods

    /// Get workout category mapping for a given activity type
    static func getWorkoutMapping(for activityType: HKWorkoutActivityType) -> WorkoutCategoryMapping? {
        workoutMappings.first { $0.activityType == activityType }
    }

    /// Get default category for unknown workout types
    static func getDefaultWorkoutMapping() -> (category: String, quantityType: String, workoutSubtype: String?) {
        return ("cardio", "cardio", nil)  // Default unknown workouts to cardio
    }

    /// Get all HKSampleTypes to request authorization for
    static func getAllSampleTypes() -> Set<HKSampleType> {
        var types = Set<HKSampleType>()

        // Add quantity types
        for config in quantityConfigs {
            if let type = config.hkQuantityType {
                types.insert(type)
            }
        }

        // Add category types
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }
        if let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
            types.insert(mindfulType)
        }

        // Add correlation types
        if let bpType = HKObjectType.correlationType(forIdentifier: .bloodPressure) {
            types.insert(bpType)
        }

        // Add workout type
        types.insert(HKObjectType.workoutType())

        return types
    }

    /// Get quantity configs by category
    static func getQuantityConfigs(for category: HealthKitQuantityConfig.SyncCategory) -> [HealthKitQuantityConfig] {
        quantityConfigs.filter { $0.category == category }
    }

    // MARK: - Sync Order Helpers

    /// High-volume quantity types that should sync LAST (heart rate has 100k+ samples typically)
    static let highVolumeTypes: Set<HKQuantityTypeIdentifier> = [
        .heartRate
    ]

    /// Get quantity configs excluding high-volume types (sync these first)
    static var quantityConfigsExcludingHighVolume: [HealthKitQuantityConfig] {
        quantityConfigs.filter { !highVolumeTypes.contains($0.hkIdentifier) }
    }

    /// Get only high-volume quantity configs (sync these last)
    static var highVolumeQuantityConfigs: [HealthKitQuantityConfig] {
        quantityConfigs.filter { highVolumeTypes.contains($0.hkIdentifier) }
    }
}
