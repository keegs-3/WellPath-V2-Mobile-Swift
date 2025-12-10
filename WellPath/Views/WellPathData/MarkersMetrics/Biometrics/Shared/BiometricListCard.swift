//
//  BiometricListCard.swift
//  WellPath
//
//  Card for displaying biometrics in list views

import SwiftUI

struct BiometricListCard: View {
    let name: String
    let value: String
    let numericValue: Double?
    let status: String
    let rangeName: String
    let optimalRange: String
    let trend: String
    let trendData: [Double]
    let statusColor: Color
    let rangeSegments: [RangeSegment]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with name and status
            HStack {
                Text(name)
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(status)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Value row
            HStack(alignment: .firstTextBaseline) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Spacer()

                // Trend indicator
                if !trend.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: trendIcon)
                            .font(.caption)
                            .foregroundColor(trendColor)
                        Text(trend)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Range info
            if !optimalRange.isEmpty {
                Text("Optimal: \(optimalRange)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Mini sparkline if we have trend data
            if trendData.count > 1 {
                MiniSparkline(data: trendData, color: statusColor)
                    .frame(height: 24)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var trendIcon: String {
        switch trend.lowercased() {
        case let t where t.contains("up") || t.contains("increasing"):
            return "arrow.up.right"
        case let t where t.contains("down") || t.contains("decreasing"):
            return "arrow.down.right"
        default:
            return "arrow.right"
        }
    }

    private var trendColor: Color {
        switch trend.lowercased() {
        case let t where t.contains("up") || t.contains("increasing"):
            return .green
        case let t where t.contains("down") || t.contains("decreasing"):
            return .red
        default:
            return .secondary
        }
    }
}

// Mini sparkline chart for trend visualization
private struct MiniSparkline: View {
    let data: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            if let minVal = data.min(), let maxVal = data.max(), maxVal > minVal {
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let range = maxVal - minVal

                    for (index, value) in data.enumerated() {
                        let x = width * CGFloat(index) / CGFloat(data.count - 1)
                        let y = height - (height * CGFloat(value - minVal) / CGFloat(range))

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, lineWidth: 1.5)
            } else {
                // Flat line for constant values
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height / 2))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height / 2))
                }
                .stroke(color, lineWidth: 1.5)
            }
        }
    }
}

#Preview {
    BiometricListCard(
        name: "Resting Heart Rate",
        value: "62 bpm",
        numericValue: 62,
        status: "Optimal",
        rangeName: "Athletic",
        optimalRange: "60-70 bpm",
        trend: "Stable",
        trendData: [64, 63, 62, 63, 62, 61, 62],
        statusColor: .green,
        rangeSegments: []
    )
    .padding()
}
