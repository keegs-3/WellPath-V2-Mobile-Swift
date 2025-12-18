//
//  StrengthDurationView.swift
//  WellPath
//
//  Full view for Strength Duration metric.
//  Uses standard MetricEducationModal for about content.
//

import SwiftUI
import Charts

struct StrengthDurationView: View {
    let color: Color
    let pillar: String
    let sectionId: String

    @StateObject private var viewModel = WorkoutDurationViewModel(category: "strength")
    @State private var showAboutModal = false
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private let metricId = "DISP_STRENGTH_DURATION"
    private let metricName = "Strength Duration"

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
                    cardId: "CARD_STRENGTH_DURATION",
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
            WorkoutEntryView(category: "strength", categoryName: "Strength", color: color, icon: "dumbbell.fill")
        }
        .sheet(isPresented: $showingDataManagement) {
            WorkoutDataManagementView(category: "strength", categoryName: "Strength", color: color)
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
        StrengthDurationView(color: .orange, pillar: "Movement + Exercise", sectionId: "NAV_MOVEMENT")
    }
}
