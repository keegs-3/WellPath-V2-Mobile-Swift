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
}

// MARK: - Patient Sample Model

/// Unified health data model matching the patient_samples table
/// Supports quantity samples (protein, steps), category samples (sleep), and correlations
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
    let categoryValue: Int?
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
    ///   - categoryType: Type identifier (e.g., "sleep_stage", "menstrual_flow")
    ///   - value: Integer category value (e.g., 0=Awake, 1=REM, 2=Core, 3=Deep for sleep)
    ///   - startTime: Period start time
    ///   - endTime: Period end time
    ///   - metadata: Optional JSONB metadata
    ///   - source: Data source
    ///   - timezone: User's timezone identifier
    ///   - eventInstanceId: Optional UUID to group related samples
    static func category(
        patientId: UUID,
        categoryType: String,
        value: Int,
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
        finalMetadata["category_value"] = .integer(value)

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

    // Physical
    static let weight = "weight"
    static let height = "height"
    static let heartRate = "heart_rate"

    // Mental
    static let meditationDuration = "meditation_duration"
}

/// Standard category types matching sample_category_types table
struct CategoryTypes {
    static let sleepStage = "sleep_stage"
    static let menstrualFlow = "menstrual_flow"
}

/// Sleep stage values (matching HealthKit and database)
struct SleepStageValues {
    static let awake = 0
    static let rem = 1
    static let core = 2  // Light sleep
    static let deep = 3
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
}
