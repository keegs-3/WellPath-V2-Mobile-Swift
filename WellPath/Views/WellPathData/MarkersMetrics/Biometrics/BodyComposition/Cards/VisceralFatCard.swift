//
//  VisceralFatCard.swift
//  WellPath
//
//  Individual card for Visceral Fat %
//

import SwiftUI

struct VisceralFatCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Visceral Fat %",
            color: color,
            metricId: "DISP_VISCERAL_FAT",
            pillar: pillar,
            cardId: "DISP_VISCERAL_FAT",
            sectionId: "NAV_BIOMETRICS",
            itemType: .biometric
        ) {
            VisceralFatMiniCard(color: color)
        } fullScreen: {
            VisceralFatView(color: color)
        }
    }
}

struct VisceralFatMiniCard: View {
    let color: Color
    @StateObject private var loader = BiometricValueLoader()

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: loader.icon ?? "circle.dotted")
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
                        Text("%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Text("Visceral fat percentage")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .task {
            await loader.loadValue(for: "DISP_VISCERAL_FAT")
        }
    }
}

#Preview {
    VisceralFatCard(color: .orange, pillar: "Core Care")
        .padding()
}
