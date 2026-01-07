//
//  AnxietyScreen.swift
//  WellPath
//
//  Category screen for Anxiety (GAD-7).
//  Shows the anxiety assessment card.
//

import SwiftUI

struct AnxietyScreen: View {
    let pillar: String
    let color: Color

    @State private var showingDataManagement = false
    @State private var showingBaseline = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Anxiety Card - taps to assessment detail view
                AnxietyCard(color: color, pillar: pillar)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Anxiety")
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
            // TODO: AnxietyDataManagementView when built
            Text("Data Management")
        }
        .sheet(isPresented: $showingBaseline) {
            // TODO: AnxietyWizardView when built
            Text("Anxiety Baseline Wizard")
        }
    }
}

#Preview {
    NavigationStack {
        AnxietyScreen(pillar: "Mental Health", color: .indigo)
    }
}
