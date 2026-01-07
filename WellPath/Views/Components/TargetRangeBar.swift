//
//  TargetRangeBar.swift
//  WellPath
//
//  Shows actual value vs target with color coding
//  - Bar width represents 100% (or max value)
//  - Vertical marker shows target position
//  - Fill shows actual value
//  - Color indicates performance relative to target
//

import SwiftUI

enum RangeBarMode {
    case higherBetter   // Green if at or above target
    case matchTarget    // Green if close to target
    case lowerBetter    // Green if at or below target
}

struct TargetRangeBar: View {
    let actual: Double
    let target: Double
    let max: Double
    let label: String
    let unit: String
    let mode: RangeBarMode
    let showValues: Bool
    let height: CGFloat

    init(
        actual: Double,
        target: Double,
        max: Double = 100,
        label: String,
        unit: String = "%",
        mode: RangeBarMode = .matchTarget,
        showValues: Bool = true,
        height: CGFloat = 8
    ) {
        self.actual = actual
        self.target = target
        self.max = max
        self.label = label
        self.unit = unit
        self.mode = mode
        self.showValues = showValues
        self.height = height
    }

    // Normalize to percentage of max
    private var actualPct: Double {
        min(100, (actual / max) * 100)
    }

    private var targetPct: Double {
        min(100, (target / max) * 100)
    }

    // Calculate color based on mode and deviation
    private var barColor: Color {
        let deviation = actual - target
        let deviationPct = abs(deviation) / target

        switch mode {
        case .higherBetter:
            if actual >= target { return .green }
            if deviationPct <= 0.1 { return .yellow }
            if deviationPct <= 0.25 { return .orange }
            return .red

        case .lowerBetter:
            if actual <= target { return .green }
            if deviationPct <= 0.1 { return .yellow }
            if deviationPct <= 0.25 { return .orange }
            return .red

        case .matchTarget:
            if deviationPct <= 0.05 { return .green }
            if deviationPct <= 0.15 { return .yellow }
            if deviationPct <= 0.3 { return .orange }
            return .red
        }
    }

    private func formatValue(_ val: Double) -> String {
        switch unit {
        case "%": return "\(Int(val))%"
        case "g": return "\(Int(val))g"
        case "ml": return "\(Int(val))ml"
        case "L": return String(format: "%.1fL", val / 1000)
        default: return "\(Int(val))\(unit)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Label row
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Spacer()

                if showValues {
                    HStack(spacing: 4) {
                        Text(formatValue(actual))
                            .foregroundColor(.primary)
                        Text("→")
                            .foregroundColor(.secondary)
                        Text(formatValue(target))
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
            }

            // Bar container
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: height)

                    // Actual value fill
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(barColor)
                        .frame(width: geometry.size.width * (actualPct / 100), height: height)

                    // Target marker
                    VStack(spacing: 0) {
                        // Triangle cap
                        Triangle()
                            .fill(Color.primary)
                            .frame(width: 8, height: 4)

                        // Vertical line
                        Rectangle()
                            .fill(Color.primary)
                            .frame(width: 2, height: height + 4)
                    }
                    .offset(x: geometry.size.width * (targetPct / 100) - 4, y: -4)
                }
            }
            .frame(height: height + 8)
        }
    }
}

// Triangle shape for marker cap
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Timing Distribution Display

struct TimingDistributionDisplay: View {
    let slots: [(name: String, actual: Double, target: Double)]
    let label: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let label = label {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }

            ForEach(slots, id: \.name) { slot in
                TargetRangeBar(
                    actual: slot.actual,
                    target: slot.target,
                    label: slot.name,
                    unit: "%",
                    mode: .matchTarget,
                    height: 6
                )
            }
        }
    }
}

// MARK: - Scoring Range Display

struct DisplayScoringRange: Identifiable {
    let id = UUID()
    let name: String      // 'OPTIMAL', 'IN RANGE', 'OUT OF RANGE'
    let low: Double
    let high: Double
    let display: String   // e.g., '1.5 – 3.0L'
}

struct ScoringRangeDisplay: View {
    let value: Double
    let ranges: [DisplayScoringRange]
    let unit: String
    let label: String?

    init(value: Double, ranges: [DisplayScoringRange], unit: String = "", label: String? = nil) {
        self.value = value
        self.ranges = ranges
        self.unit = unit
        self.label = label
    }

    private func isActive(_ range: DisplayScoringRange) -> Bool {
        value >= range.low && value <= range.high
    }

    private func rangeColor(_ range: DisplayScoringRange) -> (bg: Color, text: Color, ring: Color?) {
        let active = isActive(range)

        if !active {
            return (Color(.secondarySystemGroupedBackground), .secondary, nil)
        }

        switch range.name {
        case "OPTIMAL":
            return (Color.green.opacity(0.15), .green, .green)
        case "IN RANGE":
            return (Color.yellow.opacity(0.15), .yellow, .yellow)
        default:
            return (Color.red.opacity(0.15), .red, .red)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label = label {
                HStack {
                    Text(label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(Int(value))\(unit)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            ForEach(ranges) { range in
                let colors = rangeColor(range)
                let active = isActive(range)

                HStack {
                    HStack(spacing: 8) {
                        Text(active ? "●" : "○")
                            .font(.caption)
                        Text(range.name)
                            .fontWeight(.medium)
                    }
                    Spacer()
                    Text(range.display)
                }
                .font(.subheadline)
                .foregroundColor(colors.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(colors.bg)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(colors.ring ?? .clear, lineWidth: active ? 2 : 0)
                )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 32) {
            // Target Range Bar examples
            VStack(alignment: .leading, spacing: 16) {
                Text("Target Range Bars")
                    .font(.headline)

                TargetRangeBar(
                    actual: 20,
                    target: 25,
                    label: "Morning",
                    unit: "%",
                    mode: .matchTarget
                )

                TargetRangeBar(
                    actual: 50,
                    target: 35,
                    label: "Evening",
                    unit: "%",
                    mode: .matchTarget
                )

                TargetRangeBar(
                    actual: 150,
                    target: 175,
                    label: "Protein",
                    unit: "g",
                    mode: .higherBetter
                )
            }

            Divider()

            // Timing Distribution
            TimingDistributionDisplay(
                slots: [
                    ("Morning", 20, 25),
                    ("Afternoon", 20, 25),
                    ("Evening", 50, 35),
                    ("Night", 10, 15)
                ],
                label: "Hydration Timing"
            )

            Divider()

            // Scoring Ranges
            ScoringRangeDisplay(
                value: 2500,
                ranges: [
                    DisplayScoringRange(name: "OUT OF RANGE", low: 500, high: 999, display: "< 1.0L"),
                    DisplayScoringRange(name: "IN RANGE", low: 1000, high: 1499, display: "1.0 – 1.4L"),
                    DisplayScoringRange(name: "OPTIMAL", low: 1500, high: 2999, display: "1.5 – 3.0L"),
                    DisplayScoringRange(name: "IN RANGE", low: 3000, high: 4999, display: "3.0 – 4.9L"),
                    DisplayScoringRange(name: "OUT OF RANGE", low: 5000, high: 15000, display: "> 5.0L")
                ],
                unit: "ml",
                label: "Daily Water Intake"
            )
        }
        .padding()
    }
}
