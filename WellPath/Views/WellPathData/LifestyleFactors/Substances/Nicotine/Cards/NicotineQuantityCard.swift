//
//  NicotineQuantityCard.swift
//  WellPath
//
//  Card view for Nicotine Quantity tracking
//

import SwiftUI

struct NicotineQuantityCard: View {
    let color: Color
    let pillar: String

    private let icon = "bolt.circle"

    var body: some View {
        MetricCardView(
            title: "Daily Nicotine",
            color: color,
            pillar: pillar
        ) {
            NicotineQuantityMiniCard(color: color, icon: icon)
        } fullScreen: {
            NicotineQuantityView(color: color)
        }
    }
}

// MARK: - Mini Card

struct NicotineQuantityMiniCard: View {
    let color: Color
    let icon: String

    @StateObject private var viewModel = NicotineTrackingViewModel()

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
                        Text("\(viewModel.todayUsage)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Text("uses")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text("Today")
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
    NicotineQuantityCard(color: .indigo, pillar: "Lifestyle")
        .padding()
}
