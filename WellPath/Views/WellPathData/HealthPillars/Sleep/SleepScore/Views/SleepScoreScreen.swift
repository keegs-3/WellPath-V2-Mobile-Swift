//
//  SleepScoreScreen.swift
//  WellPath
//
//  Main view for Sleep Score metric (DISP_SLEEP_SCORE).
//  Shows composite sleep quality score with tier breakdown.
//

import SwiftUI
import Charts

struct SleepScoreScreen: View {
    let color: Color
    let pillar: String
    let sectionId: String

    @StateObject private var viewModel = SleepScoreViewModel()
    @State private var showingDataManagement = false
    @State private var showingEntryView = false
    @State private var showAboutModal = false

    private let metricId = "DISP_SLEEP_SCORE"
    private let metricName = "Sleep Score"

    init(color: Color, pillar: String = "Restorative Sleep", sectionId: String = "NAV_SLEEP") {
        self.color = color
        self.pillar = pillar
        self.sectionId = sectionId
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Main score card with donut chart
                scoreCard

                // Tier breakdown card
                tierBreakdownCard

                // About this score card
                aboutCard
            }
            .padding()
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

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                FavoriteButton(
                    itemType: .screen,
                    itemId: "SCREEN_SLEEP_SCORE",
                    displayName: "Sleep Score",
                    pillar: pillar,
                    cardId: "CARD_SLEEP_SCORE",
                    sectionId: sectionId
                )

                Button(action: {
                    showingEntryView = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEntryView) {
            SleepEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            SleepDataManagementView(color: color)
        }
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(
                viewId: metricId,
                metricName: metricName,
                color: color,
                isPresented: $showAboutModal
            )
        }
        .task {
            await viewModel.loadTierConfig()
            await viewModel.loadData()
        }
    }

    // MARK: - Score Card

    private var scoreCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Overall Score")
                    .font(.headline)
                Spacer()
                Button(action: {
                    showAboutModal = true
                }) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(color)
                }
            }

            if viewModel.isLoading {
                ProgressView()
                    .frame(height: 200)
            } else {
                HStack(spacing: 32) {
                    // Donut chart
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(Color(uiColor: .tertiarySystemGroupedBackground), lineWidth: 20)
                            .frame(width: 140, height: 140)

                        // Score segments
                        if let tierConfig = viewModel.tierConfig {
                            ForEach(Array(tierConfig.tiers.enumerated()), id: \.element.id) { index, tier in
                                let startAngle = segmentStartAngle(for: index)
                                let endAngle = segmentEndAngle(for: index)

                                Circle()
                                    .trim(from: startAngle, to: endAngle)
                                    .stroke(tier.color, style: StrokeStyle(lineWidth: 20, lineCap: .butt))
                                    .frame(width: 140, height: 140)
                                    .rotationEffect(.degrees(-90))
                            }
                        }

                        // Center score
                        VStack(spacing: 0) {
                            Text("\(Int(viewModel.totalScore.rounded()))")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(scoreColor)
                            Text("/ 100")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Legend
                    if let tierConfig = viewModel.tierConfig {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(tierConfig.tiers) { tier in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(tier.color)
                                        .frame(width: 10, height: 10)
                                    Text(tier.tierName)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(tier.targetPercentage)%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    // MARK: - Tier Breakdown Card

    private var tierBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Component Breakdown")
                .font(.headline)

            if let tierConfig = viewModel.tierConfig {
                ForEach(tierConfig.tiers) { tier in
                    tierRow(tier: tier)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private func tierRow(tier: SleepScoreTierConfig.Tier) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tier.tierName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(viewModel.getScore(for: tier.tierId).rounded()))/100")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(tier.color)
                        .frame(width: geometry.size.width * (viewModel.getScore(for: tier.tierId) / 100), height: 8)
                }
            }
            .frame(height: 8)

            Text(tier.tierDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - About Card

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How It's Calculated")
                .font(.headline)

            if let explanation = viewModel.scoringExplanation {
                Text(explanation)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Your Sleep Score is calculated from four weighted components: Consistency (30%), Duration (30%), Structure (20%), and Efficiency (20%). Each component is scored 0-100 based on your sleep data.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    // MARK: - Helpers

    private var scoreColor: Color {
        let score = viewModel.totalScore
        if score >= 85 { return MetricsUIConfig.tierGood }
        else if score >= 70 { return MetricsUIConfig.tierMedium }
        else { return MetricsUIConfig.tierPoor }
    }

    private func segmentStartAngle(for index: Int) -> CGFloat {
        guard let tierConfig = viewModel.tierConfig else { return 0 }
        var angle: CGFloat = 0
        for i in 0..<index {
            angle += CGFloat(tierConfig.tiers[i].targetPercentage) / 100
        }
        return angle
    }

    private func segmentEndAngle(for index: Int) -> CGFloat {
        guard let tierConfig = viewModel.tierConfig else { return 0 }
        var angle: CGFloat = 0
        for i in 0...index {
            angle += CGFloat(tierConfig.tiers[i].targetPercentage) / 100
        }
        return angle
    }
}

#Preview {
    NavigationStack {
        SleepScoreScreen(color: .indigo)
    }
}
