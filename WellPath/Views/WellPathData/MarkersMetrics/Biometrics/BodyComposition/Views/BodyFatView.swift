//
//  BodyFatView.swift
//  WellPath
//
//  Full detail view for Body Fat % biometric
//

import SwiftUI

struct BodyFatView: View {
    let color: Color

    @StateObject private var educationLoader = BiometricEducationLoader()
    @State private var showAbout = false
    @State private var showDataManagement = false
    @State private var showAddEntry = false

    private let metricId = "DISP_BODYFAT"
    private let metricName = "Body Fat %"

    /// DisplayMetric for the BiometricLineChart
    private var displayMetric: DisplayMetric {
        DisplayMetric(
            id: metricId,
            metricId: metricId,
            metricName: metricName,
            description: "Body fat percentage",
            pillar: nil,  // Section info loaded from database via card → category → section
            chartTypeId: "trend_line",
            isActive: true,
            aboutContent: nil,
            longevityImpact: nil,
            quickTips: nil
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
                BodyFatDataManagementView(color: color)
            }
            .sheet(isPresented: $showAddEntry) {
                BodyFatEntryView()
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
    NavigationStack { BodyFatView(color: .cyan) }
}
