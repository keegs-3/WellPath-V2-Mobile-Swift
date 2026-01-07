//
//  StandTimeEntryView.swift
//  WellPath
//
//  Entry form for logging stand hours to patient_samples
//

import SwiftUI
import Supabase

struct StandTimeEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDateTime = Date()
    @State private var hours: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let supabase = SupabaseManager.shared.client

    var body: some View {
        VStack(spacing: 0) {
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

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: "figure.stand")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                }

                Text("Stand Time")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.top, 8)
            .padding(.bottom, 24)

            Form {
                Section {
                    DatePicker("Date", selection: $selectedDateTime, displayedComponents: [.date])
                }

                Section {
                    HStack {
                        TextField("Stand Hours", text: $hours)
                            .keyboardType(.numberPad)
                        Text("hours")
                            .foregroundColor(.secondary)
                    }
                } footer: {
                    Text("Enter the number of hours you stood and moved for at least one minute")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }

            Button(action: {
                Task {
                    await saveEntry()
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
            .background(hours.isEmpty ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
            .disabled(isSaving || hours.isEmpty)
        }
    }

    private func saveEntry() async {
        guard let hourValue = Double(hours), hourValue > 0, hourValue <= 24 else {
            errorMessage = "Please enter a valid number of hours (1-24)"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            let userId = try await supabase.auth.session.user.id
            let deviceTimezone = TimeZone.current.identifier

            // Convert hours to minutes for storage
            let minuteValue = hourValue * 60

            let sample = QuantitySampleWrite.create(
                patientId: userId,
                quantityType: "stand_time",
                value: minuteValue,
                unit: "minute",
                timestamp: selectedDateTime,
                source: .wellpathInput,
                timezone: deviceTimezone,
                eventInstanceId: UUID()
            )

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
    StandTimeEntryView()
}
