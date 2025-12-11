//
//  VO2MaxCard.swift
//  WellPath
//
//  Individual card for VO2 Max
//

import SwiftUI

struct VO2MaxCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "VO2 Max",
            color: color,
            metricId: "DISP_VO2_MAX",
            pillar: pillar,
            cardId: "DISP_VO2_MAX",
            sectionId: "NAV_BIOMETRICS",
            itemType: .biometric
        ) {
            BiometricMiniCard(metricId: "DISP_VO2_MAX", color: color, fallbackIcon: "lungs.fill")
        } fullScreen: {
            VO2MaxFullView(color: color)
        }
    }
}

/// Wrapper to create DisplayMetric and route to VO2MaxView
struct VO2MaxFullView: View {
    let color: Color

    var body: some View {
        let metric = DisplayMetric(
            id: "DISP_VO2_MAX",
            metricId: "DISP_VO2_MAX",
            metricName: "VO2 Max",
            description: "Maximal oxygen uptake",
            pillar: "Movement + Exercise",
            chartTypeId: nil,
            isActive: true,
            aboutContent: nil,
            longevityImpact: nil,
            quickTips: nil
        )
        VO2MaxView(metric: metric, color: color)
    }
}

#Preview {
    VO2MaxCard(color: .green, pillar: "Movement + Exercise")
        .padding()
}
