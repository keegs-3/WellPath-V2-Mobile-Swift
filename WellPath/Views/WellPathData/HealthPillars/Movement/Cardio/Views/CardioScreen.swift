//
//  CardioScreen.swift
//  WellPath
//
//  Card-based layout for Cardio metrics.
//  Shows cards: Duration (and Type in the future).
//  Cards are reusable components defined in Cards/ folder.
//

import SwiftUI

struct CardioScreen: View {
    let pillar: String
    let color: Color
    let sectionId: String

    @StateObject private var scoreViewModel = CardioScoreViewModel()
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false
    @State private var showingBaseline = false
    @State private var showingScoreDetail = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Score card at top - always visible
                scoreCardSection

                // Reusable card components
                CardioDurationCard(color: color, pillar: pillar, sectionId: sectionId)
                // Future: CardioTypeCard(color: color, pillar: pillar, sectionId: sectionId)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Cardio")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingDataManagement = true
                } label: {
                    Image(systemName: "list.bullet")
                }
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showingBaseline = true
                } label: {
                    Image(systemName: "book.fill")
                }

                Button {
                    showingEntryForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEntryForm) {
            WorkoutEntryView(category: "cardio", categoryName: "Cardio", color: color, icon: "figure.run")
        }
        .sheet(isPresented: $showingDataManagement) {
            WorkoutDataManagementView(category: "cardio", categoryName: "Cardio", color: color)
        }
        .sheet(isPresented: $showingBaseline) {
            CardioWizardView()
        }
        .sheet(isPresented: $showingScoreDetail) {
            WorkoutScoreDetailView(viewModel: scoreViewModel, config: .cardio, color: color)
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
                        iconName: "figure.run",
                        label: "Score",
                        size: 60
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cardio Score")
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
                        iconName: "figure.run",
                        label: "Baseline",
                        size: 60
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cardio Score")
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

                        Image(systemName: "figure.run")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cardio Score")
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
        CardioScreen(pillar: "Movement + Exercise", color: .red, sectionId: "NAV_MOVEMENT")
    }
}
