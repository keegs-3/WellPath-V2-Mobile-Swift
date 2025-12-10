//
//  HeightEntryView.swift
//  WellPath
//
//  Entry form for logging height to patient_samples
//

import SwiftUI
import Supabase

struct HeightEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDateTime = Date()
    @State private var feet: String = ""
    @State private var inches: String = ""
    @State private var centimeters: String = ""
    @State private var selectedUnit: HeightUnit = .imperial
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let supabase = SupabaseManager.shared.client

    enum HeightUnit: String, CaseIterable {
        case imperial = "ft/in"
        case metric = "cm"

        var displayName: String { rawValue }
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
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: "ruler")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                }

                Text("Height")
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
                    Picker("Unit", selection: $selectedUnit) {
                        ForEach(HeightUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Height") {
                    if selectedUnit == .imperial {
                        HStack {
                            TextField("Feet", text: $feet)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                            Text("ft")
                                .foregroundColor(.secondary)

                            Spacer()

                            TextField("Inches", text: $inches)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                            Text("in")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            TextField("0", text: $centimeters)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text("cm")
                                .foregroundColor(.secondary)
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
            .background(isValid ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
            .disabled(isSaving || !isValid)
        }
    }

    private var isValid: Bool {
        if selectedUnit == .imperial {
            let feetVal = Int(feet) ?? 0
            let inchesVal = Double(inches) ?? 0
            return feetVal > 0 || inchesVal > 0
        } else {
            let cmVal = Double(centimeters) ?? 0
            return cmVal > 0
        }
    }

    private func saveEntry() async {
        var heightInCm: Double = 0

        if selectedUnit == .imperial {
            let feetVal = Double(feet) ?? 0
            let inchesVal = Double(inches) ?? 0
            let totalInches = (feetVal * 12) + inchesVal
            heightInCm = totalInches * 2.54
        } else {
            heightInCm = Double(centimeters) ?? 0
        }

        guard heightInCm > 0 else {
            errorMessage = "Please enter a valid height"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            let userId = try await supabase.auth.session.user.id
            let deviceTimezone = TimeZone.current.identifier

            let sample = QuantitySampleWrite.create(
                patientId: userId,
                quantityType: QuantityTypes.height,
                value: heightInCm,
                unit: "centimeter",
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
    HeightEntryView()
}
