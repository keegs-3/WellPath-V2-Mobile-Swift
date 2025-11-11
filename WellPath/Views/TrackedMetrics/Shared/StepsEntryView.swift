//
//  StepsEntryView.swift
//  WellPath
//
//  Entry form for logging daily steps
//

import SwiftUI

struct StepsEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDateTime = Date()
    @State private var stepCount: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let supabase = SupabaseManager.shared.client

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
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: "figure.walk")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                }

                Text("Steps")
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
                        TextField("Step Count", text: $stepCount)
                            .keyboardType(.numberPad)
                        Text("steps")
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
                Task {
                    await saveStepsEntry()
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
            .background(stepCount.isEmpty ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
            .disabled(isSaving || stepCount.isEmpty)
        }
    }

    private func saveStepsEntry() async {
        guard let countValue = Int(stepCount), countValue > 0 else {
            errorMessage = "Please enter a valid step count"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            // Get user ID
            let userId = try await supabase.auth.session.user.id.uuidString

            // Generate event instance ID for this entry
            let eventInstanceId = UUID().uuidString

            // Format dates
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let timestampString = dateFormatter.string(from: selectedDateTime)

            // Extract just the date (YYYY-MM-DD)
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day], from: selectedDateTime)
            let dateString = String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)

            // Insert step count entry
            try await supabase
                .from("patient_data_entries")
                .insert([
                    "patient_id": userId,
                    "field_id": "DEF_STEPS_DAY",
                    "entry_date": dateString,
                    "entry_timestamp": timestampString,
                    "value_quantity": "\(countValue)",
                    "source": "wellpath_input",
                    "event_instance_id": eventInstanceId
                ])
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
    StepsEntryView()
}
