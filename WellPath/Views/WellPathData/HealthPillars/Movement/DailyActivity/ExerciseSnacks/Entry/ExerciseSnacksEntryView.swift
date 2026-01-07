//
//  ExerciseSnacksEntryView.swift
//  WellPath
//
//  Entry form for logging exercise snacks to patient_samples
//

import SwiftUI
import Supabase

struct ExerciseSnacksEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDateTime = Date()
    @State private var snackCount: String = ""
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

                    Image(systemName: "hare.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                }

                Text("Exercise Snacks")
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
                        TextField("Count", text: $snackCount)
                            .keyboardType(.numberPad)
                        Text("snacks")
                            .foregroundColor(.secondary)
                    }
                } footer: {
                    Text("Brief 1-5 minute bursts of vigorous activity (stairs, squats, jumping jacks)")
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
            .background(snackCount.isEmpty ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
            .disabled(isSaving || snackCount.isEmpty)
        }
    }

    private func saveEntry() async {
        guard let countValue = Double(snackCount), countValue > 0 else {
            errorMessage = "Please enter a valid number of exercise snacks"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            let userId = try await supabase.auth.session.user.id
            let deviceTimezone = TimeZone.current.identifier

            let sample = QuantitySampleWrite.create(
                patientId: userId,
                quantityType: "exercise_snacks",
                value: countValue,
                unit: "count",
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
    ExerciseSnacksEntryView()
}
