//
//  AddTherapeuticView.swift
//  WellPath
//
//  Form to add a new therapeutic (medication, supplement, or peptide).
//

import SwiftUI

struct AddTherapeuticView: View {
    @ObservedObject var viewModel: TherapeuticsViewModel
    let therapeuticType: TherapeuticType
    @Environment(\.dismiss) private var dismiss

    // Basic Info
    @State private var therapeuticName = ""
    @State private var category = ""

    // Dosing
    @State private var doseAmount = ""
    @State private var doseUnit: DoseUnit = .mg
    @State private var dosesPerDay = 1

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
    @State private var trackAdherence = true

    @State private var isSaving = false

    private var categories: [String] {
        switch therapeuticType {
        case .medication:
            return TherapeuticCategory.medicationCategories
        case .supplement:
            return TherapeuticCategory.supplementCategories
        case .peptide:
            return TherapeuticCategory.peptideCategories
        case .hormone:
            return TherapeuticCategory.hormoneCategories
        case .other:
            return ["Other"]
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Basic Info
                Section {
                    TextField("\(therapeuticType.displayName) Name", text: $therapeuticName)

                    Picker("Category", selection: $category) {
                        Text("Select...").tag("")
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                } header: {
                    Label(therapeuticType.displayName, systemImage: therapeuticType.icon)
                }

                // Dosing
                Section {
                    HStack {
                        TextField("Amount", text: $doseAmount)
                            .keyboardType(.decimalPad)
                            .frame(maxWidth: 100)

                        Picker("Unit", selection: $doseUnit) {
                            ForEach(DoseUnit.allCases) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Stepper("Doses per day: \(dosesPerDay)", value: $dosesPerDay, in: 1...10)
                } header: {
                    Text("Dosing")
                }

                // Timing
                Section {
                    Toggle("Morning", isOn: $timingMorning)
                    Toggle("Midday", isOn: $timingMidday)
                    Toggle("Evening", isOn: $timingEvening)
                    Toggle("Bedtime", isOn: $timingBedtime)

                    Divider()

                    Toggle("Take with food", isOn: $timingWithFood)

                    TextField("Special instructions (optional)", text: $timingInstructions)
                } header: {
                    Text("When to Take")
                }

                // Start Date
                Section {
                    Toggle("Add Start Date", isOn: $hasStartDate)

                    if hasStartDate {
                        DatePicker("Started", selection: $startDate, displayedComponents: .date)
                    }
                } header: {
                    Text("Timeline")
                }

                // Additional Details
                Section {
                    if therapeuticType == .medication || therapeuticType == .hormone {
                        TextField("Prescriber (optional)", text: $prescriberName)
                    }

                    TextField("Reason for taking (optional)", text: $reasonForTaking)

                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Details")
                }

                // Tracking
                Section {
                    Toggle("Track daily adherence", isOn: $trackAdherence)
                } header: {
                    Text("Tracking")
                } footer: {
                    Text("When enabled, you'll be prompted to log when you take this \(therapeuticType.displayName.lowercased()).")
                }
            }
            .navigationTitle("Add \(therapeuticType.displayName)")
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
                    .disabled(therapeuticName.isEmpty || isSaving)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveTherapeutic() {
        isSaving = true

        Task {
            await viewModel.addTherapeutic(
                therapeuticName: therapeuticName,
                therapeuticType: therapeuticType,
                category: category.isEmpty ? nil : category,
                doseAmount: Double(doseAmount),
                doseUnit: doseUnit.rawValue,
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

            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Edit Therapeutic View

struct EditTherapeuticView: View {
    let therapeutic: PatientTherapeutic
    @ObservedObject var viewModel: TherapeuticsViewModel
    @Environment(\.dismiss) private var dismiss

    // Dosing
    @State private var doseAmount: String
    @State private var doseUnit: DoseUnit
    @State private var dosesPerDay: Int

    // Timing
    @State private var timingMorning: Bool
    @State private var timingMidday: Bool
    @State private var timingEvening: Bool
    @State private var timingBedtime: Bool
    @State private var timingWithFood: Bool
    @State private var timingInstructions: String

    // Additional
    @State private var prescriberName: String
    @State private var reasonForTaking: String
    @State private var notes: String
    @State private var trackAdherence: Bool

    // Actions
    @State private var showDiscontinueSheet = false
    @State private var showDeleteConfirmation = false
    @State private var discontinueReason = ""
    @State private var isSaving = false

    init(therapeutic: PatientTherapeutic, viewModel: TherapeuticsViewModel) {
        self.therapeutic = therapeutic
        self.viewModel = viewModel

        _doseAmount = State(initialValue: therapeutic.doseAmount.map { String($0) } ?? "")
        _doseUnit = State(initialValue: DoseUnit(rawValue: therapeutic.doseUnit ?? "mg") ?? .mg)
        _dosesPerDay = State(initialValue: therapeutic.dosesPerDay ?? 1)
        _timingMorning = State(initialValue: therapeutic.timingMorning ?? false)
        _timingMidday = State(initialValue: therapeutic.timingMidday ?? false)
        _timingEvening = State(initialValue: therapeutic.timingEvening ?? false)
        _timingBedtime = State(initialValue: therapeutic.timingBedtime ?? false)
        _timingWithFood = State(initialValue: therapeutic.timingWithFood ?? false)
        _timingInstructions = State(initialValue: therapeutic.timingInstructions ?? "")
        _prescriberName = State(initialValue: therapeutic.prescriberName ?? "")
        _reasonForTaking = State(initialValue: therapeutic.reasonForTaking ?? "")
        _notes = State(initialValue: therapeutic.notes ?? "")
        _trackAdherence = State(initialValue: therapeutic.trackAdherence ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Read-only info
                Section {
                    LabeledContent(therapeutic.type.displayName, value: therapeutic.therapeuticName)

                    if let category = therapeutic.category {
                        LabeledContent("Category", value: category)
                    }

                    if let startDate = therapeutic.parsedStartDate {
                        LabeledContent("Started", value: startDate.formatted(date: .abbreviated, time: .omitted))
                    }

                    // Status
                    HStack {
                        Text("Status")
                        Spacer()
                        if therapeutic.isActive == true {
                            Text("Active")
                                .foregroundColor(.green)
                        } else {
                            Text("Discontinued")
                                .foregroundColor(.gray)
                        }
                    }
                } header: {
                    Label(therapeutic.type.displayName, systemImage: therapeutic.type.icon)
                }

                // Dosing
                Section {
                    HStack {
                        TextField("Amount", text: $doseAmount)
                            .keyboardType(.decimalPad)
                            .frame(maxWidth: 100)

                        Picker("Unit", selection: $doseUnit) {
                            ForEach(DoseUnit.allCases) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Stepper("Doses per day: \(dosesPerDay)", value: $dosesPerDay, in: 1...10)
                } header: {
                    Text("Dosing")
                }

                // Timing
                Section {
                    Toggle("Morning", isOn: $timingMorning)
                    Toggle("Midday", isOn: $timingMidday)
                    Toggle("Evening", isOn: $timingEvening)
                    Toggle("Bedtime", isOn: $timingBedtime)

                    Divider()

                    Toggle("Take with food", isOn: $timingWithFood)

                    TextField("Special instructions", text: $timingInstructions)
                } header: {
                    Text("When to Take")
                }

                // Additional Details
                Section {
                    if therapeutic.type == .medication || therapeutic.type == .hormone {
                        TextField("Prescriber", text: $prescriberName)
                    }

                    TextField("Reason for taking", text: $reasonForTaking)

                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Details")
                }

                // Tracking
                Section {
                    Toggle("Track daily adherence", isOn: $trackAdherence)
                } header: {
                    Text("Tracking")
                }

                // Actions
                Section {
                    if therapeutic.isActive == true {
                        Button {
                            showDiscontinueSheet = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Discontinue")
                                Spacer()
                            }
                        }
                        .foregroundColor(.orange)
                    } else {
                        Button {
                            Task {
                                await viewModel.reactivateTherapeutic(therapeuticId: therapeutic.id)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Text("Reactivate")
                                Spacer()
                            }
                        }
                        .foregroundColor(.green)
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit \(therapeutic.type.displayName)")
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
            .sheet(isPresented: $showDiscontinueSheet) {
                discontinueSheet
            }
            .confirmationDialog("Delete this \(therapeutic.type.displayName.lowercased())?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteTherapeutic(therapeuticId: therapeutic.id)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    private var discontinueSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Reason (optional)", text: $discontinueReason, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Why are you discontinuing this \(therapeutic.type.displayName.lowercased())?")
                } footer: {
                    Text("This helps track your medication history.")
                }
            }
            .navigationTitle("Discontinue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showDiscontinueSheet = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Confirm") {
                        Task {
                            await viewModel.discontinueTherapeutic(
                                therapeuticId: therapeutic.id,
                                reason: discontinueReason.isEmpty ? nil : discontinueReason
                            )
                            showDiscontinueSheet = false
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func saveChanges() {
        isSaving = true

        Task {
            await viewModel.updateTherapeutic(
                therapeuticId: therapeutic.id,
                doseAmount: Double(doseAmount),
                doseUnit: doseUnit.rawValue,
                dosesPerDay: dosesPerDay,
                timingMorning: timingMorning,
                timingMidday: timingMidday,
                timingEvening: timingEvening,
                timingBedtime: timingBedtime,
                timingWithFood: timingWithFood,
                timingInstructions: timingInstructions.isEmpty ? nil : timingInstructions,
                prescriberName: prescriberName.isEmpty ? nil : prescriberName,
                reasonForTaking: reasonForTaking.isEmpty ? nil : reasonForTaking,
                notes: notes.isEmpty ? nil : notes,
                trackAdherence: trackAdherence
            )

            isSaving = false
            dismiss()
        }
    }
}

#Preview {
    AddTherapeuticView(
        viewModel: TherapeuticsViewModel(),
        therapeuticType: .medication
    )
}
