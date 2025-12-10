//
//  BiomarkerModels.swift
//  WellPath
//
//  Clean, backend-driven models for Biomarkers
//  All biomarkers share these same models - no biomarker-specific types needed
//

import Foundation
import SwiftUI
import Supabase  // For AnyJSON type

// MARK: - Backend Display Models

/// Section from display_category_sections (e.g., NAV_BIOMARKERS)
struct BiomarkerSection: Codable, Identifiable {
    let id: UUID
    let sectionId: String
    let sectionName: String
    let headerId: String
    let description: String?
    let iconName: String?
    let colorHex: String?
    let displayOrder: Int?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case sectionId = "section_id"
        case sectionName = "section_name"
        case headerId = "header_id"
        case description
        case iconName = "icon_name"
        case colorHex = "color_hex"
        case displayOrder = "display_order"
        case isActive = "is_active"
    }

    var color: Color {
        guard let hex = colorHex else { return .orange }
        return Color(hex: hex) ?? .orange
    }
}

/// Category from display_card_categories (e.g., CAT_BIOMARKER_CARDIO)
struct BiomarkerCategory: Codable, Identifiable {
    let id: UUID
    let categoryId: String
    let name: String
    let overview: String?
    let pillar: String?
    let sectionId: String
    let iconName: String?
    let displayOrder: Int?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case categoryId = "category_id"
        case name
        case overview
        case pillar
        case sectionId = "section_id"
        case iconName = "icon_name"
        case displayOrder = "display_order"
        case isActive = "is_active"
    }

    var icon: String {
        iconName ?? "testtube.2"
    }
}

/// Card from display_view_cards (e.g., CARD_BIO_HDL)
struct BiomarkerViewCard: Codable, Identifiable {
    let id: UUID
    let cardId: String
    let cardName: String
    let description: String?
    let categoryId: String
    let viewId: String?
    let displayOrder: Int?
    let canFavorite: Bool?
    let isActive: Bool?
    // Dependencies loaded via card_dependencies VIEW (joins display_view_cards → display_views_dependencies)

    enum CodingKeys: String, CodingKey {
        case id
        case cardId = "card_id"
        case cardName = "card_name"
        case description
        case categoryId = "category_id"
        case viewId = "view_id"
        case displayOrder = "display_order"
        case canFavorite = "can_favorite"
        case isActive = "is_active"
    }
}

// MARK: - View Dependencies Model

/// Dependencies from display_views_dependencies (accessed via card_dependencies VIEW for cards)
/// Defines what data type a view needs (clinical, quantity, category, or correlation)
struct ViewDependency: Codable, Identifiable {
    let id: UUID?
    let viewId: String
    let sampleClinicalType: String?   // e.g., "hdl" for biomarkers
    let sampleQuantityType: String?   // e.g., "steps" for tracked metrics
    let sampleCategoryType: String?   // e.g., "sleep_period_types" for categories
    let sampleCorrelationType: String? // e.g., "blood_pressure" for correlations
    let displayOrder: Int?
    let seriesLabel: String?
    let seriesColor: String?
    let isPrimary: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case viewId = "view_id"
        case sampleClinicalType = "sample_clinical_type"
        case sampleQuantityType = "sample_quantity_type"
        case sampleCategoryType = "sample_category_type"
        case sampleCorrelationType = "sample_correlation_type"
        case displayOrder = "display_order"
        case seriesLabel = "series_label"
        case seriesColor = "series_color"
        case isPrimary = "is_primary"
    }

    /// Returns the data type this dependency references
    var dataType: ViewDependencyDataType {
        if sampleClinicalType != nil { return .clinical }
        if sampleQuantityType != nil { return .quantity }
        if sampleCategoryType != nil { return .category }
        if sampleCorrelationType != nil { return .correlation }
        return .unknown
    }
}

/// Type of data a view depends on
enum ViewDependencyDataType {
    case clinical      // Biomarkers from patient_clinical_samples
    case quantity      // Tracked metrics from patient_quantity_samples
    case category      // Category data from patient_category_samples
    case correlation   // Paired samples from patient_correlation_samples
    case unknown
}

// MARK: - Clinical Sample Read Model

/// Reading from patient_clinical_samples table (for biomarkers/lab results)
/// Note: Uses clean clinical_type names WITHOUT 'biomarker_' prefix
struct ClinicalSampleRead: Codable, Identifiable {
    let id: UUID
    let patientId: UUID
    let clinicalType: String  // e.g., "hdl" not "biomarker_hdl"
    let value: Double
    let unit: String
    let sampleTime: Date
    let source: String?
    let labName: String?
    let labReferenceRangeLow: Double?
    let labReferenceRangeHigh: Double?
    let collectionMethod: String?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case clinicalType = "clinical_type"
        case value
        case unit
        case sampleTime = "sample_time"
        case source
        case labName = "lab_name"
        case labReferenceRangeLow = "lab_reference_range_low"
        case labReferenceRangeHigh = "lab_reference_range_high"
        case collectionMethod = "collection_method"
    }
}

/// Type alias for backwards compatibility with existing biomarker code
typealias BiomarkerSample = ClinicalSampleRead

