//
//  FamilyHistoryView.swift
//  WellPath
//
//  View for managing family medical history.
//  Shows conditions grouped by category with relative info.
//

import SwiftUI

struct FamilyHistoryView: View {
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
        .navigationTitle("Family History")
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
                scope: .family,
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
        .alert("Mark Family History Complete?", isPresented: $showMarkComplete) {
            Button("Cancel", role: .cancel) { }
            Button("Mark Complete") {
                Task {
                    await viewModel.markFamilyComplete()
                }
            }
        } message: {
            Text("This confirms you've added all known family medical conditions. You can still edit this later.")
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        if viewModel.familyHistory.isEmpty {
            emptyStateView
        } else {
            conditionsList
        }
    }

    // MARK: - Conditions List

    private var conditionsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Risk explanation card
                riskExplanationCard

                // Group by category
                ForEach(HistoryCategory.sorted, id: \.self) { category in
                    if let entries = viewModel.familyByCategory[category], !entries.isEmpty {
                        FamilyCategorySection(
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
                if !viewModel.isFamilyComplete {
                    markCompleteButton
                }

                Spacer(minLength: 40)
            }
            .padding()
        }
    }

    // MARK: - Risk Explanation Card

    private var riskExplanationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("First-Degree Relatives")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Text("Parents, siblings, and children are first-degree relatives. Conditions in first-degree relatives have a stronger impact on your health risk assessment and screening recommendations.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 56))
                .foregroundColor(.secondary)

            Text("No Family Conditions")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Add medical conditions that your family members have been diagnosed with. Focus on parents, siblings, and grandparents.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                showAddCondition = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Family Condition")
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
            if !viewModel.isFamilyComplete {
                Button {
                    showMarkComplete = true
                } label: {
                    Text("I don't know my family history")
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
                Text("Mark Family History Complete")
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

// MARK: - Family Category Section

struct FamilyCategorySection: View {
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
                FamilyConditionCard(
                    entry: entry,
                    onTap: { onSelect(entry) },
                    onDelete: { onDelete(entry) }
                )
            }
        }
    }
}

// MARK: - Family Condition Card

struct FamilyConditionCard: View {
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

                    // First degree badge
                    if entry.isFirstDegreeFamily {
                        Text("1st Degree")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(6)
                    }
                }

                // Relative info
                HStack(spacing: 12) {
                    if let relative = entry.relative {
                        HStack(spacing: 6) {
                            Image(systemName: relative.icon)
                                .font(.caption)
                            Text(relative.displayName)
                                .font(.subheadline)
                        }
                        .foregroundColor(.secondary)
                    }

                    if let age = entry.sample.ageAtDiagnosis {
                        Text("• Age \(age)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // Deceased from condition
                if entry.sample.isDeceasedFromCondition == true {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("Deceased from this condition")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
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
        FamilyHistoryView(
            viewModel: MedicalHistoryViewModel(),
            color: .red
        )
    }
}
