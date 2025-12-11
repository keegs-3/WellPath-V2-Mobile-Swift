//
//  PatientSampleModels.swift
//  WellPath
//
//  Unified patient_samples model matching Apple HealthKit patterns
//  Created 2024-11-25
//

import Foundation
import Supabase

// MARK: - Sample Types

enum PatientSampleType: String, Codable {
    case quantity = "quantity"
    case category = "category"
    case correlation = "correlation"
}

enum PatientSampleSource: String, Codable {
    case healthkit = "healthkit"
    case wellpathInput = "wellpath_input"
    case manual = "manual"
    case integration = "integration"
    case device = "device"
    case clinician = "clinician"  // Clinician-entered values from web portal
}

// MARK: - Patient Sample Model (READ-ONLY from VIEW)

/// READ-ONLY model for the patient_samples VIEW
/// The VIEW unions all sample tables for backwards-compatible reads.
/// For WRITES, use the specific table models: QuantitySampleWrite, CategorySampleWrite, etc.
struct PatientSample: Codable {
    // Primary identifiers
    let id: UUID?
    let patientId: UUID

    // Core HealthKit pattern
    let sampleType: PatientSampleType
    let startTime: Date
    let endTime: Date

    // For quantity samples (protein, steps, weight, workout duration, etc.)
    let quantityValue: Double?
    let quantityUnit: String?
    let quantityType: String?

    // For category samples (sleep stages, menstrual flow, etc.)
    let categoryValue: String?  // TEXT: awake, rem, core, deep for sleep
    let categoryType: String?

    // For correlations (blood pressure, meals with multiple components)
    let correlationType: String?
    let parentCorrelationId: UUID?

    // Metadata (stores all non-standard attributes as JSONB)
    let metadata: [String: AnyJSON]?

    // Source tracking
    let source: PatientSampleSource
    let deviceInfo: [String: AnyJSON]?
    let userTimezone: String

    // Event grouping
    let eventInstanceId: UUID?

    // Sleep session grouping (assigned by database trigger)
    let sleepSessionId: UUID?

    // Timestamps (let database set these)
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case sampleType = "sample_type"
        case startTime = "start_time"
        case endTime = "end_time"
        case quantityValue = "quantity_value"
        case quantityUnit = "quantity_unit"
        case quantityType = "quantity_type"
        case categoryValue = "category_value"
        case categoryType = "category_type"
        case correlationType = "correlation_type"
        case parentCorrelationId = "parent_correlation_id"
        case metadata
        case source
        case deviceInfo = "device_info"
        case userTimezone = "user_timezone"
        case eventInstanceId = "event_instance_id"
        case sleepSessionId = "sleep_session_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Custom encoding to omit nil values
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Skip id, createdAt, updatedAt - let database handle these
        try container.encode(patientId, forKey: .patientId)
        try container.encode(sampleType.rawValue, forKey: .sampleType)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)

        // Quantity fields (only for quantity samples)
        try container.encodeIfPresent(quantityValue, forKey: .quantityValue)
        try container.encodeIfPresent(quantityUnit, forKey: .quantityUnit)
        try container.encodeIfPresent(quantityType, forKey: .quantityType)

        // Category fields (only for category samples)
        try container.encodeIfPresent(categoryValue, forKey: .categoryValue)
        try container.encodeIfPresent(categoryType, forKey: .categoryType)

        // Correlation fields
        try container.encodeIfPresent(correlationType, forKey: .correlationType)
        try container.encodeIfPresent(parentCorrelationId, forKey: .parentCorrelationId)

        // Metadata
        try container.encodeIfPresent(metadata, forKey: .metadata)

        // Source
        try container.encode(source.rawValue, forKey: .source)
        try container.encodeIfPresent(deviceInfo, forKey: .deviceInfo)
        try container.encode(userTimezone, forKey: .userTimezone)

        // Event grouping
        try container.encodeIfPresent(eventInstanceId, forKey: .eventInstanceId)

        // Sleep session (usually nil on insert, set by trigger)
        try container.encodeIfPresent(sleepSessionId, forKey: .sleepSessionId)
    }
}

