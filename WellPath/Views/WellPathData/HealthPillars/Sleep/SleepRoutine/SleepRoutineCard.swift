//
//  SleepRoutineCard.swift
//  WellPath
//
//  Card for Sleep Routine assessment on the Sleep Routine screen.
//

import SwiftUI

struct SleepRoutineCard: View {
    let color: Color
    let pillar: String

    @StateObject private var viewModel = SleepRoutineViewModel()
    @State private var showingBaseline = false

    var body: some View {
        // MetricScoreCard handles empty state internally when hasBaselineData is false
        MetricScoreCard(
            config: .sleepRoutine,
            color: color,
            viewModel: viewModel,
            detailViewBuilder: {
                SleepRoutineDetailView(viewModel: viewModel, color: color)
            },
            onSetupTapped: {
                showingBaseline = true
            }
        )
        .sheet(isPresented: $showingBaseline) {
            SleepRoutineWizardView()
        }
    }
}

// MARK: - Sleep Routine Detail View

struct SleepRoutineDetailView: View {
    @ObservedObject var viewModel: SleepRoutineViewModel
    let color: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Score Ring
                    ScoreRingPill(
                        score: viewModel.scoreValue,
                        iconName: "moon.stars.fill",
                        label: "Routine",
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
            .navigationTitle("Sleep Routine")
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
            Text("Your Routine")
                .font(.headline)

            if viewModel.hasWindDownRoutine {
                baselineRow(
                    icon: "moon.haze.fill",
                    title: "Wind-Down Routine",
                    value: viewModel.windDownMinutes.map { "\(Int($0)) minutes" } ?? "Yes"
                )
            } else {
                baselineRow(icon: "moon.haze.fill", title: "Wind-Down Routine", value: "No routine")
            }

            if let screenCutoff = viewModel.screenCutoffMinutes {
                baselineRow(
                    icon: "iphone.slash",
                    title: "Screen Cutoff",
                    value: "\(Int(screenCutoff)) min before bed"
                )
            }

            if let caffeineCutoff = viewModel.caffeineCutoffHours {
                baselineRow(
                    icon: "cup.and.saucer.fill",
                    title: "Caffeine Cutoff",
                    value: "\(Int(caffeineCutoff)) hours before bed"
                )
            }

            if let lastMeal = viewModel.lastMealHours {
                baselineRow(
                    icon: "fork.knife",
                    title: "Last Meal",
                    value: "\(String(format: "%.1f", lastMeal)) hours before bed"
                )
            }

            if let napsPerWeek = viewModel.napsPerWeek {
                let napDuration = viewModel.napDurationMinutes.map { " (~\(Int($0)) min)" } ?? ""
                baselineRow(
                    icon: "bed.double.fill",
                    title: "Napping",
                    value: "\(Int(napsPerWeek))x/week\(napDuration)"
                )
            }

            baselineRow(
                icon: "sparkles",
                title: "Relaxation Activities",
                value: viewModel.hasRelaxationRoutine ? "Yes" : "No"
            )
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
    SleepRoutineCard(color: .teal, pillar: "Restorative Sleep")
}
