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
        ("Tier 1", MetricsUIConfig.tierGood, 21),
        ("Tier 2", MetricsUIConfig.tierMedium, 79),
        ("Tier 3", MetricsUIConfig.tierPoor, 0)
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
                        tierIndicator(label: tier.name, color: tier.color, percentage: Double(tier.percentage))
                    }
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func tierIndicator(label: String, color: Color, percentage: Double) -> some View {
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

// MARK: - Nutrient Servings Preview (Vegetables, Fruits, Legumes, Whole Grains, Nuts & Seeds)
// Now matches Protein Amount style with mini bar chart

struct NutrientServingsPreviewCard: View {
    let title: String
    let color: Color
    let todayValue: Double
    let weeklyAvg: Double
    let unit: String

    // Sample 7-day data for mini chart
    private var sampleData: [(day: String, value: Double, isToday: Bool)] {
        [
            ("S", weeklyAvg * 0.8, false),
            ("M", weeklyAvg * 1.1, false),
            ("T", weeklyAvg * 0.9, false),
            ("W", weeklyAvg * 1.2, false),
            ("T", weeklyAvg * 0.85, false),
            ("F", weeklyAvg * 1.0, false),
            ("S", todayValue, true)
        ]
    }

    private var maxValue: Double {
        sampleData.map { $0.value }.max() ?? 5
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Card header
            HStack {
                Text("\(title) Servings")
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

            // Content - matches Protein Amount layout with mini bar chart
            HStack(spacing: 12) {
                // Today's total on left
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(String(format: "%.1f", todayValue))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(color)
                        Text(unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Mini bar chart on right - 7 days
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

// MARK: - Nutrient Type/Variety Preview

struct NutrientTypePreviewCard: View {
    let title: String
    let color: Color
    let varietyScore: Int
    let typesCount: Int

    private var varietyColor: Color {
        if varietyScore >= 85 { return MetricsUIConfig.tierGood }
        else if varietyScore >= 70 { return MetricsUIConfig.tierMedium }
        else { return MetricsUIConfig.tierPoor }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Card header
            HStack {
                Text("\(title) Type")
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
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Variety Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(varietyScore)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(varietyColor)
                        Text("/ 100")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(typesCount) types")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text("this week")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Fats Amount Preview

struct FatsAmountPreviewCard: View {
    let color: Color

    private let sampleData: [(day: String, value: Double, isToday: Bool)] = [
        ("S", 55, false), ("M", 62, false), ("T", 48, false),
        ("W", 70, false), ("T", 58, false), ("F", 65, false), ("S", 52, true)
    ]

    private var maxValue: Double {
        sampleData.map { $0.value }.max() ?? 70
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Fat Amount")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Image(systemName: "star")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("52")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(color)
                        Text("g")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

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

// MARK: - Fats Type Preview

struct FatsTypePreviewCard: View {
    let color: Color

    private let tiers: [(name: String, color: Color, percentage: Int)] = [
        ("Good", MetricsUIConfig.tierGood, 72),
        ("Limit", MetricsUIConfig.tierPoor, 28)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Fat Type")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Image(systemName: "star")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quality Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("72")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(MetricsUIConfig.tierMedium)
                        Text("/ 100")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    ForEach(tiers, id: \.name) { tier in
                        tierIndicator(label: tier.name, color: tier.color, percentage: Double(tier.percentage))
                    }
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func tierIndicator(label: String, color: Color, percentage: Double) -> some View {
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

// MARK: - Water/Hydration Amount Preview

struct WaterAmountPreviewCard: View {
    let color: Color

    private let sampleData: [(day: String, value: Double, isToday: Bool)] = [
        ("S", 6, false), ("M", 8, false), ("T", 7, false),
        ("W", 9, false), ("T", 6, false), ("F", 8, false), ("S", 7, true)
    ]

    private var maxValue: Double {
        sampleData.map { $0.value }.max() ?? 10
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Water Intake")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Image(systemName: "star")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("7")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(color)
                        Text("cups")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

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

// MARK: - Ultra-Processed Preview

struct UltraProcessedPreviewCard: View {
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Ultra-Processed Foods")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Image(systemName: "star")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("2")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(MetricsUIConfig.tierGood)
                        Text("servings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Goal: <3")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text("servings/day")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Caffeine Amount Preview (matches CaffeineWizardView)

struct CaffeineAmountPreviewCard: View {
    let color: Color

    private let sampleData: [(day: String, value: Double, isToday: Bool)] = [
        ("S", 95, false), ("M", 180, false), ("T", 150, false),
        ("W", 200, false), ("T", 95, false), ("F", 250, false), ("S", 180, true)
    ]

    private var maxValue: Double {
        sampleData.map { $0.value }.max() ?? 300
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Caffeine Intake")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Image(systemName: "star")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("180")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(color)
                        Text("mg")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

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

// MARK: - Caffeine Type Preview

struct CaffeineTypePreviewCard: View {
    let color: Color

    private let tiers: [(name: String, color: Color, percentage: Int)] = [
        ("Tier 1", MetricsUIConfig.tierGood, 75),
        ("Tier 2", MetricsUIConfig.tierPoor, 25)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Caffeine Sources")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Image(systemName: "star")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quality Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("75")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(MetricsUIConfig.tierMedium)
                        Text("/ 100")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    ForEach(tiers, id: \.name) { tier in
                        tierIndicator(label: tier.name, color: tier.color, percentage: Double(tier.percentage))
                    }
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func tierIndicator(label: String, color: Color, percentage: Double) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)

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

// MARK: - Water/Hydration Timing Preview

struct WaterTimingPreviewCard: View {
    let color: Color

    // Sample hourly data for preview - shows typical hydration pattern
    private let sampleHourlyData: [Int: Double] = [
        7: 250,   // Morning
        9: 200,   // Mid-morning
        12: 300,  // Lunch
        14: 150,  // Afternoon
        16: 200,  // Late afternoon
        18: 250,  // Dinner
        20: 150   // Evening
    ]

    private let sampleScore: Int = 78

    private var scoreColor: Color {
        if sampleScore >= 85 { return MetricsUIConfig.tierGood }
        else if sampleScore >= 70 { return MetricsUIConfig.tierMedium }
        else if sampleScore >= 55 { return Color.orange }
        else { return MetricsUIConfig.tierPoor }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("Hydration Timing")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Image(systemName: "star")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }

            // Content - Score on left, ring on right (matches type cards)
            HStack(spacing: 16) {
                // Timing Score on left
                VStack(alignment: .leading, spacing: 4) {
                    Text("Timing Score")
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
                    Text("Today")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Mini ring clock on right
                WaterTimingMiniClockPreview(
                    hourlyData: sampleHourlyData,
                    color: color,
                    size: 54
                )
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Water Timing Mini Clock Preview

private struct WaterTimingMiniClockPreview: View {
    let hourlyData: [Int: Double]
    let color: Color
    let size: CGFloat

    private let ringWidth: CGFloat = 4
    private let activeStartHour = 6
    private let activeEndHour = 22

    // The radius for the ring center (stroke is centered on this)
    private var ringRadius: CGFloat {
        (size - ringWidth) / 2
    }

    var body: some View {
        ZStack {
            // Background ring - frame matches stroke-centered diameter
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: ringWidth)
                .frame(width: size - ringWidth, height: size - ringWidth)

            // Hour segments with data
            ForEach(0..<24, id: \.self) { hour in
                if (hourlyData[hour] ?? 0) > 0 {
                    hourSegment(hour: hour)
                }
            }

            // Center icon
            Image(systemName: "drop.fill")
                .font(.system(size: size * 0.28))
                .foregroundColor(color)
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private func hourSegment(hour: Int) -> some View {
        let amount = hourlyData[hour] ?? 0
        let maxHourly = hourlyData.values.max() ?? 1
        let intensity = min(amount / maxHourly, 1.0)
        let isActive = hour >= activeStartHour && hour < activeEndHour

        let degreesPerHour = 360.0 / 24.0
        // Inset slightly so rounded caps don't overlap adjacent segments
        let gapDegrees = 2.0
        let startAngle = Double(hour) * degreesPerHour - 90 + gapDegrees
        let endAngle = Double(hour + 1) * degreesPerHour - 90 - gapDegrees

        Path { path in
            path.addArc(
                center: CGPoint(x: size / 2, y: size / 2),
                radius: ringRadius,
                startAngle: .degrees(startAngle),
                endAngle: .degrees(endAngle),
                clockwise: false
            )
        }
        .stroke(
            isActive ? color.opacity(0.5 + intensity * 0.5) : Color.orange.opacity(0.6),
            style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
        )
    }
}

// MARK: - Sleep Duration Preview

struct SleepDurationPreviewCard: View {
    let color: Color

    private let sampleData: [(day: String, value: Double, isToday: Bool)] = [
        ("S", 7.5, false), ("M", 6.5, false), ("T", 8.0, false),
        ("W", 7.0, false), ("T", 6.0, false), ("F", 7.5, false), ("S", 8.0, true)
    ]

    private var maxValue: Double {
        sampleData.map { $0.value }.max() ?? 10
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sleep Duration")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Image(systemName: "star")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Night")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("8.0")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(color)
                        Text("hrs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

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

#Preview("Nutrient Servings") {
    NutrientServingsPreviewCard(title: "Vegetable", color: .green, todayValue: 3.5, weeklyAvg: 4.2, unit: "servings")
        .padding()
}

#Preview("Nutrient Type") {
    NutrientTypePreviewCard(title: "Vegetable", color: .green, varietyScore: 78, typesCount: 5)
        .padding()
}

#Preview("Fats") {
    VStack(spacing: 12) {
        FatsAmountPreviewCard(color: .orange)
        FatsTypePreviewCard(color: .orange)
    }
    .padding()
}

#Preview("Water") {
    WaterAmountPreviewCard(color: .cyan)
        .padding()
}

#Preview("Ultra-Processed") {
    UltraProcessedPreviewCard(color: .red)
        .padding()
}

#Preview("Caffeine") {
    VStack(spacing: 12) {
        CaffeineAmountPreviewCard(color: .brown)
        CaffeineTypePreviewCard(color: .brown)
    }
    .padding()
}