// MARK: - Factory Methods

extension PatientSample {

    /// Create a quantity sample (protein, steps, water, weight, workout duration, etc.)
    /// - Parameters:
    ///   - patientId: User's UUID
    ///   - quantityType: Type identifier (e.g., "protein_grams", "steps", "strength_duration")
    ///   - value: Numeric value
    ///   - unit: Unit string (e.g., "gram", "count", "minute")
    ///   - timestamp: When the sample occurred (start_time = end_time for instant samples)
    ///   - endTime: Optional end time for duration samples (e.g., workouts)
    ///   - metadata: Optional JSONB metadata (protein_type, meal_timing, workout_type, etc.)
    ///   - source: Data source (healthkit, wellpath_input, etc.)
    ///   - timezone: User's timezone identifier
    ///   - eventInstanceId: Optional UUID to group related samples
    ///   - healthKitUUID: Optional HealthKit sample UUID for deduplication
    static func quantity(
        patientId: UUID,
        quantityType: String,
        value: Double,
        unit: String,
        timestamp: Date,
        endTime: Date? = nil,
        metadata: [String: AnyJSON]? = nil,
        source: PatientSampleSource,
        timezone: String,
        eventInstanceId: UUID? = nil,
        healthKitUUID: String? = nil,
        healthKitSourceName: String? = nil
    ) -> PatientSample {
        var finalMetadata = metadata ?? [:]

        // Add HealthKit tracking info to metadata
        if let hkUUID = healthKitUUID {
            finalMetadata["healthkit_uuid"] = .string(hkUUID)
        }
        if let hkSource = healthKitSourceName {
            finalMetadata["healthkit_source_name"] = .string(hkSource)
        }

        return PatientSample(
            id: nil,
            patientId: patientId,
            sampleType: .quantity,
            startTime: timestamp,
            endTime: endTime ?? timestamp, // Same as start for instant samples
            quantityValue: value,
            quantityUnit: unit,
            quantityType: quantityType,
            categoryValue: nil,
            categoryType: nil,
            correlationType: nil,
            parentCorrelationId: nil,
            metadata: finalMetadata.isEmpty ? nil : finalMetadata,
            source: source,
            deviceInfo: nil,
            userTimezone: timezone,
            eventInstanceId: eventInstanceId,
            sleepSessionId: nil,
            createdAt: nil,
            updatedAt: nil
        )
    }

    /// Create a category sample (sleep stages, menstrual flow, etc.)
    /// - Parameters:
    ///   - patientId: User's UUID
    ///   - categoryType: Type identifier (e.g., "sleep_period_types", "menstrual_flow")
    ///   - value: String category value (e.g., "awake", "rem", "core", "deep" for sleep)
    ///   - startTime: Period start time
    ///   - endTime: Period end time
    ///   - metadata: Optional JSONB metadata
    ///   - source: Data source
    ///   - timezone: User's timezone identifier
    ///   - eventInstanceId: Optional UUID to group related samples
    static func category(
        patientId: UUID,
        categoryType: String,
        value: String,
        startTime: Date,
        endTime: Date,
        metadata: [String: AnyJSON]? = nil,
        source: PatientSampleSource,
        timezone: String,
        eventInstanceId: UUID? = nil,
        healthKitUUID: String? = nil,
        healthKitSourceName: String? = nil
    ) -> PatientSample {
        var finalMetadata = metadata ?? [:]

        // Store category_value in metadata for aggregation filtering
        finalMetadata["category_value"] = .string(value)

        // Add HealthKit tracking info
        if let hkUUID = healthKitUUID {
            finalMetadata["healthkit_uuid"] = .string(hkUUID)
        }
        if let hkSource = healthKitSourceName {
            finalMetadata["healthkit_source_name"] = .string(hkSource)
        }

        return PatientSample(
            id: nil,
            patientId: patientId,
            sampleType: .category,
            startTime: startTime,
            endTime: endTime,
            quantityValue: nil,
            quantityUnit: nil,
            quantityType: nil,
            categoryValue: value,
            categoryType: categoryType,
            correlationType: nil,
            parentCorrelationId: nil,
            metadata: finalMetadata.isEmpty ? nil : finalMetadata,
            source: source,
            deviceInfo: nil,
            userTimezone: timezone,
            eventInstanceId: eventInstanceId,
            sleepSessionId: nil,
            createdAt: nil,
            updatedAt: nil
        )
    }
}

