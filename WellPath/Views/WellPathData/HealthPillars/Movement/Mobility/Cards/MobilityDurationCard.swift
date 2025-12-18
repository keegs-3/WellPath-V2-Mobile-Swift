//
//  MobilityDurationCard.swift
//  WellPath
//
//  Reusable card for Mobility Duration metric.
//  Can be used in MobilityScreen and Favorites.
//

import SwiftUI

struct MobilityDurationCard: View {
    let color: Color
    let pillar: String
    let sectionId: String

    var body: some View {
        MetricCardView(
            title: "Mobility Duration",
            color: color,
            metricId: "DISP_MOBILITY_DURATION",
            pillar: pillar,
            cardId: "CARD_MOBILITY_DURATION",
            sectionId: sectionId,
            itemType: .metric
        ) {
            WorkoutMiniCard(category: "flexibility", color: color, icon: "figure.flexibility")
        } fullScreen: {
            MobilityDurationView(color: color, pillar: pillar, sectionId: sectionId)
        }
    }
}

#Preview {
    MobilityDurationCard(color: .green, pillar: "Movement + Exercise", sectionId: "NAV_MOVEMENT")
        .padding()
}
