//
//  VegetablesServingsView.swift
//  WellPath
//
//  Full view for Vegetables Servings metric (DISP_VEGETABLES_SERVINGS).
//  Uses shared NutrientServingsFullView.
//

import SwiftUI

struct VegetablesServingsView: View {
    let color: Color
    @StateObject private var viewModel = StandardMetricViewModel(metricId: "DISP_VEGETABLES_SERVINGS")
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Vegetables")
    }

    var body: some View {
        NutrientServingsFullView(
            viewModel: viewModel,
            color: color,
            screenIcon: screenIcon
        )
        .navigationTitle("Vegetable Servings")
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
                    itemId: "DISP_VEGETABLES_SERVINGS",
                    displayName: "Vegetable Servings",
                    pillar: "Healthful Nutrition",
                    cardId: "CARD_VEGETABLES_SERVINGS",
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
        .task {
            await viewModel.loadPrimaryScreen()
        }
    }
}

#Preview {
    NavigationStack {
        VegetablesServingsView(color: .green)
    }
}
