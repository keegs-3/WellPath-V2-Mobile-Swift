//
//  GripStrengthView.swift
//  WellPath
//
//  Full detail view for Grip Strength biometric
//

import SwiftUI

struct GripStrengthView: View {
    let color: Color

    @State private var showAboutModal = false
    @State private var showDataManagement = false

    private let metricId = "DISP_GRIP_STRENGTH"
    private let metricName = "Grip Strength"

    private var displayMetric: DisplayMetric {
        DisplayMetric(
            id: metricId,
            metricId: metricId,
            metricName: "Grip Strength",
            description: "Hand grip strength measurement",
            pillar: "Core Care",
            chartTypeId: "trend_line",
            isActive: true,
            aboutContent: nil,
            longevityImpact: nil,
            quickTips: nil
        )
    }

    var body: some View {
        BiometricLineChart(metric: displayMetric, color: color, showAbout: $showAboutModal)
            .metricScreenBackground(color: color)
        .navigationTitle("Grip Strength")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { showDataManagement = true } label: {
                    Image(systemName: "list.bullet")
                }
            }
        }
        .sheet(isPresented: $showDataManagement) {
            SimpleBiometricDataManagementView(
                title: "Grip Strength",
                biometricName: BiometricDisplayNames.displayName(for: metricId),
                unit: "kg",
                color: color
            )
        }
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(
                viewId: metricId,
                metricName: metricName,
                color: color,
                isPresented: $showAboutModal
            )
        }
    }
}

#Preview {
    NavigationStack { GripStrengthView(color: .orange) }
}
