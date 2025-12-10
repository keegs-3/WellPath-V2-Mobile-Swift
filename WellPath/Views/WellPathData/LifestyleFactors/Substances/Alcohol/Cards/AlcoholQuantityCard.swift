//
//  AlcoholQuantityCard.swift
//  WellPath
//
//  Card view for Alcohol Quantity tracking
//

import SwiftUI

struct AlcoholQuantityCard: View {
    let color: Color
    let pillar: String

    private let icon = "wineglass"

    var body: some View {
        MetricCardView(
            title: "Weekly Drinks",
            color: color,
            pillar: pillar
        ) {
            AlcoholQuantityMiniCard(color: color, icon: icon)
        } fullScreen: {
            AlcoholQuantityView(color: color)
        }
    }
}

// MARK: - Mini Card

struct AlcoholQuantityMiniCard: View {
    let color: Color
    let icon: String

    @StateObject private var viewModel = AlcoholTrackingViewModel()

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
                        Text("\(viewModel.currentWeekDrinks)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Text("drinks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text("This week")
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
    AlcoholQuantityCard(color: .orange, pillar: "Lifestyle")
        .padding()
}
