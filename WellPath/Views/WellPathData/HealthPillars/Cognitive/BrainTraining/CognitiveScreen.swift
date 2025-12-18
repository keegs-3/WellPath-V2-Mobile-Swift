//
//  CognitiveScreen.swift
//  WellPath
//
//  Main screen for Cognitive Activities tracking
//  Shows duration chart with recent entries
//

import SwiftUI

struct CognitiveScreen: View {
    let pillar: String
    let color: Color
    let sectionId: String

    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private let config = ActivityCategoryConfig.cognitive

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
        .navigationTitle("Brain Training")
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
        CognitiveScreen(
            pillar: "Cognitive Health",
            color: Color(red: 0.78, green: 0.71, blue: 1.0),
            sectionId: "NAV_COGNITION"
        )
    }
}
