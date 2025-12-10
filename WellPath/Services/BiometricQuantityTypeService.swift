//
//  BiometricQuantityTypeService.swift
//  WellPath
//
//  Service to look up sample_quantity_type from display_views_dependencies
//  Replaces hardcoded BiometricNameMapping enum
//

import Foundation
import Supabase

/// Service for looking up biometric quantity types from the database
@MainActor
class BiometricQuantityTypeService {
    static let shared = BiometricQuantityTypeService()

    private let supabase = SupabaseManager.shared.client

    /// Cache of metricId -> quantityType mappings
    private var cache: [String: String] = [:]
    private var hasLoadedAll = false

    private init() {}

    /// Get the primary quantity_type for a metric ID
    /// Returns nil if no mapping exists
    func quantityType(for metricId: String) async -> String? {
        // Check cache first
        if let cached = cache[metricId] {
            return cached
        }

        // Load from database
        do {
            struct DependencyMapping: Codable {
                let sampleQuantityType: String?

                enum CodingKeys: String, CodingKey {
                    case sampleQuantityType = "sample_quantity_type"
                }
            }

            let results: [DependencyMapping] = try await supabase
                .from("display_views_dependencies")
                .select("sample_quantity_type")
                .eq("view_id", value: metricId)
                .eq("is_primary", value: true)
                .limit(1)
                .execute()
                .value

            if let quantityType = results.first?.sampleQuantityType {
                cache[metricId] = quantityType
                return quantityType
            }

            return nil
        } catch {
            print("⚠️ Error looking up quantity_type for \(metricId): \(error)")
            return nil
        }
    }

    /// Preload all biometric quantity types for better performance
    func preloadAll() async {
        guard !hasLoadedAll else { return }

        do {
            struct DependencyMapping: Codable {
                let viewId: String
                let sampleQuantityType: String?

                enum CodingKeys: String, CodingKey {
                    case viewId = "view_id"
                    case sampleQuantityType = "sample_quantity_type"
                }
            }

            let results: [DependencyMapping] = try await supabase
                .from("display_views_dependencies")
                .select("view_id, sample_quantity_type")
                .eq("is_primary", value: true)
                .not("sample_quantity_type", operator: .is, value: "null")
                .execute()
                .value

            for mapping in results {
                if let quantityType = mapping.sampleQuantityType {
                    cache[mapping.viewId] = quantityType
                }
            }

            hasLoadedAll = true
            print("📦 Preloaded \(cache.count) biometric quantity_type mappings")
        } catch {
            print("⚠️ Error preloading biometric quantity_types: \(error)")
        }
    }

    /// Clear the cache (useful for testing or refresh)
    func clearCache() {
        cache.removeAll()
        hasLoadedAll = false
    }
}

// MARK: - Static Display Name Helper

/// Simple helper for biometric display names
/// These are just fallback names used in data management views
enum BiometricDisplayNames {
    static func displayName(for metricId: String) -> String {
        switch metricId {
        case "DISP_BMI":
            return "Body Mass Index"
        case "DISP_BODYFAT":
            return "Body Fat %"
        case "DISP_BODYWEIGHT":
            return "Body Weight"
        case "DISP_VISCERAL_FAT":
            return "Visceral Fat"
        case "DISP_WAIST_CIRCUMFERENCE":
            return "Waist Circumference"
        case "DISP_HIP_CIRCUMFERENCE":
            return "Hip Circumference"
        case "DISP_WAIST_HIP":
            return "Waist-to-Hip Ratio"
        case "DISP_ASMI":
            return "Appendicular Skeletal Muscle Index"
        case "DISP_BLOOD_PRESSURE", "DISP_SYSTOLIC_BP":
            return "Blood Pressure (Systolic)"
        case "DISP_DIASTOLIC_BP":
            return "Blood Pressure (Diastolic)"
        case "DISP_HRV":
            return "Heart Rate Variability"
        case "DISP_GRIP_STRENGTH":
            return "Grip Strength"
        case "DISP_RESTING_HR":
            return "Resting Heart Rate"
        case "DISP_VO2_MAX":
            return "VO2 Max"
        default:
            return metricId.replacingOccurrences(of: "DISP_", with: "")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }
}
