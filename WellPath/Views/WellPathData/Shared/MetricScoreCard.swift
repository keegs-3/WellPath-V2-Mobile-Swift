//
//  MetricScoreCard.swift
//  WellPath
//
//  Generic score card component for any behavioral score metric.
//  Reusable across Protein, Fats, Caffeine, etc.
//

import SwiftUI

// MARK: - Configuration

struct MetricScoreCardConfig {
    let title: String
    let iconName: String
    let emptyStateTitle: String
    let emptyStateSubtitle: String

    static let protein = MetricScoreCardConfig(
        title: "Protein Score",
        iconName: "fish.fill",
        emptyStateTitle: "Set Up Protein Score",
        emptyStateSubtitle: "Complete the baseline wizard to get your protein score"
    )

    static let fats = MetricScoreCardConfig(
        title: "Fats Score",
        iconName: "drop.fill",
        emptyStateTitle: "Set Up Fats Score",
        emptyStateSubtitle: "Complete the baseline wizard to get your fats score"
    )

    static let caffeine = MetricScoreCardConfig(
        title: "Caffeine Score",
        iconName: "cup.and.saucer.fill",
        emptyStateTitle: "Set Up Caffeine Score",
        emptyStateSubtitle: "Complete the baseline wizard to get your caffeine score"
    )

    static let vegetables = MetricScoreCardConfig(
        title: "Vegetable Score",
        iconName: "leaf.fill",
        emptyStateTitle: "Set Up Vegetable Score",
        emptyStateSubtitle: "Complete the baseline wizard to get your vegetable score"
    )

    static let fruits = MetricScoreCardConfig(
        title: "Fruit Score",
        iconName: "apple.logo",
        emptyStateTitle: "Set Up Fruit Score",
        emptyStateSubtitle: "Complete the baseline wizard to get your fruit score"
    )

    static let legumes = MetricScoreCardConfig(
        title: "Legume Score",
        iconName: "circle.grid.3x3.fill",
        emptyStateTitle: "Set Up Legume Score",
        emptyStateSubtitle: "Complete the baseline wizard to get your legume score"
    )

    static let wholeGrains = MetricScoreCardConfig(
        title: "Whole Grain Score",
        iconName: "circle.hexagongrid.fill",
        emptyStateTitle: "Set Up Whole Grain Score",
        emptyStateSubtitle: "Complete the baseline wizard to get your whole grain score"
    )

    static let nutsSeeds = MetricScoreCardConfig(
        title: "Nuts & Seeds Score",
        iconName: "sparkle",
        emptyStateTitle: "Set Up Nuts & Seeds Score",
        emptyStateSubtitle: "Complete the baseline wizard to get your nuts & seeds score"
    )

    static let hydration = MetricScoreCardConfig(
        title: "Hydration Score",
        iconName: "drop.fill",
        emptyStateTitle: "Set Up Hydration Score",
        emptyStateSubtitle: "Complete the baseline wizard to get your hydration score"
    )

    static let mealPatterns = MetricScoreCardConfig(
        title: "Meal Patterns Score",
        iconName: "fork.knife",
        emptyStateTitle: "Set Up Meal Patterns Score",
        emptyStateSubtitle: "Complete the baseline wizard to get your meal patterns score"
    )

    static let ultraProcessed = MetricScoreCardConfig(
        title: "Ultra-Processed Score",
        iconName: "xmark.circle.fill",
        emptyStateTitle: "Set Up Ultra-Processed Score",
        emptyStateSubtitle: "Complete the baseline wizard to get your ultra-processed score"
    )

    static let sleepDuration = MetricScoreCardConfig(
        title: "Sleep Duration Score",
        iconName: "bed.double.fill",
        emptyStateTitle: "Set Up Sleep Duration Score",
        emptyStateSubtitle: "Complete the baseline wizard to get your sleep duration score"
    )

    static let sleep = MetricScoreCardConfig(
        title: "Sleep Score",
        iconName: "moon.fill",
        emptyStateTitle: "Set Up Sleep Score",
        emptyStateSubtitle: "Complete the baseline wizard to get your sleep score"
    )

    static let sleepRoutine = MetricScoreCardConfig(
        title: "Sleep Routine Score",
        iconName: "moon.stars.fill",
        emptyStateTitle: "Assess Sleep Routine",
        emptyStateSubtitle: "Complete the assessment to score your pre-sleep habits"
    )

    static let sleepEnvironment = MetricScoreCardConfig(
        title: "Sleep Environment Score",
        iconName: "bed.double.fill",
        emptyStateTitle: "Assess Sleep Environment",
        emptyStateSubtitle: "Complete the assessment to score your sleep environment"
    )

    // MARK: - Movement Scores

    static let strength = MetricScoreCardConfig(
        title: "Strength Score",
        iconName: "dumbbell.fill",
        emptyStateTitle: "Set Up Strength Score",
        emptyStateSubtitle: "Complete the baseline wizard to get your strength score"
    )

