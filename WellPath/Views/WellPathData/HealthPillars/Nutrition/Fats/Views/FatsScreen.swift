//
//  FatsScreen.swift
//  WellPath
//
//  Card-based layout for Fats metric.
//  Shows cards: Amount, Type.
//

import SwiftUI

struct FatsScreen: View {
    let pillar: String
    let color: Color

    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Fats")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Baseline questions (shows if not yet answered)
                TourQuestionsSection(screenId: "SCREEN_FATS", color: color)

                // Reusable card components
                FatsAmountCard(color: color, pillar: pillar)
                FatsTypeCard(color: color, pillar: pillar)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Fats")
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
            NutritionDataManagementView(color: color, initialCategory: .fats)
        }
    }
}

#Preview {
    NavigationStack {
        FatsScreen(pillar: "Healthful Nutrition", color: .orange)
    }
}
