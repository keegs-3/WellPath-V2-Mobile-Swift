//
//  GroupListView.swift
//  WellPath
//
//  Shows groups within a category.
//  User can tap a group to start answering questions.
//

import SwiftUI

struct GroupListView: View {
    let category: SurveyCategory
    @ObservedObject var viewModel: HealthProfileViewModel
    @State private var selectedGroup: SurveyGroup?
    @State private var showQuestionFlow = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Category header
                categoryHeader

                // Group list
                groupList
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(category.displayName)
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(isPresented: $showQuestionFlow) {
            if let group = selectedGroup {
                QuestionFlowView(group: group, viewModel: viewModel) {
                    showQuestionFlow = false
                }
            }
        }
    }

    // MARK: - Category Header

    private var categoryHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.displayName)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("\(category.completedGroupCount) of \(category.groups.count) groups completed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Circular progress
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 5)
                        .frame(width: 50, height: 50)

                    Circle()
                        .trim(from: 0, to: categoryProgress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(categoryProgress * 100))%")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
            }

            if let description = category.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Group List

    private var groupList: some View {
        VStack(spacing: 12) {
            ForEach(category.groups) { group in
                GroupCard(group: group) {
                    selectedGroup = group
                    Task {
                        await viewModel.selectGroup(group)
                        showQuestionFlow = true
                    }
                }
            }
        }
    }

    private var categoryProgress: Double {
        guard category.groups.count > 0 else { return 0 }
        return Double(category.completedGroupCount) / Double(category.groups.count)
    }
}

// MARK: - Group Card

struct GroupCard: View {
    let group: SurveyGroup
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Status icon
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    if group.isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    } else if group.answeredCount > 0 {
                        Image(systemName: "circle.lefthalf.filled")
                            .font(.title2)
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "circle")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(group.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Spacer()

                        if group.isComplete {
                            Text("Complete")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        } else if group.questionCount > 0 {
                            Text("\(group.answeredCount)/\(group.questionCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let description = group.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    // Progress bar for incomplete groups
                    if !group.isComplete && group.questionCount > 0 {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 4)
                                    .cornerRadius(2)

                                Rectangle()
                                    .fill(Color.blue)
                                    .frame(width: geometry.size.width * groupProgress, height: 4)
                                    .cornerRadius(2)
                            }
                        }
                        .frame(height: 4)
                    }
                }

                // Chevron
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

    private var statusColor: Color {
        if group.isComplete {
            return .green
        } else if group.answeredCount > 0 {
            return .blue
        } else {
            return .gray
        }
    }

    private var groupProgress: Double {
        guard group.questionCount > 0 else { return 0 }
        return Double(group.answeredCount) / Double(group.questionCount)
    }
}

#Preview {
    NavigationStack {
        GroupListView(
            category: SurveyCategory(
                id: UUID(),
                categoryId: "test",
                sectionId: "section",
                displayName: "Dietary Patterns",
                description: "Your overall eating approaches and meal timing",
                categoryOrder: 1,
                sectionOrder: 1
            ),
            viewModel: HealthProfileViewModel()
        )
    }
}
