//
//  BloodPressureEntryView.swift
//  WellPath
//
//  Entry form for logging blood pressure (systolic/diastolic) to patient_samples
//

import SwiftUI
import Supabase

struct BloodPressureEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDateTime = Date()
    @State private var systolicValue: String = ""
    @State private var diastolicValue: String = ""
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
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: "heart.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.red)
                }

                Text("Blood Pressure")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("mmHg")
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

                Section("Reading") {
                    HStack {
                        Text("Systolic")
                        Spacer()
                        TextField("120", text: $systolicValue)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("mmHg")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Diastolic")
                        Spacer()
                        TextField("80", text: $diastolicValue)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("mmHg")
                            .foregroundColor(.secondary)
                    }
                }

                // Show classification
                if let systolic = Int(systolicValue), let diastolic = Int(diastolicValue) {
                    Section("Classification") {
                        HStack {
                            Text(classifyBloodPressure(systolic: systolic, diastolic: diastolic))
                                .foregroundColor(classificationColor(systolic: systolic, diastolic: diastolic))
                            Spacer()
                            Text("\(systolic)/\(diastolic)")
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
                Task { await saveEntries() }
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
            .background(isValid ? Color.red : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
            .disabled(isSaving || !isValid)
        }
    }

    private var isValid: Bool {
        !systolicValue.isEmpty && !diastolicValue.isEmpty
    }

    private func classifyBloodPressure(systolic: Int, diastolic: Int) -> String {
        if systolic < 120 && diastolic < 80 {
            return "Normal"
        } else if systolic < 130 && diastolic < 80 {
            return "Elevated"
        } else if systolic < 140 || diastolic < 90 {
            return "High (Stage 1)"
        } else if systolic >= 140 || diastolic >= 90 {
            return "High (Stage 2)"
        } else if systolic > 180 || diastolic > 120 {
            return "Hypertensive Crisis"
        }
        return "Unknown"
    }

    private func classificationColor(systolic: Int, diastolic: Int) -> Color {
        if systolic < 120 && diastolic < 80 {
            return .green
        } else if systolic < 130 && diastolic < 80 {
            return .yellow
        } else {
            return .red
        }
    }

    private func saveEntries() async {
        guard let systolic = Double(systolicValue), systolic > 0,
              let diastolic = Double(diastolicValue), diastolic > 0 else {
            errorMessage = "Please enter valid blood pressure values"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            let userId = try await supabase.auth.session.user.id
            let deviceTimezone = TimeZone.current.identifier
            let eventId = UUID() // Group both readings together

            // Save systolic
            let systolicSample = PatientSample.quantity(
                patientId: userId,
                quantityType: QuantityTypes.bloodPressureSystolic,
                value: systolic,
                unit: "mmHg",
                timestamp: selectedDateTime,
                source: .wellpathInput,
                timezone: deviceTimezone,
                eventInstanceId: eventId
            )

            try await supabase
                .from("patient_samples")
                .insert(systolicSample)
                .execute()

            // Save diastolic
            let diastolicSample = PatientSample.quantity(
                patientId: userId,
                quantityType: QuantityTypes.bloodPressureDiastolic,
                value: diastolic,
                unit: "mmHg",
                timestamp: selectedDateTime,
                source: .wellpathInput,
                timezone: deviceTimezone,
                eventInstanceId: eventId
            )

            try await supabase
                .from("patient_samples")
                .insert(diastolicSample)
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
    BloodPressureEntryView()
}
