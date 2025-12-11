//
//  GripStrengthCard.swift
//  WellPath
//
//  Individual card for Grip Strength
//

import SwiftUI

struct GripStrengthCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Grip Strength",
            color: color,
            metricId: "DISP_GRIP_STRENGTH",
            pillar: pillar,
            cardId: "DISP_GRIP_STRENGTH",
            sectionId: "NAV_BIOMETRICS",
            itemType: .biometric
        ) {
            GripStrengthMiniCard(color: color)
        } fullScreen: {
            GripStrengthView(color: color)
        }
    }
}

struct GripStrengthMiniCard: View {
    let color: Color
    @StateObject private var loader = BiometricValueLoader()

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: loader.icon ?? "hand.raised.fill")
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
                Text("Grip strength")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .task {
            await loader.loadValue(for: "DISP_GRIP_STRENGTH")
        }
    }
}

#Preview {
    GripStrengthCard(color: .purple, pillar: "Core Care")
        .padding()
}
