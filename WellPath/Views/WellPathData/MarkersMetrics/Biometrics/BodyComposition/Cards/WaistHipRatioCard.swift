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
            WaistHipRatioMiniCard(color: color)
        } fullScreen: {
            WaistHipRatioFullView(color: color)
        }
    }
}

struct WaistHipRatioMiniCard: View {
    let color: Color
    @StateObject private var loader = BiometricValueLoader()

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: loader.icon ?? "figure.stand")
                    .font(.title3)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                if loader.isLoading {
                    ProgressView().scaleEffect(0.8)
                } else if let value = loader.currentValue {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.2f", value))
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("ratio")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Text("Waist to hip ratio")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .task {
            await loader.loadValue(for: "DISP_WAIST_HIP")
        }
    }
}

/// Wrapper to route to WaistHipRatioView
struct WaistHipRatioFullView: View {
    let color: Color

    var body: some View {
        WaistHipRatioView(color: color)
    }
}

#Preview {
    WaistHipRatioCard(color: .purple, pillar: "Core Care")
        .padding()
}
