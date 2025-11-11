//
//  ScoreRingView.swift
//  WellPath
//
//  Reusable circular progress ring for score visualization
//

import SwiftUI

struct ScoreRingView<CenterContent: View>: View {
    let score: Double // 0-100 or actual points earned
    let maxScore: Double // typically 100 or max points
    let size: CGFloat
    let lineWidth: CGFloat
    let color: Color
    let centerContent: () -> CenterContent
    let subtitle: String?

    init(
        score: Double,
        maxScore: Double = 100,
        size: CGFloat = 120,
        lineWidth: CGFloat = 12,
        color: Color = Color(red: 0.56, green: 0.82, blue: 0.31), // WellPath green
        subtitle: String? = nil,
        @ViewBuilder centerContent: @escaping () -> CenterContent
    ) {
        self.score = score
        self.maxScore = maxScore
        self.size = size
        self.lineWidth = lineWidth
        self.color = color
        self.subtitle = subtitle
        self.centerContent = centerContent
    }

    private var progress: Double {
        guard maxScore > 0 else { return 0 }
        return min(score / maxScore, 1.0)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(
                        Color.gray.opacity(0.2),
                        lineWidth: lineWidth
                    )

                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        color,
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))

                // Center content
                centerContent()
            }
            .frame(width: size, height: size)

            // Subtitle below ring
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: size)
            }
        }
    }
}

// Convenience initializer for simple score display
extension ScoreRingView where CenterContent == AnyView {
    init(
        score: Double,
        maxScore: Double = 100,
        size: CGFloat = 120,
        lineWidth: CGFloat = 12,
        color: Color = Color(red: 0.56, green: 0.82, blue: 0.31),
        subtitle: String? = nil,
        showsPercentage: Bool = false
    ) {
        self.init(
            score: score,
            maxScore: maxScore,
            size: size,
            lineWidth: lineWidth,
            color: color,
            subtitle: subtitle
        ) {
            AnyView(
                VStack(spacing: 2) {
                    Text(showsPercentage ? "\(Int(score))%" : "\(Int(score))")
                        .font(.system(size: size * 0.25, weight: .bold))
                        .foregroundColor(.primary)

                    if !showsPercentage && maxScore != 100 {
                        Text("of \(Int(maxScore))")
                            .font(.system(size: size * 0.12, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                }
            )
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        // Simple score ring
        ScoreRingView(score: 53, subtitle: "Healthful Nutrition")

        // Points out of max
        ScoreRingView(score: 8, maxScore: 12, size: 100, subtitle: "HbA1c")

        // Percentage ring
        ScoreRingView(score: 72, subtitle: "Biomarkers\n38 points", showsPercentage: true)

        // Custom content
        ScoreRingView(
            score: 85,
            maxScore: 100,
            subtitle: "Overall Score"
        ) {
            AnyView(
                VStack {
                    Text("85")
                        .font(.system(size: 36, weight: .bold))
                    Text("Excellent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            )
        }
    }
    .padding()
}
