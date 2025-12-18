//
//  NutsSeedsScreen.swift
//  WellPath
//
//  Card-based layout for Nuts & Seeds metric.
//  Shows cards: Servings, Types.
//

import SwiftUI

struct NutsSeedsScreen: View {
    let pillar: String
    let color: Color

    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Nuts & Seeds")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Baseline questions (shows if not yet answered)
                TourQuestionsSection(screenId: "SCREEN_NUTS_SEEDS", color: color)

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
        NutsSeedsScreen(pillar: "Healthful Nutrition", color: .brown)
    }
}
