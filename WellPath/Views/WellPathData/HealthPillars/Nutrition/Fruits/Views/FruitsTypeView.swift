//
//  FruitsTypeView.swift
//  WellPath
//
//  Full view for Fruits Type metric (DISP_FRUITS_TYPE).
//  Uses shared NutrientTypeView.
//

import SwiftUI

struct FruitsTypeView: View {
    let color: Color
    @State private var showAboutModal = false
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private let metricId = "DISP_FRUITS_TYPE"
    private let metricName = "Fruit Type"

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Fruits")
    }

    var body: some View {
        NutrientTypeView(nutrientType: .fruits, color: color, showAbout: $showAboutModal)
        .metricScreenBackground(color: color)
        .navigationTitle("Fruit Type")
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
                    itemId: "DISP_FRUITS_TYPE",
                    displayName: "Fruit Type",
                    pillar: "Healthful Nutrition",
                    cardId: "CARD_FRUITS_TYPE",
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
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(viewId: metricId, metricName: metricName, color: color, isPresented: $showAboutModal)
        }
    }
}

#Preview {
    NavigationStack {
        FruitsTypeView(color: .red)
    }
}
