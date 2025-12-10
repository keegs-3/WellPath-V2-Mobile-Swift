//
//  SimpleBiometricDataViewModel.swift
//  WellPath
//
//  Reusable view model for simple biometric data management
//  Works with patient_quantity_samples table via quantity_type
//

import Foundation
import SwiftUI
import Supabase

// MARK: - View Model (patient_samples based)

@MainActor
class SimpleBiometricDataViewModel: ObservableObject {
    @Published var entriesByDate: [Date: [SimpleBiometricEntry]] = [:]
    @Published var isLoading = false
    @Published var displayUnit: String  // The unit to display (user's preferred or default)

    private let supabase = SupabaseManager.shared.client
    let quantityType: String
    let displayName: String
    let defaultUnit: String

    /// Initialize with a quantity_type from patient_samples
    /// - Parameters:
    ///   - quantityType: The quantity_type value (e.g., "body_fat_percent", "grip_strength")
    ///   - displayName: Human-readable name for logging
    ///   - unit: Display unit string
    init(quantityType: String, displayName: String, unit: String) {
        self.quantityType = quantityType
        self.displayName = displayName
        self.defaultUnit = unit
        self.displayUnit = unit
    }

    /// Legacy initializer for backwards compatibility - maps biometric_name to quantity_type
    convenience init(biometricName: String, unit: String) {
        let quantityType = SimpleBiometricDataViewModel.mapBiometricNameToQuantityType(biometricName)
        self.init(quantityType: quantityType, displayName: biometricName, unit: unit)
    }

    var sortedDates: [Date] {
        entriesByDate.keys.sorted(by: >)
    }

    func loadData() async {
        isLoading = true

        do {
            let patientId = try await supabase.auth.session.user.id

            struct PatientSampleRow: Codable {
                let id: UUID
                let quantityValue: Double?
                let quantityUnit: String?
                let startTime: Date
                let source: String
                let createdAt: Date?

                enum CodingKeys: String, CodingKey {
                    case id
                    case quantityValue = "quantity_value"
                    case quantityUnit = "quantity_unit"
                    case startTime = "start_time"
                    case source
                    case createdAt = "created_at"
                }
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)

                let iso8601Formatter = ISO8601DateFormatter()
                iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = iso8601Formatter.date(from: dateString) {
                    return date
                }

                iso8601Formatter.formatOptions = [.withInternetDateTime]
                if let date = iso8601Formatter.date(from: dateString) {
                    return date
                }

                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
            }

            let data = try await supabase
                .from("patient_quantity_samples")
                .select()
                .eq("patient_id", value: patientId)
                .eq("quantity_type", value: quantityType)
                .order("start_time", ascending: false)
                .execute()
                .data

            let samples = try decoder.decode([PatientSampleRow].self, from: data)

            // Data management shows RAW values from patient_quantity_samples without conversion
            // This is intentional - patient_quantity_samples stores values in the units they were entered
            // Aggregations handle conversion to canonical units (cm, kg) for standardization
            var entries: [SimpleBiometricEntry] = []
            for sample in samples {
                guard let value = sample.quantityValue else { continue }

                // Use the raw stored unit from patient_quantity_samples - no conversion
                let storedUnit = sample.quantityUnit ?? defaultUnit

                let entry = SimpleBiometricEntry(
                    id: sample.id,
                    value: value,  // Raw value as entered
                    unit: storedUnit,  // Raw unit as stored
                    recordedAt: sample.startTime,
                    source: sample.source,
                    createdAt: sample.createdAt ?? sample.startTime
                )
                entries.append(entry)
            }

            // Update displayUnit based on what's actually in the data (for header display)
            if let firstEntry = entries.first {
                displayUnit = firstEntry.unit
            }

            let calendar = Calendar.current
            entriesByDate = Dictionary(grouping: entries) { entry in
                calendar.startOfDay(for: entry.recordedAt)
            }

            print("Loaded \(entries.count) \(displayName) entries in \(displayUnit)")

        } catch {
            print("Error loading \(displayName) data: \(error)")
        }

