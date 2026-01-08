//
//  AddHistoryConditionView.swift
//  WellPath
//
//  Form for adding a new medical history condition.
//  Handles both personal and family history with appropriate fields.
//

import SwiftUI

struct AddHistoryConditionView: View {
    @ObservedObject var viewModel: MedicalHistoryViewModel
    let scope: HistoryScope
    let color: Color

    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var selectedCategory: HistoryCategory?
    @State private var selectedHistoryType: HistoryType?
    @State private var searchText = ""

    // Personal fields
    @State private var ageAtDiagnosis: Int?
    @State private var diagnosisYear: Int?
    @State private var isConfirmed = true

    // Family fields
    @State private var selectedRelativeType: RelativeType?
    @State private var relativeCount = 1
    @State private var isDeceasedFromCondition = false

    // Common fields
    @State private var notes = ""
    @State private var isSaving = false

    private var canSave: Bool {
        guard selectedHistoryType != nil else { return false }
        if scope == .family && selectedRelativeType == nil { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                // Category Selection
                categorySection

                // Condition Selection (when category selected)
                if let category = selectedCategory {
                    conditionSection(for: category)
                }

                // Details (when condition selected)
                if selectedHistoryType != nil {
                    if scope == .personal {
                        personalDetailsSection
                    } else {
                        familyDetailsSection
                    }

                    notesSection
                }
            }
            .navigationTitle(scope == .personal ? "Add Personal Condition" : "Add Family Condition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCondition()
                    }
                    .disabled(!canSave || isSaving)
                }
            }
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        Section {
            ForEach(HistoryCategory.sorted, id: \.self) { category in
                Button {
                    withAnimation {
                        selectedCategory = category
                        selectedHistoryType = nil
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: category.icon)
                            .font(.body)
                            .foregroundColor(category.color)
                            .frame(width: 28)

                        Text(category.displayName)
                            .foregroundColor(.primary)

                        Spacer()

                        if selectedCategory == category {
                            Image(systemName: "checkmark")
                                .foregroundColor(color)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Category")
        }
    }

    // MARK: - Condition Section

    private func conditionSection(for category: HistoryCategory) -> some View {
        Section {
            // Search field
            TextField("Search conditions...", text: $searchText)
                .textFieldStyle(.roundedBorder)

            // Filtered conditions
            let filteredTypes = viewModel.filteredHistoryTypes(for: category)
                .filter { type in
                    searchText.isEmpty || type.displayName.localizedCaseInsensitiveContains(searchText)
                }

            if filteredTypes.isEmpty {
                Text("No conditions found")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(filteredTypes, id: \.historyType) { type in
                    Button {
                        withAnimation {
                            selectedHistoryType = type
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.displayName)
                                    .foregroundColor(.primary)

                                if let desc = type.description {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            if selectedHistoryType?.historyType == type.historyType {
                                Image(systemName: "checkmark")
                                    .foregroundColor(color)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            Text("Condition")
        }
    }

    // MARK: - Personal Details Section

    private var personalDetailsSection: some View {
        Section {
            // Age at diagnosis
            HStack {
                Text("Age at Diagnosis")
                Spacer()
                TextField("Optional", value: $ageAtDiagnosis, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            // Diagnosis year
            HStack {
                Text("Year Diagnosed")
                Spacer()
                TextField("Optional", value: $diagnosisYear, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            // Confirmed
            Toggle("Diagnosis Confirmed", isOn: $isConfirmed)
        } header: {
            Text("Diagnosis Details")
        } footer: {
            Text("\"Confirmed\" means you have medical records or doctor confirmation.")
        }
    }

    // MARK: - Family Details Section

    private var familyDetailsSection: some View {
        Section {
            // Relative type picker
            Picker("Relative", selection: $selectedRelativeType) {
                Text("Select...").tag(nil as RelativeType?)

                // First degree relatives
                Section("First Degree (Higher Risk)") {
                    ForEach(viewModel.firstDegreeRelatives, id: \.relativeType) { relative in
                        Text(relative.displayName).tag(relative as RelativeType?)
                    }
                }

                // Second degree relatives
                Section("Second Degree") {
                    ForEach(viewModel.secondDegreeRelatives, id: \.relativeType) { relative in
                        Text(relative.displayName).tag(relative as RelativeType?)
                    }
                }
            }

            // Number of relatives with this condition
            Stepper("Number of relatives: \(relativeCount)", value: $relativeCount, in: 1...10)

            // Age at diagnosis
            HStack {
                Text("Their Age at Diagnosis")
                Spacer()
                TextField("Optional", value: $ageAtDiagnosis, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            // Deceased from condition
            Toggle("Passed Away From This", isOn: $isDeceasedFromCondition)
        } header: {
            Text("Family Member Details")
        } footer: {
            Text("First-degree relatives (parents, siblings, children) have the strongest impact on your risk assessment.")
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        Section {
            TextEditor(text: $notes)
                .frame(minHeight: 80)
        } header: {
            Text("Notes (Optional)")
        } footer: {
            Text("Add any additional details about this condition.")
        }
    }

    // MARK: - Save

    private func saveCondition() {
        guard let historyType = selectedHistoryType else { return }

        isSaving = true

        Task {
            if scope == .personal {
                await viewModel.addPersonalCondition(
                    historyType: historyType.historyType,
                    ageAtDiagnosis: ageAtDiagnosis,
                    diagnosisYear: diagnosisYear,
                    isConfirmed: isConfirmed,
                    notes: notes.isEmpty ? nil : notes
                )
            } else {
                guard let relativeType = selectedRelativeType else {
                    isSaving = false
                    return
                }

                await viewModel.addFamilyCondition(
                    historyType: historyType.historyType,
                    relativeType: relativeType.relativeType,
                    relativeCount: relativeCount,
                    ageAtDiagnosis: ageAtDiagnosis,
                    isDeceasedFromCondition: isDeceasedFromCondition,
                    notes: notes.isEmpty ? nil : notes
                )
            }

            dismiss()
        }
    }
}

// MARK: - Edit View

struct EditHistoryConditionView: View {
    @ObservedObject var viewModel: MedicalHistoryViewModel
    let entry: HistoryEntry
    let color: Color

    @Environment(\.dismiss) private var dismiss

    // Form state (initialized from entry)
    @State private var ageAtDiagnosis: Int?
    @State private var diagnosisYear: Int?
    @State private var isConfirmed: Bool
    @State private var selectedRelativeType: RelativeType?
    @State private var relativeCount: Int
    @State private var isDeceasedFromCondition: Bool
    @State private var notes: String
    @State private var isSaving = false

    init(viewModel: MedicalHistoryViewModel, entry: HistoryEntry, color: Color) {
        self.viewModel = viewModel
        self.entry = entry
        self.color = color

        // Initialize state from entry
        _ageAtDiagnosis = State(initialValue: entry.sample.ageAtDiagnosis)
        _diagnosisYear = State(initialValue: entry.sample.diagnosisYear)
        _isConfirmed = State(initialValue: entry.sample.isConfirmed ?? true)
        _selectedRelativeType = State(initialValue: entry.relative)
        _relativeCount = State(initialValue: entry.sample.relativeCount ?? 1)
        _isDeceasedFromCondition = State(initialValue: entry.sample.isDeceasedFromCondition ?? false)
        _notes = State(initialValue: entry.sample.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                // Condition info (read-only)
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: entry.icon)
                            .font(.title3)
                            .foregroundColor(entry.color)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.displayName)
                                .font(.headline)

                            Text(entry.category.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Condition")
                }

                // Editable fields based on scope
                if entry.sample.isPersonal {
                    personalEditSection
                } else {
                    familyEditSection
                }

                notesEditSection
            }
            .navigationTitle("Edit Condition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    // MARK: - Personal Edit Section

    private var personalEditSection: some View {
        Section {
            HStack {
                Text("Age at Diagnosis")
                Spacer()
                TextField("Optional", value: $ageAtDiagnosis, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            HStack {
                Text("Year Diagnosed")
                Spacer()
                TextField("Optional", value: $diagnosisYear, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            Toggle("Diagnosis Confirmed", isOn: $isConfirmed)
        } header: {
            Text("Diagnosis Details")
        }
    }

    // MARK: - Family Edit Section

    private var familyEditSection: some View {
        Section {
            Picker("Relative", selection: $selectedRelativeType) {
                Text("Select...").tag(nil as RelativeType?)

                Section("First Degree (Higher Risk)") {
                    ForEach(viewModel.firstDegreeRelatives, id: \.relativeType) { relative in
                        Text(relative.displayName).tag(relative as RelativeType?)
                    }
                }

                Section("Second Degree") {
                    ForEach(viewModel.secondDegreeRelatives, id: \.relativeType) { relative in
                        Text(relative.displayName).tag(relative as RelativeType?)
                    }
                }
            }

            Stepper("Number of relatives: \(relativeCount)", value: $relativeCount, in: 1...10)

            HStack {
                Text("Their Age at Diagnosis")
                Spacer()
                TextField("Optional", value: $ageAtDiagnosis, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            Toggle("Passed Away From This", isOn: $isDeceasedFromCondition)
        } header: {
            Text("Family Member Details")
        }
    }

    // MARK: - Notes Edit Section

    private var notesEditSection: some View {
        Section {
            TextEditor(text: $notes)
                .frame(minHeight: 80)
        } header: {
            Text("Notes")
        }
    }

    // MARK: - Save Changes

    private func saveChanges() {
        isSaving = true

        Task {
            await viewModel.updateCondition(
                id: entry.id,
                relativeType: selectedRelativeType?.relativeType,
                relativeCount: entry.sample.isFamily ? relativeCount : nil,
                ageAtDiagnosis: ageAtDiagnosis,
                diagnosisYear: entry.sample.isPersonal ? diagnosisYear : nil,
                isConfirmed: entry.sample.isPersonal ? isConfirmed : nil,
                isDeceasedFromCondition: entry.sample.isFamily ? isDeceasedFromCondition : nil,
                notes: notes.isEmpty ? nil : notes
            )

            dismiss()
        }
    }
}

#Preview("Add Personal") {
    AddHistoryConditionView(
        viewModel: MedicalHistoryViewModel(),
        scope: .personal,
        color: .red
    )
}

#Preview("Add Family") {
    AddHistoryConditionView(
        viewModel: MedicalHistoryViewModel(),
        scope: .family,
        color: .red
    )
}
