//
//  ProteinScoreCard.swift
//  WellPath
//
//  Card displaying protein score with ring visualization and threshold progress
//

import SwiftUI

struct ProteinScoreCard: View {
    let color: Color
    @ObservedObject var viewModel: ProteinScoreViewModel

    @State private var showingDetail = false

    var body: some View {
        Button {
            showingDetail = true
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            ProteinScoreDetailView(viewModel: viewModel, color: color)
        }
    }

    private var cardContent: some View {
        HStack(spacing: 16) {
            // Score Ring
            ScoreRingView(
                score: Double(viewModel.scoreValue),
                maxScore: 100,
                size: 80,
                lineWidth: 8,
                color: scoreColor
            ) {
                AnyView(
                    VStack(spacing: 0) {
                        Text("\(viewModel.scoreValue)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                    }
                )
            }

            // Score Info
            VStack(alignment: .leading, spacing: 6) {
                Text("Protein Score")
                    .font(.headline)
                    .foregroundColor(.primary)

                // Source indicator
                HStack(spacing: 4) {
                    Image(systemName: viewModel.isTracked ? "chart.line.uptrend.xyaxis" : "doc.text")
                        .font(.caption)
                    Text(viewModel.score?.sourceDisplayText ?? "No score yet")
                        .font(.caption)
                }
                .foregroundColor(.secondary)

                // Threshold progress (only show if baseline)
                if viewModel.isBaseline, let score = viewModel.score {
                    thresholdProgressView(score: score)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func thresholdProgressView(score: BehavioralScore) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geometry.size.width * min(viewModel.thresholdProgress, 1.0), height: 4)
                }
            }
            .frame(height: 4)

            // Progress text
            Text("\(score.daysTracked)/\(score.daysRequired) days tracked")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: 120)
    }

    private var scoreColor: Color {
        let score = viewModel.scoreValue
        if score >= 80 {
            return .green
        } else if score >= 60 {
            return .yellow
        } else if score >= 40 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Empty State Card

struct ProteinScoreEmptyCard: View {
    let color: Color
    let onSetupTapped: () -> Void

    var body: some View {
        Button(action: onSetupTapped) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 80, height: 80)

                    Image(systemName: "plus")
                        .font(.title)
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Set Up Protein Score")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Complete the baseline wizard to get your protein score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        ProteinScoreCard(
            color: .green,
            viewModel: ProteinScoreViewModel()
        )

        ProteinScoreEmptyCard(color: .green) {
            print("Setup tapped")
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