    static let cardio = MetricScoreCardConfig(
        title: "Cardio Score",
        iconName: "heart.fill",
        emptyStateTitle: "Set Up Cardio Score",
        emptyStateSubtitle: "Complete the baseline wizard to get your cardio score"
    )

    static let hiit = MetricScoreCardConfig(
        title: "HIIT Score",
        iconName: "bolt.heart.fill",
        emptyStateTitle: "Set Up HIIT Score",
        emptyStateSubtitle: "Complete the baseline wizard to get your HIIT score"
    )

    static let mobility = MetricScoreCardConfig(
        title: "Mobility Score",
        iconName: "figure.flexibility",
        emptyStateTitle: "Set Up Mobility Score",
        emptyStateSubtitle: "Complete the baseline wizard to get your mobility score"
    )

    static let steps = MetricScoreCardConfig(
        title: "Steps Score",
        iconName: "figure.walk",
        emptyStateTitle: "Set Up Steps Score",
        emptyStateSubtitle: "Complete the baseline wizard to get your steps score"
    )

    static let dailyActivity = MetricScoreCardConfig(
        title: "Daily Activity Score",
        iconName: "flame.fill",
        emptyStateTitle: "Set Up Daily Activity Score",
        emptyStateSubtitle: "Complete the baseline wizard to get your daily activity score"
    )
}

// MARK: - Score Card

struct MetricScoreCard<ViewModel: BehavioralScoreViewModel, DetailView: View>: View {
    let config: MetricScoreCardConfig
    let color: Color
    @ObservedObject var viewModel: ViewModel
    let detailViewBuilder: () -> DetailView
    var onSetupTapped: (() -> Void)?  // Optional - if provided, tapping empty state opens wizard

    @State private var showingDetail = false

    private var displayScore: Int? {
        if let daily = viewModel.dailyScore {
            return Int(daily)
        } else if viewModel.hasScore {
            return viewModel.scoreValue
        }
        return nil
    }

    private var hasDailyScore: Bool {
        viewModel.dailyScore != nil
    }

    /// Whether to show the "Set Up" empty state
    /// Baseline must be set before showing any scores (even if daily data exists)
    private var showEmptyState: Bool {
        !viewModel.hasBaselineData
    }

    var body: some View {
        Button {
            if showEmptyState, let onSetup = onSetupTapped {
                onSetup()
            } else {
                showingDetail = true
            }
        } label: {
            if showEmptyState {
                // Empty state - show "Set Up" prompt
                emptyStateContent
            } else {
                // Has data - show score card
                scoreContent
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            detailViewBuilder()
        }
    }

    // MARK: - Score Content (has data)

    private var scoreContent: some View {
        HStack(spacing: 16) {
            ScoreRingPill(
                score: displayScore,
                iconName: config.iconName,
                label: config.title.replacingOccurrences(of: " Score", with: ""),
                size: 70
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(config.title)
                    .font(.headline)
                    .foregroundColor(.primary)

                if hasDailyScore {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(scoreColor)
                            .frame(width: 8, height: 8)
                        Text("Today")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("·")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(scoreStatus)
                            .font(.caption)
                            .foregroundColor(scoreColor)
                    }
                } else if viewModel.hasScore {
                    HStack(spacing: 4) {
                        Image(systemName: "book.fill")
                            .font(.caption)
                        Text("Baseline")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text("No data today")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Empty State Content (no data)

    private var emptyStateContent: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                    .frame(width: 60, height: 60)

                Image(systemName: config.iconName)
                    .font(.title2)
                    .foregroundColor(.gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(config.title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("Set your baseline to get started")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("Set Up")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(color)
                .cornerRadius(16)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var scoreStatus: String {
        guard let score = displayScore else { return "" }
        if score >= 80 { return "Excellent" }
        else if score >= 60 { return "Good" }
        else if score >= 40 { return "Fair" }
        else { return "Needs work" }
    }

    private var scoreColor: Color {
        guard let score = displayScore else { return .secondary }
        if score >= 80 { return .green }
        else if score >= 60 { return .yellow }
        else if score >= 40 { return .orange }
        else { return .red }
    }
}

// MARK: - Empty State Card

struct MetricScoreEmptyCard: View {
    let config: MetricScoreCardConfig
    let color: Color
    let onSetupTapped: () -> Void

    var body: some View {
        Button(action: onSetupTapped) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                        .frame(width: 60, height: 60)

                    Image(systemName: config.iconName)
                        .font(.title2)
                        .foregroundColor(.gray)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(config.title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Set your baseline to get started")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("Set Up")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(color)
                    .cornerRadius(16)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        MetricScoreEmptyCard(
            config: .caffeine,
            color: .brown
        ) {
            print("Setup tapped")
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
