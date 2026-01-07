//
//  ScoreRingPill.swift
//  WellPath
//
//  Oura-style compact score ring with icon and label
//  DB-driven: uses icon_name from display_card_categories
//

import SwiftUI

struct ScoreRingPill: View {
    let score: Int?
    let maxScore: Int
    let iconName: String
    let label: String
    let size: CGFloat
    let color: Color?

    /// Standard init with score out of 100
    init(
        score: Int?,
        iconName: String,
        label: String,
        size: CGFloat = 70
    ) {
        self.score = score
        self.maxScore = 100
        self.iconName = iconName
        self.label = label
        self.size = size
        self.color = nil
    }

    /// Init with custom max score (normalizes to 100 for display)
    init(
        score: Int?,
        maxScore: Int,
        iconName: String,
        label: String,
        size: CGFloat = 70,
        color: Color? = nil
    ) {
        self.score = score
        self.maxScore = maxScore
        self.iconName = iconName
        self.label = label
        self.size = size
        self.color = color
    }

    // Subtle teal/cyan like Oura, or custom color
    private var ringColor: Color {
        color ?? Color(red: 0.4, green: 0.7, blue: 0.8).opacity(0.8)
    }

    /// Normalized score out of 100
    private var normalizedScore: Int? {
        guard let score = score, maxScore > 0 else { return nil }
        return Int((Double(score) / Double(maxScore)) * 100.0)
    }

    private var progress: Double {
        guard let score = score, maxScore > 0 else { return 0 }
        return Double(score) / Double(maxScore)
    }

    var body: some View {
        VStack(spacing: label.isEmpty ? 0 : 6) {
            // Ring with score and icon
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: size * 0.04)
                    .frame(width: size, height: size)

                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(
                            lineWidth: size * 0.04,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: size, height: size)

                // Center content
                VStack(spacing: 2) {
                    // Score (normalized to 100 scale for display)
                    if let displayScore = normalizedScore {
                        Text("\(displayScore)")
                            .font(.system(size: size * 0.3, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                    } else {
                        Text("--")
                            .font(.system(size: size * 0.3, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    // Icon
                    Image(systemName: iconName)
                        .font(.system(size: size * 0.16))
                        .foregroundColor(ringColor)
                }
            }
            .frame(width: size, height: size)

            // Label - only show if not empty
            if !label.isEmpty {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Horizontal Score Row

struct ScoreRingRow: View {
    let scores: [ScoreRingData]
    let pillSize: CGFloat

    init(scores: [ScoreRingData], pillSize: CGFloat = 70) {
        self.scores = scores
        self.pillSize = pillSize
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(scores) { data in
                    ScoreRingPill(
                        score: data.score,
                        iconName: data.iconName,
                        label: data.label,
                        size: pillSize
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

struct ScoreRingData: Identifiable {
    let id = UUID()
    let score: Int?
    let iconName: String
    let label: String
    let categoryId: String?

    init(
        score: Int?,
        iconName: String,
        label: String,
        categoryId: String? = nil
    ) {
        self.score = score
        self.iconName = iconName
        self.label = label
        self.categoryId = categoryId
    }
}

#Preview {
    VStack(spacing: 32) {
        // Single pill
        ScoreRingPill(
            score: 72,
            iconName: "fish.fill",
            label: "Protein"
        )

        // Row of pills (Oura style)
        ScoreRingRow(scores: [
            ScoreRingData(score: 85, iconName: "drop.fill", label: "Hydration"),
            ScoreRingData(score: 72, iconName: "fish.fill", label: "Protein"),
            ScoreRingData(score: 45, iconName: "carrot.fill", label: "Vegetables"),
            ScoreRingData(score: nil, iconName: "apple.logo", label: "Fruits"),
            ScoreRingData(score: 90, iconName: "leaf.fill", label: "Legumes")
        ])

        // Smaller size
        ScoreRingRow(scores: [
            ScoreRingData(score: 77, iconName: "fish.fill", label: "Protein"),
            ScoreRingData(score: 95, iconName: "drop.fill", label: "Hydration"),
            ScoreRingData(score: 62, iconName: "carrot.fill", label: "Vegetables")
        ], pillSize: 56)
    }
    .padding()
    .background(Color(.systemBackground))
}
