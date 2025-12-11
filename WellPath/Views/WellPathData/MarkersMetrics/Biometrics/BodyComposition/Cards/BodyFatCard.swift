//
//  BodyFatCard.swift
//  WellPath
//
//  Individual card for Body Fat %
//

import SwiftUI

struct BodyFatCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Body Fat %",
            color: color,
            metricId: "DISP_BODYFAT",
            pillar: pillar,
            cardId: "DISP_BODYFAT",
            sectionId: "NAV_BIOMETRICS",
            itemType: .biometric
        ) {
            BiometricMiniCard(metricId: "DISP_BODYFAT", color: color, fallbackIcon: "percent")
        } fullScreen: {
            BodyFatView(color: color)
        }
    }
}

#Preview {
    BodyFatCard(color: .orange, pillar: "Core Care")
        .padding()
}
