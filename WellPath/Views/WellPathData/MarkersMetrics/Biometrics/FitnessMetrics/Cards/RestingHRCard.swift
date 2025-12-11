//
//  RestingHRCard.swift
//  WellPath
//
//  Individual card for Resting Heart Rate
//

import SwiftUI

struct RestingHRCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Resting Heart Rate",
            color: color,
            metricId: "DISP_RESTING_HR",
            pillar: pillar,
            cardId: "DISP_RESTING_HR",
            sectionId: "NAV_BIOMETRICS",
            itemType: .biometric
        ) {
            BiometricMiniCard(metricId: "DISP_RESTING_HR", color: color, fallbackIcon: "heart.fill")
        } fullScreen: {
            RestingHRFullView(color: color)
        }
    }
}

/// Wrapper to create DisplayMetric and route to RestingHRView
struct RestingHRFullView: View {
    let color: Color

    var body: some View {
        let metric = DisplayMetric(
            id: "DISP_RESTING_HR",
            metricId: "DISP_RESTING_HR",
            metricName: "Resting Heart Rate",
            description: "Beats per minute at rest",
            pillar: "Movement + Exercise",
            chartTypeId: nil,
            isActive: true,
            aboutContent: nil,
            longevityImpact: nil,
            quickTips: nil
        )
        RestingHRView(metric: metric, color: color)
    }
}

#Preview {
    RestingHRCard(color: .red, pillar: "Movement + Exercise")
        .padding()
}
