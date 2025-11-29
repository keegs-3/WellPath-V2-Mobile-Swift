//
//  ActiveExceptionsView.swift
//  WellPath
//
//  Displays active and past life exceptions.
//  Allows users to view, resolve, or delete exceptions.
//

import SwiftUI

struct ActiveExceptionsView: View {
    @ObservedObject var viewModel: HealthProfileViewModel
    @State private var showLogException = false
    @State private var showResolveConfirmation = false
    @State private var exceptionToResolve: PlanException?
    @State private var showDeleteConfirmation = false
    @State private var exceptionToDelete: PlanException?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.activeExceptions.isEmpty && !viewModel.isLoading {
                    emptyView
                } else {
                    exceptionsList
                }
            }
            .navigationTitle("Life Exceptions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showLogException = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showLogException) {
                LogExceptionView(viewModel: viewModel) {
                    showLogException = false
                }
            }
            .alert("Resolve Exception?", isPresented: $showResolveConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Resolve") {
                    if let exception = exceptionToResolve {
                        resolveException(exception)
                    }
                }
            } message: {
                Text("This will mark the exception as resolved and resume normal adherence tracking.")
            }
            .alert("Delete Exception?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let exception = exceptionToDelete {
                        deleteException(exception)
                    }
                }
            } message: {
                Text("This will permanently remove this exception from your records.")
            }
            .task {
                await viewModel.refreshExceptions()
            }
        }
    }

    // MARK: - Exceptions List

    private var exceptionsList: some View {
        List {
            // Active exceptions
            if !activeExceptions.isEmpty {
                Section {
                    ForEach(activeExceptions) { exception in
                        ExceptionRow(exception: exception, isActive: true)
                            .swipeActions(edge: .trailing) {
                                Button {
                                    exceptionToResolve = exception
                                    showResolveConfirmation = true
                                } label: {
                                    Label("Resolve", systemImage: "checkmark.circle")
                                }
                                .tint(.green)

                                Button(role: .destructive) {
                                    exceptionToDelete = exception
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    Text("Active Exceptions")
                } footer: {
                    Text("Swipe left to resolve or delete")
                }
            }

            // Resolved exceptions
            if !resolvedExceptions.isEmpty {
                Section {
                    ForEach(resolvedExceptions) { exception in
                        ExceptionRow(exception: exception, isActive: false)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    exceptionToDelete = exception
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    Text("Past Exceptions")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 56))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Exceptions")
                    .font(.headline)

                Text("When life gets in the way of your health goals, you can log an exception here to track it.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showLogException = true
            } label: {
                Label("Log an Exception", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Computed Properties

    private var activeExceptions: [PlanException] {
        viewModel.activeExceptions.filter { $0.isActive }
    }

    private var resolvedExceptions: [PlanException] {
        viewModel.activeExceptions.filter { !$0.isActive }
    }

    // MARK: - Actions

    private func resolveException(_ exception: PlanException) {
        Task {
            try? await viewModel.resolveException(exception)
        }
    }

    private func deleteException(_ exception: PlanException) {
        Task {
            try? await viewModel.deleteException(exception)
        }
    }
}

// MARK: - Exception Row

struct ExceptionRow: View {
    let exception: PlanException
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            Image(systemName: exception.exceptionType.iconName)
                .font(.title3)
                .foregroundColor(isActive ? .orange : .secondary)
                .frame(width: 40, height: 40)
                .background((isActive ? Color.orange : Color.gray).opacity(0.15))
                .cornerRadius(10)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(exception.exceptionType.displayName)
                        .font(.headline)

                    if isActive {
                        Text("Active")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(4)
                    }
                }

                if !exception.reasonText.isEmpty {
                    Text(exception.reasonText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                // Duration info
                HStack(spacing: 8) {
                    Label(dateRangeText, systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let pillars = exception.affectedPillars, !pillars.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)

                        Text(exception.affectedPillarsDisplay)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        if isActive {
            if let endDate = exception.endDate {
                return "\(formatter.string(from: exception.startDate)) – \(formatter.string(from: endDate))"
            } else {
                return "Since \(formatter.string(from: exception.startDate))"
            }
        } else {
            if let resolved = exception.resolvedAt {
                let relativeFormatter = RelativeDateTimeFormatter()
                relativeFormatter.unitsStyle = .abbreviated
                let relativeString = relativeFormatter.localizedString(for: resolved, relativeTo: Date())
                return "\(exception.daysActive) days (resolved \(relativeString))"
            } else if let endDate = exception.endDate {
                return "\(formatter.string(from: exception.startDate)) – \(formatter.string(from: endDate))"
            } else {
                return formatter.string(from: exception.startDate)
            }
        }
    }
}

// MARK: - Exception Badge (for pillar cards)

struct ExceptionBadge: View {
    let count: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
            if count > 0 {
                Text("\(count)")
                    .font(.caption2)
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(.orange)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(6)
    }
}

// MARK: - Exception Summary Card (for dashboard)

struct ExceptionSummaryCard: View {
    let exceptions: [PlanException]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(exceptions.count) Active Exception\(exceptions.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(affectedPillarsText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private var affectedPillarsText: String {
        let allPillars = exceptions.compactMap { $0.affectedPillars }.flatMap { $0 }
        let uniquePillars = Set(allPillars)

        if uniquePillars.isEmpty {
            return "All areas affected"
        } else {
            return uniquePillars.map { $0.capitalized }.joined(separator: ", ") + " affected"
        }
    }
}

#Preview("List View") {
    ActiveExceptionsView(viewModel: HealthProfileViewModel())
}

#Preview("Exception Badge") {
    HStack(spacing: 16) {
        ExceptionBadge(count: 1)
        ExceptionBadge(count: 3)
    }
    .padding()
}

#Preview("Summary Card") {
    ExceptionSummaryCard(
        exceptions: [
            PlanException(
                patientId: UUID(),
                exceptionType: .lifeEvent,
                reasonText: "New baby",
                affectedPillars: ["sleep", "movement"],
                startDate: Date()
            )
        ]
    ) {
        print("Tapped")
    }
    .padding()
}
