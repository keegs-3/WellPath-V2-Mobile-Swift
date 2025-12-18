//
//  WorkoutEntryView.swift
//  WellPath
//
//  Entry form for logging workouts to patient_quantity_samples
//  Used by category-specific screens (Cardio, Strength, HIIT, Mobility)
//

import SwiftUI

// MARK: - Workout Category Config

struct WorkoutCategoryConfig: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    let quantityType: String
    let referenceCategory: String

    static let cardio = WorkoutCategoryConfig(
        id: "cardio",
        name: "Cardio",
        icon: "figure.run",
        color: .red,
        quantityType: "cardio",
        referenceCategory: "cardio_types"
    )

    static let strength = WorkoutCategoryConfig(
        id: "strength",
        name: "Strength",
        icon: "dumbbell.fill",
        color: .orange,
        quantityType: "strength_training",
        referenceCategory: "strength_types"
    )

    static let hiit = WorkoutCategoryConfig(
        id: "hiit",
        name: "HIIT",
        icon: "bolt.heart.fill",
        color: .purple,
        quantityType: "hiit",
        referenceCategory: "hiit_types"
    )

    static let mobility = WorkoutCategoryConfig(
        id: "mobility",
        name: "Mobility",
        icon: "figure.flexibility",
        color: .teal,
        quantityType: "mobility",
        referenceCategory: "mobility_types"
    )

    static let all: [WorkoutCategoryConfig] = [cardio, strength, hiit, mobility]

    static func forCategory(_ category: String) -> WorkoutCategoryConfig {
        all.first { $0.id == category } ?? cardio
    }
}

// MARK: - Workout Entry View

struct WorkoutEntryView: View {
    let category: WorkoutCategoryConfig

    @Environment(\.dismiss) var dismiss
    @State private var startDateTime = Date()
    @State private var endDateTime = Date()
    @State private var selectedType: String = ""
    @State private var workoutTypes: [WorkoutTypeOption] = []
    @State private var intensityOptions: [IntensityOption] = []
    @State private var showingTypePicker = false
    @State private var typeSearchText = ""
    @State private var muscleGroupOptions: [MuscleGroupOption] = []
    @State private var selectedIntensity: String = ""
    @State private var selectedMuscleGroups: Set<String> = []
    @State private var showingMuscleGroupPicker = false
    @StateObject private var unitService = UnitConversionService.shared
    @State private var caloriesText: String = ""
    @State private var distanceText: String = ""
    @State private var selectedDistanceUnit: String = ""
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let supabase = SupabaseManager.shared.client

    /// Init with category string (used by screens)
    init(category: String, categoryName: String, color: Color, icon: String) {
        self.category = WorkoutCategoryConfig.forCategory(category)
    }

    /// Init with config directly
    init(config: WorkoutCategoryConfig) {
        self.category = config
    }

    var duration: TimeInterval {
        endDateTime.timeIntervalSince(startDateTime)
    }

    var durationMinutes: Double {
        duration / 60
    }

    /// Whether the selected workout type supports distance tracking (from database)
    var supportsDistance: Bool {
        workoutTypes.first(where: { $0.activityType == selectedType })?.supportsDistance ?? false
    }

    /// Whether this category supports muscle group selection (strength only)
    var showMuscleGroups: Bool {
        category.id == "strength"
    }

