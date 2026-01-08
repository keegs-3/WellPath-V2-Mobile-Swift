//
//  ScoreTabView.swift
//  WellPath
//
//  WellPath Score tab - shows overall health score and pillar breakdown
//  Shows demo content during onboarding, real data after cycle is active
//

import SwiftUI

struct ScoreTabView: View {
    @StateObject private var scoreViewModel = WellPathScoreViewModel()
    @ObservedObject private var journeyState = JourneyStateService.shared
    @Binding var showTour: Bool
    @State private var showProfile = false
    @State private var showWizard = false

    var body: some View {
        Group {
            if journeyState.shouldShowDemo {
                // Show locked view during onboarding
                ScoreLockedView(
                    onTakeTour: { showTour = true },
                    onContinueSetup: { showWizard = true }
                )
            } else {
                // Show real score content
                realScoreContent
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
        }
        .fullScreenCover(isPresented: $showWizard) {
            WizardView()
        }
        .task {
            await journeyState.loadState()
            if !journeyState.shouldShowDemo {
                await scoreViewModel.loadWellPathScore()
            }
        }
    }

    // MARK: - Real Score Content

    private var realScoreContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // WellPath Score Card
                if scoreViewModel.isLoading {
                    ProgressView()
                        .padding(40)
                } else if let error = scoreViewModel.error {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundColor(.orange)
                        Text("Unable to load score")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(WellPathColors.cardBackground)
                    .cornerRadius(12)
                } else {
                    NavigationLink(destination: WellPathOverviewView()) {
                        LargeScoreCard(
                            score: scoreViewModel.scorePercentage,
                            calculatedDate: scoreViewModel.formattedCalculatedDate
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Pillar Breakdown
                // TODO: Add pillar scores when available
                PillarBreakdownSection()
            }
            .padding()
        }
        .wellPathNeutralBackground()
        .refreshable {
            await scoreViewModel.loadWellPathScore()
        }
    }
}

// MARK: - Large Score Card

struct LargeScoreCard: View {
    let score: Int
    let calculatedDate: String

    var body: some View {
        VStack(spacing: 20) {
            // Large Ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 140, height: 140)

                // Progress ring
                Circle()
                    .trim(from: 0, to: min(CGFloat(score) / 100, 0.995))
                    .stroke(
                        Color(red: 0.56, green: 0.82, blue: 0.31),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))

                // Score text
                VStack(spacing: 4) {
                    Text("\(score)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(Color(red: 0.56, green: 0.82, blue: 0.31))
                    Text("/ 100")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Labels
            VStack(spacing: 4) {
                Text("WellPath Score")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(calculatedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Text("Tap to view details")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Pillar Breakdown Section

struct PillarBreakdownSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Health Pillars")
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                ForEach(HealthPillar.allCases, id: \.rawValue) { pillar in
                    ScorePillarRow(pillar: pillar, score: nil) // TODO: Add actual scores
                }
            }
        }
    }
}

// MARK: - Score Pillar Row

struct ScorePillarRow: View {
    let pillar: HealthPillar
    let score: Int?

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill((Color(hex: pillar.color) ?? .green).opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: pillar.icon)
                    .foregroundColor(Color(hex: pillar.color) ?? .green)
            }

            // Name
            Text(pillar.displayName)
                .font(.subheadline)

            Spacer()

            // Score
            if let score = score {
                Text("\(score)%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: pillar.color) ?? .green)
            } else {
                Text("--")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

#Preview {
    ScoreTabView(showTour: .constant(false))
}
