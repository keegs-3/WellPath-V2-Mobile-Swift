//
//  SleepDurationScreen.swift
//  WellPath
//
//  Category screen for Sleep Duration.
//  Shows the score card and provides access to baseline wizard.
//

import SwiftUI

struct SleepDurationScreen: View {
    let pillar: String
    let color: Color

    @StateObject private var scoreViewModel = SleepDurationScoreViewModel()
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false
    @State private var showingBaseline = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Sleep Duration Score Card
                // MetricScoreCard handles empty state internally when hasBaselineData is false
                MetricScoreCard(
                    config: .sleepDuration,
                    color: color,
                    viewModel: scoreViewModel,
                    detailViewBuilder: {
                        SleepDurationScoreDetailView(viewModel: scoreViewModel, color: color)
                    },
                    onSetupTapped: {
                        showingBaseline = true
                    }
                )

                // Sleep Duration tracking card
                SleepDurationCard(color: color, pillar: pillar)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Sleep Duration")
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
        .task {
            await scoreViewModel.loadData()
        }
    }
}

#Preview {
    NavigationStack {
        SleepDurationScreen(pillar: "Restorative Sleep", color: .teal)
    }
}
