//
//  BiomarkerValueLoader.swift
//  WellPath
//
//  Loads biomarker values from patient_clinical_samples
//  Loads range information from biomarkers_detail with patient stratification
//

import Foundation
import SwiftUI
import Supabase

// MARK: - Range Info Model

struct BiomarkerRangeInfo {
    let directionality: String  // "optimal_range", "lower_better", "higher_better"
    let ranges: [BiomarkerRangeDetail]
    let realisticLow: Double?
    let realisticHigh: Double?

    var numberOfBands: Int {
        ranges.count
    }

    /// Returns ranges sorted from lowest to highest for 5-band display
    var sortedRanges: [BiomarkerRangeDetail] {
        ranges.sorted { ($0.rangeLow ?? Double.leastNormalMagnitude) < ($1.rangeLow ?? Double.leastNormalMagnitude) }
    }
}

struct BiomarkerRangeDetail: Identifiable {
    let id: UUID
    let rangeName: String
    let rangeNameBackend: String
    let rangeLow: Double?
    let rangeHigh: Double?
    let frontendDisplay: String?

    var color: Color {
        switch rangeName.uppercased() {
        case "OPTIMAL":
            return .green
        case "IN RANGE", "IN-RANGE":
            return Color.yellow
        default:  // "OUT OF RANGE", "OUT-OF-RANGE"
            return .red
        }
    }
}

// MARK: - Patient Info for Range Stratification

struct PatientRangeContext {
    let gender: String?
    let age: Int?
    let menopausalStatus: String?
    let cycleStage: String?
    let isAthlete: Bool

    init(gender: String? = nil, age: Int? = nil, menopausalStatus: String? = nil, cycleStage: String? = nil, isAthlete: Bool = false) {
        self.gender = gender
        self.age = age
        self.menopausalStatus = menopausalStatus
        self.cycleStage = cycleStage
        self.isAthlete = isAthlete
    }
}

// MARK: - BiomarkerValueLoader

@MainActor
class BiomarkerValueLoader: ObservableObject {
    @Published var currentValue: Double?
    @Published var unit: String?
    @Published var unitDisplay: String?
    @Published var lastUpdated: Date?
    @Published var isLoading = false
    @Published var rangeInfo: BiomarkerRangeInfo?
    @Published var biomarkerBase: BiomarkerBase?

    private let supabase = SupabaseManager.shared.client

    /// Maps raw unit strings from database to human-readable display symbols
    private static let unitDisplayMap: [String: String] = [
        "percent": "%",
        "percentage": "%",
        "grams_per_deciliter": "g/dL",
        "milligrams_per_deciliter": "mg/dL",
        "micrograms_per_deciliter": "µg/dL",
        "nanograms_per_deciliter": "ng/dL",
        "picograms_per_milliliter": "pg/mL",
        "nanograms_per_milliliter": "ng/mL",
        "milligrams_per_liter": "mg/L",
        "micrograms_per_liter": "µg/L",
        "micromoles_per_liter": "µmol/L",
        "millimoles_per_liter": "mmol/L",
        "units_per_liter": "U/L",
        "micro_international_units_per_milliliter": "µIU/mL",
        "international_units_per_liter": "IU/L",
        "milliliters_per_minute_per_1_73_m2": "mL/min/1.73m²",
        "per_microliter": "/µL",
        "cells_per_microliter": "cells/µL",
        "kilogram": "kg",
        "pound": "lb",
        "centimeter": "cm",
        "inch": "in",
        "millimeter_of_mercury": "mmHg",
        "millisecond": "ms",
        "beat_per_minute": "bpm",
        "beats_per_minute": "bpm",
        "milliliter_per_kilogram_per_minute": "mL/kg/min"
    ]

    /// Convert raw unit string to human-readable display format
    static func formatUnitForDisplay(_ rawUnit: String?) -> String {
        guard let unit = rawUnit?.lowercased() else { return "" }
        return unitDisplayMap[unit] ?? rawUnit ?? ""
    }

    // MARK: - Load Value and Range

    func loadValue(for biomarkerName: String) async {
        isLoading = true

        do {
            let patientId = try await supabase.auth.session.user.id

            // Load patient context for range stratification (includes all relevant characteristics)
            let patientContext = await loadPatientContext(patientId: patientId)

            // Load biomarker base info
            await loadBiomarkerBase(biomarkerName: biomarkerName)

            // Load latest value from patient_samples
            await loadLatestValue(biomarkerName: biomarkerName, patientId: patientId)

            // Load range info from biomarkers_detail with full patient stratification
            await loadRangeInfo(biomarkerName: biomarkerName, patientContext: patientContext)

        } catch {
            print("❌ Error loading biomarker value: \(error)")
        }

        isLoading = false
    }

    // MARK: - Private Helpers

