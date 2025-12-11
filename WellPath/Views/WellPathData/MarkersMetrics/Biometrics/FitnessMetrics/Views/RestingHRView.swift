//
//  RestingHRView.swift
//  WellPath
//
//  Full detail view for Resting Heart Rate biometric - chart-only layout
//  Loads title, subtitle, and unit from database
//

import SwiftUI

struct RestingHRView: View {
    let metric: DisplayMetric
    let color: Color

    @State private var showAboutModal = false
    @State private var showDataManagement = false
    @State private var showAddEntry = false
    @State private var metadata: ViewMetadata?

    private let metricId = "DISP_RESTING_HR"

    // Computed from metadata with fallbacks
    private var metricName: String { metadata?.title ?? "Resting Heart Rate" }
    private var metricNameLong: String? { metadata?.subtitle }
    private var unitDisplay: String { metadata?.unit ?? "bpm" }

    /// DisplayMetric for the BiometricLineChart
    private var displayMetric: DisplayMetric {
        DisplayMetric(
            id: metricId,
            metricId: metricId,
            metricName: metricName,
            description: metricNameLong ?? "Beats per minute at rest",
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
                RestingHREntryView()
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
        RestingHRView(
            metric: DisplayMetric(
                id: "DISP_RESTING_HR",
                metricId: "DISP_RESTING_HR",
                metricName: "Resting Heart Rate",
                description: "Beats per minute at rest",
                pillar: "Movement + Exercise",
                chartTypeId: nil,
                isActive: true,
                aboutContent: nil,
                longevityImpact: nil,
                quickTips: nil
            ),
            color: .red
        )
    }
}
