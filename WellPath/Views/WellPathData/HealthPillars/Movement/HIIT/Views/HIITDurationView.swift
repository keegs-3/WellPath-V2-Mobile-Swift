//
//  HIITDurationView.swift
//  WellPath
//
//  Full view for HIIT Duration metric.
//  Uses standard MetricEducationModal for about content.
//

import SwiftUI
import Charts

struct HIITDurationView: View {
    let color: Color
    let pillar: String
    let sectionId: String

    @StateObject private var viewModel = WorkoutDurationViewModel(category: "hiit")
    @State private var showAboutModal = false
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private let metricId = "DISP_HIIT_DURATION"
    private let metricName = "HIIT Duration"

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
                    cardId: "CARD_HIIT_DURATION",
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
            WorkoutEntryView(category: "hiit", categoryName: "HIIT", color: color, icon: "bolt.heart.fill")
        }
        .sheet(isPresented: $showingDataManagement) {
            WorkoutDataManagementView(category: "hiit", categoryName: "HIIT", color: color)
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
        HIITDurationView(color: .purple, pillar: "Movement + Exercise", sectionId: "NAV_MOVEMENT")
    }
}