    private func loadPatientContext(patientId: UUID) async -> PatientRangeContext {
        do {
            struct CharacteristicResult: Codable {
                let characteristicTypeName: String
                let valueText: String?
                let valueDate: String?
                let valueBoolean: Bool?

                enum CodingKeys: String, CodingKey {
                    case characteristicTypeName = "characteristic_type_name"
                    case valueText = "value_text"
                    case valueDate = "value_date"
                    case valueBoolean = "value_boolean"
                }
            }

            // Fetch all relevant characteristics for biomarker range filtering
            let results: [CharacteristicResult] = try await supabase
                .from("patient_characteristics")
                .select("characteristic_type_name, value_text, value_date, value_boolean")
                .eq("patient_id", value: patientId.uuidString)
                .in("characteristic_type_name", values: [
                    "biological_sex",
                    "date_of_birth",
                    "menopausal_status",
                    "athlete_status"
                ])
                .execute()
                .value

            var gender: String?
            var age: Int?
            var menopausalStatus: String?
            var isAthlete: Bool = false

            for char in results {
                switch char.characteristicTypeName {
                case "biological_sex":
                    gender = char.valueText?.lowercased()
                case "date_of_birth":
                    if let dobString = char.valueDate {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        if let birthDate = formatter.date(from: dobString) {
                            age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year
                        }
                    }
                case "menopausal_status":
                    menopausalStatus = char.valueText
                case "athlete_status":
                    isAthlete = char.valueBoolean ?? false
                default:
                    break
                }
            }

            print("📋 Patient context loaded: gender=\(gender ?? "nil"), age=\(age ?? -1), menopausal=\(menopausalStatus ?? "nil"), athlete=\(isAthlete)")

            return PatientRangeContext(
                gender: gender,
                age: age,
                menopausalStatus: menopausalStatus,
                cycleStage: nil,  // Would need cycle tracking feature
                isAthlete: isAthlete
            )
        } catch {
            print("⚠️ Could not load patient context: \(error)")
        }

        return PatientRangeContext()
    }

    private func loadBiomarkerBase(biomarkerName: String) async {
        do {
            let results: [BiomarkerBase] = try await supabase
                .from("biomarkers_base")
                .select()
                .eq("biomarker_name", value: biomarkerName)
                .limit(1)
                .execute()
                .value

            if let base = results.first {
                biomarkerBase = base
                unit = base.units
                unitDisplay = Self.formatUnitForDisplay(base.units)
            }
        } catch {
            print("⚠️ Could not load biomarker base: \(error)")
        }
    }

    private func loadLatestValue(biomarkerName: String, patientId: UUID) async {
        do {
            struct ClinicalSampleReading: Codable {
                let value: Double
                let unit: String?
                let sampleTime: Date

                enum CodingKeys: String, CodingKey {
                    case value
                    case unit
                    case sampleTime = "sample_time"
                }
            }

            // Query patient_clinical_samples using biomarker name as clinical_type
            let results: [ClinicalSampleReading] = try await supabase
                .from("patient_clinical_samples")
                .select("value, unit, sample_time")
                .eq("patient_id", value: patientId)
                .eq("clinical_type", value: biomarkerName)
                .order("sample_time", ascending: false)
                .limit(1)
                .execute()
                .value

            if let reading = results.first {
                currentValue = reading.value
                lastUpdated = reading.sampleTime
                if let readingUnit = reading.unit {
                    unitDisplay = Self.formatUnitForDisplay(readingUnit)
                }
            }
        } catch {
            print("⚠️ Could not load latest biomarker value: \(error)")
        }
    }

