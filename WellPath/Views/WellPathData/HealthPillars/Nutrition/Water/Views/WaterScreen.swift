//
//  WaterScreen.swift
//  WellPath
//
//  Card-based layout for Water/Hydration metric.
//  Shows score card at top, then Amount, Timing cards.
//  Follows ProteinScreen pattern for behavioral scores.
//

import SwiftUI

struct WaterScreen: View {
    let pillar: String
    let color: Color

    @StateObject private var scoreViewModel = HydrationScoreViewModel()
    @StateObject private var detailViewModel = GenericScoreDetailViewModel(scoreType: "hydration_score")
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false
    @State private var showingBaseline = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Hydration Score Card - always shown, handles empty state internally
                MetricScoreCard(
                    config: .hydration,
                    color: color,
                    viewModel: scoreViewModel,
                    detailViewBuilder: {
                        GenericScoreDetailView(
                            viewModel: detailViewModel,
                            title: "Hydration Score",
                            iconName: "drop.fill",
                            color: color
                        )
                    },
                    onSetupTapped: {
                        showingBaseline = true
                    }
                )

                // Reusable card components
                WaterAmountCard(color: color, pillar: pillar)
                WaterTimingCard(color: color, pillar: pillar)
            }
            .padding()
            .padding(.bottom, 24)
        }
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

            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        showingBaseline = true
                    } label: {
                        Image(systemName: "book.fill")
                    }

                    Button {
                        showingEntryForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEntryForm) {
            WaterEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            NutritionDataManagementView(color: color, initialCategory: .water)
        }
        .sheet(isPresented: $showingBaseline) {
            SimpleBaselineWizardView(
                baselineViewId: "BASELINE_VIEW_HYDRATION",
                categoryId: "CAT_HYDRATION",
                categoryName: "Hydration",
                scoreId: "SCORE_HYDRATION",
                scoreType: "hydration_score"
            )
        }
        .task {
            await scoreViewModel.loadData()
        }
    }
}

#Preview {
    NavigationStack {
        WaterScreen(pillar: "Healthful Nutrition", color: .cyan)
    }
}
