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
    case kg = "kg"
    case lb = "lb"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .kg: return "Kilograms (kg)"
        case .lb: return "Pounds (lb)"
        }
    }
}

enum HeightDisplayUnit2: String, CaseIterable, Identifiable {
    case cm = "cm"
    case ftIn = "ft_in"

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
}

enum DistanceDisplayUnit: String, CaseIterable, Identifiable {
    case km = "km"
    case mi = "mi"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .km: return "Kilometers (km)"
        case .mi: return "Miles (mi)"
        }
    }
}

enum TemperatureDisplayUnit: String, CaseIterable, Identifiable {
    case c = "c"
    case f = "f"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .c: return "Celsius (°C)"
        case .f: return "Fahrenheit (°F)"
        }
    }
}

enum LiquidDisplayUnit: String, CaseIterable, Identifiable {
    case fluidOunce = "fl_oz"
    case milliliter = "ml"
    case cup = "cups"
    case glass = "glasses"
    case liter = "L"
    case gallon = "gal"

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

    /// For backwards compatibility with existing DB values
    static func fromLegacy(_ rawValue: String) -> LiquidDisplayUnit {
        switch rawValue {
        case "ml": return .milliliter
        case "oz": return .fluidOunce
        default: return LiquidDisplayUnit(rawValue: rawValue) ?? .milliliter
        }
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
                if let w = prefs.weightUnit, let unit = WeightDisplayUnit(rawValue: w) {
                    weightUnit = unit
                }
                if let h = prefs.heightUnit, let unit = HeightDisplayUnit2(rawValue: h) {
                    heightUnit = unit
                }
                if let d = prefs.distanceUnit, let unit = DistanceDisplayUnit(rawValue: d) {
                    distanceUnit = unit
                }
                if let t = prefs.temperatureUnit, let unit = TemperatureDisplayUnit(rawValue: t) {
                    temperatureUnit = unit
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
