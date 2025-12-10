//
//  HipCircumferenceView.swift
//  WellPath
//
//  Full detail view for Hip Circumference biometric
//  BiometricLineChart handles unit toggle (in/cm) internally
//

import SwiftUI

struct HipCircumferenceView: View {
    let color: Color

    @State private var showAboutModal = false
    @State private var showAddEntry = false
    @State private var showDataManagement = false

    private let metricId = "DISP_HIP_CIRCUMFERENCE"
    private let metricName = "Hip Circumference"

    private var displayMetric: DisplayMetric {
        DisplayMetric(
            id: metricId,
            metricId: metricId,
            metricName: "Hip Circumference",
            description: "Hip measurement",
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
        .navigationTitle("Hip Circumference")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { showDataManagement = true } label: {
                    Image(systemName: "list.bullet")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddEntry = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddEntry) {
            WaistHipEntryView()
        }
        .sheet(isPresented: $showDataManagement) {
            SimpleBiometricDataManagementView(
                title: "Hip Circumference",
                biometricName: BiometricDisplayNames.displayName(for: metricId),
                unit: "cm",
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
    NavigationStack { HipCircumferenceView(color: .cyan) }
}
