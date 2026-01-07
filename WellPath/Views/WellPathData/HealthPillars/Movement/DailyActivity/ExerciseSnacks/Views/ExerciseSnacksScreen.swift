//
//  ExerciseSnacksScreen.swift
//  WellPath
//
//  Exercise Snacks view - tracks brief bursts of activity
//  Card (CARD_EXERCISE_SNACKS) exists in DB for favorites display
//

import SwiftUI

struct ExerciseSnacksScreen: View {
    let pillar: String
    let color: Color
    let sectionId: String

    @StateObject private var viewModel = ExerciseSnacksPrimaryViewModel()
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false
    @State private var showAboutModal = false

    private let metricId = "DISP_EXERCISE_SNACKS"
    private let metricName = "Exercise Snacks"

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
        .navigationTitle("Exercise Snacks")
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
                    itemId: "SCREEN_EXERCISE_SNACKS",
                    displayName: "Exercise Snacks",
                    pillar: pillar,
                    cardId: "CARD_EXERCISE_SNACKS",
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
            ExerciseSnacksEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            MetricDataManagementView(config: .exerciseSnacks(color: color))
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
        ExerciseSnacksScreen(pillar: "Movement + Exercise", color: .orange, sectionId: "NAV_MOVEMENT")
    }
}
