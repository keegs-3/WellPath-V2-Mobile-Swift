//
//  ActivityEntryView.swift
//  WellPath
//
//  Generic entry form for duration-based activities
//  Used by: Mindfulness, Outdoor Time, Social Interactions, Cognitive Activities
//

import SwiftUI

// MARK: - Activity Category Config

struct ActivityCategoryConfig: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    let quantityType: String
    let referenceCategory: String
    let pillar: String

    // Mindfulness - Stress Management pillar (salmon/red)
    static let mindfulness = ActivityCategoryConfig(
        id: "mindfulness",
        name: "Mindfulness",
        icon: "figure.mind.and.body",
        color: Color(red: 0.93, green: 0.55, blue: 0.55),  // #ED8D8D
        quantityType: "mindfulness",
        referenceCategory: "mindfulness_types",
        pillar: "Stress Management"
    )

    // Outdoor Time - Connection pillar (green)
    static let outdoorTime = ActivityCategoryConfig(
        id: "outdoor_time",
        name: "Outdoor Time",
        icon: "leaf.fill",
        color: Color(red: 0.68, green: 0.83, blue: 0.60),  // #ADD399
        quantityType: "outdoor_time",
        referenceCategory: "outdoor_time_types",
        pillar: "Connection + Purpose"
    )

    // Social Interactions - Connection pillar (green)
    static let social = ActivityCategoryConfig(
        id: "social",
        name: "Social Time",
        icon: "person.2.fill",
        color: Color(red: 0.68, green: 0.83, blue: 0.60),  // #ADD399
        quantityType: "social_interaction",
        referenceCategory: "social_interaction_types",
        pillar: "Connection + Purpose"
    )

    // Cognitive Activities - Cognitive Health pillar (purple)
    static let cognitive = ActivityCategoryConfig(
        id: "cognitive",
        name: "Brain Training",
        icon: "brain.head.profile",
        color: Color(red: 0.78, green: 0.71, blue: 1.0),  // #C6B5FF
        quantityType: "cognitive_activity",
        referenceCategory: "cognitive_activity_types",
        pillar: "Cognitive Health"
    )
}

// MARK: - Activity Entry View

struct ActivityEntryView: View {
    let config: ActivityCategoryConfig
    var onSave: (() -> Void)?

    @Environment(\.dismiss) var dismiss
    @State private var startDateTime = Date()
    @State private var durationMinutes: Double = 15
    @State private var selectedType: String = ""
    @State private var activityTypes: [ActivityTypeOption] = []
    @State private var showingTypePicker = false
    @State private var typeSearchText = ""
    @State private var notes: String = ""
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let supabase = SupabaseManager.shared.client

    private let durationPresets: [Double] = [5, 10, 15, 20, 30, 45, 60, 90, 120]

    var selectedTypeName: String {
        activityTypes.first(where: { $0.key == selectedType })?.displayName ?? "Select Type"
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
                        .fill(config.color.opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: config.icon)
                        .font(.system(size: 32))
                        .foregroundColor(config.color)
                }

                Text(config.name)
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
                        DatePicker("When", selection: $startDateTime, displayedComponents: [.date, .hourAndMinute])
                    } header: {
                        Text("Date & Time")
                    }

                    Section {
                        // Duration picker with presets
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Duration: \(formatDuration(durationMinutes))")
                                .font(.headline)

                            // Preset buttons
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(durationPresets, id: \.self) { preset in
                                    Button {
                                        durationMinutes = preset
                                    } label: {
                                        Text(formatDuration(preset))
                                            .font(.subheadline)
                                            .fontWeight(durationMinutes == preset ? .semibold : .regular)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(durationMinutes == preset ? config.color.opacity(0.2) : Color(uiColor: .tertiarySystemGroupedBackground))
                                            .foregroundColor(durationMinutes == preset ? config.color : .primary)
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            // Custom slider for fine-tuning
                            Slider(value: $durationMinutes, in: 1...180, step: 1)
                                .tint(config.color)
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("Duration")
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
                    } header: {
                        Text("Activity Type")
                    }

                    Section {
                        TextField("Optional notes...", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    } header: {
                        Text("Notes")
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
            .background(selectedType.isEmpty || isLoading ? Color.gray : config.color)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
            .disabled(isSaving || selectedType.isEmpty || isLoading)
        }
        .onAppear {
            Task {
                await loadActivityTypes()
            }
        }
        .sheet(isPresented: $showingTypePicker) {
            ActivityTypePickerSheet(
                activityTypes: activityTypes,
                selectedType: $selectedType,
                searchText: $typeSearchText,
                color: config.color
            )
        }
    }

    // MARK: - Helper Methods

    private func formatDuration(_ minutes: Double) -> String {
        let totalMinutes = Int(minutes)
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        } else {
            return "\(mins) min"
        }
    }

    private func loadActivityTypes() async {
        isLoading = true

        do {
            let types: [ActivityTypeOption] = try await supabase
                .from("sample_category_types_reference")
                .select("reference_key, display_name")
                .eq("reference_category", value: config.referenceCategory)
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            await MainActor.run {
                activityTypes = types
                selectedType = types.first?.key ?? ""
                isLoading = false
            }

        } catch {
            await MainActor.run {
                print("Error loading activity types: \(error)")
                errorMessage = "Failed to load activity types"
                isLoading = false
            }
        }
    }

    private func saveEntry() async {
        guard !selectedType.isEmpty else {
            errorMessage = "Please select an activity type"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            let userId = try await supabase.auth.session.user.id

            let endTime = startDateTime.addingTimeInterval(durationMinutes * 60)

            let metadata = ActivityEntryMetadata(
                activitySubtype: selectedType,
                notes: notes.isEmpty ? nil : notes
            )

            let entry = ActivitySampleInsert(
                patientId: userId,
                quantityType: config.quantityType,
                quantityValue: durationMinutes,
                quantityUnit: "minutes",
                startTime: startDateTime,
                endTime: endTime,
                source: "wellpath_input",
                userTimezone: TimeZone.current.identifier,
                metadata: metadata
            )

            try await supabase
                .from("patient_quantity_samples")
                .insert(entry)
                .execute()

            await MainActor.run {
                onSave?()
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

struct ActivityTypeOption: Codable {
    let key: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case key = "reference_key"
        case displayName = "display_name"
    }
}

struct ActivityEntryMetadata: Codable {
    let activitySubtype: String
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case activitySubtype = "activity_subtype"
        case notes
    }
}

struct ActivitySampleInsert: Codable {
    let patientId: UUID
    let quantityType: String
    let quantityValue: Double
    let quantityUnit: String
    let startTime: Date
    let endTime: Date
    let source: String
    let userTimezone: String
    let metadata: ActivityEntryMetadata

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

// MARK: - Activity Type Picker Sheet

struct ActivityTypePickerSheet: View {
    let activityTypes: [ActivityTypeOption]
    @Binding var selectedType: String
    @Binding var searchText: String
    let color: Color

    @Environment(\.dismiss) private var dismiss

    var filteredTypes: [ActivityTypeOption] {
        if searchText.isEmpty {
            return activityTypes
        }
        return activityTypes.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredTypes, id: \.key) { option in
                    Button {
                        selectedType = option.key
                        dismiss()
                    } label: {
                        HStack {
                            Text(option.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedType == option.key {
                                Image(systemName: "checkmark")
                                    .foregroundColor(color)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search types")
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

#Preview {
    ActivityEntryView(config: .mindfulness)
}
