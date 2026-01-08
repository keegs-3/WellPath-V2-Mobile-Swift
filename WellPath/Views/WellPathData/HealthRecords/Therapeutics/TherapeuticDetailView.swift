//
//  TherapeuticDetailView.swift
//  WellPath
//
//  Detail view for a patient's therapeutic with edit, discontinue, and history.
//  Shows current dosing info, adherence stats, and management actions.
//

import SwiftUI

struct TherapeuticDetailView: View {
    let therapeutic: PatientTherapeutic
    @StateObject private var viewModel = TherapeuticsViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showingEditSheet = false
    @State private var showingDiscontinueAlert = false
    @State private var discontinueReason = ""
    @State private var showingDeleteAlert = false

    private var color: Color {
        therapeutic.type.color
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header card
                headerCard

                // Status badge
                if therapeutic.isActive == false {
                    discontinuedBadge
                }

                // Dosing info
                dosingCard

                // Timing info
                timingCard

                // Notes/Details
                if hasDetails {
                    detailsCard
                }

                // Actions
                actionsCard

                Spacer(minLength: 40)
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(therapeutic.therapeuticName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    if therapeutic.isActive == true {
                        Button(role: .destructive) {
                            showingDiscontinueAlert = true
                        } label: {
                            Label("Discontinue", systemImage: "stop.circle")
                        }
                    } else {
                        Button {
                            reactivate()
                        } label: {
                            Label("Reactivate", systemImage: "arrow.uturn.backward")
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditTherapeuticView(therapeutic: therapeutic)
        }
        .alert("Discontinue \(therapeutic.therapeuticName)?", isPresented: $showingDiscontinueAlert) {
            TextField("Reason (optional)", text: $discontinueReason)
            Button("Cancel", role: .cancel) {
                discontinueReason = ""
            }
            Button("Discontinue", role: .destructive) {
                discontinue()
            }
        } message: {
            Text("This will mark the therapeutic as discontinued. You can reactivate it later if needed.")
        }
        .alert("Delete \(therapeutic.therapeuticName)?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                delete()
            }
        } message: {
            Text("This will permanently delete this therapeutic and all associated data. This cannot be undone.")
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: therapeutic.type.icon)
                    .font(.title)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(therapeutic.therapeuticName)
                    .font(.title2)
                    .fontWeight(.bold)

                HStack(spacing: 8) {
                    Text(therapeutic.type.displayName)
                        .font(.subheadline)
                        .foregroundColor(color)

                    if let category = therapeutic.category {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(category)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                if let startDate = therapeutic.parsedStartDate {
                    Text("Started \(startDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Discontinued Badge

    private var discontinuedBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "stop.circle.fill")
                .foregroundColor(.red)

            VStack(alignment: .leading, spacing: 2) {
                Text("Discontinued")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let reason = therapeutic.discontinuedReason {
                    Text(reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let endDate = therapeutic.parsedEndDate {
                    Text("Ended \(endDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button("Reactivate") {
                reactivate()
            }
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.blue)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Dosing Card

    private var dosingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dosing")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                InfoRow(label: "Amount", value: therapeutic.doseDescription)
                InfoRow(label: "Frequency", value: therapeutic.frequencyDescription)

                if let doses = therapeutic.dosesPerDay, doses > 1 {
                    InfoRow(label: "Daily Total", value: calculateDailyTotal())
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Timing Card

    private var timingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("When to Take")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            // Time of day pills
            HStack(spacing: 8) {
                if therapeutic.timingMorning == true {
                    TimingPill(label: "Morning", icon: "sun.max.fill", color: .orange)
                }
                if therapeutic.timingMidday == true {
                    TimingPill(label: "Midday", icon: "sun.min.fill", color: .yellow)
                }
                if therapeutic.timingEvening == true {
                    TimingPill(label: "Evening", icon: "sunset.fill", color: .blue)
                }
                if therapeutic.timingBedtime == true {
                    TimingPill(label: "Bedtime", icon: "moon.fill", color: .purple)
                }

                if !hasAnyTiming {
                    Text("No specific timing set")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if therapeutic.timingWithFood == true {
                HStack(spacing: 6) {
                    Image(systemName: "fork.knife")
                        .font(.caption)
                        .foregroundColor(color)
                    Text("Take with food")
                        .font(.subheadline)
                }
            }

            if let instructions = therapeutic.timingInstructions, !instructions.isEmpty {
                Text(instructions)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                if let prescriber = therapeutic.prescriberName, !prescriber.isEmpty {
                    InfoRow(label: "Prescriber", value: prescriber)
                }
                if let reason = therapeutic.reasonForTaking, !reason.isEmpty {
                    InfoRow(label: "Reason", value: reason)
                }
                if let notes = therapeutic.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(notes)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Actions Card

    private var actionsCard: some View {
        VStack(spacing: 12) {
            Button {
                showingEditSheet = true
            } label: {
                HStack {
                    Image(systemName: "pencil")
                    Text("Edit Dosing & Timing")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(color)
                .cornerRadius(12)
            }

            if therapeutic.isActive == true {
                Button {
                    showingDiscontinueAlert = true
                } label: {
                    HStack {
                        Image(systemName: "stop.circle")
                        Text("Discontinue")
                    }
                    .font(.headline)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
            } else {
                Button {
                    reactivate()
                } label: {
                    HStack {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Reactivate")
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Helpers

    private var hasAnyTiming: Bool {
        therapeutic.timingMorning == true ||
        therapeutic.timingMidday == true ||
        therapeutic.timingEvening == true ||
        therapeutic.timingBedtime == true
    }

    private var hasDetails: Bool {
        (therapeutic.prescriberName != nil && !therapeutic.prescriberName!.isEmpty) ||
        (therapeutic.reasonForTaking != nil && !therapeutic.reasonForTaking!.isEmpty) ||
        (therapeutic.notes != nil && !therapeutic.notes!.isEmpty)
    }

    private func calculateDailyTotal() -> String {
        guard let amount = therapeutic.doseAmount,
              let doses = therapeutic.dosesPerDay else {
            return ""
        }
        let total = amount * Double(doses)
        let unit = therapeutic.doseUnit ?? ""
        return "\(total.formatted()) \(unit)"
    }

    // MARK: - Actions

    private func discontinue() {
        Task {
            await viewModel.discontinueTherapeutic(
                therapeuticId: therapeutic.id,
                reason: discontinueReason.isEmpty ? nil : discontinueReason
            )
            discontinueReason = ""
            dismiss()
        }
    }

    private func reactivate() {
        Task {
            await viewModel.reactivateTherapeutic(therapeuticId: therapeutic.id)
            dismiss()
        }
    }

    private func delete() {
        Task {
            await viewModel.deleteTherapeutic(therapeuticId: therapeutic.id)
            dismiss()
        }
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Timing Pill

private struct TimingPill: View {
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(label)
                .font(.caption)
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .cornerRadius(16)
    }
}

// MARK: - Edit Therapeutic View

struct EditTherapeuticView: View {
    let therapeutic: PatientTherapeutic
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TherapeuticsViewModel()

    // Dosing
    @State private var doseAmount: Double?
    @State private var selectedUnitId: String
    @State private var dosesPerDay: Int

    // Timing
    @State private var timingMorning: Bool
    @State private var timingMidday: Bool
    @State private var timingEvening: Bool
    @State private var timingBedtime: Bool
    @State private var timingWithFood: Bool
    @State private var timingInstructions: String

    // Details
    @State private var prescriberName: String
    @State private var reasonForTaking: String
    @State private var notes: String
    @State private var trackAdherence: Bool

    @State private var isSaving = false

    init(therapeutic: PatientTherapeutic) {
        self.therapeutic = therapeutic
        _doseAmount = State(initialValue: therapeutic.doseAmount)
        _selectedUnitId = State(initialValue: therapeutic.doseUnit ?? "mg")
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

    private var color: Color {
        therapeutic.type.color
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Dosing card
                    TherapeuticDosingCard(
                        therapeutic: nil,
                        doseAmount: $doseAmount,
                        selectedUnitId: $selectedUnitId,
                        dosesPerDay: $dosesPerDay,
                        availableUnits: viewModel.unitOptions,
                        color: color,
                        fallbackUnit: therapeutic.doseUnit
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
                        timingGuidance: nil
                    )

                    // Details section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Details")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        if therapeutic.type == .medication || therapeutic.type == .hormone {
                            TextField("Prescriber (optional)", text: $prescriberName)
                                .font(.subheadline)
                                .padding(12)
                                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                .cornerRadius(8)
                        }

                        TextField("Reason for taking (optional)", text: $reasonForTaking)
                            .font(.subheadline)
                            .padding(12)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground))
                            .cornerRadius(8)

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

                    // Tracking toggle
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(trackAdherence ? color : .secondary)
                        Text("Track daily adherence")
                            .font(.subheadline)
                        Spacer()
                        Toggle("", isOn: $trackAdherence)
                            .labelsHidden()
                            .tint(color)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(12)

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Edit \(therapeutic.therapeuticName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .disabled(isSaving)
                    .fontWeight(.semibold)
                }
            }
        }
        .task {
            await viewModel.loadUnitOptions(for: therapeutic.therapeuticName)
        }
    }

    private func save() {
        isSaving = true
        Task {
            await viewModel.updateTherapeutic(
                therapeuticId: therapeutic.id,
                doseAmount: doseAmount,
                doseUnit: selectedUnitId,
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
    NavigationStack {
        TherapeuticDetailView(
            therapeutic: PatientTherapeutic(
                id: UUID(),
                patientId: UUID(),
                therapeuticBaseId: nil,
                therapeuticName: "NMN",
                therapeuticType: "SUP",
                category: "NAD+ Precursor",
                doseAmount: 500,
                doseUnit: "mg",
                dosesPerDay: 1,
                timingMorning: true,
                timingMidday: false,
                timingEvening: false,
                timingBedtime: false,
                timingWithFood: false,
                timingInstructions: "Take on empty stomach",
                startDate: "2024-01-15",
                endDate: nil,
                prescriberName: nil,
                prescriptionNumber: nil,
                pharmacyName: nil,
                refillsRemaining: nil,
                trackAdherence: true,
                reminderEnabled: false,
                reminderTimes: nil,
                reasonForTaking: "Longevity support",
                notes: "Started after research on NAD+ benefits",
                isActive: true,
                discontinuedReason: nil,
                discontinuedDate: nil,
                dataSource: "manual",
                createdAt: nil,
                updatedAt: nil
            )
        )
    }
}
