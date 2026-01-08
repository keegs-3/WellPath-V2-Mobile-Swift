//
//  SleepScoreScreen.swift
//  WellPath
//
//  Category screen for unified Sleep Score.
//  Shows the score card and provides access to baseline wizard.
//

import SwiftUI

struct SleepScoreScreen: View {
    let pillar: String
    let color: Color

    @StateObject private var scoreViewModel = SleepScoreViewModel()
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false
    @State private var showingBaseline = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Sleep Score Card
                // MetricScoreCard handles empty state internally when hasBaselineData is false
                MetricScoreCard(
                    config: .sleep,
                    color: color,
                    viewModel: scoreViewModel,
                    detailViewBuilder: {
                        SleepScoreDetailView(viewModel: scoreViewModel, color: color)
                    },
                    onSetupTapped: {
                        showingBaseline = true
                    }
                )

                // Component explanation card
                componentExplanationCard
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Sleep Score")
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
            SleepWizardView()
        }
        .task {
            await scoreViewModel.loadData()
        }
    }

    // MARK: - Component Explanation Card

    private var componentExplanationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How Your Score Works")
                .font(.headline)

            VStack(spacing: 12) {
                componentRow(
                    icon: "clock.fill",
                    title: "Duration",
                    weight: "40%",
                    description: "Total hours of sleep (7-9 hours optimal)"
                )

                componentRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Consistency",
                    weight: "30%",
                    description: "How closely you stick to regular times (±30 min optimal)"
                )

                componentRow(
                    icon: "waveform.path.ecg",
                    title: "Stage Amounts",
                    weight: "30%",
                    description: "Quality of deep, REM, and core sleep stages"
                )
            }

            if !scoreViewModel.hasTracker {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Connect a sleep tracker for full score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func componentRow(icon: String, title: String, weight: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(weight)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .cornerRadius(4)
                }
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SleepScoreScreen(pillar: "Restorative Sleep", color: .teal)
    }
}
