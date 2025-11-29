//
//  PreventiveScreeningsView.swift
//  WellPath
//
//  View for tracking preventive health screenings.
//  Shows due dates, last completed, and status.
//

import SwiftUI

struct PreventiveScreeningsView: View {
    @StateObject private var viewModel = MedicalHistoryViewModel()
    @State private var selectedScreening: PatientScreening?
    @State private var showAddScreening = false

    var body: some View {
        ZStack {
            backgroundGradient

            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error {
                errorView(error)
            } else {
                contentView
            }
        }
        .navigationTitle("Preventive Screenings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddScreening = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showAddScreening) {
            AddScreeningView(viewModel: viewModel)
        }
        .sheet(item: $selectedScreening) { screening in
            EditScreeningView(screening: screening, viewModel: viewModel)
        }
        .task {
            await viewModel.loadScreenings()
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        Group {
            if viewModel.screenings.isEmpty {
                emptyStateView
            } else {
                screeningsList
            }
        }
    }

    // MARK: - Screenings List

    private var screeningsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Due Soon section
                let dueSoon = viewModel.screenings.filter { screening in
                    if let dueDate = screening.nextDueDate {
                        return dueDate <= Date().addingTimeInterval(90 * 24 * 60 * 60) // 90 days
                    }
                    return false
                }

                if !dueSoon.isEmpty {
                    sectionHeader("Due Soon", icon: "exclamationmark.triangle.fill", color: .orange)

                    ForEach(dueSoon) { screening in
                        ScreeningCard(screening: screening, screeningTypes: viewModel.screeningTypes) {
                            selectedScreening = screening
                        }
                    }
                }

                // Up to Date section
                let upToDate = viewModel.screenings.filter { screening in
                    if let dueDate = screening.nextDueDate {
                        return dueDate > Date().addingTimeInterval(90 * 24 * 60 * 60)
                    }
                    return screening.screeningStatus == "completed"
                }

                if !upToDate.isEmpty {
                    sectionHeader("Up to Date", icon: "checkmark.seal.fill", color: .green)

                    ForEach(upToDate) { screening in
                        ScreeningCard(screening: screening, screeningTypes: viewModel.screeningTypes) {
                            selectedScreening = screening
                        }
                    }
                }

                // Not Scheduled section
                let notScheduled = viewModel.screenings.filter { screening in
                    return screening.nextDueDate == nil && screening.screeningStatus != "completed"
                }

                if !notScheduled.isEmpty {
                    sectionHeader("Not Scheduled", icon: "calendar.badge.exclamationmark", color: .gray)

                    ForEach(notScheduled) { screening in
                        ScreeningCard(screening: screening, screeningTypes: viewModel.screeningTypes) {
                            selectedScreening = screening
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "stethoscope")
                .font(.system(size: 56))
                .foregroundColor(.secondary)

            Text("No Screenings Tracked")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Track your preventive health screenings like mammograms, colonoscopies, and annual checkups.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                showAddScreening = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Screening")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.teal)
                .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Loading & Error Views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading screenings...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
            Button("Try Again") {
                Task { await viewModel.loadScreenings() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)

            VStack(spacing: 0) {
                LinearGradient(
                    colors: [
                        Color.teal.opacity(0.3),
                        Color.teal.opacity(0.2),
                        Color.teal.opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 300)

                Spacer()
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Screening Card

struct ScreeningCard: View {
    let screening: PatientScreening
    let screeningTypes: [ScreeningType]
    let onEdit: () -> Void

    private var screeningType: ScreeningType? {
        screeningTypes.first { $0.screeningTypeId == screening.screeningTypeId }
    }

    private var statusColor: Color {
        if let dueDate = screening.nextDueDate {
            if dueDate < Date() {
                return .red
            } else if dueDate < Date().addingTimeInterval(90 * 24 * 60 * 60) {
                return .orange
            }
        }

        switch screening.screeningStatus {
        case "completed": return .green
        case "scheduled": return .blue
        case "overdue": return .red
        default: return .gray
        }
    }

    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(screeningType?.screeningName ?? screening.screeningTypeId)
                            .font(.headline)
                            .foregroundColor(.primary)

                        if let interval = screeningType?.recommendedFrequencyMonths {
                            Text("Every \(interval) months")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Status indicator
                    Circle()
                        .fill(statusColor)
                        .frame(width: 12, height: 12)
                }

                // Dates
                HStack(spacing: 16) {
                    if let lastDate = screening.screeningDate {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Last")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(lastDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }

                    if let nextDate = screening.nextDueDate {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Next Due")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(nextDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(nextDate < Date() ? .red : .primary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Screening View

struct AddScreeningView: View {
    @ObservedObject var viewModel: MedicalHistoryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTypeId = ""
    @State private var screeningDate = Date()
    @State private var hasScreeningDate = false
    @State private var nextDueDate = Date()
    @State private var hasNextDueDate = false
    @State private var notes = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Screening Type", selection: $selectedTypeId) {
                        Text("Select...").tag("")
                        ForEach(viewModel.screeningTypes) { type in
                            Text(type.screeningName).tag(type.screeningTypeId)
                        }
                    }
                } header: {
                    Text("Screening")
                }

                Section {
                    Toggle("Add Last Completed Date", isOn: $hasScreeningDate)

                    if hasScreeningDate {
                        DatePicker("Completed", selection: $screeningDate, displayedComponents: .date)
                    }

                    Toggle("Add Next Due Date", isOn: $hasNextDueDate)

                    if hasNextDueDate {
                        DatePicker("Due Date", selection: $nextDueDate, displayedComponents: .date)
                    }
                } header: {
                    Text("Dates")
                }

                Section {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Notes")
                }
            }
            .navigationTitle("Add Screening")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveScreening() }
                        .disabled(selectedTypeId.isEmpty || isSaving)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveScreening() {
        isSaving = true
        Task {
            await viewModel.upsertScreening(
                screeningTypeId: selectedTypeId,
                screeningStatus: hasScreeningDate ? "completed" : "not_scheduled",
                screeningDate: hasScreeningDate ? screeningDate : nil,
                nextDueDate: hasNextDueDate ? nextDueDate : nil,
                notes: notes.isEmpty ? nil : notes
            )
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Edit Screening View

struct EditScreeningView: View {
    let screening: PatientScreening
    @ObservedObject var viewModel: MedicalHistoryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var screeningDate: Date
    @State private var hasScreeningDate: Bool
    @State private var nextDueDate: Date
    @State private var hasNextDueDate: Bool
    @State private var notes: String
    @State private var isSaving = false
    @State private var showDeleteConfirmation = false

    init(screening: PatientScreening, viewModel: MedicalHistoryViewModel) {
        self.screening = screening
        self.viewModel = viewModel
        _screeningDate = State(initialValue: screening.screeningDate ?? Date())
        _hasScreeningDate = State(initialValue: screening.screeningDate != nil)
        _nextDueDate = State(initialValue: screening.nextDueDate ?? Date())
        _hasNextDueDate = State(initialValue: screening.nextDueDate != nil)
        _notes = State(initialValue: screening.notes ?? "")
    }

    private var screeningType: ScreeningType? {
        viewModel.screeningTypes.first { $0.screeningTypeId == screening.screeningTypeId }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Screening", value: screeningType?.screeningName ?? screening.screeningTypeId)

                    if let interval = screeningType?.recommendedFrequencyMonths {
                        LabeledContent("Recommended Interval", value: "\(interval) months")
                    }
                } header: {
                    Text("Screening Details")
                }

                Section {
                    Toggle("Completed", isOn: $hasScreeningDate)

                    if hasScreeningDate {
                        DatePicker("Date Completed", selection: $screeningDate, displayedComponents: .date)
                    }

                    Toggle("Next Due Date", isOn: $hasNextDueDate)

                    if hasNextDueDate {
                        DatePicker("Due Date", selection: $nextDueDate, displayedComponents: .date)
                    }
                } header: {
                    Text("Status")
                }

                Section {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Notes")
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Screening")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Screening")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveChanges() }
                        .disabled(isSaving)
                        .fontWeight(.semibold)
                }
            }
            .confirmationDialog("Delete this screening?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteScreening(screeningId: screening.id)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    private func saveChanges() {
        isSaving = true
        Task {
            await viewModel.upsertScreening(
                screeningTypeId: screening.screeningTypeId,
                screeningStatus: hasScreeningDate ? "completed" : "not_scheduled",
                screeningDate: hasScreeningDate ? screeningDate : nil,
                nextDueDate: hasNextDueDate ? nextDueDate : nil,
                notes: notes.isEmpty ? nil : notes
            )
            isSaving = false
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        PreventiveScreeningsView()
    }
}
