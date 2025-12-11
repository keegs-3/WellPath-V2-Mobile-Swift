//
//  ASMICard.swift
//  WellPath
//
//  Individual card for ASMI (Appendicular Skeletal Muscle Index)
//

import SwiftUI

struct ASMICard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "ASMI",
            color: color,
            metricId: "DISP_ASMI",
            pillar: pillar,
            cardId: "DISP_ASMI",
            sectionId: "NAV_BIOMETRICS",
            itemType: .biometric
        ) {
            BiometricMiniCard(metricId: "DISP_ASMI", color: color, fallbackIcon: "figure.arms.open")
        } fullScreen: {
            ASMIView(color: color)
        }
    }
}

#Preview {
    ASMICard(color: .blue, pillar: "Core Care")
        .padding()
}
