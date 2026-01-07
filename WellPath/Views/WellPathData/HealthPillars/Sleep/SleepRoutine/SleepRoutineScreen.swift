//
//  SleepRoutineScreen.swift
//  WellPath
//
//  Category screen for Sleep Routine.
//  Shows the routine assessment card.
//

import SwiftUI

struct SleepRoutineScreen: View {
    let pillar: String
    let color: Color

    @State private var showingDataManagement = false
    @State private var showingBaseline = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Sleep Routine Card - taps to assessment detail view
                SleepRoutineCard(color: color, pillar: pillar)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Sleep Routine")
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
            SleepRoutineWizardView()
        }
    }
}

#Preview {
    NavigationStack {
        SleepRoutineScreen(pillar: "Restorative Sleep", color: .teal)
    }
}
