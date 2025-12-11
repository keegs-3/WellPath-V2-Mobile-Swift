//
//  VisceralFatCard.swift
//  WellPath
//
//  Individual card for Visceral Fat %
//

import SwiftUI

struct VisceralFatCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Visceral Fat %",
            color: color,
            metricId: "DISP_VISCERAL_FAT",
            pillar: pillar,
            cardId: "DISP_VISCERAL_FAT",
            sectionId: "NAV_BIOMETRICS",
            itemType: .biometric
        ) {
            BiometricMiniCard(metricId: "DISP_VISCERAL_FAT", color: color, fallbackIcon: "circle.dotted")
        } fullScreen: {
            VisceralFatView(color: color)
        }
    }
}

#Preview {
    VisceralFatCard(color: .orange, pillar: "Core Care")
        .padding()
}
