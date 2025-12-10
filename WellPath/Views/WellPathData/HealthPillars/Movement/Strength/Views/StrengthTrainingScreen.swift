//
//  StrengthTrainingScreen.swift
//  WellPath
//
//  Simple metric - shows chart directly (no cards needed)
//

import SwiftUI

struct StrengthTrainingScreen: View {
    let pillar: String
    let color: Color

    @StateObject private var viewModel = StrengthTrainingPrimaryViewModel()
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false
    @State private var showAboutModal = false

    private let metricId = "DISP_STRENGTH_TRAINING"
    private let metricName = "Strength Training"

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "StrengthTraining")
    }

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
        .navigationTitle("Strength Training")
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
                    itemId: "SCREEN_STRENGTH_TRAINING",
                    displayName: "Strength Training",
                    pillar: pillar,
                    cardId: nil,
                    sectionId: "NAV_MOVEMENT"
                )

                Button {
                    showingEntryForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEntryForm) {
            StrengthTrainingEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            MetricDataManagementView(config: .strengthTraining(color: color))
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
        StrengthTrainingScreen(pillar: "Movement + Exercise", color: .orange)
    }
}
