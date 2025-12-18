//
//  UltraProcessedScreen.swift
//  WellPath
//
//  Card-based layout for Ultra-Processed Foods metric.
//  Shows card: Servings tracking.
//

import SwiftUI

struct UltraProcessedScreen: View {
    let pillar: String
    let color: Color

    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Baseline questions (shows if not yet answered)
                TourQuestionsSection(screenId: "SCREEN_ULTRA_PROCESSED", color: color)

                // Reusable card component
                UltraProcessedServingsCard(color: color, pillar: pillar)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Ultra-Processed")
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
        UltraProcessedScreen(pillar: "Healthful Nutrition", color: .red)
    }
}
