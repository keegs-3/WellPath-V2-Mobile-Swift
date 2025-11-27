//
//  ProteinTypeScoreView.swift
//  WellPath
//
//  Displays Type Score (0-100) with expandable explanation
//

import SwiftUI

struct ProteinTypeScoreView: View {
    let score: Double
    let scoringExplanation: String
    let color: Color

    @State private var isExpanded = false

    private var scoreColor: Color {
        switch score {
        case 75...:
            return .green
        case 50..<75:
            return .yellow
        case 25..<50:
            return .orange
        default:
            return .red
        }
    }

    private var scoreGrade: String {
        switch score {
        case 90...:
            return "Excellent"
        case 75..<90:
            return "Good"
        case 60..<75:
            return "Fair"
        case 40..<60:
            return "Needs Improvement"
        default:
            return "Poor"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Score header (always visible)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 16) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 24))
                        .foregroundColor(color)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Type Score")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(scoreGrade)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text("\(Int(score.rounded()))")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(scoreColor)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
            }
            .cornerRadius(isExpanded ? 12 : 12, corners: isExpanded ? [.topLeft, .topRight] : .allCorners)

            // Explanation (expandable)
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Text(scoringExplanation)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
            }
        }
    }
}

#Preview {
    ProteinTypeScoreView(
        score: 85.5,
        scoringExplanation: "Your Protein Type Score reflects the quality distribution of your protein intake...",
        color: .green
    )
    .padding()
}
