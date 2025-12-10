//
//  StackedMeasurementsChart.swift
//  WellPath
//
//  2 charts for Waist-to-Hip:
//  - Top: Hip + Waist on same chart (different colors, connected)
//  - Bottom: Ratio
//  Follows Apple Health Blood Pressure pattern
//

import SwiftUI
import Charts

/// Aggregated data for 6M/Y views - represents a week or month's min/max
struct AggregatedMeasurementRange: Identifiable {
    let id = UUID()
    let periodStart: Date  // Start of week or month
    let waistMin: Double
    let waistMax: Double
    let hipMin: Double
    let hipMax: Double
    let ratioMin: Double
    let ratioMax: Double
}

struct StackedMeasurementsChart: View {
    let color: Color
    @Binding var selectedUnit: HeightDisplayUnit2
    @Binding var selectedPeriod: TimePeriod
    @ObservedObject var scrollManager: MeasurementsChartScrollManager
    var showAbout: Binding<Bool>? = nil

    // Shared scroll position for linked scrolling
    @State private var scrollPosition: Date
    @State private var selectedPointDate: Date?

    // Colors for the two measurement lines
    private let waistColor = Color.cyan
    private let hipColor = Color.cyan.opacity(0.5)

    private var displayUnitString: String {
        selectedUnit == .cm ? "cm" : "in"
    }

