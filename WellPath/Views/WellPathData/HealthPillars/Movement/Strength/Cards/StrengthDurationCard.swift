//
//  StrengthDurationCard.swift
//  WellPath
//
//  Reusable card for Strength Duration metric.
//  Can be used in StrengthScreen and Favorites.
//

import SwiftUI

struct StrengthDurationCard: View {
    let color: Color
    let pillar: String
    let sectionId: String

    var body: some View {
        MetricCardView(
            title: "Strength Duration",
            color: color,
            metricId: "DISP_STRENGTH_DURATION",
            pillar: pillar,
            cardId: "CARD_STRENGTH_DURATION",
            sectionId: sectionId,
            itemType: .metric
        ) {
            WorkoutMiniCard(category: "strength", color: color, icon: "dumbbell.fill")
        } fullScreen: {
            StrengthDurationView(color: color, pillar: pillar, sectionId: sectionId)
        }
    }
}

#Preview {
    StrengthDurationCard(color: .orange, pillar: "Movement + Exercise", sectionId: "NAV_MOVEMENT")
        .padding()
}
