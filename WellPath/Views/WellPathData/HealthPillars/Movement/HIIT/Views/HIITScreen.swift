//
//  HIITScreen.swift
//  WellPath
//
//  Card-based layout for HIIT metrics.
//  Shows cards: Duration (and Type in the future).
//  Cards are reusable components defined in Cards/ folder.
//

import SwiftUI

struct HIITScreen: View {
    let pillar: String
    let color: Color
    let sectionId: String

    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Reusable card components
                HIITDurationCard(color: color, pillar: pillar, sectionId: sectionId)
                // Future: HIITTypeCard(color: color, pillar: pillar, sectionId: sectionId)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("HIIT")
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
            WorkoutEntryView(category: "hiit", categoryName: "HIIT", color: color, icon: "bolt.heart.fill")
        }
        .sheet(isPresented: $showingDataManagement) {
            WorkoutDataManagementView(category: "hiit", categoryName: "HIIT", color: color)
        }
    }
}

#Preview {
    NavigationStack {
        HIITScreen(pillar: "Movement + Exercise", color: .purple, sectionId: "NAV_MOVEMENT")
    }
}
