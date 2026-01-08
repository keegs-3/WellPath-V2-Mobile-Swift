//
//  SleepEnvironmentCard.swift
//  WellPath
//
//  Card for Sleep Environment assessment on the Sleep Environment screen.
//

import SwiftUI

struct SleepEnvironmentCard: View {
    let color: Color
    let pillar: String

    @StateObject private var viewModel = SleepEnvironmentViewModel()
    @State private var showingBaseline = false

    var body: some View {
        // MetricScoreCard handles empty state internally when hasBaselineData is false
        MetricScoreCard(
            config: .sleepEnvironment,
            color: color,
            viewModel: viewModel,
            detailViewBuilder: {
                SleepEnvironmentDetailView(viewModel: viewModel, color: color)
            },
            onSetupTapped: {
                showingBaseline = true
            }
        )
        .sheet(isPresented: $showingBaseline) {
            SleepEnvironmentWizardView()
        }
    }
}

// MARK: - Sleep Environment Detail View

struct SleepEnvironmentDetailView: View {
    @ObservedObject var viewModel: SleepEnvironmentViewModel
    let color: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Score Ring
                    ScoreRingPill(
                        score: viewModel.scoreValue,
                        iconName: "bed.double.fill",
                        label: "Environment",
                        size: 90
                    )
                    .padding(.top, 8)

                    if viewModel.hasScore {
                        Text(scoreLabel(for: viewModel.scoreValue))
                            .font(.headline)
                            .foregroundColor(scoreColor(for: viewModel.scoreValue))
                    }

                    // Baseline summary
                    baselineSummaryCard

                    // Scoring explanation
                    if let explanation = viewModel.scoringExplanation {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How Your Score Works")
                                .font(.headline)

                            Text(explanation)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Sleep Environment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await viewModel.loadData()
            }
        }
    }

    private var baselineSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Environment")
                .font(.headline)

            if let darkness = viewModel.roomDarkness {
                baselineRow(icon: "moon.fill", title: "Room Darkness", value: "\(Int(darkness))/10")
            }

            if viewModel.usesBlackoutCurtains {
                baselineRow(icon: "blinds.vertical.closed", title: "Blackout Curtains", value: "Yes")
            }

            if let temp = viewModel.roomTemperature {
                let tempStatus = temp >= 65 && temp <= 68 ? "Optimal" : (temp < 65 ? "Cool" : "Warm")
                baselineRow(icon: "thermometer.medium", title: "Temperature", value: "\(Int(temp))°F (\(tempStatus))")
            }

            if let noise = viewModel.roomNoise {
                baselineRow(icon: "speaker.slash.fill", title: "Noise Level", value: "\(Int(noise))/10")
            }

            if let mattress = viewModel.mattressQuality {
                baselineRow(icon: "bed.double.fill", title: "Mattress", value: "\(Int(mattress))/10")
            }

            if let pillow = viewModel.pillowQuality {
                baselineRow(icon: "rectangle.fill", title: "Pillow", value: "\(Int(pillow))/10")
            }

            baselineRow(icon: "tv.fill", title: "Electronics", value: viewModel.hasElectronics ? "Yes" : "No")

            if viewModel.hasSleepPartner {
                baselineRow(icon: "person.2.fill", title: "Shares Bed", value: "Yes")
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func baselineRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }

    private func scoreLabel(for score: Int) -> String {
        if score >= 80 { return "Excellent" }
        else if score >= 60 { return "Good" }
        else if score >= 40 { return "Fair" }
        else { return "Needs Work" }
    }

    private func scoreColor(for score: Int) -> Color {
        if score >= 80 { return .green }
        else if score >= 60 { return .yellow }
        else if score >= 40 { return .orange }
        else { return .red }
    }
}

#Preview {
    SleepEnvironmentCard(color: .teal, pillar: "Restorative Sleep")
}