    /// Display name for selected type
    var selectedTypeName: String {
        workoutTypes.first(where: { $0.activityType == selectedType })?.displayName ?? "Select Type"
    }

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
                        .fill(category.color.opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: category.icon)
                        .font(.system(size: 32))
                        .foregroundColor(category.color)
                }

                Text(category.name)
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
                            Text(formatDuration(durationMinutes))
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Workout Time")
                    }

                    Section {
                        // Searchable type picker
                        Button {
                            showingTypePicker = true
                        } label: {
                            HStack {
                                Text("Type")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(selectedTypeName)
                                    .foregroundColor(selectedType.isEmpty ? .secondary : .primary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Picker("Intensity", selection: $selectedIntensity) {
                            Text("Select Intensity").tag("")
                            ForEach(intensityOptions, id: \.key) { option in
                                Text(option.displayName).tag(option.key)
                            }
                        }
                    } header: {
                        Text("Workout Type")
                    }

                    // Muscle Groups (strength only)
                    if showMuscleGroups && !muscleGroupOptions.isEmpty {
                        Section {
                            Button {
                                showingMuscleGroupPicker = true
                            } label: {
                                HStack {
                                    Text("Muscle Groups")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedMuscleGroups.isEmpty {
                                        Text("Select")
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("\(selectedMuscleGroups.count) selected")
                                            .foregroundColor(category.color)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } header: {
                            Text("Target Areas")
                        }
                    }

                    Section {
                        HStack {
                            Text("Calories")
                            Spacer()
                            TextField("Optional", text: $caloriesText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                            Text("kcal")
                                .foregroundColor(.secondary)
                        }

                        if supportsDistance {
                            HStack {
                                Text("Distance")
                                Spacer()
                                TextField("Optional", text: $distanceText)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                Picker("", selection: $selectedDistanceUnit) {
                                    Text("km").tag("km")
                                    Text("mi").tag("mi")
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 80)
                            }
                        }
                    } header: {
                        Text("Additional Info (Optional)")
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

            // Save button
            Button(action: {
                Task {
                    await saveWorkoutEntry()
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
            .background(selectedType.isEmpty || duration <= 0 || isLoading ? Color.gray : category.color)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
            .disabled(isSaving || selectedType.isEmpty || duration <= 0 || isLoading)
        }
        .onAppear {
            // Initialize end time to 30 minutes after start
            endDateTime = startDateTime.addingTimeInterval(1800)
            // Set default distance unit from user preference
            selectedDistanceUnit = unitService.preferredDistanceUnit.rawValue
            Task {
                await loadAllOptions()
            }
        }
        .sheet(isPresented: $showingTypePicker) {
            WorkoutTypePickerSheet(
                workoutTypes: workoutTypes,
                selectedType: $selectedType,
                searchText: $typeSearchText,
                color: category.color
            )
        }
        .sheet(isPresented: $showingMuscleGroupPicker) {
            MuscleGroupPickerSheet(
                muscleGroups: muscleGroupOptions,
                selectedGroups: $selectedMuscleGroups,
                color: category.color
            )
        }
    }

    // MARK: - Helper Methods

    private func formatDuration(_ minutes: Double) -> String {
        let totalMinutes = Int(minutes)
        if totalMinutes < 0 {
            return "Invalid"
        }
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins) minutes"
        }
    }

    private func loadAllOptions() async {
        isLoading = true

        do {
            // Load workout types from sample_category_types_reference (all types including non-HK ones)
            let types: [WorkoutTypeOption] = try await supabase
                .from("sample_category_types_reference")
                .select("reference_key, display_name, supports_distance")
                .eq("reference_category", value: category.referenceCategory)
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            // Load intensity options
            let intensities: [IntensityOption] = try await supabase
                .from("sample_category_types_reference")
                .select("reference_key, display_name")
                .eq("reference_category", value: "workout_intensity")
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            // Load muscle groups (for strength workouts)
            var muscleGroups: [MuscleGroupOption] = []
            if category.id == "strength" {
                muscleGroups = try await supabase
                    .from("sample_category_types_reference")
                    .select("reference_key, display_name")
                    .eq("reference_category", value: "muscle_groups")
                    .eq("is_active", value: true)
                    .order("display_order")
                    .execute()
                    .value
            }

            await MainActor.run {
                workoutTypes = types
                intensityOptions = intensities
                muscleGroupOptions = muscleGroups
                selectedType = workoutTypes.first?.activityType ?? ""
                isLoading = false
            }

        } catch {
            await MainActor.run {
                print("Error loading workout options: \(error)")
                errorMessage = "Failed to load workout options"
                isLoading = false
            }
        }
    }

    private func saveWorkoutEntry() async {
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
            let userId = try await supabase.auth.session.user.id

            // Build metadata struct
            let calories = Double(caloriesText)
            let distanceEntry = Double(distanceText)

            // Convert distance to meters for storage
            var distanceMeters: Double? = nil
            if let dist = distanceEntry, dist > 0 {
                if selectedDistanceUnit == "mi" {
                    distanceMeters = dist * 1609.344  // miles to meters
                } else {
                    distanceMeters = dist * 1000  // km to meters
                }
            }

            let metadata = WorkoutEntryMetadata(
                workoutSubtype: selectedType,
                intensity: selectedIntensity.isEmpty ? nil : selectedIntensity,
                muscleGroups: selectedMuscleGroups.isEmpty ? nil : Array(selectedMuscleGroups),
                caloriesBurned: (calories ?? 0) > 0 ? calories : nil,
                distanceMeters: distanceMeters
            )

            // Create workout entry
            let entry = QuantitySampleInsertWithMetadata(
                patientId: userId,
                quantityType: category.quantityType,
                quantityValue: durationMinutes,
                quantityUnit: "minutes",
                startTime: startDateTime,
                endTime: endDateTime,
                source: "wellpath_input",
                userTimezone: TimeZone.current.identifier,
                metadata: metadata
            )

            try await supabase
                .from("patient_quantity_samples")
                .insert(entry)
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

struct WorkoutTypeOption: Codable {
    let activityType: String
    let displayName: String
    let supportsDistance: Bool

    enum CodingKeys: String, CodingKey {
        case activityType = "reference_key"
        case displayName = "display_name"
        case supportsDistance = "supports_distance"
    }
}

struct IntensityOption: Codable {
    let key: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case key = "reference_key"
        case displayName = "display_name"
    }
}

struct MuscleGroupOption: Codable {
    let key: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case key = "reference_key"
        case displayName = "display_name"
    }
}

struct QuantitySampleInsert: Codable {
    let patientId: UUID
    let quantityType: String
    let quantityValue: Double
    let quantityUnit: String
    let startTime: Date
    let endTime: Date
    let source: String
    let userTimezone: String

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case quantityType = "quantity_type"
        case quantityValue = "quantity_value"
        case quantityUnit = "quantity_unit"
        case startTime = "start_time"
        case endTime = "end_time"
        case source
        case userTimezone = "user_timezone"
    }
}

struct WorkoutEntryMetadata: Codable {
    let workoutSubtype: String
    let intensity: String?
    let muscleGroups: [String]?
    let caloriesBurned: Double?
    let distanceMeters: Double?  // Always stored in meters (like HealthKit)

    enum CodingKeys: String, CodingKey {
        case workoutSubtype = "workout_subtype"
        case intensity
        case muscleGroups = "muscle_groups"
        case caloriesBurned = "calories_burned"
        case distanceMeters = "distance_meters"
    }
}

struct QuantitySampleInsertWithMetadata: Codable {
    let patientId: UUID
    let quantityType: String
    let quantityValue: Double
    let quantityUnit: String
    let startTime: Date
    let endTime: Date
    let source: String
    let userTimezone: String
    let metadata: WorkoutEntryMetadata

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case quantityType = "quantity_type"
        case quantityValue = "quantity_value"
        case quantityUnit = "quantity_unit"
        case startTime = "start_time"
        case endTime = "end_time"
        case source
        case userTimezone = "user_timezone"
        case metadata
    }
}

// MARK: - Workout Type Picker Sheet

struct WorkoutTypePickerSheet: View {
    let workoutTypes: [WorkoutTypeOption]
    @Binding var selectedType: String
    @Binding var searchText: String
    let color: Color

    @Environment(\.dismiss) private var dismiss

    var filteredTypes: [WorkoutTypeOption] {
        if searchText.isEmpty {
            return workoutTypes
        }
        return workoutTypes.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredTypes, id: \.activityType) { option in
                    Button {
                        selectedType = option.activityType
                        dismiss()
                    } label: {
                        HStack {
                            Text(option.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedType == option.activityType {
                                Image(systemName: "checkmark")
                                    .foregroundColor(color)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search workout types")
            .navigationTitle("Select Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Muscle Group Picker Sheet

struct MuscleGroupPickerSheet: View {
    let muscleGroups: [MuscleGroupOption]
    @Binding var selectedGroups: Set<String>
    let color: Color

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var filteredGroups: [MuscleGroupOption] {
        if searchText.isEmpty {
            return muscleGroups
        }
        return muscleGroups.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredGroups, id: \.key) { option in
                    Button {
                        if selectedGroups.contains(option.key) {
                            selectedGroups.remove(option.key)
                        } else {
                            selectedGroups.insert(option.key)
                        }
                    } label: {
                        HStack {
                            Text(option.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedGroups.contains(option.key) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(color)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search muscle groups")
            .navigationTitle("Select Muscle Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    WorkoutEntryView(category: "cardio", categoryName: "Cardio", color: .red, icon: "figure.run")
}
