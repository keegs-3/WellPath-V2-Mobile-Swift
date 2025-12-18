//
//  CardioScreen.swift
//  WellPath
//
//  Card-based layout for Cardio metrics.
//  Shows cards: Duration (and Type in the future).
//  Cards are reusable components defined in Cards/ folder.
//

import SwiftUI

struct CardioScreen: View {
    let pillar: String
    let color: Color
    let sectionId: String

    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Reusable card components
                CardioDurationCard(color: color, pillar: pillar, sectionId: sectionId)
                // Future: CardioTypeCard(color: color, pillar: pillar, sectionId: sectionId)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Cardio")
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
            WorkoutEntryView(category: "cardio", categoryName: "Cardio", color: color, icon: "figure.run")
        }
        .sheet(isPresented: $showingDataManagement) {
            WorkoutDataManagementView(category: "cardio", categoryName: "Cardio", color: color)
        }
    }
}

#Preview {
    NavigationStack {
        CardioScreen(pillar: "Movement + Exercise", color: .red, sectionId: "NAV_MOVEMENT")
    }
}
