//
//  ProteinScoreCard.swift
//  WellPath
//
//  Card displaying protein score with Oura-style ring pill
//  Taps through to score detail with calculation breakdown
//

import SwiftUI

struct ProteinScoreCard: View {
    let color: Color
    @ObservedObject var viewModel: ProteinScoreViewModel

    @State private var showingDetail = false

    private var displayScore: Int? {
        if viewModel.hasDailyScore {
            return viewModel.dailyScoreValue
        } else if viewModel.hasScore {
            return viewModel.scoreValue
        }
        return nil
    }

    var body: some View {
        Button {
            showingDetail = true
        } label: {
            HStack(spacing: 16) {
                // Oura-style score ring pill
                ScoreRingPill(
                    score: displayScore,
                    iconName: "fish.fill",
                    label: "Protein",
                    size: 70
                )

                // Context info
                VStack(alignment: .leading, spacing: 6) {
                    Text("Protein Score")
                        .font(.headline)
                        .foregroundColor(.primary)

                    if viewModel.hasDailyScore {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(scoreColor)
                                .frame(width: 8, height: 8)
                            Text("Today")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("·")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(scoreStatus)
                                .font(.caption)
                                .foregroundColor(scoreColor)
                        }
                    } else if viewModel.hasScore {
                        HStack(spacing: 4) {
                            Image(systemName: "book.fill")
                                .font(.caption)
                            Text("Baseline")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption)
                            Text("No data today")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
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
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            ProteinScoreDetailView(viewModel: viewModel, color: color)
        }
    }

    private var scoreStatus: String {
        guard let score = displayScore else { return "" }
        if score >= 80 { return "Excellent" }
        else if score >= 60 { return "Good" }
        else if score >= 40 { return "Fair" }
        else { return "Needs work" }
    }

    private var scoreColor: Color {
        guard let score = displayScore else { return .secondary }
        if score >= 80 { return .green }
        else if score >= 60 { return .yellow }
        else if score >= 40 { return .orange }
        else { return .red }
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
