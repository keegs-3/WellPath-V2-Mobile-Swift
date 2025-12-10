//
//  ProteinTimingCard.swift
//  WellPath
//
//  Reusable card for Protein Timing metric.
//  Can be used in ProteinScreen and Favorites.
//

import SwiftUI

struct ProteinTimingCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Protein Timing",
            color: color,
            metricId: "DISP_PROTEIN_TIMING",
            pillar: pillar
        ) {
            ProteinTimingMiniCard(color: color)
        } fullScreen: {
            ProteinTimingView(color: color)
        }
    }
}

// MARK: - Mini Card

struct ProteinTimingMiniCard: View {
    let color: Color
    @StateObject private var viewModel: NutrientTimingViewModel

    init(color: Color) {
        self.color = color
        _viewModel = StateObject(wrappedValue: NutrientTimingViewModel(nutrientType: .protein, baseColor: color))
    }

    private var topMeal: (name: String, percentage: Double)? {
        var totalValue: Double = 0
        var topMealInfo: (name: String, value: Double)?

        for meal in viewModel.mealAggregations {
            let value = viewModel.periodData[meal.aggId] ?? 0
            if value > 0 {
                totalValue += value
                if topMealInfo == nil || value > topMealInfo!.value {
                    topMealInfo = (meal.displayName, value)
                }
            }
        }

        guard let top = topMealInfo, totalValue > 0 else { return nil }
        return (top.name, (top.value / totalValue) * 100)
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
            } else if let top = topMeal {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Top Meal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(top.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(top.percentage.rounded()))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(color)
                        Text("of daily intake")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                HStack {
                    Text("No timing data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 60)
            }
        }
        .task {
            await viewModel.discoverMealAggregations()
            await viewModel.loadDataForPeriod(period: .week, date: Date())
        }
    }
}

#Preview {
    ProteinTimingCard(color: .blue, pillar: "Healthful Nutrition")
        .padding()
}
