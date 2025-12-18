//
//  HeartRateRangeChart.swift
//  WellPath
//
//  Range/band chart showing heart rate over time
//  Displays shaded area between min and max values for each period
//  Includes H (hourly) view for minute-by-minute data - unique to Heart Rate
//

import SwiftUI
import Charts
import Supabase

/// Heart Rate specific time periods - includes H for minute-by-minute view
enum HRTimePeriod: String, CaseIterable {
    case hour = "H"      // Minute-by-minute for last hour
    case day = "D"       // Hourly aggregates
    case week = "W"      // Daily aggregates
    case month = "M"     // Daily aggregates
    case sixMonth = "6M" // Weekly aggregates
    case year = "Y"      // Monthly aggregates

    var numberOfBars: Int {
        switch self {
        case .hour: return 60     // 60 minutes
        case .day: return 24      // 24 hours
        case .week: return 7      // 7 days
        case .month: return 33    // 33 days
        case .sixMonth: return 26 // 26 weeks
        case .year: return 12     // 12 months
        }
    }

    var loadChunkSize: Int {
        switch self {
        case .hour: return 120    // Load 2 hours at a time
        case .day: return 48      // Load 2 days at a time
        case .week: return 28     // Load 4 weeks at a time
        case .month: return 66    // Load 2 months at a time
        case .sixMonth: return 52 // Load 1 year at a time
        case .year: return 24     // Load 2 years at a time
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .hour: return .minute
        case .day: return .hour
        case .week, .month: return .day
        case .sixMonth: return .weekOfYear
        case .year: return .month
        }
    }

    /// Chart unit for x-axis binning - use second for minute data to avoid binning issues
    var chartUnit: Calendar.Component {
        switch self {
        case .hour: return .second  // Use second to plot individual minutes without binning
        case .day: return .hour
        case .week, .month: return .day
        case .sixMonth: return .weekOfYear
        case .year: return .month
        }
    }

    /// Convert to standard TimePeriod for compatible operations
    var asTimePeriod: TimePeriod? {
        switch self {
        case .hour: return nil  // No equivalent
        case .day: return .day
        case .week: return .week
        case .month: return .month
        case .sixMonth: return .sixMonth
        case .year: return .year
        }
    }
}

struct HeartRateRangeChart: View {
    let color: Color
    var showAbout: Binding<Bool>? = nil

    @State private var selectedPeriod: HRTimePeriod = .week
    @State private var selectedPointDate: Date?
    @StateObject private var scrollManager: HRChartScrollManager
    @State private var scrollPosition: Date
    @State private var unitDisplayLoaded: Bool = false

