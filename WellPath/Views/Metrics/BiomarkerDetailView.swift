//
//  BiomarkerDetailView.swift
//  WellPath
//
//  Detail view for biomarkers and biometrics with line chart
//  Matches WellPathScoreTrendChart pattern with optimal range visualization
//

import SwiftUI
import Charts

// Local TimePeriod enum for biomarkers (includes 5Y)
enum BiomarkerTimePeriod: String, CaseIterable, Identifiable {
    case week = "W"
    case month = "M"
    case sixMonth = "6M"
    case year = "Y"
    case fiveYear = "5Y"

    var id: String { rawValue }

    var calendarComponent: Calendar.Component {
        switch self {
        case .week: return .day
        case .month: return .day
        case .sixMonth: return .weekOfYear
        case .year: return .month
        case .fiveYear: return .month
        }
    }
}

struct BiomarkerDetailView: View {
    let name: String
    let value: String?
    let status: String?
    let optimalRange: String?
    let trend: String?
    let isBiometric: Bool

    @StateObject private var viewModel = BiomarkerDetailViewModel()
    @State private var showAbout = false
    @State private var selectedPeriod: BiomarkerTimePeriod = .month
    @State private var scrollPosition: Date = Date()
    @State private var selectedDate: Date?
    @State private var optimalRangeLow: Double?
    @State private var optimalRangeHigh: Double?
    @State private var unit: String = ""
    @State private var rangeSegments: [RangeSegmentDetail] = []
    @State private var directionality: String = "optimal_range"
    @State private var scrollViewID = UUID()

    var metricColor: Color {
        isBiometric ? Color(red: 0.40, green: 0.80, blue: 1.0) : Color(red: 0.74, green: 0.56, blue: 0.94)
    }

    var metricIcon: String {
        isBiometric ? "waveform.path.ecg" : "testtube.2"
    }

    init(name: String, value: String? = nil, status: String? = nil, optimalRange: String? = nil, trend: String? = nil, isBiometric: Bool) {
        self.name = name
        self.value = value
        self.status = status
        self.optimalRange = optimalRange
        self.trend = trend
        self.isBiometric = isBiometric
    }

