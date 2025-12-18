//
//  LegumesServingsView.swift
//  WellPath
//
//  Full view for Legumes Servings metric (DISP_LEGUMES_SERVINGS).
//  Uses shared NutrientServingsFullView.
//

import SwiftUI

struct LegumesServingsView: View {
    let color: Color
    @StateObject private var viewModel = StandardMetricViewModel(metricId: "DISP_LEGUMES_SERVINGS")
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Legumes")
    }

    var body: some View {
        NutrientServingsFullView(
            viewModel: viewModel,
            color: color,
            screenIcon: screenIcon,
            metricId: "DISP_LEGUMES_SERVINGS",
            metricName: "Legume Servings"
        )
        .navigationTitle("Legume Servings")
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
                    itemId: "DISP_LEGUMES_SERVINGS",
                    displayName: "Legume Servings",
                    pillar: "Healthful Nutrition",
                    cardId: "CARD_LEGUMES_SERVINGS",
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
            NutritionDataManagementView(color: color, initialCategory: .legumes)
        }
        .task {
            await viewModel.loadPrimaryScreen()
        }
    }
}

#Preview {
    NavigationStack {
        LegumesServingsView(color: .green)
    }
}
