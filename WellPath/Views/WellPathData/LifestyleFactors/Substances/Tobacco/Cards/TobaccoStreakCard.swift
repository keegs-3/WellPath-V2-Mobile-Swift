//
//  TobaccoStreakCard.swift
//  WellPath
//
//  Card view for Smoke-Free Streak tracking
//

import SwiftUI

struct TobaccoStreakCard: View {
    let color: Color
    let pillar: String

    private let icon = "calendar.badge.checkmark"

    var body: some View {
        MetricCardView(
            title: "Smoke-Free Streak",
            color: color,
            pillar: pillar
        ) {
            TobaccoStreakMiniCard(color: color, icon: icon)
        } fullScreen: {
            TobaccoStreakView(color: color)
        }
    }
}

// MARK: - Mini Card

struct TobaccoStreakMiniCard: View {
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
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(viewModel.currentStreak)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Text("days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text("Smoke-free")
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
    TobaccoStreakCard(color: .mint, pillar: "Lifestyle")
        .padding()
}