// MARK: - Quantity Type Constants

/// Standard quantity types matching sample_quantity_types table
struct QuantityTypes {
    // Nutrition
    static let proteinGrams = "protein_grams"
    static let vegetablesServings = "vegetables_servings"
    static let legumesServings = "legumes_servings"
    static let wholeGrainsServings = "whole_grains_servings"
    static let fruitsServings = "fruits_servings"
    static let hydrationOunces = "hydration_ounces"

    // Movement
    static let steps = "steps"
    static let strengthDuration = "strength_duration"
    static let cardioDuration = "cardio_duration"
    static let yogaDuration = "yoga_duration"

    // Physical / Biometrics
    static let weight = "bodyweight"
    static let height = "height"
    static let heartRate = "heart_rate"
    static let waistCircumference = "waist_circumference"
    static let hipCircumference = "hip_circumference"
    static let bloodPressureSystolic = "blood_pressure_systolic"
    static let bloodPressureDiastolic = "blood_pressure_diastolic"
    static let restingHeartRate = "resting_heart_rate"
    static let hrv = "hrv"
    static let vo2Max = "vo2_max"
    static let bodyFatPercent = "body_fat_percent"
    static let gripStrength = "grip_strength"
    static let appendicularSkeletalMuscleMass = "appendicular_skeletal_muscle_mass"
    static let visceralFatPercent = "visceral_fat_percent"
    static let asmi = "asmi"
    static let bmi = "bmi"

    // Mental
    static let meditationDuration = "meditation_duration"
    static let swlsScore = "swls_score"  // Satisfaction With Life Scale
    static let gad2Score = "gad2_score"  // GAD-2 Anxiety
    static let phq2Score = "phq2_score"  // PHQ-2 Depression

    // Substances
    static let alcoholDrinks = "alcohol_drinks"
    static let tobaccoUses = "tobacco_uses"
    static let nicotineUses = "nicotine_uses"

    // Cannabis (separate quantity types per consumption method)
    static let cannabisFlower = "cannabis_flower"
    static let cannabisVape = "cannabis_vape"
    static let cannabisEdibles = "cannabis_edibles"
    static let cannabisConcentrates = "cannabis_concentrates"
    static let cannabisTinctures = "cannabis_tinctures"
}

/// Standard category types matching sample_category_types table
struct CategoryTypes {
    static let sleepPeriodTypes = "sleep_period_types"
    static let menstrualFlow = "menstrual_flow"
}

/// Sleep period type keys (matching HealthKit and sample_category_types_reference)
struct SleepPeriodTypeKeys {
    static let awake = "awake"
    static let rem = "rem"
    static let core = "core"
    static let deep = "deep"
    static let asleep = "asleep"  // Unspecified sleep
    static let inBed = "in_bed"
}

// MARK: - Metadata Key Constants

/// Standard metadata keys for food/nutrition samples (timing applies to all nutrients)
struct FoodMetadataKeys {
    static let foodTiming = "food_timing"  // Standardized timing key for all food types
}

/// Standard metadata keys for protein samples
struct ProteinMetadataKeys {
    static let proteinType = "protein_type"
}

/// Standard metadata keys for workout samples
struct WorkoutMetadataKeys {
    static let workoutType = "workout_type"
    static let muscleGroups = "muscle_groups"
    static let intensity = "intensity"
    static let caloriesBurned = "calories_burned"
}

