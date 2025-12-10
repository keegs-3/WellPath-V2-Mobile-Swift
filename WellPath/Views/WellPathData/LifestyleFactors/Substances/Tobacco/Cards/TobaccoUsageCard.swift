//
//  TobaccoUsageCard.swift
//  WellPath
//
//  Card view for Tobacco Usage tracking
//

import SwiftUI

struct TobaccoUsageCard: View {
    let color: Color
    let pillar: String

    private let icon = "smoke"

    var body: some View {
        MetricCardView(
            title: "Daily Cigarettes",
            color: color,
            pillar: pillar
        ) {
            TobaccoUsageMiniCard(color: color, icon: icon)
        } fullScreen: {
            TobaccoUsageView(color: color)
        }
    }
}

// MARK: - Mini Card

struct TobaccoUsageMiniCard: View {
    let color: Color
    let icon: String

    @StateObject private var viewModel = TobaccoTrackingViewModel()

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if let latest = viewModel.cigaretteHistory.last {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(latest.value)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Text("cigarettes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text("Track daily usage")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .task {
            await viewModel.loadHistory()
        }
    }
}

#Preview {
    TobaccoUsageCard(color: .mint, pillar: "Lifestyle")
        .padding()
}
