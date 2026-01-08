//
//  WizardView.swift
//  WellPath
//
//  Main wizard container shown on first app launch.
//  Hierarchical navigation: Pillars → Categories → Questions
//  Shows pillar cards with completion rings (like My Data section).
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
                    pillarListView
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

    // MARK: - Pillar List View (Hierarchical)

    private var pillarListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Overall progress ring at top
                overallProgressHeader

                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else {
                    // Pillar cards with completion rings
                    ForEach(viewModel.pillarsWithBaselines, id: \.pillar) { pillarData in
                        NavigationLink {
                            PillarBaselineCategoriesView(
                                pillar: pillarData.pillar,
                                categories: pillarData.categories,
                                viewModel: viewModel
                            )
                        } label: {
                            BaselinePillarCard(pillarData: pillarData)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Complete button
                if viewModel.allCategoriesComplete {
                    completeButton
                }
            }
            .padding()
        }
        .background(
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [
                            Color.green.opacity(0.45),
                            Color.green.opacity(0.25),
                            Color.green.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 400)
                    Spacer()
                }
            }
            .ignoresSafeArea()
        )
        .navigationTitle("Set Your Baselines")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Overall Progress Header

    private var overallProgressHeader: some View {
        VStack(spacing: 12) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: viewModel.overallProgress)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(Int(viewModel.overallProgress * 100))")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Status text
            VStack(spacing: 4) {
                Text("\(viewModel.completedCount) of \(viewModel.categories.count) complete")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if viewModel.allCategoriesComplete {
                    Label("All Done!", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
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
}

// MARK: - Baseline Pillar Card

struct BaselinePillarCard: View {
    let pillarData: PillarBaselineData

    private var completionFraction: CGFloat {
        guard pillarData.totalCategories > 0 else { return 0 }
        return CGFloat(pillarData.completedCategories) / CGFloat(pillarData.totalCategories)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(pillarData.color.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: pillarData.icon)
                    .font(.title3)
                    .foregroundColor(pillarData.color)
            }

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(pillarData.pillar)
                    .font(.headline)
                    .foregroundColor(.primary)

                if pillarData.completedCategories == pillarData.totalCategories {
                    Text("COMPLETE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                } else {
                    Text("\(pillarData.completedCategories) of \(pillarData.totalCategories) categories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(pillarData.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Completion ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0, to: completionFraction)
                    .stroke(pillarData.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                if pillarData.completedCategories == pillarData.totalCategories {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                } else {
                    Text("\(Int(completionFraction * 100))")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(pillarData.color)
                }
            }

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Pillar Baseline Categories View

struct PillarBaselineCategoriesView: View {
    let pillar: String
    let categories: [WizardCategory]
    @ObservedObject var viewModel: WizardViewModel

    private var pillarColor: Color {
        pillarColorFromName(pillar)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(categories) { category in
                    NavigationLink {
                        destinationView(for: category)
                    } label: {
                        categoryRow(category)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [
                            pillarColor.opacity(0.45),
                            pillarColor.opacity(0.25),
                            pillarColor.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 400)
                    Spacer()
                }
            }
            .ignoresSafeArea()
        )
        .navigationTitle(pillar)
        .navigationBarTitleDisplayMode(.large)
    }

    private func categoryRow(_ category: WizardCategory) -> some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(pillarColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: category.iconName)
                    .font(.title3)
                    .foregroundColor(pillarColor)
            }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text(category.isTour ? "Quick tour" : "\(category.questionCount) questions")
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

    @ViewBuilder
    private func destinationView(for category: WizardCategory) -> some View {
        switch category.id {
        // Healthful Nutrition
        case "CAT_PROTEIN":
            ProteinWizardView()
        case "CAT_VEGETABLES":
            VegetablesWizardView()
        case "CAT_FRUITS":
            FruitsWizardView()
        case "CAT_WHOLE_GRAINS":
            WholeGrainsWizardView()
        case "CAT_LEGUMES":
            LegumesWizardView()
        case "CAT_NUTS_SEEDS":
            NutsSeedsWizardView()
        case "CAT_FATS":
            FatsWizardView()
        case "CAT_MEAL_PATTERNS":
            MealPatternsWizardView()
        case "CAT_HYDRATION":
            HydrationWizardView()
        case "CAT_CAFFEINE":
            CaffeineWizardView()
        case "CAT_ULTRA_PROCESSED":
            UltraProcessedWizardView()
        // Movement + Exercise
        case "CAT_STEPS":
            StepsWizardView()
        case "CAT_CARDIO":
            CardioWizardView()
        case "CAT_STRENGTH":
            StrengthWizardView()
        case "CAT_HIIT":
            HIITWizardView()
        case "CAT_MOBILITY":
            MobilityWizardView()
        case "CAT_DAILY_ACTIVITY":
            DailyActivityWizardView()
        // Core Care
        case "CAT_THERAPEUTICS":
            TherapeuticsWizardView()
        default:
            // Placeholder for categories not yet implemented
            Text("Coming soon: \(category.displayName)")
                .navigationTitle(category.displayName)
        }
    }

    private func pillarColorFromName(_ pillar: String) -> Color {
        switch pillar {
        case "Healthful Nutrition": return Color(hex: "8DD8FF") ?? .blue
        case "Movement + Exercise": return Color(hex: "EB875D") ?? .orange
        case "Restorative Sleep": return Color(hex: "80CBC4") ?? .teal
        case "Stress Management": return Color(hex: "ED8D8D") ?? .pink
        case "Cognitive Health": return Color(hex: "C6B5FF") ?? .purple
        case "Connection + Purpose": return Color(hex: "ADD399") ?? .green
        case "Core Care": return Color(hex: "F4D284") ?? .yellow
        default: return .gray
        }
    }
}

// MARK: - Data Models

struct PillarBaselineData {
    let pillar: String
    let description: String
    let icon: String
    let color: Color
    let categories: [WizardCategory]
    let totalCategories: Int
    let completedCategories: Int
}

// Note: Color(hex:) extension is defined in PillarModels.swift

// MARK: - Preview

#Preview {
    WizardView()
}
