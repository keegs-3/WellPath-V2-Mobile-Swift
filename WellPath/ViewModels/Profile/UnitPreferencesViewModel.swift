//
//  UnitPreferencesViewModel.swift
//  WellPath
//
//  ViewModel for managing user unit display preferences
//

import Foundation
import Supabase

// MARK: - Unit Types

enum WeightDisplayUnit: String, CaseIterable, Identifiable {
    case kg = "kilogram"
    case lb = "pound"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .kg: return "Kilograms (kg)"
        case .lb: return "Pounds (lb)"
        }
    }

    /// For backwards compatibility with legacy DB values
    static func fromLegacy(_ rawValue: String) -> WeightDisplayUnit {
        switch rawValue {
        case "kg": return .kg
        case "lb": return .lb
        default: return WeightDisplayUnit(rawValue: rawValue) ?? .kg
        }
    }
}

enum HeightDisplayUnit2: String, CaseIterable, Identifiable {
    case cm = "centimeter"
    case ftIn = "feet_inches"

    var id: String { rawValue }

    /// Short label for segmented pickers
    var shortLabel: String {
        switch self {
        case .cm: return "cm"
        case .ftIn: return "ft/in"
        }
    }

    /// Full display name for settings/lists
    var displayName: String {
        switch self {
        case .cm: return "Centimeters (cm)"
        case .ftIn: return "Feet & Inches (ft/in)"
        }
    }

    /// For backwards compatibility with legacy DB values
    static func fromLegacy(_ rawValue: String) -> HeightDisplayUnit2 {
        switch rawValue {
        case "cm": return .cm
        case "ft_in": return .ftIn
        default: return HeightDisplayUnit2(rawValue: rawValue) ?? .cm
        }
    }
}

enum DistanceDisplayUnit: String, CaseIterable, Identifiable {
    case km = "kilometer"
    case mi = "mile"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .km: return "Kilometers (km)"
        case .mi: return "Miles (mi)"
        }
    }

    /// For backwards compatibility with legacy DB values
    static func fromLegacy(_ rawValue: String) -> DistanceDisplayUnit {
        switch rawValue {
        case "km": return .km
        case "mi": return .mi
        default: return DistanceDisplayUnit(rawValue: rawValue) ?? .km
        }
    }
}

enum TemperatureDisplayUnit: String, CaseIterable, Identifiable {
    case c = "degrees_celsius"
    case f = "degrees_fahrenheit"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .c: return "Celsius (°C)"
        case .f: return "Fahrenheit (°F)"
        }
    }

    /// For backwards compatibility with legacy DB values
    static func fromLegacy(_ rawValue: String) -> TemperatureDisplayUnit {
        switch rawValue {
        case "c": return .c
        case "f": return .f
        default: return TemperatureDisplayUnit(rawValue: rawValue) ?? .c
        }
    }
}

enum LiquidDisplayUnit: String, CaseIterable, Identifiable {
    case fluidOunce = "fluid_ounce"
    case milliliter = "milliliter"
    case cup = "cup"
    case glass = "glass"
    case liter = "liter"
    case gallon = "gallon_us"

    var id: String { rawValue }

    /// Short label for chart display
    var shortLabel: String {
        switch self {
        case .fluidOunce: return "fl oz"
        case .milliliter: return "mL"
        case .cup: return "cups"
        case .glass: return "glasses"
        case .liter: return "L"
        case .gallon: return "gal"
        }
    }

    /// Full display name for settings/lists
    var displayName: String {
        switch self {
        case .fluidOunce: return "Fluid Ounces (fl oz)"
        case .milliliter: return "Milliliters (mL)"
        case .cup: return "Cups"
        case .glass: return "Glasses"
        case .liter: return "Liters (L)"
        case .gallon: return "Gallons (gal)"
        }
    }

    /// Conversion factor from mL (canonical unit) to this unit
    /// Usage: displayValue = mlValue / mlPerUnit
    var mlPerUnit: Double {
        switch self {
        case .milliliter: return 1.0
        case .fluidOunce: return 29.5735
        case .cup: return 236.588      // 1 US cup = 236.588 mL
        case .glass: return 236.588    // 1 glass = 8 fl oz = 236.588 mL
        case .liter: return 1000.0
        case .gallon: return 3785.41   // 1 US gallon = 3785.41 mL
        }
    }

    /// For backwards compatibility with legacy DB values
    static func fromLegacy(_ rawValue: String) -> LiquidDisplayUnit {
        switch rawValue {
        case "ml": return .milliliter
        case "oz", "fl_oz": return .fluidOunce
        case "cups": return .cup
        case "glasses": return .glass
        case "L": return .liter
        case "gal": return .gallon
        default: return LiquidDisplayUnit(rawValue: rawValue) ?? .milliliter
        }
    }

