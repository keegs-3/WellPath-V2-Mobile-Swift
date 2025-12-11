//
//  BloodPressureCard.swift
//  WellPath
//
//  Individual card for Blood Pressure
//

import SwiftUI

struct BloodPressureCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Blood Pressure",
            color: color,
            metricId: "DISP_BLOOD_PRESSURE",
            pillar: pillar,
            cardId: "DISP_BLOOD_PRESSURE",
            sectionId: "NAV_BIOMETRICS",
            itemType: .biometric
        ) {
            BloodPressureMiniCard(color: color)
        } fullScreen: {
            BloodPressureFullView(color: color)
        }
    }
}

struct BloodPressureMiniCard: View {
    let color: Color
    @StateObject private var systolicLoader = BiometricValueLoader()
    @StateObject private var diastolicLoader = BiometricValueLoader()

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: systolicLoader.icon ?? "heart.fill")
                    .font(.title3)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                if systolicLoader.isLoading || diastolicLoader.isLoading {
                    ProgressView().scaleEffect(0.8)
                } else if let systolic = systolicLoader.currentValue,
                          let diastolic = diastolicLoader.currentValue {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(systolic))/\(Int(diastolic))")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("mmHg")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Text("Blood pressure")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .task {
            // Blood pressure needs both systolic and diastolic values
            async let loadSystolic: () = systolicLoader.loadValue(for: "DISP_SYSTOLIC_BP")
            async let loadDiastolic: () = diastolicLoader.loadValue(for: "DISP_DIASTOLIC_BP")
            _ = await (loadSystolic, loadDiastolic)
        }
    }
}

/// Wrapper to route to BloodPressureView
struct BloodPressureFullView: View {
    let color: Color

    var body: some View {
        BloodPressureView(color: color)
    }
}

#Preview {
    BloodPressureCard(color: .red, pillar: "Core Care")
        .padding()
}
