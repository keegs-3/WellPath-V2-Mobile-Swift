//
//  BodyWeightEntryView.swift
//  WellPath
//
//  Entry form for logging body weight to patient_samples
//

import SwiftUI
import Supabase

struct BodyWeightEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDateTime = Date()
    @State private var weightValue: String = ""
    @State private var selectedUnit: WeightUnit = .pounds
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let supabase = SupabaseManager.shared.client

    enum WeightUnit: String, CaseIterable {
        case pounds = "lb"
        case kilograms = "kg"

        var displayName: String {
            switch self {
            case .pounds: return "lb"
            case .kilograms: return "kg"
            }
        }

        // Store in the original unit the user enters
        // Conversion to canonical (kg) happens during aggregation
        func toCanonical(_ value: Double) -> Double {
            return value  // No conversion - store as entered
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with X button
            HStack {
                Button(action: {
                    dismiss()
                }) {
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

                    Image(systemName: "scalemass")
                        .font(.system(size: 32))
                        .foregroundColor(.cyan)
                }

                Text("Body Weight")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.top, 8)
            .padding(.bottom, 24)

            Form {
                Section {
                    DatePicker("Date", selection: $selectedDateTime, displayedComponents: [.date])
                    DatePicker("Time", selection: $selectedDateTime, displayedComponents: [.hourAndMinute])
                }

                Section {
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

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }

            // Save button at bottom
            Button(action: {
                Task {
                    await saveWeightEntry()
                }
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
            .background(weightValue.isEmpty ? Color.gray : Color.cyan)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
            .disabled(isSaving || weightValue.isEmpty)
        }
    }

    private func saveWeightEntry() async {
        guard let inputValue = Double(weightValue), inputValue > 0 else {
            errorMessage = "Please enter a valid weight"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            // Get user ID
            let userId = try await supabase.auth.session.user.id

            // Get device timezone
            let deviceTimezone = TimeZone.current.identifier

            // Convert to canonical unit (pounds)
            let canonicalValue = selectedUnit.toCanonical(inputValue)

            // Create quantity sample - store in original unit (trigger converts to canonical)
            let sample = QuantitySampleWrite.create(
                patientId: userId,
                quantityType: QuantityTypes.weight,
                value: inputValue,  // Store original value
                unit: selectedUnit.rawValue == "lb" ? "pound" : "kilogram",  // Store actual unit
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
    BodyWeightEntryView()
}
