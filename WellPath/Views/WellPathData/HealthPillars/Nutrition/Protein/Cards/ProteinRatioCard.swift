//
//  ProteinRatioCard.swift
//  WellPath
//
//  Reusable card for Protein Ratio metric (g/kg or g/lb body weight).
//  Shows weekly average with mini line chart and target range band.
//

import SwiftUI

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

    // Get last 7 days of data for mini chart
    private var last7DaysData: [ProteinPerBodyWeightData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekAgo = calendar.date(byAdding: .day, value: -6, to: today) else {
            return []
        }
        return viewModel.chartData.filter { dataPoint in
            dataPoint.date >= weekAgo && dataPoint.date <= Date()
        }
    }

    // Weekly average in user's preferred unit
    private var weeklyAverage: Double {
        let validData = last7DaysData.filter { displayValue(for: $0) > 0 }
        guard !validData.isEmpty else { return 0 }
        let sum = validData.reduce(0.0) { $0 + displayValue(for: $1) }
        return sum / Double(validData.count)
    }

    private var ratioStatus: (text: String, color: Color) {
        guard weeklyAverage > 0 else { return ("No data", .secondary) }

        if weeklyAverage >= optimalRangeLow && weeklyAverage <= optimalRangeHigh {
            return ("Optimal", MetricsUIConfig.tierGood)
        } else if weeklyAverage < optimalRangeLow {
            return ("Below target", MetricsUIConfig.tierMedium)
        } else {
            return ("Above target", MetricsUIConfig.tierMedium)
        }
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
            } else if weeklyAverage > 0 {
                HStack(spacing: 12) {
                    // Weekly avg on left
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weekly Avg")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.2f", weeklyAverage))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(color)
                            Text(unitLabel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(ratioStatus.text)
                            .font(.caption2)
                            .foregroundColor(ratioStatus.color)
                    }

                    Spacer()

                    // Mini line chart with target range band on right
                    MiniRatioLineChart(
                        data: last7DaysData,
                        color: color,
                        optimalLow: optimalRangeLow,
                        optimalHigh: optimalRangeHigh,
                        displayValue: displayValue
                    )
                    .frame(width: 90, height: 45)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
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

// MARK: - Mini Line Chart with Target Range Band

private struct MiniRatioLineChart: View {
    let data: [ProteinPerBodyWeightData]
    let color: Color
    let optimalLow: Double
    let optimalHigh: Double
    let displayValue: (ProteinPerBodyWeightData) -> Double

    var body: some View {
        GeometryReader { geometry in
            let validData = data.filter { displayValue($0) > 0 }
            let values = validData.map { displayValue($0) }

            // Calculate Y scale to include optimal range
            let dataMin = values.min() ?? optimalLow
            let dataMax = values.max() ?? optimalHigh
            let yMin = min(dataMin, optimalLow) * 0.9
            let yMax = max(dataMax, optimalHigh) * 1.1
            let yRange = yMax - yMin

            ZStack {
                // Target range band (shaded area)
                let bandTop = (1 - (optimalHigh - yMin) / yRange) * geometry.size.height
                let bandBottom = (1 - (optimalLow - yMin) / yRange) * geometry.size.height

                Rectangle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(height: max(0, bandBottom - bandTop))
                    .offset(y: bandTop + (bandBottom - bandTop) / 2 - geometry.size.height / 2)

                // Line connecting data points
                if validData.count >= 2 {
                    Path { path in
                        let sortedData = validData.sorted { $0.date < $1.date }
                        let width = geometry.size.width
                        let height = geometry.size.height

                        for (index, dataPoint) in sortedData.enumerated() {
                            let x = (width / CGFloat(sortedData.count - 1)) * CGFloat(index)
                            let normalizedY = (displayValue(dataPoint) - yMin) / yRange
                            let y = height - (normalizedY * height)

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }

                // Data points
                ForEach(Array(validData.sorted { $0.date < $1.date }.enumerated()), id: \.offset) { index, dataPoint in
                    let sortedData = validData.sorted { $0.date < $1.date }
                    let x = sortedData.count > 1
                        ? (geometry.size.width / CGFloat(sortedData.count - 1)) * CGFloat(index)
                        : geometry.size.width / 2
                    let normalizedY = (displayValue(dataPoint) - yMin) / yRange
                    let y = geometry.size.height - (normalizedY * geometry.size.height)

                    Circle()
                        .fill(color)
                        .frame(width: 4, height: 4)
                        .position(x: x, y: y)
                }
            }
        }
    }
}

#Preview {
    ProteinRatioCard(color: .blue, pillar: "Healthful Nutrition")
        .padding()
}
