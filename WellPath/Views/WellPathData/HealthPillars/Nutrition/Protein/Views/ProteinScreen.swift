//
//  ProteinScreen.swift
//  WellPath
//
//  Card-based layout for Protein metric.
//  Shows score card at top, then 3 cards: Amount, Type, Ratio.
//  Cards are reusable components defined in Cards/ folder.
//

import SwiftUI

struct ProteinScreen: View {
    let pillar: String
    let color: Color

    @StateObject private var scoreViewModel = ProteinScoreViewModel()
    @StateObject private var detailViewModel = GenericScoreDetailViewModel(scoreType: "protein_score")
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false
    @State private var showingBaseline = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Protein Score Card - always shown, handles empty state internally
                MetricScoreCard(
                    config: .protein,
                    color: color,
                    viewModel: scoreViewModel,
                    detailViewBuilder: {
                        GenericScoreDetailView(
                            viewModel: detailViewModel,
                            title: "Protein Score",
                            iconName: "fork.knife",
                            color: color
                        )
                    },
                    onSetupTapped: {
                        showingBaseline = true
                    }
                )

                // Reusable card components
                ProteinAmountCard(color: color, pillar: pillar)
                ProteinTypeCard(color: color, pillar: pillar)
                ProteinRatioCard(color: color, pillar: pillar)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Protein")
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
            NutritionDataManagementView(color: color, initialCategory: .protein)
        }
        .sheet(isPresented: $showingBaseline) {
            ProteinWizardView()
        }
        .task {
            await scoreViewModel.loadData()
        }
    }
}

#Preview {
    NavigationStack {
        ProteinScreen(pillar: "Healthful Nutrition", color: .green)
    }
}
