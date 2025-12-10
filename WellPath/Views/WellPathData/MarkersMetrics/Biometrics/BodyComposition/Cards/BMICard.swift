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
            BMIMiniCard(color: color)
        } fullScreen: {
            BMIFullView(color: color)
        }
    }
}

struct BMIMiniCard: View {
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
                        Text(String(format: "%.1f", value))
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("kg/m²")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Text("Body Mass Index")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .task {
            await loader.loadValue(for: "DISP_BMI")
        }
    }
}

/// Wrapper to route to BMIView
struct BMIFullView: View {
    let color: Color

    var body: some View {
        BMIView(color: color)
    }
}

#Preview {
    BMICard(color: .blue, pillar: "Core Care")
        .padding()
}
