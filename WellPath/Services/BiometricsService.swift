//
//  BiometricsService.swift
//  WellPath
//
//  Created on 2025-10-22
//

import Foundation
import Supabase

@MainActor
class BiometricsService: ObservableObject {
    private let supabase = SupabaseManager.shared.client

    // MARK: - Fetch Biomarker Readings for User
    func fetchBiomarkerReadings(for userId: UUID) async throws -> [BiomarkerReading] {
        let response: [BiomarkerReading] = try await supabase
            .from("patient_biomarker_readings")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("test_date", ascending: false)
            .execute()
            .value

        return response
    }

    // MARK: - Fetch Specific Biomarker History
    func fetchBiomarkerHistory(biomarkerName: String, userId: UUID) async throws -> [BiomarkerReading] {
        let response: [BiomarkerReading] = try await supabase
            .from("patient_biomarker_readings")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("biomarker_name", value: biomarkerName)
            .order("test_date", ascending: false)
            .execute()
            .value

        return response
    }

    // MARK: - Fetch Biomarker Range Details
    func fetchBiomarkerDetails(for biomarkerName: String) async throws -> [BiomarkerDetail] {
        let response: [BiomarkerDetail] = try await supabase
            .from("biomarkers_detail")
            .select()
            .eq("biomarker", value: biomarkerName)
            .execute()
            .value

        return response
    }

    // MARK: - Fetch Biomarker Base Info with Unit Display
    func fetchBiomarkerBase(for biomarkerName: String) async throws -> BiomarkerBase? {
        print("🔍 BiometricsService: Querying biomarkers_base for biomarker_name = '\(biomarkerName)'")

        // First fetch the biomarker
        let biomarkerResponse: [BiomarkerBase] = try await supabase
            .from("biomarkers_base")
            .select()
            .eq("biomarker_name", value: biomarkerName)
            .limit(1)
            .execute()
            .value

        print("🔍 BiometricsService: Got \(biomarkerResponse.count) results")
        if let first = biomarkerResponse.first {
            print("🔍 BiometricsService: First result biomarker_name = '\(first.biomarkerName)'")
        }

        guard let biomarker = biomarkerResponse.first else {
            print("❌ BiometricsService: No biomarker found for '\(biomarkerName)'")
            return nil
        }

        // If it has a unit, fetch the display from units_base
        if let unitId = biomarker.units {
            let unitResponse: [[String: String]] = try await supabase
                .from("units_base")
                .select("ui_display")
                .eq("unit_id", value: unitId)
                .limit(1)
                .execute()
                .value

            if let unitDisplay = unitResponse.first?["ui_display"] {
                // Create a new biomarker with the unit display
                return BiomarkerBase(
                    id: biomarker.id,
                    markerId: biomarker.markerId,
                    biomarkerName: biomarker.biomarkerName,
                    category: biomarker.category,
                    units: biomarker.units,
                    unitDisplay: unitDisplay,
                    format: biomarker.format,
                    isActive: biomarker.isActive,
                    aboutWhy: biomarker.aboutWhy,
                    aboutOptimalTarget: biomarker.aboutOptimalTarget,
                    aboutQuickTips: biomarker.aboutQuickTips
                )
            }
        }

        return biomarker
    }

    // MARK: - Fetch Biometric Readings for User
    func fetchBiometricReadings(for userId: UUID) async throws -> [BiometricReading] {
        let response: [BiometricReading] = try await supabase
            .from("patient_biometric_readings")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("recorded_at", ascending: false)
            .execute()
            .value

        return response
    }