/// Standard metadata keys for HealthKit tracking
struct HealthKitMetadataKeys {
    static let healthkitUuid = "healthkit_uuid"
    static let healthkitSourceName = "healthkit_source_name"
    static let healthkitBundleId = "healthkit_bundle_id"
}

/// Standard metadata keys for alcohol samples
struct AlcoholMetadataKeys {
    static let alcoholType = "alcohol_type"
}

/// Standard metadata keys for tobacco samples
struct TobaccoMetadataKeys {
    static let tobaccoType = "tobacco_type"
}

/// Standard metadata keys for nicotine samples
struct NicotineMetadataKeys {
    static let nicotineType = "nicotine_type"
}

/// Cannabis type keys (reference_key values from cannabis_types)
struct CannabisTypeKeys {
    static let flower = "flower"
    static let vape = "vape"
    static let edibles = "edibles"
    static let concentrates = "concentrates"
    static let tinctures = "tinctures"
}

// MARK: - ============================================================
// MARK: - WRITE MODELS (for specific tables)
// MARK: - ============================================================
// These models are for INSERTING data into the specific sample tables.
// The database VIEW (patient_samples) is READ-ONLY.

// MARK: - Quantity Sample Write Model

/// Write model for patient_quantity_samples table
/// Use for: steps, weight, heart_rate, protein, water, workout durations, etc.
struct QuantitySampleWrite: Codable {
    let patientId: UUID
    let quantityType: String
    let quantityValue: Double
    let quantityUnit: String
    let startTime: Date
    let endTime: Date
    let source: PatientSampleSource
    let deviceInfo: [String: AnyJSON]?
    let metadata: [String: AnyJSON]?
    let userTimezone: String
    let eventInstanceId: UUID?
    let aggregationDate: Date?

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case quantityType = "quantity_type"
        case quantityValue = "quantity_value"
        case quantityUnit = "quantity_unit"
        case startTime = "start_time"
        case endTime = "end_time"
        case source
        case deviceInfo = "device_info"
        case metadata
        case userTimezone = "user_timezone"
        case eventInstanceId = "event_instance_id"
        case aggregationDate = "aggregation_date"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(patientId, forKey: .patientId)
        try container.encode(quantityType, forKey: .quantityType)
        try container.encode(quantityValue, forKey: .quantityValue)
        try container.encode(quantityUnit, forKey: .quantityUnit)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(source.rawValue, forKey: .source)
        try container.encodeIfPresent(deviceInfo, forKey: .deviceInfo)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encode(userTimezone, forKey: .userTimezone)
        try container.encodeIfPresent(eventInstanceId, forKey: .eventInstanceId)
        try container.encodeIfPresent(aggregationDate, forKey: .aggregationDate)
    }

    /// Factory method for creating quantity samples
    static func create(
        patientId: UUID,
        quantityType: String,
        value: Double,
        unit: String,
        timestamp: Date,
        endTime: Date? = nil,
        source: PatientSampleSource,
        timezone: String,
        metadata: [String: AnyJSON]? = nil,
        eventInstanceId: UUID? = nil,
        healthKitUUID: String? = nil,
        healthKitSourceName: String? = nil,
        healthKitBundleId: String? = nil
    ) -> QuantitySampleWrite {
        var finalMetadata = metadata ?? [:]
        if let hkUUID = healthKitUUID {
            finalMetadata["healthkit_uuid"] = .string(hkUUID)
        }
        if let hkSource = healthKitSourceName {
            finalMetadata["healthkit_source_name"] = .string(hkSource)
        }
        if let hkBundle = healthKitBundleId {
            finalMetadata["healthkit_bundle_id"] = .string(hkBundle)
        }

        return QuantitySampleWrite(
            patientId: patientId,
            quantityType: quantityType,
            quantityValue: value,
            quantityUnit: unit,
            startTime: timestamp,
            endTime: endTime ?? timestamp,
            source: source,
            deviceInfo: nil,
            metadata: finalMetadata.isEmpty ? nil : finalMetadata,
            userTimezone: timezone,
            eventInstanceId: eventInstanceId,
            aggregationDate: nil // Set by database trigger
        )
    }
}

