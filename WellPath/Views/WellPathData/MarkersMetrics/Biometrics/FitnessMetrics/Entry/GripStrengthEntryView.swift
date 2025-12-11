//
//  GripStrengthEntryView.swift
//  WellPath
//
//  Entry form for logging grip strength to patient_samples
//

import SwiftUI
import Supabase

struct GripStrengthEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDateTime = Date()
    @State private var gripValue: String = ""
    @State private var selectedUnit: GripUnit = .kg
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let supabase = SupabaseManager.shared.client

    enum GripUnit: String, CaseIterable {
        case kg = "kg"
        case lb = "lb"

        var displayName: String { rawValue }

        var databaseUnit: String {
            switch self {
            case .kg: return "kilogram"
            case .lb: return "pound"
            }
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
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                }

                Text("Grip Strength")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Enter your grip strength measurement")
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

                Section {
                    HStack {
                        Text("Unit")
                        Spacer()
                        Picker("Unit", selection: $selectedUnit) {
                            ForEach(GripUnit.allCases, id: \.self) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 100)
                    }
                }

                Section("Grip Strength") {
                    HStack {
                        TextField("0", text: $gripValue)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text(selectedUnit.displayName)
                            .foregroundColor(.secondary)
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
            .background(isValid ? Color.orange : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
            .disabled(isSaving || !isValid)
        }
    }

    private var isValid: Bool {
        guard let value = Double(gripValue) else { return false }
        return value > 0
    }

    private func saveEntry() async {
        guard let value = Double(gripValue), value > 0 else {
            errorMessage = "Please enter a valid grip strength"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            let userId = try await supabase.auth.session.user.id
            let deviceTimezone = TimeZone.current.identifier

            let sample = QuantitySampleWrite.create(
                patientId: userId,
                quantityType: QuantityTypes.gripStrength,
                value: value,
                unit: selectedUnit.databaseUnit,
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
    GripStrengthEntryView()
}
