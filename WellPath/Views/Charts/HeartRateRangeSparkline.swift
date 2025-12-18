//
//  HeartRateRangeSparkline.swift
//  WellPath
//
//  Mini sparkline showing daily heart rate ranges as vertical bars
//  Fixed 7-slot layout - bars fill from right to left
//  Each bar shows min-max range for the day in grey, with most recent value as a colored dot
//

import SwiftUI
import Charts

/// Data point for heart rate range sparkline
struct HRRangePoint: Identifiable {
    let id = UUID()
    let date: Date
    let minValue: Double
    let maxValue: Double
    let latestValue: Double?  // The most recent reading for this day (for the dot)
    let isLatest: Bool        // Is this the most recent day with data?
}

/// Mini sparkline chart showing daily heart rate ranges
struct HeartRateRangeSparkline: View {
    let dataPoints: [HRRangePoint]
    let color: Color

    /// Fixed number of slots for consistent spacing
    private let slotCount = 7

    /// Points positioned in fixed slots (right-aligned)
    private var slottedPoints: [SlottedHRPoint] {
        let points = Array(dataPoints.suffix(slotCount))
        guard !points.isEmpty else { return [] }

        // Place points in rightmost slots
        let startSlot = slotCount - points.count
        return points.enumerated().map { index, point in
            SlottedHRPoint(
                slot: startSlot + index,
                minValue: point.minValue,
                maxValue: point.maxValue,
                latestValue: point.latestValue,
                isLatest: point.isLatest
            )
        }
    }

    /// Y-axis domain based on data
    private var yDomain: ClosedRange<Double> {
        guard !dataPoints.isEmpty else { return 50...120 }
        let allMins = dataPoints.map { $0.minValue }
        let allMaxs = dataPoints.map { $0.maxValue }
        let minVal = (allMins.min() ?? 50) - 5
        let maxVal = (allMaxs.max() ?? 120) + 5
        return minVal...maxVal
    }

    private var hasData: Bool {
        !dataPoints.isEmpty
    }

    var body: some View {
        if hasData {
            Chart(slottedPoints) { point in
                // Range bar (grey vertical bar from min to max)
                RectangleMark(
                    x: .value("Slot", point.slot),
                    yStart: .value("Min", point.minValue),
                    yEnd: .value("Max", point.maxValue),
                    width: 4
                )
                .foregroundStyle(Color.secondary.opacity(0.3))
                .cornerRadius(2)

                // Latest value dot (only on most recent day)
                if point.isLatest, let latest = point.latestValue {
                    PointMark(
                        x: .value("Slot", point.slot),
                        y: .value("Latest", latest)
                    )
                    .symbol {
                        Circle()
                            .fill(color)
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .chartXScale(domain: 0...slotCount - 1)
            .chartYScale(domain: yDomain)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(width: 70, height: 30)
        } else {
            EmptyView()
        }
    }
}

/// Point positioned in a fixed slot
private struct SlottedHRPoint: Identifiable {
    let id = UUID()
    let slot: Int
    let minValue: Double
    let maxValue: Double
    let latestValue: Double?
    let isLatest: Bool
}

#Preview {
    VStack(spacing: 20) {
        // 7 days of data
        HStack {
            Text("7 days:")
            HeartRateRangeSparkline(
                dataPoints: [
                    HRRangePoint(date: Date().addingTimeInterval(-6*24*3600), minValue: 62, maxValue: 88, latestValue: nil, isLatest: false),
                    HRRangePoint(date: Date().addingTimeInterval(-5*24*3600), minValue: 65, maxValue: 92, latestValue: nil, isLatest: false),
                    HRRangePoint(date: Date().addingTimeInterval(-4*24*3600), minValue: 60, maxValue: 85, latestValue: nil, isLatest: false),
                    HRRangePoint(date: Date().addingTimeInterval(-3*24*3600), minValue: 68, maxValue: 95, latestValue: nil, isLatest: false),
                    HRRangePoint(date: Date().addingTimeInterval(-2*24*3600), minValue: 64, maxValue: 90, latestValue: nil, isLatest: false),
                    HRRangePoint(date: Date().addingTimeInterval(-1*24*3600), minValue: 66, maxValue: 87, latestValue: nil, isLatest: false),
                    HRRangePoint(date: Date(), minValue: 68, maxValue: 85, latestValue: 82, isLatest: true)
                ],
                color: .red
            )
        }

        // 2 days of data (right-aligned)
        HStack {
            Text("2 days:")
            HeartRateRangeSparkline(
                dataPoints: [
                    HRRangePoint(date: Date().addingTimeInterval(-1*24*3600), minValue: 66, maxValue: 87, latestValue: nil, isLatest: false),
                    HRRangePoint(date: Date(), minValue: 68, maxValue: 85, latestValue: 82, isLatest: true)
                ],
                color: .red
            )
        }

        // Single day
        HStack {
            Text("1 day:")
            HeartRateRangeSparkline(
                dataPoints: [
                    HRRangePoint(date: Date(), minValue: 68, maxValue: 85, latestValue: 82, isLatest: true)
                ],
                color: .red
            )
        }

        // Empty
        HStack {
            Text("Empty:")
            HeartRateRangeSparkline(dataPoints: [], color: .red)
        }
    }
    .padding()
}
