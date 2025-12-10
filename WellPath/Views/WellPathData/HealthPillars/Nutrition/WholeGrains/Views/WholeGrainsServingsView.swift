//
//  WholeGrainsServingsView.swift
//  WellPath
//
//  Full view for Whole Grains Servings metric (DISP_WHOLE_GRAINS_SERVINGS).
//  Uses shared NutrientServingsFullView.
//

import SwiftUI

struct WholeGrainsServingsView: View {
    let color: Color
    @StateObject private var viewModel = StandardMetricViewModel(metricId: "DISP_WHOLE_GRAINS_SERVINGS")
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Whole Grains")
    }

    var body: some View {
        NutrientServingsFullView(
            viewModel: viewModel,
            color: color,
            screenIcon: screenIcon
        )
        .navigationTitle("Whole Grain Servings")
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
                    itemId: "DISP_WHOLE_GRAINS_SERVINGS",
                    displayName: "Whole Grain Servings",
                    pillar: "Healthful Nutrition",
                    cardId: "CARD_WHOLE_GRAINS_SERVINGS",
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
        .task {
            await viewModel.loadPrimaryScreen()
        }
    }
}

#Preview {
    NavigationStack {
        WholeGrainsServingsView(color: .orange)
    }
}
