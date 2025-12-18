//
//  WaterTimingCard.swift
//  WellPath
//
//  Reusable card for Water Timing metric.
//

import SwiftUI

struct WaterTimingCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Hydration Timing",
            color: color,
            metricId: "DISP_WATER_TIMING",
            pillar: pillar
        ) {
            WaterTimingMiniCard(color: color)
        } fullScreen: {
            WaterTimingView(color: color)
        }
    }
}

// MARK: - Mini Card

struct WaterTimingMiniCard: View {
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 24))
                    .foregroundColor(color.opacity(0.6))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Timing")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("View hydration patterns")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(height: 60)
    }
}

#Preview {
    WaterTimingCard(color: .cyan, pillar: "Healthful Nutrition")
        .padding()
}
