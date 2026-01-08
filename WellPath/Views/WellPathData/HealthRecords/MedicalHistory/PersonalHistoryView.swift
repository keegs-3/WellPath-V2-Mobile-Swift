//
//  PersonalHistoryView.swift
//  WellPath
//
//  View for managing personal medical history.
//  Shows conditions grouped by category with add/edit/delete.
//

import SwiftUI

struct PersonalHistoryView: View {
    @StateObject private var viewModel: MedicalHistoryViewModel
    let color: Color

    @State private var showAddCondition = false

    init(viewModel: MedicalHistoryViewModel? = nil, color: Color = .red) {
        _viewModel = StateObject(wrappedValue: viewModel ?? MedicalHistoryViewModel())
        self.color = color
    }
    @State private var selectedEntry: HistoryEntry?
    @State private var showMarkComplete = false

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                if viewModel.isLoading {
                    loadingView
                } else {
                    contentView
                }
            }
        }
        .navigationTitle("Personal History")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddCondition = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(color)
                }
            }
        }
        .sheet(isPresented: $showAddCondition) {
            AddHistoryConditionView(
                viewModel: viewModel,
                scope: .personal,
                color: color
            )
        }
        .sheet(item: $selectedEntry) { entry in
            EditHistoryConditionView(
                viewModel: viewModel,
                entry: entry,
                color: color
            )
        }
        .alert("Mark Personal History Complete?", isPresented: $showMarkComplete) {
            Button("Cancel", role: .cancel) { }
            Button("Mark Complete") {
                Task {
                    await viewModel.markPersonalComplete()
                }
            }
        } message: {
            Text("This confirms you've added all your personal medical conditions. You can still edit this later.")
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        if viewModel.personalHistory.isEmpty {
            emptyStateView
        } else {
            conditionsList
        }
    }

    // MARK: - Conditions List

    private var conditionsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Group by category
                ForEach(HistoryCategory.sorted, id: \.self) { category in
                    if let entries = viewModel.personalByCategory[category], !entries.isEmpty {
                        CategorySection(
                            category: category,
                            entries: entries,
                            onSelect: { entry in
                                selectedEntry = entry
                            },
                            onDelete: { entry in
                                Task {
                                    await viewModel.deleteCondition(id: entry.id)
                                }
                            }
                        )
                    }
                }

                // Mark Complete Button
                if !viewModel.isPersonalComplete {
                    markCompleteButton
                }

                Spacer(minLength: 40)
            }
            .padding()
        }
    }

    // MARK: - Category Section

    struct CategorySection: View {
        let category: HistoryCategory
        let entries: [HistoryEntry]
        let onSelect: (HistoryEntry) -> Void
        let onDelete: (HistoryEntry) -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: category.icon)
                        .font(.subheadline)
                        .foregroundColor(category.color)

                    Text(category.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(entries.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)

                // Conditions
                ForEach(entries) { entry in
                    PersonalConditionCard(
                        entry: entry,
                        onTap: { onSelect(entry) },
                        onDelete: { onDelete(entry) }
                    )
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cross.case")
                .font(.system(size: 56))
                .foregroundColor(.secondary)

            Text("No Personal Conditions")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Add any medical conditions you have been diagnosed with, including past conditions.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                showAddCondition = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Condition")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(color)
                .cornerRadius(12)
            }
            .padding(.top, 8)

            // Mark as complete if no conditions
            if !viewModel.isPersonalComplete {
                Button {
                    showMarkComplete = true
                } label: {
                    Text("I have no personal medical conditions")
                        .font(.subheadline)
                        .foregroundColor(color)
                }
                .padding(.top, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Mark Complete Button

    private var markCompleteButton: some View {
        Button {
            showMarkComplete = true
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Mark Personal History Complete")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .cornerRadius(12)
        }
        .padding(.top, 8)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading...")
                .foregroundColor(.secondary)
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
                        color.opacity(0.3),
                        color.opacity(0.2),
                        color.opacity(0.1),
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

// MARK: - Personal Condition Card

struct PersonalConditionCard: View {
    let entry: HistoryEntry
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    Image(systemName: entry.icon)
                        .font(.subheadline)
                        .foregroundColor(entry.color)

                    Text(entry.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    // Confirmed badge
                    if entry.sample.isConfirmed == true {
                        Text("Confirmed")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(6)
                    }
                }

                // Diagnosis info
                if !entry.sample.diagnosisDescription.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text(entry.sample.diagnosisDescription)
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                }

                // Notes
                if let notes = entry.sample.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                // Actions
                HStack {
                    Spacer()

                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.8))
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .confirmationDialog(
            "Remove \(entry.displayName)?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

#Preview {
    NavigationStack {
        PersonalHistoryView(
            viewModel: MedicalHistoryViewModel(),
            color: .red
        )
    }
}
