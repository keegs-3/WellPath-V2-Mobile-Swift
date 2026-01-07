//
//  StandTimeScreen.swift
//  WellPath
//
//  Stand Time view - tracks hours with standing/movement
//  Card (CARD_STAND_TIME) exists in DB for favorites display
//

import SwiftUI

struct StandTimeScreen: View {
    let pillar: String
    let color: Color
    let sectionId: String

    @StateObject private var viewModel = StandTimePrimaryViewModel()
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false
    @State private var showAboutModal = false

    private let metricId = "DISP_STAND_TIME"
    private let metricName = "Stand Time"

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
        .navigationTitle("Stand Time")
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
                    itemId: "SCREEN_STAND_TIME",
                    displayName: "Stand Time",
                    pillar: pillar,
                    cardId: "CARD_STAND_TIME",
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
            StandTimeEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            MetricDataManagementView(config: .standTime(color: color))
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
        StandTimeScreen(pillar: "Movement + Exercise", color: .orange, sectionId: "NAV_MOVEMENT")
    }
}
