//
//  MobilityScreen.swift
//  WellPath
//
//  Card-based layout for Mobility metrics.
//  Shows cards: Duration (and Type in the future).
//  Cards are reusable components defined in Cards/ folder.
//

import SwiftUI

struct MobilityScreen: View {
    let pillar: String
    let color: Color
    let sectionId: String

    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Reusable card components
                MobilityDurationCard(color: color, pillar: pillar, sectionId: sectionId)
                // Future: MobilityTypeCard(color: color, pillar: pillar, sectionId: sectionId)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Mobility")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingDataManagement = true
                } label: {
                    Image(systemName: "list.bullet")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
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
    }
}

#Preview {
    NavigationStack {
        MobilityScreen(pillar: "Movement + Exercise", color: .green, sectionId: "NAV_MOVEMENT")
    }
}
