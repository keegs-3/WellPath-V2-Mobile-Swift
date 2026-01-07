//
//  StepsDetailView.swift
//  WellPath
//
//  Detail view showing the Steps chart.
//  Navigated to from StepsCard.
//

import SwiftUI

struct StepsDetailView: View {
    let pillar: String
    let color: Color
    let sectionId: String

    @StateObject private var viewModel = StandardMetricViewModel(metricId: "DISP_STEPS")
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false
    @State private var showAboutModal = false

    private let metricId = "DISP_STEPS"
    private let metricName = "Steps"

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let metric = viewModel.displayMetric {
                    ParentMetricBarChart(metric: metric, color: color, showAbout: $showAboutModal)
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
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Steps")
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
                    itemId: "SCREEN_STEPS_DETAIL",
                    displayName: "Steps Chart",
                    pillar: pillar,
                    cardId: "CARD_STEPS",
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
            StepsEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            MetricDataManagementView(config: .steps(color: color))
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
        StepsDetailView(pillar: "Movement + Exercise", color: .orange, sectionId: "NAV_MOVEMENT")
    }
}
