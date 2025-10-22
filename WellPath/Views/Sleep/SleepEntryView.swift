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
            let userId = try await supabase.auth.session.user.id

            let metadata = SleepMetadata(
                bedtime: ISO8601DateFormatter().string(from: bedtime),
                wakeTime: ISO8601DateFormatter().string(from: wakeTime),
                quality: quality
            )

            let entry = SleepDataEntry(
                userId: userId,
                fieldId: "DEF_SLEEP_DURATION",
                entryDate: ISO8601DateFormatter().string(from: bedtime),
                entryTimestamp: ISO8601DateFormatter().string(from: bedtime),
                valueQuantity: duration,
                source: "manual_entry",
                metadata: metadata
            )

            _ = try await supabase
                .from("patient_data_entries")
                .insert(entry)
                .execute()

            isLoading = false
            return true

        } catch {
            self.error = error.localizedDescription
            print("Error saving sleep: \(error)")
            isLoading = false
            return false
        }
    }
}

struct SleepMetadata: Codable {
    let bedtime: String
    let wakeTime: String
    let quality: Int

    enum CodingKeys: String, CodingKey {
        case bedtime
        case wakeTime = "wake_time"
        case quality
    }
}

struct SleepDataEntry: Codable {
    let userId: UUID
    let fieldId: String
    let entryDate: String
    let entryTimestamp: String
    let valueQuantity: Double
    let source: String
    let metadata: SleepMetadata

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case fieldId = "field_id"
        case entryDate = "entry_date"
        case entryTimestamp = "entry_timestamp"
        case valueQuantity = "value_quantity"
        case source
        case metadata
    }
}

#Preview {
    SleepEntryView()
}
