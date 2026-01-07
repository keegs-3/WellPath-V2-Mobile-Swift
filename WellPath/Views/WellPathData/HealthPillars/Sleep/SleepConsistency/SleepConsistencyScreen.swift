//
//  SleepConsistencyScreen.swift
//  WellPath
//
//  Category screen for Sleep Consistency.
//  Shows score card at top, then the consistency card.
//

import SwiftUI

struct SleepConsistencyScreen: View {
    let pillar: String
    let color: Color

    @State private var showingEntryForm = false
    @State private var showingDataManagement = false
    @State private var showingBaseline = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Sleep Consistency Card - taps to detail view
                SleepConsistencyCard(color: color, pillar: pillar)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Sleep Consistency")
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
                HStack(spacing: 12) {
                    Button {
                        showingBaseline = true
                    } label: {
                        Image(systemName: "book.fill")
                    }

                    Button {
                        showingEntryForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEntryForm) {
            SleepEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            SleepDataManagementView(color: color)
        }
        .sheet(isPresented: $showingBaseline) {
            SleepDurationWizardView()
        }
    }
}

#Preview {
    NavigationStack {
        SleepConsistencyScreen(pillar: "Restorative Sleep", color: .teal)
    }
}
