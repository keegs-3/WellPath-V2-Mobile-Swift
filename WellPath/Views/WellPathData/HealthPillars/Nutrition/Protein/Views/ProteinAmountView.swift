//
//  ProteinAmountView.swift
//  WellPath
//
//  Full view for Protein Amount metric (DISP_PROTEIN_GRAMS).
//  Uses shared NutrientServingsFullView.
//

import SwiftUI

struct ProteinAmountView: View {
    let color: Color
    @StateObject private var viewModel = StandardMetricViewModel(metricId: "DISP_PROTEIN_GRAMS")
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Protein Intake")
    }

    var body: some View {
        NutrientServingsFullView(
            viewModel: viewModel,
            color: color,
            screenIcon: screenIcon,
            metricId: "DISP_PROTEIN_GRAMS",
            metricName: "Protein Amount"
        )
        .navigationTitle("Protein Amount")
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
                    itemId: "DISP_PROTEIN_GRAMS",
                    displayName: "Protein Amount",
                    pillar: "Healthful Nutrition",
                    cardId: "CARD_PROTEIN_AMOUNT",
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
            NutritionDataManagementView(color: color, initialCategory: .protein)
        }
        .task {
            await viewModel.loadPrimaryScreen()
        }
    }
}

#Preview {
    NavigationStack {
        ProteinAmountView(color: .green)
    }
}
