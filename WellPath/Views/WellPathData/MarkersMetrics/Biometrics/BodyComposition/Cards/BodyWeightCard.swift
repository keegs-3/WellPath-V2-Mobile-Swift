//
//  BodyWeightCard.swift
//  WellPath
//
//  Individual card for Body Weight
//

import SwiftUI

struct BodyWeightCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Body Weight",
            color: color,
            metricId: "DISP_BODYWEIGHT",
            pillar: pillar,
            cardId: "DISP_BODYWEIGHT",
            sectionId: "NAV_BIOMETRICS",
            itemType: .biometric
        ) {
            BiometricMiniCard(metricId: "DISP_BODYWEIGHT", color: color, fallbackIcon: "scalemass.fill")
        } fullScreen: {
            BodyWeightView(color: color)
        }
    }
}

#Preview {
    BodyWeightCard(color: .blue, pillar: "Core Care")
        .padding()
}
