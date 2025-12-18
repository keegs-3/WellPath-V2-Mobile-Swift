//
//  CaffeineTypeView.swift
//  WellPath
//
//  Full view for Caffeine Type metric (DISP_CAFFEINE_TYPE).
//  Shows caffeine source quality breakdown with tiers.
//

import SwiftUI

struct CaffeineTypeView: View {
    let color: Color

    @State private var showAboutModal = false
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private let metricId = "DISP_CAFFEINE_TYPE"
    private let metricName = "Caffeine Type"

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Source Quality Overview Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Source Quality")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            showAboutModal = true
                        }) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(color)
                        }
                    }

                    Text("Track your caffeine sources to optimize energy and health benefits.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // Tier Overview
                    VStack(spacing: 12) {
                        tierRow(
                            name: "Quality Sources",
                            description: "Coffee, tea, matcha - natural caffeine sources",
                            color: MetricsUIConfig.tierGood,
                            target: "95%+"
                        )
                        tierRow(
                            name: "Limit Sources",
                            description: "Energy drinks, sweetened coffee drinks, pre-workout",
                            color: MetricsUIConfig.tierPoor,
                            target: "<5%"
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
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 48))
                        .foregroundColor(color.opacity(0.3))

                    Text("Track caffeine intake to see your source distribution")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button(action: {
                        showingEntryForm = true
                    }) {
                        Label("Log Caffeine", systemImage: "plus")
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
        .navigationTitle("Caffeine Types")
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
                    itemId: "DISP_CAFFEINE_TYPE",
                    displayName: "Caffeine Type",
                    pillar: "Healthful Nutrition",
                    cardId: "CARD_CAFFEINE_TYPE",
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
    private func tierRow(name: String, description: String, color: Color, target: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("Target: \(target)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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
        CaffeineTypeView(color: .brown)
    }
}
