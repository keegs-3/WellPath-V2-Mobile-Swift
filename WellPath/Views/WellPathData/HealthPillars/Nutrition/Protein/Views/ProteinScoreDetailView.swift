//
//  ProteinScoreDetailView.swift
//  WellPath
//
//  Detail view showing protein score breakdown, components, and threshold progress.
//  Content driven by display_behavioral_scores and display_behavioral_score_components.
//

import SwiftUI

struct ProteinScoreDetailView: View {
    @ObservedObject var viewModel: ProteinScoreViewModel
    let color: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Main Score Ring
                    scoreRingSection

                    // Source indicator
                    scoreSourceBadge

                    // Threshold Progress (if baseline)
                    if viewModel.isBaseline {
                        thresholdSection
                    }

                    // Component Breakdown
                    componentBreakdownSection

                    // How It's Calculated
                    if let explanation = viewModel.scoringExplanation {
                        scoringExplanationSection(explanation)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(viewModel.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Score Ring Section

    private var scoreRingSection: some View {
        VStack(spacing: 12) {
            ScoreRingView(
                score: Double(viewModel.scoreValue),
                maxScore: 100,
                size: 160,
                lineWidth: 16,
                color: scoreColor
            ) {
                AnyView(
                    VStack(spacing: 2) {
                        Text("\(viewModel.scoreValue)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.primary)
                        Text("of 100")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                )
            }

            Text(scoreLabel)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(scoreColor)
        }
        .padding(.vertical)
    }

    // MARK: - Score Source Badge

    private var scoreSourceBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: viewModel.isTracked ? "chart.line.uptrend.xyaxis.circle.fill" : "doc.text.fill")
                .font(.body)
                .foregroundColor(color)

            Text(viewModel.isTracked ? "Based on tracked data" : "Based on baseline estimate")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
    }

    // MARK: - Threshold Section

    private var thresholdSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Unlock Tracked Score")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: geometry.size.width * min(viewModel.thresholdProgress, 1.0), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(viewModel.daysTracked) of \(viewModel.daysRequired) days")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text("\(Int(viewModel.thresholdProgress * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let explanation = viewModel.thresholdExplanation {
                    Text(explanation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Component Breakdown Section

    private var componentBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Score Breakdown")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.components.enumerated()), id: \.element.id) { index, component in
                    componentRow(component)

                    if index < viewModel.components.count - 1 {
                        Divider()
                            .padding(.horizontal)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    private func componentRow(_ component: BehavioralScoreComponent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: component.iconName ?? "circle.fill")
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(component.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    if let score = viewModel.componentScoreValue(for: component) {
                        Text("\(score)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(componentScoreColor(score))
                    } else {
                        Text("--")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    if let description = component.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(component.weightPercentage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }

    // MARK: - Scoring Explanation Section

    private func scoringExplanationSection(_ explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How It's Calculated")
                .font(.headline)

            Text(explanation)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
        }
    }

    // MARK: - Helpers

    private var scoreColor: Color {
        let score = viewModel.scoreValue
        if score >= 80 { return .green }
        else if score >= 60 { return .yellow }
        else if score >= 40 { return .orange }
        else { return .red }
    }

    private var scoreLabel: String {
        let score = viewModel.scoreValue
        if score >= 80 { return "Excellent" }
        else if score >= 60 { return "Good" }
        else if score >= 40 { return "Fair" }
        else { return "Needs Improvement" }
    }

    private func componentScoreColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        else if score >= 60 { return .yellow }
        else if score >= 40 { return .orange }
        else { return .red }
    }
}

#Preview {
    ProteinScoreDetailView(
        viewModel: ProteinScoreViewModel(),
        color: .green
    )
}
