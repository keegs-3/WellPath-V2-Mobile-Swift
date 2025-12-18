//
//  HIITDurationCard.swift
//  WellPath
//
//  Reusable card for HIIT Duration metric.
//  Can be used in HIITScreen and Favorites.
//

import SwiftUI

struct HIITDurationCard: View {
    let color: Color
    let pillar: String
    let sectionId: String

    var body: some View {
        MetricCardView(
            title: "HIIT Duration",
            color: color,
            metricId: "DISP_HIIT_DURATION",
            pillar: pillar,
            cardId: "CARD_HIIT_DURATION",
            sectionId: sectionId,
            itemType: .metric
        ) {
            WorkoutMiniCard(category: "hiit", color: color, icon: "bolt.heart.fill")
        } fullScreen: {
            HIITDurationView(color: color, pillar: pillar, sectionId: sectionId)
        }
    }
}

#Preview {
    HIITDurationCard(color: .purple, pillar: "Movement + Exercise", sectionId: "NAV_MOVEMENT")
        .padding()
}
