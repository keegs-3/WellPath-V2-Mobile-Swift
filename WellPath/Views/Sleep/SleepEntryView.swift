//
//  SleepEntryView.swift
//  WellPath
//
//  Created on 2025-10-22
//

import SwiftUI

struct SleepEntryView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = SleepEntryViewModel()

    @State private var bedtime = Date()
    @State private var wakeTime = Date()
    @State private var sleepQuality: Int = 3

    var sleepDuration: TimeInterval {
        wakeTime.timeIntervalSince(bedtime)
    }

    var sleepHours: Double {
        sleepDuration / 3600
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Sleep Times") {
                    DatePicker("Bedtime", selection: $bedtime)

                    DatePicker("Wake Time", selection: $wakeTime)

                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(String(format: "%.1f hours", sleepHours))
                            .foregroundColor(.secondary)
                    }
                }

                Section("Sleep Quality") {
                    Picker("Quality", selection: $sleepQuality) {
                        Text("Poor").tag(1)
                        Text("Fair").tag(2)
                        Text("Good").tag(3)
                        Text("Very Good").tag(4)
                        Text("Excellent").tag(5)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button(action: saveSleep) {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Save Sleep")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(sleepDuration <= 0 || viewModel.isLoading)
                }
            }
            .navigationTitle("Log Sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                if let error = viewModel.error {
                    Text(error)
                }
            }
        }
    }

    func saveSleep() {
        Task {
            let success = await viewModel.saveSleep(
                bedtime: bedtime,
                wakeTime: wakeTime,
                quality: sleepQuality
            )

            if success {
                dismiss()
            }
        }
    }
}

@MainActor
class SleepEntryViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    func saveSleep(bedtime: Date, wakeTime: Date, quality: Int) async -> Bool {
        isLoading = true
        error = nil

        do {
            let duration = wakeTime.timeIntervalSince(bedtime) / 60  // Convert to minutes

            // Insert into patient_data_entries
            let entry: [String: Any] = [
                "user_id": try await supabase.auth.session.user.id.uuidString,
                "field_id": "DEF_SLEEP_DURATION",
                "entry_date": ISO8601DateFormatter().string(from: bedtime),
                "entry_timestamp": ISO8601DateFormatter().string(from: bedtime),
                "value_quantity": duration,
                "source": "manual_entry",
                "metadata": [
                    "bedtime": ISO8601DateFormatter().string(from: bedtime),
                    "wake_time": ISO8601DateFormatter().string(from: wakeTime),
                    "quality": quality
                ]
            ]

            _ = try await supabase
                .from("patient_data_entries")
                .insert(entry)
                .execute()

            isLoading = false
            return true

        } catch {
            self.error = error.localizedDescription
            print("Error saving sleep: \\(error)")
            isLoading = false
            return false
        }
    }
}

#Preview {
    SleepEntryView()
}
