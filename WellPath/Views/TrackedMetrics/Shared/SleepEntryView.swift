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

    @State private var asleepStart = Date()
    @State private var asleepEnd = Date()
    @State private var includeTimeInBed = false
    @State private var inBedStart = Date()
    @State private var inBedEnd = Date()

    var asleepDuration: TimeInterval {
        asleepEnd.timeIntervalSince(asleepStart)
    }

    var asleepHours: Double {
        asleepDuration / 3600
    }

    var timeInBedDuration: TimeInterval {
        inBedEnd.timeIntervalSince(inBedStart)
    }

    var timeInBedHours: Double {
        timeInBedDuration / 3600
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    DatePicker("Start", selection: $asleepStart)
                    DatePicker("End", selection: $asleepEnd)

                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(String(format: "%.1f hours", asleepHours))
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Time Asleep")
                }

                Section {
                    Toggle("Include Time in Bed", isOn: $includeTimeInBed)

                    if includeTimeInBed {
                        DatePicker("Start", selection: $inBedStart)
                        DatePicker("End", selection: $inBedEnd)

                        HStack {
                            Text("Duration")
                            Spacer()
                            Text(String(format: "%.1f hours", timeInBedHours))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Time in Bed (Optional)")
                } footer: {
                    Text("Time in bed includes time awake before falling asleep and after waking up.")
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
                    .disabled(asleepDuration <= 0 || viewModel.isLoading)
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
            .onChange(of: includeTimeInBed) { newValue in
                if newValue {
                    // Initialize in bed times to match asleep times
                    inBedStart = asleepStart
                    inBedEnd = asleepEnd
                }
            }
        }
    }

    func saveSleep() {
        Task {
            // If user didn't specify time in bed, use time asleep as time in bed
            let bedStart = includeTimeInBed ? inBedStart : asleepStart
            let bedEnd = includeTimeInBed ? inBedEnd : asleepEnd

            let success = await viewModel.saveSleep(
                inBedStart: bedStart,
                inBedEnd: bedEnd,
                asleepStart: asleepStart,
                asleepEnd: asleepEnd
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

    func saveSleep(inBedStart: Date, inBedEnd: Date, asleepStart: Date, asleepEnd: Date) async -> Bool {
        isLoading = true
        error = nil

        do {
            let userId = try await supabase.auth.session.user.id.uuidString

            // Generate shared event instance ID for both periods (links them together)
            let sharedEventInstanceId = UUID().uuidString

            // Format dates
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let calendar = Calendar.current
            let bedtimeComponents = calendar.dateComponents([.year, .month, .day], from: inBedStart)
            let entryDateString = String(format: "%04d-%02d-%02d",
                                         bedtimeComponents.year!,
                                         bedtimeComponents.month!,
                                         bedtimeComponents.day!)

            // UUIDs for sleep period types (from data_entry_fields_reference)
            // Using the same types as HealthKit: in_bed and asleep (not custom manual types)
            let inBedTypeId = "0354d91d-6729-45cc-b0d8-3d20847b14aa"  // in_bed
            let asleepTypeId = "dcca423d-b20f-4ca2-8f1f-f1f1b460803d" // asleep

            // =============================================================
            // PERIOD 1: TIME IN BED
            // =============================================================
            // This matches how HealthKit stores sleep data:
            // - 3 entries per period sharing the same event_instance_id
            // - DEF_SLEEP_PERIOD_START, DEF_SLEEP_PERIOD_END, DEF_SLEEP_PERIOD_TYPE

            let inBedEventId = UUID().uuidString
            let inBedMetadata = """
            {"reference_key": "in_bed", "shared_event_instance_id": "\(sharedEventInstanceId)", "was_user_entered": true}
            """

            // Period start
            try await supabase.from("patient_data_entries").insert([
                "patient_id": userId,
                "field_id": "DEF_SLEEP_PERIOD_START",
                "entry_date": entryDateString,
                "value_timestamp": dateFormatter.string(from: inBedStart),
                "source": "wellpath_input",
                "event_instance_id": inBedEventId,
                "metadata": inBedMetadata
            ]).execute()

            // Period end
            try await supabase.from("patient_data_entries").insert([
                "patient_id": userId,
                "field_id": "DEF_SLEEP_PERIOD_END",
                "entry_date": entryDateString,
                "value_timestamp": dateFormatter.string(from: inBedEnd),
                "source": "wellpath_input",
                "event_instance_id": inBedEventId,
                "metadata": inBedMetadata
            ]).execute()

            // Period type (reference to in_bed)
            try await supabase.from("patient_data_entries").insert([
                "patient_id": userId,
                "field_id": "DEF_SLEEP_PERIOD_TYPE",
                "entry_date": entryDateString,
                "value_reference": inBedTypeId,
                "source": "wellpath_input",
                "event_instance_id": inBedEventId,
                "metadata": inBedMetadata
            ]).execute()

            // =============================================================
            // PERIOD 2: TIME ASLEEP
            // =============================================================

            let asleepEventId = UUID().uuidString
            let asleepMetadata = """
            {"reference_key": "asleep", "shared_event_instance_id": "\(sharedEventInstanceId)", "was_user_entered": true}
            """

            // Period start
            try await supabase.from("patient_data_entries").insert([
                "patient_id": userId,
                "field_id": "DEF_SLEEP_PERIOD_START",
                "entry_date": entryDateString,
                "value_timestamp": dateFormatter.string(from: asleepStart),
                "source": "wellpath_input",
                "event_instance_id": asleepEventId,
                "metadata": asleepMetadata
            ]).execute()

            // Period end
            try await supabase.from("patient_data_entries").insert([
                "patient_id": userId,
                "field_id": "DEF_SLEEP_PERIOD_END",
                "entry_date": entryDateString,
                "value_timestamp": dateFormatter.string(from: asleepEnd),
                "source": "wellpath_input",
                "event_instance_id": asleepEventId,
                "metadata": asleepMetadata
            ]).execute()

            // Period type (reference to asleep)
            try await supabase.from("patient_data_entries").insert([
                "patient_id": userId,
                "field_id": "DEF_SLEEP_PERIOD_TYPE",
                "entry_date": entryDateString,
                "value_reference": asleepTypeId,
                "source": "wellpath_input",
                "event_instance_id": asleepEventId,
                "metadata": asleepMetadata
            ]).execute()

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

#Preview {
    SleepEntryView()
}
