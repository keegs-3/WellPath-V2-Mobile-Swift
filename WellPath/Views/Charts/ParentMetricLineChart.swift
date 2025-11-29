//
//  ParentMetricLineChart.swift
//  WellPath
//
//  Reusable line chart component for metrics like bodyweight, HRV, etc.
//  Same pattern as ParentMetricBarChart but renders as a line with points
//

import SwiftUI
import Charts

struct ParentMetricLineChart: View {
    let metric: DisplayMetric
    let color: Color
    var showAbout: Binding<Bool>? = nil

    @State private var selectedPeriod: TimePeriod = .week
    @State private var selectedPointDate: Date?
    @State private var selectedUnit: String
    @State private var actualUnit: String?
    @State private var decimalPlaces: Int = 1
    @StateObject private var scrollManager: LineChartScrollManager
    @State private var scrollPosition: Date

    private var selectedPoint: ChartDataPoint? {
        guard let selectedDate = selectedPointDate else { return nil }
        return scrollManager.chartData.first(where: {
            Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: selectedPeriod.dateGranularity)
        })
    }

    init(metric: DisplayMetric, color: Color, showAbout: Binding<Bool>? = nil) {
        self.metric = metric
        self.color = color
        self.showAbout = showAbout

        _selectedUnit = State(initialValue: "")

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

        _scrollManager = StateObject(wrappedValue: LineChartScrollManager(
            period: initialPeriod,
            metricId: metric.metricId
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Time period picker
            Picker("Period", selection: $selectedPeriod) {
                ForEach(TimePeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 16)
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

            // Value display with optional info button
            HStack(alignment: .top, spacing: 40) {
                VStack(alignment: .leading, spacing: 4) {
                    if let selected = selectedPoint, selected.value > 0 {
                        Text(selectedPeriod.barLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatValue(selected.value))
                                .font(.system(size: 48, weight: .semibold))
                            if !displayUnit.isEmpty {
                                Text(displayUnit)
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Text(formatDate(selected.date))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text(selectedPeriod.aggregateLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatValue(calculateAverage()))
                                .font(.system(size: 48, weight: .semibold))
                            if !displayUnit.isEmpty {
                                Text(displayUnit)
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
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
            .padding(.top, 12)
            .onChange(of: scrollManager.actualUnit) { oldValue, newValue in
                if let newUnit = newValue {
                    actualUnit = newUnit
                    if selectedUnit.isEmpty {
                        selectedUnit = newUnit
                    }
                }
            }

            // Line chart
            Chart(scrollManager.chartData) { dataPoint in
                // Invisible placeholder for all points to establish x-axis domain
                PointMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Value", 0)
                )
                .opacity(0)

                // Only show line/area/points for non-zero values
                if dataPoint.value > 0 {
                    // Line
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3))

                    // Area under line
                    AreaMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.2), color.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    // Point marks
                    if let selectedDate = selectedPointDate,
                       Calendar.current.isDate(dataPoint.date, equalTo: selectedDate, toGranularity: selectedPeriod.dateGranularity) {
                        // Selected point (larger)
                        PointMark(
                            x: .value("Date", dataPoint.date),
                            y: .value("Value", dataPoint.value)
                        )
                        .foregroundStyle(color)
                        .symbolSize(150)
                    } else {
                        // Regular point
                        PointMark(
                            x: .value("Date", dataPoint.date),
                            y: .value("Value", dataPoint.value)
                        )
                        .foregroundStyle(color)
                        .symbolSize(50)
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
                                .filter { $0.value > 0 }
                                .min(by: {
                                    abs($0.date.timeIntervalSince(tappedDate)) < abs($1.date.timeIntervalSince(tappedDate))
                                })

                            if let closestDate = closest?.date,
                               Calendar.current.isDate(selectedPointDate ?? Date.distantPast, equalTo: closestDate, toGranularity: selectedPeriod.dateGranularity) {
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
            .chartXAxis {
                AxisMarks(values: .stride(by: getAxisLabelStride(), count: getAxisLabelMultiplier())) { value in
                    if let date = value.as(Date.self) {
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
                            Text(formatAxisValue(numValue))
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
            .padding(.top, 16)
            .padding(.bottom, 24)

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
        .background(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: - Computed Properties

    private var displayUnit: String {
        let unit = (actualUnit ?? selectedUnit).lowercased()
        switch unit {
        case "kilogram", "kg":
            return "kg"
        case "pound", "lb", "lbs":
            return "lb"
        case "percent", "percentage", "%":
            return "%"
        default:
            return selectedUnit
        }
    }

    private var yAxisDomain: ClosedRange<Double> {
        let values = scrollManager.chartData.map { $0.value }.filter { $0 > 0 }
        guard !values.isEmpty else { return 0...100 }

        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 100
        let padding = (maxVal - minVal) * 0.1

        // Add some padding to make the chart look better
        let lowerBound = max(0, minVal - padding)
        let upperBound = maxVal + padding

        return lowerBound...upperBound
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

    private func calculateAverage() -> Double {
        let visibleData = getVisibleDataPoints()
        let nonZeroValues = visibleData.filter { $0.value > 0 }.map { $0.value }
        guard !nonZeroValues.isEmpty else { return 0 }
        return nonZeroValues.reduce(0, +) / Double(nonZeroValues.count)
    }

    private func getVisibleDataPoints() -> [ChartDataPoint] {
        let calendar = Calendar.current
        let visibleDuration = selectedPeriod.numberOfBars
        let endDate = calendar.date(byAdding: selectedPeriod.calendarComponent, value: visibleDuration, to: scrollPosition) ?? scrollPosition

        return scrollManager.chartData.filter { dataPoint in
            dataPoint.date >= scrollPosition && dataPoint.date <= endDate
        }
    }

    private func visibleDateRangeString() -> String {
        let calendar = Calendar.current
        let visibleDuration = selectedPeriod.numberOfBars
        let endDate = calendar.date(byAdding: selectedPeriod.calendarComponent, value: visibleDuration - 1, to: scrollPosition) ?? scrollPosition

        let formatter = DateFormatter()
        formatter.dateFormat = selectedPeriod == .year ? "MMM yyyy" : "MMM d"

        return "\(formatter.string(from: scrollPosition)) - \(formatter.string(from: endDate))"
    }

    private func formatValue(_ value: Double) -> String {
        if decimalPlaces == 0 || value >= 100 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.\(decimalPlaces)f", value)
        }
    }

    private func formatAxisValue(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch selectedPeriod {
        case .day:
            formatter.dateFormat = "MMM d, yyyy"
        case .week:
            formatter.dateFormat = "MMM d"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
        case .sixMonth, .year:
            formatter.dateFormat = "MMM yyyy"
        }
        return formatter.string(from: date)
    }

    private func getVisibleDomainTimeInterval() -> TimeInterval {
        switch selectedPeriod {
        case .day:
            return TimeInterval(7 * 24 * 60 * 60)  // 7 days
        case .week:
            return TimeInterval(8 * 7 * 24 * 60 * 60)  // 8 weeks
        case .month:
            return TimeInterval(6 * 30 * 24 * 60 * 60)  // 6 months
        case .sixMonth:
            return TimeInterval(180 * 24 * 60 * 60)  // 6 months
        case .year:
            return TimeInterval(365 * 24 * 60 * 60)  // 1 year
        }
    }

    private func getAxisLabelStride() -> Calendar.Component {
        switch selectedPeriod {
        case .day:
            return .day
        case .week:
            return .weekOfYear
        case .month:
            return .month
        case .sixMonth:
            return .month
        case .year:
            return .month
        }
    }

    private func getAxisLabelMultiplier() -> Int {
        switch selectedPeriod {
        case .day:
            return 1
        case .week:
            return 2
        case .month:
            return 1
        case .sixMonth:
            return 2
        case .year:
            return 3
        }
    }

    private func getAxisLabelFormat() -> Date.FormatStyle {
        switch selectedPeriod {
        case .day:
            return .dateTime.day().month(.abbreviated)
        case .week:
            return .dateTime.day().month(.abbreviated)
        case .month:
            return .dateTime.month(.abbreviated)
        case .sixMonth:
            return .dateTime.month(.abbreviated)
        case .year:
            return .dateTime.month(.abbreviated).year(.twoDigits)
        }
    }
}

// MARK: - Line Chart Scroll Manager

@MainActor
class LineChartScrollManager: ObservableObject {
    @Published var chartData: [ChartDataPoint] = []
    @Published var isLoadingOlder = false
    @Published var isLoadingNewer = false
    @Published var actualUnit: String?

    private var oldestDate: Date
    private var newestDate: Date
    private var selectedPeriod: TimePeriod
    private let metricId: String
    private let supabase = SupabaseManager.shared.client

    init(period: TimePeriod, metricId: String) {
        self.selectedPeriod = period
        self.metricId = metricId

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

        Task {
            await loadInitialData()
        }
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
        Task {
            await loadInitialData()
        }
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
        // Generate empty timeline
        var timeline = generateEmptyTimeline(from: startDate, to: endDate)

        // Fetch data from aggregation_results_cache
        let dataPoints = await fetchDataPoints(from: startDate, to: endDate)

        // Overlay actual data on timeline
        for dataPoint in dataPoints {
            if let index = timeline.firstIndex(where: {
                Calendar.current.isDate($0.date, equalTo: dataPoint.date, toGranularity: selectedPeriod.dateGranularity)
            }) {
                timeline[index] = dataPoint
            }
        }

        // Merge with existing data
        await MainActor.run {
            let existingDates = Set(chartData.map { $0.date })
            let newPoints = timeline.filter { !existingDates.contains($0.date) }
            chartData.append(contentsOf: newPoints)
            chartData.sort { $0.date > $1.date }
        }
    }

    private func generateEmptyTimeline(from startDate: Date, to endDate: Date) -> [ChartDataPoint] {
        var timeline: [ChartDataPoint] = []
        var currentDate = startDate
        let calendar = Calendar.current
        let component = selectedPeriod.calendarComponent

        while currentDate <= endDate {
            timeline.append(ChartDataPoint(date: currentDate, value: 0, label: ""))
            currentDate = calendar.date(byAdding: component, value: 1, to: currentDate) ?? endDate
        }

        return timeline
    }

    private func fetchDataPoints(from startDate: Date, to endDate: Date) async -> [ChartDataPoint] {
        do {
            let patientId = try await supabase.auth.session.user.id

            // Look up aggregation metric ID from display_metrics_aggregations
            let aggId = await lookupAggregationId()
            guard let aggMetricId = aggId else {
                print("⚠️ No aggregation ID found for \(metricId)")
                return []
            }

            // Also fetch the unit from aggregation_metrics
            await fetchUnit(for: aggMetricId)

            let periodType = getPeriodType()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            struct AggResult: Codable {
                let value: Double
                let periodStart: Date

                enum CodingKeys: String, CodingKey {
                    case value
                    case periodStart = "period_start"
                }
            }

            let results: [AggResult] = try await supabase
                .from("aggregation_results_cache")
                .select("value, period_start")
                .eq("patient_id", value: patientId)
                .eq("agg_metric_id", value: aggMetricId)
                .eq("period_type", value: periodType)
                .gte("period_start", value: formatter.string(from: startDate))
                .lte("period_start", value: formatter.string(from: endDate))
                .order("period_start", ascending: false)
                .execute()
                .value

            return results.map { ChartDataPoint(date: $0.periodStart, value: $0.value, label: "") }

        } catch {
            print("❌ Error fetching line chart data: \(error)")
            return []
        }
    }

    private func lookupAggregationId() async -> String? {
        do {
            struct AggLookup: Codable {
                let aggMetricId: String

                enum CodingKeys: String, CodingKey {
                    case aggMetricId = "agg_metric_id"
                }
            }

            let periodType = getPeriodType()

            let results: [AggLookup] = try await supabase
                .from("display_metrics_aggregations")
                .select("agg_metric_id")
                .eq("metric_id", value: metricId)
                .eq("period_type", value: periodType)
                .limit(1)
                .execute()
                .value

            return results.first?.aggMetricId

        } catch {
            print("❌ Error looking up aggregation ID: \(error)")
            return nil
        }
    }

    private func fetchUnit(for aggMetricId: String) async {
        do {
            struct UnitResult: Codable {
                let outputUnit: String?

                enum CodingKeys: String, CodingKey {
                    case outputUnit = "output_unit"
                }
            }

            let results: [UnitResult] = try await supabase
                .from("aggregation_metrics")
                .select("output_unit")
                .eq("agg_id", value: aggMetricId)
                .limit(1)
                .execute()
                .value

            if let unit = results.first?.outputUnit {
                await MainActor.run {
                    self.actualUnit = unit
                }
            }

        } catch {
            print("❌ Error fetching unit: \(error)")
        }
    }

    private func getPeriodType() -> String {
        switch selectedPeriod {
        case .day:
            return "daily"
        case .week:
            return "weekly"
        case .month:
            return "monthly"
        case .sixMonth:
            return "daily"  // Use daily data for 6M view
        case .year:
            return "daily"  // Use daily data for Y view
        }
    }
}

// MARK: - TimePeriod Extension

extension TimePeriod {
    var dateGranularity: Calendar.Component {
        switch self {
        case .day:
            return .day
        case .week:
            return .weekOfYear
        case .month:
            return .month
        case .sixMonth:
            return .day
        case .year:
            return .day
        }
    }
}

#Preview {
    let mockMetric = DisplayMetric(
        id: "preview-id",
        metricId: "DISP_WEIGHT",
        metricName: "Weight",
        description: "Body weight tracking",
        screenId: nil,
        pillar: "Core Care",
        chartTypeId: "trend_line",
        isActive: true,
        createdAt: nil,
        updatedAt: nil,
        aboutContent: nil,
        longevityImpact: nil,
        quickTips: nil
    )

    ParentMetricLineChart(metric: mockMetric, color: .cyan)
}
