//
//  DualScoreRingView.swift
//  WellPath
//
//  Dual concentric ring visualization showing two scores:
//  - Outer ring: Behavioral score (baseline or tracked)
//  - Inner ring: Daily score (today's performance)
//

import SwiftUI

struct DualScoreRingView: View {
    let outerScore: Double
    let innerScore: Double?
    let maxScore: Double
    let size: CGFloat
    let outerLineWidth: CGFloat
    let innerLineWidth: CGFloat
    let outerColor: Color
    let innerColor: Color

    init(
        outerScore: Double,
        innerScore: Double? = nil,
        maxScore: Double = 100,
        size: CGFloat = 120,
        outerLineWidth: CGFloat = 10,
        innerLineWidth: CGFloat = 6,
        outerColor: Color = .green,
        innerColor: Color = .blue
    ) {
        self.outerScore = outerScore
        self.innerScore = innerScore
        self.maxScore = maxScore
        self.size = size
        self.outerLineWidth = outerLineWidth
        self.innerLineWidth = innerLineWidth
        self.outerColor = outerColor
        self.innerColor = innerColor
    }

    private var outerProgress: Double {
        guard maxScore > 0 else { return 0 }
        return min(outerScore / maxScore, 1.0)
    }

    private var innerProgress: Double {
        guard maxScore > 0, let inner = innerScore else { return 0 }
        return min(inner / maxScore, 1.0)
    }

    private var innerRingSize: CGFloat {
        size - (outerLineWidth * 2) - 8 // Gap between rings
    }

    var body: some View {
        ZStack {
            // Outer ring background
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: outerLineWidth)
                .frame(width: size, height: size)

            // Outer ring progress
            Circle()
                .trim(from: 0, to: outerProgress)
                .stroke(
                    outerColor,
                    style: StrokeStyle(lineWidth: outerLineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)

            // Inner ring (only if we have a daily score)
            if innerScore != nil {
                // Inner ring background
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: innerLineWidth)
                    .frame(width: innerRingSize, height: innerRingSize)

                // Inner ring progress
                Circle()
                    .trim(from: 0, to: innerProgress)
                    .stroke(
                        innerColor,
                        style: StrokeStyle(lineWidth: innerLineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: innerRingSize, height: innerRingSize)
            }

            // Center content
            centerContent
        }
        .frame(width: size, height: size)
    }

    private var centerContent: some View {
        VStack(spacing: 0) {
            if let daily = innerScore {
                // Show both scores
                Text("\(Int(daily))")
                    .font(.system(size: size * 0.22, weight: .bold))
                    .foregroundColor(innerColor)

                Text("\(Int(outerScore))")
                    .font(.system(size: size * 0.14, weight: .semibold))
                    .foregroundColor(outerColor.opacity(0.8))
            } else {
                // Show only behavioral score
                Text("\(Int(outerScore))")
                    .font(.system(size: size * 0.28, weight: .bold))
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Compact version for cards

struct DualScoreRingCompact: View {
    let behavioralScore: Double
    let dailyScore: Double?
    let size: CGFloat
    let color: Color

    init(
        behavioralScore: Double,
        dailyScore: Double? = nil,
        size: CGFloat = 80,
        color: Color = .green
    ) {
        self.behavioralScore = behavioralScore
        self.dailyScore = dailyScore
        self.size = size
        self.color = color
    }

    private var behavioralColor: Color {
        scoreColor(for: behavioralScore)
    }

    private var dailyColor: Color {
        if let daily = dailyScore {
            return scoreColor(for: daily)
        }
        return color
    }

    private func scoreColor(for score: Double) -> Color {
        if score >= 80 { return .green }
        else if score >= 60 { return .yellow }
        else if score >= 40 { return .orange }
        else { return .red }
    }

    var body: some View {
        DualScoreRingView(
            outerScore: behavioralScore,
            innerScore: dailyScore,
            size: size,
            outerLineWidth: size * 0.1,
            innerLineWidth: size * 0.075,
            outerColor: behavioralColor,
            innerColor: dailyColor
        )
    }
}

#Preview {
    VStack(spacing: 40) {
        // Both scores
        VStack(spacing: 8) {
            DualScoreRingView(
                outerScore: 72,
                innerScore: 54,
                size: 120,
                outerColor: .yellow,
                innerColor: .orange
            )
            Text("Behavioral: 72 | Today: 54")
                .font(.caption)
        }

        // Behavioral only
        VStack(spacing: 8) {
            DualScoreRingView(
                outerScore: 85,
                innerScore: nil,
                size: 120,
                outerColor: .green
            )
            Text("Behavioral only: 85")
                .font(.caption)
        }

        // Compact version
        VStack(spacing: 8) {
            DualScoreRingCompact(
                behavioralScore: 72,
                dailyScore: 90,
                size: 80
            )
            Text("Compact with daily")
                .font(.caption)
        }
    }
    .padding()
}
