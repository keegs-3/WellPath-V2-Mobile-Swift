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
            RestingHRMiniCard(color: color)
        } fullScreen: {
            RestingHRFullView(color: color)
        }
    }
}

struct RestingHRMiniCard: View {
    let color: Color
    @StateObject private var loader = BiometricValueLoader()

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: loader.icon ?? "heart.fill")
                    .font(.title3)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                if loader.isLoading {
                    ProgressView().scaleEffect(0.8)
                } else if let value = loader.currentValue {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.0f", value))
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("bpm")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Text("Resting heart rate")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .task {
            await loader.loadValue(for: "DISP_RESTING_HR")
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
