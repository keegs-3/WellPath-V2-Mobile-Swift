//
//  DailyActivityScreen.swift
//  WellPath
//
//  Card-based layout for Daily Activity metrics.
//  Shows cards: Move Minutes, Stand Time, Active Calories, Exercise Snacks.
//  Cards are reusable components defined in each metric's Cards/ folder.
//

import SwiftUI

struct DailyActivityScreen: View {
    let pillar: String
    let color: Color
    let sectionId: String

    @StateObject private var scoreViewModel = DailyActivityScoreViewModel()
    @StateObject private var detailViewModel = GenericScoreDetailViewModel(scoreType: "daily_activity_score")
    @State private var showingBaseline = false
    @State private var showingScoreDetail = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Score card at top - always visible
                scoreCardSection

                // Reusable card components
                MoveMinutesCard(color: color, pillar: pillar, sectionId: sectionId)
                StandTimeCard(color: color, pillar: pillar, sectionId: sectionId)
                ActiveCaloriesCard(color: color, pillar: pillar, sectionId: sectionId)
                ExerciseSnacksCard(color: color, pillar: pillar, sectionId: sectionId)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Daily Activity")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingBaseline = true
                } label: {
                    Image(systemName: "book.fill")
                }
            }
        }
        .sheet(isPresented: $showingBaseline) {
            DailyActivityWizardView()
        }
        .sheet(isPresented: $showingScoreDetail) {
            GenericScoreDetailView(
                viewModel: detailViewModel,
                title: "Daily Activity Score",
                iconName: "figure.stand",
                color: color
            )
        }
        .task {
            await scoreViewModel.loadData()
        }
    }

    // MARK: - Score Card Section

    @ViewBuilder
    private var scoreCardSection: some View {
        if scoreViewModel.hasScore {
            Button {
                showingScoreDetail = true
            } label: {
                HStack(spacing: 16) {
                    ScoreRingPill(
                        score: scoreViewModel.scoreValue,
                        iconName: "figure.stand",
                        label: "Score",
                        size: 60
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Activity Score")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Based on tracking")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
            .buttonStyle(.plain)
        } else if scoreViewModel.hasBaselineData {
            Button {
                showingScoreDetail = true
            } label: {
                HStack(spacing: 16) {
                    ScoreRingPill(
                        score: scoreViewModel.scoreValue,
                        iconName: "figure.stand",
                        label: "Baseline",
                        size: 60
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Activity Score")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Based on questionnaire")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
            .buttonStyle(.plain)
        } else {
            Button {
                showingBaseline = true
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                            .frame(width: 60, height: 60)

                        Image(systemName: "figure.stand")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Activity Score")
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
}

#Preview {
    NavigationStack {
        DailyActivityScreen(pillar: "Movement + Exercise", color: .orange, sectionId: "NAV_MOVEMENT")
    }
}
