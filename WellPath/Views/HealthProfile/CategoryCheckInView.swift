//
//  CategoryCheckInView.swift
//  WellPath
//
//  Quick check-in view for survey categories without tracked data.
//  Prompts users: "Any changes to X since last time?"
//

import SwiftUI

struct CategoryCheckInView: View {
    let category: SurveyCategory
    @ObservedObject var viewModel: ReassessmentViewModel
    let onComplete: () -> Void

    @StateObject private var healthProfileViewModel = HealthProfileViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showFullQuestions = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                contentView
            }
            .navigationTitle(category.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showFullQuestions) {
                // Show the full question flow for this category
                if let firstGroup = category.groups.first {
                    QuestionFlowView(
                        group: firstGroup,
                        viewModel: healthProfileViewModel,
                        onDismiss: {
                            showFullQuestions = false
                            viewModel.markCategoryReviewed(category.categoryId)
                            onComplete()
                        }
                    )
                }
            }
            .task {
                // Load the category's questions for potential review
                await healthProfileViewModel.loadData()
            }
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon and question
            questionHeader

            // Info about what this category covers
            categoryInfoCard

            Spacer()

            // Action buttons
            actionButtons
        }
        .padding()
    }

    // MARK: - Question Header

    private var questionHeader: some View {
        VStack(spacing: 16) {
            // Category icon
            Image(systemName: categoryIcon)
                .font(.system(size: 56))
                .foregroundColor(categoryColor)

            // Main question
            Text("Have there been any changes to your \(category.displayName.lowercased()) since your last assessment?")
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Category Info Card

    private var categoryInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This covers topics like:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Show group names in this category
            VStack(alignment: .leading, spacing: 8) {
                ForEach(category.groups.prefix(4)) { group in
                    HStack(spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundColor(categoryColor)
                        Text(group.displayName)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }

                if category.groups.count > 4 {
                    Text("...and \(category.groups.count - 4) more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 14)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // No changes button
            Button {
                viewModel.markCategoryNoChanges(category.categoryId)
                onComplete()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle")
                    Text("No Changes")
                }
                .font(.headline)
                .foregroundColor(.green)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green, lineWidth: 1)
                )
                .cornerRadius(12)
            }

            // Review questions button
            Button {
                showFullQuestions = true
            } label: {
                HStack {
                    Image(systemName: "pencil.circle.fill")
                    Text("Review & Update")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }

            // Help text
            Text("Select 'No Changes' if nothing has changed since your last assessment.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Helpers

    private var categoryIcon: String {
        switch category.categoryId.lowercased() {
        case let id where id.contains("substance"):
            return "wineglass"
        case let id where id.contains("supplement"):
            return "pills"
        case let id where id.contains("mental") || id.contains("stress"):
            return "brain.head.profile"
        case let id where id.contains("social"):
            return "person.2"
        case let id where id.contains("environment"):
            return "leaf"
        case let id where id.contains("medical"):
            return "cross.case"
        case let id where id.contains("family"):
            return "figure.2.and.child.holdinghands"
        default:
            return "questionmark.circle"
        }
    }

    private var categoryColor: Color {
        switch category.categoryId.lowercased() {
        case let id where id.contains("substance"):
            return .orange
        case let id where id.contains("supplement"):
            return .purple
        case let id where id.contains("mental") || id.contains("stress"):
            return .indigo
        case let id where id.contains("social"):
            return .teal
        case let id where id.contains("environment"):
            return .green
        case let id where id.contains("medical"):
            return .red
        case let id where id.contains("family"):
            return .pink
        default:
            return .blue
        }
    }
}

#Preview {
    CategoryCheckInView(
        category: SurveyCategory(
            id: UUID(),
            categoryId: "substance_use",
            sectionId: "lifestyle",
            displayName: "Substance Use",
            description: "Alcohol, tobacco, and other substances",
            categoryOrder: 1,
            sectionOrder: 1,
            groups: []
        ),
        viewModel: ReassessmentViewModel(),
        onComplete: {}
    )
}
