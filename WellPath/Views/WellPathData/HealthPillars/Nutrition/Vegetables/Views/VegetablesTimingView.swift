//
//  VegetablesTimingView.swift
//  WellPath
//
//  Full view for Vegetables Timing metric (DISP_VEGETABLES_TIMING).
//  Uses shared NutrientTimingTimelineView.
//

import SwiftUI

struct VegetablesTimingView: View {
    let color: Color
    @State private var showAboutModal = false
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private let metricId = "DISP_VEGETABLES_TIMING"
    private let metricName = "Vegetable Timing"

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Vegetables")
    }

    var body: some View {
        NutrientTimingTimelineView(nutrientType: .vegetables, color: color, showAbout: $showAboutModal)
        .metricScreenBackground(color: color)
        .navigationTitle("Vegetable Timing")
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
                    itemId: "DISP_VEGETABLES_TIMING",
                    displayName: "Vegetable Timing",
                    pillar: "Healthful Nutrition",
                    cardId: "CARD_VEGETABLES_TIMING",
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
            VegetablesEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            MetricDataManagementView(config: MetricDataConfig.vegetables(color: color))
        }
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(viewId: metricId, metricName: metricName, color: color, isPresented: $showAboutModal)
        }
    }
}

#Preview {
    NavigationStack {
        VegetablesTimingView(color: .green)
    }
}
