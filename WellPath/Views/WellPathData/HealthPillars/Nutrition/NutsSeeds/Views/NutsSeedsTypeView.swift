//
//  NutsSeedsTypeView.swift
//  WellPath
//
//  Full view for Nuts & Seeds Type metric (DISP_NUTS_SEEDS_TYPE).
//  Uses shared NutrientTypeView.
//

import SwiftUI

struct NutsSeedsTypeView: View {
    let color: Color
    @State private var showAboutModal = false
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private let metricId = "DISP_NUTS_SEEDS_TYPE"
    private let metricName = "Nuts & Seeds Type"

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Nuts & Seeds")
    }

    var body: some View {
        NutrientTypeView(nutrientType: .nutsSeeds, color: color, showAbout: $showAboutModal)
        .metricScreenBackground(color: color)
        .navigationTitle("Nuts & Seeds Type")
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
                    itemId: "DISP_NUTS_SEEDS_TYPE",
                    displayName: "Nuts & Seeds Type",
                    pillar: "Healthful Nutrition",
                    cardId: "CARD_NUTS_SEEDS_TYPE",
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
            NutritionDataManagementView(color: color, initialCategory: .nutsSeeds)
        }
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(viewId: metricId, metricName: metricName, color: color, isPresented: $showAboutModal)
        }
    }
}

#Preview {
    NavigationStack {
        NutsSeedsTypeView(color: .brown)
    }
}
