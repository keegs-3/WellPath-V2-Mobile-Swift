//
//  FruitsTimingView.swift
//  WellPath
//
//  Full view for Fruits Timing metric (DISP_FRUITS_TIMING).
//  Uses shared NutrientTimingTimelineView.
//

import SwiftUI

struct FruitsTimingView: View {
    let color: Color
    @State private var showAboutModal = false
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private let metricId = "DISP_FRUITS_TIMING"
    private let metricName = "Fruit Timing"

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Fruits")
    }

    var body: some View {
        NutrientTimingTimelineView(nutrientType: .fruits, color: color, showAbout: $showAboutModal)
        .metricScreenBackground(color: color)
        .navigationTitle("Fruit Timing")
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
                    itemId: "DISP_FRUITS_TIMING",
                    displayName: "Fruit Timing",
                    pillar: "Healthful Nutrition",
                    cardId: "CARD_FRUITS_TIMING",
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
            FruitsEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            MetricDataManagementView(config: MetricDataConfig.fruits(color: color))
        }
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(viewId: metricId, metricName: metricName, color: color, isPresented: $showAboutModal)
        }
    }
}

#Preview {
    NavigationStack {
        FruitsTimingView(color: .red)
    }
}
