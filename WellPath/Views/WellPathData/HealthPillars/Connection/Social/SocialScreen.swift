//
//  SocialScreen.swift
//  WellPath
//
//  Main screen for Social Interactions tracking
//  Shows duration chart with recent entries
//

import SwiftUI

struct SocialScreen: View {
    let pillar: String
    let color: Color
    let sectionId: String

    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private let config = ActivityCategoryConfig.social

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
        .navigationTitle("Social Time")
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
        SocialScreen(
            pillar: "Connection + Purpose",
            color: Color(red: 0.68, green: 0.83, blue: 0.60),
            sectionId: "NAV_CONNECTION"
        )
    }
}
