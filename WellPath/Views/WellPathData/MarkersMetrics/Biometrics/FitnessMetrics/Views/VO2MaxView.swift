//
//  VO2MaxView.swift
//  WellPath
//
//  Full detail view for VO2 Max biometric - chart-only layout
//  Loads title, subtitle, and unit from database
//

import SwiftUI

struct VO2MaxView: View {
    let metric: DisplayMetric
    let color: Color

    @State private var showAboutModal = false
    @State private var showDataManagement = false
    @State private var showAddEntry = false
    @State private var metadata: ViewMetadata?

    private let metricId = "DISP_VO2_MAX"

    // Computed from metadata with fallbacks
    private var metricName: String { metadata?.title ?? "VO2 Max" }
    private var metricNameLong: String? { metadata?.subtitle }
    private var unitDisplay: String { metadata?.unit ?? "mL/kg/min" }

    /// DisplayMetric for the BiometricLineChart
    private var displayMetric: DisplayMetric {
        DisplayMetric(
            id: metricId,
            metricId: metricId,
            metricName: metricName,
            description: metricNameLong ?? "Maximal oxygen uptake",
            pillar: metadata?.pillar,
            chartTypeId: "trend_line",
            isActive: true,
            aboutContent: metric.aboutContent,
            longevityImpact: metric.longevityImpact,
            quickTips: metric.quickTips
        )
    }

    var body: some View {
        BiometricLineChart(metric: displayMetric, color: color, showAbout: $showAboutModal, subtitle: metricNameLong)
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
                    unit: unitDisplay,
                    color: color
                )
            }
            .sheet(isPresented: $showAddEntry) {
                VO2MaxEntryView()
            }
            .sheet(isPresented: $showAboutModal) {
                MetricEducationModal(
                    viewId: metricId,
                    metricName: metricName,
                    color: color,
                    isPresented: $showAboutModal
                )
            }
            .task {
                metadata = await ViewMetadataService.shared.loadMetadata(for: metricId)
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
