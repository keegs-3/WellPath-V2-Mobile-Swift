//
//  PlantBasedMealsView.swift
//  WellPath
//
//  Full view for Plant-Based Meals metric (DISP_PLANT_BASED_MEALS).
//  Shows percentage of meals that are plant-based.
//

import SwiftUI

struct PlantBasedMealsView: View {
    let color: Color

    @StateObject private var viewModel = StandardMetricViewModel(metricId: "DISP_PLANT_BASED_MEALS")
    @State private var showAboutModal = false
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private let metricId = "DISP_PLANT_BASED_MEALS"
    private let metricName = "Plant-Based Meals"

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Overview Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Plant-Based Score")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            showAboutModal = true
                        }) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(color)
                        }
                    }

                    if let todayValue = viewModel.todayValue {
                        HStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Today")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text(String(format: "%.0f", todayValue))
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(color)
                                    Text("%")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Target")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("50%+")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Progress bar
                        let progress = min(todayValue / 100.0, 1.0)
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 8)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(todayValue >= 50 ? MetricsUIConfig.tierGood : (todayValue >= 30 ? MetricsUIConfig.tierMedium : MetricsUIConfig.tierPoor))
                                    .frame(width: geometry.size.width * progress, height: 8)
                            }
                        }
                        .frame(height: 8)
                    } else {
                        Text("Track your meals to see your plant-based percentage")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                .padding(.horizontal)

                // Benefits card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Benefits of Plant-Based Eating")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        benefitRow(icon: "heart.fill", text: "Reduced heart disease risk")
                        benefitRow(icon: "figure.walk", text: "Better weight management")
                        benefitRow(icon: "leaf.arrow.circlepath", text: "Lower environmental impact")
                        benefitRow(icon: "bolt.fill", text: "Improved energy levels")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                .padding(.horizontal)

                // CTA
                if viewModel.todayValue == nil {
                    VStack(spacing: 12) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 48))
                            .foregroundColor(color.opacity(0.3))

                        Button(action: {
                            showingEntryForm = true
                        }) {
                            Label("Log Meal", systemImage: "plus")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(color)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.vertical, 40)
                }
            }
            .padding(.top)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Plant-Based Meals")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingDataManagement = true
                } label: {
                    Image(systemName: "list.bullet")
                }
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                FavoriteButton(
                    itemType: .metric,
                    itemId: "DISP_PLANT_BASED_MEALS",
                    displayName: "Plant-Based Meals",
                    pillar: "Healthful Nutrition",
                    cardId: "CARD_PLANT_BASED_MEALS",
                    sectionId: "NAV_NUTRITION"
                )

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
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(viewId: metricId, metricName: metricName, color: color, isPresented: $showAboutModal)
        }
        .task {
            await viewModel.loadPrimaryScreen()
        }
    }

    @ViewBuilder
    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        PlantBasedMealsView(color: .indigo)
    }
}
