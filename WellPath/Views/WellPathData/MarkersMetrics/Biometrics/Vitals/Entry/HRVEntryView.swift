//
//  HRVEntryView.swift
//  WellPath
//
//  Entry form for logging Heart Rate Variability (HRV) to patient_samples
//

import SwiftUI
import Supabase

struct HRVEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDateTime = Date()
    @State private var hrvValue: String = ""
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
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 32))
                        .foregroundColor(.purple)
                }

                Text("Heart Rate Variability")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("SDNN or RMSSD measurement in milliseconds")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)
            .padding(.bottom, 24)

            Form {
                Section {
                    DatePicker("Date", selection: $selectedDateTime, displayedComponents: [.date])
                    DatePicker("Time", selection: $selectedDateTime, displayedComponents: [.hourAndMinute])
                }

                Section("HRV") {
                    HStack {
                        TextField("0", text: $hrvValue)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("ms")
                            .foregroundColor(.secondary)
                    }
                }

                // Classification based on typical ranges
                if let hrv = Double(hrvValue), hrv > 0 {
                    Section("Classification") {
                        HStack {
                            Text(classifyHRV(hrv))
                                .foregroundColor(classificationColor(hrv))
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
            .background(isValid ? Color.purple : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
            .disabled(isSaving || !isValid)
        }
    }

    private var isValid: Bool {
        guard let value = Double(hrvValue) else { return false }
        return value > 0 && value < 500  // Reasonable HRV range
    }

    private func classifyHRV(_ hrv: Double) -> String {
        // These ranges vary significantly by age and fitness level
        if hrv >= 60 {
            return "Excellent"
        } else if hrv >= 40 {
            return "Good"
        } else if hrv >= 25 {
            return "Average"
        } else {
            return "Below Average"
        }
    }

    private func classificationColor(_ hrv: Double) -> Color {
        if hrv >= 60 {
            return .green
        } else if hrv >= 40 {
            return .green
        } else if hrv >= 25 {
            return .yellow
        } else {
            return .red
        }
    }

    private func saveEntry() async {
        guard let value = Double(hrvValue), value > 0 else {
            errorMessage = "Please enter a valid HRV value"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            let userId = try await supabase.auth.session.user.id
            let deviceTimezone = TimeZone.current.identifier

            let sample = QuantitySampleWrite.create(
                patientId: userId,
                quantityType: QuantityTypes.hrv,
                value: value,
                unit: "ms",
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
    HRVEntryView()
}
