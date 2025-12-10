//
//  VO2MaxEntryView.swift
//  WellPath
//
//  Entry form for logging VO2 Max to patient_samples
//

import SwiftUI
import Supabase

struct VO2MaxEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDateTime = Date()
    @State private var vo2Value: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let supabase = SupabaseManager.shared.client

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
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: "lungs.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                }

                Text("VO2 Max")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Maximum oxygen consumption (mL/kg/min)")
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

                Section("VO2 Max") {
                    HStack {
                        TextField("0", text: $vo2Value)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("mL/kg/min")
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
            .background(isValid ? Color.green : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
            .disabled(isSaving || !isValid)
        }
    }

    private var isValid: Bool {
        guard let value = Double(vo2Value) else { return false }
        return value > 0 && value < 100  // Reasonable VO2 Max range
    }

    private func saveEntry() async {
        guard let value = Double(vo2Value), value > 0 else {
            errorMessage = "Please enter a valid VO2 Max value"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            let userId = try await supabase.auth.session.user.id
            let deviceTimezone = TimeZone.current.identifier

            let sample = QuantitySampleWrite.create(
                patientId: userId,
                quantityType: QuantityTypes.vo2Max,
                value: value,
                unit: "mL/kg/min",
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
    VO2MaxEntryView()
}
