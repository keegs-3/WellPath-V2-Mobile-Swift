//
//  StrengthTrainingEntryView.swift
//  WellPath
//
//  Entry form for logging Strength Training workouts to patient_samples
//

import SwiftUI
import Supabase

struct StrengthTrainingEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var startDateTime = Date()
    @State private var endDateTime = Date()
    @State private var selectedType: String = ""
    @State private var selectedIntensity: String = ""
    @State private var selectedMuscleGroups: Set<String> = []
    @State private var strengthTypes: [StrengthReferenceOption] = []
    @State private var intensityLevels: [StrengthReferenceOption] = []
    @State private var muscleGroups: [StrengthReferenceOption] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showMuscleGroupPicker = false

    private let supabase = SupabaseManager.shared.client

    var duration: TimeInterval {
        endDateTime.timeIntervalSince(startDateTime)
    }

    var durationMinutes: Double {
        duration / 60
    }

    var muscleGroupsDisplayText: String {
        let names = muscleGroups
            .filter { selectedMuscleGroups.contains($0.referenceKey) }
            .map { $0.displayName }
        return names.joined(separator: ", ")
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
                                Text(option.displayName).tag(option.referenceKey)
                            }
                        }
                    } header: {
                        Text("Required")
                    }

                    Section {
                        Picker("Intensity", selection: $selectedIntensity) {
                            Text("Not specified").tag("")
                            ForEach(intensityLevels, id: \.id) { option in
                                Text(option.displayName).tag(option.referenceKey)
                            }
                        }

                        // Multi-select for muscle groups
                        Button(action: { showMuscleGroupPicker = true }) {
                            HStack {
                                Text("Muscle Groups")
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedMuscleGroups.isEmpty {
                                    Text("Not specified")
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(muscleGroupsDisplayText)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
        .sheet(isPresented: $showMuscleGroupPicker) {
            MuscleGroupPickerSheet(
                muscleGroups: muscleGroups,
                selectedMuscleGroups: $selectedMuscleGroups
            )
        }
    }
}

// MARK: - Multi-Select Muscle Group Picker

struct MuscleGroupPickerSheet: View {
    let muscleGroups: [StrengthReferenceOption]
    @Binding var selectedMuscleGroups: Set<String>
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(muscleGroups, id: \.id) { option in
                    Button(action: {
                        if selectedMuscleGroups.contains(option.referenceKey) {
                            selectedMuscleGroups.remove(option.referenceKey)
                        } else {
                            selectedMuscleGroups.insert(option.referenceKey)
                        }
                    }) {
                        HStack {
                            Text(option.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedMuscleGroups.contains(option.referenceKey) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Muscle Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") {
                        selectedMuscleGroups.removeAll()
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
}

// MARK: - StrengthTrainingEntryView Private Functions

private extension StrengthTrainingEntryView {
    func loadReferenceData() async {
        isLoading = true

        do {
            // Load strength types from data_entry_fields_reference
            let typesResponse: [StrengthReferenceOption] = try await supabase
                .from("data_entry_fields_reference")
                .select("id, display_name, reference_key")
                .eq("reference_category", value: "strength_types")
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            // Load intensity levels from data_entry_fields_reference
            let intensityResponse: [StrengthReferenceOption] = try await supabase
                .from("data_entry_fields_reference")
                .select("id, display_name, reference_key")
                .eq("reference_category", value: "workout_intensity")
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            // Load muscle groups from data_entry_fields_reference
            let muscleGroupResponse: [StrengthReferenceOption] = try await supabase
                .from("data_entry_fields_reference")
                .select("id, display_name, reference_key")
                .eq("reference_category", value: "muscle_groups")
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            await MainActor.run {
                strengthTypes = typesResponse
                intensityLevels = intensityResponse
                muscleGroups = muscleGroupResponse

                // Set default type to first option
                selectedType = strengthTypes.first?.referenceKey ?? ""

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

    func saveStrengthTrainingEntry() async {
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
            let userId = try await supabase.auth.session.user.id

            // Get device timezone
            let deviceTimezone = TimeZone.current.identifier

            // Build metadata with workout attributes
            var metadata: [String: AnyJSON] = [
                WorkoutMetadataKeys.workoutType: .string(selectedType)
            ]

            if !selectedIntensity.isEmpty {
                metadata[WorkoutMetadataKeys.intensity] = .string(selectedIntensity)
            }

            if !selectedMuscleGroups.isEmpty {
                // Store as array to support multi-select (aggregation uses @> containment)
                let muscleGroupArray = selectedMuscleGroups.map { AnyJSON.string($0) }
                metadata[WorkoutMetadataKeys.muscleGroups] = .array(muscleGroupArray)
            }

            // Create single patient_samples entry with duration and metadata
            let sample = PatientSample.quantity(
                patientId: userId,
                quantityType: QuantityTypes.strengthDuration,
                value: durationMinutes,
                unit: "minute",
                timestamp: startDateTime,
                endTime: endDateTime,  // Workout has duration (start != end)
                metadata: metadata,
                source: .wellpathInput,
                timezone: deviceTimezone,
                eventInstanceId: UUID()
            )

            // Insert into patient_samples
            try await supabase
                .from("patient_samples")
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

// MARK: - Supporting Models

struct StrengthReferenceOption: Codable, Identifiable {
    let id: String
    let displayName: String
    let referenceKey: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case referenceKey = "reference_key"
    }
}

#Preview {
    StrengthTrainingEntryView()
}