// MARK: - Correlation Sample Read Model

/// Reading from patient_correlation_samples table (for blood pressure, body comp, etc.)
struct CorrelationSampleRead: Codable, Identifiable {
    let id: UUID
    let patientId: UUID
    let correlationType: String
    let components: [String: AnyJSON]  // e.g., {"systolic": 120, "diastolic": 80}
    let sampleTime: Date
    let source: String?
    let userTimezone: String?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case correlationType = "correlation_type"
        case components
        case sampleTime = "sample_time"
        case source
        case userTimezone = "user_timezone"
    }

    /// Extract systolic BP value from components
    var systolic: Double? {
        switch components["systolic"] {
        case .double(let v): return v
        case .integer(let v): return Double(v)
        default: return nil
        }
    }

    /// Extract diastolic BP value from components
    var diastolic: Double? {
        switch components["diastolic"] {
        case .double(let v): return v
        case .integer(let v): return Double(v)
        default: return nil
        }
    }

    /// Extract pulse value from components
    var pulse: Double? {
        switch components["pulse"] {
        case .double(let v): return v
        case .integer(let v): return Double(v)
        default: return nil
        }
    }
}

// MARK: - Range Models (from sample_scoring_ranges)

/// Range detail from sample_scoring_ranges table with patient stratification
/// Used for both biomarkers (clinical_type) and biometrics (quantity_type)
struct ScoringRange: Codable, Identifiable {
    let id: UUID
    let clinicalType: String?   // For biomarkers (e.g., "hdl")
    let quantityType: String?   // For biometrics/tracked (e.g., "steps")
    let rangeName: String
    let rangeNameBackend: String?
    let rangeLow: Double?
    let rangeHigh: Double?
    let frontendDisplay: String?
    let gender: String?
    let directionality: String?
    let ageLow: Double?
    let ageHigh: Double?
    let menopausalStatus: String?
    let cycleStage: String?
    let uniqueCondition: String?
    let rangeScore: Double?  // Score associated with this range

    enum CodingKeys: String, CodingKey {
        case id
        case clinicalType = "clinical_type"
        case quantityType = "quantity_type"
        case rangeName = "range_name"
        case rangeNameBackend = "range_name_backend"
        case rangeLow = "range_low"
        case rangeHigh = "range_high"
        case frontendDisplay = "frontend_display"
        case gender
        case directionality
        case ageLow = "age_low"
        case ageHigh = "age_high"
        case menopausalStatus = "menopausal_status"
        case cycleStage = "cycle_stage"
        case uniqueCondition = "unique_condition"
        case rangeScore = "range_score"
    }

    var color: Color {
        switch rangeName.uppercased() {
        case "OPTIMAL":
            return .green
        case "IN RANGE", "IN-RANGE":
            return .yellow
        default:
            return .red
        }
    }
}

/// Type alias for backwards compatibility
typealias BiomarkerRange = ScoringRange

// MARK: - Patient Context for Range Filtering

/// Patient characteristics used for range stratification
struct BiomarkerPatientContext {
    let gender: String?
    let age: Int?
    let menopausalStatus: String?
    let cycleStage: String?
    let isAthlete: Bool

    init(
        gender: String? = nil,
        age: Int? = nil,
        menopausalStatus: String? = nil,
        cycleStage: String? = nil,
        isAthlete: Bool = false
    ) {
        self.gender = gender
        self.age = age
        self.menopausalStatus = menopausalStatus
        self.cycleStage = cycleStage
        self.isAthlete = isAthlete
    }

