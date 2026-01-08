//
//  MealPatternsScreen.swift
//  WellPath
//
//  Card-based layout for Meal Patterns metrics.
//  Shows score card at top, then Meal Type, Whole Food, Plant-Based, Homemade cards.
//

import SwiftUI

struct MealPatternsScreen: View {
    let pillar: String
    let color: Color

    @StateObject private var scoreViewModel = MealPatternsScoreViewModel()
    @StateObject private var detailViewModel = GenericScoreDetailViewModel(scoreType: "meal_patterns_score")
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false
    @State private var showingBaseline = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Meal Patterns Score Card
                // MetricScoreCard handles empty state internally when hasBaselineData is false
                MetricScoreCard(
                    config: .mealPatterns,
                    color: color,
                    viewModel: scoreViewModel,
                    detailViewBuilder: {
                        GenericScoreDetailView(
                            viewModel: detailViewModel,
                            title: "Meal Patterns Score",
                            iconName: MetricsUIConfig.getIcon(for: "Meal Patterns"),
                            color: color
                        )
                    },
                    onSetupTapped: {
                        showingBaseline = true
                    }
                )

                // Reusable card components
                MealTypeCard(color: color, pillar: pillar)
                WholeFoodMealsCard(color: color, pillar: pillar)
                PlantBasedMealsCard(color: color, pillar: pillar)
                HomemadeMealsCard(color: color, pillar: pillar)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Meal Patterns")
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
                baselineViewId: "BASELINE_VIEW_MEAL_PATTERNS",
                categoryId: "CAT_MEAL_PATTERNS",
                categoryName: "Meal Patterns",
                scoreId: "SCORE_MEAL_PATTERNS",
                scoreType: "meal_patterns_score"
            )
        }
        .task {
            await scoreViewModel.loadData()
        }
    }
}

#Preview {
    NavigationStack {
        MealPatternsScreen(pillar: "Healthful Nutrition", color: .indigo)
    }
}
