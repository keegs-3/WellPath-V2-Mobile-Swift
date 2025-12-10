//
//  ProteinTimingView.swift
//  WellPath
//
//  Full view for Protein Timing metric (DISP_PROTEIN_TIMING).
//  Shows protein distribution across meals with timeline chart.
//

import SwiftUI

struct ProteinTimingView: View {
    let color: Color
    @State private var showAboutModal = false
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private let metricId = "DISP_PROTEIN_TIMING"
    private let metricName = "Protein Timing"

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Protein Intake")
    }

    var body: some View {
        ProteinTimingTimelineView(color: color, showAbout: $showAboutModal)
        .metricScreenBackground(color: color)
        .navigationTitle("Protein Timing")
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
                    itemId: "DISP_PROTEIN_TIMING",
                    displayName: "Protein Timing",
                    pillar: "Healthful Nutrition",
                    cardId: "CARD_PROTEIN_TIMING",
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
            ProteinEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            ProteinDataManagementView(color: color)
        }
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(viewId: metricId, metricName: metricName, color: color, isPresented: $showAboutModal)
        }
    }
}

#Preview {
    NavigationStack {
        ProteinTimingView(color: .green)
    }
}
