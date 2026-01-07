//
//  FatsScreen.swift
//  WellPath
//
//  Card-based layout for Fats metric.
//  Shows score card at top, then 2 cards: Amount, Type.
//  Follows ProteinScreen pattern for behavioral scores.
//

import SwiftUI

struct FatsScreen: View {
    let pillar: String
    let color: Color

    @StateObject private var scoreViewModel = FatsScoreViewModel()
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false
    @State private var showingBaseline = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Fats Score Card - taps to detail (show if baseline wizard completed)
                if scoreViewModel.hasScore || scoreViewModel.hasBaselineData || scoreViewModel.hasDailyScore {
                    MetricScoreCard(
                        config: .fats,
                        color: color,
                        viewModel: scoreViewModel
                    ) {
                        FatsScoreDetailView(viewModel: scoreViewModel, color: color)
                    }
                } else {
                    MetricScoreEmptyCard(config: .fats, color: color) {
                        showingBaseline = true
                    }
                }

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
            NutritionDataManagementView(color: color, initialCategory: .fats)
        }
        .sheet(isPresented: $showingBaseline) {
            FatsWizardView()
        }
        .task {
            await scoreViewModel.loadData()
        }
    }
}

#Preview {
    NavigationStack {
        FatsScreen(pillar: "Healthful Nutrition", color: .orange)
    }
}
