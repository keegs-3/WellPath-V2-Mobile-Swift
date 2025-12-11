//
//  BiomarkerRangeSelectorModal.swift
//  WellPath
//
//  Modal view for biomarker ranges with chart visualization
//  Same chart as main view, with range filtering/highlighting
//

import SwiftUI
import Charts

struct BiomarkerRangeSelectorModal: View {
    let biomarkerName: String
    let unit: String
    let rangeInfo: BiomarkerRangeInfo
    let quantityType: String  // For scroll manager
    let sectionColor: Color
    @Binding var isPresented: Bool

    @State private var selectedPeriod: BiomarkerTimePeriod = .month
    @State private var selectedDate: Date?
    @State private var selectedRangeFilter: RangeFilter? = nil
    @State private var scrollPosition: Date = Date()
    @State private var cachedDataMin: Double?
    @State private var cachedDataMax: Double?
    @State private var isFilterChanging: Bool = false

    // Scroll manager for infinite scroll
    @StateObject private var scrollManager: BiomarkerChartScrollManager

    init(
        biomarkerName: String,
        unit: String,
        rangeInfo: BiomarkerRangeInfo,
        quantityType: String,
        sectionColor: Color,
        isPresented: Binding<Bool>
    ) {
        self.biomarkerName = biomarkerName
        self.unit = unit
        self.rangeInfo = rangeInfo
        self.quantityType = quantityType
        self.sectionColor = sectionColor
        self._isPresented = isPresented
        self._scrollManager = StateObject(wrappedValue: BiomarkerChartScrollManager(
            period: .month,
            quantityType: quantityType
        ))
    }

    /// Simplified range filter categories - only 3 options
    enum RangeFilter: String, CaseIterable, Identifiable {
        case optimal = "Optimal"
        case inRange = "In-Range"
        case outOfRange = "Out of Range"

        var id: String { rawValue }

        var color: Color {
            switch self {
            case .optimal: return .green
            case .inRange: return .yellow
            case .outOfRange: return .red
            }
        }
    }

    /// All biomarkers show the same 3 filters
    private var availableFilters: [RangeFilter] {
        [.optimal, .inRange, .outOfRange]
    }

    /// Chart data points with values
    private var chartPointsWithData: [BiomarkerChartPoint] {
        scrollManager.dataPointsWithValues
    }

    /// Count values in each range category
    private var rangeCounts: [RangeFilter: Int] {
        var counts: [RangeFilter: Int] = [.optimal: 0, .inRange: 0, .outOfRange: 0]
        for point in chartPointsWithData {
            let filter = getFilterCategory(for: point.value)
            counts[filter, default: 0] += 1
        }
        return counts
    }

    /// Ranges that match the currently selected filter
    private var matchingRanges: [BiomarkerRangeDetail] {
        guard let filter = selectedRangeFilter else { return [] }
        return rangeInfo.ranges.filter { matchesFilter(range: $0, filter: filter) }
    }

    /// Range boundaries for the currently selected filter (value and color for RuleMark lines)
    private var currentRangeBoundaries: [(value: Double, color: Color)] {
        guard let filter = selectedRangeFilter else { return [] }
        var boundaries: [(value: Double, color: Color)] = []

        // Get boundaries from matching ranges
        for range in matchingRanges {
            if let low = range.rangeLow, low > 0 {
                if !boundaries.contains(where: { abs($0.value - low) < 0.01 }) {
                    boundaries.append((value: low, color: filter.color))
                }
            }
            if let high = range.rangeHigh {
                if !boundaries.contains(where: { abs($0.value - high) < 0.01 }) {
                    boundaries.append((value: high, color: filter.color))
                }
            }
        }
        return boundaries.sorted { $0.value < $1.value }
    }

    /// All unique boundary values from all ranges (for stable chart structure)
    private func getAllBoundaryValues() -> [Double] {
        var allBoundaries: Set<Double> = []
        for range in rangeInfo.ranges {
            if let low = range.rangeLow, low > 0 {
                allBoundaries.insert(low)
            }
            if let high = range.rangeHigh {
                allBoundaries.insert(high)
            }
        }
        return Array(allBoundaries).sorted()
    }

