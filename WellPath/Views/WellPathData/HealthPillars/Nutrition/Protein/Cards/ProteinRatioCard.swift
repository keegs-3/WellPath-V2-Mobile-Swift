//
//  ProteinRatioCard.swift
//  WellPath
//
//  Reusable card for Protein Ratio metric (g/kg or g/lb body weight).
//  Shows weekly average with mini line chart and target range band.
//

import SwiftUI
import Charts

struct ProteinRatioCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Protein Ratio",
            color: color,
            metricId: "DISP_PROTEIN_RATIO",
            pillar: pillar
        ) {
            ProteinRatioMiniCard(color: color)
        } fullScreen: {
            ProteinRatioView(color: color)
        }
    }
}

// MARK: - Mini Card

struct ProteinRatioMiniCard: View {
    let color: Color
    @StateObject private var viewModel = ProteinPerBodyWeightViewModel()
    @StateObject private var unitPrefs = UnitPreferencesViewModel()

    // Optimal range in g/kg (backend standard)
    private let optimalRangeGPerKg: ClosedRange<Double> = 1.2...1.6

    // Conversion factor: 1 kg = 2.2046 lb
    private let kgToLb: Double = 2.2046

    private var usePounds: Bool {
        unitPrefs.weightUnit == .lb
    }

    private var optimalRangeLow: Double {
        usePounds ? optimalRangeGPerKg.lowerBound / kgToLb : optimalRangeGPerKg.lowerBound
    }

    private var optimalRangeHigh: Double {
        usePounds ? optimalRangeGPerKg.upperBound / kgToLb : optimalRangeGPerKg.upperBound
    }

    private var unitLabel: String {
        usePounds ? "g/lb" : "g/kg"
    }

    private func displayValue(for dataPoint: ProteinPerBodyWeightData) -> Double {
        usePounds ? dataPoint.perLb : dataPoint.perKg
    }

    // Get last 6 data points with values (like biometrics cards)
    private var last6DataPoints: [ProteinPerBodyWeightData] {
        return viewModel.chartData
            .filter { displayValue(for: $0) > 0 }
            .suffix(6)
            .map { $0 }
    }

    // Most recent value
    private var latestValue: Double? {
        guard let latest = last6DataPoints.last else { return nil }
        return displayValue(for: latest)
    }

    // Most recent date
    private var latestDate: Date? {
        last6DataPoints.last?.date
    }

    private var ratioStatus: (text: String, color: Color) {
        guard let value = latestValue else { return ("No data", .secondary) }

        if value >= optimalRangeLow && value <= optimalRangeHigh {
            return ("Optimal", MetricsUIConfig.tierGood)
        } else if value < optimalRangeLow {
            return ("Below target", MetricsUIConfig.tierMedium)
        } else {
            return ("Above target", MetricsUIConfig.tierMedium)
        }
    }

    /// Smart date display: Today, Yesterday, day name (if this week), or date
    private var formattedDate: String {
        guard let date = latestDate else { return "" }

        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "Today"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        if date >= startOfWeek {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isLoading || unitPrefs.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(height: 60)
            } else if let value = latestValue {
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
                            Text(String(format: "%.2f", value))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Text(unitLabel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack(spacing: 4) {
                            Text(formattedDate)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("·")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(ratioStatus.text)
                                .font(.caption)
                                .foregroundColor(ratioStatus.color)
                        }
                    }

                    Spacer()

                    // Mini sparkline with range band
                    ProteinRatioSparkline(
                        dataPoints: last6DataPoints,
                        color: color,
                        optimalLow: optimalRangeLow,
                        optimalHigh: optimalRangeHigh,
                        displayValue: displayValue
                    )
                    .frame(width: 70, height: 36)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "percent")
                        .font(.system(size: 24))
                        .foregroundColor(color.opacity(0.6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Protein Ratio")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("No data yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(height: 60)
            }
        }
        .task {
            await unitPrefs.loadPreferences()
            await viewModel.loadData(for: .week)
        }
    }
}

// MARK: - Protein Ratio Sparkline (with range band and stroked circles)

private struct ProteinRatioSparkline: View {
    let dataPoints: [ProteinPerBodyWeightData]
    let color: Color
    let optimalLow: Double
    let optimalHigh: Double
    let displayValue: (ProteinPerBodyWeightData) -> Double

    /// Fixed number of slots for consistent spacing
    private let slotCount = 6

    /// Points positioned in fixed slots (right-aligned)
    private var slottedPoints: [SlottedRatioPoint] {
        let points = Array(dataPoints.suffix(slotCount))
        guard !points.isEmpty else { return [] }

        let startSlot = slotCount - points.count
        return points.enumerated().map { index, point in
            SlottedRatioPoint(
                slot: startSlot + index,
                value: displayValue(point),
                isLatest: index == points.count - 1,
                isInRange: displayValue(point) >= optimalLow && displayValue(point) <= optimalHigh
            )
        }
    }

    private var hasData: Bool {
        !dataPoints.isEmpty && dataPoints.contains { displayValue($0) > 0 }
    }

    var body: some View {
        if hasData {
            let values = slottedPoints.map { $0.value }
            let dataMin = values.min() ?? optimalLow
            let dataMax = values.max() ?? optimalHigh
            let yMin = min(dataMin, optimalLow) * 0.85
            let yMax = max(dataMax, optimalHigh) * 1.15

            Chart {
                // Optimal range shading
                RectangleMark(
                    xStart: .value("Start", -0.5),
                    xEnd: .value("End", Double(slotCount) - 0.5),
                    yStart: .value("OptimalLow", optimalLow),
                    yEnd: .value("OptimalHigh", optimalHigh)
                )
                .foregroundStyle(Color.blue.opacity(0.12))

                ForEach(slottedPoints) { point in
                    // Line connecting points
                    LineMark(
                        x: .value("Slot", point.slot),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(Color.secondary.opacity(0.3))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

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
            }
            .chartXScale(domain: 0...slotCount - 1)
            .chartYScale(domain: yMin...yMax)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
        } else {
            EmptyView()
        }
    }
}

/// Point positioned in a fixed slot for protein ratio
private struct SlottedRatioPoint: Identifiable {
    let id = UUID()
    let slot: Int
    let value: Double
    let isLatest: Bool
    let isInRange: Bool
}

#Preview {
    ProteinRatioCard(color: .blue, pillar: "Healthful Nutrition")
        .padding()
}
