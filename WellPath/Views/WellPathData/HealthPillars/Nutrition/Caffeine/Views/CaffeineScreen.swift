//
//  CaffeineScreen.swift
//  WellPath
//
//  Card-based layout for Caffeine metric.
//  Shows score card at top, then Amount, Type cards.
//

import SwiftUI

struct CaffeineScreen: View {
    let pillar: String
    let color: Color

    @StateObject private var scoreViewModel = CaffeineScoreViewModel()
    @StateObject private var detailViewModel = GenericScoreDetailViewModel(scoreType: "caffeine_score")
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false
    @State private var showingBaseline = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Caffeine Score Card
                // MetricScoreCard handles empty state internally when hasBaselineData is false
                MetricScoreCard(
                    config: .caffeine,
                    color: color,
                    viewModel: scoreViewModel,
                    detailViewBuilder: {
                        GenericScoreDetailView(
                            viewModel: detailViewModel,
                            title: "Caffeine Score",
                            iconName: MetricsUIConfig.getIcon(for: "Caffeine"),
                            color: color
                        )
                    },
                    onSetupTapped: {
                        showingBaseline = true
                    }
                )

                // Reusable card components
                CaffeineAmountCard(color: color, pillar: pillar)
                CaffeineTypeCard(color: color, pillar: pillar)
                CaffeineTimingCard(color: color, pillar: pillar)
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
            CaffeineEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            NutritionDataManagementView(color: color, initialCategory: .caffeine)
        }
        .sheet(isPresented: $showingBaseline) {
            CaffeineWizardView()
        }
        .task {
            await scoreViewModel.loadData()
        }
    }
}

#Preview {
    NavigationStack {
        CaffeineScreen(pillar: "Healthful Nutrition", color: .brown)
    }
}
