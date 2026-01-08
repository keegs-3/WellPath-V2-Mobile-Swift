//
//  TherapeuticFormView.swift
//  WellPath
//
//  Complete add therapeutic form with styled cards.
//  Supports both database therapeutics and custom entries.
//  Uses DB-driven unit options, timing guidance, and reminder settings.
//

import SwiftUI

struct TherapeuticFormView: View {
    /// Pre-selected therapeutic from database (nil for custom entry)
    let preselectedTherapeutic: TherapeuticsBase?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TherapeuticsViewModel()

    // Custom entry mode
    @State private var isCustomEntry: Bool
    @State private var customName: String = ""
    @State private var selectedType: TherapeuticType = .supplement
    @State private var customCategory: String = ""

    // Dosing
    @State private var doseAmount: Double?
    @State private var selectedUnitId: String = "mg"
    @State private var dosesPerDay: Int = 1

    // Timing
    @State private var timingMorning = false
    @State private var timingMidday = false
    @State private var timingEvening = false
    @State private var timingBedtime = false
    @State private var timingWithFood = false
    @State private var timingInstructions = ""

    // Dates
    @State private var startDate = Date()
    @State private var hasStartDate = false

    // Additional
    @State private var prescriberName = ""
    @State private var reasonForTaking = ""
    @State private var notes = ""

    // Reminders
    @State private var trackAdherence = true
    @State private var enableReminders = false
    @State private var reminderTimes: [Date] = []

    @State private var isSaving = false

    // MARK: - Init

    init(preselectedTherapeutic: TherapeuticsBase? = nil) {
        self.preselectedTherapeutic = preselectedTherapeutic
        _isCustomEntry = State(initialValue: preselectedTherapeutic == nil)
    }

    // MARK: - Computed Properties

    private var therapeuticType: TherapeuticType {
        if let therapeutic = preselectedTherapeutic {
            return therapeutic.type
        }
        return selectedType
    }

    private var therapeuticName: String {
        preselectedTherapeutic?.therapeuticName ?? customName
    }

    private var color: Color {
        therapeuticType.color
    }

    private var canSave: Bool {
        if isCustomEntry {
            return !customName.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return preselectedTherapeutic != nil
    }

    private var timingGuidance: String? {
        preselectedTherapeutic?.timingGuidance
    }

    private var fallbackUnit: String? {
        preselectedTherapeutic?.therapeuticUnitSymbol ?? preselectedTherapeutic?.therapeuticUnit
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header card (or custom entry fields)
                    if isCustomEntry {
                        customEntryCard
                    } else if let therapeutic = preselectedTherapeutic {
                        therapeuticHeaderCard(therapeutic)
                    }

                    // Dosing card
                    TherapeuticDosingCard(
                        therapeutic: preselectedTherapeutic,
                        doseAmount: $doseAmount,
                        selectedUnitId: $selectedUnitId,
                        dosesPerDay: $dosesPerDay,
                        availableUnits: viewModel.unitOptions,
                        color: color,
                        fallbackUnit: fallbackUnit
                    )

                    // Timing card
                    TherapeuticTimingCard(
                        morning: $timingMorning,
                        midday: $timingMidday,
                        evening: $timingEvening,
                        bedtime: $timingBedtime,
                        withFood: $timingWithFood,
                        instructions: $timingInstructions,
                        color: color,
                        timingGuidance: timingGuidance
                    )

                    // Reminder card
                    TherapeuticReminderCard(
                        trackAdherence: $trackAdherence,
                        enableReminders: $enableReminders,
                        reminderTimes: $reminderTimes,
                        color: color,
                        dosesPerDay: dosesPerDay
                    )

                    // Start date section
                    startDateCard

                    // Details section
                    detailsCard

                    Spacer(minLength: 100)
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(isCustomEntry ? "Add Custom" : "Add \(therapeuticName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTherapeutic()
                    }
                    .disabled(!canSave || isSaving)
                    .fontWeight(.semibold)
                }
            }
            .overlay(alignment: .bottom) {
                saveButton
            }
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Header Card

