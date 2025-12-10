//
//  BodyWeightCard.swift
//  WellPath
//
//  Individual card for Body Weight
//

import SwiftUI

struct BodyWeightCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Body Weight",
            color: color,
            metricId: "DISP_BODYWEIGHT",
            pillar: pillar,
            cardId: "DISP_BODYWEIGHT",
            sectionId: "NAV_BIOMETRICS",
            itemType: .biometric
        ) {
            BodyWeightMiniCard(color: color)
        } fullScreen: {
            BodyWeightFullView(color: color)
        }
    }
}

struct BodyWeightMiniCard: View {
    let color: Color
    @StateObject private var loader = BiometricValueLoader()

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: loader.icon ?? "scalemass.fill")
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
                        Text(loader.unit ?? "kg")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Text("Body weight")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .task {
            await loader.loadValue(for: "DISP_BODYWEIGHT")
        }
    }
}

/// Wrapper to route to BodyWeightView
struct BodyWeightFullView: View {
    let color: Color

    var body: some View {
        BodyWeightView(color: color)
    }
}

#Preview {
    BodyWeightCard(color: .blue, pillar: "Core Care")
        .padding()
}
