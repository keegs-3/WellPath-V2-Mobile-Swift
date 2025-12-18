//
//  CaffeineAmountView.swift
//  WellPath
//
//  Full view for Caffeine Amount metric (DISP_CAFFEINE_MG).
//  Uses shared NutrientServingsFullView.
//

import SwiftUI

struct CaffeineAmountView: View {
    let color: Color
    @StateObject private var viewModel = StandardMetricViewModel(metricId: "DISP_CAFFEINE_MG")
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Caffeine")
    }

    var body: some View {
        NutrientServingsFullView(
            viewModel: viewModel,
            color: color,
            screenIcon: screenIcon,
            metricId: "DISP_CAFFEINE_MG",
            metricName: "Caffeine Amount"
        )
        .navigationTitle("Caffeine Amount")
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
                    itemId: "DISP_CAFFEINE_MG",
                    displayName: "Caffeine Amount",
                    pillar: "Healthful Nutrition",
                    cardId: "CARD_CAFFEINE_MG",
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
            NutritionDataManagementView(color: color, initialCategory: .caffeine)
        }
        .task {
            await viewModel.loadPrimaryScreen()
        }
    }
}

#Preview {
    NavigationStack {
        CaffeineAmountView(color: .brown)
    }
}
