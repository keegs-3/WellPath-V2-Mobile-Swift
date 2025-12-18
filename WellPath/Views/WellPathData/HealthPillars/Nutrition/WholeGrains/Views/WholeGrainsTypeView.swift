//
//  WholeGrainsTypeView.swift
//  WellPath
//
//  Full view for Whole Grains Type metric (DISP_WHOLE_GRAINS_TYPE).
//  Uses shared NutrientTypeView.
//

import SwiftUI

struct WholeGrainsTypeView: View {
    let color: Color
    @State private var showAboutModal = false
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private let metricId = "DISP_WHOLE_GRAINS_TYPE"
    private let metricName = "Whole Grain Type"

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Whole Grains")
    }

    var body: some View {
        NutrientTypeView(nutrientType: .wholeGrains, color: color, showAbout: $showAboutModal)
        .metricScreenBackground(color: color)
        .navigationTitle("Whole Grain Type")
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
                    itemId: "DISP_WHOLE_GRAINS_TYPE",
                    displayName: "Whole Grain Type",
                    pillar: "Healthful Nutrition",
                    cardId: "CARD_WHOLE_GRAINS_TYPE",
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
            FoodEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            NutritionDataManagementView(color: color, initialCategory: .wholeGrains)
        }
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(viewId: metricId, metricName: metricName, color: color, isPresented: $showAboutModal)
        }
    }
}

#Preview {
    NavigationStack {
        WholeGrainsTypeView(color: .orange)
    }
}
