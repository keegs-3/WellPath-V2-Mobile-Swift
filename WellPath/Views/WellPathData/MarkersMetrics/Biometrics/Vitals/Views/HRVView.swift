//
//  HRVView.swift
//  WellPath
//
//  Full detail view for Heart Rate Variability (HRV)
//

import SwiftUI

struct HRVView: View {
    let color: Color

    @State private var showAboutModal = false
    @State private var showDataManagement = false
    @State private var showAddEntry = false

    private let metricId = "DISP_HRV"
    private let metricName = "HRV"

    private var displayMetric: DisplayMetric {
        DisplayMetric(
            id: metricId,
            metricId: metricId,
            metricName: "HRV",
            description: "Heart Rate Variability",
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
        .navigationTitle("HRV")
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
            HRVEntryView()
        }
        .sheet(isPresented: $showDataManagement) {
            SimpleBiometricDataManagementView(
                title: "HRV",
                biometricName: BiometricDisplayNames.displayName(for: metricId),
                unit: "ms",
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
    NavigationStack { HRVView(color: .red) }
}
