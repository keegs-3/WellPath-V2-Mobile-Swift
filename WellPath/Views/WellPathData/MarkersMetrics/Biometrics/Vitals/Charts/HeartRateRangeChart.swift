//
//  HeartRateRangeChart.swift
//  WellPath
//
//  Range/band chart showing heart rate over time
//  Displays shaded area between min and max values for each period
//

import SwiftUI
import Charts
import Supabase

struct HeartRateRangeChart: View {
    let color: Color
    var showAbout: Binding<Bool>? = nil

    @State private var selectedPeriod: TimePeriod = .week
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
        let initialPeriod = TimePeriod.week
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
                // Time period picker
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
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
            Chart(scrollManager.chartData) { dataPoint in
                // Invisible placeholder for x-axis domain
                PointMark(
                    x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
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
                            x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
                            yStart: .value("Min", dataPoint.minValue),
                            yEnd: .value("Max", dataPoint.maxValue),
                            width: .fixed(barWidth)
                        )
                        .foregroundStyle(isSelected ? color : color.opacity(0.85))
                        .clipShape(Capsule())
                    } else {
                        // Single value - show as point
                        PointMark(
                            x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
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
        case .week, .month, .sixMonth, .year: return 1
        }
    }

    private func getAxisLabelFormat() -> Date.FormatStyle {
        switch selectedPeriod {
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

@MainActor
class HRChartScrollManager: ObservableObject {
    @Published var chartData: [HRDataPoint] = []
    @Published var isLoadingOlder = false
    @Published var isLoadingNewer = false

    private var oldestDate: Date
    private var newestDate: Date
    private var selectedPeriod: TimePeriod
    private let supabase = SupabaseManager.shared.client

    init(period: TimePeriod) {
        self.selectedPeriod = period

        let now = Date()
        self.newestDate = Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now

        switch period {
        case .day:
            self.oldestDate = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        case .week:
            self.oldestDate = Calendar.current.date(byAdding: .weekOfYear, value: -12, to: now) ?? now
        case .month:
            self.oldestDate = Calendar.current.date(byAdding: .month, value: -12, to: now) ?? now
        case .sixMonth:
            self.oldestDate = Calendar.current.date(byAdding: .month, value: -24, to: now) ?? now
        case .year:
            self.oldestDate = Calendar.current.date(byAdding: .year, value: -5, to: now) ?? now
        }

        Task { await loadInitialData() }
    }

    func updatePeriod(_ period: TimePeriod) {
        self.selectedPeriod = period

        let now = Date()
        self.newestDate = Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now

        switch period {
        case .day:
            self.oldestDate = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        case .week:
            self.oldestDate = Calendar.current.date(byAdding: .weekOfYear, value: -12, to: now) ?? now
        case .month:
            self.oldestDate = Calendar.current.date(byAdding: .month, value: -12, to: now) ?? now
        case .sixMonth:
            self.oldestDate = Calendar.current.date(byAdding: .month, value: -24, to: now) ?? now
        case .year:
            self.oldestDate = Calendar.current.date(byAdding: .year, value: -5, to: now) ?? now
        }

        chartData.removeAll()
        Task { await loadInitialData() }
    }

    func loadOlderData() {
        guard !isLoadingOlder else { return }
        isLoadingOlder = true

        Task {
            let calendar = Calendar.current
            let component = selectedPeriod.calendarComponent
            let loadAmount = -selectedPeriod.loadChunkSize

            let tenYearsAgo = calendar.date(byAdding: .year, value: -10, to: Date()) ?? Date()
            guard oldestDate > tenYearsAgo else {
                isLoadingOlder = false
                return
            }

            let newOldestDate = calendar.date(byAdding: component, value: loadAmount, to: oldestDate) ?? oldestDate
            let cappedOldestDate = max(newOldestDate, tenYearsAgo)

            await loadDataRange(from: cappedOldestDate, to: oldestDate)
            oldestDate = cappedOldestDate
            isLoadingOlder = false
        }
    }

    func loadNewerData() {
        guard !isLoadingNewer else { return }
        isLoadingNewer = true

        Task {
            let calendar = Calendar.current
            let component = selectedPeriod.calendarComponent
            let loadAmount = selectedPeriod.loadChunkSize

            let newNewestDate = calendar.date(byAdding: component, value: loadAmount, to: newestDate) ?? newestDate

            await loadDataRange(from: newestDate, to: newNewestDate)
            newestDate = newNewestDate
            isLoadingNewer = false
        }
    }

    private func loadInitialData() async {
        await loadDataRange(from: oldestDate, to: newestDate)
    }

    private func loadDataRange(from startDate: Date, to endDate: Date) async {
        var timeline = generateEmptyTimeline(from: startDate, to: endDate)
        let dataPoints = await fetchDataPoints(from: startDate, to: endDate)

        for dataPoint in dataPoints {
            if let index = timeline.firstIndex(where: {
                Calendar.current.isDate($0.date, equalTo: dataPoint.date, toGranularity: selectedPeriod.calendarComponent)
            }) {
                timeline[index] = dataPoint
            }
        }

        await MainActor.run {
            let existingDates = Set(chartData.map { $0.date })
            let newPoints = timeline.filter { !existingDates.contains($0.date) }
            chartData.append(contentsOf: newPoints)
            chartData.sort { $0.date > $1.date }
        }
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

    private func fetchDataPoints(from startDate: Date, to endDate: Date) async -> [HRDataPoint] {
        do {
            let patientId = try await supabase.auth.session.user.id

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            struct SeriesResult: Codable {
                let value: Double
                let timestamp: Date

                enum CodingKeys: String, CodingKey {
                    case value
                    case timestamp
                }
            }

            // Custom decoder for Supabase timestamps
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

            let data = try await supabase
                .from("patient_series_samples")
                .select("value, timestamp")
                .eq("patient_id", value: patientId)
                .eq("series_type", value: "heart_rate_series")
                .gte("timestamp", value: formatter.string(from: startDate))
                .lte("timestamp", value: formatter.string(from: endDate))
                .order("timestamp", ascending: false)
                .execute()
                .data

            let results = try decoder.decode([SeriesResult].self, from: data)

            // Group by period and aggregate min/max
            var groupedByPeriod: [Date: [Double]] = [:]
            let calendar = Calendar.current

            for reading in results {
                let periodKey = getPeriodKey(for: reading.timestamp, calendar: calendar)
                groupedByPeriod[periodKey, default: []].append(reading.value)
            }

            return groupedByPeriod.compactMap { date, values in
                guard !values.isEmpty else { return nil }

                let minVal = values.min() ?? 0
                let maxVal = values.max() ?? 0
                let count = values.count

                return HRDataPoint(date: date, minValue: minVal, maxValue: maxVal, readingCount: count)
            }

        } catch {
            print("Error fetching HR data: \(error)")
            return []
        }
    }

    private func getPeriodKey(for date: Date, calendar: Calendar) -> Date {
        switch selectedPeriod {
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
