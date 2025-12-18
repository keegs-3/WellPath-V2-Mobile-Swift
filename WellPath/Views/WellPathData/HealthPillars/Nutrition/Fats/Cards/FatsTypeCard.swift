//
//  FatsTypeCard.swift
//  WellPath
//
//  Reusable card for Fat Type metric showing quality score.
//

import SwiftUI

struct FatsTypeCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Fat Types",
            color: color,
            metricId: "DISP_FATS_TYPE",
            pillar: pillar
        ) {
            FatsTypeMiniCard(color: color)
        } fullScreen: {
            FatsTypeView(color: color)
        }
    }
}

// MARK: - Mini Card

struct FatsTypeMiniCard: View {
    let color: Color
    @StateObject private var viewModel: FatsTypeDonutViewModel

    init(color: Color) {
        self.color = color
        _viewModel = StateObject(wrappedValue: FatsTypeDonutViewModel(baseColor: color))
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
            } else if viewModel.totalFats > 0 {
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
                        tierIndicator(label: "T1", percentage: tier1Percentage, color: MetricsUIConfig.tierGood)
                        tierIndicator(label: "T2", percentage: tier2Percentage, color: MetricsUIConfig.tierMedium)
                        tierIndicator(label: "T3", percentage: tier3Percentage, color: MetricsUIConfig.tierPoor)
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
        if score >= 85 { return MetricsUIConfig.tierGood }
        else if score >= 70 { return MetricsUIConfig.tierMedium }
        else { return MetricsUIConfig.tierPoor }
    }

    private var tier1Percentage: Double {
        tierPercentage(forTierIndex: 0)
    }

    private var tier2Percentage: Double {
        tierPercentage(forTierIndex: 1)
    }

    private var tier3Percentage: Double {
        tierPercentage(forTierIndex: 2)
    }

    private func tierPercentage(forTierIndex index: Int) -> Double {
        guard let tierConfig = viewModel.tierConfig,
              index < tierConfig.tiers.count,
              viewModel.totalFats > 0 else { return 0 }

        let tier = tierConfig.tiers.sorted { $0.displayOrder < $1.displayOrder }[index]
        let tierGrams = tier.fatTypes.reduce(0.0) { sum, typeId in
            sum + (viewModel.typeData[typeId] ?? 0)
        }
        return (tierGrams / viewModel.totalFats) * 100
    }

    @ViewBuilder
    private func tierIndicator(label: String, percentage: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .trailing)

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
    FatsTypeCard(color: .orange, pillar: "Healthful Nutrition")
        .padding()
}