        isLoading = false
    }

    func deleteEntries(_ entries: [SimpleBiometricEntry]) async {
        do {
            let patientId = try await supabase.auth.session.user.id

            for entry in entries {
                try await supabase
                    .from("patient_quantity_samples")
                    .delete()
                    .eq("id", value: entry.id)
                    .eq("patient_id", value: patientId)
                    .execute()

                print("Deleted \(displayName) sample: \(entry.id)")
            }

            await loadData()

        } catch {
            print("Error deleting entries: \(error)")
        }
    }

    /// Maps legacy biometric_name values to patient_quantity_samples quantity_type
    private static func mapBiometricNameToQuantityType(_ biometricName: String) -> String {
        switch biometricName {
        case "BMI", "Body Mass Index":
            return "bmi"  // Calculated field - may not exist in patient_quantity_samples
        case "Bodyfat (%)", "Body Fat", "Body Fat %", "body_fat_percent":
            return QuantityTypes.bodyFatPercent
        case "Visceral Fat", "Visceral Fat %", "visceral_fat":
            return QuantityTypes.visceralFatPercent
        case "Grip Strength", "grip_strength":
            return QuantityTypes.gripStrength
        case "HRV", "Heart Rate Variability":
            return QuantityTypes.hrv
        case "Resting Heart Rate", "resting_heart_rate":
            return QuantityTypes.restingHeartRate
        case "VO2 Max", "vo2_max":
            return QuantityTypes.vo2Max
        case "Waist Circumference", "waist_circumference":
            return QuantityTypes.waistCircumference
        case "Hip Circumference", "hip_circumference":
            return QuantityTypes.hipCircumference
        case "Waist-to-Hip Ratio", "waist_hip_ratio":
            return "waist_hip_ratio"  // Calculated field
        case "Height", "height":
            return QuantityTypes.height
        case "Bodyweight", "Weight", "Body Weight", "bodyweight":
            return QuantityTypes.weight
        case "Appendicular Skeletal Muscle Index", "ASMI", "asmi":
            return QuantityTypes.asmi
        case "Blood Pressure (Systolic)", "Systolic Blood Pressure", "systolic_bp":
            return QuantityTypes.bloodPressureSystolic
        case "Blood Pressure (Diastolic)", "Diastolic Blood Pressure", "diastolic_bp":
            return QuantityTypes.bloodPressureDiastolic
        default:
            // Fallback: assume biometricName is already a quantity_type
            return biometricName.lowercased().replacingOccurrences(of: " ", with: "_")
        }
    }
}

// MARK: - Model

struct SimpleBiometricEntry: Identifiable {
    let id: UUID
    let value: Double
    let unit: String
    let recordedAt: Date
    let source: String
    let createdAt: Date

    var canDelete: Bool {
        source == "wellpath" || source == "wellpath_input" || source == "healthkit"
    }
}

// MARK: - Reusable Entry Row

struct SimpleBiometricEntryRow: View {
    let entry: SimpleBiometricEntry
    let unit: String  // Fallback unit if entry.unit is empty
    var formatDecimals: Int = 1

    /// Display unit - uses entry's stored unit if available, otherwise falls back to passed unit
    private var displayUnit: String {
        let entryUnit = entry.unit
        // Use entry unit if it's meaningful, otherwise fall back
        if entryUnit.isEmpty || entryUnit == unit {
            return formatUnit(unit)
        }
        return formatUnit(entryUnit)
    }

    /// Format unit for display (e.g., "pound" -> "lb", "kilogram" -> "kg")
    private func formatUnit(_ rawUnit: String) -> String {
        switch rawUnit.lowercased() {
        case "pound", "pounds", "lb", "lbs":
            return "lb"
        case "kilogram", "kilograms", "kg":
            return "kg"
        case "inch", "inches", "in":
            return "in"
        case "centimeter", "centimeters", "cm":
            return "cm"
        default:
            return rawUnit
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            sourceIcon

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatValue(entry.value))
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text(displayUnit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(formatTime(entry.recordedAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var sourceIcon: some View {
        Group {
            if entry.source == "healthkit" {
                Image(systemName: "heart.text.square.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.4, blue: 0.5), Color(red: 1.0, green: 0.2, blue: 0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 24, height: 24)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.95), Color(white: 0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 24, height: 24)

                    Image("black_green")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                }
                .frame(width: 24, height: 24)
            }
        }
    }

    private func formatValue(_ value: Double) -> String {
        String(format: "%.\(formatDecimals)f", value)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