    var body: some View {
        VStack(spacing: 0) {
            if showAbout {
                aboutView
            } else {
                chartView
            }
        }
        .background(
            ZStack {
                // Background gradient
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [
                            metricColor.opacity(0.65),
                            metricColor.opacity(0.45),
                            metricColor.opacity(0.25),
                            metricColor.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 900)
                    Spacer()
                }

                // Large background icon
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: metricIcon)
                            .font(.system(size: 200))
                            .foregroundStyle(Color.white.opacity(0.2))
                            .rotationEffect(.degrees(-15))
                            .offset(x: 50, y: -50)
                    }
                    Spacer()
                }
            }
            .ignoresSafeArea()
        )
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadHistory(for: name, isBiometric: isBiometric)
            await loadOptimalRange()
            await loadRangeSegments()
        }
    }

    // MARK: - Chart View

    private var chartView: some View {
        ScrollView {
            VStack(spacing: 0) {
                if !viewModel.isLoading {
                    VStack(spacing: 0) {
                        // Period picker
                        Picker("Period", selection: $selectedPeriod) {
                            ForEach(BiomarkerTimePeriod.allCases) { period in
                                Text(period.rawValue).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .onChange(of: selectedPeriod) { oldValue, newPeriod in
                            selectedDate = nil
                            scrollPosition = calculateScrollPosition(for: newPeriod)
                            scrollViewID = UUID()  // Force chart recreation to stop scroll momentum
                        }

                        // Value display with info button (matches MetricDetailView pattern)
                        HStack(alignment: .top, spacing: 40) {
                            VStack(alignment: .leading, spacing: 4) {
                                // Get selected data point if any
                                let selectedDataPoint: BiomarkerDataPoint? = {
                                    guard let date = selectedDate else { return nil }
                                    return viewModel.historicalData.first(where: { Calendar.current.isDate($0.date, equalTo: date, toGranularity: .day) })
                                }()
                                let visibleAvg = calculateVisibleAverage()
                                let hasVisibleData = visibleAvg > 0

                                // Label row
                                Text(selectedDataPoint != nil ? "Value" : "Average")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                // Value display
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    if let selected = selectedDataPoint {
                                        Text(formatDisplayValue(selected.value))
                                            .font(.system(size: 48, weight: .semibold))
                                            .foregroundColor(metricColor)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.6)
                                    } else if hasVisibleData {
                                        Text(formatDisplayValue(visibleAvg))
                                            .font(.system(size: 48, weight: .semibold))
                                            .foregroundColor(metricColor)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.6)
                                    } else {
                                        Text("No Data")
                                            .font(.system(size: 48, weight: .semibold))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.6)
                                    }

                                    if !unit.isEmpty && (selectedDataPoint != nil || hasVisibleData) {
                                        Text(unit)
                                            .font(.title2)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                // Date display
                                if let selected = selectedDataPoint {
                                    Text(formatSingleDate(selected.date))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(visibleDateRangeString())
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            // Info button (top-aligned with value display)
                            Button(action: {
                                withAnimation {
                                    showAbout.toggle()
                                }
                            }) {
                                Image(systemName: "info.circle")
                                    .font(.title3)
                                    .foregroundColor(metricColor)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 12)

                        // Line chart (show chart even when empty - with grid lines)
                        if !viewModel.historicalData.isEmpty {
                            lineChartView
                                .padding(.top, 16)
                                .padding(.bottom, 16)
                        } else {
                            emptyChartView
                                .padding(.top, 16)
                                .padding(.bottom, 16)
                        }

                        // Status summary bar
                        statusSummaryBar
                            .padding(.top, 8)
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                    }
                    .background(Color(uiColor: .systemGroupedBackground))
                    .padding(.top, 16)

                    // Records list
                    if !viewModel.historicalData.isEmpty {
                        recordsListView
                            .padding(.top, 16)
                    }
                }

                Spacer(minLength: 32)
            }
        }
    }

    // MARK: - Line Chart

    @ViewBuilder
    private var lineChartView: some View {
        Chart {
            // Optimal range shading - use full data range
            if let rangeLow = optimalRangeLow, let rangeHigh = optimalRangeHigh,
               let oldest = viewModel.historicalData.last?.date,
               let newest = viewModel.historicalData.first?.date {
                let rangeStart = Calendar.current.date(byAdding: .month, value: -1, to: oldest) ?? oldest
                let rangeEnd = Calendar.current.date(byAdding: .month, value: 1, to: newest) ?? newest
                RectangleMark(
                    xStart: .value("Start", rangeStart),
                    xEnd: .value("End", rangeEnd),
                    yStart: .value("Low", rangeLow),
                    yEnd: .value("High", rangeHigh)
                )
                .foregroundStyle(Color.green.opacity(0.1))
            }

            ForEach(viewModel.historicalData) { dataPoint in

                // Line only (NO AreaMark per user request)
                LineMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Value", dataPoint.value)
                )
                .foregroundStyle(metricColor)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3))

                // Points with circle selection indicator
                if let selectedDate = selectedDate,
                   Calendar.current.isDate(dataPoint.date, equalTo: selectedDate, toGranularity: .day) {
                    // Selected point - draw circle around it
                    PointMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(metricColor)
                    .symbolSize(200)
                    .symbol {
                        Circle()
                            .strokeBorder(metricColor, lineWidth: 3)
                            .background(Circle().fill(Color(uiColor: .systemBackground)))
                            .frame(width: 16, height: 16)
                    }
                } else {
                    // Regular point
                    PointMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(metricColor)
                }
            }
        }
        .chartYScale(domain: getDynamicYAxisDomain())
        .chartXScale(domain: getXAxisDomain())
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let selectedDate = selectedDate,
                   let selectedData = viewModel.historicalData.first(where: { Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: .day) }) {

                    if let xPos = proxy.position(forX: selectedData.date),
                       let yPos = proxy.position(forY: selectedData.value) {

                        VStack(spacing: 4) {
                            Text(String(format: "%.1f %@", selectedData.value, unit))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(uiColor: .systemBackground))
                                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        )
                        .position(x: xPos, y: max(30, yPos - 40))
                    }
                }
            }
        }
        .frame(height: 220)
        .chartBackground { proxy in Color.clear }
        .chartScrollableAxes(.horizontal)
        .chartScrollPosition(x: $scrollPosition)
        .chartXVisibleDomain(length: getVisibleDomainTimeInterval())
        .onAppear {
            scrollPosition = calculateScrollPosition(for: selectedPeriod)
        }
        .onChange(of: scrollPosition) { oldPos, newPos in
            // Infinite scroll: load more data when approaching edges
            Task {
                await viewModel.loadMoreIfNeeded(for: name, isBiometric: isBiometric, scrollPosition: newPos, period: selectedPeriod)
            }
        }
        .chartGesture { proxy in
            SpatialTapGesture()
                .onEnded { value in
                    if let tappedDate: Date = proxy.value(atX: value.location.x) {
                        let closest = viewModel.historicalData.min(by: {
                            abs($0.date.timeIntervalSince(tappedDate)) < abs($1.date.timeIntervalSince(tappedDate))
                        })

                        if selectedDate == closest?.date {
                            selectedDate = nil
                        } else {
                            selectedDate = closest?.date
                        }
                    }
                }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: getAxisStride(), count: getAxisMultiplier())) { value in
                if value.as(Date.self) != nil {
                    AxisValueLabel(format: getAxisFormat())
                    AxisGridLine()
                    AxisTick()
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel()
                AxisGridLine(
                    stroke: StrokeStyle(
                        lineWidth: 0.5,
                        dash: [2, 3]
                    )
                )
                .foregroundStyle(Color.secondary.opacity(0.2))
            }
        }
        .id(scrollViewID)  // Force recreation on period change to stop scroll momentum
        .padding(.horizontal)
    }

    // MARK: - Empty Chart View (shows grid lines when no data)

    @ViewBuilder
    private var emptyChartView: some View {
        let visibleDuration = getVisibleDomainTimeInterval()
        let visibleStart = scrollPosition
        let visibleEnd = scrollPosition.addingTimeInterval(visibleDuration)

        Chart {
            // Create invisible points to establish the domain
            PointMark(
                x: .value("Date", visibleStart),
                y: .value("Value", 0)
            )
            .opacity(0)

            PointMark(
                x: .value("Date", visibleEnd),
                y: .value("Value", 150)
            )
            .opacity(0)
        }
        .chartYScale(domain: 0...150)
        .frame(height: 220)
        .chartXAxis {
            AxisMarks(values: .stride(by: getAxisStride(), count: getAxisMultiplier())) { value in
                if value.as(Date.self) != nil {
                    AxisValueLabel(format: getAxisFormat())
                    AxisGridLine()
                    AxisTick()
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel()
                AxisGridLine(
                    stroke: StrokeStyle(
                        lineWidth: 0.5,
                        dash: [2, 3]
                    )
                )
                .foregroundStyle(Color.secondary.opacity(0.2))
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Status Summary Bar

    @ViewBuilder
    private var statusSummaryBar: some View {
        HStack {
            Text(getCurrentStatus())
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()

            Text("\(viewModel.historicalData.count) Record\(viewModel.historicalData.count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(10)
    }

    /// Determines the current status based on the latest value and range segments
    private func getCurrentStatus() -> String {
        // If we have a selected point, use its status
        if let selectedDate = selectedDate,
           let selectedPoint = viewModel.historicalData.first(where: { Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: .day) }) {
            return getStatusForValue(selectedPoint.value)
        }

        // Otherwise use the latest/average value
        guard let latestValue = viewModel.historicalData.first?.value else {
            return "No Data"
        }

        return getStatusForValue(latestValue)
    }

    /// Returns status string for a given value based on range segments
    private func getStatusForValue(_ value: Double) -> String {
        for segment in rangeSegments {
            if value >= segment.rangeLow && value <= segment.rangeHigh {
                return segment.rangeName ?? segment.rangeBucket
            }
        }

        // Fallback if no matching range
        if let optLow = optimalRangeLow, let optHigh = optimalRangeHigh {
            if value >= optLow && value <= optHigh {
                return "Optimal"
            } else if value < optLow {
                return "Low"
            } else {
                return "High"
            }
        }

        return "Unknown"
    }

    // MARK: - Records List (Apple Health Style)

    @ViewBuilder
    private var recordsListView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Records")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.horizontal)

            // Group records by date
            ForEach(groupedRecords, id: \.date) { group in
                VStack(alignment: .leading, spacing: 8) {
                    // Date header
                    Text(formatRecordDateHeader(group.date))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal)

                    // Source label
                    Text("Health Record")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    // Record cards for this date
                    ForEach(group.records) { record in
                        NavigationLink(destination: LabResultRecordView(
                            record: record,
                            metricName: name,
                            unit: unit,
                            metricColor: metricColor,
                            rangeSegments: rangeSegments,
                            isBiometric: isBiometric
                        )) {
                            BiomarkerRecordCard(
                                record: record,
                                metricName: name,
                                unit: unit,
                                metricColor: metricColor,
                                metricIcon: metricIcon,
                                rangeSegments: rangeSegments,
                                directionality: directionality
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal)
                    }
                }
            }

            // Show All Records button (if more than 3 records)
            if viewModel.historicalData.count > 3 {
                NavigationLink(destination: AllRecordsView(
                    records: viewModel.historicalData,
                    metricName: name,
                    unit: unit,
                    metricColor: metricColor,
                    metricIcon: metricIcon,
                    rangeSegments: rangeSegments,
                    isBiometric: isBiometric,
                    directionality: directionality
                )) {
                    HStack {
                        Text("Show All Records")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal)
            }
        }
    }

    /// Groups records by date for display
    private var groupedRecords: [RecordGroup] {
        let calendar = Calendar.current
        var groups: [Date: [BiomarkerDataPoint]] = [:]

        // Only show first 3 records in summary view
        let recordsToShow = Array(viewModel.historicalData.prefix(3))

        for record in recordsToShow {
            let dateOnly = calendar.startOfDay(for: record.date)
            groups[dateOnly, default: []].append(record)
        }

        return groups.map { RecordGroup(date: $0.key, records: $0.value) }
            .sorted { $0.date > $1.date }
    }

    private func formatRecordDateHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }

    // MARK: - About View

    @ViewBuilder
    private var aboutView: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !viewModel.aboutSections.isEmpty {
                        ForEach(viewModel.aboutSections.sorted(by: { $0.displayOrder < $1.displayOrder })) { section in
                            EducationAccordionSection(
                                sectionNumber: section.displayOrder,
                                title: section.sectionTitle,
                                content: section.sectionContent,
                                color: metricColor
                            )
                        }
                    } else {
                        // Placeholder if no content loaded
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: isBiometric ? "waveform.path.ecg" : "testtube.2")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("Educational content for \(name) will be displayed here.")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .padding(.top, 32)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
            }

            // Floating close button (chart icon)
            Button(action: {
                withAnimation {
                    showAbout = false
                }
            }) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.title3)
                    .foregroundColor(metricColor)
            }
            .padding(.top, 8)
            .padding(.trailing, 16)
        }
    }

    // MARK: - Helper Functions

    private func calculateVisibleAverage() -> Double {
        guard !viewModel.historicalData.isEmpty else { return 0 }

        // Get visible window bounds
        let visibleDuration = getVisibleDomainTimeInterval()
        let visibleStart = scrollPosition
        let visibleEnd = scrollPosition.addingTimeInterval(visibleDuration)

        // Filter data points in visible window
        let visibleData = viewModel.historicalData.filter { dataPoint in
            dataPoint.date >= visibleStart && dataPoint.date <= visibleEnd
        }

        guard !visibleData.isEmpty else { return 0 }

        let sum = visibleData.reduce(0.0) { $0 + $1.value }
        return sum / Double(visibleData.count)
    }

    private func visibleDateRangeString() -> String {
        // ALWAYS show the full visible window range (not based on data points)
        let visibleDuration = getVisibleDomainTimeInterval()
        let visibleStart = scrollPosition
        let visibleEnd = scrollPosition.addingTimeInterval(visibleDuration)

        let formatter = DateFormatter()
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let startYear = calendar.component(.year, from: visibleStart)

        switch selectedPeriod {
        case .week:
            formatter.dateFormat = "MMM d"
            let yearSuffix = startYear == currentYear ? ", \(currentYear)" : ", \(startYear)"
            return "\(formatter.string(from: visibleStart)) - \(formatter.string(from: visibleEnd))\(yearSuffix)"
        case .month:
            formatter.dateFormat = "MMM d"
            let yearSuffix = startYear == currentYear ? ", \(currentYear)" : ", \(startYear)"
            return "\(formatter.string(from: visibleStart)) - \(formatter.string(from: visibleEnd))\(yearSuffix)"
        case .sixMonth:
            formatter.dateFormat = "MMM yyyy"
            return "\(formatter.string(from: visibleStart)) - \(formatter.string(from: visibleEnd))"
        case .year:
            formatter.dateFormat = "MMM yyyy"
            return "\(formatter.string(from: visibleStart)) - \(formatter.string(from: visibleEnd))"
        case .fiveYear:
            formatter.dateFormat = "yyyy"
            return "\(formatter.string(from: visibleStart)) - \(formatter.string(from: visibleEnd))"
        }
    }

    private func getDynamicYAxisDomain() -> ClosedRange<Double> {
        let values = viewModel.historicalData.map { $0.value }
        guard !values.isEmpty else { return 0...100 }

        let dataMin = values.min() ?? 0
        let dataMax = values.max() ?? 100

        // If we have optimal range, use it to inform y-axis
        if let rangeLow = optimalRangeLow, let rangeHigh = optimalRangeHigh {
            let yMin = min(dataMin, rangeLow)
            let yMax = max(dataMax, rangeHigh)
            let range = yMax - yMin
            // Use at least 20% buffer or 10 units, whichever is larger
            let buffer = max(range * 0.15, 10.0)
            return max(0, yMin - buffer)...(yMax + buffer)
        } else {
            // No optimal range - just use data
            let range = dataMax - dataMin
            // For single point or small range, use fixed buffer
            let buffer = range < 1.0 ? max(dataMax * 0.2, 5.0) : range * 0.2
            return max(0, dataMin - buffer)...(dataMax + buffer)
        }
    }

    /// Returns the x-axis domain based on data and selected period
    /// This establishes the scrollable range without dynamic recalculation during scroll
    private func getXAxisDomain() -> ClosedRange<Date> {
        let calendar = Calendar.current
        let now = Date()

        // Get data bounds or use defaults
        let oldestData = viewModel.historicalData.last?.date ?? now
        let newestData = viewModel.historicalData.first?.date ?? now

        // Extend bounds based on period for scrolling room
        let pastBuffer: Int
        let futureBuffer: Int

        switch selectedPeriod {
        case .week:
            pastBuffer = -2  // 2 weeks before oldest
            futureBuffer = 1 // 1 week after newest
        case .month:
            pastBuffer = -3  // 3 months before oldest
            futureBuffer = 1 // 1 month after newest
        case .sixMonth:
            pastBuffer = -12 // 1 year before oldest
            futureBuffer = 3 // 3 months after newest
        case .year:
            pastBuffer = -24 // 2 years before oldest
            futureBuffer = 6 // 6 months after newest
        case .fiveYear:
            pastBuffer = -60 // 5 years before oldest
            futureBuffer = 12 // 1 year after newest
        }

        let domainStart = calendar.date(byAdding: .month, value: pastBuffer, to: oldestData) ?? oldestData
        let domainEnd = calendar.date(byAdding: .month, value: futureBuffer, to: max(newestData, now)) ?? now

        return domainStart...domainEnd
    }

    private func calculateScrollPosition(for period: BiomarkerTimePeriod) -> Date {
        // Position most recent data on RIGHT side of visible window (at ~90%)
        // Use most recent data point if available, otherwise use now
        let referenceDate = viewModel.historicalData.first?.date ?? Date()
        let visibleDomain = getVisibleDomainTimeInterval()

        // Calculate how much of the window should show BEFORE the most recent date (90%)
        // and how much AFTER (10% buffer for future)
        let offsetBeforeLatest = visibleDomain * 0.9

        // Scroll position should be offsetBeforeLatest BEFORE the most recent date
        // This puts the most recent date at 90% across the window (on the right)
        return referenceDate.addingTimeInterval(-offsetBeforeLatest)
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

    // X-axis label stride (what component to stride by)
    private func getAxisStride() -> Calendar.Component {
        switch selectedPeriod {
        case .week: return .day          // Daily marks
        case .month: return .weekOfYear  // Weekly marks
        case .sixMonth: return .month    // Monthly marks
        case .year: return .month        // Monthly marks
        case .fiveYear: return .year     // Yearly marks
        }
    }

    // X-axis label multiplier (every N of the stride component)
    private func getAxisMultiplier() -> Int {
        switch selectedPeriod {
        case .week: return 1      // Every day
        case .month: return 1     // Every week
        case .sixMonth: return 1  // Every month
        case .year: return 1      // Every month
        case .fiveYear: return 1  // Every year
        }
    }

    // X-axis label format (how to display the date)
    private func getAxisFormat() -> Date.FormatStyle {
        switch selectedPeriod {
        case .week:
            return .dateTime.weekday(.narrow)          // M, T, W, T, F, S, S
        case .month:
            return .dateTime.day(.defaultDigits)       // 1, 8, 15, 22, 29
        case .sixMonth:
            return .dateTime.month(.abbreviated)       // Jan, Feb, Mar
        case .year:
            return .dateTime.month(.narrow)            // J, F, M, A, M, J
        case .fiveYear:
            return .dateTime.year()                    // 2020, 2021, 2022
        }
    }

    private func formatSelectedDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    /// Formats a single date for display when a point is selected (e.g., "October 15, 2025")
    private func formatSingleDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }

    /// Formats a value for display - uses integer format for whole numbers, 1 decimal otherwise
    private func formatDisplayValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 && value < 10000 {
            return String(format: "%.0f", value)
        } else if value >= 1000 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func loadOptimalRange() async {
        let supabase = SupabaseManager.shared.client

        // Define UnitsBase struct for join queries
        struct UnitsBase: Codable {
            let uiDisplay: String?

            enum CodingKeys: String, CodingKey {
                case uiDisplay = "ui_display"
            }
        }

        do {
            _ = try await supabase.auth.session.user.id

            if isBiometric {
                // Fetch unit from biometrics_base with units_base join

                struct BiometricWithUnit: Codable {
                    let unit: String?
                    let unitDisplay: String?
                    let unitsBase: UnitsBase?

                    enum CodingKeys: String, CodingKey {
                        case unit
                        case unitDisplay = "unit_display"
                        case unitsBase = "units_base"
                    }
                }

                let response: [BiometricWithUnit] = try await supabase
                    .from("biometrics_base")
                    .select("unit, unit_display, units_base(ui_display)")
                    .eq("biometric_name", value: name)
                    .limit(1)
                    .execute()
                    .value

                if let first = response.first {
                    // Prefer ui_display from units_base join, fallback to unit_display, then unit
                    unit = first.unitsBase?.uiDisplay ?? first.unitDisplay ?? first.unit ?? ""
                }

                // Get optimal range from biometric_detail
                let details: [BiometricDetail] = try await supabase
                    .from("biometrics_detail")
                    .select()
                    .eq("biometric", value: name)
                    .eq("range_bucket", value: "Optimal")
                    .limit(1)
                    .execute()
                    .value

                if let detail = details.first,
                   let rangeLow = detail.rangeLow,
                   let rangeHigh = detail.rangeHigh {
                    optimalRangeLow = rangeLow
                    optimalRangeHigh = rangeHigh
                }
            } else {
                // Fetch unit from biomarkers_base with units_base join
                struct BiomarkerWithUnit: Codable {
                    let units: String?
                    let unitsBase: UnitsBase?

                    enum CodingKeys: String, CodingKey {
                        case units
                        case unitsBase = "units_base"
                    }
                }

                let response: [BiomarkerWithUnit] = try await supabase
                    .from("biomarkers_base")
                    .select("units, units_base(ui_display)")
                    .eq("biomarker_name", value: name)
                    .limit(1)
                    .execute()
                    .value

                if let first = response.first {
                    // Prefer ui_display from units_base join, fallback to units
                    unit = first.unitsBase?.uiDisplay ?? first.units ?? ""
                }

                // Get optimal range from biomarker_detail
                let details: [BiomarkerDetail] = try await supabase
                    .from("biomarkers_detail")
                    .select()
                    .eq("biomarker", value: name)
                    .eq("range_bucket", value: "Optimal")
                    .limit(1)
                    .execute()
                    .value

                if let detail = details.first,
                   let rangeLow = detail.rangeLow,
                   let rangeHigh = detail.rangeHigh {
                    optimalRangeLow = rangeLow
                    optimalRangeHigh = rangeHigh
                }
            }
        } catch {
            print("❌ Error loading optimal range: \(error)")
        }

        // Load About content - outside try-catch so it always runs even if range queries fail
        await viewModel.loadAboutContent(for: name, isBiometric: isBiometric)
    }

    private func loadRangeSegments() async {
        let supabase = SupabaseManager.shared.client

        print("🔄 loadRangeSegments() called for: \(name), isBiometric: \(isBiometric)")

        do {
            // Get current user for gender/age filtering
            let userId = try await supabase.auth.session.user.id
            print("✅ Got userId: \(userId)")

            // Fetch patient details for gender/age - use defaults if not found
            var patientGender = "all"
            var patientAge = 0

            let patientDetails: [PatientDetails] = try await supabase
                .from("patients")
                .select()
                .eq("patient_id", value: userId)
                .limit(1)
                .execute()
                .value

            if let patient = patientDetails.first {
                patientGender = patient.biologicalSex ?? "all"

                // Parse date of birth string to Date (format: "YYYY-MM-DD")
                if let dobString = patient.dateOfBirth {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    if let dob = formatter.date(from: dobString) {
                        patientAge = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
                    }
                }
                print("✅ Patient found - gender: \(patientGender), age: \(patientAge)")
            } else {
                print("⚠️ No patient details found, using defaults")
            }

            // Struct to hold realistic bounds from base table
            struct RealisticBounds: Codable {
                let realisticLow: Double?
                let realisticHigh: Double?

                enum CodingKeys: String, CodingKey {
                    case realisticLow = "realistic_low"
                    case realisticHigh = "realistic_high"
                }
            }

            if isBiometric {
                print("🔍 Fetching biometric data for: \(name)")

                // Fetch realistic bounds from biometrics_base
                let boundsResult: [RealisticBounds] = try await supabase
                    .from("biometrics_base")
                    .select("realistic_low, realistic_high")
                    .eq("biometric_name", value: name)
                    .limit(1)
                    .execute()
                    .value
                let realisticLow = boundsResult.first?.realisticLow
                let realisticHigh = boundsResult.first?.realisticHigh
                print("📏 Realistic bounds: low=\(realisticLow ?? -1), high=\(realisticHigh ?? -1)")

                // Fetch all biometric ranges for this metric (filtered by gender/age)
                // Try patient gender first, fall back to "all" if no results
                print("🔍 Querying biometrics_detail for gender: \(patientGender)")
                var ranges: [BiometricDetail] = try await supabase
                    .from("biometrics_detail")
                    .select()
                    .eq("biometric", value: name)
                    .eq("gender", value: patientGender)
                    .order("range_low", ascending: true)
                    .execute()
                    .value
                print("📊 Found \(ranges.count) ranges for gender \(patientGender)")

                // Fall back to "all" gender if no gender-specific ranges
                if ranges.isEmpty {
                    print("🔄 No gender-specific ranges, falling back to 'all'")
                    ranges = try await supabase
                        .from("biometrics_detail")
                        .select()
                        .eq("biometric", value: name)
                        .eq("gender", value: "all")
                        .order("range_low", ascending: true)
                        .execute()
                        .value
                    print("📊 Found \(ranges.count) ranges for gender 'all'")
                }

                // Filter by age first
                let patientAgeDouble = Double(patientAge)
                let filteredRanges = ranges.filter { range in
                    if let ageLow = range.ageLow, let ageHigh = range.ageHigh {
                        return patientAgeDouble >= ageLow && patientAgeDouble <= ageHigh
                    }
                    return true // Include if no age restriction
                }
                print("📊 After age filtering: \(filteredRanges.count) ranges (age=\(patientAge))")

                let rangesToUse = filteredRanges.isEmpty ? ranges : filteredRanges
                let rangeCount = rangesToUse.count

                // Convert to RangeSegmentDetail with realistic bounds applied to first/last
                // Extract directionality from first range that has it
                if let firstDirectionality = rangesToUse.compactMap({ $0.directionality }).first {
                    directionality = firstDirectionality
                    print("📍 Directionality: \(directionality)")
                }

                rangeSegments = rangesToUse.enumerated().compactMap { index, range in
                    guard let rangeLow = range.rangeLow,
                          let rangeHigh = range.rangeHigh,
                          let rangeBucket = range.rangeBucket,
                          let rangeName = range.rangeName else {
                        print("⚠️ Skipping biometric range at index \(index): missing required fields (rangeLow=\(range.rangeLow ?? -999), rangeHigh=\(range.rangeHigh ?? -999), rangeBucket=\(range.rangeBucket ?? "nil"), rangeName=\(range.rangeName ?? "nil"))")
                        return nil
                    }

                    let isFirst = index == 0
                    let isLast = index == rangeCount - 1

                    // Apply realistic bounds to display values for first/last tiers
                    let displayLow = isFirst && realisticLow != nil ? max(rangeLow, realisticLow!) : rangeLow
                    let displayHigh = isLast && realisticHigh != nil ? min(rangeHigh, realisticHigh!) : rangeHigh

                    // Determine if this range contains the latest value
                    let containsValue: Bool
                    if let latestValue = viewModel.historicalData.first?.value {
                        containsValue = latestValue >= rangeLow && latestValue <= rangeHigh
                    } else {
                        containsValue = false
                    }

                    return RangeSegmentDetail(
                        rangeName: rangeName,
                        rangeBucket: rangeBucket,
                        rangeLow: rangeLow,
                        rangeHigh: rangeHigh,
                        frontendDisplay: range.frontendDisplaySpecific,
                        containsValue: containsValue,
                        displayLow: displayLow,
                        displayHigh: displayHigh,
                        isFirstTier: isFirst,
                        isLastTier: isLast
                    )
                }
                print("✅ Created \(rangeSegments.count) RangeSegmentDetail objects for biometric")
            } else {
                print("🔍 Fetching biomarker data for: \(name)")

                // Fetch realistic bounds from biomarkers_base
                let boundsResult: [RealisticBounds] = try await supabase
                    .from("biomarkers_base")
                    .select("realistic_low, realistic_high")
                    .eq("biomarker_name", value: name)
                    .limit(1)
                    .execute()
                    .value
                let realisticLow = boundsResult.first?.realisticLow
                let realisticHigh = boundsResult.first?.realisticHigh
                print("📏 Realistic bounds: low=\(realisticLow ?? -1), high=\(realisticHigh ?? -1)")

                // Fetch all biomarker ranges for this metric (filtered by gender)
                // Try patient gender first, fall back to "all" if no results
                print("🔍 Querying biomarkers_detail for gender: \(patientGender)")
                var ranges: [BiomarkerDetail] = try await supabase
                    .from("biomarkers_detail")
                    .select()
                    .eq("biomarker", value: name)
                    .eq("gender", value: patientGender)
                    .order("range_low", ascending: true)
                    .execute()
                    .value
                print("📊 Found \(ranges.count) ranges for gender \(patientGender)")

                // Fall back to "all" gender if no gender-specific ranges
                if ranges.isEmpty {
                    print("🔄 No gender-specific ranges, falling back to 'all'")
                    ranges = try await supabase
                        .from("biomarkers_detail")
                        .select()
                        .eq("biomarker", value: name)
                        .eq("gender", value: "all")
                        .order("range_low", ascending: true)
                        .execute()
                        .value
                    print("📊 Found \(ranges.count) ranges for gender 'all'")
                }

                let rangeCount = ranges.count

                // Convert to RangeSegmentDetail with realistic bounds applied to first/last
                // range_name IS the bucket now: "OPTIMAL", "IN RANGE", "OUT OF RANGE"
                // Extract directionality from first range that has it
                if let firstDirectionality = ranges.compactMap({ $0.directionality }).first {
                    directionality = firstDirectionality
                    print("📍 Directionality: \(directionality)")
                }

                rangeSegments = ranges.enumerated().compactMap { index, range in
                    guard let rangeLow = range.rangeLow,
                          let rangeHigh = range.rangeHigh else {
                        print("⚠️ Skipping range at index \(index): missing rangeLow or rangeHigh")
                        return nil
                    }

                    let isFirst = index == 0
                    let isLast = index == rangeCount - 1

                    // Apply realistic bounds to display values for first/last tiers
                    let displayLow = isFirst && realisticLow != nil ? max(rangeLow, realisticLow!) : rangeLow
                    let displayHigh = isLast && realisticHigh != nil ? min(rangeHigh, realisticHigh!) : rangeHigh

                    // Determine if this range contains the latest value
                    let containsValue: Bool
                    if let latestValue = viewModel.historicalData.first?.value {
                        containsValue = latestValue >= rangeLow && latestValue <= rangeHigh
                    } else {
                        containsValue = false
                    }

                    return RangeSegmentDetail(
                        rangeName: range.rangeName,
                        rangeBucket: range.rangeName,  // range_name IS the bucket
                        rangeLow: rangeLow,
                        rangeHigh: rangeHigh,
                        frontendDisplay: range.frontendDisplay,
                        containsValue: containsValue,
                        displayLow: displayLow,
                        displayHigh: displayHigh,
                        isFirstTier: isFirst,
                        isLastTier: isLast
                    )
                }
                print("✅ Created \(rangeSegments.count) RangeSegmentDetail objects")
            }

            print("📊 Final: Loaded \(rangeSegments.count) range segments for \(name)")
        } catch {
            print("❌ Error loading range segments: \(error)")
        }
    }
}

