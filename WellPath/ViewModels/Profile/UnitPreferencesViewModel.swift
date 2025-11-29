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
    case ml = "ml"
    case oz = "oz"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .ml: return "Milliliters (ml)"
        case .oz: return "Fluid Ounces (oz)"
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
    @Published var liquidUnit: LiquidDisplayUnit = .ml

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
                if let l = prefs.liquidUnit, let unit = LiquidDisplayUnit(rawValue: l) {
                    liquidUnit = unit
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
