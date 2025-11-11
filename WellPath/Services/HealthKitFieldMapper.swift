//
//  HealthKitFieldMapper.swift
//  WellPath
//
//  Maps HealthKit identifiers to WellPath field_ids using backend data
//

import Foundation
import HealthKit

@MainActor
class HealthKitFieldMapper: ObservableObject {
    static let shared = HealthKitFieldMapper()

    private let supabase = SupabaseManager.shared.client
    private var mappingCache: [String: String] = [:] // healthkit_identifier -> field_id
    private var reverseMappingCache: [String: String] = [:] // field_id -> healthkit_identifier
    private var isCacheLoaded = false

    private init() {}

    /// Load all HealthKit mappings from backend and cache them
    func loadMappings() async throws {
        guard !isCacheLoaded else { return }

        print("📥 Loading HealthKit field mappings from backend...")

        // Query field_registry_complete view which includes healthkit_identifier
        let fields: [HealthKitFieldMapping] = try await supabase
            .from("field_registry_complete")
            .select("field_id, healthkit_identifier")
            .not("healthkit_identifier", operator: .is, value: "null")
            .execute()
            .value

        // Populate both caches
        for field in fields {
            mappingCache[field.healthkitIdentifier] = field.fieldId
            reverseMappingCache[field.fieldId] = field.healthkitIdentifier
        }

        isCacheLoaded = true
        print("✅ Loaded \(mappingCache.count) HealthKit field mappings")
    }

    /// Get field_id for a HealthKit identifier (e.g., "HKQuantityTypeIdentifierDietaryProtein" -> "DEF_PROTEIN_GRAMS")
    func getFieldId(for healthKitIdentifier: String) async throws -> String {
        if !isCacheLoaded {
            try await loadMappings()
        }

        guard let fieldId = mappingCache[healthKitIdentifier] else {
            throw HealthKitFieldMapperError.noMappingFound(healthKitIdentifier)
        }

        return fieldId
    }

    /// Get field_id for a HealthKit quantity type
    func getFieldId(for quantityType: HKQuantityTypeIdentifier) async throws -> String {
        let identifier = "HKQuantityTypeIdentifier\(quantityType.rawValue.replacingOccurrences(of: "HKQuantityTypeIdentifier", with: ""))"
        return try await getFieldId(for: identifier)
    }

    /// Get field_id for a HealthKit category type
    func getFieldId(for categoryType: HKCategoryTypeIdentifier) async throws -> String {
        let identifier = "HKCategoryTypeIdentifier\(categoryType.rawValue.replacingOccurrences(of: "HKCategoryTypeIdentifier", with: ""))"
        return try await getFieldId(for: identifier)
    }

    /// Get HealthKit identifier for a field_id (reverse lookup)
    func getHealthKitIdentifier(for fieldId: String) async throws -> String {
        if !isCacheLoaded {
            try await loadMappings()
        }

        guard let identifier = reverseMappingCache[fieldId] else {
            throw HealthKitFieldMapperError.noMappingFound(fieldId)
        }

        return identifier
    }

    /// Clear cache (useful for debugging or if mappings change)
    func clearCache() {
        mappingCache.removeAll()
        reverseMappingCache.removeAll()
        isCacheLoaded = false
    }
}

// MARK: - Models

struct HealthKitFieldMapping: Codable {
    let fieldId: String
    let healthkitIdentifier: String

    enum CodingKeys: String, CodingKey {
        case fieldId = "field_id"
        case healthkitIdentifier = "healthkit_identifier"
    }
}

// MARK: - Errors

enum HealthKitFieldMapperError: Error, LocalizedError {
    case noMappingFound(String)
    case cacheNotLoaded

    var errorDescription: String? {
        switch self {
        case .noMappingFound(let identifier):
            return "No field mapping found for: \(identifier)"
        case .cacheNotLoaded:
            return "Field mapping cache not loaded"
        }
    }
}
