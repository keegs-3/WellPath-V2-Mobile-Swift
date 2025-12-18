//
//  WaterScreen.swift
//  WellPath
//
//  Card-based layout for Water/Hydration metric.
//  Shows cards: Amount, Timing.
//

import SwiftUI

struct WaterScreen: View {
    let pillar: String
    let color: Color

    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Water")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Baseline questions (shows if not yet answered)
                TourQuestionsSection(screenId: "SCREEN_WATER", color: color)

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
    }
}

#Preview {
    NavigationStack {
        WaterScreen(pillar: "Healthful Nutrition", color: .cyan)
    }
}
