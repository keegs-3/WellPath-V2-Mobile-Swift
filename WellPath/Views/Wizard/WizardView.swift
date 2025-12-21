//
//  WizardView.swift
//  WellPath
//
//  Main wizard container shown on first app launch.
//  Shows overview of WellPath, then sections/categories to set up baselines.
//  Actual baseline UI lives in each category's folder.
//

import SwiftUI

struct WizardView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WizardViewModel()
    @State private var currentPage = 0

    var body: some View {
        NavigationStack {
            Group {
                if currentPage == 0 {
                    welcomeView
                } else {
                    categoryListView
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if currentPage > 0 {
                        Button("Skip") {
                            viewModel.markWizardComplete()
                            dismiss()
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
        .interactiveDismissDisabled(!viewModel.hasCompletedWizard)
    }

    // MARK: - Welcome View

    private var welcomeView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo/Icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
            }

            // Title
            VStack(spacing: 12) {
                Text("Welcome to WellPath")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Your personalized path to better health and longevity")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Features
            VStack(alignment: .leading, spacing: 16) {
                featureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Track Your Progress",
                    description: "Monitor health metrics across 7 pillars"
                )
                featureRow(
                    icon: "target",
                    title: "Personalized Scores",
                    description: "See how your habits impact longevity"
                )
                featureRow(
                    icon: "lightbulb.fill",
                    title: "Actionable Insights",
                    description: "Get recommendations tailored to you"
                )
            }
            .padding(.horizontal, 32)
            .padding(.vertical)

            Spacer()

            // Get Started Button
            Button {
                withAnimation {
                    currentPage = 1
                }
                Task {
                    await viewModel.loadCategories()
                }
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.green)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Category List View

    private var categoryListView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Progress header
                progressHeader

                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else {
                    // Categories grouped by pillar
                    ForEach(groupedCategories, id: \.pillar) { group in
                        pillarSection(pillar: group.pillar, categories: group.categories)
                    }
                }

                // Complete button
                if viewModel.allCategoriesComplete {
                    completeButton
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Set Your Baselines")
        .navigationBarTitleDisplayMode(.large)
    }

    private var progressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(viewModel.completedCount) of \(viewModel.categories.count) complete")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                if viewModel.allCategoriesComplete {
                    Label("All Done!", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green)
                        .frame(
                            width: viewModel.categories.isEmpty ? 0 :
                                geometry.size.width * CGFloat(viewModel.completedCount) / CGFloat(viewModel.categories.count),
                            height: 8
                        )
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func pillarSection(pillar: String, categories: [WizardCategory]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(pillar)
                .font(.headline)
                .foregroundColor(.secondary)

            ForEach(categories) { category in
                categoryRow(category)
            }
        }
    }

    private func categoryRow(_ category: WizardCategory) -> some View {
        NavigationLink {
            destinationView(for: category)
        } label: {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(categoryColor(category.color).opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: category.iconName)
                        .font(.title3)
                        .foregroundColor(categoryColor(category.color))
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text("\(category.questionCount) questions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Status
                if category.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func destinationView(for category: WizardCategory) -> some View {
        switch category.id {
        case "CAT_PROTEIN":
            ProteinBaselineView(color: .green)
        default:
            // Placeholder for categories not yet implemented
            Text("Coming soon: \(category.displayName)")
                .navigationTitle(category.displayName)
        }
    }

    private var completeButton: some View {
        Button {
            viewModel.markWizardComplete()
            dismiss()
        } label: {
            Text("Complete Setup")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
        .padding(.top)
    }

    // MARK: - Helpers

    private var groupedCategories: [(pillar: String, categories: [WizardCategory])] {
        Dictionary(grouping: viewModel.categories, by: { $0.pillar })
            .map { (pillar: $0.key, categories: $0.value) }
            .sorted { $0.pillar < $1.pillar }
    }

    private func categoryColor(_ colorName: String) -> Color {
        switch colorName {
        case "green": return .green
        case "blue": return .blue
        case "orange": return .orange
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink": return .pink
        case "red": return .red
        default: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    WizardView()
}