struct BiomarkerDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - Record Group for date grouping
struct RecordGroup {
    let date: Date
    let records: [BiomarkerDataPoint]
}

// MARK: - Biomarker Record Card (Apple Health Style)
struct BiomarkerRecordCard: View {
    let record: BiomarkerDataPoint
    let metricName: String
    let unit: String
    let metricColor: Color
    let metricIcon: String
    let rangeSegments: [RangeSegmentDetail]
    let directionality: String

    // Backward compatibility init
    init(record: BiomarkerDataPoint, metricName: String, unit: String, metricColor: Color, metricIcon: String, rangeSegments: [RangeSegmentDetail], directionality: String = "optimal_range") {
        self.record = record
        self.metricName = metricName
        self.unit = unit
        self.metricColor = metricColor
        self.metricIcon = metricIcon
        self.rangeSegments = rangeSegments
        self.directionality = directionality
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row: icon + name + date + chevron
            HStack {
                Image(systemName: metricIcon)
                    .font(.system(size: 14))
                    .foregroundColor(metricColor)

                Text(metricName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(metricColor)

                Spacer()

                Text(formatShortDate(record.date))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Value display
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formatValue(record.value))
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.primary)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Status
            Text(getStatus().uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            // Range bar
            if !rangeSegments.isEmpty {
                InlineRangeBar(
                    segments: rangeSegments,
                    currentValue: record.value,
                    metricColor: metricColor,
                    directionality: directionality,
                    allSegments: rangeSegments
                )
                .padding(.vertical, 4)
            }

            // Collected label
            Text("Collected")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }

    private func formatValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 && value < 10000 {
            return String(format: "%.0f", value)
        } else if value >= 1000 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func getStatus() -> String {
        for segment in rangeSegments {
            if record.value >= segment.rangeLow && record.value <= segment.rangeHigh {
                return segment.rangeName ?? segment.rangeBucket
            }
        }
        return "Unknown"
    }
}

// MARK: - All Records View
struct AllRecordsView: View {
    let records: [BiomarkerDataPoint]
    let metricName: String
    let unit: String
    let metricColor: Color
    let metricIcon: String
    let rangeSegments: [RangeSegmentDetail]
    let isBiometric: Bool
    let directionality: String

