//
//  HRVCard.swift
//  WellPath
//
//  Individual card for Heart Rate Variability
//

import SwiftUI

struct HRVCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Heart Rate Variability",
            color: color,
            metricId: "DISP_HRV",
            pillar: pillar,
            cardId: "DISP_HRV",
            sectionId: "NAV_BIOMETRICS",
            itemType: .biometric
        ) {
            HRVMiniCard(color: color)
        } fullScreen: {
            HRVView(color: color)
        }
    }
}

struct HRVMiniCard: View {
    let color: Color
    @StateObject private var loader = BiometricValueLoader()

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: loader.icon ?? "waveform.path.ecg")
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
                        Text(loader.unit ?? "ms")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Text("Heart rate variability")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .task {
            await loader.loadValue(for: "DISP_HRV")
        }
    }
}

#Preview {
    HRVCard(color: .red, pillar: "Core Care")
        .padding()
}