    /// Create from short label (e.g., "mL", "cups", "fl oz")
    static func fromShortLabel(_ label: String) -> LiquidDisplayUnit? {
        allCases.first { $0.shortLabel == label }
    }
}

// MARK: - ViewModel

@MainActor
class UnitPreferencesViewModel: ObservableObject {
    @Published var weightUnit: WeightDisplayUnit = .kg
    @Published var heightUnit: HeightDisplayUnit2 = .cm
    @Published var distanceUnit: DistanceDisplayUnit = .km
    @Published var temperatureUnit: TemperatureDisplayUnit = .c
    @Published var liquidUnit: LiquidDisplayUnit = .milliliter

    @Published var isLoading = false
    @Published var isSaving = false
    @Published var error: String?
    @Published var saveSuccess = false

    private let supabase = SupabaseManager.shared.client
    private var patientId: UUID?

    // MARK: - Load Preferences

    func loadPreferences() async {
        isLoading = true
        error = nil

        do {
            let userId = try await supabase.auth.session.user.id
            patientId = userId

            struct UnitPrefs: Codable {
                let weightUnit: String?
                let heightUnit: String?
                let distanceUnit: String?
                let temperatureUnit: String?
                let liquidUnit: String?

                enum CodingKeys: String, CodingKey {
                    case weightUnit = "weight_unit"
                    case heightUnit = "height_unit"
                    case distanceUnit = "distance_unit"
                    case temperatureUnit = "temperature_unit"
                    case liquidUnit = "liquid_unit"
                }
            }

            let results: [UnitPrefs] = try await supabase
                .from("patient_unit_preferences")
                .select()
                .eq("patient_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            if let prefs = results.first {
                if let w = prefs.weightUnit {
                    weightUnit = WeightDisplayUnit.fromLegacy(w)
                }
                if let h = prefs.heightUnit {
                    heightUnit = HeightDisplayUnit2.fromLegacy(h)
                }
                if let d = prefs.distanceUnit {
                    distanceUnit = DistanceDisplayUnit.fromLegacy(d)
                }
                if let t = prefs.temperatureUnit {
                    temperatureUnit = TemperatureDisplayUnit.fromLegacy(t)
                }
                if let l = prefs.liquidUnit {
                    liquidUnit = LiquidDisplayUnit.fromLegacy(l)
                }
                print("✅ Loaded unit preferences")
            } else {
                // No preferences yet, create defaults
                await createDefaultPreferences(patientId: userId)
            }

        } catch {
            self.error = "Failed to load preferences: \(error.localizedDescription)"
            print("❌ Error loading unit preferences: \(error)")
        }

        isLoading = false
    }

    private func createDefaultPreferences(patientId: UUID) async {
        do {
            struct NewPrefs: Encodable {
                let patientId: String

                enum CodingKeys: String, CodingKey {
                    case patientId = "patient_id"
                }
            }

            try await supabase
                .from("patient_unit_preferences")
                .insert(NewPrefs(patientId: patientId.uuidString))
                .execute()

            print("✅ Created default unit preferences")
        } catch {
            print("⚠️ Could not create default preferences: \(error)")
        }
    }

    // MARK: - Save Preferences

    func savePreferences() async -> Bool {
        guard let patientId = patientId else {
            error = "No patient ID"
            return false
        }

        isSaving = true
        error = nil
        saveSuccess = false

        do {
            struct PrefsUpdate: Encodable {
                let weightUnit: String
                let heightUnit: String
                let distanceUnit: String
                let temperatureUnit: String
                let liquidUnit: String

                enum CodingKeys: String, CodingKey {
                    case weightUnit = "weight_unit"
                    case heightUnit = "height_unit"
                    case distanceUnit = "distance_unit"
                    case temperatureUnit = "temperature_unit"
                    case liquidUnit = "liquid_unit"
                }
            }

            let update = PrefsUpdate(
                weightUnit: weightUnit.rawValue,
                heightUnit: heightUnit.rawValue,
                distanceUnit: distanceUnit.rawValue,
                temperatureUnit: temperatureUnit.rawValue,
                liquidUnit: liquidUnit.rawValue
            )

            try await supabase
                .from("patient_unit_preferences")
                .update(update)
                .eq("patient_id", value: patientId.uuidString)
                .execute()

            print("✅ Unit preferences saved")
            saveSuccess = true
            isSaving = false
            return true

        } catch {
            self.error = "Failed to save: \(error.localizedDescription)"
            print("❌ Error saving unit preferences: \(error)")
            isSaving = false
            return false
        }
    }
}
