//
//  StrengthTrainingEntryView.swift
//  WellPath
//
//  Entry form for logging Strength Training workouts
//

import SwiftUI

struct StrengthTrainingEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var startDateTime = Date()
    @State private var endDateTime = Date()
    @State private var selectedType: String = ""
    @State private var selectedIntensity: String = ""
    @State private var selectedMuscleGroup: String = ""
    @State private var strengthTypes: [ReferenceOption] = []
    @State private var intensityLevels: [ReferenceOption] = []
    @State private var muscleGroups: [ReferenceOption] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let supabase = SupabaseManager.shared.client

    var duration: TimeInterval {
        endDateTime.timeIntervalSince(startDateTime)
    }

    var durationMinutes: Double {
        duration / 60
    }

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
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                }

                Text("Strength Training")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.top, 8)
            .padding(.bottom, 24)

            Form {
                if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else {
                    Section {
                        DatePicker("Start", selection: $startDateTime)
                        DatePicker("End", selection: $endDateTime)

                        HStack {
                            Text("Duration")
                            Spacer()
                            Text(String(format: "%.0f minutes", durationMinutes))
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Workout Time")
                    }

                    Section {
                        Picker("Type", selection: $selectedType) {
                            Text("Select Type").tag("")
                            ForEach(strengthTypes, id: \.id) { option in
                                Text(option.displayName).tag(option.id)
                            }
                        }
                    } header: {
                        Text("Required")
                    }

                    Section {
                        Picker("Intensity", selection: $selectedIntensity) {
                            Text("Not specified").tag("")
                            ForEach(intensityLevels, id: \.id) { option in
                                Text(option.displayName).tag(option.id)
                            }
                        }

                        Picker("Muscle Group", selection: $selectedMuscleGroup) {
                            Text("Not specified").tag("")
                            ForEach(muscleGroups, id: \.id) { option in
                                Text(option.displayName).tag(option.id)
                            }
                        }
                    } header: {
                        Text("Optional Details")
                    }

                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
            }

            // Save button at bottom
            Button(action: {
                Task {
                    await saveStrengthTrainingEntry()
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
            .background(selectedType.isEmpty || duration <= 0 || isLoading ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
            .disabled(isSaving || selectedType.isEmpty || duration <= 0 || isLoading)
        }
        .task {
            await loadReferenceData()
        }
        .onAppear {
            // Initialize end time to 1 hour after start
            endDateTime = startDateTime.addingTimeInterval(3600)
        }
    }

    private func loadReferenceData() async {
        isLoading = true

        do {
            // Load strength types from data_entry_fields_reference
            let typesResponse: [ReferenceOption] = try await supabase
                .from("data_entry_fields_reference")
                .select("id, display_name")
                .eq("reference_category", value: "strength_types")
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            // Load intensity levels from data_entry_fields_reference
            let intensityResponse: [ReferenceOption] = try await supabase
                .from("data_entry_fields_reference")
                .select("id, display_name")
                .eq("reference_category", value: "workout_intensity")
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            // Load muscle groups from data_entry_fields_reference
            let muscleGroupResponse: [ReferenceOption] = try await supabase
                .from("data_entry_fields_reference")
                .select("id, display_name")
                .eq("reference_category", value: "muscle_groups")
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            await MainActor.run {
                strengthTypes = typesResponse
                intensityLevels = intensityResponse
                muscleGroups = muscleGroupResponse

                // Set default type to traditional
                selectedType = strengthTypes.first?.id ?? ""

                isLoading = false
            }

        } catch {
            await MainActor.run {
                print("⚠️ Could not load reference options: \(error.localizedDescription)")
                errorMessage = "Failed to load options: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    private func saveStrengthTrainingEntry() async {
        guard duration > 0 else {
            errorMessage = "End time must be after start time"
            return
        }

        guard !selectedType.isEmpty else {
            errorMessage = "Please select a workout type"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            // Get user ID
            let userId = try await supabase.auth.session.user.id.uuidString

            // Generate event instance ID to link all fields together
            let eventInstanceId = UUID().uuidString

            // Format dates
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let startTimestampString = dateFormatter.string(from: startDateTime)
            let endTimestampString = dateFormatter.string(from: endDateTime)

            // Extract just the date (YYYY-MM-DD) from start
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day], from: startDateTime)
            let dateString = String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)

            // Calculate duration in minutes
            let durationValue = durationMinutes

            // Insert strength start timestamp
            try await supabase
                .from("patient_data_entries")
                .insert([
                    "patient_id": userId,
                    "field_id": "DEF_STRENGTH_START",
                    "entry_date": dateString,
                    "value_timestamp": startTimestampString,
                    "source": "wellpath_input",
                    "event_instance_id": eventInstanceId
                ])
                .execute()

            // Insert strength end timestamp
            try await supabase
                .from("patient_data_entries")
                .insert([
                    "patient_id": userId,
                    "field_id": "DEF_STRENGTH_END",
                    "entry_date": dateString,
                    "value_timestamp": endTimestampString,
                    "source": "wellpath_input",
                    "event_instance_id": eventInstanceId
                ])
                .execute()

            // Insert strength duration
            try await supabase
                .from("patient_data_entries")
                .insert([
                    "patient_id": userId,
                    "field_id": "DEF_STRENGTH_DURATION",
                    "entry_date": dateString,
                    "entry_timestamp": endTimestampString,
                    "value_quantity": "\(durationValue)",
                    "source": "wellpath_input",
                    "event_instance_id": eventInstanceId
                ])
                .execute()

            // Insert strength type (required)
            try await supabase
                .from("patient_data_entries")
                .insert([
                    "patient_id": userId,
                    "field_id": "DEF_STRENGTH_TYPE",
                    "entry_date": dateString,
                    "entry_timestamp": startTimestampString,
                    "value_reference": selectedType,
                    "source": "wellpath_input",
                    "event_instance_id": eventInstanceId
                ])
                .execute()

            // Optional: Insert intensity
            if !selectedIntensity.isEmpty {
                try await supabase
                    .from("patient_data_entries")
                    .insert([
                        "patient_id": userId,
                        "field_id": "DEF_STRENGTH_INTENSITY",
                        "entry_date": dateString,
                        "entry_timestamp": startTimestampString,
                        "value_reference": selectedIntensity,
                        "source": "wellpath_input",
                        "event_instance_id": eventInstanceId
                    ])
                    .execute()
            }

            // Optional: Insert muscle group
            if !selectedMuscleGroup.isEmpty {
                try await supabase
                    .from("patient_data_entries")
                    .insert([
                        "patient_id": userId,
                        "field_id": "DEF_STRENGTH_MUSCLE_GROUPS",
                        "entry_date": dateString,
                        "entry_timestamp": startTimestampString,
                        "value_reference": selectedMuscleGroup,
                        "source": "wellpath_input",
                        "event_instance_id": eventInstanceId
                    ])
                    .execute()
            }

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
    StrengthTrainingEntryView()
}
