//
//  WaistHipRatioChart.swift
//  WellPath
//
//  Line chart showing waist-to-hip ratio over time
//  Synchronized with BodyMeasurementsRangeChart via shared scroll position
//

import SwiftUI
import Charts

struct WaistHipRatioChart: View {
    let color: Color
    let selectedUnit: HeightDisplayUnit2  // To convert waist/hip for display
    @Binding var scrollPosition: Date
    @Binding var selectedPeriod: TimePeriod
    @Binding var selectedPointDate: Date?  // Shared with measurements chart
    @ObservedObject var scrollManager: MeasurementsChartScrollManager

    private var selectedPoint: MeasurementDataPoint? {
        guard let selectedDate = selectedPointDate else { return nil }
        return scrollManager.chartData.first(where: {
            Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: getDateGranularity())
        })
    }

    private func calculateRatio(_ point: MeasurementDataPoint) -> Double? {
        guard point.waist > 0 && point.hip > 0 else { return nil }
        return point.waist / point.hip
    }

    private func convertValue(_ cm: Double) -> Double {
        switch selectedUnit {
        case .cm: return cm
        case .ftIn: return cm / 2.54
        }
    }

    private var displayUnitString: String {
        selectedUnit == .cm ? "cm" : "in"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Ratio")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)

            // Value display - shows all 3 values (waist, hip, ratio)
            HStack(alignment: .top, spacing: 16) {
                if let selected = selectedPoint, let ratio = calculateRatio(selected) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WAIST")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.1f", convertValue(selected.waist)))
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(displayUnitString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("HIP")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.1f", convertValue(selected.hip)))
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(displayUnitString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("RATIO")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.2f", ratio))
                                .font(.title2)
                                .fontWeight(.bold)
                            let (classification, statusColor) = classifyWHR(ratio)
                            Circle()
                                .fill(statusColor)
                                .frame(width: 8, height: 8)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text(formatSelectedDate(selected.date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if let latest = getLatestReading() {
                    let ratio = latest.waist / latest.hip

                    VStack(alignment: .leading, spacing: 4) {
                        Text("LATEST")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 12) {
                            VStack(alignment: .leading) {
                                Text("Waist")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                HStack(alignment: .firstTextBaseline, spacing: 1) {
                                    Text(String(format: "%.1f", convertValue(latest.waist)))
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Text(displayUnitString)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            VStack(alignment: .leading) {
                                Text("Hip")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                HStack(alignment: .firstTextBaseline, spacing: 1) {
                                    Text(String(format: "%.1f", convertValue(latest.hip)))
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Text(displayUnitString)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            VStack(alignment: .leading) {
                                Text("Ratio")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text(String(format: "%.2f", ratio))
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    let (_, statusColor) = classifyWHR(ratio)
                                    Circle()
                                        .fill(statusColor)
                                        .frame(width: 6, height: 6)
                                }
                            }
                        }
                    }
                    Spacer()
                } else {
                    Text("No data")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 8)

            // Chart
            Chart(scrollManager.chartData) { dataPoint in
                // Invisible placeholder for timeline
                PointMark(
                    x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
                    y: .value("Value", 0)
                )
                .opacity(0)

                if dataPoint.waist > 0 && dataPoint.hip > 0 {
                    let ratio = dataPoint.waist / dataPoint.hip

                    // Ratio line
                    LineMark(
                        x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
                        y: .value("Ratio", ratio)
                    )
                    .foregroundStyle(color.opacity(0.7))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    // Points
                    if let selectedDate = selectedPointDate,
                       Calendar.current.isDate(dataPoint.date, equalTo: selectedDate, toGranularity: getDateGranularity()) {
                        PointMark(
                            x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
                            y: .value("Ratio", ratio)
                        )
                        .foregroundStyle(color)
                        .symbolSize(100)
                    } else {
                        PointMark(
                            x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
                            y: .value("Ratio", ratio)
                        )
                        .foregroundStyle(color.opacity(0.7))
                        .symbolSize(40)
                    }
                }
            }
            .chartYScale(domain: yAxisDomain)
            .frame(height: 150)
            .chartScrollableAxes(.horizontal)
            .chartScrollPosition(x: $scrollPosition)
            .chartXVisibleDomain(length: getVisibleDomainTimeInterval())
            .chartGesture { proxy in
                SpatialTapGesture()
                    .onEnded { value in
                        if let tappedDate: Date = proxy.value(atX: value.location.x) {
                            let closest = scrollManager.chartData
                                .filter { $0.waist > 0 && $0.hip > 0 }
                                .min(by: {
                                    abs($0.date.timeIntervalSince(tappedDate)) < abs($1.date.timeIntervalSince(tappedDate))
                                })

                            if let closestDate = closest?.date,
                               Calendar.current.isDate(selectedPointDate ?? Date.distantPast, equalTo: closestDate, toGranularity: getDateGranularity()) {
                                selectedPointDate = nil
                            } else {
                                selectedPointDate = closest?.date
                            }
                        }
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: getAxisLabelStride(), count: getAxisLabelMultiplier())) { value in
                    if value.as(Date.self) != nil {
                        AxisValueLabel(format: getAxisLabelFormat())
                        AxisGridLine()
                        AxisTick()
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let numValue = value.as(Double.self) {
                            Text(String(format: "%.2f", numValue))
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(Color.secondary.opacity(0.2))
                }
            }
            .chartPlotStyle { plotArea in
                plotArea.frame(height: 150)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Computed Properties

    private var yAxisDomain: ClosedRange<Double> {
        let ratios = scrollManager.chartData
            .filter { $0.waist > 0 && $0.hip > 0 }
            .map { $0.waist / $0.hip }

        guard !ratios.isEmpty else {
            return 0.6...1.2
        }

        let minVal = ratios.min() ?? 0.7
        let maxVal = ratios.max() ?? 1.0
        let padding = (maxVal - minVal) * 0.2

        return max(0.5, minVal - padding)...min(1.5, maxVal + padding)
    }

    // MARK: - Helper Functions

    private func getLatestReading() -> MeasurementDataPoint? {
        scrollManager.chartData
            .filter { $0.waist > 0 && $0.hip > 0 }
            .sorted { $0.date > $1.date }
            .first
    }

    private func classifyWHR(_ value: Double) -> (String, Color) {
        if value < 0.80 {
            return ("Low Risk", .green)
        } else if value < 0.90 {
            return ("Moderate Risk", .yellow)
        } else if value < 1.0 {
            return ("High Risk", .orange)
        } else {
            return ("Very High Risk", .red)
        }
    }

    private func formatSelectedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch selectedPeriod {
        case .hour:
            formatter.dateFormat = "h:mm a"
        case .day:
            formatter.dateFormat = "MMM d, h:mm a"
        case .week:
            formatter.dateFormat = "E, MMM d"
        case .month, .sixMonth, .year:
            formatter.dateFormat = "MMM d, yyyy"
        }
        return formatter.string(from: date)
    }

    private func getDateGranularity() -> Calendar.Component {
        switch selectedPeriod {
        case .hour: return .minute
        case .day: return .hour
        case .week, .month: return .day
        case .sixMonth: return .weekOfYear
        case .year: return .month
        }
    }

    private func getVisibleDomainTimeInterval() -> TimeInterval {
        switch selectedPeriod {
        case .hour: return 3600
        case .day: return 24 * 3600
        case .week: return 7 * 24 * 3600
        case .month: return 30 * 24 * 3600
        case .sixMonth: return 26 * 7 * 24 * 3600
        case .year: return 365 * 24 * 3600
        }
    }

    private func getAxisLabelStride() -> Calendar.Component {
        switch selectedPeriod {
        case .hour: return .minute
        case .day: return .hour
        case .week: return .day
        case .month: return .weekOfYear
        case .sixMonth, .year: return .month
        }
    }

    private func getAxisLabelMultiplier() -> Int {
        switch selectedPeriod {
        case .hour: return 10
        case .day: return 6
        default: return 1
        }
    }

    private func getAxisLabelFormat() -> Date.FormatStyle {
        switch selectedPeriod {
        case .hour: return .dateTime.minute()
        case .day: return .dateTime.hour(.defaultDigits(amPM: .abbreviated))
        case .week: return .dateTime.weekday(.narrow)
        case .month: return .dateTime.day(.defaultDigits)
        case .sixMonth: return .dateTime.month(.abbreviated)
        case .year: return .dateTime.month(.narrow)
        }
    }
}
