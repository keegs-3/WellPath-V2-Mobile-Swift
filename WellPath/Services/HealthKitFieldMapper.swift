//
//  HealthKitFieldMapper.swift
//  WellPath
//
//  Maps HealthKit identifiers to WellPath database IDs
//  Data now goes to patient_samples table using:
//  - Quantity samples: quantity_type (e.g., "protein_grams", "steps")
//  - Category samples: category_type + category_value (e.g., "sleep_stage" with 0=Awake, 1=REM, 2=Core, 3=Deep)
//
//  Legacy mappings kept for reference lookup during migration
//

import Foundation
import HealthKit

@MainActor
class HealthKitFieldMapper: ObservableObject {
    static let shared = HealthKitFieldMapper()

    private let supabase = SupabaseManager.shared.client

    // Non-sleep mappings: healthkit_identifier -> field_id (legacy reference)
    private var fieldMappingCache: [String: String] = [:]
    private var reverseFieldMappingCache: [String: String] = [:]

    // Sleep period type mappings: healthkit_identifier -> reference UUID (legacy reference)
    private var sleepTypeMappingCache: [String: String] = [:]
    private var reverseSleepTypeMappingCache: [String: String] = [:]

    private var isCacheLoaded = false

    private init() {}

    /// Load all HealthKit mappings from backend and cache them
    func loadMappings() async throws {
        guard !isCacheLoaded else { return }

        print("📥 Loading HealthKit field mappings from backend...")

        // MARK: - Load Non-Sleep Mappings from data_entry_fields

        let fields: [DataEntryFieldMapping] = try await supabase
            .from("data_entry_fields")
            .select("field_id, healthkit_identifier")
            .not("healthkit_identifier", operator: .is, value: "null")
            .eq("supports_healthkit_sync", value: true)
            .execute()
            .value

        for field in fields {
            fieldMappingCache[field.healthkitIdentifier] = field.fieldId
            reverseFieldMappingCache[field.fieldId] = field.healthkitIdentifier
        }

        print("✅ Loaded \(fieldMappingCache.count) non-sleep HealthKit field mappings")

        // MARK: - Load Sleep Type Mappings from data_entry_fields_reference

        let sleepTypes: [SleepPeriodTypeMapping] = try await supabase
            .from("data_entry_fields_reference")
            .select("id, healthkit_identifier, reference_key, display_name")
            .eq("reference_category", value: "sleep_period_types")
            .execute()
            .value

        for sleepType in sleepTypes {
            sleepTypeMappingCache[sleepType.healthkitIdentifier] = sleepType.id
            reverseSleepTypeMappingCache[sleepType.id] = sleepType.healthkitIdentifier
        }

        print("✅ Loaded \(sleepTypeMappingCache.count) sleep period type mappings")

        isCacheLoaded = true
    }

    // MARK: - Non-Sleep Data Mappings (legacy)

    /// Get field_id for a HealthKit identifier (legacy - now use quantity_type in patient_samples)
    /// Example: "HKQuantityTypeIdentifierStepCount" -> "DEF_STEPS"
    func getFieldId(for healthKitIdentifier: String) async throws -> String {
        if !isCacheLoaded {
            try await loadMappings()
        }

        guard let fieldId = fieldMappingCache[healthKitIdentifier] else {
            throw HealthKitFieldMapperError.noMappingFound(healthKitIdentifier)
        }

        return fieldId
    }

    /// Get field_id for a HealthKit quantity type
    func getFieldId(for quantityType: HKQuantityTypeIdentifier) async throws -> String {
        return try await getFieldId(for: quantityType.rawValue)
    }

    /// Get field_id for a HealthKit category type (non-sleep only)
    func getFieldId(for categoryType: HKCategoryTypeIdentifier) async throws -> String {
        return try await getFieldId(for: categoryType.rawValue)
    }

    /// Get HealthKit identifier for a field_id (reverse lookup)
    func getHealthKitIdentifier(for fieldId: String) async throws -> String {
        if !isCacheLoaded {
            try await loadMappings()
        }

        guard let identifier = reverseFieldMappingCache[fieldId] else {
            throw HealthKitFieldMapperError.noMappingFound(fieldId)
        }

        return identifier
    }

