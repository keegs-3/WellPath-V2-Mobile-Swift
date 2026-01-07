//
//  ChallengesCard.swift
//  WellPath
//
//  Entry card for Challenges on Goals tab
//  Shows preview of active challenge or prompt to view recommendations
//

import SwiftUI

struct ChallengesCard: View {
    let activeChallenge: PatientChallenge?
    let recommendedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)

                Text("Challenges")
                    .font(.headline)

                Spacer()

                if recommendedCount > 0 && activeChallenge == nil {
                    RecommendedBadge(count: recommendedCount)
                }

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            // Preview content
            if let challenge = activeChallenge {
                ActiveChallengePreview(challenge: challenge)
            } else if recommendedCount > 0 {
                Text("\(recommendedCount) recommended challenge\(recommendedCount == 1 ? "" : "s") waiting for you")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Short-term pushes to accelerate your goals")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Recommended Badge

struct RecommendedBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange)
            .clipShape(Capsule())
    }
}

// MARK: - Active Challenge Preview

struct ActiveChallengePreview: View {
    let challenge: PatientChallenge

    var body: some View {
        HStack(spacing: 12) {
            // Progress indicator
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.2), lineWidth: 3)
                    .frame(width: 40, height: 40)

                Circle()
                    .trim(from: 0, to: challenge.displayProgress / 100)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(challenge.displayProgress))%")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(challenge.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text("Day \(challenge.daysCompleted + 1) of \(challenge.durationDays ?? 7)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Previews

#Preview("With Active Challenge") {
    ChallengesCard(
        activeChallenge: PatientChallenge(
            challengeId: "1",
            patientId: "user",
            goalId: nil,
            title: "10k Steps Challenge",
            description: nil,
            challengeType: "steps",
            targetValue: 10000,
            targetMetric: "steps",
            durationDays: 7,
            currentValue: 5000,
            progressPercentage: 50,
            status: .active,
            startDate: "2026-01-01",
            endDate: "2026-01-07",
            completedAt: nil,
            aiRationale: nil,
            difficultyLevel: nil,
            challengeRationale: nil,
            suggestedTemplateId: nil,
            skipReason: nil,
            skippedAt: nil,
            recTypeId: nil
        ),
        recommendedCount: 0
    )
    .padding()
}

#Preview("With Recommendations") {
    ChallengesCard(
        activeChallenge: nil,
        recommendedCount: 3
    )
    .padding()
}

#Preview("Empty") {
    ChallengesCard(
        activeChallenge: nil,
        recommendedCount: 0
    )
    .padding()
}
