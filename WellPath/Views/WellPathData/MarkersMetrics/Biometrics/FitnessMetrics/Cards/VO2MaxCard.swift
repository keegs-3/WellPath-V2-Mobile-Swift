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
            VO2MaxMiniCard(color: color)
        } fullScreen: {
            VO2MaxFullView(color: color)
        }
    }
}

struct VO2MaxMiniCard: View {
    let color: Color
    @StateObject private var loader = BiometricValueLoader()

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: loader.icon ?? "lungs.fill")
                    .font(.title3)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                if loader.isLoading {
                    ProgressView().scaleEffect(0.8)
                } else if let value = loader.currentValue {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", value))
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("mL/kg/min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Text("Maximal oxygen uptake")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .task {
            await loader.loadValue(for: "DISP_VO2_MAX")
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
