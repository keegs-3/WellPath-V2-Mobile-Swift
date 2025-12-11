//
//  HRVCard.swift
//  WellPath
//
//  Individual card for Heart Rate Variability
//

import SwiftUI

struct HRVCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Heart Rate Variability",
            color: color,
            metricId: "DISP_HRV",
            pillar: pillar,
            cardId: "DISP_HRV",
            sectionId: "NAV_BIOMETRICS",
            itemType: .biometric
        ) {
            BiometricMiniCard(metricId: "DISP_HRV", color: color, fallbackIcon: "waveform.path.ecg")
        } fullScreen: {
            HRVView(color: color)
        }
    }
}

#Preview {
    HRVCard(color: .red, pillar: "Core Care")
        .padding()
}
