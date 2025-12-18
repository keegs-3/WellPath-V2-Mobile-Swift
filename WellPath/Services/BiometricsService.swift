//
//  BiometricsService.swift
//  WellPath
//
//  Created on 2025-10-22
//

import Foundation
import Supabase

// MARK: - Helper structs for queries

/// Clinical sample row for reading biomarkers from patient_clinical_samples
private struct ClinicalSampleRow: Codable {
    let id: UUID
    let patientId: UUID
    let clinicalType: String
    let value: Double?
    let unit: String?
    let sampleTime: Date
    let source: String?
    let labName: String?
    let cycleStage: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case clinicalType = "clinical_type"
        case value
        case unit
        case sampleTime = "sample_time"
        case source
        case labName = "lab_name"
        case cycleStage = "cycle_stage"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Quantity sample row for reading biometrics from patient_quantity_samples
private struct QuantitySampleRow: Codable {
    let id: UUID
    let patientId: UUID
    let quantityType: String
    let quantityValue: Double?
    let quantityUnit: String?
    let startTime: Date
    let source: String?
    let metadata: [String: AnyJSON]?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case quantityType = "quantity_type"
        case quantityValue = "quantity_value"
        case quantityUnit = "quantity_unit"
        case startTime = "start_time"
        case source
        case metadata
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Mapping from quantity_type to display_name
private struct QuantityTypeMapping: Codable {
    let quantityType: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case quantityType = "quantity_type"
        case displayName = "display_name"
    }
}

/// Mapping from name_backend to biometric_name
private struct BiometricNameMapping: Codable {
    let nameBackend: String
    let biometricName: String

    enum CodingKeys: String, CodingKey {
        case nameBackend = "name_backend"
        case biometricName = "biometric_name"
    }
}

@MainActor
class BiometricsService: ObservableObject {
    private let supabase = SupabaseManager.shared.client

    // MARK: - Fetch Biomarker Readings for User
    func fetchBiomarkerReadings(for userId: UUID) async throws -> [BiomarkerReading] {
        // Query patient_clinical_samples for biomarker data
        let samples: [ClinicalSampleRow] = try await supabase
            .from("patient_clinical_samples")
            .select("id, patient_id, clinical_type, value, unit, sample_time, source, lab_name, cycle_stage, created_at, updated_at")
            .eq("patient_id", value: userId.uuidString)
            .order("sample_time", ascending: false)
            .execute()
            .value

        // Get display name mappings from sample_clinical_types
        struct ClinicalTypeMapping: Codable {
            let clinicalType: String
            let displayName: String

            enum CodingKeys: String, CodingKey {
                case clinicalType = "clinical_type"
                case displayName = "display_name"
            }
        }

        let types: [ClinicalTypeMapping] = try await supabase
            .from("sample_clinical_types")
            .select("clinical_type, display_name")
            .execute()
            .value

        let nameMap = Dictionary(uniqueKeysWithValues: types.map { ($0.clinicalType, $0.displayName) })
        let dateFormatter = ISO8601DateFormatter()

        return samples.map { sample in
            BiomarkerReading(
                id: sample.id,
                patientId: sample.patientId,
                biomarkerName: nameMap[sample.clinicalType] ?? sample.clinicalType,
                value: sample.value ?? 0,
                unit: sample.unit ?? "",
                testDate: dateFormatter.string(from: sample.sampleTime),
                source: sample.source,
                notes: nil,  // Notes are now in metadata if needed
                cyclePhase: sample.cycleStage,
                createdAt: sample.createdAt,
                updatedAt: sample.updatedAt
            )
        }
    }

