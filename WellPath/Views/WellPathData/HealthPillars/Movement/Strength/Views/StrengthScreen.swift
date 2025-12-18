//
//  StrengthScreen.swift
//  WellPath
//
//  Card-based layout for Strength metrics.
//  Shows cards: Duration (and Type in the future).
//  Cards are reusable components defined in Cards/ folder.
//

import SwiftUI

struct StrengthScreen: View {
    let pillar: String
    let color: Color
    let sectionId: String

    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Reusable card components
                StrengthDurationCard(color: color, pillar: pillar, sectionId: sectionId)
                // Future: StrengthTypeCard(color: color, pillar: pillar, sectionId: sectionId)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Strength")
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
            WorkoutEntryView(category: "strength", categoryName: "Strength", color: color, icon: "dumbbell.fill")
        }
        .sheet(isPresented: $showingDataManagement) {
            WorkoutDataManagementView(category: "strength", categoryName: "Strength", color: color)
        }
    }
}

#Preview {
    NavigationStack {
        StrengthScreen(pillar: "Movement + Exercise", color: .orange, sectionId: "NAV_MOVEMENT")
    }
}
