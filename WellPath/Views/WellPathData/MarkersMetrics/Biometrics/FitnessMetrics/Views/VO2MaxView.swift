//
//  VO2MaxView.swift
//  WellPath
//
//  Full detail view for VO2 Max biometric - chart-only layout
//

import SwiftUI

struct VO2MaxView: View {
    let metric: DisplayMetric
    let color: Color

    @StateObject private var educationLoader = BiometricEducationLoader()
    @State private var showAbout = false
    @State private var showDataManagement = false
    @State private var showAddEntry = false

    private let metricId = "DISP_VO2_MAX"
    private let metricName = "VO2 Max"

    /// DisplayMetric for the BiometricLineChart
    private var displayMetric: DisplayMetric {
        DisplayMetric(
            id: metricId,
            metricId: metricId,
            metricName: metricName,
            description: "Maximal oxygen uptake",
            pillar: nil,
            chartTypeId: "trend_line",
            isActive: true,
            aboutContent: metric.aboutContent,
            longevityImpact: metric.longevityImpact,
            quickTips: metric.quickTips
        )
    }

    var body: some View {
        BiometricLineChart(metric: displayMetric, color: color, showAbout: $showAbout)
            .metricScreenBackground(color: color)
            .navigationTitle(metricName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showDataManagement = true } label: {
                        Image(systemName: "list.bullet")
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    FavoriteButton(
                        itemType: .biometric,
                        itemId: metricId,
                        displayName: metricName,
                        pillar: "Biometrics",
                        cardId: metricId,
                        sectionId: "NAV_BIOMETRICS"
                    )
                    Button { showAddEntry = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showDataManagement) {
                SimpleBiometricDataManagementView(
                    title: metricName,
                    biometricName: BiometricDisplayNames.displayName(for: metricId),
                    unit: "mL/kg/min",
                    color: color
                )
            }
            .sheet(isPresented: $showAddEntry) {
                VO2MaxEntryView()
            }
            .sheet(isPresented: $showAbout) {
                BiometricAboutModal(
                    title: metricName,
                    educationLoader: educationLoader,
                    color: color
                )
            }
            .task {
                await educationLoader.loadSections(for: metricId)
            }
    }
}

#Preview {
    NavigationStack {
        VO2MaxView(
            metric: DisplayMetric(
                id: "DISP_VO2_MAX",
                metricId: "DISP_VO2_MAX",
                metricName: "VO2 Max",
                description: "Maximal oxygen uptake",
                pillar: "Movement + Exercise",
                chartTypeId: nil,
                isActive: true,
                aboutContent: nil,
                longevityImpact: nil,
                quickTips: nil
            ),
            color: .green
        )
    }
}
