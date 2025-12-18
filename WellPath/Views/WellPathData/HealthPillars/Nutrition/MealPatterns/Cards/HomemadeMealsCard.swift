//
//  HomemadeMealsCard.swift
//  WellPath
//
//  Reusable card for Homemade Meals metric.
//

import SwiftUI

struct HomemadeMealsCard: View {
    let color: Color
    let pillar: String

    @StateObject private var viewModel = StandardMetricViewModel(metricId: "DISP_HOMEMADE_MEALS")

    var body: some View {
        MetricCardView(
            title: "Homemade Meals",
            color: color,
            metricId: "DISP_HOMEMADE_MEALS",
            pillar: pillar
        ) {
            HomemadeMealsMiniCard(viewModel: viewModel, color: color)
        } fullScreen: {
            HomemadeMealsView(color: color)
        }
        .task {
            await viewModel.loadPrimaryScreen()
        }
    }
}

// MARK: - Mini Card

struct HomemadeMealsMiniCard: View {
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
                        Text("70%+")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 24))
                        .foregroundColor(color.opacity(0.6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Homemade")
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
    HomemadeMealsCard(color: .indigo, pillar: "Healthful Nutrition")
        .padding()
}