    private func therapeuticHeaderCard(_ therapeutic: TherapeuticsBase) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: therapeuticType.icon)
                    .font(.title2)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(therapeutic.therapeuticName)
                    .font(.headline)

                if let category = therapeutic.category {
                    Text(category)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    Text(therapeuticType.displayName)
                        .font(.caption)
                        .foregroundColor(color)

                    if !therapeutic.doseRangeDescription.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(therapeutic.doseRangeDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Custom Entry Card

    private var customEntryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Custom Therapeutic")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            // Name field
            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("e.g., My Custom Supplement", text: $customName)
                    .font(.subheadline)
                    .padding(12)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(8)
            }

            // Type picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Type")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TherapeuticType.primaryCases) { type in
                            Button {
                                selectedType = type
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 12))
                                    Text(type.displayName)
                                        .font(.subheadline)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedType == type ? type.color.opacity(0.15) : Color(uiColor: .tertiarySystemGroupedBackground))
                                .foregroundColor(selectedType == type ? type.color : .secondary)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedType == type ? type.color.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Category field (optional)
            VStack(alignment: .leading, spacing: 6) {
                Text("Category (optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("e.g., Vitamin, Herbal, etc.", text: $customCategory)
                    .font(.subheadline)
                    .padding(12)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Start Date Card

    private var startDateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 16))
                    .foregroundColor(hasStartDate ? color : .secondary)
                    .frame(width: 24)

                Text("Track start date")
                    .font(.subheadline)

                Spacer()

                Toggle("", isOn: $hasStartDate)
                    .labelsHidden()
                    .tint(color)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(8)

            if hasStartDate {
                DatePicker(
                    "Started",
                    selection: $startDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.2), value: hasStartDate)
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            // Prescriber (for medications/hormones)
            if therapeuticType == .medication || therapeuticType == .hormone {
                TextField("Prescriber (optional)", text: $prescriberName)
                    .font(.subheadline)
                    .padding(12)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(8)
            }

            // Reason
            TextField("Reason for taking (optional)", text: $reasonForTaking)
                .font(.subheadline)
                .padding(12)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(8)

            // Notes
            TextField("Notes (optional)", text: $notes, axis: .vertical)
                .lineLimit(2...4)
                .font(.subheadline)
                .padding(12)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color(uiColor: .systemGroupedBackground).opacity(0), Color(uiColor: .systemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)

            Button {
                saveTherapeutic()
            } label: {
                HStack {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "plus.circle.fill")
                        Text("Add to My Therapeutics")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(canSave ? color : .gray)
                .cornerRadius(12)
            }
            .disabled(!canSave || isSaving)
            .padding(.horizontal)
            .padding(.bottom)
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        // Load unit options for this therapeutic
        if let therapeutic = preselectedTherapeutic {
            await viewModel.loadUnitOptions(for: therapeutic.therapeuticName)

            // Pre-fill defaults
            prefillFromTherapeutic(therapeutic)
        }
    }

    private func prefillFromTherapeutic(_ therapeutic: TherapeuticsBase) {
        // Pre-fill dose unit
        if let defaultUnit = viewModel.unitOptions.first(where: { $0.isDefault }) {
            selectedUnitId = defaultUnit.unitId
        } else if let unit = therapeutic.therapeuticUnit {
            selectedUnitId = unit
        }

        // Pre-fill suggested dose if available
        if let minDose = therapeutic.therapeuticDoseMin {
            doseAmount = minDose
        }

        // Pre-fill timing from guidance (simple parsing)
        if let guidance = therapeutic.timingGuidance?.lowercased() {
            if guidance.contains("morning") {
                timingMorning = true
            }
            if guidance.contains("empty stomach") || guidance.contains("before meal") {
                timingWithFood = false
            } else if guidance.contains("with food") || guidance.contains("with meal") {
                timingWithFood = true
            }
        }
    }

    // MARK: - Save

    private func saveTherapeutic() {
        isSaving = true

        Task {
            // Convert reminder times to strings
            let reminderTimeStrings: [String]? = enableReminders && !reminderTimes.isEmpty
                ? reminderTimes.map { formatTimeForStorage($0) }
                : nil

            await viewModel.addTherapeutic(
                therapeuticName: therapeuticName,
                therapeuticType: therapeuticType,
                category: isCustomEntry ? (customCategory.isEmpty ? nil : customCategory) : preselectedTherapeutic?.category,
                doseAmount: doseAmount,
                doseUnit: selectedUnitId,
                dosesPerDay: dosesPerDay,
                timingMorning: timingMorning,
                timingMidday: timingMidday,
                timingEvening: timingEvening,
                timingBedtime: timingBedtime,
                timingWithFood: timingWithFood,
                timingInstructions: timingInstructions.isEmpty ? nil : timingInstructions,
                startDate: hasStartDate ? startDate : nil,
                prescriberName: prescriberName.isEmpty ? nil : prescriberName,
                reasonForTaking: reasonForTaking.isEmpty ? nil : reasonForTaking,
                notes: notes.isEmpty ? nil : notes,
                trackAdherence: trackAdherence
            )

            // TODO: Save reminder settings separately if needed
            // This would wire into the existing notification system

            isSaving = false
            dismiss()
        }
    }

    private func formatTimeForStorage(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

#Preview("From Database") {
    TherapeuticFormView(
        preselectedTherapeutic: TherapeuticsBase(
            id: UUID(),
            therapeuticName: "NMN",
            therapeuticType: "SUP",
            category: "NAD+ Precursor",
            overview: "NMN is a precursor to NAD+",
            recommendationText: nil,
            therapeuticOperator: nil,
            therapeuticDoseMin: 500,
            therapeuticDoseMax: 1000,
            therapeuticUnit: "mg",
            therapeuticUnitSymbol: "mg",
            therapeuticDoseRollup: nil,
            therapeuticFrequencyDays: nil,
            therapeuticTiming: nil,
            linkedEvidence: nil,
            ageMin: nil,
            ageMax: nil,
            gender: nil,
            isActive: true,
            createdAt: nil,
            updatedAt: nil,
            mechanismOfAction: nil,
            benefits: nil,
            risksWarnings: nil,
            contraindications: nil,
            dosingGuidance: nil,
            timingGuidance: "Best taken in the morning on an empty stomach",
            longevityRelevance: nil,
            researchSummary: nil,
            commonBrands: nil,
            aiContext: nil
        )
    )
}

#Preview("Custom Entry") {
    TherapeuticFormView(preselectedTherapeutic: nil)
}
