//
//  ASMIEntryView.swift
//  WellPath
//
//  Entry form for logging Appendicular Skeletal Muscle Mass (AMM)
//  ASMI is calculated from AMM / height^2 (height from patient_characteristics)
//

import SwiftUI
import Supabase

struct ASMIEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDateTime = Date()
    @State private var muscleMassValue: String = ""
    @State private var selectedUnit: MassUnit = .kilograms
    @State private var patientHeight: Double? // Height in cm from patient_characteristics
    @State private var isSaving = false
    @State private var isLoadingHeight = true
    @State private var errorMessage: String?

    private let supabase = SupabaseManager.shared.client
    private let color = Color.cyan  // Biometrics color

    enum MassUnit: String, CaseIterable {
        case kilograms = "kg"
        case pounds = "lb"

        var displayName: String { rawValue }
    }

    // Value in kg for calculation
    private var muscleMassInKg: Double? {
        guard let value = Double(muscleMassValue), value > 0 else { return nil }
        return selectedUnit == .kilograms ? value : value * 0.453592
    }

    // Calculated ASMI preview
    private var calculatedASMI: Double? {
        guard let muscleMassKg = muscleMassInKg,
              let heightCm = patientHeight, heightCm > 0 else { return nil }
        let heightM = heightCm / 100.0
        return muscleMassKg / (heightM * heightM)
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
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 28))
                        .foregroundColor(color)
                }

                Text("Appendicular Muscle Mass")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .padding(.top, 4)
            .padding(.bottom, 16)

            Form {
                Section {
                    DatePicker("Date", selection: $selectedDateTime, displayedComponents: [.date])
                    DatePicker("Time", selection: $selectedDateTime, displayedComponents: [.hourAndMinute])
                }

                Section("Appendicular Muscle Mass") {
                    HStack {
                        TextField("0.0", text: $muscleMassValue)
                            .keyboardType(.decimalPad)
                        Picker("Unit", selection: $selectedUnit) {
                            ForEach(MassUnit.allCases, id: \.self) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 100)
                    }
                }

                // Calculated ASMI preview
                if let asmi = calculatedASMI {
                    Section("Calculated ASMI") {
                        HStack {
                            Text(String(format: "%.2f", asmi))
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("kg/m²")
                                .foregroundColor(.secondary)
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
            .background(isValid ? color : Color.gray)
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
        guard let massKg = muscleMassInKg, massKg > 0, massKg < 50 else { return false }
        return patientHeight != nil
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
        guard let inputValue = Double(muscleMassValue), inputValue > 0 else {
            errorMessage = "Please enter a valid value"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            // Get user ID
            let userId = try await supabase.auth.session.user.id

            // Get device timezone
            let deviceTimezone = TimeZone.current.identifier

            // Create patient_quantity_samples entry - store in original unit
            let sample = QuantitySampleWrite.create(
                patientId: userId,
                quantityType: QuantityTypes.appendicularSkeletalMuscleMass,
                value: inputValue,  // Store original value, not converted
                unit: selectedUnit == .pounds ? "pound" : "kilogram",  // Store actual unit
                timestamp: selectedDateTime,
                source: .wellpathInput,
                timezone: deviceTimezone,
                eventInstanceId: UUID()
            )

            // Insert into patient_quantity_samples
            try await supabase
                .from("patient_quantity_samples")
                .insert(sample)
                .execute()

            await MainActor.run {
                dismiss()
            }

        } catch {
            await MainActor.run {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }
}

#Preview {
    ASMIEntryView()
}
