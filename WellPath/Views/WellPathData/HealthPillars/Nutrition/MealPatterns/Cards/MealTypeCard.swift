//
//  MealTypeCard.swift
//  WellPath
//
//  Reusable card for Meal Distribution metric.
//

import SwiftUI

struct MealTypeCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Meal Distribution",
            color: color,
            metricId: "DISP_MEAL_TYPE",
            pillar: pillar
        ) {
            MealTypeMiniCard(color: color)
        } fullScreen: {
            MealTypeView(color: color)
        }
    }
}

// MARK: - Mini Card

struct MealTypeMiniCard: View {
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 24))
                    .foregroundColor(color.opacity(0.6))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Meal Distribution")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Breakfast, lunch, dinner")
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
    MealTypeCard(color: .indigo, pillar: "Healthful Nutrition")
        .padding()
}
