//
//  ASMICard.swift
//  WellPath
//
//  Individual card for ASMI (Appendicular Skeletal Muscle Index)
//

import SwiftUI

struct ASMICard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "ASMI",
            color: color,
            metricId: "DISP_ASMI",
            pillar: pillar,
            cardId: "DISP_ASMI",
            sectionId: "NAV_BIOMETRICS",
            itemType: .biometric
        ) {
            ASMIMiniCard(color: color)
        } fullScreen: {
            ASMIView(color: color)
        }
    }
}

struct ASMIMiniCard: View {
    let color: Color
    @StateObject private var loader = BiometricValueLoader()

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: loader.icon ?? "figure.arms.open")
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
                        Text(loader.unit ?? "kg/m²")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Text("Appendicular Skeletal Muscle Index")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .task {
            await loader.loadValue(for: "DISP_ASMI")
        }
    }
}

#Preview {
    ASMICard(color: .blue, pillar: "Core Care")
        .padding()
}