// MARK: - Category Sample Write Model

/// Write model for patient_category_samples table
/// Use for: sleep_period_types, menstrual_flow, etc.
struct CategorySampleWrite: Codable {
    let patientId: UUID
    let categoryType: String
    let categoryValue: String  // String key matching sample_category_types_reference (e.g., "awake", "rem", "core", "deep")
    let startTime: Date
    let endTime: Date
    let source: PatientSampleSource
    let deviceInfo: [String: AnyJSON]?
    let metadata: [String: AnyJSON]?
    let userTimezone: String
    let eventInstanceId: UUID?
    let sleepSessionId: UUID?
    let aggregationDate: Date?

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case categoryType = "category_type"
        case categoryValue = "category_value"
        case startTime = "start_time"
        case endTime = "end_time"
        case source
        case deviceInfo = "device_info"
        case metadata
        case userTimezone = "user_timezone"
        case eventInstanceId = "event_instance_id"
        case sleepSessionId = "sleep_session_id"
        case aggregationDate = "aggregation_date"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(patientId, forKey: .patientId)
        try container.encode(categoryType, forKey: .categoryType)
        try container.encode(categoryValue, forKey: .categoryValue)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(source.rawValue, forKey: .source)
        try container.encodeIfPresent(deviceInfo, forKey: .deviceInfo)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encode(userTimezone, forKey: .userTimezone)
        try container.encodeIfPresent(eventInstanceId, forKey: .eventInstanceId)
        try container.encodeIfPresent(sleepSessionId, forKey: .sleepSessionId)
        try container.encodeIfPresent(aggregationDate, forKey: .aggregationDate)
    }

    /// Factory method for creating category samples (e.g., sleep period types)
    static func create(
        patientId: UUID,
        categoryType: String,
        value: String,  // String key (e.g., "awake", "rem", "core", "deep")
        startTime: Date,
        endTime: Date,
        source: PatientSampleSource,
        timezone: String,
        metadata: [String: AnyJSON]? = nil,
        eventInstanceId: UUID? = nil,
        healthKitUUID: String? = nil,
        healthKitSourceName: String? = nil,
        healthKitBundleId: String? = nil
    ) -> CategorySampleWrite {
        var finalMetadata = metadata ?? [:]
        if let hkUUID = healthKitUUID {
            finalMetadata["healthkit_uuid"] = .string(hkUUID)
        }
        if let hkSource = healthKitSourceName {
            finalMetadata["healthkit_source_name"] = .string(hkSource)
        }
        if let hkBundle = healthKitBundleId {
            finalMetadata["healthkit_bundle_id"] = .string(hkBundle)
        }

        return CategorySampleWrite(
            patientId: patientId,
            categoryType: categoryType,
            categoryValue: value,
            startTime: startTime,
            endTime: endTime,
            source: source,
            deviceInfo: nil,
            metadata: finalMetadata.isEmpty ? nil : finalMetadata,
            userTimezone: timezone,
            eventInstanceId: eventInstanceId,
            sleepSessionId: nil, // Assigned by database trigger
            aggregationDate: nil // Set by database trigger
        )
    }
}

// MARK: - Clinical Sample Write Model

