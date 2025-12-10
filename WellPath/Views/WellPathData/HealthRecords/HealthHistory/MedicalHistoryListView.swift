//
//  MedicalHistoryListView.swift
//  WellPath
//
//  Main view for personal and family medical history.
//  Shows conditions grouped by type with ability to add/edit.
//

import SwiftUI

struct MedicalHistoryListView: View {
    @StateObject private var viewModel = MedicalHistoryViewModel()
    @State private var showAddCondition = false
    @State private var selectedCondition: PatientCondition?
    @State private var showingType: HistoryDisplayType = .personal

    enum HistoryDisplayType: String, CaseIterable {
        case personal = "Personal"
        case family = "Family"
    }

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                // Segmented control
                Picker("History Type", selection: $showingType) {
                    ForEach(HistoryDisplayType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.error {
                    errorView(error)
                } else {
                    contentView
                }
            }
        }
        .navigationTitle("Medical History")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddCondition = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showAddCondition) {
            AddMedicalConditionView(
                historyType: showingType == .personal ? "personal" : "family",
                viewModel: viewModel
            )
        }
        .sheet(item: $selectedCondition) { condition in
            EditMedicalConditionView(condition: condition, viewModel: viewModel)
        }
        .task {
            await viewModel.loadConditions()
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        let conditions = showingType == .personal ? viewModel.personalConditions : viewModel.familyConditions

        return Group {
            if conditions.isEmpty {
                emptyStateView
            } else {
                conditionsList(conditions)
            }
        }
    }

    // MARK: - Conditions List

    private func conditionsList(_ conditions: [PatientCondition]) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(conditions) { condition in
                    ConditionCard(condition: condition) {
                        selectedCondition = condition
                    } onDelete: {
                        Task {
                            await viewModel.deleteCondition(conditionId: condition.id)
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: showingType == .personal ? "cross.case" : "figure.2.and.child.holdinghands")
                .font(.system(size: 56))
                .foregroundColor(.secondary)

            Text("No \(showingType.rawValue) History")
                .font(.title3)
                .fontWeight(.semibold)

            Text(showingType == .personal
                ? "Add any medical conditions you've been diagnosed with."
                : "Add medical conditions from your immediate family members.")
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
                .background(Color.red)
                .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading medical history...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Something went wrong")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
            Button("Try Again") {
                Task {
                    await viewModel.loadConditions()
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)

            VStack(spacing: 0) {
                LinearGradient(
                    colors: [
                        Color.red.opacity(0.3),
                        Color.red.opacity(0.2),
                        Color.red.opacity(0.1),
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

// MARK: - Condition Card

struct ConditionCard: View {
    let condition: PatientCondition
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(condition.conditionName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let category = condition.conditionCategory {
                        Text(category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Status badge
                if condition.isActive == true {
                    Text("Active")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(6)
                } else {
                    Text("Resolved")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(6)
                }
            }

            // Family member (for family history)
            if let relationship = condition.familyMemberRelationship, condition.historyType == "family" {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .font(.caption)
                    Text(relationship.capitalized)
                        .font(.subheadline)
                }
                .foregroundColor(.secondary)
            }

            // Dates
            if let diagnosedAt = condition.diagnosisDate {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text("Diagnosed: \(diagnosedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            // Notes
            if let notes = condition.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Action buttons
            HStack {
                Button {
                    onEdit()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("Edit")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }

                Spacer()

                Button {
                    showDeleteConfirmation = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Remove")
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .confirmationDialog(
            "Remove this condition?",
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
        MedicalHistoryListView()
    }
}
