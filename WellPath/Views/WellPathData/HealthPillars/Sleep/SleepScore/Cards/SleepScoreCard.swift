//
//  SleepScoreCard.swift
//  WellPath
//
//  Reusable card for Sleep Score metric.
//

import SwiftUI

struct SleepScoreCard: View {
    let color: Color
    let pillar: String
    let sectionId: String

    init(color: Color, pillar: String = "Restorative Sleep", sectionId: String = "NAV_SLEEP") {
        self.color = color
        self.pillar = pillar
        self.sectionId = sectionId
    }

    var body: some View {
        MetricCardView(
            title: "Sleep Score",
            color: color,
            metricId: "SCREEN_SLEEP_SCORE",
            pillar: pillar,
            cardId: "CARD_SLEEP_SCORE",
            sectionId: sectionId,
            itemType: .screen
        ) {
            SleepScoreMiniCard(color: color)
        } fullScreen: {
            SleepScoreScreen(color: color, pillar: pillar, sectionId: sectionId)
        }
    }
}

// MARK: - Mini Card

struct SleepScoreMiniCard: View {
    let color: Color
    @StateObject private var viewModel = SleepScoreViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(height: 60)
            } else if viewModel.tierConfig != nil {
                HStack(spacing: 16) {
                    // Score on left
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quality Score")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(viewModel.totalScore.rounded()))")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(scoreColor)
                            Text("/ 100")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Tier indicators on right
                    if let tierConfig = viewModel.tierConfig {
                        VStack(alignment: .trailing, spacing: 4) {
                            ForEach(tierConfig.tiers.prefix(4)) { tier in
                                tierIndicator(tier: tier)
                            }
                        }
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 24))
                        .foregroundColor(color.opacity(0.6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sleep Score")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("No data yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(height: 60)
            }
        }
        .task {
            await viewModel.loadTierConfig()
            await viewModel.loadData()
        }
    }

    private var scoreColor: Color {
        let score = viewModel.totalScore
        if score >= 85 { return MetricsUIConfig.tierGood }
        else if score >= 70 { return MetricsUIConfig.tierMedium }
        else { return MetricsUIConfig.tierPoor }
    }

    @ViewBuilder
    private func tierIndicator(tier: SleepScoreTierConfig.Tier) -> some View {
        let score = viewModel.getScore(for: tier.tierId)
        HStack(spacing: 4) {
            Text(tierAbbreviation(tier.tierName))
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .trailing)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                    .frame(width: 40, height: 6)

                RoundedRectangle(cornerRadius: 2)
                    .fill(tier.color)
                    .frame(width: 40 * min(score / 100, 1.0), height: 6)
            }

            Text("\(Int(score.rounded()))")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .leading)
        }
    }

    private func tierAbbreviation(_ name: String) -> String {
        // Create abbreviation from tier name
        switch name.lowercased() {
        case "consistency": return "Con"
        case "duration": return "Dur"
        case "structure": return "Str"
        case "efficiency": return "Eff"
        default: return String(name.prefix(3))
        }
    }
}

#Preview {
    SleepScoreCard(color: .indigo, pillar: "Restorative Sleep")
        .padding()
}
