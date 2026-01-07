//
//  ActiveCaloriesScreen.swift
//  WellPath
//
//  Active Calories view - tracks calories burned through activity
//  Card (CARD_ACTIVE_CALORIES) exists in DB for favorites display
//

import SwiftUI

struct ActiveCaloriesScreen: View {
    let pillar: String
    let color: Color
    let sectionId: String

    @StateObject private var viewModel = ActiveCaloriesPrimaryViewModel()
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false
    @State private var showAboutModal = false

    private let metricId = "DISP_ACTIVE_CALORIES"
    private let metricName = "Active Calories"

    var body: some View {
        VStack(spacing: 0) {
            if let metric = viewModel.metrics.first {
                ParentMetricBarChart(metric: metric.metric, color: color, showAbout: $showAboutModal)
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
            } else {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            }
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Active Calories")
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
                    itemType: .screen,
                    itemId: "SCREEN_ACTIVE_CALORIES",
                    displayName: "Active Calories",
                    pillar: pillar,
                    cardId: "CARD_ACTIVE_CALORIES",
                    sectionId: sectionId
                )

                Button {
                    showingEntryForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEntryForm) {
            ActiveCaloriesEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            MetricDataManagementView(config: .activeCalories(color: color))
        }
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(
                viewId: metricId,
                metricName: metricName,
                color: color,
                isPresented: $showAboutModal
            )
        }
        .task {
            await viewModel.loadPrimaryScreen()
        }
    }
}

#Preview {
    NavigationStack {
        ActiveCaloriesScreen(pillar: "Movement + Exercise", color: .orange, sectionId: "NAV_MOVEMENT")
    }
}
