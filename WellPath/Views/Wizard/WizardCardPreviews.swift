//
//  WizardCardPreviews.swift
//  WellPath
//
//  Static preview cards for the baseline wizard.
//  Shows sample data to demonstrate what the cards will look like when populated.
//  Non-interactive (no navigation).
//

import SwiftUI

// MARK: - Protein Amount Preview

struct ProteinAmountPreviewCard: View {
    let color: Color

    // Sample data for preview
    private let sampleData: [(day: String, value: Double, isToday: Bool)] = [
        ("S", 85, false),
        ("M", 92, false),
        ("T", 78, false),
        ("W", 105, false),
        ("T", 88, false),
        ("F", 95, false),
        ("S", 72, true)
    ]

    private var maxValue: Double {
        sampleData.map { $0.value }.max() ?? 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Card header
            HStack {
                Text("Protein Amount")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Image(systemName: "star")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }

            // Content
            HStack(spacing: 12) {
                // Today's total
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("72")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(color)
                        Text("g")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Mini bar chart
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(Array(sampleData.enumerated()), id: \.offset) { _, day in
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(day.isToday ? color : color.opacity(0.4))
                                .frame(width: 8, height: barHeight(for: day.value))
                            Text(day.day)
                                .font(.system(size: 7))
                                .foregroundColor(day.isToday ? color : .secondary)
                        }
                    }
                }
                .frame(height: 45)
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func barHeight(for value: Double) -> CGFloat {
        let normalized = min(value / max(maxValue, 1), 1)
        return 15 + normalized * 25
    }
}

// MARK: - Protein Type Preview (matches ProteinTypeMiniCard)

struct ProteinTypePreviewCard: View {
    let color: Color

    // Sample tier data matching real card layout
    private let tiers: [(name: String, color: Color, percentage: Int)] = [
        ("Best", MetricsUIConfig.tierGood, 21),
        ("Good", MetricsUIConfig.tierMedium, 79),
        ("Limit", MetricsUIConfig.tierPoor, 0)
    ]

    private let sampleScore: Int = 66

    private var scoreColor: Color {
        if sampleScore >= 85 { return Color.green }
        else if sampleScore >= 70 { return Color.blue }
        else if sampleScore >= 55 { return Color.orange }
        else { return Color.red }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Card header
            HStack {
                Text("Protein Type")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Image(systemName: "star")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }

            // Content - matches ProteinTypeMiniCard layout
            HStack(spacing: 16) {
                // Quality Score on left
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quality Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(sampleScore)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(scoreColor)
                        Text("/ 100")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Tier breakdown with horizontal bars on right
                VStack(alignment: .trailing, spacing: 4) {
                    ForEach(tiers, id: \.name) { tier in
                        tierIndicator(label: tier.name, percentage: Double(tier.percentage), color: tier.color)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func tierIndicator(label: String, percentage: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 32, alignment: .trailing)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                    .frame(width: 50, height: 6)

                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 50 * min(percentage / 100, 1.0), height: 6)
            }

            Text("\(Int(percentage.rounded()))%")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)
        }
    }
}

// MARK: - Protein Ratio Preview (matches ProteinRatioMiniCard)

struct ProteinRatioPreviewCard: View {
    let color: Color

    // Sample data matching real card
    private let sampleValue: Double = 1.35
    private let sampleStatus: String = "Optimal"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Card header
            HStack {
                Text("Protein Ratio")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Image(systemName: "star")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }

            // Content - matches ProteinRatioMiniCard layout
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "percent")
                        .font(.title3)
                        .foregroundColor(color)
                }

                // Value, date, and status
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.2f", sampleValue))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Text("g/kg")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Text("Yesterday")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("·")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(sampleStatus)
                            .font(.caption)
                            .foregroundColor(MetricsUIConfig.tierGood)
                    }
                }

                Spacer()

                // Mini sparkline with line, circles, and range band (matches real card)
                RatioSparklinePreview(color: color)
                    .frame(width: 70, height: 36)
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Ratio Sparkline Preview (matches ProteinRatioSparkline)

private struct RatioSparklinePreview: View {
    let color: Color

    // Sample data points (y positions as percentages of height, representing ratio values)
    // Values around 1.2-1.6 g/kg optimal range
    private let samplePoints: [CGFloat] = [0.35, 0.55, 0.3, 0.7, 0.45, 0.6]

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let pointSpacing = width / CGFloat(samplePoints.count - 1)

            ZStack {
                // Optimal range band (blue rectangle in middle area)
                Rectangle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(height: height * 0.35)
                    .offset(y: height * 0.05)

                // Line connecting points
                Path { path in
                    for (index, point) in samplePoints.enumerated() {
                        let x = CGFloat(index) * pointSpacing
                        let y = height - (point * height)

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1.5)

                // Stroked circle points
                ForEach(Array(samplePoints.enumerated()), id: \.offset) { index, point in
                    let x = CGFloat(index) * pointSpacing
                    let y = height - (point * height)
                    let isLatest = index == samplePoints.count - 1

                    Circle()
                        .strokeBorder(
                            isLatest ? color : Color.secondary.opacity(0.4),
                            lineWidth: isLatest ? 2 : 1.5
                        )
                        .background(Circle().fill(Color(uiColor: .systemBackground)))
                        .frame(width: isLatest ? 8 : 6, height: isLatest ? 8 : 6)
                        .position(x: x, y: y)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Protein Amount") {
    ProteinAmountPreviewCard(color: .blue)
        .padding()
}

#Preview("Protein Type") {
    ProteinTypePreviewCard(color: .blue)
        .padding()
}

#Preview("Protein Ratio") {
    ProteinRatioPreviewCard(color: .blue)
        .padding()
}
