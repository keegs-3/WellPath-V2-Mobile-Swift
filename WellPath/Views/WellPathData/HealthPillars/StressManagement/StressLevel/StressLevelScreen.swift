//
//  StressLevelScreen.swift
//  WellPath
//
//  Category screen for Stress Level.
//  Shows the stress assessment card.
//

import SwiftUI

struct StressLevelScreen: View {
    let pillar: String
    let color: Color

    @State private var showingDataManagement = false
    @State private var showingBaseline = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Stress Card - taps to assessment detail view
                StressCard(color: color, pillar: pillar)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Stress Level")
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
            // TODO: StressDataManagementView when built
            Text("Data Management")
        }
        .sheet(isPresented: $showingBaseline) {
            // TODO: StressBaselineWizardView when built
            Text("Stress Baseline Wizard")
        }
    }
}

#Preview {
    NavigationStack {
        StressLevelScreen(pillar: "Stress Management", color: .purple)
    }
}
