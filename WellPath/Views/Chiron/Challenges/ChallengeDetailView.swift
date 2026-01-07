//
//  ChallengeDetailView.swift
//  WellPath
//
//  Detailed view for an individual challenge
//  Shows progress, rationale, tips, and actions
//

import SwiftUI

struct ChallengeDetailView: View {
    let challenge: PatientChallenge

    @StateObject private var viewModel = ChironViewModel()
    @State private var showingSkipSheet = false
    @State private var showingCompleteConfirm = false
    @State private var showingAbandonConfirm = false
    @Environment(\.dismiss) private var dismiss

    private var accentColor: Color { .orange }

    private var daysProgress: String {
        "Day \(challenge.daysCompleted + 1) of \(challenge.durationDays ?? 7)"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                heroSection
                targetSection
                progressSection

                if let rationale = challenge.aiRationale, !rationale.isEmpty {
                    rationaleSection(rationale: rationale)
                }

                actionsSection
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(challenge.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if challenge.status == .active {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showingAbandonConfirm = true
                        } label: {
                            Label("Abandon Challenge", systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog("Why are you skipping?", isPresented: $showingSkipSheet) {
            ForEach(ChallengeSkipReason.allCases, id: \.self) { reason in
                Button(reason.displayName) {
                    Task {
                        if await viewModel.skipChallenge(challenge, reason: reason) {
                            dismiss()
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Complete Challenge?", isPresented: $showingCompleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Complete") {
                Task {
                    if await viewModel.completeChallenge(challenge) {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Mark this challenge as complete?")
        }
        .alert("Abandon Challenge?", isPresented: $showingAbandonConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Abandon", role: .destructive) {
                Task {
                    if await viewModel.abandonChallenge(challenge) {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("This will end the challenge early. You can try again later.")
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            // Rationale badge
            if let rationale = challenge.challengeRationale {
                ChallengeRationaleBadge(rationale: rationale)
            }

            // Progress ring
            ScoreRingPill(
                score: Int(challenge.displayProgress),
                maxScore: 100,
                iconName: "flame.fill",
                label: daysProgress,
                size: 140,
                color: accentColor
            )

            // Day progress dots
            ChallengeProgressDots(
                totalDays: challenge.durationDays ?? 7,
                completedDays: challenge.daysCompleted
            )

            // Days remaining
            if challenge.status == .active {
                Text("\(challenge.daysRemaining) days remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Target Section

    private var targetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ChironSectionHeader(title: "Your Target", icon: "target")

            VStack(alignment: .leading, spacing: 8) {
                if let targetValue = challenge.targetValue, let metric = challenge.targetMetric {
                    HStack(spacing: 4) {
                        Text("\(Int(targetValue))")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(accentColor)
                        Text(metric)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }

                if let description = challenge.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ChironSectionHeader(title: "Progress", icon: "chart.bar.fill")

            HStack(spacing: 24) {
                // Current value
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let currentValue = challenge.currentValue {
                        Text("\(Int(currentValue))")
                            .font(.title2)
                            .fontWeight(.semibold)
                    } else {
                        Text("--")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()
                    .frame(height: 40)

                // Target value
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let targetValue = challenge.targetValue {
                        Text("\(Int(targetValue))")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(accentColor)
                    } else {
                        Text("--")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Completion %
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Completion")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(challenge.displayProgress))%")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(challenge.displayProgress >= 100 ? .green : .primary)
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Rationale Section

    private func rationaleSection(rationale: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ChironSectionHeader(title: "Why This Challenge", icon: "lightbulb.fill")

            Text(rationale)
                .font(.subheadline)
                .foregroundColor(.primary)
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 12) {
            // History button - navigate to WellPath Data screen
            NavigationLink {
                historyDestination
            } label: {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("View History")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(accentColor)
                .cornerRadius(12)
            }

            // Complete (if active and sufficient progress)
            if challenge.status == .active {
                HStack(spacing: 12) {
                    Button {
                        showingCompleteConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Complete")
                        }
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }

                    Button {
                        showingSkipSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Skip")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }

    // MARK: - History Destination

    /// Maps challenge to the appropriate WellPath Data screen
    /// Uses recTypeId or challengeType to determine routing
    @ViewBuilder
    private var historyDestination: some View {
        let color = accentColor

        // Try to determine pillar from challenge type
        let pillar = determinePillar()

        switch challenge.challengeType ?? challenge.recTypeId {
        // Movement
        case "GOAL_STEPS_DAILY", "REC_STEPS_DAILY", "steps":
            StepsScreen(pillar: pillar, color: color, sectionId: "SECT_STEPS")
        case "GOAL_CARDIO_WEEKLY", "REC_CARDIO_WEEKLY", "cardio":
            CardioScreen(pillar: pillar, color: color, sectionId: "SECT_CARDIO")
        case "GOAL_STRENGTH_WEEKLY", "REC_STRENGTH_WEEKLY", "strength":
            StrengthScreen(pillar: pillar, color: color, sectionId: "SECT_STRENGTH")

        // Nutrition
        case "GOAL_PROTEIN_TOTAL", "REC_PROTEIN_AMOUNT", "protein":
            ProteinScreen(pillar: pillar, color: color)
        case "REC_VEGETABLES_AMOUNT", "vegetables":
            VegetablesScreen(pillar: pillar, color: color)
        case "REC_FRUITS_AMOUNT", "fruits":
            FruitsScreen(pillar: pillar, color: color)
        case "REC_HYDRATION_AMOUNT", "water":
            WaterScreen(pillar: pillar, color: color)

        // Sleep
        case "GOAL_SLEEP_DURATION", "REC_BEDTIME_CONSISTENCY", "sleep":
            SleepAnalysisScreen(pillar: pillar, color: color)

        default:
            // Fallback
            VStack(spacing: 16) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("History not available for this challenge")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }

    private func determinePillar() -> String {
        // Try to infer pillar from challenge type
        if let type = challenge.challengeType ?? challenge.recTypeId {
            if type.contains("STEPS") || type.contains("CARDIO") || type.contains("STRENGTH") {
                return "movement"
            } else if type.contains("PROTEIN") || type.contains("VEGETABLES") || type.contains("FRUITS") || type.contains("HYDRATION") {
                return "nutrition"
            } else if type.contains("SLEEP") || type.contains("BEDTIME") {
                return "sleep"
            }
        }
        return "movement" // Default
    }
}

// MARK: - Challenge Section Header

struct ChironSectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Challenge Progress Dots

struct ChallengeProgressDots: View {
    let totalDays: Int
    let completedDays: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<min(totalDays, 14), id: \.self) { day in
                Circle()
                    .fill(day < completedDays ? Color.orange : Color.gray.opacity(0.3))
                    .frame(width: 10, height: 10)
            }

            if totalDays > 14 {
                Text("+\(totalDays - 14)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Challenge Rationale Badge

struct ChallengeRationaleBadge: View {
    let rationale: ChallengeRationale

    private var text: String {
        switch rationale {
        case .recovery: return "Getting Back on Track"
        case .growth: return "Level Up"
        case .expansion: return "Try Something New"
        }
    }

    private var color: Color {
        switch rationale {
        case .recovery: return .blue
        case .growth: return .green
        case .expansion: return .purple
        }
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color)
            .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ChallengeDetailView(
            challenge: PatientChallenge(
                challengeId: "preview-1",
                patientId: "user-1",
                goalId: nil,
                title: "10k Steps Challenge",
                description: "Hit 10,000 steps for 5 days",
                challengeType: "steps",
                targetValue: 10000,
                targetMetric: "steps per day",
                durationDays: 5,
                currentValue: 7500,
                progressPercentage: 75,
                status: .active,
                startDate: "2026-01-01",
                endDate: "2026-01-05",
                completedAt: nil,
                aiRationale: "Based on your recent activity, increasing your daily steps will help improve your cardiovascular health.",
                difficultyLevel: 2,
                challengeRationale: .growth,
                suggestedTemplateId: nil,
                skipReason: nil,
                skippedAt: nil,
                recTypeId: "REC_STEPS_DAILY"
            )
        )
    }
}
