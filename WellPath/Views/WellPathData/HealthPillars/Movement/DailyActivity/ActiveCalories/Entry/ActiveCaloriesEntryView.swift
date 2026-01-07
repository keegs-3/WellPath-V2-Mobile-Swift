//
//  ActiveCaloriesEntryView.swift
//  WellPath
//
//  Entry form for logging active calories to patient_samples
//

import SwiftUI
import Supabase

struct ActiveCaloriesEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDateTime = Date()
    @State private var calories: String = ""
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

                    Image(systemName: "flame.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                }

                Text("Active Calories")
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
                        TextField("Calories", text: $calories)
                            .keyboardType(.numberPad)
                        Text("cal")
                            .foregroundColor(.secondary)
                    }
                } footer: {
                    Text("Calories burned through physical activity (not including resting metabolism)")
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
            .background(calories.isEmpty ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
            .disabled(isSaving || calories.isEmpty)
        }
    }

    private func saveEntry() async {
        guard let calorieValue = Double(calories), calorieValue > 0 else {
            errorMessage = "Please enter a valid calorie amount"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            let userId = try await supabase.auth.session.user.id
            let deviceTimezone = TimeZone.current.identifier

            let sample = QuantitySampleWrite.create(
                patientId: userId,
                quantityType: "active_calories",
                value: calorieValue,
                unit: "kilocalorie",
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
    ActiveCaloriesEntryView()
}
