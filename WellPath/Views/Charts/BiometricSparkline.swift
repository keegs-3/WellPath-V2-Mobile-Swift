//
//  BiometricSparkline.swift
//  WellPath
//
//  Mini trend sparkline for biometric cards
//  Shows recent data points with the most recent highlighted
//  Fixed 6-slot layout - points fill from right to left
//

import SwiftUI
import Charts

/// Mini sparkline chart for biometric card displays
struct BiometricSparkline: View {
    let dataPoints: [SparklinePoint]
    let color: Color

    /// Fixed number of slots for consistent spacing
    private let slotCount = 6

    /// Points positioned in fixed slots (right-aligned)
    private var slottedPoints: [SlottedPoint] {
        let points = Array(dataPoints.suffix(slotCount))
        guard !points.isEmpty else { return [] }

        // Place points in rightmost slots
        let startSlot = slotCount - points.count
        return points.enumerated().map { index, point in
            SlottedPoint(
                slot: startSlot + index,
                value: point.value,
                isLatest: point.isLatest
            )
        }
    }

    private var hasData: Bool {
        !dataPoints.isEmpty
    }

    var body: some View {
        if hasData {
            Chart(slottedPoints) { point in
                // Line connecting points - secondary color
                LineMark(
                    x: .value("Slot", point.slot),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(Color.secondary.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1.5))

                // Stroked circle points
                PointMark(
                    x: .value("Slot", point.slot),
                    y: .value("Value", point.value)
                )
                .symbol {
                    Circle()
                        .strokeBorder(
                            point.isLatest ? color : Color.secondary.opacity(0.4),
                            lineWidth: point.isLatest ? 2 : 1.5
                        )
                        .background(Circle().fill(Color(uiColor: .systemBackground)))
                        .frame(width: point.isLatest ? 8 : 6, height: point.isLatest ? 8 : 6)
                }
            }
            .chartXScale(domain: 0...slotCount - 1)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(width: 60, height: 30)
        } else {
            // No placeholder when no data - just empty space
            EmptyView()
        }
    }
}

/// Point positioned in a fixed slot
private struct SlottedPoint: Identifiable {
    let id = UUID()
    let slot: Int
    let value: Double
    let isLatest: Bool
}

/// Data point for sparkline
struct SparklinePoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let isLatest: Bool

    init(date: Date, value: Double, isLatest: Bool = false) {
        self.date = date
        self.value = value
        self.isLatest = isLatest
    }
}

#Preview {
    VStack(spacing: 20) {
        // 6 points - fills all slots
        HStack {
            Text("6 pts:")
            BiometricSparkline(
                dataPoints: [
                    SparklinePoint(date: Date().addingTimeInterval(-5*24*3600), value: 22.5),
                    SparklinePoint(date: Date().addingTimeInterval(-4*24*3600), value: 23.1),
                    SparklinePoint(date: Date().addingTimeInterval(-3*24*3600), value: 22.8),
                    SparklinePoint(date: Date().addingTimeInterval(-2*24*3600), value: 23.5),
                    SparklinePoint(date: Date().addingTimeInterval(-1*24*3600), value: 22.9),
                    SparklinePoint(date: Date(), value: 23.0, isLatest: true)
                ],
                color: .cyan
            )
        }

        // 2 points - fills last 2 slots
        HStack {
            Text("2 pts:")
            BiometricSparkline(
                dataPoints: [
                    SparklinePoint(date: Date().addingTimeInterval(-1*24*3600), value: 22.9),
                    SparklinePoint(date: Date(), value: 23.0, isLatest: true)
                ],
                color: .cyan
            )
        }

        // Single point - last slot only
        HStack {
            Text("1 pt:")
            BiometricSparkline(
                dataPoints: [
                    SparklinePoint(date: Date(), value: 23.0, isLatest: true)
                ],
                color: .cyan
            )
        }

        // Empty
        HStack {
            Text("Empty:")
            BiometricSparkline(dataPoints: [], color: .cyan)
        }
    }
    .padding()
}
