//
//  CategoryListView.swift
//  WellPath
//
//  Shows categories within a section.
//  User can tap a category to see groups within it.
//

import SwiftUI

struct CategoryListView: View {
    let section: SurveySection
    @ObservedObject var viewModel: HealthProfileViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Section header with description
                sectionHeader

                // Category list
                categoryList
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(section.displayName)
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: SurveyCategory.self) { category in
            GroupListView(category: category, viewModel: viewModel)
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: section.iconName)
                    .font(.title)
                    .foregroundColor(sectionColor)
                    .frame(width: 50, height: 50)
                    .background(sectionColor.opacity(0.15))
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(section.displayName)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("\(section.completedCategoryCount) of \(section.categories.count) topics completed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            if let description = section.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Progress bar
            ProgressView(value: sectionProgress)
                .tint(sectionColor)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Category List

    private var categoryList: some View {
        VStack(spacing: 12) {
            ForEach(section.categories) { category in
                NavigationLink(value: category) {
                    CategoryCard(category: category, themeColor: sectionColor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private var sectionProgress: Double {
        guard section.categories.count > 0 else { return 0 }
        return Double(section.completedCategoryCount) / Double(section.categories.count)
    }

    private var sectionColor: Color {
        switch section.themeColor {
        case "green": return .green
        case "orange": return .orange
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink": return .pink
        case "teal": return .teal
        case "red": return .red
        default: return .blue
        }
    }
}

// MARK: - Category Card

struct CategoryCard: View {
    let category: SurveyCategory
    let themeColor: Color

    var body: some View {
        HStack(spacing: 16) {
            // Completion indicator
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                    .frame(width: 40, height: 40)

                Circle()
                    .trim(from: 0, to: categoryProgress)
                    .stroke(themeColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))

                if category.isComplete {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(themeColor)
                } else {
                    Text("\(Int(categoryProgress * 100))")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(category.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    if category.isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                if let description = category.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                // Group progress dots
                HStack(spacing: 4) {
                    ForEach(category.groups) { group in
                        Circle()
                            .fill(group.isComplete ? themeColor : Color.gray.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }

                    Spacer()

                    Text("\(category.completedGroupCount) of \(category.groups.count) groups")
                        .font(.caption2)
                        .foregroundColor(.secondary)
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

    private var categoryProgress: Double {
        guard category.groups.count > 0 else { return 0 }
        return Double(category.completedGroupCount) / Double(category.groups.count)
    }
}

#Preview {
    NavigationStack {
        CategoryListView(
            section: SurveySection(
                id: UUID(),
                sectionId: "healthful_nutrition",
                pillar: nil,
                displayName: "Healthful Nutrition",
                sectionOrder: 1,
                description: "Your dietary habits and nutritional intake"
            ),
            viewModel: HealthProfileViewModel()
        )
    }
}