    /// Filter ranges based on patient context
    func filterRanges(_ ranges: [BiomarkerRange]) -> [BiomarkerRange] {
        ranges.filter { range in
            // 1. Gender filter
            if let rangeGender = range.gender?.lowercased(), rangeGender != "all" {
                guard let patientGender = gender?.lowercased(),
                      rangeGender == patientGender else {
                    return false
                }
            }

            // 2. Age filter
            if let patientAge = age {
                let ageLow = range.ageLow ?? 0
                let ageHigh = range.ageHigh ?? 150
                if Double(patientAge) < ageLow || Double(patientAge) > ageHigh {
                    return false
                }
            }

            // 3. Menopausal status filter
            if let rangeMenopausal = range.menopausalStatus?.lowercased(), !rangeMenopausal.isEmpty {
                guard let patientMenopausal = menopausalStatus?.lowercased(),
                      rangeMenopausal == patientMenopausal else {
                    return false
                }
            }

            // 4. Athlete status filter (unique_condition = "athlete")
            if let condition = range.uniqueCondition?.lowercased(), !condition.isEmpty {
                if condition == "athlete" && !isAthlete {
                    return false
                } else if condition != "athlete" {
                    return false  // Unknown condition - skip
                }
            } else {
                // No unique_condition - skip if patient IS an athlete and athlete ranges exist
                if isAthlete {
                    let hasAthleteRange = ranges.contains { r in
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
    }
}

// MARK: - UI Display Model

/// Complete biomarker data for display (combines sample + ranges + base info)
struct BiomarkerDisplayData: Identifiable {
    let id: UUID
    let cardId: String
    let viewId: String?  // For loading education sections from biomarkers_education_sections
    let name: String
    let value: Double
    let formattedValue: String
    let unit: String
    let unitDisplay: String
    let lastUpdated: Date
    let status: BiomarkerStatus
    let rangeName: String
    let ranges: [BiomarkerRange]
    let directionality: String
    let category: String?
    let categoryId: String
    let aboutWhy: String?
    let aboutOptimalTarget: String?
    let aboutQuickTips: String?
    let historicalValues: [BiomarkerSample]

    init(
        cardId: String,
        viewId: String? = nil,
        name: String,
        value: Double,
        formattedValue: String,
        unit: String,
        unitDisplay: String,
        lastUpdated: Date,
        ranges: [BiomarkerRange],
        category: String?,
        categoryId: String,
        aboutWhy: String? = nil,
        aboutOptimalTarget: String? = nil,
        aboutQuickTips: String? = nil,
        historicalValues: [BiomarkerSample] = []
    ) {
        self.id = UUID()
        self.cardId = cardId
        self.viewId = viewId
        self.name = name
        self.value = value
        self.formattedValue = formattedValue
        self.unit = unit
        self.unitDisplay = unitDisplay
        self.lastUpdated = lastUpdated
        self.ranges = ranges
        self.category = category
        self.categoryId = categoryId
        self.aboutWhy = aboutWhy
        self.aboutOptimalTarget = aboutOptimalTarget
        self.aboutQuickTips = aboutQuickTips
        self.historicalValues = historicalValues

        // Determine status and range name
        self.directionality = ranges.first?.directionality ?? "optimal_range"

        var foundStatus: BiomarkerStatus = .unknown
        var foundRangeName = "Unknown"

        for range in ranges.sorted(by: { ($0.rangeLow ?? 0) < ($1.rangeLow ?? 0) }) {
            let low = range.rangeLow ?? Double.leastNormalMagnitude
            let high = range.rangeHigh ?? Double.greatestFiniteMagnitude

            if value >= low && value < high {
                foundRangeName = range.rangeName
                foundStatus = BiomarkerStatus.from(rangeName: range.rangeName)
                break
            }
        }

        self.status = foundStatus
        self.rangeName = foundRangeName
    }

    /// Range segments for the visual indicator
    var rangeSegments: [RangeSegment] {
        ranges.sorted { ($0.rangeLow ?? 0) < ($1.rangeLow ?? 0) }.map { range in
            RangeSegment(
                rangeName: range.rangeName,
                rangeBucket: range.rangeName,
                rangeLow: range.rangeLow ?? 0,
                rangeHigh: range.rangeHigh ?? Double.greatestFiniteMagnitude,
                isArtificialLow: range.rangeLow == nil,
                isArtificialHigh: range.rangeHigh == nil,
                isPatientSegment: rangeName == range.rangeName
            )
        }
    }

    /// Trend data for sparkline
    var trendData: [Double] {
        historicalValues.prefix(6).reversed().map { $0.value }
    }

    /// The clinical_type for patient_clinical_samples queries (derived from historical values)
    var sampleClinicalType: String? {
        historicalValues.first?.clinicalType
    }
}

// MARK: - Status Enum

enum BiomarkerStatus: String {
    case optimal = "Optimal"
    case inRange = "In-Range"
    case outOfRange = "Out-of-Range"
    case unknown = "Unknown"

    var color: Color {
        switch self {
        case .optimal: return .green
        case .inRange: return .yellow
        case .outOfRange: return .red
        case .unknown: return .secondary
        }
    }

    var priority: Int {
        switch self {
        case .outOfRange: return 0
        case .inRange: return 1
        case .optimal: return 2
        case .unknown: return 3
        }
    }

    static func from(rangeName: String) -> BiomarkerStatus {
        switch rangeName.uppercased() {
        case "OPTIMAL": return .optimal
        case "IN RANGE", "IN-RANGE": return .inRange
        case "OUT OF RANGE", "OUT-OF-RANGE": return .outOfRange
        default: return .unknown
        }
    }
}

// MARK: - Unit Formatting

extension BiomarkerDisplayData {
    /// Maps raw unit strings from database to human-readable display symbols
    static let unitDisplayMap: [String: String] = [
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
        "milli_international_units_per_liter": "mIU/L",
        "billion_per_liter": "B/L"
    ]

    /// Convert raw unit string to human-readable display format
    static func formatUnit(_ rawUnit: String?) -> String {
        guard let unit = rawUnit?.lowercased() else { return "" }
        return unitDisplayMap[unit] ?? rawUnit ?? ""
    }

    /// Format numeric value based on format string
    static func formatValue(_ value: Double, format: String?) -> String {
        guard let format = format?.lowercased() else {
            return String(format: "%.1f", value)
        }

        if format.contains("integer") {
            return String(format: "%.0f", value)
        } else if format.contains("2 decimal") {
            return String(format: "%.2f", value)
        } else if format.contains("3 decimal") {
            return String(format: "%.3f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}
