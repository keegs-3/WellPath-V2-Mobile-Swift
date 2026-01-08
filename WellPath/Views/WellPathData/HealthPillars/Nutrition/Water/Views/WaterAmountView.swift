//
//  WaterAmountView.swift
//  WellPath
//
//  Full view for Water Amount metric (DISP_HYDRATION_AMOUNT).
//  Uses custom WaterLineChart with unit preference support (mL/oz toggle).
//

import SwiftUI

struct WaterAmountView: View {
    let color: Color

    @State private var showingEntryForm = false
    @State private var showingDataManagement = false
    @State private var showAboutModal = false

    private let metricId = "DISP_HYDRATION_AMOUNT"
    private let metricName = "Hydration"

    var body: some View {
        WaterLineChart(color: color, showAbout: $showAboutModal)
            .metricScreenBackground(color: color)
            .navigationTitle("Hydration")
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
                        itemId: metricId,
                        displayName: metricName,
                        pillar: "Healthful Nutrition",
                        cardId: "CARD_HYDRATION_AMOUNT",
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
                WaterEntryView()
            }
            .sheet(isPresented: $showingDataManagement) {
                NutritionDataManagementView(color: color, initialCategory: .water)
            }
            .sheet(isPresented: $showAboutModal) {
                MetricEducationModal(
                    viewId: metricId,
                    metricName: metricName,
                    color: color,
                    isPresented: $showAboutModal
                )
            }
    }
}

#Preview {
    NavigationStack {
        WaterAmountView(color: .cyan)
    }
}
