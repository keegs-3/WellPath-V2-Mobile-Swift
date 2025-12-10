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

    private let supabase = SupabaseManager.shared.client
    private let unitService = UnitConversionService.shared

    // Metrics that use weight units
    private let weightMetrics: Set<String> = ["DISP_BODYWEIGHT"]

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

            // Query sample_quantity_type from display_views_dependencies (primary dependency)
            struct DependencyMapping: Codable {
                let sampleQuantityType: String?

                enum CodingKeys: String, CodingKey {
                    case sampleQuantityType = "sample_quantity_type"
                }
            }

            let dependencies: [DependencyMapping] = try await supabase
                .from("display_views_dependencies")
                .select("sample_quantity_type")
                .eq("view_id", value: metricId)
                .eq("is_primary", value: true)
                .limit(1)
                .execute()
                .value

            guard let quantityType = dependencies.first?.sampleQuantityType else {
                print("⚠️ No sample_quantity_type dependency for \(metricId)")
                isLoading = false
                return
            }

            let patientId = try await supabase.auth.session.user.id

            struct SampleReading: Codable {
                let quantityValue: Double
                let quantityUnit: String?
                let startTime: Date

                enum CodingKeys: String, CodingKey {
                    case quantityValue = "quantity_value"
                    case quantityUnit = "quantity_unit"
                    case startTime = "start_time"
                }
            }

            // Query patient_quantity_samples for the latest value
            let results: [SampleReading] = try await supabase
                .from("patient_quantity_samples")
                .select("quantity_value, quantity_unit, start_time")
                .eq("patient_id", value: patientId)
                .eq("quantity_type", value: quantityType)
                .order("start_time", ascending: false)
                .limit(1)
                .execute()
                .value

            if let reading = results.first {
                // Store raw canonical value
                rawValue = reading.quantityValue
                rawUnit = reading.quantityUnit

                // Store user's preferred units
                preferredWeightUnit = unitService.preferredWeightUnit
                preferredLengthUnit = unitService.preferredHeightUnit

                // Convert to user's preferred unit for default display
                if weightMetrics.contains(metricId) {
                    let converted = unitService.convertWeightToPreferred(value: reading.quantityValue, fromUnit: reading.quantityUnit)
                    currentValue = converted.value
                    unit = converted.unit
                } else if lengthMetrics.contains(metricId) {
                    let converted = unitService.convertLengthToPreferred(value: reading.quantityValue, fromUnit: reading.quantityUnit)
                    currentValue = converted.value
                    unit = converted.unit
                } else {
                    currentValue = reading.quantityValue
                    // Look up symbol from units_base, fallback to static map
                    if let symbol = await lookupUnitSymbol(reading.quantityUnit) {
                        unit = symbol
                    } else {
                        unit = formatUnitForDisplay(reading.quantityUnit)
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
