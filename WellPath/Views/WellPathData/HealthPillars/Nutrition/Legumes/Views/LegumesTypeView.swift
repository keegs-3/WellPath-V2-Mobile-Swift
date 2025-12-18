//
//  LegumesTypeView.swift
//  WellPath
//
//  Full view for Legumes Type metric (DISP_LEGUMES_TYPE).
//  Uses shared NutrientTypeView.
//

import SwiftUI

struct LegumesTypeView: View {
    let color: Color
    @State private var showAboutModal = false
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private let metricId = "DISP_LEGUMES_TYPE"
    private let metricName = "Legume Type"

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Legumes")
    }

    var body: some View {
        NutrientTypeView(nutrientType: .legumes, color: color, showAbout: $showAboutModal)
        .metricScreenBackground(color: color)
        .navigationTitle("Legume Type")
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
                    itemId: "DISP_LEGUMES_TYPE",
                    displayName: "Legume Type",
                    pillar: "Healthful Nutrition",
                    cardId: "CARD_LEGUMES_TYPE",
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
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(viewId: metricId, metricName: metricName, color: color, isPresented: $showAboutModal)
        }
    }
}

#Preview {
    NavigationStack {
        LegumesTypeView(color: .green)
    }
}
