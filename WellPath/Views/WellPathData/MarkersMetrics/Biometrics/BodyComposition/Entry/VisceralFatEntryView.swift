//
//  VisceralFatEntryView.swift
//  WellPath
//
//  Entry form for logging Visceral Fat rating to patient_samples
//

import SwiftUI
import Supabase

struct VisceralFatEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDateTime = Date()
    @State private var ratingValue: String = ""
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
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: "circle.hexagonpath")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                }

                Text("Visceral Fat %")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Fat stored around internal organs")
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

                Section("Visceral Fat Rating") {
                    HStack {
                        TextField("Percent", text: $ratingValue)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("%")
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
            .background(isValid ? Color.orange : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
            .disabled(isSaving || !isValid)
        }
    }

    private var isValid: Bool {
        guard let value = Int(ratingValue) else { return false }
        return value >= 1 && value <= 59
    }

    private func saveEntry() async {
        guard let value = Double(ratingValue), value >= 1 && value <= 59 else {
            errorMessage = "Please enter a value between 1 and 59"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            let userId = try await supabase.auth.session.user.id
            let deviceTimezone = TimeZone.current.identifier

            let sample = QuantitySampleWrite.create(
                patientId: userId,
                quantityType: QuantityTypes.visceralFatPercent,
                value: value,
                unit: "percent",
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
    VisceralFatEntryView()
}
