//
//  ReassessmentEntryView.swift
//  WellPath
//
//  Main entry point for the smart reassessment flow.
//  Shows summary of data-driven updates and category-level prompts.
//

import SwiftUI

struct ReassessmentEntryView: View {
    @StateObject private var viewModel = ReassessmentViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showProposedChanges = false
    @State private var selectedCategory: SurveyCategory?
    @State private var showCompletionAlert = false
    @State private var showInfoSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.error {
                    errorView(error)
                } else {
                    contentView
                }
            }
            .navigationTitle("Reassessment")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showInfoSheet = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
            .sheet(isPresented: $showInfoSheet) {
                ReassessmentInfoSheet()
            }
            .task {
                await viewModel.loadReassessmentData()
            }
            .sheet(isPresented: $showProposedChanges) {
                ProposedChangesView(viewModel: viewModel)
            }
            .sheet(item: $selectedCategory) { category in
                CategoryCheckInView(
                    category: category,
                    viewModel: viewModel,
                    onComplete: {
                        selectedCategory = nil
                    }
                )
            }
            .alert("Complete Reassessment?", isPresented: $showCompletionAlert) {
                Button("Not Yet", role: .cancel) { }
                Button("Complete") {
                    Task {
                        do {
                            try await viewModel.completeReassessment()
                            dismiss()
                        } catch {
                            print("Error completing reassessment: \(error)")
                        }
                    }
                }
            } message: {
                Text("This will start your new health plan based on your updated responses.")
            }
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Data-driven updates summary
                if !viewModel.proposedChanges.isEmpty {
                    dataDrivenUpdatesCard
                }

                // Category check-ins
                if !viewModel.categoriesWithoutTracking.isEmpty {
                    categoryCheckInsSection
                }

                // Info note about medical history
                medicalHistoryNote

                // Complete button
                completeButton
            }
            .padding()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            Text("Time for a Check-in")
                .font(.title2)
                .fontWeight(.bold)

            Text("Based on your tracked data over the last 90 days, we've identified some suggested updates to your health profile.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }

    // MARK: - Data-Driven Updates Card

    private var dataDrivenUpdatesCard: some View {
        Button {
            showProposedChanges = true
        } label: {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundColor(.blue)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(viewModel.proposedChangeCount) suggested updates")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Spacer()

                        if viewModel.acceptedChangeIds.count + viewModel.keptChangeIds.count == viewModel.proposedChangeCount {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }

                    Text("from your tracked data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // Progress indicator
                    if viewModel.proposedChangeCount > 0 {
                        let addressed = viewModel.acceptedChangeIds.count + viewModel.keptChangeIds.count
                        ProgressView(value: Double(addressed), total: Double(viewModel.proposedChangeCount))
                            .tint(.blue)
                            .padding(.top, 4)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category Check-ins Section

    private var categoryCheckInsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Check-ins")
                .font(.headline)
                .foregroundColor(.primary)

            Text("For areas we couldn't track, let's do a quick check:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                ForEach(viewModel.categoriesWithoutTracking) { category in
                    CategoryCheckInRow(
                        category: category,
                        status: viewModel.categoryCheckInStatus[category.categoryId] ?? .notReviewed,
                        onNoChanges: {
                            viewModel.markCategoryNoChanges(category.categoryId)
                        },
                        onReview: {
                            selectedCategory = category
                        }
                    )
                }
            }
        }
    }

    // MARK: - Medical History Note

    private var medicalHistoryNote: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Medical History")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Personal and family medical history is now in the Data tab, editable anytime.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Complete Button

    private var completeButton: some View {
        Button {
            showCompletionAlert = true
        } label: {
            HStack {
                Image(systemName: viewModel.isReassessmentComplete ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                Text(viewModel.isReassessmentComplete ? "Complete Reassessment" : "Review Remaining Items")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.isReassessmentComplete ? Color.green : Color.blue)
            .cornerRadius(12)
        }
        .disabled(!viewModel.isReassessmentComplete)
        .opacity(viewModel.isReassessmentComplete ? 1.0 : 0.6)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Analyzing your tracked data...")
                .foregroundColor(.secondary)
        }
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
                    await viewModel.loadReassessmentData()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

// MARK: - Category Check-in Row

struct CategoryCheckInRow: View {
    let category: SurveyCategory
    let status: CategoryCheckInStatus
    let onNoChanges: () -> Void
    let onReview: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            statusIcon

            // Category name
            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                statusText
            }

            Spacer()

            // Action buttons
            if status == .notReviewed || status == .needsReview {
                HStack(spacing: 8) {
                    Button("No changes") {
                        onNoChanges()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(8)

                    Button("Review") {
                        onReview()
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }

    private var statusIcon: some View {
        Group {
            switch status {
            case .notReviewed, .needsReview:
                Image(systemName: "circle")
                    .foregroundColor(.gray.opacity(0.5))
            case .noChanges:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .reviewed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .font(.title3)
    }

    @ViewBuilder
    private var statusText: some View {
        switch status {
        case .notReviewed:
            Text("Any changes since last time?")
                .font(.caption)
                .foregroundColor(.secondary)
        case .needsReview:
            Text("Needs review")
                .font(.caption)
                .foregroundColor(.orange)
        case .noChanges:
            Text("No changes")
                .font(.caption)
                .foregroundColor(.green)
        case .reviewed:
            Text("Reviewed")
                .font(.caption)
                .foregroundColor(.blue)
        }
    }
}

#Preview {
    ReassessmentEntryView()
}
