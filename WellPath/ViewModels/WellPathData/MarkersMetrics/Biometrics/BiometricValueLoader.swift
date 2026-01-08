//
//  BiometricValueLoader.swift
//  WellPath
//
//  Loads biometric values from patient_quantity_samples
//  Handles unit conversion based on user preferences
//

import Foundation
import Supabase

@MainActor
class BiometricValueLoader: ObservableObject {
    @Published var currentValue: Double?  // Converted to user preference
    @Published var rawValue: Double?       // Raw canonical value (kg, cm)
    @Published var rawUnit: String?        // Canonical unit from DB
    @Published var unit: String?           // Display unit (converted)
    @Published var status: String?
    @Published var lastUpdated: Date?
    @Published var isLoading = false
    @Published var preferredWeightUnit: WeightDisplayUnit = .lb
    @Published var preferredLengthUnit: HeightDisplayUnit2 = .ftIn
    @Published var icon: String?           // Icon from display_views.icon_name
    @Published var sparklinePoints: [SparklinePoint] = []  // Recent points for mini chart

    private let supabase = SupabaseManager.shared.client
    private let unitService = UnitConversionService.shared
    private let sparklinePointCount = 7  // Number of points for sparkline

    // Metrics that use weight units
    private let weightMetrics: Set<String> = ["DISP_BODYWEIGHT", "DISP_GRIP_STRENGTH"]

    // Metrics that use length units
    private let lengthMetrics: Set<String> = ["DISP_WAIST_CIRCUMFERENCE", "DISP_HIP_CIRCUMFERENCE"]

    /// Maps raw unit strings from database to human-readable display symbols
    private static let unitDisplayMap: [String: String] = [
        "percent": "%",
        "percentage": "%",
        "kilogram": "kg",
        "pound": "lb",
        "kilogram_per_square_meter": "kg/m²",
        "centimeter": "cm",
        "inch": "in",
        "millimeter_of_mercury": "mmHg",
        "millisecond": "ms",
        "beat_per_minute": "bpm",
        "beats_per_minute": "bpm",
        "milliliter_per_kilogram_per_minute": "mL/kg/min",
        "ml_per_kg_per_min": "mL/kg/min",
        "ratio": "",
        "index": "",
        "count": "",
        "level": ""
    ]

    /// Convert raw unit string to human-readable display format
    private func formatUnitForDisplay(_ rawUnit: String?) -> String {
        return Self.formatUnitForDisplay(rawUnit)
    }

    /// Static helper to convert raw unit string to human-readable display format
    static func formatUnitForDisplay(_ rawUnit: String?) -> String {
        guard let unit = rawUnit?.lowercased() else { return "" }
        return unitDisplayMap[unit] ?? rawUnit ?? ""
    }

