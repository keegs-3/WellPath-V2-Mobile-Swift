//
//  FiberAmountView.swift
//  WellPath
//
//  Full view for Fiber Amount metric (DISP_FIBER_GRAMS).
//  Uses shared NutrientServingsFullView.
//

import SwiftUI

struct FiberAmountView: View {
    let color: Color
    @StateObject private var viewModel = StandardMetricViewModel(metricId: "DISP_FIBER_GRAMS")
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Fiber")
    }

    var body: some View {
        NutrientServingsFullView(
            viewModel: viewModel,
            color: color,
            screenIcon: screenIcon,
            metricId: "DISP_FIBER_GRAMS",
            metricName: "Fiber Amount"
        )
        .navigationTitle("Fiber Amount")
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
                    itemId: "DISP_FIBER_GRAMS",
                    displayName: "Fiber Amount",
                    pillar: "Healthful Nutrition",
                    cardId: "CARD_FIBER_GRAMS",
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
            NutritionDataManagementView(color: color, initialCategory: .fiber)
        }
        .task {
            await viewModel.loadPrimaryScreen()
        }
    }
}

#Preview {
    NavigationStack {
        FiberAmountView(color: .green)
    }
}
