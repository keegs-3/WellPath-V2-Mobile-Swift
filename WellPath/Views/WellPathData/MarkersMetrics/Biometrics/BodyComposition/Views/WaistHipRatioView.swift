//
//  WaistHipRatioView.swift
//  WellPath
//
//  Full detail view for Waist-to-Hip Ratio biometric
//

import SwiftUI

struct WaistHipRatioView: View {
    let color: Color

    @State private var showAboutModal = false
    @State private var showAddEntry = false
    @State private var showDataManagement = false

    private let metricId = "DISP_WAIST_HIP"
    private let metricName = "Waist-to-Hip Ratio"

    private var displayMetric: DisplayMetric {
        DisplayMetric(
            id: metricId,
            metricId: metricId,
            metricName: "Waist-to-Hip Ratio",
            description: "Ratio of waist to hip circumference",
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
        .navigationTitle("Waist-to-Hip Ratio")
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
                title: "Waist-to-Hip Ratio",
                biometricName: BiometricDisplayNames.displayName(for: metricId),
                unit: "",
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
    NavigationStack { WaistHipRatioView(color: .purple) }
}