    func loadValue(for metricId: String) async {
        isLoading = true

        // Load user preferences first
        await unitService.loadUserPreferences()

        do {
            // First, load icon from display_views (metricId could be view_id or card_id)
            struct ViewInfo: Codable {
                let iconName: String?

                enum CodingKeys: String, CodingKey {
                    case iconName = "icon_name"
                }
            }

            // Try direct view lookup first
            var viewInfos: [ViewInfo] = try await supabase
                .from("display_views")
                .select("icon_name")
                .eq("view_id", value: metricId)
                .limit(1)
                .execute()
                .value

            // If not found, try via card -> view relationship
            if viewInfos.isEmpty {
                struct CardViewInfo: Codable {
                    let displayViews: ViewInfo?

                    enum CodingKeys: String, CodingKey {
                        case displayViews = "display_views"
                    }
                }

                let cardInfos: [CardViewInfo] = try await supabase
                    .from("display_view_cards")
                    .select("display_views(icon_name)")
                    .eq("card_id", value: metricId)
                    .limit(1)
                    .execute()
                    .value

                if let viewInfo = cardInfos.first?.displayViews {
                    viewInfos = [viewInfo]
                }
            }

            icon = viewInfos.first?.iconName

            // Query dependency type from display_views_dependencies (primary dependency)
            // Can be sample_quantity_type OR sample_derived_type
            struct DependencyMapping: Codable {
                let sampleQuantityType: String?
                let sampleDerivedType: String?

                enum CodingKeys: String, CodingKey {
                    case sampleQuantityType = "sample_quantity_type"
                    case sampleDerivedType = "sample_derived_type"
                }
            }

            let dependencies: [DependencyMapping] = try await supabase
                .from("display_views_dependencies")
                .select("sample_quantity_type, sample_derived_type")
                .eq("view_id", value: metricId)
                .eq("is_primary", value: true)
                .limit(1)
                .execute()
                .value

            let quantityType = dependencies.first?.sampleQuantityType
            let derivedType = dependencies.first?.sampleDerivedType

            guard quantityType != nil || derivedType != nil else {
                print("⚠️ No sample_quantity_type or sample_derived_type dependency for \(metricId)")
                isLoading = false
                return
            }

            let patientId = try await supabase.auth.session.user.id

            struct SampleReading: Codable {
                let canonicalValue: Double
                let canonicalUnit: String?
                let startTime: Date

                enum CodingKeys: String, CodingKey {
                    case canonicalValue = "canonical_value"
                    case canonicalUnit = "canonical_unit"
                    case startTime = "start_time"
                }
            }

            // For derived types, we need a different model (patient_derived_samples has different columns)
            struct DerivedReading: Codable {
                let calculatedValue: Double?
                let calculationDate: Date

                enum CodingKeys: String, CodingKey {
                    case calculatedValue = "calculated_value"
                    case calculationDate = "calculation_date"
                }
            }

            var results: [SampleReading] = []

            // Query from the appropriate table based on dependency type
            if let derivedType = derivedType {
                // Query patient_derived_samples view for derived values (ASMI, BMI, ratios, etc.)
                let derivedResults: [DerivedReading] = try await supabase
                    .from("patient_derived_samples")
                    .select("calculated_value, calculation_date")
                    .eq("patient_id", value: patientId)
                    .eq("derived_type", value: derivedType)
                    .order("calculation_date", ascending: false)
                    .limit(sparklinePointCount)
                    .execute()
                    .value

                // Convert to SampleReading format for consistent handling
                results = derivedResults.compactMap { derived -> SampleReading? in
                    guard let value = derived.calculatedValue else { return nil }
                    return SampleReading(
                        canonicalValue: value,
                        canonicalUnit: nil, // Derived values may not have unit in view
                        startTime: derived.calculationDate
                    )
                }
            } else if let quantityType = quantityType {
                // Query patient_quantity_samples for raw values
                // Use canonical values - always in standard units (kg, cm) for consistent conversion
                results = try await supabase
                    .from("patient_quantity_samples")
                    .select("canonical_value, canonical_unit, start_time")
                    .eq("patient_id", value: patientId)
                    .eq("quantity_type", value: quantityType)
                    .order("start_time", ascending: false)
                    .limit(sparklinePointCount)
                    .execute()
                    .value
            }

            // Build sparkline points (reversed to show oldest first)
            let reversedResults = results.reversed()
            sparklinePoints = reversedResults.enumerated().map { index, reading in
                SparklinePoint(
                    date: reading.startTime,
                    value: reading.canonicalValue,
                    isLatest: index == reversedResults.count - 1
                )
            }

            if let reading = results.first {
                // Store raw canonical value (always in standard units like kg, cm)
                rawValue = reading.canonicalValue
                rawUnit = reading.canonicalUnit

                // Store user's preferred units
                preferredWeightUnit = unitService.preferredWeightUnit
                preferredLengthUnit = unitService.preferredHeightUnit

                // Convert canonical value to user's preferred unit for display
                if weightMetrics.contains(metricId) {
                    let converted = unitService.convertWeightToPreferred(value: reading.canonicalValue, fromUnit: reading.canonicalUnit)
                    currentValue = converted.value
                    unit = converted.unit
                } else if lengthMetrics.contains(metricId) {
                    let converted = unitService.convertLengthToPreferred(value: reading.canonicalValue, fromUnit: reading.canonicalUnit)
                    currentValue = converted.value
                    unit = converted.unit
                } else {
                    currentValue = reading.canonicalValue
                    // Look up symbol from units_base, fallback to static map
                    if let symbol = await lookupUnitSymbol(reading.canonicalUnit) {
                        unit = symbol
                    } else {
                        unit = formatUnitForDisplay(reading.canonicalUnit)
                    }
                }

                status = nil  // Status is computed from ranges, not stored
                lastUpdated = reading.startTime
            }

        } catch {
            print("❌ Error loading biometric value: \(error)")
        }

        isLoading = false
    }

    /// Look up ui_display from units_base for a given unit_id
    private func lookupUnitSymbol(_ unitId: String?) async -> String? {
        guard let unitId = unitId else { return nil }
        do {
            struct UnitDisplay: Codable {
                let uiDisplay: String?
                let symbol: String?

                enum CodingKeys: String, CodingKey {
                    case uiDisplay = "ui_display"
                    case symbol
                }
            }

            let results: [UnitDisplay] = try await supabase
                .from("units_base")
                .select("ui_display, symbol")
                .eq("unit_id", value: unitId)
                .limit(1)
                .execute()
                .value

            // Prefer ui_display, fallback to symbol
            return results.first?.uiDisplay ?? results.first?.symbol
        } catch {
            return nil
        }
    }
}
