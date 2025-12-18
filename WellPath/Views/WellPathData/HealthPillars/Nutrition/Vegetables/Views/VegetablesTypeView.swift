//
//  VegetablesTypeView.swift
//  WellPath
//
//  Full view for Vegetables Type metric (DISP_VEGETABLES_TYPE).
//  Uses shared NutrientTypeView.
//

import SwiftUI

struct VegetablesTypeView: View {
    let color: Color
    @State private var showAboutModal = false
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private let metricId = "DISP_VEGETABLES_TYPE"
    private let metricName = "Vegetable Type"

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Vegetables")
    }

    var body: some View {
        NutrientTypeView(nutrientType: .vegetables, color: color, showAbout: $showAboutModal)
        .metricScreenBackground(color: color)
        .navigationTitle("Vegetable Type")
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
                    itemId: "DISP_VEGETABLES_TYPE",
                    displayName: "Vegetable Type",
                    pillar: "Healthful Nutrition",
                    cardId: "CARD_VEGETABLES_TYPE",
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
            NutritionDataManagementView(color: color, initialCategory: .vegetables)
        }
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(viewId: metricId, metricName: metricName, color: color, isPresented: $showAboutModal)
        }
    }
}

#Preview {
    NavigationStack {
        VegetablesTypeView(color: .green)
    }
}
