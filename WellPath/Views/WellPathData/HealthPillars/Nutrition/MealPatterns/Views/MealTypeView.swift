//
//  MealTypeView.swift
//  WellPath
//
//  Full view for Meal Distribution metric (DISP_MEAL_TYPE).
//  Shows breakdown by breakfast, lunch, dinner, snacks.
//

import SwiftUI

struct MealTypeView: View {
    let color: Color

    @State private var showAboutModal = false
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private let metricId = "DISP_MEAL_TYPE"
    private let metricName = "Meal Distribution"

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Distribution Overview Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Daily Meal Balance")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            showAboutModal = true
                        }) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(color)
                        }
                    }

                    Text("Track your meal distribution for optimal energy and metabolism.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // Meal type breakdown
                    VStack(spacing: 12) {
                        mealRow(
                            name: "Breakfast",
                            description: "Start your day with a balanced meal",
                            target: "20-25%",
                            icon: "sunrise.fill",
                            color: .orange
                        )
                        mealRow(
                            name: "Lunch",
                            description: "Main meal for sustained energy",
                            target: "30-35%",
                            icon: "sun.max.fill",
                            color: .yellow
                        )
                        mealRow(
                            name: "Dinner",
                            description: "Lighter evening meal",
                            target: "25-30%",
                            icon: "sunset.fill",
                            color: .purple
                        )
                        mealRow(
                            name: "Snacks",
                            description: "Healthy snacks between meals",
                            target: "10-15%",
                            icon: "leaf.fill",
                            color: .green
                        )
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                .padding(.horizontal)

                // Coming soon message
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 48))
                        .foregroundColor(color.opacity(0.3))

                    Text("Log meals to see your distribution patterns")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

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
            .padding(.top)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Meal Distribution")
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
                    itemId: "DISP_MEAL_TYPE",
                    displayName: "Meal Distribution",
                    pillar: "Healthful Nutrition",
                    cardId: "CARD_MEAL_TYPE",
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
    }

    @ViewBuilder
    private func mealRow(name: String, description: String, target: String, icon: String, color: Color) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(target)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
    }
}

#Preview {
    NavigationStack {
        MealTypeView(color: .indigo)
    }
}
