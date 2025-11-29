//
//  AddMedicalConditionView.swift
//  WellPath
//
//  Form to add a new medical condition (personal or family history).
//

import SwiftUI

struct AddMedicalConditionView: View {
    let historyType: String  // "personal" or "family"
    @ObservedObject var viewModel: MedicalHistoryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var conditionName = ""
    @State private var conditionCategory = "General"
    @State private var familyMember = "parent"
    @State private var diagnosedAt = Date()
    @State private var hasDiagnosisDate = false
    @State private var notes = ""
    @State private var isSaving = false

    let categories = ["General", "Cardiovascular", "Metabolic", "Cancer", "Neurological", "Autoimmune", "Mental Health", "Respiratory", "Musculoskeletal", "Other"]

    let familyMembers = [
        ("parent", "Parent"),
        ("mother", "Mother"),
        ("father", "Father"),
        ("sibling", "Sibling"),
        ("grandparent", "Grandparent"),
        ("child", "Child"),
        ("aunt_uncle", "Aunt/Uncle")
    ]

    var body: some View {
        NavigationStack {
            Form {
                // Condition info
                Section {
                    TextField("Condition Name", text: $conditionName)

                    Picker("Category", selection: $conditionCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                } header: {
                    Text("Condition")
                }

                // Family member (only for family history)
                if historyType == "family" {
                    Section {
                        Picker("Family Member", selection: $familyMember) {
                            ForEach(familyMembers, id: \.0) { member in
                                Text(member.1).tag(member.0)
                            }
                        }
                    } header: {
                        Text("Family Member")
                    }
                }

                // Diagnosis date
                Section {
                    Toggle("Add Diagnosis Date", isOn: $hasDiagnosisDate)

                    if hasDiagnosisDate {
                        DatePicker("Diagnosed", selection: $diagnosedAt, displayedComponents: .date)
                    }
                } header: {
                    Text("Timeline")
                }

                // Notes
                Section {
                    TextField("Additional notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Notes")
                }
            }
            .navigationTitle(historyType == "personal" ? "Add Condition" : "Add Family History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCondition()
                    }
                    .disabled(conditionName.isEmpty || isSaving)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveCondition() {
        isSaving = true

        Task {
            await viewModel.addCondition(
                conditionId: UUID().uuidString, // Generate a new ID
                conditionName: conditionName,
                conditionCategory: conditionCategory,
                historyType: historyType,
                familyMemberRelationship: historyType == "family" ? familyMember : nil,
                diagnosisDate: hasDiagnosisDate ? diagnosedAt : nil,
                notes: notes.isEmpty ? nil : notes
            )

            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Edit Medical Condition View

struct EditMedicalConditionView: View {
    let condition: PatientCondition
    @ObservedObject var viewModel: MedicalHistoryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var status: String
    @State private var severity: String
    @State private var notes: String
    @State private var isSaving = false

    let statusOptions = ["active", "resolved", "managed", "in_remission"]
    let severityOptions = ["mild", "moderate", "severe", "unknown"]

    init(condition: PatientCondition, viewModel: MedicalHistoryViewModel) {
        self.condition = condition
        self.viewModel = viewModel
        _status = State(initialValue: condition.status ?? "active")
        _severity = State(initialValue: condition.severity ?? "unknown")
        _notes = State(initialValue: condition.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                // Condition info (read-only)
                Section {
                    LabeledContent("Condition", value: condition.conditionName)

                    if let category = condition.conditionCategory {
                        LabeledContent("Category", value: category)
                    }

                    if let relationship = condition.familyMemberRelationship {
                        LabeledContent("Family Member", value: relationship.capitalized)
                    }

                    if let diagnosed = condition.diagnosisDate {
                        LabeledContent("Diagnosed", value: diagnosed.formatted(date: .abbreviated, time: .omitted))
                    }
                } header: {
                    Text("Condition Details")
                }

                // Status and Severity
                Section {
                    Picker("Status", selection: $status) {
                        ForEach(statusOptions, id: \.self) { option in
                            Text(option.replacingOccurrences(of: "_", with: " ").capitalized).tag(option)
                        }
                    }

                    Picker("Severity", selection: $severity) {
                        ForEach(severityOptions, id: \.self) { option in
                            Text(option.capitalized).tag(option)
                        }
                    }
                } header: {
                    Text("Status")
                }

                // Notes
                Section {
                    TextField("Additional notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Notes")
                }
            }
            .navigationTitle("Edit Condition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(isSaving)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveChanges() {
        isSaving = true

        Task {
            await viewModel.updateCondition(
                conditionId: condition.id,
                severity: severity,
                status: status,
                notes: notes.isEmpty ? nil : notes
            )

            isSaving = false
            dismiss()
        }
    }
}

#Preview {
    AddMedicalConditionView(
        historyType: "personal",
        viewModel: MedicalHistoryViewModel()
    )
}
