//
//  ComponentDetailView.swift
//  WellPath
//
//  Level 3: Individual metrics within a component
//

import SwiftUI

struct ComponentDetailView: View {
    let pillarName: String
    let componentType: ComponentMetric.ComponentType
    let componentScore: Double
    let componentWeight: Double

    @StateObject private var viewModel = ComponentDetailViewModel()

    // Grid layout - 3 columns for better metric visibility
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    private var pillarConfig: PillarUIConfig {
        PillarUIConfig.config(for: pillarName)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Component Score Summary
                componentSummarySection

                // Individual Metric Rings Grid
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if let error = viewModel.error {
                    errorView(error)
                } else if viewModel.metrics.isEmpty {
                    emptyStateView
                } else {
                    metricsGridSection
                }
            }
            .padding()
        }
        .navigationTitle(componentType.displayName)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadComponentMetrics(pillar: pillarName, componentType: componentType)
        }
    }

    // MARK: - Component Summary Section

    private var componentSummarySection: some View {
        VStack(spacing: 16) {
            // Component score ring
            ScoreRingView(
                score: componentScore,
                maxScore: 100,
                size: 160,
                lineWidth: 16,
                color: pillarConfig.color
            ) {
                AnyView(
                    VStack(spacing: 4) {
                        Text("\(Int(componentScore.rounded()))")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.primary)
                        Text("points")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                )
            }

            // Weight badge
            ComponentWeightBadge(
                weight: componentWeight,
                pointsEarned: Int(componentScore.rounded()),
                maxPoints: 100,
                displayStyle: .both
            )

            // Description
            Text("These \(componentType.displayName.lowercased()) contribute \(Int((componentWeight * 100).rounded()))% to your \(pillarName) score.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }

    // MARK: - Metrics Grid Section

    private var metricsGridSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Individual Metrics")
                .font(.system(size: 20, weight: .semibold))
                .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(viewModel.metrics) { metric in
                    metricRingCard(metric)
                }
            }
        }
    }

    private func metricRingCard(_ metric: ComponentMetric) -> some View {
        // Calculate color intensity based on performance
        let performance = metric.maxPoints > 0 ? metric.pointsEarned / metric.maxPoints : 0
        let colorIntensity = 0.5 + (performance * 0.5) // Range from 0.5 to 1.0

        return Button(action: {
            // TODO: Navigate to MetricDetailView
            print("Tapped \(metric.metricName)")
        }) {
            VStack(spacing: 8) {
                ScoreRingView(
                    score: metric.pointsEarned,
                    maxScore: metric.maxPoints,
                    size: 100,
                    lineWidth: 10,
                    color: pillarConfig.color.opacity(colorIntensity)
                ) {
                    AnyView(
                        VStack(spacing: 2) {
                            Text("\(metric.pointsEarnedInt)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)
                            Text("of \(metric.maxPointsInt)")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                    )
                }

                // Metric name
                Text(metric.metricName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 32)

                // Weight percentage
                Text("\(metric.weightPercentage)% weight")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Metrics Available")
                .font(.headline)

            Text("Metrics for this component will appear here once your scoring data is available.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Unable to Load Metrics")
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Retry") {
                Task {
                    await viewModel.loadComponentMetrics(pillar: pillarName, componentType: componentType)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

#Preview {
    NavigationStack {
        ComponentDetailView(
            pillarName: "Healthful Nutrition",
            componentType: .biomarkers,
            componentScore: 38,
            componentWeight: 0.72
        )
    }
}
