//
//  MobilityDurationView.swift
//  WellPath
//
//  Full view for Mobility Duration metric.
//  Uses standard MetricEducationModal for about content.
//

import SwiftUI
import Charts

struct MobilityDurationView: View {
    let color: Color
    let pillar: String
    let sectionId: String

    @StateObject private var viewModel = WorkoutDurationViewModel(category: "mobility")
    @State private var showAboutModal = false
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private let metricId = "DISP_MOBILITY_DURATION"
    private let metricName = "Mobility Duration"

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                WorkoutDurationChart(
                    viewModel: viewModel,
                    color: color,
                    showAboutModal: $showAboutModal
                )
            }
        }
        .metricScreenBackground(color: color)
        .navigationTitle(metricName)
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
                    itemId: metricId,
                    displayName: metricName,
                    pillar: pillar,
                    cardId: "CARD_MOBILITY_DURATION",
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
            WorkoutEntryView(category: "mobility", categoryName: "Mobility", color: color, icon: "figure.flexibility")
        }
        .sheet(isPresented: $showingDataManagement) {
            WorkoutDataManagementView(category: "mobility", categoryName: "Mobility", color: color)
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
            await viewModel.loadData(period: .week)
        }
    }
}

#Preview {
    NavigationStack {
        MobilityDurationView(color: .green, pillar: "Movement + Exercise", sectionId: "NAV_MOVEMENT")
    }
}
