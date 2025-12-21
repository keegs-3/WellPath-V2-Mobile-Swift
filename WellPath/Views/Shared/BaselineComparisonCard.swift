//
//  BaselineComparisonCard.swift
//  WellPath
//
//  Reusable component showing baseline vs current value comparison.
//  Used in wizard summary and on metric screens.
//

import SwiftUI

struct BaselineComparisonCard: View {
    let title: String
    let baselineValue: Double?
    let currentValue: Double?
    let unit: String
    let color: Color
    var baselineLabel: String = "Baseline"
    var currentLabel: String = "Current"
    var showSetBaselineAction: Bool = true
    var onSetBaseline: (() -> Void)?

    private var comparison: BaselineComparison {
        guard let baseline = baselineValue, baseline > 0,
              let current = currentValue else {
            return .noBaseline
        }
        let diff = ((current - baseline) / baseline) * 100
        if abs(diff) < 5 { return .atBaseline }
        return diff > 0 ? .aboveBaseline(percent: diff) : .belowBaseline(percent: abs(diff))
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                Spacer()
            }

            if baselineValue != nil {
                // Has baseline - show comparison
                comparisonContent
            } else {
                // No baseline - show prompt
                noBaselineContent
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Comparison Content

    private var comparisonContent: some View {
        VStack(spacing: 12) {
            // Values row
            HStack(spacing: 0) {
                // Baseline value
                valueColumn(
                    label: baselineLabel,
                    value: baselineValue,
                    icon: "flag.fill",
                    iconColor: .secondary
                )

                Divider()
                    .frame(height: 50)

                // Current value
                valueColumn(
                    label: currentLabel,
                    value: currentValue,
                    icon: "location.fill",
                    iconColor: color
                )

                Divider()
                    .frame(height: 50)

                // Difference
                differenceColumn
            }

            // Status badge
            HStack {
                Circle()
                    .fill(comparison.color)
                    .frame(width: 8, height: 8)
                Text(comparison.description)
                    .font(.subheadline)
                    .foregroundColor(comparison.color)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(comparison.color.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private func valueColumn(label: String, value: Double?, icon: String, iconColor: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(iconColor)
            Text(formatValue(value))
                .font(.title3)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var differenceColumn: some View {
        VStack(spacing: 4) {
            Image(systemName: differenceIcon)
                .font(.caption)
                .foregroundColor(comparison.color)
            Text(differenceText)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(comparison.color)
            Text("Change")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var differenceIcon: String {
        switch comparison {
        case .noBaseline, .atBaseline:
            return "equal"
        case .aboveBaseline:
            return "arrow.up"
        case .belowBaseline:
            return "arrow.down"
        }
    }

    private var differenceText: String {
        switch comparison {
        case .noBaseline:
            return "--"
        case .atBaseline:
            return "0%"
        case .aboveBaseline(let percent), .belowBaseline(let percent):
            return String(format: "%.0f%%", percent)
        }
    }

    // MARK: - No Baseline Content

    private var noBaselineContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "flag.badge.ellipsis")
                    .font(.title2)
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("No baseline set")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Set your baseline to track progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            if showSetBaselineAction, let action = onSetBaseline {
                Button(action: action) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Set Baseline")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(color)
                    .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatValue(_ value: Double?) -> String {
        guard let value = value else { return "--" }
        if value >= 100 || value == floor(value) {
            return "\(Int(value)) \(unit)"
        } else {
            return String(format: "%.1f %@", value, unit)
        }
    }
}

// MARK: - Preview

#Preview("With Baseline - Above") {
    BaselineComparisonCard(
        title: "Daily Protein",
        baselineValue: 80,
        currentValue: 95,
        unit: "g",
        color: .blue
    )
    .padding()
}

#Preview("With Baseline - Below") {
    BaselineComparisonCard(
        title: "Daily Protein",
        baselineValue: 80,
        currentValue: 65,
        unit: "g",
        color: .blue
    )
    .padding()
}

#Preview("With Baseline - At") {
    BaselineComparisonCard(
        title: "Daily Protein",
        baselineValue: 80,
        currentValue: 82,
        unit: "g",
        color: .blue
    )
    .padding()
}

#Preview("No Baseline") {
    BaselineComparisonCard(
        title: "Daily Protein",
        baselineValue: nil,
        currentValue: 95,
        unit: "g",
        color: .blue
    ) {
        print("Set baseline tapped")
    }
    .padding()
}
