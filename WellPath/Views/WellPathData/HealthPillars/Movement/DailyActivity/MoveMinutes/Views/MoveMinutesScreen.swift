//
//  MoveMinutesScreen.swift
//  WellPath
//
//  Move Minutes view - single-card category so navigates directly to view
//  Card (CARD_MOVE_MINUTES) exists in DB for favorites display
//

import SwiftUI

struct MoveMinutesScreen: View {
    let pillar: String
    let color: Color
    let sectionId: String

    @StateObject private var viewModel = MoveMinutesPrimaryViewModel()
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false
    @State private var showAboutModal = false

    private let metricId = "DISP_MOVE_MINUTES"
    private let metricName = "Move Minutes"

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
        .navigationTitle("Move Minutes")
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
                    itemId: "SCREEN_MOVE_MINUTES",
                    displayName: "Move Minutes",
                    pillar: pillar,
                    cardId: "CARD_MOVE_MINUTES",
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
            MoveMinutesEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            MetricDataManagementView(config: .moveMinutes(color: color))
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
        MoveMinutesScreen(pillar: "Movement + Exercise", color: .orange, sectionId: "NAV_MOVEMENT")
    }
}
