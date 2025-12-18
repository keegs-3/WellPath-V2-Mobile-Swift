//
//  MealPatternsScreen.swift
//  WellPath
//
//  Card-based layout for Meal Patterns metrics.
//  Shows cards: Meal Type, Whole Food, Plant-Based, Homemade.
//

import SwiftUI

struct MealPatternsScreen: View {
    let pillar: String
    let color: Color

    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Baseline questions (shows if not yet answered)
                TourQuestionsSection(screenId: "SCREEN_MEAL_PATTERNS", color: color)

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
            NutritionDataManagementView(color: color)
        }
    }
}

#Preview {
    NavigationStack {
        MealPatternsScreen(pillar: "Healthful Nutrition", color: .indigo)
    }
}
