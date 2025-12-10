//
//  BodyFatCard.swift
//  WellPath
//
//  Individual card for Body Fat %
//

import SwiftUI

struct BodyFatCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Body Fat %",
            color: color,
            metricId: "DISP_BODYFAT",
            pillar: pillar,
            cardId: "DISP_BODYFAT",
            sectionId: "NAV_BIOMETRICS",
            itemType: .biometric
        ) {
            BodyFatMiniCard(color: color)
        } fullScreen: {
            BodyFatFullView(color: color)
        }
    }
}

struct BodyFatMiniCard: View {
    let color: Color
    @StateObject private var loader = BiometricValueLoader()

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: loader.icon ?? "percent")
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
                Text("Body fat percentage")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .task {
            await loader.loadValue(for: "DISP_BODYFAT")
        }
    }
}

/// Wrapper to route to BodyFatView
struct BodyFatFullView: View {
    let color: Color

    var body: some View {
        BodyFatView(color: color)
    }
}

#Preview {
    BodyFatCard(color: .orange, pillar: "Core Care")
        .padding()
}
