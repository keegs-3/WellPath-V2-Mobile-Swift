//
//  LegumesTimingView.swift
//  WellPath
//
//  Full view for Legumes Timing metric (DISP_LEGUMES_TIMING).
//  Uses shared NutrientTimingTimelineView.
//

import SwiftUI

struct LegumesTimingView: View {
    let color: Color
    @State private var showAboutModal = false
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private let metricId = "DISP_LEGUMES_TIMING"
    private let metricName = "Legume Timing"

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Legumes")
    }

    var body: some View {
        NutrientTimingTimelineView(nutrientType: .legumes, color: color, showAbout: $showAboutModal)
        .metricScreenBackground(color: color)
        .navigationTitle("Legume Timing")
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
                    itemId: "DISP_LEGUMES_TIMING",
                    displayName: "Legume Timing",
                    pillar: "Healthful Nutrition",
                    cardId: "CARD_LEGUMES_TIMING",
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
            LegumesEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            MetricDataManagementView(config: MetricDataConfig.legumes(color: color))
        }
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(viewId: metricId, metricName: metricName, color: color, isPresented: $showAboutModal)
        }
    }
}

#Preview {
    NavigationStack {
        LegumesTimingView(color: .green)
    }
}
