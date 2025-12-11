//
//  WaistHipRatioCard.swift
//  WellPath
//
//  Individual card for Waist-to-Hip Ratio
//

import SwiftUI

struct WaistHipRatioCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Waist-to-Hip Ratio",
            color: color,
            metricId: "DISP_WAIST_HIP",
            pillar: pillar,
            cardId: "DISP_WAIST_HIP",
            sectionId: "NAV_BIOMETRICS",
            itemType: .biometric
        ) {
            BiometricMiniCard(metricId: "DISP_WAIST_HIP", color: color, fallbackIcon: "figure.stand")
        } fullScreen: {
            WaistHipView(color: color)
        }
    }
}

#Preview {
    WaistHipRatioCard(color: .purple, pillar: "Core Care")
        .padding()
}
