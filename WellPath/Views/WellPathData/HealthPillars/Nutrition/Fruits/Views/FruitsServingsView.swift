//
//  FruitsServingsView.swift
//  WellPath
//
//  Full view for Fruits Servings metric (DISP_FRUITS_SERVINGS).
//  Uses shared NutrientServingsFullView.
//

import SwiftUI

struct FruitsServingsView: View {
    let color: Color
    @StateObject private var viewModel = StandardMetricViewModel(metricId: "DISP_FRUITS_SERVINGS")
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Fruits")
    }

    var body: some View {
        NutrientServingsFullView(
            viewModel: viewModel,
            color: color,
            screenIcon: screenIcon,
            metricId: "DISP_FRUITS_SERVINGS",
            metricName: "Fruit Servings"
        )
        .navigationTitle("Fruit Servings")
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
                    itemId: "DISP_FRUITS_SERVINGS",
                    displayName: "Fruit Servings",
                    pillar: "Healthful Nutrition",
                    cardId: "CARD_FRUITS_SERVINGS",
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
            NutritionDataManagementView(color: color, initialCategory: .fruits)
        }
        .task {
            await viewModel.loadPrimaryScreen()
        }
    }
}

#Preview {
    NavigationStack {
        FruitsServingsView(color: .red)
    }
}