    // MARK: - Sleep Data Mappings (legacy)

    /// Get period_type_id (UUID) for a sleep HealthKit identifier (legacy - now use category_value in patient_samples)
    /// Example: "HKCategoryValueSleepAnalysisAsleepCore" -> "3ddf524a-d6e8-49a8-ae79-27477f30dde2"
    func getSleepPeriodTypeId(for healthKitSleepValue: Int) async throws -> String {
        if !isCacheLoaded {
            try await loadMappings()
        }

        // Map HKCategoryValueSleepAnalysis values to HealthKit identifiers
        let healthKitIdentifier: String
        switch healthKitSleepValue {
        case 0: healthKitIdentifier = "HKCategoryValueSleepAnalysisInBed"
        case 1: healthKitIdentifier = "HKCategoryValueSleepAnalysisAsleepUnspecified"
        case 2: healthKitIdentifier = "HKCategoryValueSleepAnalysisAwake"
        case 3: healthKitIdentifier = "HKCategoryValueSleepAnalysisAsleepCore"
        case 4: healthKitIdentifier = "HKCategoryValueSleepAnalysisAsleepDeep"
        case 5: healthKitIdentifier = "HKCategoryValueSleepAnalysisAsleepREM"
        default:
            throw HealthKitFieldMapperError.unknownSleepValue(healthKitSleepValue)
        }

        guard let periodTypeId = sleepTypeMappingCache[healthKitIdentifier] else {
            throw HealthKitFieldMapperError.noMappingFound(healthKitIdentifier)
        }

        return periodTypeId
    }

    /// Get period_type_id by HealthKit identifier string
    func getSleepPeriodTypeId(for healthKitIdentifier: String) async throws -> String {
        if !isCacheLoaded {
            try await loadMappings()
        }

        guard let periodTypeId = sleepTypeMappingCache[healthKitIdentifier] else {
            throw HealthKitFieldMapperError.noMappingFound(healthKitIdentifier)
        }

        return periodTypeId
    }

    /// Get HealthKit identifier for a sleep period_type_id (reverse lookup)
    func getHealthKitIdentifier(forSleepPeriodTypeId periodTypeId: String) async throws -> String {
        if !isCacheLoaded {
            try await loadMappings()
        }

        guard let identifier = reverseSleepTypeMappingCache[periodTypeId] else {
            throw HealthKitFieldMapperError.noMappingFound(periodTypeId)
        }

        return identifier
    }

    // MARK: - Utility

    /// Check if a HealthKit identifier is for sleep data
    func isSleepData(_ healthKitIdentifier: String) -> Bool {
        return healthKitIdentifier.contains("SleepAnalysis")
    }

    /// Clear cache (useful for debugging or if mappings change)
    func clearCache() {
        fieldMappingCache.removeAll()
        reverseFieldMappingCache.removeAll()
        sleepTypeMappingCache.removeAll()
        reverseSleepTypeMappingCache.removeAll()
        isCacheLoaded = false
    }
}

// MARK: - Models

struct DataEntryFieldMapping: Codable {
    let fieldId: String
    let healthkitIdentifier: String

    enum CodingKeys: String, CodingKey {
        case fieldId = "field_id"
        case healthkitIdentifier = "healthkit_identifier"
    }
}

struct SleepPeriodTypeMapping: Codable {
    let id: String // UUID
    let healthkitIdentifier: String
    let referenceKey: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case id
        case healthkitIdentifier = "healthkit_identifier"
        case referenceKey = "reference_key"
        case displayName = "display_name"
    }
}

// MARK: - Errors

enum HealthKitFieldMapperError: Error, LocalizedError {
    case noMappingFound(String)
    case cacheNotLoaded
    case unknownSleepValue(Int)

    var errorDescription: String? {
        switch self {
        case .noMappingFound(let identifier):
            return "No field mapping found for: \(identifier)"
        case .cacheNotLoaded:
            return "Field mapping cache not loaded"
        case .unknownSleepValue(let value):
            return "Unknown HKCategoryValueSleepAnalysis value: \(value)"
        }
    }
}