    private var selectedPoint: HRDataPoint? {
        guard let selectedDate = selectedPointDate else { return nil }
        return scrollManager.chartData.first(where: {
            Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: getDateGranularity())
        })
    }

    private var dataPointsWithValues: [HRDataPoint] {
        scrollManager.chartData.filter { $0.maxValue > 0 }
    }

    /// Bar width varies by time period for optimal visual density
    private var barWidth: CGFloat {
        switch selectedPeriod {
        case .hour: return 3
        case .day: return 8
        case .week: return 6
        case .month: return 4
        case .sixMonth: return 5
        case .year: return 6
        }
    }

    private var displayUnit: String {
        _ = unitDisplayLoaded
        return UnitConversionService.shared.getUIDisplay(for: "beats_per_minute")
    }

    init(color: Color, showAbout: Binding<Bool>? = nil) {
        self.color = color
        self.showAbout = showAbout

        let now = Date()
        let initialPeriod = HRTimePeriod.week
        let visibleDuration = initialPeriod.numberOfBars
        let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
        let scrollStart = Calendar.current.date(
            byAdding: initialPeriod.calendarComponent,
            value: -offsetFromEnd,
            to: now
        ) ?? now

        _scrollPosition = State(initialValue: scrollStart)
        _scrollManager = StateObject(wrappedValue: HRChartScrollManager(period: initialPeriod))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Time period picker - includes H for minute-by-minute view
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(HRTimePeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, MetricScreenLayout.pickerTopPadding)
            .onChange(of: selectedPeriod) { oldValue, newPeriod in
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

            // Value display - shows selected point or range for visible window
            HStack(alignment: .top, spacing: 40) {
                VStack(alignment: .leading, spacing: 4) {
                    if let selected = selectedPoint {
                        Text("RANGE")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatRangeValue(min: selected.minValue, max: selected.maxValue))
                                .font(.system(size: 48, weight: .semibold))
                            Text(displayUnit)
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        Text(formatSelectedDate(selected.date))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("RANGE")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        let overallRange = getOverallRange()
                        if let range = overallRange {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(formatRangeValue(min: range.min, max: range.max))
                                    .font(.system(size: 48, weight: .semibold))
                                Text(displayUnit)
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("--")
                                .font(.system(size: 48, weight: .semibold))
                        }
                        Text(visibleDateRangeString())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Info button
                if let showAboutBinding = showAbout {
                    Button(action: {
                        withAnimation {
                            showAboutBinding.wrappedValue = true
                        }
                    }) {
                        Image(systemName: "info.circle")
                            .font(.title3)
                            .foregroundColor(color)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, MetricScreenLayout.headerTopPadding)

            // Range chart - Apple Health style with range bars
            if scrollManager.isLoading {
                // Show loading indicator while data loads
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 280)
                .frame(maxWidth: .infinity)
            } else {
            Chart(scrollManager.chartData) { dataPoint in
                // Invisible placeholder for x-axis domain
                PointMark(
                    x: .value("Date", dataPoint.date, unit: selectedPeriod.chartUnit),
                    y: .value("Value", 0)
                )
                .opacity(0)

                // Only show marks for valid readings
                if dataPoint.maxValue > 0 {
                    let isSelected = selectedPointDate != nil &&
                        Calendar.current.isDate(dataPoint.date, equalTo: selectedPointDate!, toGranularity: getDateGranularity())

                    if dataPoint.isRange {
                        // Range bar (min to max)
                        BarMark(
                            x: .value("Date", dataPoint.date, unit: selectedPeriod.chartUnit),
                            yStart: .value("Min", dataPoint.minValue),
                            yEnd: .value("Max", dataPoint.maxValue),
                            width: .fixed(barWidth)
                        )
                        .foregroundStyle(isSelected ? color : color.opacity(0.85))
                        .clipShape(Capsule())
                    } else {
                        // Single value - show as point
                        PointMark(
                            x: .value("Date", dataPoint.date, unit: selectedPeriod.chartUnit),
                            y: .value("Value", dataPoint.maxValue)
                        )
                        .foregroundStyle(isSelected ? color : color.opacity(0.85))
                        .symbolSize(isSelected ? 80 : 50)
                    }
                }
            }
            .chartYScale(domain: yAxisDomain)
            .frame(height: 280)
            .chartScrollableAxes(.horizontal)
            .chartScrollPosition(x: $scrollPosition)
            .chartXVisibleDomain(length: getVisibleDomainTimeInterval())
            .chartGesture { proxy in
                SpatialTapGesture()
                    .onEnded { value in
                        if let tappedDate: Date = proxy.value(atX: value.location.x) {
                            let closest = scrollManager.chartData
                                .filter { $0.maxValue > 0 }
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
            .onChange(of: scrollPosition) { oldValue, newValue in
                handleChartScrolling(position: newValue)
            }
            .onChange(of: dataPointsWithValues.count) { oldValue, newValue in
                if oldValue == 0 && newValue > 0 {
                    scrollToMostRecentData()
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
                            Text("\(Int(numValue))")
                        }
                    }
                    AxisGridLine(
                        stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3])
                    )
                    .foregroundStyle(Color.secondary.opacity(0.2))
                }
            }
            .chartPlotStyle { plotArea in
                plotArea.frame(height: 280)
            }
            .padding(.horizontal)
            .padding(.top, MetricScreenLayout.chartTopPadding)
            .padding(.bottom, MetricScreenLayout.chartBottomPadding)
            }  // End of else block

            // Loading indicators
            HStack {
                if scrollManager.isLoadingOlder {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading older data...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if scrollManager.isLoadingNewer {
                    Text("Loading newer data...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .frame(height: 20)
            .padding(.horizontal)
            }
            .padding(.vertical)
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .task {
            await UnitConversionService.shared.loadConversions()
            unitDisplayLoaded = true
        }
    }

    // MARK: - Computed Properties

    private var yAxisDomain: ClosedRange<Double> {
        let values = scrollManager.chartData
            .flatMap { [$0.minValue, $0.maxValue] }
            .filter { $0 > 0 }

        guard !values.isEmpty else { return 40...180 }

        let minVal = values.min() ?? 40
        let maxVal = values.max() ?? 180
        let padding = (maxVal - minVal) * 0.15

        return max(30, minVal - padding)...min(220, maxVal + padding)
    }

    // MARK: - Helper Functions

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

        if let newestDate = scrollManager.chartData.first?.date {
            let diff = calendar.dateComponents([component], from: position, to: newestDate)
            let units = abs(diff.value(for: component) ?? 0)

            if units < 5 && !scrollManager.isLoadingNewer {
                scrollManager.loadNewerData()
            }
        }
    }

    private func getLatestReading() -> HRDataPoint? {
        scrollManager.chartData
            .filter { $0.maxValue > 0 }
            .sorted { $0.date > $1.date }
            .first
    }

    private func scrollToMostRecentData() {
        guard let latestData = getLatestReading() else { return }

        let calendar = Calendar.current
        let visibleBars = selectedPeriod.numberOfBars
        if let newPosition = calendar.date(byAdding: selectedPeriod.calendarComponent, value: -(visibleBars - 1), to: latestData.date) {
            scrollPosition = newPosition
        }
    }

    private func formatRangeValue(min: Double, max: Double) -> String {
        if min == max || min == 0 {
            return "\(Int(max))"
        } else {
            return "\(Int(min))-\(Int(max))"
        }
    }

    private func getOverallRange() -> (min: Double, max: Double)? {
        let calendar = Calendar.current
        let visibleDuration = selectedPeriod.numberOfBars
        let endDate = calendar.date(byAdding: selectedPeriod.calendarComponent, value: visibleDuration, to: scrollPosition) ?? scrollPosition

        let visiblePoints = dataPointsWithValues.filter { point in
            point.date >= scrollPosition && point.date <= endDate
        }

        guard !visiblePoints.isEmpty else { return nil }

        let minVal = visiblePoints.map { $0.minValue }.filter { $0 > 0 }.min() ?? 0
        let maxVal = visiblePoints.map { $0.maxValue }.max() ?? 0

        guard maxVal > 0 else { return nil }

        return (minVal, maxVal)
    }

    private func visibleDateRangeString() -> String {
        let calendar = Calendar.current
        let visibleDuration = selectedPeriod.numberOfBars
        let endDate = calendar.date(byAdding: selectedPeriod.calendarComponent, value: visibleDuration - 1, to: scrollPosition) ?? scrollPosition

        let sameYear = calendar.component(.year, from: scrollPosition) == calendar.component(.year, from: endDate)

        let formatter = DateFormatter()

        switch selectedPeriod {
        case .hour:
            // Show time range for hour view
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d, yyyy"
            return "\(timeFormatter.string(from: scrollPosition)) - \(timeFormatter.string(from: endDate)), \(dateFormatter.string(from: scrollPosition))"
        case .year:
            formatter.dateFormat = "MMM yyyy"
            return "\(formatter.string(from: scrollPosition)) - \(formatter.string(from: endDate))"
        default:
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

    private func formatSelectedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()

        switch selectedPeriod {
        case .hour:
            formatter.dateFormat = "h:mm a"
        case .day:
            formatter.dateFormat = "MMM d, yyyy, h:mm a"
        case .week, .month:
            formatter.dateFormat = "MMM d, yyyy"
        case .sixMonth:
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
            formatter.dateFormat = "MMM yyyy"
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
        case .hour: return 60 * 60              // 1 hour
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
        case .hour: return 15     // Every 15 minutes
        case .day: return 6       // Every 6 hours
        case .week, .month, .sixMonth, .year: return 1
        }
    }

    private func getAxisLabelFormat() -> Date.FormatStyle {
        switch selectedPeriod {
        case .hour: return .dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute()
        case .day: return .dateTime.hour(.defaultDigits(amPM: .abbreviated))
        case .week: return .dateTime.weekday(.narrow)
        case .month: return .dateTime.day(.defaultDigits)
        case .sixMonth: return .dateTime.month(.abbreviated)
        case .year: return .dateTime.month(.narrow)
        }
    }
}

// MARK: - HR Data Point (with min/max ranges for aggregation)

struct HRDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let minValue: Double
    let maxValue: Double
    let readingCount: Int

    var isRange: Bool { minValue != maxValue && minValue > 0 }

    init(date: Date, minValue: Double, maxValue: Double, readingCount: Int = 1) {
        self.date = date
        self.minValue = minValue
        self.maxValue = maxValue
        self.readingCount = readingCount
    }

    init(date: Date, value: Double) {
        self.date = date
        self.minValue = value
        self.maxValue = value
        self.readingCount = 1
    }
}

// MARK: - HR Chart Scroll Manager
// Database-driven: queries display_views_dependencies for sample_quantity_type
// Caches all raw samples once, then re-buckets locally for each period (no DB calls on period switch)

/// Raw heart rate reading from database
private struct HRRawReading {
    let value: Double
    let timestamp: Date
}

@MainActor
class HRChartScrollManager: ObservableObject {
    @Published var chartData: [HRDataPoint] = []
    @Published var isLoadingOlder = false
    @Published var isLoadingNewer = false
    @Published var isLoading = false  // Main loading state for period switches

    // Cache of raw readings for current window
    private var rawReadingsCache: [HRRawReading] = []

    // Current visible window for infinite scroll
    private var currentWindowStart: Date = Date()
    private var currentWindowEnd: Date = Date()

    // Track data boundaries to know when we've hit the edge
    private var oldestDataTimestamp: Date?
    private var newestDataTimestamp: Date?
    private var isInitialized = false

    private var selectedPeriod: HRTimePeriod
    private let viewId: String
    private var quantityType: String?
    private var patientId: UUID?
    private let supabase = SupabaseManager.shared.client

    init(period: HRTimePeriod, viewId: String = "DISP_HEART_RATE") {
        self.selectedPeriod = period
        self.viewId = viewId
        isLoading = true
        Task { await initialize() }
    }

    func updatePeriod(_ period: HRTimePeriod) {
        guard period != selectedPeriod else { return }
        self.selectedPeriod = period

        // Clear data and show loading state immediately
        chartData = []
        isLoading = true

        // Reset window and reload for new period
        Task { await loadInitialWindow() }
    }

    func loadOlderData() {
        guard isInitialized, !isLoadingOlder else { return }

        // Check if we've already reached the oldest data
        if let oldest = oldestDataTimestamp, currentWindowStart <= oldest {
            return  // No more data to load
        }

        Task { await loadOlder() }
    }

    func loadNewerData() {
        guard isInitialized, !isLoadingNewer else { return }

        // Check if we're already at present time
        let now = Date()
        if currentWindowEnd >= now {
            return  // Already at present
        }

        Task { await loadNewer() }
    }

    /// Initialize by getting quantity type and patient ID, then load initial window
    private func initialize() async {
        do {
            // 1. Query display_views_dependencies to get sample_quantity_type
            struct DependencyMapping: Codable {
                let sampleQuantityType: String?

                enum CodingKeys: String, CodingKey {
                    case sampleQuantityType = "sample_quantity_type"
                }
            }

            let dependencies: [DependencyMapping] = try await supabase
                .from("display_views_dependencies")
                .select("sample_quantity_type")
                .eq("view_id", value: viewId)
                .eq("is_primary", value: true)
                .limit(1)
                .execute()
                .value

            guard let qType = dependencies.first?.sampleQuantityType else {
                print("⚠️ No sample_quantity_type dependency for \(viewId)")
                return
            }

            quantityType = qType
            patientId = try await supabase.auth.session.user.id

            print("📊 HRChart: Initialized with quantity_type '\(qType)'")

            // Get data boundaries (oldest/newest timestamps)
            await loadDataBoundaries()

            // Load initial window
            await loadInitialWindow()

            isInitialized = true
            isLoading = false

        } catch {
            print("❌ Error initializing HRChart: \(error)")
            isLoading = false
        }
    }

    /// Get the oldest and newest timestamps in the data
    private func loadDataBoundaries() async {
        guard let quantityType = quantityType, let patientId = patientId else { return }

        do {
            struct BoundaryResult: Codable {
                let startTime: Date

                enum CodingKeys: String, CodingKey {
                    case startTime = "start_time"
                }
            }

            let decoder = makeDecoder()

            // Get oldest
            let oldestData = try await supabase
                .from("patient_quantity_samples")
                .select("start_time")
                .eq("patient_id", value: patientId)
                .eq("quantity_type", value: quantityType)
                .order("start_time", ascending: true)
                .limit(1)
                .execute()
                .data

            if let oldest = try? decoder.decode([BoundaryResult].self, from: oldestData).first {
                oldestDataTimestamp = oldest.startTime
            }

            // Get newest
            let newestData = try await supabase
                .from("patient_quantity_samples")
                .select("start_time")
                .eq("patient_id", value: patientId)
                .eq("quantity_type", value: quantityType)
                .order("start_time", ascending: false)
                .limit(1)
                .execute()
                .data

            if let newest = try? decoder.decode([BoundaryResult].self, from: newestData).first {
                newestDataTimestamp = newest.startTime
            }

            print("📊 HRChart: Data range \(oldestDataTimestamp?.description ?? "nil") to \(newestDataTimestamp?.description ?? "nil")")

        } catch {
            print("❌ Error loading data boundaries: \(error)")
        }
    }

    /// Load initial window of data
    private func loadInitialWindow() async {
        let now = Date()

        // Set initial window
        let (startDate, endDate) = getInitialWindow(now: now)
        currentWindowStart = startDate
        currentWindowEnd = endDate

        // Load data for this window
        await loadDataForRange(from: startDate, to: endDate, replace: true)

        isLoading = false
    }

    /// Load older data when scrolling backwards
    private func loadOlder() async {
        isLoadingOlder = true
        defer { isLoadingOlder = false }

        let calendar = Calendar.current
        let extensionAmount = getWindowExtensionAmount()
        let newStart = calendar.date(byAdding: selectedPeriod.calendarComponent, value: -extensionAmount, to: currentWindowStart) ?? currentWindowStart

        // Load data for the new range only
        await loadDataForRange(from: newStart, to: currentWindowStart, replace: false)
        currentWindowStart = newStart

        // Rebuild chart with all cached data
        buildChartDataFromCache()
    }

    /// Load newer data when scrolling forwards
    private func loadNewer() async {
        isLoadingNewer = true
        defer { isLoadingNewer = false }

        let calendar = Calendar.current
        let extensionAmount = getWindowExtensionAmount()
        let newEnd = calendar.date(byAdding: selectedPeriod.calendarComponent, value: extensionAmount, to: currentWindowEnd) ?? currentWindowEnd

        // Load data for the new range only
        await loadDataForRange(from: currentWindowEnd, to: newEnd, replace: false)
        currentWindowEnd = newEnd

        // Rebuild chart with all cached data
        buildChartDataFromCache()
    }

    /// Load data for a specific date range from database
    private func loadDataForRange(from startDate: Date, to endDate: Date, replace: Bool) async {
        guard let quantityType = quantityType, let patientId = patientId else { return }

        do {
            struct QuantityResult: Codable {
                let quantityValue: Double
                let startTime: Date

                enum CodingKeys: String, CodingKey {
                    case quantityValue = "quantity_value"
                    case startTime = "start_time"
                }
            }

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let data = try await supabase
                .from("patient_quantity_samples")
                .select("quantity_value, start_time")
                .eq("patient_id", value: patientId)
                .eq("quantity_type", value: quantityType)
                .gte("start_time", value: formatter.string(from: startDate))
                .lte("start_time", value: formatter.string(from: endDate))
                .order("start_time", ascending: false)
                .execute()
                .data

            let results = try makeDecoder().decode([QuantityResult].self, from: data)
            let newReadings = results.map { HRRawReading(value: $0.quantityValue, timestamp: $0.startTime) }

            if replace {
                rawReadingsCache = newReadings
            } else {
                // Merge with existing cache, avoiding duplicates
                let existingTimestamps = Set(rawReadingsCache.map { $0.timestamp })
                let uniqueNewReadings = newReadings.filter { !existingTimestamps.contains($0.timestamp) }
                rawReadingsCache.append(contentsOf: uniqueNewReadings)
            }

            print("📊 HRChart: Loaded \(newReadings.count) readings for range, cache now has \(rawReadingsCache.count)")

            if replace {
                buildChartDataFromCache()
            }

        } catch {
            print("❌ Error loading HR data for range: \(error)")
        }
    }

    /// How many units to extend the window by when scrolling
    private func getWindowExtensionAmount() -> Int {
        switch selectedPeriod {
        case .hour: return 60     // 60 more minutes
        case .day: return 24      // 24 more hours
        case .week: return 14     // 2 more weeks
        case .month: return 30    // 30 more days
        case .sixMonth: return 13 // 13 more weeks
        case .year: return 6      // 6 more months
        }
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            let iso8601 = ISO8601DateFormatter()
            iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601.date(from: dateString) {
                return date
            }

            iso8601.formatOptions = [.withInternetDateTime]
            if let date = iso8601.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }
        return decoder
    }

    /// Build chart data from the cached readings
    private func buildChartDataFromCache() {
        let calendar = Calendar.current

        // Generate timeline for current window
        var timeline = generateEmptyTimeline(from: currentWindowStart, to: currentWindowEnd)

        // Bucket raw readings by current period's granularity
        var bucketedData: [Date: (min: Double, max: Double, count: Int)] = [:]

        for reading in rawReadingsCache {
            let bucketKey = getPeriodKey(for: reading.timestamp, calendar: calendar)

            if var existing = bucketedData[bucketKey] {
                existing.min = min(existing.min, reading.value)
                existing.max = max(existing.max, reading.value)
                existing.count += 1
                bucketedData[bucketKey] = existing
            } else {
                bucketedData[bucketKey] = (min: reading.value, max: reading.value, count: 1)
            }
        }

        // Overlay bucketed data onto timeline
        for (bucketDate, data) in bucketedData {
            if let index = timeline.firstIndex(where: {
                calendar.isDate($0.date, equalTo: bucketDate, toGranularity: selectedPeriod.calendarComponent)
            }) {
                timeline[index] = HRDataPoint(
                    date: bucketDate,
                    minValue: data.min,
                    maxValue: data.max,
                    readingCount: data.count
                )
            }
        }

        chartData = timeline.sorted { $0.date > $1.date }
    }


    /// Get initial window size for each period - reasonable starting size that extends with scroll
    private func getInitialWindow(now: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current

        let start: Date
        let end: Date

        switch selectedPeriod {
        case .hour:
            // Start with 2 hours of minute data (120 slots) - extends on scroll
            start = calendar.date(byAdding: .hour, value: -2, to: now) ?? now
            end = calendar.date(byAdding: .minute, value: 5, to: now) ?? now
        case .day:
            // Start with 2 weeks of hourly data
            start = calendar.date(byAdding: .day, value: -14, to: now) ?? now
            end = calendar.date(byAdding: .hour, value: 6, to: now) ?? now
        case .week:
            // Start with 3 months of daily data
            start = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            end = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        case .month:
            // Start with 6 months of daily data
            start = calendar.date(byAdding: .month, value: -6, to: now) ?? now
            end = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        case .sixMonth:
            // Start with 2 years of weekly data
            start = calendar.date(byAdding: .year, value: -2, to: now) ?? now
            end = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        case .year:
            // Start with 5 years of monthly data
            start = calendar.date(byAdding: .year, value: -5, to: now) ?? now
            end = calendar.date(byAdding: .month, value: 1, to: now) ?? now
        }

        return (start, end)
    }

    private func generateEmptyTimeline(from startDate: Date, to endDate: Date) -> [HRDataPoint] {
        var timeline: [HRDataPoint] = []
        var currentDate = startDate
        let calendar = Calendar.current
        let component = selectedPeriod.calendarComponent

        while currentDate <= endDate {
            timeline.append(HRDataPoint(date: currentDate, minValue: 0, maxValue: 0, readingCount: 0))
            currentDate = calendar.date(byAdding: component, value: 1, to: currentDate) ?? endDate
        }

        return timeline
    }

    private func getPeriodKey(for date: Date, calendar: Calendar) -> Date {
        switch selectedPeriod {
        case .hour:
            // For H view, each minute is a separate point
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            return calendar.date(from: components) ?? date
        case .day:
            let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
            return calendar.date(from: components) ?? date
        case .week, .month:
            return calendar.startOfDay(for: date)
        case .sixMonth:
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return calendar.date(from: components) ?? date
        case .year:
            let components = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: components) ?? date
        }
    }
}

#Preview {
    HeartRateRangeChart(color: .red)
}
