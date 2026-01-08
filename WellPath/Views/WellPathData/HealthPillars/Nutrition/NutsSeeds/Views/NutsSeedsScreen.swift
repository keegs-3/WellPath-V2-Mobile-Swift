//
//  NutsSeedsScreen.swift
//  WellPath
//
//  Card-based layout for Nuts & Seeds metric.
//  Shows score card at top, then Servings, Types cards.
//

import SwiftUI

struct NutsSeedsScreen: View {
    let pillar: String
    let color: Color

    @StateObject private var scoreViewModel = NutsSeedsScoreViewModel()
    @StateObject private var detailViewModel = GenericScoreDetailViewModel(scoreType: "nuts_seeds_score")
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false
    @State private var showingBaseline = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Nuts & Seeds Score Card
                // MetricScoreCard handles empty state internally when hasBaselineData is false
                MetricScoreCard(
                    config: .nutsSeeds,
                    color: color,
                    viewModel: scoreViewModel,
                    detailViewBuilder: {
                        GenericScoreDetailView(
                            viewModel: detailViewModel,
                            title: "Nuts & Seeds Score",
                            iconName: MetricsUIConfig.getIcon(for: "Nuts & Seeds"),
                            color: color
                        )
                    },
                    onSetupTapped: {
                        showingBaseline = true
                    }
                )

                // Reusable card components
                NutsSeedsServingsCard(color: color, pillar: pillar)
                NutsSeedsTypeCard(color: color, pillar: pillar)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Nuts & Seeds")
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
            FoodEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            NutritionDataManagementView(color: color)
        }
        .sheet(isPresented: $showingBaseline) {
            SimpleBaselineWizardView(
                baselineViewId: "BASELINE_VIEW_NUTS_SEEDS",
                categoryId: "CAT_NUTS_SEEDS",
                categoryName: "Nuts & Seeds",
                scoreId: "SCORE_NUTS_SEEDS",
                scoreType: "nuts_seeds_score"
            )
        }
        .task {
            await scoreViewModel.loadData()
        }
    }
}

#Preview {
    NavigationStack {
        NutsSeedsScreen(pillar: "Healthful Nutrition", color: .brown)
    }
}
