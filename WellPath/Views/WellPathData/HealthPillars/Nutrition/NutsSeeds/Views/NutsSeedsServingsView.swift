//
//  NutsSeedsServingsView.swift
//  WellPath
//
//  Full view for Nuts & Seeds Servings metric (DISP_NUTS_SEEDS_SERVINGS).
//  Uses shared NutrientServingsFullView.
//

import SwiftUI

struct NutsSeedsServingsView: View {
    let color: Color
    @StateObject private var viewModel = StandardMetricViewModel(metricId: "DISP_NUTS_SEEDS_SERVINGS")
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Nuts & Seeds")
    }

    var body: some View {
        NutrientServingsFullView(
            viewModel: viewModel,
            color: color,
            screenIcon: screenIcon,
            metricId: "DISP_NUTS_SEEDS_SERVINGS",
            metricName: "Nuts & Seeds"
        )
        .navigationTitle("Nuts & Seeds")
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
                    itemId: "DISP_NUTS_SEEDS_SERVINGS",
                    displayName: "Nuts & Seeds",
                    pillar: "Healthful Nutrition",
                    cardId: "CARD_NUTS_SEEDS_SERVINGS",
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
        .task {
            await viewModel.loadPrimaryScreen()
        }
    }
}

#Preview {
    NavigationStack {
        NutsSeedsServingsView(color: .brown)
    }
}
