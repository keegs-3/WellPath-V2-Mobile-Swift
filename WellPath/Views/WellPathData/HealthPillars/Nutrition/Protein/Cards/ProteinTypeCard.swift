//
//  ProteinTypeCard.swift
//  WellPath
//
//  Reusable card for Protein Type metric.
//  Can be used in ProteinScreen and Favorites.
//

import SwiftUI

struct ProteinTypeCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Protein Type",
            color: color,
            metricId: "DISP_PROTEIN_TYPE",
            pillar: pillar
        ) {
            ProteinTypeMiniCard(color: color)
        } fullScreen: {
            ProteinTypeView(color: color)
        }
    }
}

// MARK: - Mini Card

struct ProteinTypeMiniCard: View {
    let color: Color
    @StateObject private var viewModel: ProteinTypeDonutViewModel

    init(color: Color) {
        self.color = color
        _viewModel = StateObject(wrappedValue: ProteinTypeDonutViewModel(baseColor: color))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(height: 60)
            } else if viewModel.totalProtein > 0 {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quality Score")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(viewModel.calculateTypeScore().rounded()))")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(scoreColor)
                            Text("/ 100")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        tierIndicator(label: tierName(for: "PROTEIN_TIER_1"), percentage: tier1Percentage, color: MetricsUIConfig.tierGood)
                        tierIndicator(label: tierName(for: "PROTEIN_TIER_2"), percentage: tier2Percentage, color: MetricsUIConfig.tierMedium)
                        tierIndicator(label: tierName(for: "PROTEIN_TIER_3"), percentage: tier3Percentage, color: MetricsUIConfig.tierPoor)
                    }
                }
            } else {
                HStack {
                    Text("No type data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 60)
            }
        }
        .task {
            await viewModel.loadTierConfig()
            await viewModel.loadDataForPeriod(period: .week, date: Date())
        }
    }

    private var scoreColor: Color {
        let score = viewModel.calculateTypeScore()
        if score >= 85 { return Color.green }
        else if score >= 70 { return Color.blue }
        else if score >= 55 { return Color.orange }
        else { return Color.red }
    }

    private var tier1Percentage: Double {
        tierPercentage(for: "PROTEIN_TIER_1")
    }

    private var tier2Percentage: Double {
        tierPercentage(for: "PROTEIN_TIER_2")
    }

    private var tier3Percentage: Double {
        tierPercentage(for: "PROTEIN_TIER_3")
    }

    private func tierName(for tierId: String) -> String {
        guard let tierConfig = viewModel.tierConfig,
              let tier = tierConfig.tiers.first(where: { $0.tierId == tierId }) else {
            // Fallback to tier names if config not loaded
            switch tierId {
            case "PROTEIN_TIER_1": return "Best"
            case "PROTEIN_TIER_2": return "Good"
            case "PROTEIN_TIER_3": return "Limit"
            default: return "?"
            }
        }
        return tier.tierName
    }

    private func tierPercentage(for tierId: String) -> Double {
        guard let tierConfig = viewModel.tierConfig,
              let tier = tierConfig.tiers.first(where: { $0.tierId == tierId }),
              viewModel.totalProtein > 0 else { return 0 }

        let tierGrams = tier.proteinTypes.reduce(0.0) { sum, typeId in
            sum + (viewModel.typeData[typeId] ?? 0)
        }
        return (tierGrams / viewModel.totalProtein) * 100
    }

    @ViewBuilder
    private func tierIndicator(label: String, percentage: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 32, alignment: .trailing)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                    .frame(width: 50, height: 6)

                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 50 * min(percentage / 100, 1.0), height: 6)
            }

            Text("\(Int(percentage.rounded()))%")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)
        }
    }
}

#Preview {
    ProteinTypeCard(color: .blue, pillar: "Healthful Nutrition")
        .padding()
}
