//
//  WholeGrainsTimingView.swift
//  WellPath
//
//  Full view for Whole Grains Timing metric (DISP_WHOLE_GRAINS_TIMING).
//  Uses shared NutrientTimingTimelineView.
//

import SwiftUI

struct WholeGrainsTimingView: View {
    let color: Color
    @State private var showAboutModal = false
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private let metricId = "DISP_WHOLE_GRAINS_TIMING"
    private let metricName = "Whole Grain Timing"

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Whole Grains")
    }

    var body: some View {
        NutrientTimingTimelineView(nutrientType: .wholeGrains, color: color, showAbout: $showAboutModal)
        .metricScreenBackground(color: color)
        .navigationTitle("Whole Grain Timing")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingDataManagement = true
                } label: {
                    Image(systemName: "list.bullet")
                }
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                FavoriteButton(
                    itemType: .metric,
                    itemId: "DISP_WHOLE_GRAINS_TIMING",
                    displayName: "Whole Grain Timing",
                    pillar: "Healthful Nutrition",
                    cardId: "CARD_WHOLE_GRAINS_TIMING",
                    sectionId: "NAV_NUTRITION"
                )

                Button {
                    showingEntryForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEntryForm) {
            WholeGrainsEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            MetricDataManagementView(config: MetricDataConfig.wholeGrains(color: color))
        }
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(viewId: metricId, metricName: metricName, color: color, isPresented: $showAboutModal)
        }
    }
}

#Preview {
    NavigationStack {
        WholeGrainsTimingView(color: .orange)
    }
}
