//
//  UnitConversionService.swift
//  WellPath
//
//  Service for looking up unit conversions from the database
//  Uses unit_conversions table with from_unit_id, to_unit_id, conversion_multiplier
//

import Foundation

/// Cached unit conversion data from database
private struct UnitConversionRecord: Codable {
    let calcId: String
    let fromUnitId: String
    let toUnitId: String
    let conversionMultiplier: Double

    enum CodingKeys: String, CodingKey {
        case calcId = "calc_id"
        case fromUnitId = "from_unit_id"
        case toUnitId = "to_unit_id"
        case conversionMultiplier = "conversion_multiplier"
    }
}

/// Canonical unit definition for a quantity type
private struct QuantityTypeUnit: Codable {
    let quantityType: String
    let canonicalUnit: String

    enum CodingKeys: String, CodingKey {
        case quantityType = "quantity_type"
        case canonicalUnit = "canonical_unit"
    }
}

@MainActor
class UnitConversionService: ObservableObject {
    static let shared = UnitConversionService()

    private let supabase = SupabaseManager.shared.client

    /// Cached conversions: "from_unit:to_unit" -> multiplier
    private var conversionCache: [String: Double] = [:]

    /// Cached canonical units: "quantity_type" -> unit_id
    private var canonicalUnitCache: [String: String] = [:]

    /// Whether initial load has completed
    private var isLoaded = false

    private init() {}

    // MARK: - Public API

    /// Load all conversions into cache (call once at app startup or first use)
    func loadConversions() async {
        guard !isLoaded else { return }

        do {
            // Load unit conversions
            let conversions: [UnitConversionRecord] = try await supabase
                .from("unit_conversions")
                .select("calc_id, from_unit_id, to_unit_id, conversion_multiplier")
                .execute()
                .value

            for conversion in conversions {
                let key = "\(conversion.fromUnitId):\(conversion.toUnitId)"
                conversionCache[key] = conversion.conversionMultiplier
            }

            print("📐 Loaded \(conversions.count) unit conversions")

            // Load canonical units
            let quantityTypes: [QuantityTypeUnit] = try await supabase
                .from("sample_quantity_types")
                .select("quantity_type, canonical_unit")
                .execute()
                .value

            for qt in quantityTypes {
                canonicalUnitCache[qt.quantityType] = qt.canonicalUnit
            }

            print("📐 Loaded \(quantityTypes.count) canonical unit definitions")

            isLoaded = true

        } catch {
            print("❌ Error loading unit conversions: \(error)")
        }
    }

    /// Get conversion multiplier between two units
    /// Returns nil if conversion not found
    func getMultiplier(from fromUnit: String, to toUnit: String) -> Double? {
        // Same unit = no conversion
        if fromUnit == toUnit { return 1.0 }

        let key = "\(fromUnit):\(toUnit)"
        return conversionCache[key]
    }

    /// Convert a value from one unit to another
    /// Returns nil if conversion not found
    func convert(_ value: Double, from fromUnit: String, to toUnit: String) -> Double? {
        guard let multiplier = getMultiplier(from: fromUnit, to: toUnit) else {
            return nil
        }
        return value * multiplier
    }

    /// Get the canonical (storage) unit for a quantity type
    func getCanonicalUnit(for quantityType: String) -> String? {
        return canonicalUnitCache[quantityType]
    }

    /// Convert a value to the canonical unit for storage
    func convertToCanonical(_ value: Double, fromUnit: String, quantityType: String) -> Double? {
        guard let canonicalUnit = getCanonicalUnit(for: quantityType) else {
            print("⚠️ No canonical unit defined for \(quantityType)")
            return nil
        }

        return convert(value, from: fromUnit, to: canonicalUnit)
    }

    /// Convert a value from canonical unit for display
    func convertFromCanonical(_ value: Double, toUnit: String, quantityType: String) -> Double? {
        guard let canonicalUnit = getCanonicalUnit(for: quantityType) else {
            print("⚠️ No canonical unit defined for \(quantityType)")
            return nil
        }

        return convert(value, from: canonicalUnit, to: toUnit)
    }

    // MARK: - Common Conversions (convenience methods)

    /// Convert kilograms to pounds
    func kgToLb(_ kg: Double) -> Double {
        return convert(kg, from: "kilogram", to: "pound") ?? (kg * 2.2046)
    }

    /// Convert pounds to kilograms
    func lbToKg(_ lb: Double) -> Double {
        return convert(lb, from: "pound", to: "kilogram") ?? (lb * 0.453592)
    }

    /// Convert g/kg ratio to g/lb ratio
    func gPerKgToGPerLb(_ gPerKg: Double) -> Double {
        // g/kg to g/lb: multiply by (kg/lb) = 0.453592
        // Because: if you need X grams per kg, you need X * 0.453592 grams per lb
        return gPerKg * 0.453592
    }

    /// Convert g/lb ratio to g/kg ratio
    func gPerLbToGPerKg(_ gPerLb: Double) -> Double {
        // g/lb to g/kg: multiply by (lb/kg) = 2.2046
        return gPerLb * 2.2046
    }
}
