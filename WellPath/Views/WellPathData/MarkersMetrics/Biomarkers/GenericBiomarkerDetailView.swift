//
//  GenericBiomarkerDetailView.swift
//  WellPath
//
//  Generic detail view for ANY biomarker
//  Uses shared BiomarkerViewModel and new models
//

import SwiftUI
import Charts

struct GenericBiomarkerDetailView: View {
    let biomarkerName: String
    @ObservedObject var viewModel: BiomarkerViewModel

    @State private var biomarker: BiomarkerDisplayData?
    @State private var isLoading = true
    @State private var showAboutModal = false
    @State private var showAddEntry = false
    @State private var showDataManagement = false
    @State private var showRangeSelector = false
    @State private var selectedPeriod: BiomarkerTimePeriod = .month
    @State private var selectedDate: Date?
    @State private var selectedRecordForDetail: BiomarkerSample?
    @State private var scrollPosition: Date = Date()
    @State private var lastPeriod: BiomarkerTimePeriod = .month

    // Scroll manager for infinite scroll (initialized when we have quantityType)
    @StateObject private var scrollManager = BiomarkerChartScrollManagerWrapper()


    private var sectionColor: Color {
        viewModel.sectionColor
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingView
            } else if let data = biomarker {
                chartView(data: data)
            } else {
                emptyView
            }
        }
        .metricScreenBackground(color: sectionColor)
        .navigationTitle(biomarkerName)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showDataManagement = true
                } label: {
                    Image(systemName: "list.bullet")
                }
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                FavoriteButton(
                    itemType: .biomarker,
                    itemId: biomarker?.viewId ?? biomarker?.cardId ?? biomarkerName,  // Use viewId for consistency with other metrics
                    displayName: biomarkerName,
                    pillar: biomarker?.category ?? "Biomarkers",
                    cardId: biomarker?.cardId,
                    sectionId: "NAV_BIOMARKERS"
                )

                Button {
                    showAddEntry = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddEntry) {
            if let clinicalType = biomarker?.sampleClinicalType {
                BiomarkerEntryView(
                    biomarkerName: biomarkerName,
                    clinicalType: clinicalType,
                    unit: biomarker?.unitDisplay ?? ""
                )
            }
        }
        .sheet(isPresented: $showDataManagement) {
            if let quantityType = biomarker?.sampleClinicalType {
                BiomarkerDataManagementView(
                    biomarkerName: biomarkerName,
                    sampleClinicalType: quantityType,
                    unit: biomarker?.unitDisplay ?? "",
                    color: sectionColor
                )
            } else {
                Text("No data available")
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showRangeSelector) {
            if let data = biomarker, !data.ranges.isEmpty, let quantityType = data.sampleClinicalType {
                BiomarkerRangeSelectorModal(
                    biomarkerName: biomarkerName,
                    unit: data.unitDisplay,
                    rangeInfo: BiomarkerRangeInfo(
                        directionality: data.directionality,
                        ranges: data.ranges.map { range in
                            BiomarkerRangeDetail(
                                id: range.id,
                                rangeName: range.rangeName,
                                rangeNameBackend: range.rangeNameBackend ?? "",
                                rangeLow: range.rangeLow,
                                rangeHigh: range.rangeHigh,
                                frontendDisplay: range.frontendDisplay
                            )
                        },
                        realisticLow: nil,
                        realisticHigh: nil
                    ),
                    quantityType: quantityType,
                    sectionColor: sectionColor,
                    isPresented: $showRangeSelector
                )
            }
        }
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(
                viewId: biomarker?.viewId ?? "",
                metricName: biomarkerName,
                color: sectionColor,
                isPresented: $showAboutModal
            )
        }
        .sheet(item: $selectedRecordForDetail) { sample in
            if let data = biomarker {
                BiomarkerRecordDetailView(
                    biomarkerName: biomarkerName,
                    sample: sample,
                    ranges: data.ranges,
                    unitDisplay: data.unitDisplay,
                    sectionColor: sectionColor
                )
            }
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true

        // Try to get from cache first
        if let cached = viewModel.biomarkerData[biomarkerName] {
            biomarker = cached
            // Initialize scroll manager with quantityType
            if let quantityType = cached.sampleClinicalType, !scrollManager.isInitialized {
                scrollManager.initialize(period: selectedPeriod, quantityType: quantityType)
                scrollPosition = calculateScrollPosition()
            }
        }

        // Also load fresh data
        if let fresh = await viewModel.loadSingleBiomarker(name: biomarkerName) {
            biomarker = fresh
            // Initialize scroll manager with quantityType if not already done
            if let quantityType = fresh.sampleClinicalType, !scrollManager.isInitialized {
                scrollManager.initialize(period: selectedPeriod, quantityType: quantityType)
                scrollPosition = calculateScrollPosition()
            }
        }

        isLoading = false
    }

    // MARK: - Chart View

    private func chartView(data: BiomarkerDisplayData) -> some View {
        ScrollView {
            VStack(spacing: 0) {
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
                    .onChange(of: selectedPeriod) { oldPeriod, newPeriod in
                        selectedDate = nil  // Clear selection when period changes
                        // Only update scroll position if period actually changed
                        if lastPeriod != newPeriod {
                            scrollManager.manager?.updatePeriod(newPeriod)
                            // Preserve scroll position if possible
                            // Only reset if period is not 5y (which causes jump)
                            if newPeriod != .fiveYear {
                                scrollPosition = calculateScrollPosition()
                            }
                            lastPeriod = newPeriod
                        }
                    }

                    // Value display
                    HStack(alignment: .top, spacing: 40) {
                        valueDisplay(data: data)

                        Spacer()

                        Button(action: { showAboutModal = true }) {
                            Image(systemName: "info.circle")
                                .font(.title3)
                                .foregroundColor(sectionColor)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 12)

                    // Chart
                    if !data.historicalValues.isEmpty {
                        biomarkerChart(data: data)
                            // Don't use .id(selectedPeriod) - it forces chart recreation, breaking scroll/x-axis
                            // Period changes are handled by onChange + scrollManager.updatePeriod()
                            .padding(.top, 16)
                            .padding(.bottom, 16)
                    } else {
                        emptyChartPlaceholder
                            .padding(.top, 16)
                            .padding(.bottom, 16)
                    }

                    // Status bar
                    statusBar(data: data)
                        .padding(.top, 8)
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                }
                .background(Color(uiColor: .systemGroupedBackground))
                .padding(.top, 16)

                // Records list
                if !data.historicalValues.isEmpty {
                    recordsList(data: data)
                        .padding(.top, 16)
                }

                Spacer(minLength: 32)
            }
        }
    }

    // MARK: - Value Display

    private func valueDisplay(data: BiomarkerDisplayData) -> some View {
        let pointsWithData = scrollManager.manager?.dataPointsWithValues ?? []
        let visiblePoints = getVisibleDataPoints()
        let hasVisibleData = !visiblePoints.isEmpty

        return VStack(alignment: .leading, spacing: 4) {
            let selectedValue = selectedDate.flatMap { date in
                pointsWithData.first { Calendar.current.isDate($0.date, equalTo: date, toGranularity: getDateGranularity()) }?.value
            }

            // Show "Value" when selected, "AVG" when showing average, nothing special for NO DATA
            Text(selectedDate != nil ? "Value" : (hasVisibleData ? "AVG" : ""))
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if let val = selectedValue {
                    // Show selected point value
                    Text(formatDisplayValue(val))
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundColor(sectionColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Text(data.unitDisplay)
                        .font(.title2)
                        .foregroundColor(.secondary)
                } else if hasVisibleData {
                    // Show average of visible data
                    let values = visiblePoints.map { $0.value }
                    let avgValue = values.reduce(0, +) / Double(values.count)

                    Text(formatDisplayValue(avgValue))
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundColor(sectionColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Text(data.unitDisplay)
                        .font(.title2)
                        .foregroundColor(.secondary)
                } else {
                    // No data in visible window - use "--" like modal
                    Text("--")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text(data.unitDisplay)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if let selectedDate = selectedDate {
                Text(formatSelectedDate(selectedDate))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                // Show date range for the visible period
                Text(visibleDateRangeString())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Chart

    /// Calendar component for current period (matches scroll manager)
    private var chartCalendarComponent: Calendar.Component {
        switch selectedPeriod {
        case .week: return .day
        case .month: return .day
        case .sixMonth: return .weekOfYear
        case .year: return .month
        case .fiveYear: return .month
        }
    }

    @ViewBuilder
    private func biomarkerChart(data: BiomarkerDisplayData) -> some View {
        // Use scroll manager data - only show points with actual values
        let chartPoints = scrollManager.manager?.chartData ?? []
        let pointsWithData = chartPoints.filter { $0.hasData }
        let calComponent = chartCalendarComponent

        Chart {
            // Invisible placeholder for all loaded points (establishes x-axis domain)
            // Use unit: parameter to match BiometricLineChart pattern
            ForEach(chartPoints) { point in
                PointMark(
                    x: .value("Date", point.date, unit: calComponent),
                    y: .value("Value", 0)
                )
                .opacity(0)
            }

            // Only show line/points for non-zero values
            ForEach(pointsWithData) { point in
                LineMark(
                    x: .value("Date", point.date, unit: calComponent),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(sectionColor)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3))

                // Point marks
                if let selectedDate = selectedDate,
                   Calendar.current.isDate(point.date, equalTo: selectedDate, toGranularity: getDateGranularity()) {
                    // Selected point (larger with outline)
                    PointMark(x: .value("Date", point.date, unit: calComponent), y: .value("Value", point.value))
                        .foregroundStyle(sectionColor)
                        .symbolSize(200)
                        .symbol {
                            Circle()
                                .strokeBorder(sectionColor, lineWidth: 3)
                                .background(Circle().fill(Color(uiColor: .systemBackground)))
                                .frame(width: 16, height: 16)
                        }
                } else {
                    // Regular point
                    PointMark(x: .value("Date", point.date, unit: calComponent), y: .value("Value", point.value))
                        .foregroundStyle(sectionColor)
                        .symbolSize(80)
                }
            }
        }
        // Don't use .id(selectedPeriod) - it forces full chart recreation which breaks scroll/x-axis
        .chartYScale(domain: calculateYDomain(data: data))
        .chartScrollableAxes(.horizontal)
        .chartScrollPosition(x: $scrollPosition)
        .chartXVisibleDomain(length: getVisibleDomainTimeInterval())
        .chartGesture { proxy in
            SpatialTapGesture()
                .onEnded { value in
                    if let tappedDate: Date = proxy.value(atX: value.location.x) {
                        // Find closest point with data
                        let closest = pointsWithData.min(by: {
                            abs($0.date.timeIntervalSince(tappedDate)) < abs($1.date.timeIntervalSince(tappedDate))
                        })
                        // Toggle selection
                        if let closestDate = closest?.date,
                           Calendar.current.isDate(selectedDate ?? Date.distantPast, equalTo: closestDate, toGranularity: getDateGranularity()) {
                            selectedDate = nil
                        } else {
                            selectedDate = closest?.date
                        }
                    }
                }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: getAxisStride(), count: 1)) { _ in
                AxisValueLabel(format: getAxisFormat())
                AxisGridLine()
                AxisTick()
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                if let yValue = value.as(Double.self) {
                    // Check if this is a range boundary
                    if let boundary = getRangeBoundaryLabel(for: yValue, ranges: data.ranges) {
                        AxisValueLabel {
                            Text(boundary)
                                .font(.caption2)
                        }
                    } else {
                        AxisValueLabel {
                            Text(formatAxisValue(yValue))
                                .font(.caption2)
                        }
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(Color.secondary.opacity(0.2))
            }
        }
        .frame(height: 220)
        .padding(.horizontal)
        .onChange(of: scrollPosition) { _, newPosition in
            scrollManager.manager?.handleScroll(position: newPosition)
        }

        // Loading indicators
        HStack {
            if scrollManager.manager?.isLoadingOlder == true {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if scrollManager.manager?.isLoadingNewer == true {
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

    // MARK: - Status Bar

    private func statusBar(data: BiomarkerDisplayData) -> some View {
        let samples = scrollManager.manager?.samples ?? data.historicalValues
        let recordCount = samples.count

        return Button {
            showRangeSelector = true
        } label: {
            HStack {
                Text(data.status.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Spacer()

                Text("\(recordCount) Record\(recordCount == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Records List

    private func recordsList(data: BiomarkerDisplayData) -> some View {
        let samples = scrollManager.manager?.samples ?? data.historicalValues

        return VStack(alignment: .leading, spacing: 16) {
            Text("Records")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.horizontal)

            ForEach(samples.prefix(3)) { sample in
                recordCard(sample: sample, data: data)
                    .padding(.horizontal)
            }

            if samples.count > 3 {
                NavigationLink(destination: AllBiomarkerRecordsView(
                    biomarkerName: biomarkerName,
                    data: data,
                    sectionColor: sectionColor,
                    scrollManagerWrapper: scrollManager
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
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
        }
    }

    private func recordCard(sample: BiomarkerSample, data: BiomarkerDisplayData) -> some View {
        Button {
            selectedRecordForDetail = sample
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "testtube.2")
                        .font(.system(size: 14))
                        .foregroundColor(sectionColor)

                    Text(biomarkerName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(sectionColor)

                    Spacer()

                    Text(formatShortDate(sample.sampleTime))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatDisplayValue(sample.value))
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(data.unitDisplay)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Status for this value
                let status = getStatusForValue(sample.value, ranges: data.ranges)
                Text(status.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading & Empty States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "testtube.2")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No Data Available")
                .font(.headline)

            Text("Add a lab result to start tracking \(biomarkerName)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Helper Functions

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

    /// Get visible data points (points with actual values in the visible window)
    private func getVisibleDataPoints() -> [BiomarkerChartPoint] {
        guard let manager = scrollManager.manager else { return [] }
        let calendar = Calendar.current
        let visibleDuration = manager.numberOfBars
        let endDate = calendar.date(byAdding: manager.calendarComponent, value: visibleDuration, to: scrollPosition) ?? scrollPosition

        return manager.dataPointsWithValues.filter { point in
            point.date >= scrollPosition && point.date <= endDate
        }
    }

    /// Format the visible date range as a string (always includes year for context)
    private func visibleDateRangeString() -> String {
        guard let manager = scrollManager.manager else { return "" }
        let calendar = Calendar.current
        let visibleDuration = manager.numberOfBars
        let endDate = calendar.date(byAdding: manager.calendarComponent, value: visibleDuration - 1, to: scrollPosition) ?? scrollPosition

        let formatter = DateFormatter()
        // Check if start and end are in same year
        let sameYear = calendar.component(.year, from: scrollPosition) == calendar.component(.year, from: endDate)

        switch selectedPeriod {
        case .year, .fiveYear:
            formatter.dateFormat = "MMM yyyy"
            return "\(formatter.string(from: scrollPosition)) - \(formatter.string(from: endDate))"
        default:
            // Always show year for context when scrolling
            if sameYear {
                let startFormatter = DateFormatter()
                startFormatter.dateFormat = "MMM d"
                let endFormatter = DateFormatter()
                endFormatter.dateFormat = "MMM d, yyyy"
                return "\(startFormatter.string(from: scrollPosition)) - \(endFormatter.string(from: endDate))"
            } else {
                formatter.dateFormat = "MMM d, yyyy"
                return "\(formatter.string(from: scrollPosition)) - \(formatter.string(from: endDate))"
            }
        }
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
        case .year, .fiveYear:
            // Show month name and year
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }
    }

    private func calculateYDomain(data: BiomarkerDisplayData) -> ClosedRange<Double> {
        let pointsWithData = scrollManager.manager?.dataPointsWithValues ?? []
        let values = pointsWithData.isEmpty ? data.historicalValues.map { $0.value } : pointsWithData.map { $0.value }

        // If no data, use range bounds to define a sensible Y-axis
        if values.isEmpty {
            // Try to derive domain from ranges
            let allLows = data.ranges.compactMap { $0.rangeLow }
            let allHighs = data.ranges.compactMap { $0.rangeHigh }

            if !allLows.isEmpty || !allHighs.isEmpty {
                let minBound = allLows.min() ?? 0
                let maxBound = allHighs.max() ?? (minBound + 100)
                let buffer = (maxBound - minBound) * 0.1
                return max(0, minBound - buffer)...(maxBound + buffer)
            }
            // Fallback for no ranges
            return 0...100
        }

        let dataMin = values.min() ?? 0
        let dataMax = values.max() ?? 100

        let range = dataMax - dataMin
        // Ensure minimum padding to prevent Y-axis from disappearing with single data point
        let buffer = max(range * 0.15, dataMax * 0.1, 5.0)

        return max(0, dataMin - buffer)...(dataMax + buffer)
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

    private func calculateScrollPosition() -> Date {
        // Position the scroll so the most recent data appears on the right side
        // Use calendar-based positioning (like BiometricLineChart) for consistent behavior
        let now = Date()
        guard let manager = scrollManager.manager else {
            // Fallback if manager not initialized
            let visibleDomain = getVisibleDomainTimeInterval()
            return now.addingTimeInterval(-visibleDomain)
        }

        // Use 90% offset so "now" appears near (but not at) the right edge
        let visibleDuration = manager.numberOfBars
        let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
        return Calendar.current.date(
            byAdding: manager.calendarComponent,
            value: -offsetFromEnd,
            to: now
        ) ?? now
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

    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }

    private func getStatusForValue(_ value: Double, ranges: [BiomarkerRange]) -> String {
        for range in ranges.sorted(by: { ($0.rangeLow ?? 0) < ($1.rangeLow ?? 0) }) {
            let low = range.rangeLow ?? Double.leastNormalMagnitude
            let high = range.rangeHigh ?? Double.greatestFiniteMagnitude
            if value >= low && value < high {
                return range.rangeName
            }
        }
        return "Unknown"
    }

    /// Get a label for a range boundary value (with < or > for open-ended ranges)
    private func getRangeBoundaryLabel(for value: Double, ranges: [BiomarkerRange]) -> String? {
        for range in ranges {
            // Check if this is the low boundary
            if let low = range.rangeLow, abs(low - value) < 0.5 {
                if range.rangeHigh == nil {
                    // This is a "> low" range
                    return "> \(formatAxisValue(low))"
                }
            }

            // Check if this is the high boundary
            if let high = range.rangeHigh, abs(high - value) < 0.5 {
                if range.rangeLow == nil {
                    // This is a "< high" range
                    return "< \(formatAxisValue(high))"
                }
            }
        }
        return nil
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
}

// MARK: - All Records View

struct AllBiomarkerRecordsView: View {
    let biomarkerName: String
    let data: BiomarkerDisplayData
    let sectionColor: Color
    @ObservedObject var scrollManagerWrapper: BiomarkerChartScrollManagerWrapper

    @State private var selectedRecord: BiomarkerSample?

    private var samples: [BiomarkerSample] {
        scrollManagerWrapper.manager?.samples ?? data.historicalValues
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(samples) { sample in
                    Button {
                        selectedRecord = sample
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "testtube.2")
                                    .font(.system(size: 14))
                                    .foregroundColor(sectionColor)

                                Text(biomarkerName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(sectionColor)

                                Spacer()

                                Text(formatDate(sample.sampleTime))
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(formatValue(sample.value))
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(.primary)

                                Text(data.unitDisplay)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            let status = getStatusForValue(sample.value)
                            Text(status.uppercased())
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Records")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedRecord) { sample in
            BiomarkerRecordDetailView(
                biomarkerName: biomarkerName,
                sample: sample,
                ranges: data.ranges,
                unitDisplay: data.unitDisplay,
                sectionColor: sectionColor
            )
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func formatValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 && value < 10000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private func getStatusForValue(_ value: Double) -> String {
        for range in data.ranges.sorted(by: { ($0.rangeLow ?? 0) < ($1.rangeLow ?? 0) }) {
            let low = range.rangeLow ?? Double.leastNormalMagnitude
            let high = range.rangeHigh ?? Double.greatestFiniteMagnitude
            if value >= low && value < high {
                return range.rangeName
            }
        }
        return "Unknown"
    }
}

// MARK: - Time Period Enum

enum BiomarkerTimePeriod: String, CaseIterable, Identifiable {
    case week = "W"
    case month = "M"
    case sixMonth = "6M"
    case year = "Y"
    case fiveYear = "5Y"

    var id: String { rawValue }
}

// MARK: - Scroll Manager Wrapper

/// Wrapper class to allow lazy initialization of the scroll manager
/// This is needed because we don't have quantityType until after data loads
@MainActor
class BiomarkerChartScrollManagerWrapper: ObservableObject {
    @Published var manager: BiomarkerChartScrollManager?

    var isInitialized: Bool { manager != nil }

    func initialize(period: BiomarkerTimePeriod, quantityType: String) {
        guard manager == nil else { return }
        manager = BiomarkerChartScrollManager(period: period, quantityType: quantityType)
    }
}

#Preview {
    NavigationStack {
        GenericBiomarkerDetailView(
            biomarkerName: "HDL",
            viewModel: BiomarkerViewModel()
        )
    }
}
