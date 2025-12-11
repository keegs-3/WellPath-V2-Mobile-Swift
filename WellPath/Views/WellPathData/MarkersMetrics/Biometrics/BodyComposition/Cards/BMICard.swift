//
//  BMICard.swift
//  WellPath
//
//  Individual card for BMI
//

import SwiftUI

struct BMICard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "BMI",
            color: color,
            metricId: "DISP_BMI",
            pillar: pillar,
            cardId: "DISP_BMI",
            sectionId: "NAV_BIOMETRICS",
            itemType: .biometric
        ) {
            BiometricMiniCard(metricId: "DISP_BMI", color: color, fallbackIcon: "figure.stand")
        } fullScreen: {
            BMIView(color: color)
        }
    }
}

#Preview {
    BMICard(color: .blue, pillar: "Core Care")
        .padding()
}
