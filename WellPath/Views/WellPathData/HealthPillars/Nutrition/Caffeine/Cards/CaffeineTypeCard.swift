//
//  CaffeineTypeCard.swift
//  WellPath
//
//  Reusable card for Caffeine Type metric showing quality score.
//

import SwiftUI

struct CaffeineTypeCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Caffeine Types",
            color: color,
            metricId: "DISP_CAFFEINE_TYPE",
            pillar: pillar
        ) {
            CaffeineTypeMiniCard(color: color)
        } fullScreen: {
            CaffeineTypeView(color: color)
        }
    }
}

// MARK: - Mini Card

struct CaffeineTypeMiniCard: View {
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "chart.pie")
                    .font(.system(size: 24))
                    .foregroundColor(color.opacity(0.6))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Source Quality")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("View source breakdown")
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
    CaffeineTypeCard(color: .brown, pillar: "Healthful Nutrition")
        .padding()
}
