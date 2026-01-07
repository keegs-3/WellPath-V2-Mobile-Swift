//
//  HIITScreen.swift
//  WellPath
//
//  Card-based layout for HIIT metrics.
//  Shows cards: Duration (and Type in the future).
//  Cards are reusable components defined in Cards/ folder.
//

import SwiftUI

struct HIITScreen: View {
    let pillar: String
    let color: Color
    let sectionId: String

    @StateObject private var scoreViewModel = HIITScoreViewModel()
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
                HIITDurationCard(color: color, pillar: pillar, sectionId: sectionId)
                // Future: HIITTypeCard(color: color, pillar: pillar, sectionId: sectionId)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("High-Intensity Interval Training")
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
            WorkoutEntryView(category: "hiit", categoryName: "HIIT", color: color, icon: "bolt.heart.fill")
        }
        .sheet(isPresented: $showingDataManagement) {
            WorkoutDataManagementView(category: "hiit", categoryName: "HIIT", color: color)
        }
        .sheet(isPresented: $showingBaseline) {
            HIITWizardView()
        }
        .sheet(isPresented: $showingScoreDetail) {
            WorkoutScoreDetailView(viewModel: scoreViewModel, config: .hiit, color: color)
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
                        iconName: "bolt.heart.fill",
                        label: "Score",
                        size: 60
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("HIIT Score")
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
                        iconName: "bolt.heart.fill",
                        label: "Baseline",
                        size: 60
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("HIIT Score")
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

                        Image(systemName: "bolt.heart.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("HIIT Score")
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
        HIITScreen(pillar: "Movement + Exercise", color: .purple, sectionId: "NAV_MOVEMENT")
    }
}
