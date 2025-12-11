//
//  GripStrengthView.swift
//  WellPath
//
//  Full detail view for Grip Strength biometric
//  Loads title, subtitle, and unit from database
//

import SwiftUI

struct GripStrengthView: View {
    let color: Color

    @State private var showAboutModal = false
    @State private var showDataManagement = false
    @State private var showAddEntry = false
    @State private var metadata: ViewMetadata?

    private let metricId = "DISP_GRIP_STRENGTH"

    // Computed from metadata with fallbacks
    private var metricName: String { metadata?.title ?? "Grip Strength" }
    private var metricNameLong: String? { metadata?.subtitle }
    private var unitDisplay: String { metadata?.unit ?? "kg" }

    private var displayMetric: DisplayMetric {
        DisplayMetric(
            id: metricId,
            metricId: metricId,
            metricName: metricName,
            description: metricNameLong ?? "Hand grip strength measurement",
            pillar: metadata?.pillar ?? "Core Care",
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
            .sheet(isPresented: $showAddEntry) {
                GripStrengthEntryView()
            }
            .sheet(isPresented: $showDataManagement) {
                SimpleBiometricDataManagementView(
                    title: metricName,
                    biometricName: BiometricDisplayNames.displayName(for: metricId),
                    unit: unitDisplay,
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
            .task {
                metadata = await ViewMetadataService.shared.loadMetadata(for: metricId)
            }
    }
}

#Preview {
    NavigationStack { GripStrengthView(color: .orange) }
}