    // MARK: - Fetch Biometrics Base Info with Unit Display
    func fetchBiometricsBase(for biometricName: String) async throws -> BiometricsBase? {
        // First fetch the biometric
        let biometricResponse: [BiometricsBase] = try await supabase
            .from("biometrics_base")
            .select()
            .eq("biometric_name", value: biometricName)
            .limit(1)
            .execute()
            .value

        guard let biometric = biometricResponse.first else {
            return nil
        }

        // If it has a unit, fetch the display from units_base
        if let unitId = biometric.unit {
            let unitResponse: [[String: String]] = try await supabase
                .from("units_base")
                .select("ui_display")
                .eq("unit_id", value: unitId)
                .limit(1)
                .execute()
                .value

            if let unitDisplay = unitResponse.first?["ui_display"] {
                // Create a new biometric with the unit display
                return BiometricsBase(
                    id: biometric.id,
                    metricId: biometric.metricId,
                    biometricName: biometric.biometricName,
                    nameBackend: biometric.nameBackend,
                    category: biometric.category,
                    unit: biometric.unit,
                    unitDisplay: unitDisplay,
                    format: biometric.format,
                    isActive: biometric.isActive,
                    aboutWhy: biometric.aboutWhy,
                    aboutOptimalRange: biometric.aboutOptimalRange,
                    aboutQuickTips: biometric.aboutQuickTips
                )
            }
        }

        return biometric
    }

    // MARK: - Fetch Biometric Range Details
    func fetchBiometricDetails(for biometricName: String) async throws -> [BiometricDetail] {
        let response: [BiometricDetail] = try await supabase
            .from("biometrics_detail")
            .select()
            .eq("biometric", value: biometricName)
            .execute()
            .value

        return response
    }

    // MARK: - Get Optimal Range Display for Biometric
    func getOptimalRangeDisplayBiometric(from ranges: [BiometricDetail], gender: String = "all", age: Int? = nil) -> String {
        // Filter ranges for the appropriate gender and age
        var applicableRanges = ranges.filter { range in
            range.gender?.lowercased() == gender.lowercased() ||
            range.gender?.lowercased() == "all"
        }

        // If age is provided, filter by age range
        if let age = age {
            applicableRanges = applicableRanges.filter { range in
                let matchesAgeMin = range.ageMin == nil || age >= range.ageMin!
                let matchesAgeMax = range.ageMax == nil || age <= range.ageMax!
                return matchesAgeMin && matchesAgeMax
            }
        }

        // Find the "Optimal" range
        if let optimalRange = applicableRanges.first(where: {
            $0.rangeName?.lowercased().contains("optimal") ?? false
        }) {
            return optimalRange.frontendDisplaySpecific ?? "N/A"
        }

        // Fallback to first range
        return applicableRanges.first?.frontendDisplaySpecific ?? "N/A"
    }

    // MARK: - Determine Biometric Status from Value and Ranges
    func determineBiometricStatus(value: Double, ranges: [BiometricDetail], gender: String = "all") async -> String {
        // Filter ranges for the appropriate gender
        let applicableRanges = ranges.filter { range in
            range.gender?.lowercased() == gender.lowercased() ||
            range.gender?.lowercased() == "all"
        }

        // Find which range the value falls into and return the range_bucket
        for range in applicableRanges {
            var matchesRange = false

            if let low = range.rangeLow, let high = range.rangeHigh {
                matchesRange = value >= low && value <= high
            } else if let low = range.rangeLow, range.rangeHigh == nil {
                matchesRange = value >= low
            } else if let high = range.rangeHigh, range.rangeLow == nil {
                matchesRange = value <= high
            }

            if matchesRange {
                // Use the range_bucket if available
                if let bucket = range.rangeBucket {
                    return bucket
                }
                return range.rangeName ?? "Unknown"
            }
        }

        return "Unknown"
    }

    // MARK: - Fetch Categories
    func fetchCategories() async throws -> [BiometricsBiomarkersCategory] {
        let response: [BiometricsBiomarkersCategory] = try await supabase
            .from("biometrics_biomarkers_categories")
            .select()
            .execute()
            .value

        return response
    }

