//
//  WellbeingScreen.swift
//  WellPath
//
//  Category screen for Wellbeing (WHO-5).
//  Shows the wellbeing assessment card.
//

import SwiftUI

struct WellbeingScreen: View {
    let pillar: String
    let color: Color

    @State private var showingDataManagement = false
    @State private var showingBaseline = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Wellbeing Card - taps to assessment detail view
                WellBeingCard(color: color, pillar: pillar)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Wellbeing")
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
                    showingBaseline = true
                } label: {
                    Image(systemName: "book.fill")
                }
            }
        }
        .sheet(isPresented: $showingDataManagement) {
            // TODO: WellbeingDataManagementView when built
            Text("Data Management")
        }
        .sheet(isPresented: $showingBaseline) {
            // TODO: WellbeingWizardView when built
            Text("Wellbeing Baseline Wizard")
        }
    }
}

#Preview {
    NavigationStack {
        WellbeingScreen(pillar: "Mental Health", color: .indigo)
    }
}
