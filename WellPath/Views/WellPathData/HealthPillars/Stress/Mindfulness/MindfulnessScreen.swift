//
//  MindfulnessScreen.swift
//  WellPath
//
//  Main screen for Mindfulness tracking
//  Shows duration chart with recent entries
//

import SwiftUI

struct MindfulnessScreen: View {
    let pillar: String
    let color: Color
    let sectionId: String

    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private let config = ActivityCategoryConfig.mindfulness

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ActivityDurationCard(
                    config: config,
                    pillar: pillar,
                    sectionId: sectionId
                )
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Mindfulness")
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
            ActivityEntryView(config: config)
        }
        .sheet(isPresented: $showingDataManagement) {
            ActivityDataManagementView(config: config)
        }
    }
}

#Preview {
    NavigationStack {
        MindfulnessScreen(
            pillar: "Stress Management",
            color: Color(red: 0.93, green: 0.55, blue: 0.55),
            sectionId: "NAV_STRESS"
        )
    }
}
