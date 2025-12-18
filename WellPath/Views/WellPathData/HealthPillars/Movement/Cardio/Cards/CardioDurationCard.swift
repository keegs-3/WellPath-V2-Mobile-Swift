//
//  CardioDurationCard.swift
//  WellPath
//
//  Reusable card for Cardio Duration metric.
//  Can be used in CardioScreen and Favorites.
//

import SwiftUI

struct CardioDurationCard: View {
    let color: Color
    let pillar: String
    let sectionId: String

    var body: some View {
        MetricCardView(
            title: "Cardio Duration",
            color: color,
            metricId: "DISP_CARDIO_DURATION",
            pillar: pillar,
            cardId: "CARD_CARDIO_DURATION",
            sectionId: sectionId,
            itemType: .metric
        ) {
            WorkoutMiniCard(category: "cardio", color: color, icon: "figure.run")
        } fullScreen: {
            CardioDurationView(color: color, pillar: pillar, sectionId: sectionId)
        }
    }
}

#Preview {
    CardioDurationCard(color: .red, pillar: "Movement + Exercise", sectionId: "NAV_MOVEMENT")
        .padding()
}