    // MARK: - Determine Status from Value and Ranges
    func determineStatus(value: Double, ranges: [BiomarkerDetail], gender: String = "all") async -> String {
        // Filter ranges for the appropriate gender
        let applicableRanges = ranges.filter { range in
            range.gender?.lowercased() == gender.lowercased() ||
            range.gender?.lowercased() == "all"
        }

        // Find which range the value falls into and return the range_bucket
        for range in applicableRanges {
            var matchesRange = false

            if let low = range.rangeLow, let high = range.rangeHigh {
                matchesRange = value >= low && value <= high
            } else if let low = range.rangeLow, range.rangeHigh == nil {
                matchesRange = value >= low
            } else if let high = range.rangeHigh, range.rangeLow == nil {
                matchesRange = value <= high
            }

            if matchesRange {
                // Use the range_bucket if available, otherwise fall back to range name
                if let bucket = range.rangeBucket {
                    return bucket
                }
                return range.rangeName
            }
        }

        return "Unknown"
    }

    // MARK: - Get Detailed Range Name (not bucket)
    func getRangeName(value: Double, ranges: [BiomarkerDetail], gender: String = "all") async -> String {
        // Filter ranges for the appropriate gender
        let applicableRanges = ranges.filter { range in
            range.gender?.lowercased() == gender.lowercased() ||
            range.gender?.lowercased() == "all"
        }

        // Find which range the value falls into and return the range name
        for range in applicableRanges {
            var matchesRange = false

            if let low = range.rangeLow, let high = range.rangeHigh {
                matchesRange = value >= low && value <= high
            } else if let low = range.rangeLow, range.rangeHigh == nil {
                matchesRange = value >= low
            } else if let high = range.rangeHigh, range.rangeLow == nil {
                matchesRange = value <= high
            }

            if matchesRange {
                return range.rangeName
            }
        }

        return "Unknown"
    }

    // MARK: - Get Detailed Biometric Range Name (not bucket)
    func getBiometricRangeName(value: Double, ranges: [BiometricDetail], gender: String = "all") async -> String {
        // Filter ranges for the appropriate gender
        let applicableRanges = ranges.filter { range in
            range.gender?.lowercased() == gender.lowercased() ||
            range.gender?.lowercased() == "all"
        }

        // Find which range the value falls into and return the range name
        for range in applicableRanges {
            var matchesRange = false

            if let low = range.rangeLow, let high = range.rangeHigh {
                matchesRange = value >= low && value <= high
            } else if let low = range.rangeLow, range.rangeHigh == nil {
                matchesRange = value >= low
            } else if let high = range.rangeHigh, range.rangeLow == nil {
                matchesRange = value <= high
            }

            if matchesRange {
                return range.rangeName ?? "Unknown"
            }
        }

        return "Unknown"
    }

    // MARK: - Get Optimal Range Display String
    func getOptimalRangeDisplay(from ranges: [BiomarkerDetail], gender: String = "all") -> String {
        // Filter ranges for the appropriate gender first
        let applicableRanges = ranges.filter { range in
            range.gender?.lowercased() == gender.lowercased() ||
            range.gender?.lowercased() == "all"
        }

        // Find the "Optimal" range
        if let optimalRange = applicableRanges.first(where: { $0.rangeName.lowercased().contains("optimal") }) {
            return optimalRange.frontendDisplay ?? "N/A"
        }

        // Fallback to first range
        return applicableRanges.first?.frontendDisplay ?? "N/A"
    }

    // MARK: - Calculate Trend Description
    func calculateTrend(from readings: [BiomarkerReading]) -> String {
        guard readings.count >= 2 else { return "" }

        // Readings are ordered newest first, so take first 3 (most recent)
        let recent = Array(readings.prefix(3))

        if recent.count >= 2 {
            // Compare oldest to newest of the recent readings
            let newestValue = recent.first!.value  // Most recent
            let oldestValue = recent.last!.value   // Oldest of the recent 3
            let change = newestValue - oldestValue

            if change > 0 {
                return "Rising over time"
            } else if change < 0 {
                return "Decreasing over time"
            } else {
                return "Stable"
            }
        }

        return ""
    }
}
