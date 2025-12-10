//
//  BMIEntryView.swift
//  WellPath
//
//  Entry form for logging body weight to calculate BMI
//  BMI = weight(kg) / height(m)^2
//  Height is read from patient_characteristics (static value)
//

import SwiftUI
import Supabase

struct BMIEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDateTime = Date()
    @State private var weightValue: String = ""
    @State private var selectedUnit: WeightUnit = .pounds
    @State private var patientHeight: Double? // Height in cm from patient_characteristics
    @State private var isSaving = false
    @State private var isLoadingHeight = true
    @State private var errorMessage: String?

    private let supabase = SupabaseManager.shared.client

    enum WeightUnit: String, CaseIterable {
        case pounds = "lb"
        case kilograms = "kg"

        var displayName: String { rawValue }

        func toKg(_ value: Double) -> Double {
            switch self {
            case .pounds: return value / 2.2046
            case .kilograms: return value
            }
        }
    }

    // Calculated BMI based on entered weight and patient height
    private var calculatedBMI: Double? {
        guard let weight = Double(weightValue), weight > 0,
              let heightCm = patientHeight, heightCm > 0 else { return nil }
        let heightM = heightCm / 100.0
        let weightKg = selectedUnit.toKg(weight)
        return weightKg / (heightM * heightM)
    }

    private var bmiClassification: (String, Color)? {
        guard let bmi = calculatedBMI else { return nil }
        if bmi < 18.5 {
            return ("Underweight", .blue)
        } else if bmi < 25 {
            return ("Normal", .green)
        } else if bmi < 30 {
            return ("Overweight", .orange)
        } else {
            return ("Obese", .red)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with X button
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .disabled(isSaving)
                Spacer()
            }
            .padding()
            .background(Color(uiColor: .systemBackground))

            // Icon and Title
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: "figure.stand")
                        .font(.system(size: 32))
                        .foregroundColor(.cyan)
                }

                Text("BMI Entry")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Enter your weight to calculate BMI")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
            .padding(.bottom, 24)

            Form {
                Section {
                    DatePicker("Date", selection: $selectedDateTime, displayedComponents: [.date])
                    DatePicker("Time", selection: $selectedDateTime, displayedComponents: [.hourAndMinute])
                }

                // Height display (read-only from patient_characteristics)
                Section("Your Height") {
                    if isLoadingHeight {
                        HStack {
                            Text("Loading...")
                            Spacer()
                            ProgressView()
                        }
                    } else if let height = patientHeight {
                        HStack {
                            Text(formatHeight(height))
                                .foregroundColor(.primary)
                            Spacer()
                            Text("from your profile")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Height not set in profile")
                            .foregroundColor(.orange)
                    }
                }

                // Weight entry
                Section("Weight") {
                    HStack {
                        TextField("Weight", text: $weightValue)
                            .keyboardType(.decimalPad)

                        Picker("Unit", selection: $selectedUnit) {
                            ForEach(WeightUnit.allCases, id: \.self) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 100)
                    }
                }

                // BMI Preview
                if let bmi = calculatedBMI, let (classification, color) = bmiClassification {
                    Section("Calculated BMI") {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text(String(format: "%.1f", bmi))
                                        .font(.title)
                                        .fontWeight(.bold)
                                    Text("kg/m\u{00B2}")
                                        .foregroundColor(.secondary)
                                }
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 8, height: 8)
                                    Text(classification)
                                        .font(.subheadline)
                                        .foregroundColor(color)
                                }
                            }
                            Spacer()
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }

            // Save button
            Button(action: {
                Task { await saveEntry() }
            }) {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text("Save")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isValid ? Color.cyan : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
            .disabled(isSaving || !isValid)
        }
        .task {
            await loadPatientHeight()
        }
    }

    private var isValid: Bool {
        guard let weight = Double(weightValue), weight > 0 else { return false }
        return patientHeight != nil
    }

    private func formatHeight(_ cm: Double) -> String {
        let inches = cm / 2.54
        let feet = Int(inches / 12)
        let remainingInches = Int(inches.truncatingRemainder(dividingBy: 12))
        return "\(feet)' \(remainingInches)\" (\(Int(cm)) cm)"
    }

    private func loadPatientHeight() async {
        isLoadingHeight = true

        do {
            let userId = try await supabase.auth.session.user.id

            struct PatientCharacteristic: Codable {
                let valueNumeric: Double?

                enum CodingKeys: String, CodingKey {
                    case valueNumeric = "value_numeric"
                }
            }

            // Query patient_characteristics directly using the name
            // (characteristic_type_name references characteristic_types.name)
            let results: [PatientCharacteristic] = try await supabase
                .from("patient_characteristics")
                .select("value_numeric")
                .eq("patient_id", value: userId)
                .eq("characteristic_type_name", value: "height")
                .limit(1)
                .execute()
                .value

            await MainActor.run {
                patientHeight = results.first?.valueNumeric
                isLoadingHeight = false
            }

        } catch {
            print("Error loading height: \(error)")
            await MainActor.run { isLoadingHeight = false }
        }
    }

    private func saveEntry() async {
        guard let weight = Double(weightValue), weight > 0 else {
            errorMessage = "Please enter a valid weight"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            let userId = try await supabase.auth.session.user.id
            let deviceTimezone = TimeZone.current.identifier

            // Save weight to patient_quantity_samples - backend calculates BMI
            let sample = QuantitySampleWrite.create(
                patientId: userId,
                quantityType: QuantityTypes.weight,
                value: weight,
                unit: selectedUnit.rawValue == "lb" ? "pound" : "kilogram",
                timestamp: selectedDateTime,
                source: .wellpathInput,
                timezone: deviceTimezone,
                eventInstanceId: UUID()
            )

            try await supabase
                .from("patient_quantity_samples")
                .insert(sample)
                .execute()

            await MainActor.run { dismiss() }

        } catch {
            await MainActor.run {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }
}

#Preview {
    BMIEntryView()
}