    private var selectedPoint: MeasurementDataPoint? {
        guard let selectedDate = selectedPointDate else { return nil }
        // Use granularity matching for all periods (data is now aggregated by period)
        return scrollManager.chartData.first(where: {
            Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: getDateGranularity())
        })
    }

    private var dataPointsWithValues: [MeasurementDataPoint] {
        scrollManager.chartData.filter { $0.waist > 0 && $0.hip > 0 }
    }

    init(color: Color, selectedUnit: Binding<HeightDisplayUnit2>, selectedPeriod: Binding<TimePeriod>, scrollManager: MeasurementsChartScrollManager, showAbout: Binding<Bool>? = nil) {
        self.color = color
        self._selectedUnit = selectedUnit
        self._selectedPeriod = selectedPeriod
        self.scrollManager = scrollManager
        self.showAbout = showAbout

        let now = Date()
        let initialPeriod = selectedPeriod.wrappedValue
        let visibleDuration = initialPeriod.numberOfBars
        let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
        let scrollStart = Calendar.current.date(
            byAdding: initialPeriod.calendarComponent,
            value: -offsetFromEnd,
            to: now
        ) ?? now

        _scrollPosition = State(initialValue: scrollStart)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Row 1: Period picker (D/W/M/6M/Y)
            Picker("Period", selection: $selectedPeriod) {
                ForEach(TimePeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 16)

            // Row 2: Unit picker (right-aligned)
            HStack {
                Spacer()
                Picker("Unit", selection: $selectedUnit) {
                    Text("in").tag(HeightDisplayUnit2.ftIn)
                    Text("cm").tag(HeightDisplayUnit2.cm)
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
            }
            .padding(.horizontal)
            .padding(.top, 12)

            // Row 3: WAIST/HIP labels, AVG label, values | info button
            HStack(alignment: .top, spacing: 12) {
                // Left side: Labels, AVG, and values stacked vertically
                VStack(alignment: .leading, spacing: 4) {
                    // Row 1: WAIST and HIP labels with dots
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Circle().fill(waistColor).frame(width: 8, height: 8)
                            Text("WAIST")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2).fill(hipColor).frame(width: 8, height: 8)
                            Text("HIP")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Row 2: AVG label (only when no selection)
                    if selectedPoint == nil {
                        Text("AVG")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Row 3: Values
                    HStack(spacing: 16) {
                        if let point = selectedPoint {
                            Text(String(format: "%.0f", convertValue(point.waist)))
                                .font(.system(size: 28, weight: .regular))
                            Text(String(format: "%.0f", convertValue(point.hip)))
                                .font(.system(size: 28, weight: .regular))
                        } else {
                            Text(waistRangeString)
                                .font(.system(size: 28, weight: .regular))
                            Text(hipRangeString)
                                .font(.system(size: 28, weight: .regular))
                        }
                    }
                }

                Spacer()

                // Right side: Info button (top-aligned with labels)
                if let showAboutBinding = showAbout {
                    Button(action: {
                        withAnimation { showAboutBinding.wrappedValue = true }
                    }) {
                        Image(systemName: "info.circle")
                            .font(.title3)
                            .foregroundColor(color)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Row 4: Date range
            Text(selectedPoint != nil ? formatSelectedDate(selectedPoint!.date) : visibleDateRangeString())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 4)

            // Row 5: Waist/Hip chart
            measurementsChart
                .padding(.top, 16)

            // Row 6 & 7: Ratio label + value + chart
            ratioChart
                .padding(.top, 24)
                .padding(.bottom, 80)  // Extra padding to avoid tab bar cutoff
        }
        .background(Color(uiColor: .systemBackground))
        .onChange(of: selectedPeriod) { _, newPeriod in
            scrollManager.updatePeriod(newPeriod)
            selectedPointDate = nil

            let now = Date()
            let visibleDuration = newPeriod.numberOfBars
            let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
            scrollPosition = Calendar.current.date(
                byAdding: newPeriod.calendarComponent,
                value: -offsetFromEnd,
                to: now
            ) ?? now
        }
    }

    // MARK: - Measurements Chart (Hip + Waist)

    private var measurementsChart: some View {
        Chart {
            // Waist series - separate from Hip
            ForEach(scrollManager.chartData.filter { $0.waist > 0 && $0.hip > 0 }) { dataPoint in
                let waistVal = convertValue(dataPoint.waist)
                let isSelected = selectedPointDate != nil &&
                    Calendar.current.isDate(dataPoint.date, equalTo: selectedPointDate!, toGranularity: getDateGranularity())

                LineMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Value", waistVal),
                    series: .value("Type", "Waist")
                )
                .foregroundStyle(waistColor)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))

                PointMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Value", waistVal)
                )
                .foregroundStyle(waistColor)
                .symbolSize(isSelected ? 150 : 60)
                .symbol(.circle)
            }

            // Hip series - separate from Waist
            ForEach(scrollManager.chartData.filter { $0.waist > 0 && $0.hip > 0 }) { dataPoint in
                let hipVal = convertValue(dataPoint.hip)
                let isSelected = selectedPointDate != nil &&
                    Calendar.current.isDate(dataPoint.date, equalTo: selectedPointDate!, toGranularity: getDateGranularity())

                LineMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Value", hipVal),
                    series: .value("Type", "Hip")
                )
                .foregroundStyle(hipColor)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))

                PointMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Value", hipVal)
                )
                .foregroundStyle(hipColor)
                .symbolSize(isSelected ? 150 : 60)
                .symbol(.square)

                // Connecting line between hip and waist - ONLY when selected
                if isSelected {
                    let waistVal = convertValue(dataPoint.waist)
                    RuleMark(
                        x: .value("Date", dataPoint.date),
                        yStart: .value("Hip", hipVal),
                        yEnd: .value("Waist", waistVal)
                    )
                    .foregroundStyle(Color.secondary.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                }
            }
        }
        .chartYScale(domain: measurementsYDomain)
        .chartXScale(domain: chartXDomain)
        .frame(height: 200)
        .chartScrollableAxes(.horizontal)
        .chartScrollPosition(x: $scrollPosition)
        .chartXVisibleDomain(length: getVisibleDomainTimeInterval())
        .chartGesture { proxy in
            SpatialTapGesture()
                .onEnded { tapValue in
                    handleTap(at: tapValue.location.x, using: proxy)
                }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: getAxisLabelStride(), count: getAxisLabelMultiplier())) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(Color.secondary.opacity(0.3))
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { axisValue in
                AxisValueLabel {
                    if let numValue = axisValue.as(Double.self) {
                        Text(String(format: "%.0f", numValue))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(Color.secondary.opacity(0.3))
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Ratio Chart

    private var ratioChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Ratio label and value (value below label)
            VStack(alignment: .leading, spacing: 2) {
                // AVG label when no selection
                if selectedPoint == nil {
                    Text("AVG")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 8))
                        .foregroundColor(color.opacity(0.6))
                    Text("RATIO")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let point = selectedPoint, point.waist > 0, point.hip > 0 {
                    // Selected point ratio (aggregated for the period)
                    let ratio = point.waist / point.hip
                    Text(String(format: "%.2f", ratio))
                        .font(.system(size: 28, weight: .regular))
                } else {
                    // Average ratio across visible range
                    Text(ratioRangeString)
                        .font(.system(size: 28, weight: .regular))
                }
            }
            .padding(.horizontal)

            Chart {
                // All periods use aggregated data from scrollManager
                // D: hourly avg, W/M: daily avg, 6M: weekly avg, Y: monthly avg
                ForEach(scrollManager.chartData) { dataPoint in
                    // Invisible placeholder to maintain x-axis even with sparse data
                    PointMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Value", 0)
                    )
                    .opacity(0)

                    if dataPoint.waist > 0 && dataPoint.hip > 0 {
                        let ratio = dataPoint.waist / dataPoint.hip
                        let isSelected = selectedPointDate != nil &&
                            Calendar.current.isDate(dataPoint.date, equalTo: selectedPointDate!, toGranularity: getDateGranularity())

                        // Trend line connecting ratio points
                        LineMark(
                            x: .value("Date", dataPoint.date),
                            y: .value("Ratio", ratio)
                        )
                        .foregroundStyle(color.opacity(0.6))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        // Diamond point for each ratio value
                        PointMark(
                            x: .value("Date", dataPoint.date),
                            y: .value("Ratio", ratio)
                        )
                        .foregroundStyle(color.opacity(0.6))
                        .symbolSize(isSelected ? 150 : 60)
                        .symbol(.diamond)
                    }
                }
            }
            .chartYScale(domain: ratioYDomain)
            .chartXScale(domain: chartXDomain)
            .frame(height: 120)
            .chartScrollableAxes(.horizontal)
            .chartScrollPosition(x: $scrollPosition)
            .chartXVisibleDomain(length: getVisibleDomainTimeInterval())
            .chartGesture { proxy in
                SpatialTapGesture()
                    .onEnded { tapValue in
                        handleTap(at: tapValue.location.x, using: proxy)
                    }
            }
            .onChange(of: scrollPosition) { _, newValue in
                handleChartScrolling(position: newValue)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: getAxisLabelStride(), count: getAxisLabelMultiplier())) { axisValue in
                    if axisValue.as(Date.self) != nil {
                        AxisValueLabel(format: getAxisLabelFormat())
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                            .foregroundStyle(Color.secondary.opacity(0.3))
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: ratioYAxisValues) { axisValue in
                    AxisValueLabel {
                        if let numValue = axisValue.as(Double.self) {
                            Text(String(format: "%.1f", numValue))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(Color.secondary.opacity(0.3))
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Computed Properties

    private var waistRangeString: String {
        let visibleData = getVisibleDataPoints()
        let values = visibleData.compactMap { $0.waist > 0 ? convertValue($0.waist) : nil }
        guard !values.isEmpty else { return "--" }

        // Always show average for clean display (biometric data is typically sparse)
        let avg = values.reduce(0, +) / Double(values.count)
        return String(format: "%.0f", avg)
    }

    private var hipRangeString: String {
        let visibleData = getVisibleDataPoints()
        let values = visibleData.compactMap { $0.hip > 0 ? convertValue($0.hip) : nil }
        guard !values.isEmpty else { return "--" }

        // Always show average for clean display (biometric data is typically sparse)
        let avg = values.reduce(0, +) / Double(values.count)
        return String(format: "%.0f", avg)
    }

    private var ratioRangeString: String {
        let visibleData = getVisibleDataPoints()
        let values = visibleData.compactMap { point -> Double? in
            guard point.waist > 0 && point.hip > 0 else { return nil }
            return point.waist / point.hip
        }
        guard !values.isEmpty else { return "--" }

        // Always show average for clean display
        let avg = values.reduce(0, +) / Double(values.count)
        return String(format: "%.2f", avg)
    }

    private func getVisibleDataPoints() -> [MeasurementDataPoint] {
        let calendar = Calendar.current
        let visibleDuration = selectedPeriod.numberOfBars
        let endDate = calendar.date(byAdding: selectedPeriod.calendarComponent, value: visibleDuration, to: scrollPosition) ?? scrollPosition

        return scrollManager.chartData.filter { dataPoint in
            dataPoint.date >= scrollPosition && dataPoint.date <= endDate
        }
    }

    /// X-axis domain spanning the full visible time range (not just where data exists)
    private var chartXDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let now = Date()

        // Calculate the full range for the selected period
        let start: Date
        let end: Date

        switch selectedPeriod {
        case .day:
            start = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            end = now
        case .week:
            start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            end = now
        case .month:
            start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            end = now
        case .sixMonth:
            start = calendar.date(byAdding: .month, value: -6, to: now) ?? now
            end = now
        case .year:
            start = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            end = now
        }

        return start...end
    }

    private var measurementsYDomain: ClosedRange<Double> {
        let waistValues = scrollManager.chartData.map { convertValue($0.waist) }.filter { $0 > 0 }
        let hipValues = scrollManager.chartData.map { convertValue($0.hip) }.filter { $0 > 0 }
        let allValues = waistValues + hipValues

        guard !allValues.isEmpty else { return selectedUnit == .cm ? 60...120 : 24...48 }

        let minVal = allValues.min() ?? 60
        let maxVal = allValues.max() ?? 120
        let range = maxVal - minVal
        let padding = max(range * 0.15, 5)

        return max(0, minVal - padding)...(maxVal + padding)
    }

    private var ratioYDomain: ClosedRange<Double> {
        let values = dataPointsWithValues.map { $0.waist / $0.hip }
        guard !values.isEmpty else { return 0.6...1.2 }

        let minVal = values.min() ?? 0.6
        let maxVal = values.max() ?? 1.2
        let range = maxVal - minVal
        // Ensure minimum range of 0.2 to prevent Y-axis from disappearing with single data point
        let padding = max(range * 0.2, 0.1)

        return max(0.4, minVal - padding)...min(1.4, maxVal + padding)
    }

    /// Explicit Y-axis values for ratio chart - ensures axis always shows
    private var ratioYAxisValues: [Double] {
        let domain = ratioYDomain
        let min = domain.lowerBound
        let max = domain.upperBound
        let range = max - min

        // Generate 4-5 evenly spaced values
        let step = range / 4
        var values: [Double] = []
        var current = min
        while current <= max + 0.001 {  // Small epsilon for floating point
            values.append(current)
            current += step
        }
        return values
    }

    // MARK: - Helper Functions

    private func convertValue(_ cm: Double) -> Double {
        switch selectedUnit {
        case .cm: return cm
        case .ftIn: return cm / 2.54
        }
    }

    /// Aggregate data points into weekly (6M) or monthly (Y) ranges
    private var aggregatedRanges: [AggregatedMeasurementRange] {
        let calendar = Calendar.current
        let groupComponent: Calendar.Component = selectedPeriod == .sixMonth ? .weekOfYear : .month

        // Group data points by week or month
        var grouped: [Date: [MeasurementDataPoint]] = [:]

        for point in scrollManager.chartData where point.waist > 0 && point.hip > 0 {
            let periodStart: Date
            if selectedPeriod == .sixMonth {
                // Start of week
                periodStart = calendar.dateInterval(of: .weekOfYear, for: point.date)?.start ?? point.date
            } else {
                // Start of month
                periodStart = calendar.dateInterval(of: .month, for: point.date)?.start ?? point.date
            }
            grouped[periodStart, default: []].append(point)
        }

        // Convert to aggregated ranges
        return grouped.map { (periodStart, points) in
            let waistValues = points.map { $0.waist }
            let hipValues = points.map { $0.hip }
            let ratioValues = points.map { $0.waist / $0.hip }

            return AggregatedMeasurementRange(
                periodStart: periodStart,
                waistMin: waistValues.min() ?? 0,
                waistMax: waistValues.max() ?? 0,
                hipMin: hipValues.min() ?? 0,
                hipMax: hipValues.max() ?? 0,
                ratioMin: ratioValues.min() ?? 0,
                ratioMax: ratioValues.max() ?? 0
            )
        }.sorted { $0.periodStart < $1.periodStart }
    }

    /// Get the aggregated range for the selected week/month (used for showing selected values)
    private var selectedAggregatedRange: AggregatedMeasurementRange? {
        guard let selectedDate = selectedPointDate else { return nil }
        let calendar = Calendar.current

        return aggregatedRanges.first { range in
            if selectedPeriod == .sixMonth {
                return calendar.isDate(range.periodStart, equalTo: selectedDate, toGranularity: .weekOfYear)
            } else {
                return calendar.isDate(range.periodStart, equalTo: selectedDate, toGranularity: .month)
            }
        }
    }

    private func handleTap(at x: CGFloat, using proxy: ChartProxy) {
        if let tappedDate: Date = proxy.value(atX: x) {
            // Find closest data point (works for all periods since data is now aggregated)
            let closest = scrollManager.chartData
                .filter { $0.waist > 0 && $0.hip > 0 }
                .min(by: {
                    abs($0.date.timeIntervalSince(tappedDate)) < abs($1.date.timeIntervalSince(tappedDate))
                })

            // Toggle selection using granularity matching
            if let closestDate = closest?.date,
               let currentSelection = selectedPointDate,
               Calendar.current.isDate(currentSelection, equalTo: closestDate, toGranularity: getDateGranularity()) {
                selectedPointDate = nil
            } else {
                selectedPointDate = closest?.date
            }
        }
    }

    private func handleChartScrolling(position: Date) {
        guard !scrollManager.chartData.isEmpty else { return }

        let calendar = Calendar.current
        let component = selectedPeriod.calendarComponent

        if let oldestDate = scrollManager.chartData.last?.date {
            let diff = calendar.dateComponents([component], from: oldestDate, to: position)
            let units = abs(diff.value(for: component) ?? 0)

            if units < 5 && !scrollManager.isLoadingOlder {
                scrollManager.loadOlderData()
            }
        }
    }

    private func visibleDateRangeString() -> String {
        let calendar = Calendar.current
        let visibleDuration = selectedPeriod.numberOfBars
        let endDate = calendar.date(byAdding: selectedPeriod.calendarComponent, value: visibleDuration - 1, to: scrollPosition) ?? scrollPosition

        let formatter = DateFormatter()
        formatter.dateFormat = selectedPeriod == .year ? "MMM yyyy" : "MMM d, yyyy"

        return "\(formatter.string(from: scrollPosition))–\(formatter.string(from: endDate))"
    }

    private func formatSelectedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        switch selectedPeriod {
        case .day:
            // D: "Dec 3, 7 PM" (hour)
            formatter.dateFormat = "MMM d, h a"
            return formatter.string(from: date)
        case .week, .month:
            // W/M: "Dec 3, 2025" (day)
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        case .sixMonth:
            // 6M: "Dec 1–7, 2025" (week range Mon-Sun)
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? date
            formatter.dateFormat = "MMM d"
            let startStr = formatter.string(from: weekStart)
            formatter.dateFormat = "d, yyyy"
            let endStr = formatter.string(from: weekEnd)
            return "\(startStr)–\(endStr)"
        case .year:
            // Y: "Dec 2025" (month)
            formatter.dateFormat = "MMM yyyy"
            return formatter.string(from: date)
        }
    }

    private func getDateGranularity() -> Calendar.Component {
        switch selectedPeriod {
        case .day: return .hour
        case .week, .month: return .day
        case .sixMonth: return .weekOfYear
        case .year: return .month
        }
    }

    private func getVisibleDomainTimeInterval() -> TimeInterval {
        switch selectedPeriod {
        case .day: return 24 * 3600
        case .week: return 7 * 24 * 3600
        case .month: return 30 * 24 * 3600
        case .sixMonth: return 26 * 7 * 24 * 3600
        case .year: return 365 * 24 * 3600
        }
    }

    private func getAxisLabelStride() -> Calendar.Component {
        switch selectedPeriod {
        case .day: return .hour
        case .week: return .day
        case .month: return .weekOfYear
        case .sixMonth, .year: return .month
        }
    }

    private func getAxisLabelMultiplier() -> Int {
        switch selectedPeriod {
        case .day: return 6
        default: return 1
        }
    }

    private func getAxisLabelFormat() -> Date.FormatStyle {
        switch selectedPeriod {
        case .day: return .dateTime.hour(.defaultDigits(amPM: .abbreviated))
        case .week: return .dateTime.weekday(.abbreviated)
        case .month: return .dateTime.day(.defaultDigits)
        case .sixMonth: return .dateTime.month(.abbreviated)
        case .year: return .dateTime.month(.narrow)
        }
    }
}

#Preview {
    StackedMeasurementsChart(
        color: .cyan,
        selectedUnit: .constant(.ftIn),
        selectedPeriod: .constant(.week),
        scrollManager: MeasurementsChartScrollManager(period: .week)
    )
    .background(Color.black)
}