    private func loadRangeInfo(biomarkerName: String, patientContext: PatientRangeContext) async {
        do {
            // Fetch all columns needed for filtering
            let query = supabase
                .from("biomarkers_detail")
                .select("id, range_name, range_name_backend, range_low, range_high, frontend_display, gender, directionality, unique_condition, age_low, age_high, menopausal_status")
                .eq("biomarker", value: biomarkerName)

            struct RangeRecord: Codable {
                let id: UUID
                let rangeName: String
                let rangeNameBackend: String
                let rangeLow: Double?
                let rangeHigh: Double?
                let frontendDisplay: String?
                let gender: String?
                let directionality: String?
                let uniqueCondition: String?
                let ageLow: Double?
                let ageHigh: Double?
                let menopausalStatus: String?

                enum CodingKeys: String, CodingKey {
                    case id
                    case rangeName = "range_name"
                    case rangeNameBackend = "range_name_backend"
                    case rangeLow = "range_low"
                    case rangeHigh = "range_high"
                    case frontendDisplay = "frontend_display"
                    case gender
                    case directionality
                    case uniqueCondition = "unique_condition"
                    case ageLow = "age_low"
                    case ageHigh = "age_high"
                    case menopausalStatus = "menopausal_status"
                }
            }

            let results: [RangeRecord] = try await query.execute().value
            print("📊 Fetched \(results.count) total ranges for \(biomarkerName)")

            // Filter by patient context with proper stratification
            let filteredRanges = results.filter { range in
                // 1. Gender filter
                if let rangeGender = range.gender?.lowercased(),
                   rangeGender != "all" {
                    // Range requires specific gender
                    if let patientGender = patientContext.gender?.lowercased() {
                        if rangeGender != patientGender {
                            return false
                        }
                    }
                    // If patient gender unknown, skip gender-specific ranges
                    else {
                        return false
                    }
                }

                // 2. Age filter
                if let patientAge = patientContext.age {
                    let ageLow = range.ageLow ?? 0
                    let ageHigh = range.ageHigh ?? 150

                    if Double(patientAge) < ageLow || Double(patientAge) > ageHigh {
                        return false
                    }
                }

                // 3. Menopausal status filter
                if let rangeMenopausal = range.menopausalStatus?.lowercased(),
                   !rangeMenopausal.isEmpty {
                    // Range requires specific menopausal status
                    if let patientMenopausal = patientContext.menopausalStatus?.lowercased() {
                        if rangeMenopausal != patientMenopausal {
                            return false
                        }
                    } else {
                        // If patient menopausal status unknown, skip status-specific ranges
                        return false
                    }
                }

                // 4. Athlete status filter (unique_condition = "athlete")
                if let condition = range.uniqueCondition?.lowercased(), !condition.isEmpty {
                    if condition == "athlete" {
                        // Only include athlete ranges if patient is an athlete
                        if !patientContext.isAthlete {
                            return false
                        }
                    } else {
                        // Unknown condition - skip for safety
                        return false
                    }
                } else {
                    // No unique_condition - this is a "normal" range
                    // Skip if patient IS an athlete (they should use athlete-specific ranges)
                    // But only if athlete-specific ranges exist for this biomarker
                    if patientContext.isAthlete {
                        // Check if there are athlete-specific ranges for same gender
                        let hasAthleteRange = results.contains { r in
                            r.uniqueCondition?.lowercased() == "athlete" &&
                            (r.gender?.lowercased() == range.gender?.lowercased() || r.gender?.lowercased() == "all")
                        }
                        if hasAthleteRange {
                            return false
                        }
                    }
                }

                return true
            }

            print("📊 After filtering: \(filteredRanges.count) ranges match patient context")

            // Get directionality from first result
            let directionality = filteredRanges.first?.directionality ?? "optimal_range"

            // Get realistic range from biomarkers_base
            var realisticLow: Double?
            var realisticHigh: Double?

            struct BaseWithRealistic: Codable {
                let realisticLow: Double?
                let realisticHigh: Double?

                enum CodingKeys: String, CodingKey {
                    case realisticLow = "realistic_low"
                    case realisticHigh = "realistic_high"
                }
            }

            let baseResults: [BaseWithRealistic] = try await supabase
                .from("biomarkers_base")
                .select("realistic_low, realistic_high")
                .eq("biomarker_name", value: biomarkerName)
                .limit(1)
                .execute()
                .value

            if let baseResult = baseResults.first {
                realisticLow = baseResult.realisticLow
                realisticHigh = baseResult.realisticHigh
            }

            // Convert to BiomarkerRangeDetail
            let ranges = filteredRanges.map { range in
                BiomarkerRangeDetail(
                    id: range.id,
                    rangeName: range.rangeName,
                    rangeNameBackend: range.rangeNameBackend,
                    rangeLow: range.rangeLow,
                    rangeHigh: range.rangeHigh,
                    frontendDisplay: range.frontendDisplay
                )
            }

            rangeInfo = BiomarkerRangeInfo(
                directionality: directionality,
                ranges: ranges,
                realisticLow: realisticLow,
                realisticHigh: realisticHigh
            )

        } catch {
            print("⚠️ Could not load range info: \(error)")
        }
    }

    // MARK: - Range Classification

    /// Determine which range the current value falls into
    func currentRangeName() -> String? {
        guard let value = currentValue,
              let ranges = rangeInfo?.ranges else { return nil }

        for range in ranges {
            let low = range.rangeLow ?? Double.leastNormalMagnitude
            let high = range.rangeHigh ?? Double.greatestFiniteMagnitude

            if value >= low && value < high {
                return range.rangeName
            }
        }

        return nil
    }

    /// Get the color for the current value's range
    func currentRangeColor() -> Color {
        guard let rangeName = currentRangeName() else { return .secondary }

        switch rangeName.uppercased() {
        case "OPTIMAL":
            return .green
        case "IN RANGE", "IN-RANGE":
            return Color.yellow
        default:
            return .red
        }
    }

    /// Create RangeSegments for the range indicator view
    func createRangeSegments() -> [RangeSegment] {
        guard let info = rangeInfo else { return [] }

        return info.sortedRanges.compactMap { range in
            guard let low = range.rangeLow ?? info.realisticLow,
                  let high = range.rangeHigh ?? info.realisticHigh else { return nil }

            let isPatientSegment = currentRangeName() == range.rangeName

            return RangeSegment(
                rangeName: range.rangeName,
                rangeBucket: range.rangeName,
                rangeLow: low,
                rangeHigh: high,
                isArtificialLow: range.rangeLow == nil,
                isArtificialHigh: range.rangeHigh == nil,
                isPatientSegment: isPatientSegment
            )
        }
    }
}
