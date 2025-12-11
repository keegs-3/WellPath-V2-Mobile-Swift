//
//  BMIView.swift
//  WellPath
//
//  Full detail view for BMI (Body Mass Index) biometric
//  BMI is calculated from height and weight, not directly entered
//  Loads title, subtitle, and unit from database
//

import SwiftUI

struct BMIView: View {
    let color: Color

    @State private var showAboutModal = false
    @State private var showDataManagement = false
    @State private var showAddEntry = false
    @State private var metadata: ViewMetadata?

    private let metricId = "DISP_BMI"

    // Computed from metadata with fallbacks
    private var metricName: String { metadata?.title ?? "BMI" }
    private var metricNameLong: String? { metadata?.subtitle }
    private var unitDisplay: String { metadata?.unit ?? "kg/m²" }

    /// DisplayMetric for the BiometricLineChart
    private var displayMetric: DisplayMetric {
        DisplayMetric(
            id: metricId,
            metricId: metricId,
            metricName: metricName,
            description: metricNameLong ?? "Body Mass Index",
            pillar: metadata?.pillar,
            chartTypeId: "trend_line",
            isActive: true,
            aboutContent: nil,
            longevityImpact: nil,
            quickTips: nil
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
                BMIDataManagementView(color: color)
            }
            .sheet(isPresented: $showAddEntry) {
                BMIEntryView()
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
        BMIView(color: .cyan)
    }
}
