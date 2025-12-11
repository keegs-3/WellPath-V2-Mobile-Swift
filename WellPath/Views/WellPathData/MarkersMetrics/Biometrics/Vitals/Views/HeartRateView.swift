//
//  HeartRateView.swift
//  WellPath
//
//  Full detail view for Heart Rate biometric
//  Shows time series heart rate with min/max ranges
//  Loads title, subtitle, and unit from database
//

import SwiftUI

struct HeartRateView: View {
    let color: Color

    @State private var showAboutModal = false
    @State private var showDataManagement = false
    @State private var metadata: ViewMetadata?

    private let metricId = "DISP_HEART_RATE"

    // Computed from metadata with fallbacks
    private var metricName: String { metadata?.title ?? "Heart Rate" }
    private var metricNameLong: String? { metadata?.subtitle }

    var body: some View {
        HeartRateRangeChart(color: color, showAbout: $showAboutModal)
            .metricScreenBackground(color: color)
            .navigationTitle(metricName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showDataManagement = true
                    } label: {
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
                }
            }
            .sheet(isPresented: $showDataManagement) {
                HeartRateDataManagementView(color: color)
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
        HeartRateView(color: .red)
    }
}
