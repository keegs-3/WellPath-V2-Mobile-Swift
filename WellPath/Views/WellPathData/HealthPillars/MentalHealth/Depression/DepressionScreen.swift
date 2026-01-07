//
//  DepressionScreen.swift
//  WellPath
//
//  Category screen for Depression (PHQ-9).
//  Shows the depression assessment card.
//

import SwiftUI

struct DepressionScreen: View {
    let pillar: String
    let color: Color

    @State private var showingDataManagement = false
    @State private var showingBaseline = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Depression Card - taps to assessment detail view
                DepressionCard(color: color, pillar: pillar)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Depression")
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
            // TODO: DepressionDataManagementView when built
            Text("Data Management")
        }
        .sheet(isPresented: $showingBaseline) {
            // TODO: DepressionWizardView when built
            Text("Depression Baseline Wizard")
        }
    }
}

#Preview {
    NavigationStack {
        DepressionScreen(pillar: "Mental Health", color: .indigo)
    }
}
