//
//  NutsSeedsTypeCard.swift
//  WellPath
//
//  Reusable card for Nuts & Seeds Type metric showing variety breakdown.
//

import SwiftUI

struct NutsSeedsTypeCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Variety",
            color: color,
            metricId: "DISP_NUTS_SEEDS_TYPE",
            pillar: pillar
        ) {
            NutsSeedsTypeMiniCard(color: color)
        } fullScreen: {
            NutsSeedsTypeView(color: color)
        }
    }
}

// MARK: - Mini Card

struct NutsSeedsTypeMiniCard: View {
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "chart.pie")
                    .font(.system(size: 24))
                    .foregroundColor(color.opacity(0.6))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Type Variety")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("View variety breakdown")
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
    NutsSeedsTypeCard(color: .brown, pillar: "Healthful Nutrition")
        .padding()
}
