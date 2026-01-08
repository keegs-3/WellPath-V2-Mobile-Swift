//
//  SuggestedTherapeuticsCard.swift
//  WellPath
//
//  Card showing count of suggested therapeutics based on patient scores.
//  Uses the same pattern as score cards but displays a count instead of a score.
//  Taps into SuggestedTherapeuticsList with rationale and quick add.
//

import SwiftUI

struct SuggestedTherapeuticsCard: View {
    let color: Color
    @StateObject private var viewModel = SuggestedTherapeuticsViewModel()
    @State private var showingList = false

    var body: some View {
        Button {
            showingList = true
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingList) {
            SuggestedTherapeuticsList(
                viewModel: viewModel,
                color: color
            )
        }
        .task {
            await viewModel.loadSuggestions()
        }
    }

    // MARK: - Card Content

    private var cardContent: some View {
        HStack(spacing: 16) {
            // Count circle (similar to score ring but shows count)
            countCircle

            // Context info
            VStack(alignment: .leading, spacing: 6) {
                Text("Suggested For You")
                    .font(.headline)
                    .foregroundColor(.primary)

                if viewModel.isLoading {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if viewModel.hasSuggestions {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(color)
                            .frame(width: 8, height: 8)
                        Text(suggestionSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("No suggestions at this time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if viewModel.hasSuggestions {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Count Circle

    private var countCircle: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(
                    viewModel.hasSuggestions ? color.opacity(0.3) : Color.gray.opacity(0.2),
                    lineWidth: 6
                )
                .frame(width: 70, height: 70)

            // Filled arc based on relevance
            if viewModel.hasSuggestions {
                Circle()
                    .trim(from: 0, to: relevanceProgress)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 70, height: 70)
            }

            // Center content
            VStack(spacing: 2) {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("\(viewModel.suggestionCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(viewModel.hasSuggestions ? color : .gray)

                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundColor(viewModel.hasSuggestions ? color : .gray)
                }
            }
        }
    }

    // MARK: - Computed Properties

    /// Progress for the arc (based on average relevance)
    private var relevanceProgress: CGFloat {
        guard viewModel.hasSuggestions else { return 0 }
        let avgRelevance = viewModel.suggestions.compactMap { $0.relevance }.reduce(0, +)
            / max(viewModel.suggestionCount, 1)
        return CGFloat(avgRelevance) / 5.0  // Relevance is 1-5 scale
    }

    /// Summary text for suggestions
    private var suggestionSummary: String {
        let count = viewModel.suggestionCount
        if count == 1 {
            return "1 therapeutic suggestion"
        }
        return "\(count) based on your scores"
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        SuggestedTherapeuticsCard(
            color: Color(hex: "F4D284") ?? .yellow
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