    // MARK: - Fetch Specific Biomarker History
    func fetchBiomarkerHistory(biomarkerName: String, userId: UUID) async throws -> [BiomarkerReading] {
        // First get the clinical_type for this biomarker display name
        struct ClinicalTypeMapping: Codable {
            let clinicalType: String
            let displayName: String

            enum CodingKeys: String, CodingKey {
                case clinicalType = "clinical_type"
                case displayName = "display_name"
            }
        }

        let types: [ClinicalTypeMapping] = try await supabase
            .from("sample_clinical_types")
            .select("clinical_type, display_name")
            .eq("display_name", value: biomarkerName)
            .execute()
            .value

        guard let clinicalType = types.first?.clinicalType else {
            return []
        }

        let samples: [ClinicalSampleRow] = try await supabase
            .from("patient_clinical_samples")
            .select("id, patient_id, clinical_type, value, unit, sample_time, source, lab_name, cycle_stage, created_at, updated_at")
            .eq("patient_id", value: userId.uuidString)
            .eq("clinical_type", value: clinicalType)
            .order("sample_time", ascending: false)
            .execute()
            .value

        let dateFormatter = ISO8601DateFormatter()

        return samples.map { sample in
            BiomarkerReading(
                id: sample.id,
                patientId: sample.patientId,
                biomarkerName: biomarkerName,
                value: sample.value ?? 0,
                unit: sample.unit ?? "",
                testDate: dateFormatter.string(from: sample.sampleTime),
                source: sample.source,
                notes: nil,  // Notes now in metadata if needed
                cyclePhase: sample.cycleStage,
                createdAt: sample.createdAt,
                updatedAt: sample.updatedAt
            )
        }
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

    // MARK: - Fetch Biomarker Details with Patient-Specific Filtering
    /// Fetches biomarker ranges filtered by patient attributes (gender, menopausal status, athlete status)
    /// and optionally by cycle phase for hormone biomarkers.
    ///
    /// - Parameters:
    ///   - biomarkerName: The name of the biomarker
    ///   - gender: Patient's biological sex (male/female)
    ///   - menopausalStatus: Patient's menopausal status (Premenopausal/Postmenopausal) - optional
    ///   - isAthlete: Whether patient is an athlete (affects ranges for biomarkers like Creatine Kinase)
    ///   - cyclePhase: Current cycle phase for the reading (Follicular/Luteal/Ovulatory) - optional
    /// - Returns: Filtered array of BiomarkerDetail ranges
    func fetchBiomarkerDetailsFiltered(
        for biomarkerName: String,
        gender: String,
        menopausalStatus: String? = nil,
        isAthlete: Bool = false,
        cyclePhase: String? = nil
    ) async throws -> [BiomarkerDetail] {
        // Fetch all ranges for this biomarker
        let allRanges: [BiomarkerDetail] = try await supabase
            .from("biomarkers_detail")
            .select()
            .eq("biomarker", value: biomarkerName)
            .execute()
            .value

        // Apply filters in order of specificity
        let filteredRanges = allRanges.filter { range in
            // 1. Gender filter: match patient gender or "all"
            let genderMatch = range.gender?.lowercased() == gender.lowercased() ||
                              range.gender?.lowercased() == "all" ||
                              range.gender == nil

            // 2. Menopausal status filter (for female patients)
            let menopausalMatch: Bool
            if let patientMenopausal = menopausalStatus, let rangeMenopausal = range.menopausalStatus {
                // If both patient and range have menopausal status, they must match
                menopausalMatch = rangeMenopausal.lowercased() == patientMenopausal.lowercased()
            } else if range.menopausalStatus != nil {
                // Range requires specific menopausal status but patient doesn't have one - skip this range
                menopausalMatch = false
            } else {
                // Range doesn't require menopausal status - include it
                menopausalMatch = true
            }

            // 3. Unique condition filter (athlete status)
            let athleteMatch: Bool
            if isAthlete {
                // Patient is athlete - prefer athlete ranges, but fall back to general if none exist
                athleteMatch = range.uniqueCondition == "athlete" || range.uniqueCondition == nil
            } else {
                // Patient is not athlete - only use ranges without unique_condition
                athleteMatch = range.uniqueCondition == nil
            }

            // 4. Cycle phase filter (for hormone biomarkers)
            let cycleMatch: Bool
            if let patientCycle = cyclePhase, let rangeCycle = range.cycleStage {
                // If both patient reading and range have cycle info, they must match
                cycleMatch = rangeCycle.lowercased() == patientCycle.lowercased()
            } else if range.cycleStage != nil {
                // Range requires specific cycle stage but reading doesn't have one - skip this range
                cycleMatch = false
            } else {
                // Range doesn't require cycle stage - include it
                cycleMatch = true
            }

            return genderMatch && menopausalMatch && athleteMatch && cycleMatch
        }

        // If athlete filtering returned no results, fall back to non-athlete ranges
        if filteredRanges.isEmpty && isAthlete {
            print("⚠️ No athlete-specific ranges found for \(biomarkerName), falling back to general ranges")
            return allRanges.filter { range in
                let genderMatch = range.gender?.lowercased() == gender.lowercased() ||
                                  range.gender?.lowercased() == "all" ||
                                  range.gender == nil
                let menopausalMatch = range.menopausalStatus == nil ||
                                      (menopausalStatus != nil && range.menopausalStatus?.lowercased() == menopausalStatus?.lowercased())
                let cycleMatch = range.cycleStage == nil ||
                                 (cyclePhase != nil && range.cycleStage?.lowercased() == cyclePhase?.lowercased())
                return genderMatch && menopausalMatch && range.uniqueCondition == nil && cycleMatch
            }
        }

        print("📊 Filtered \(biomarkerName) ranges: \(filteredRanges.count) of \(allRanges.count) (gender=\(gender), menopausal=\(menopausalStatus ?? "nil"), athlete=\(isAthlete), cycle=\(cyclePhase ?? "nil"))")

        return filteredRanges
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

        return biomarker
    }

    // MARK: - Fetch Biometric Readings for User
    func fetchBiometricReadings(for userId: UUID) async throws -> [BiometricReading] {
        // Get biometric name mappings from biometrics_base
        let biometricTypes: [BiometricNameMapping] = try await supabase
            .from("biometrics_base")
            .select("name_backend, biometric_name")
            .eq("is_active", value: true)
            .execute()
            .value

        let nameBackendSet = Set(biometricTypes.map { $0.nameBackend })
        let nameMap = Dictionary(uniqueKeysWithValues: biometricTypes.map { ($0.nameBackend, $0.biometricName) })

        // Query patient_quantity_samples for biometric data
        let samples: [QuantitySampleRow] = try await supabase
            .from("patient_quantity_samples")
            .select("id, patient_id, quantity_type, quantity_value, quantity_unit, start_time, source, metadata, created_at, updated_at")
            .eq("patient_id", value: userId.uuidString)
            .eq("is_primary", value: true)  // Only use primary samples for analysis
            .order("start_time", ascending: false)
            .execute()
            .value

        let dateFormatter = ISO8601DateFormatter()

        // Filter to only biometric types (those in biometrics_base) and transform
        return samples
            .filter { nameBackendSet.contains($0.quantityType) }
            .map { sample in
                BiometricReading(
                    id: sample.id,
                    patientId: sample.patientId,
                    biometricName: nameMap[sample.quantityType] ?? sample.quantityType,
                    value: sample.quantityValue ?? 0,
                    unit: sample.quantityUnit ?? "",
                    recordedAt: dateFormatter.string(from: sample.startTime),
                    source: sample.source,
                    notes: {
                        if let metadata = sample.metadata,
                           case .string(let notes) = metadata["notes"] {
                            return notes
                        }
                        return nil
                    }(),
                    createdAt: sample.createdAt,
                    updatedAt: sample.updatedAt
                )
            }
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
                    aboutQuickTips: biometric.aboutQuickTips,
                    education: biometric.education
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
            let ageDouble = Double(age)
            applicableRanges = applicableRanges.filter { range in
                let matchesAgeLow = range.ageLow == nil || ageDouble >= range.ageLow!
                let matchesAgeHigh = range.ageHigh == nil || ageDouble <= range.ageHigh!
                return matchesAgeLow && matchesAgeHigh
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
                // rangeName IS the bucket now
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

    // MARK: - Fetch Unit Conversions
    func fetchUnitConversions(for unitId: String) async throws -> [UnitConversion] {
        // Fetch conversions where this unit is the "from" unit
        let response: [UnitConversion] = try await supabase
            .from("unit_conversions")
            .select()
            .eq("from_unit_id", value: unitId)
            .execute()
            .value

        return response
    }

    // MARK: - Convert Value
    func convertValue(_ value: Double, from fromUnit: String, to toUnit: String, conversions: [UnitConversion]) -> Double {
        // If units are the same, return original value
        guard fromUnit != toUnit else { return value }

        // Find the conversion
        if let conversion = conversions.first(where: { $0.fromUnit == fromUnit && $0.toUnit == toUnit }) {
            // Apply conversion: value * factor + offset
            let convertedValue = value * conversion.conversionFactor
            if let offset = conversion.conversionOffset {
                return convertedValue + offset
            }
            return convertedValue
        }

        // No conversion found, return original
        return value
    }

    // MARK: - Get Unit Display Name
    func getUnitDisplayName(for unitId: String) async throws -> String {
        let response: [[String: String]] = try await supabase
            .from("units_base")
            .select("ui_display")
            .eq("unit_id", value: unitId)
            .limit(1)
            .execute()
            .value

        return response.first?["ui_display"] ?? unitId
    }

    // MARK: - Calculate Trend Description
    func calculateTrend(from readings: [BiomarkerReading]) -> String {
        // Insufficient data
        guard readings.count > 1 else { return "-" }

        // Get most recent value and oldest value
        let newestValue = readings.first!.value  // Most recent (readings are sorted newest first)
        let oldestValue = readings.last!.value   // Oldest

        // Calculate percent change from oldest to newest
        guard oldestValue != 0 else {
            // Handle division by zero - just compare absolute values
            if newestValue > oldestValue {
                return "Rising"
            } else if newestValue < oldestValue {
                return "Falling"
            } else {
                return "Stable"
            }
        }

        let percentChange = ((newestValue - oldestValue) / abs(oldestValue)) * 100

        // Use 5% threshold to determine significance
        if percentChange > 5 {
            return "Rising"
        } else if percentChange < -5 {
            return "Falling"
        } else {
            return "Stable"
        }
    }
}
