//
//  CaffeineScreen.swift
//  WellPath
//
//  Card-based layout for Caffeine metric.
//  Shows cards: Amount, Type.
//

import SwiftUI

struct CaffeineScreen: View {
    let pillar: String
    let color: Color

    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Caffeine")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Baseline questions (shows if not yet answered)
                TourQuestionsSection(screenId: "SCREEN_CAFFEINE", color: color)

                // Reusable card components
                CaffeineAmountCard(color: color, pillar: pillar)
                CaffeineTypeCard(color: color, pillar: pillar)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Caffeine")
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
            CaffeineEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            NutritionDataManagementView(color: color, initialCategory: .caffeine)
        }
    }
}

#Preview {
    NavigationStack {
        CaffeineScreen(pillar: "Healthful Nutrition", color: .brown)
    }
}