/// Write model for patient_clinical_samples table
/// Use for: biomarkers/lab results (hdl, hba1c, vitamin_d, etc.)
/// Note: clinical_type uses clean names WITHOUT 'biomarker_' prefix
struct ClinicalSampleWrite: Codable {
    let patientId: UUID
    let clinicalType: String  // e.g., "hdl" not "biomarker_hdl"
    let value: Double
    let unit: String
    let sampleTime: Date
    let source: PatientSampleSource
    let deviceInfo: [String: AnyJSON]?
    let metadata: [String: AnyJSON]?
    let labName: String?
    let labReferenceRangeLow: Double?
    let labReferenceRangeHigh: Double?
    let collectionMethod: String?  // 'fasting', 'random', 'post-prandial'
    let cycleStage: String?  // 'Follicular', 'Ovulatory', 'Luteal' for hormone biomarkers

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case clinicalType = "clinical_type"
        case value
        case unit
        case sampleTime = "sample_time"
        case source
        case deviceInfo = "device_info"
        case metadata
        case labName = "lab_name"
        case labReferenceRangeLow = "lab_reference_range_low"
        case labReferenceRangeHigh = "lab_reference_range_high"
        case collectionMethod = "collection_method"
        case cycleStage = "cycle_stage"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(patientId, forKey: .patientId)
        try container.encode(clinicalType, forKey: .clinicalType)
        try container.encode(value, forKey: .value)
        try container.encode(unit, forKey: .unit)
        try container.encode(sampleTime, forKey: .sampleTime)
        try container.encode(source.rawValue, forKey: .source)
        try container.encodeIfPresent(deviceInfo, forKey: .deviceInfo)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encodeIfPresent(labName, forKey: .labName)
        try container.encodeIfPresent(labReferenceRangeLow, forKey: .labReferenceRangeLow)
        try container.encodeIfPresent(labReferenceRangeHigh, forKey: .labReferenceRangeHigh)
        try container.encodeIfPresent(collectionMethod, forKey: .collectionMethod)
        try container.encodeIfPresent(cycleStage, forKey: .cycleStage)
    }

    /// Factory method for creating clinical/biomarker samples
    static func create(
        patientId: UUID,
        clinicalType: String,
        value: Double,
        unit: String,
        sampleTime: Date,
        source: PatientSampleSource = .manual,
        labName: String? = nil,
        labRangeLow: Double? = nil,
        labRangeHigh: Double? = nil,
        collectionMethod: String? = nil,
        cycleStage: String? = nil
    ) -> ClinicalSampleWrite {
        return ClinicalSampleWrite(
            patientId: patientId,
            clinicalType: clinicalType,
            value: value,
            unit: unit,
            sampleTime: sampleTime,
            source: source,
            deviceInfo: nil,
            metadata: nil,
            labName: labName,
            labReferenceRangeLow: labRangeLow,
            labReferenceRangeHigh: labRangeHigh,
            collectionMethod: collectionMethod,
            cycleStage: cycleStage
        )
    }
}

// MARK: - Correlation Sample Write Model

/// Write model for patient_correlation_samples table
/// Use for: blood pressure, body composition, or other paired measurements
struct CorrelationSampleWrite: Codable {
    let patientId: UUID
    let correlationType: String  // e.g., "blood_pressure", "body_composition"
    let components: [String: AnyJSON]  // e.g., {"systolic": 120, "diastolic": 80}
    let sampleTime: Date
    let source: PatientSampleSource
    let deviceInfo: [String: AnyJSON]?
    let metadata: [String: AnyJSON]?
    let userTimezone: String

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case correlationType = "correlation_type"
        case components
        case sampleTime = "sample_time"
        case source
        case deviceInfo = "device_info"
        case metadata
        case userTimezone = "user_timezone"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(patientId, forKey: .patientId)
        try container.encode(correlationType, forKey: .correlationType)
        try container.encode(components, forKey: .components)
        try container.encode(sampleTime, forKey: .sampleTime)
        try container.encode(source.rawValue, forKey: .source)
        try container.encodeIfPresent(deviceInfo, forKey: .deviceInfo)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encode(userTimezone, forKey: .userTimezone)
    }

    /// Factory method for blood pressure samples
    static func bloodPressure(
        patientId: UUID,
        systolic: Double,
        diastolic: Double,
        pulse: Double? = nil,
        sampleTime: Date,
        source: PatientSampleSource,
        timezone: String
    ) -> CorrelationSampleWrite {
        var components: [String: AnyJSON] = [
            "systolic": .double(systolic),
            "diastolic": .double(diastolic)
        ]
        if let pulse = pulse {
            components["pulse"] = .double(pulse)
        }

        return CorrelationSampleWrite(
            patientId: patientId,
            correlationType: "blood_pressure",
            components: components,
            sampleTime: sampleTime,
            source: source,
            deviceInfo: nil,
            metadata: nil,
            userTimezone: timezone
        )
    }
}

