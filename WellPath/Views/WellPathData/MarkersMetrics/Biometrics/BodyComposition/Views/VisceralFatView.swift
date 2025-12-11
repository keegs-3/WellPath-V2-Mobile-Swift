//
//  VisceralFatView.swift
//  WellPath
//
//  Full detail view for Visceral Fat biometric
//

import SwiftUI

struct VisceralFatView: View {
    let color: Color

    @State private var showAboutModal = false
    @State private var showDataManagement = false
    @State private var showAddEntry = false

    private let metricId = "DISP_VISCERAL_FAT"
    private let metricName = "Visceral Fat"

    private var displayMetric: DisplayMetric {
        DisplayMetric(
            id: metricId,
            metricId: metricId,
            metricName: "Visceral Fat",
            description: "Visceral fat rating",
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
        .navigationTitle("Visceral Fat")
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
            VisceralFatEntryView()
        }
        .sheet(isPresented: $showDataManagement) {
            SimpleBiometricDataManagementView(
                title: "Visceral Fat",
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
    NavigationStack { VisceralFatView(color: .orange) }
}
