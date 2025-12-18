//
//  PlantBasedMealsCard.swift
//  WellPath
//
//  Reusable card for Plant-Based Meals metric.
//

import SwiftUI

struct PlantBasedMealsCard: View {
    let color: Color
    let pillar: String

    @StateObject private var viewModel = StandardMetricViewModel(metricId: "DISP_PLANT_BASED_MEALS")

    var body: some View {
        MetricCardView(
            title: "Plant-Based Meals",
            color: color,
            metricId: "DISP_PLANT_BASED_MEALS",
            pillar: pillar
        ) {
            PlantBasedMealsMiniCard(viewModel: viewModel, color: color)
        } fullScreen: {
            PlantBasedMealsView(color: color)
        }
        .task {
            await viewModel.loadPrimaryScreen()
        }
    }
}

// MARK: - Mini Card

struct PlantBasedMealsMiniCard: View {
    @ObservedObject var viewModel: StandardMetricViewModel
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(height: 60)
            } else if let todayValue = viewModel.todayValue {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.0f", todayValue))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(color)
                            Text("%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Target")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("50%+")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 24))
                        .foregroundColor(color.opacity(0.6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Plant-Based")
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
    }
}

#Preview {
    PlantBasedMealsCard(color: .indigo, pillar: "Healthful Nutrition")
        .padding()
}
