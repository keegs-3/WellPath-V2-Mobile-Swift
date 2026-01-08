//
//  UltraProcessedScreen.swift
//  WellPath
//
//  Card-based layout for Ultra-Processed Foods metric.
//  Shows score card at top, then Servings tracking card.
//

import SwiftUI

struct UltraProcessedScreen: View {
    let pillar: String
    let color: Color

    @StateObject private var scoreViewModel = UltraProcessedScoreViewModel()
    @StateObject private var detailViewModel = GenericScoreDetailViewModel(scoreType: "ultra_processed_score")
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false
    @State private var showingBaseline = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Ultra-Processed Score Card
                // MetricScoreCard handles empty state internally when hasBaselineData is false
                MetricScoreCard(
                    config: .ultraProcessed,
                    color: color,
                    viewModel: scoreViewModel,
                    detailViewBuilder: {
                        GenericScoreDetailView(
                            viewModel: detailViewModel,
                            title: "Ultra-Processed Score",
                            iconName: MetricsUIConfig.getIcon(for: "Ultra-Processed"),
                            color: color
                        )
                    },
                    onSetupTapped: {
                        showingBaseline = true
                    }
                )

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
                baselineViewId: "BASELINE_VIEW_ULTRA_PROCESSED",
                categoryId: "CAT_ULTRA_PROCESSED",
                categoryName: "Ultra-Processed Foods",
                scoreId: "SCORE_ULTRA_PROCESSED",
                scoreType: "ultra_processed_score"
            )
        }
        .task {
            await scoreViewModel.loadData()
        }
    }
}

#Preview {
    NavigationStack {
        UltraProcessedScreen(pillar: "Healthful Nutrition", color: .red)
    }
}