// MARK: - Baseline Sample Write Model

/// Write model for patient_baseline_samples table
/// Use for: survey-derived baseline values (daily steps baseline, sleep hours baseline, etc.)
struct BaselineSampleWrite: Codable {
    let patientId: UUID
    let baselineType: String  // e.g., "daily_steps", "sleep_hours" (without baseline_ prefix)
    let value: Double
    let unit: String?
    let surveyId: UUID?
    let assessmentDate: Date
    let source: PatientSampleSource
    let metadata: [String: AnyJSON]?

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case baselineType = "baseline_type"
        case value
        case unit
        case surveyId = "survey_id"
        case assessmentDate = "assessment_date"
        case source
        case metadata
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(patientId, forKey: .patientId)
        try container.encode(baselineType, forKey: .baselineType)
        try container.encode(value, forKey: .value)
        try container.encodeIfPresent(unit, forKey: .unit)
        try container.encodeIfPresent(surveyId, forKey: .surveyId)
        try container.encode(assessmentDate, forKey: .assessmentDate)
        try container.encode(source.rawValue, forKey: .source)
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }

    /// Factory method for survey-derived baselines
    static func fromSurvey(
        patientId: UUID,
        baselineType: String,
        value: Double,
        unit: String? = nil,
        surveyId: UUID? = nil,
        assessmentDate: Date = Date()
    ) -> BaselineSampleWrite {
        return BaselineSampleWrite(
            patientId: patientId,
            baselineType: baselineType,
            value: value,
            unit: unit,
            surveyId: surveyId,
            assessmentDate: assessmentDate,
            source: .wellpathInput,
            metadata: nil
        )
    }
}

// MARK: - Correlation Types Constants

struct CorrelationTypes {
    static let bloodPressure = "blood_pressure"
    static let bodyComposition = "body_composition"
}

// MARK: - Clinical Types Constants

/// Clinical types matching sample_clinical_types table (WITHOUT biomarker_ prefix)
struct ClinicalTypes {
    // Lipids
    static let hdl = "hdl"
    static let ldl = "ldl"
    static let totalCholesterol = "total_cholesterol"
    static let triglycerides = "triglycerides"
    static let apob = "apob"
    static let lpA = "lp_a"

    // Metabolic
    static let fastingGlucose = "fasting_glucose"
    static let hba1c = "hba1c"
    static let fastingInsulin = "fasting_insulin"
    static let homaIr = "homa_ir"

    // Inflammation
    static let hscrp = "hscrp"
    static let homocysteine = "homocysteine"

    // Liver
    static let alt = "alt"
    static let ast = "ast"
    static let ggt = "ggt"
    static let alp = "alp"

    // Kidney
    static let creatinine = "creatinine"
    static let bun = "bun"
    static let egfr = "egfr"
    static let cystatinC = "cystatin_c"

    // Thyroid
    static let tsh = "tsh"
    static let freeT3 = "free_t3"
    static let freeT4 = "free_t4"

    // Hormones
    static let testosterone = "testosterone"
    static let estradiol = "estradiol"
    static let dheas = "dheas"
    static let cortisol = "cortisol"

    // Vitamins & Minerals
    static let vitaminD = "vitamin_d"
    static let vitaminB12 = "vitamin_b12"
    static let folateSerum = "folate_serum"
    static let iron = "iron"
    static let ferritin = "ferritin"
    static let magnesiumRbc = "magnesium_rbc"

    // Blood Cells
    static let hemoglobin = "hemoglobin"
    static let hematocrit = "hematocrit"
    static let rbcCount = "rbc_count"
    static let wbcCount = "wbc_count"
    static let plateletCount = "platelet_count"
}