    // Backward compatibility init
    init(records: [BiomarkerDataPoint], metricName: String, unit: String, metricColor: Color, metricIcon: String, rangeSegments: [RangeSegmentDetail], isBiometric: Bool, directionality: String = "optimal_range") {
        self.records = records
        self.metricName = metricName
        self.unit = unit
        self.metricColor = metricColor
        self.metricIcon = metricIcon
        self.rangeSegments = rangeSegments
        self.isBiometric = isBiometric
        self.directionality = directionality
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(groupedRecords, id: \.date) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        // Date header
                        Text(formatRecordDateHeader(group.date))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .padding(.horizontal)

                        // Source label
                        Text("Health Record")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        // Record cards for this date
                        ForEach(group.records) { record in
                            NavigationLink(destination: LabResultRecordView(
                                record: record,
                                metricName: metricName,
                                unit: unit,
                                metricColor: metricColor,
                                rangeSegments: rangeSegments,
                                isBiometric: isBiometric
                            )) {
                                BiomarkerRecordCard(
                                    record: record,
                                    metricName: metricName,
                                    unit: unit,
                                    metricColor: metricColor,
                                    metricIcon: metricIcon,
                                    rangeSegments: rangeSegments,
                                    directionality: directionality
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.top, 16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Records")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var groupedRecords: [RecordGroup] {
        let calendar = Calendar.current
        var groups: [Date: [BiomarkerDataPoint]] = [:]

        for record in records {
            let dateOnly = calendar.startOfDay(for: record.date)
            groups[dateOnly, default: []].append(record)
        }

        return groups.map { RecordGroup(date: $0.key, records: $0.value) }
            .sorted { $0.date > $1.date }
    }

    private func formatRecordDateHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationView {
        BiomarkerDetailView(
            name: "Vitamin D",
            value: "45.2 ng/mL",
            status: "Optimal",
            optimalRange: "30-100 ng/mL",
            trend: "Stable",
            isBiometric: false
        )
    }
}
