//
//  SleepEnvironmentScreen.swift
//  WellPath
//
//  Category screen for Sleep Environment.
//  Shows the environment assessment card.
//

import SwiftUI

struct SleepEnvironmentScreen: View {
    let pillar: String
    let color: Color

    @State private var showingDataManagement = false
    @State private var showingBaseline = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Sleep Environment Card - taps to assessment detail view
                SleepEnvironmentCard(color: color, pillar: pillar)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Sleep Environment")
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
            SleepDataManagementView(color: color)
        }
        .sheet(isPresented: $showingBaseline) {
            SleepEnvironmentWizardView()
        }
    }
}

#Preview {
    NavigationStack {
        SleepEnvironmentScreen(pillar: "Restorative Sleep", color: .teal)
    }
}