    /// Get the start and end dates for the selected period
    private func getPeriodDateRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch selectedPeriod {
        case .week:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (start, now)
        case .month:
            let start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return (start, now)
        case .sixMonth:
            let start = calendar.date(byAdding: .month, value: -6, to: now) ?? now
            return (start, now)
        case .year:
            let start = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            return (start, now)
        case .fiveYear:
            let start = calendar.date(byAdding: .year, value: -5, to: now) ?? now
            return (start, now)
        }
    }

    /// Format the period date range as a string
    private func periodDateRangeString() -> String {
        let (start, end) = getPeriodDateRange()
        let formatter = DateFormatter()

        switch selectedPeriod {
        case .week, .month:
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        case .sixMonth, .year:
            formatter.dateFormat = "MMM yyyy"
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        case .fiveYear:
            formatter.dateFormat = "yyyy"
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Chart area with visual delineation
                    VStack(spacing: 0) {
                        // Period picker (same as main view)
                        periodPicker

                        // Value display
                        valueDisplay
                            .padding(.horizontal)
                            .padding(.top, 12)

                        // Chart (same as main view)
                        if !chartPointsWithData.isEmpty {
                            biomarkerChart
                                .padding(.top, 16)
                                .padding(.bottom, 16)
                        } else {
                            emptyChartPlaceholder
                                .padding(.top, 16)
                                .padding(.bottom, 16)
                        }
                    }
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Range filter buttons
                    rangeFilterList
                        .padding(.top, 16)
                        .padding(.horizontal)

                    Spacer(minLength: 40)
                }
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle(biomarkerName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            scrollPosition = calculateScrollPosition()
            // Cache data bounds so they're available even during state changes
            updateCachedDataBounds()
        }
        .onChange(of: scrollManager.isLoading) { _, isLoading in
            // Update cached bounds when data finishes loading
            if !isLoading {
                updateCachedDataBounds()
                // Recalculate scroll position when data first loads
                if !scrollManager.dataPointsWithValues.isEmpty {
                    scrollPosition = calculateScrollPosition()
                }
            }
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(BiomarkerTimePeriod.allCases) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.top, 16)
        .onChange(of: selectedPeriod) { _, newPeriod in
            selectedDate = nil  // Clear selection when period changes
            scrollManager.updatePeriod(newPeriod)
            scrollPosition = calculateScrollPosition()
        }
    }

    // MARK: - Value Display

    private var valueDisplay: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 2) {
                // Calculate display value: selected point value or average of visible data
                let displayValue: Double? = {
                    if let date = selectedDate {
                        return chartPointsWithData.first { Calendar.current.isDate($0.date, equalTo: date, toGranularity: getDateGranularity()) }?.value
                    }
                    // Calculate average of visible values
                    let visiblePoints = getVisibleDataPoints()
                    let values = visiblePoints.map { $0.value }
                    guard !values.isEmpty else { return nil }
                    return values.reduce(0, +) / Double(values.count)
                }()

                Text(selectedDate != nil ? "Value" : "AVG")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    if let value = displayValue {
                        Text(formatDisplayValue(value))
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(sectionColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    } else {
                        Text("--")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.secondary)
                    }

                    Text(unit)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Show selected date or visible range
                if let selectedDate = selectedDate {
                    Text(formatSelectedDate(selectedDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(visibleDateRangeString())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Chart (Same as main view)

    /// Calendar component for current period
    private var chartCalendarComponent: Calendar.Component {
        switch selectedPeriod {
        case .week: return .day
        case .month: return .day
        case .sixMonth: return .weekOfYear
        case .year: return .month
        case .fiveYear: return .quarter  // Quarterly buckets for 5Y view
        }
    }

    @ViewBuilder
    private var biomarkerChart: some View {
        let chartPoints = scrollManager.chartData
        let pointsWithData = chartPointsWithData
        let yDomain = calculateYDomain()
        let calComponent = chartCalendarComponent

        // Calculate bounded X domain for range shading (static, based on data bounds)
        let now = Date()
        let calendar = Calendar.current
        let oldestData = chartPoints.last?.date ?? calendar.date(byAdding: .year, value: -5, to: now)!
        let newestData = chartPoints.first?.date ?? now
        let xStart = calendar.date(byAdding: .month, value: -1, to: oldestData)!
        let xEnd = calendar.date(byAdding: .month, value: 1, to: newestData)!

        // Apple Health style: only draw lines if multiple points are visible in the current scroll window
        let visibleDuration = getVisibleDomainTimeInterval()
        let windowEnd = scrollPosition.addingTimeInterval(visibleDuration)
        let visiblePointsCount = pointsWithData.filter { point in
            point.date >= scrollPosition && point.date <= windowEnd
        }.count
        let shouldDrawLines = visiblePointsCount > 1

        Chart {
            // Invisible placeholder for all points to establish x-axis domain
            // Use unit: parameter to match BiometricLineChart pattern
            ForEach(chartPoints) { point in
                PointMark(
                    x: .value("Date", point.date, unit: calComponent),
                    y: .value("Value", 0)
                )
                .opacity(0)
            }

            // Range zone shading - ALWAYS render all ranges to prevent chart relayout
            // Control visibility via opacity (0 when not matching filter, 0.15 when matching)
            ForEach(rangeInfo.ranges, id: \.id) { range in
                let rangeLow = range.rangeLow ?? rangeInfo.realisticLow ?? yDomain.lowerBound
                let rangeHigh = range.rangeHigh ?? rangeInfo.realisticHigh ?? yDomain.upperBound

                // Determine if this range matches the selected filter
                let isMatchingFilter: Bool = {
                    guard let filter = selectedRangeFilter else { return false }
                    return matchesFilter(range: range, filter: filter)
                }()
                let filterColor = selectedRangeFilter?.color ?? .green
                let shadeOpacity: Double = isMatchingFilter ? 0.15 : 0

                RectangleMark(
                    xStart: .value("Start", xStart),
                    xEnd: .value("End", xEnd),
                    yStart: .value("Low", rangeLow),
                    yEnd: .value("High", rangeHigh)
                )
                .foregroundStyle(filterColor.opacity(shadeOpacity))
            }

            // Range boundary lines (dotted) - ALWAYS render all possible boundaries
            // Control visibility via opacity
            ForEach(getAllBoundaryValues(), id: \.self) { boundaryValue in
                let isVisibleBoundary = currentRangeBoundaries.contains(where: { abs($0.value - boundaryValue) < 0.01 })
                let boundaryColor = currentRangeBoundaries.first(where: { abs($0.value - boundaryValue) < 0.01 })?.color ?? .gray

                RuleMark(y: .value("Boundary", boundaryValue))
                    .foregroundStyle(boundaryColor.opacity(isVisibleBoundary ? 0.6 : 0))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }

            // Line and point marks - only for points with data
            ForEach(pointsWithData) { point in
                let pointFilter = getFilterCategory(for: point.value)
                let isInSelectedRange = selectedRangeFilter == nil || pointFilter == selectedRangeFilter
                let lineOpacity: Double = isInSelectedRange ? 1.0 : 0.3
                let pointOpacity: Double = isInSelectedRange ? 1.0 : 0.3
                let pointColor = pointFilter.color
                let isSelected = selectedDate != nil && Calendar.current.isDate(point.date, equalTo: selectedDate!, toGranularity: getDateGranularity())

                // Only draw lines if multiple points visible in window
                if shouldDrawLines {
                    LineMark(
                        x: .value("Date", point.date, unit: calComponent),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(sectionColor.opacity(lineOpacity))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }

                // Stroked circle points (Apple Health style) - always show
                PointMark(x: .value("Date", point.date, unit: calComponent), y: .value("Value", point.value))
                    .foregroundStyle(pointColor.opacity(isSelected ? 1.0 : pointOpacity))
                    .symbolSize(isSelected ? 180 : 80)
                    .symbol {
                        Circle()
                            .strokeBorder(pointColor.opacity(isSelected ? 1.0 : pointOpacity), lineWidth: isSelected ? 3 : 2)
                            .background(Circle().fill(Color(uiColor: .systemBackground)))
                            .frame(width: isSelected ? 14 : 10, height: isSelected ? 14 : 10)
                    }
            }
        }
        // Don't use .id(selectedPeriod) - it forces full chart recreation which breaks scroll position
        // Period changes are handled by .onChange(of: selectedPeriod) and scroll position updates
        .chartYScale(domain: yDomain)
        .chartScrollableAxes(.horizontal)
        .chartScrollPosition(x: $scrollPosition)
        .chartXVisibleDomain(length: getVisibleDomainTimeInterval())
        .chartGesture { proxy in
            SpatialTapGesture()
                .onEnded { value in
                    if let tappedDate: Date = proxy.value(atX: value.location.x) {
                        let closest = pointsWithData.min(by: {
                            abs($0.date.timeIntervalSince(tappedDate)) < abs($1.date.timeIntervalSince(tappedDate))
                        })
                        if let closestDate = closest?.date,
                           Calendar.current.isDate(selectedDate ?? Date.distantPast, equalTo: closestDate, toGranularity: getDateGranularity()) {
                            selectedDate = nil
                        } else {
                            selectedDate = closest?.date
                        }
                    }
                }
        }
        .onChange(of: scrollPosition) { _, newPosition in
            // Ignore scroll changes during filter toggle
            guard !isFilterChanging else { return }
            scrollManager.handleScroll(position: newPosition)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: getAxisStride(), count: 1)) { _ in
                AxisValueLabel(format: getAxisFormat())
                AxisGridLine()
                AxisTick()
            }
        }
        .chartYAxis {
            // Y-axis - when filter selected, show ONLY range boundaries (replaces normal axis)
            if let boundaryValues = getRangeBoundaryValues(), !boundaryValues.isEmpty {
                // Use explicit boundary values only when filter is selected
                AxisMarks(values: boundaryValues) { value in
                    if let yValue = value.as(Double.self) {
                        AxisValueLabel {
                            Text(getYAxisLabel(for: yValue))
                                .font(.caption2)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(Color.secondary.opacity(0.2))
                }
            } else {
                // No filter - use automatic values
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    if let yValue = value.as(Double.self) {
                        AxisValueLabel {
                            Text(formatAxisValue(yValue))
                                .font(.caption2)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(Color.secondary.opacity(0.2))
                }
            }
        }
        .frame(height: 200)
        .padding(.horizontal)

        // Loading indicators
        HStack {
            if scrollManager.isLoadingOlder {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if scrollManager.isLoadingNewer {
                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .frame(height: 16)
        .padding(.horizontal)
    }

    private var emptyChartPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No historical data")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 220)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Range Filter List

    private var rangeFilterList: some View {
        VStack(spacing: 6) {
            ForEach(availableFilters) { filter in
                let count = rangeCounts[filter] ?? 0
                let isSelected = selectedRangeFilter == filter

                Button {
                    // Save scroll position before filter change
                    let savedPosition = scrollPosition
                    isFilterChanging = true

                    // Toggle filter without animation to prevent scroll position drift
                    withTransaction(Transaction(animation: nil)) {
                        if selectedRangeFilter == filter {
                            selectedRangeFilter = nil
                        } else {
                            selectedRangeFilter = filter
                        }
                    }

                    // Force restore scroll position on next run loop
                    DispatchQueue.main.async {
                        withTransaction(Transaction(animation: nil)) {
                            scrollPosition = savedPosition
                        }
                        isFilterChanging = false
                    }
                } label: {
                    HStack {
                        Circle()
                            .fill(filter.color)
                            .frame(width: 10, height: 10)

                        Text(filter.rawValue)
                            .font(.subheadline)
                            .foregroundColor(isSelected ? filter.color : .primary)

                        Spacer()

                        Text("\(count)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(isSelected ? filter.color : .secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isSelected ? filter.color.opacity(0.2) : Color(uiColor: .secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? filter.color : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helper Functions

    private func getFilterCategory(for value: Double) -> RangeFilter {
        // Find which range this value falls into
        for range in rangeInfo.ranges.sorted(by: { ($0.rangeLow ?? 0) < ($1.rangeLow ?? 0) }) {
            let low = range.rangeLow ?? Double.leastNormalMagnitude
            let high = range.rangeHigh ?? Double.greatestFiniteMagnitude

            if value >= low && value < high {
                let rangeName = range.rangeName.uppercased()
                if rangeName == "OPTIMAL" {
                    return .optimal
                } else if rangeName == "IN RANGE" || rangeName == "IN-RANGE" {
                    return .inRange
                } else {
                    return .outOfRange
                }
            }
        }
        return .outOfRange
    }

    private func matchesFilter(range: BiomarkerRangeDetail, filter: RangeFilter) -> Bool {
        let rangeName = range.rangeName.uppercased()
        switch filter {
        case .optimal:
            return rangeName == "OPTIMAL"
        case .inRange:
            return rangeName == "IN RANGE" || rangeName == "IN-RANGE"
        case .outOfRange:
            // Match ALL out-of-range bands (both low and high)
            return rangeName.contains("OUT") || (!rangeName.contains("OPTIMAL") && !rangeName.contains("IN RANGE") && !rangeName.contains("IN-RANGE"))
        }
    }

    private func getPointColor(for value: Double) -> Color {
        let filter = getFilterCategory(for: value)
        return filter.color
    }

    private func calculateScrollPosition() -> Date {
        // Position the scroll so the most recent DATA appears on the right side (Apple Health style)
        // Get the most recent data point date, default to now if no data
        let mostRecentDataDate = scrollManager.dataPointsWithValues.first?.date ?? Date()

        // Use 90% offset so most recent data appears near (but not at) the right edge
        let visibleDuration = scrollManager.numberOfBars
        let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
        return Calendar.current.date(
            byAdding: scrollManager.calendarComponent,
            value: -offsetFromEnd,
            to: mostRecentDataDate
        ) ?? mostRecentDataDate
    }

    /// Update cached data bounds - call when data loads or changes
    private func updateCachedDataBounds() {
        let values = chartPointsWithData.map { $0.value }
        if !values.isEmpty {
            cachedDataMin = values.min()
            cachedDataMax = values.max()
        }
    }

    private func calculateYDomain() -> ClosedRange<Double> {
        // Use cached data bounds to ensure they're always available
        let dataMin = cachedDataMin ?? chartPointsWithData.map { $0.value }.min()
        let dataMax = cachedDataMax ?? chartPointsWithData.map { $0.value }.max()

        // If a filter is selected, EXPAND Y-axis to include both data AND selected range bounds
        if let filter = selectedRangeFilter {
            let matchingRanges = rangeInfo.ranges.filter { matchesFilter(range: $0, filter: filter) }
            let filteredRangeLows = matchingRanges.compactMap { $0.rangeLow }
            let filteredRangeHighs = matchingRanges.compactMap { $0.rangeHigh }

            // Get range bounds
            let rangeMin = filteredRangeLows.min() ?? 0
            let rangeMax = filteredRangeHighs.max() ?? 100

            let yMin: Double
            let yMax: Double

            if let dMin = dataMin, let dMax = dataMax {
                // Have data - include both data and range bounds
                yMin = min(dMin, rangeMin)
                yMax = max(dMax, rangeMax)
            } else {
                // No data - just use range bounds
                yMin = rangeMin
                yMax = rangeMax
            }

            let range = yMax - yMin
            let buffer = max(range * 0.1, 2.0)
            return max(0, yMin - buffer)...(yMax + buffer)
        }

        // Default: base Y-axis on actual patient data only
        guard let dMin = dataMin, let dMax = dataMax else { return 0...100 }

        let range = dMax - dMin
        let buffer = max(range * 0.15, dMax * 0.1, 5.0)

        return max(0, dMin - buffer)...(dMax + buffer)
    }

    /// Format axis values
    private func formatAxisValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.0f", value)
        } else if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else if value < 1 {
            return String(format: "%.2f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func getVisibleDomainTimeInterval() -> TimeInterval {
        switch selectedPeriod {
        case .week: return 7 * 24 * 3600
        case .month: return 30 * 24 * 3600
        case .sixMonth: return 26 * 7 * 24 * 3600
        case .year: return 365 * 24 * 3600
        case .fiveYear: return 5 * 365 * 24 * 3600
        }
    }

    private func getAxisStride() -> Calendar.Component {
        switch selectedPeriod {
        case .week: return .day
        case .month: return .weekOfYear
        case .sixMonth: return .month
        case .year: return .month
        case .fiveYear: return .year
        }
    }

    private func getAxisFormat() -> Date.FormatStyle {
        switch selectedPeriod {
        case .week: return .dateTime.weekday(.narrow)
        case .month: return .dateTime.day(.defaultDigits)
        case .sixMonth: return .dateTime.month(.abbreviated)
        case .year: return .dateTime.month(.narrow)
        case .fiveYear: return .dateTime.year()
        }
    }

    private func formatDisplayValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 && value < 10000 {
            return String(format: "%.0f", value)
        } else if value >= 1000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    /// Get the calendar granularity for date matching based on period
    private func getDateGranularity() -> Calendar.Component {
        switch selectedPeriod {
        case .week, .month:
            return .day
        case .sixMonth:
            return .weekOfYear
        case .year, .fiveYear:
            return .month
        }
    }

    /// Get data points within the visible scroll window (for average calculation)
    /// Average updates as user scrolls the chart
    private func getVisibleDataPoints() -> [BiomarkerChartPoint] {
        let visibleDuration = getVisibleDomainTimeInterval()
        let windowEnd = scrollPosition.addingTimeInterval(visibleDuration)

        // Return data points within the visible scroll window
        return chartPointsWithData.filter { point in
            point.date >= scrollPosition && point.date <= windowEnd
        }
    }

    /// Format the visible date range as a string
    private func visibleDateRangeString() -> String {
        let calendar = Calendar.current
        let visibleDuration = scrollManager.numberOfBars
        let endDate = calendar.date(byAdding: scrollManager.calendarComponent, value: visibleDuration - 1, to: scrollPosition) ?? scrollPosition

        let formatter = DateFormatter()
        switch selectedPeriod {
        case .year, .fiveYear:
            formatter.dateFormat = "MMM yyyy"
        default:
            formatter.dateFormat = "MMM d"
        }

        return "\(formatter.string(from: scrollPosition)) - \(formatter.string(from: endDate))"
    }

    /// Format date for selected point display
    private func formatSelectedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()

        switch selectedPeriod {
        case .week, .month:
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        case .sixMonth:
            // Show week range (Mon-Sun)
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
                formatter.dateFormat = "MMM d, yyyy"
                return formatter.string(from: date)
            }
            let startFormatter = DateFormatter()
            startFormatter.dateFormat = "MMM d"
            let endFormatter = DateFormatter()
            endFormatter.dateFormat = "MMM d, yyyy"
            let lastDay = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.end
            return "\(startFormatter.string(from: weekInterval.start)) - \(endFormatter.string(from: lastDay))"
        case .year:
            // Show month name and year
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        case .fiveYear:
            // Show quarter range (e.g., "Oct - Dec 2025")
            guard let quarterInterval = calendar.dateInterval(of: .quarter, for: date) else {
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: date)
            }
            let startFormatter = DateFormatter()
            startFormatter.dateFormat = "MMM"
            let endFormatter = DateFormatter()
            endFormatter.dateFormat = "MMM yyyy"
            let lastDay = calendar.date(byAdding: .day, value: -1, to: quarterInterval.end) ?? quarterInterval.end
            return "\(startFormatter.string(from: quarterInterval.start)) - \(endFormatter.string(from: lastDay))"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }

    /// Get Y-axis boundary values - when filter selected, returns ONLY range boundaries
    /// Returns nil when no filter is selected (use automatic axis values)
    private func getRangeBoundaryValues() -> [Double]? {
        guard let filter = selectedRangeFilter else { return nil }

        // When filter selected, show ONLY the range boundaries
        let matchingRanges = rangeInfo.ranges.filter { matchesFilter(range: $0, filter: filter) }
        var boundaryValues: [Double] = []

        for range in matchingRanges {
            if let low = range.rangeLow {
                boundaryValues.append(low)
            }
            if let high = range.rangeHigh {
                boundaryValues.append(high)
            }
        }

        // Return explicit boundary values only (sorted, unique)
        let uniqueValues = Array(Set(boundaryValues)).sorted()
        return uniqueValues.isEmpty ? nil : uniqueValues
    }

    /// Get Y-axis label for a value - show < or > for open-ended range boundaries
    private func getYAxisLabel(for value: Double) -> String {
        // Get all range boundaries sorted
        let allBoundaries = getAllBoundaryValues()
        guard !allBoundaries.isEmpty else {
            return formatAxisValue(value)
        }

        let lowestBoundary = allBoundaries.first!
        let highestBoundary = allBoundaries.last!

        // Check if this is the lowest boundary - show "< X" (open-ended below)
        if abs(value - lowestBoundary) < 0.5 {
            // Check if any range has no meaningful lower bound (nil or 0) - indicates open-ended
            let hasOpenLowRange = rangeInfo.ranges.contains { range in
                range.rangeLow == nil || range.rangeLow == 0
            }
            if hasOpenLowRange {
                return "< \(formatAxisValue(value))"
            }
        }

        // Check if this is the highest boundary - show "> X" (open-ended above)
        if abs(value - highestBoundary) < 0.5 {
            // Check if any range has no upper bound - indicates open-ended
            let hasOpenHighRange = rangeInfo.ranges.contains { $0.rangeHigh == nil }
            if hasOpenHighRange {
                return "> \(formatAxisValue(value))"
            }
        }

        return formatAxisValue(value)
    }
}

#Preview {
    BiomarkerRangeSelectorModal(
        biomarkerName: "HDL",
        unit: "mg/dL",
        rangeInfo: BiomarkerRangeInfo(
            directionality: "optimal_range",
            ranges: [
                BiomarkerRangeDetail(id: UUID(), rangeName: "OUT OF RANGE", rangeNameBackend: "low_out", rangeLow: 0, rangeHigh: 40, frontendDisplay: "< 40"),
                BiomarkerRangeDetail(id: UUID(), rangeName: "IN RANGE", rangeNameBackend: "low_in", rangeLow: 40, rangeHigh: 60, frontendDisplay: "40-60"),
                BiomarkerRangeDetail(id: UUID(), rangeName: "OPTIMAL", rangeNameBackend: "optimal", rangeLow: 60, rangeHigh: 100, frontendDisplay: "60-100"),
                BiomarkerRangeDetail(id: UUID(), rangeName: "IN RANGE", rangeNameBackend: "high_in", rangeLow: 100, rangeHigh: 120, frontendDisplay: "100-120"),
                BiomarkerRangeDetail(id: UUID(), rangeName: "OUT OF RANGE", rangeNameBackend: "high_out", rangeLow: 120, rangeHigh: 200, frontendDisplay: "> 120")
            ],
            realisticLow: 20,
            realisticHigh: 150
        ),
        quantityType: "HKQuantityTypeIdentifierBloodPressureSystolic",
        sectionColor: .orange,
        isPresented: .constant(true)
    )
}
