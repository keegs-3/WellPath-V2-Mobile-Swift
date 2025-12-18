//
//  WaterLineChart.swift
//  WellPath
//
//  Bar chart for water intake with unit preference support
//  Shows cumulative daily intake in user's preferred unit (mL, fl oz, cups, glasses, L, gal)
//

import SwiftUI
import Charts

struct WaterLineChart: View {
    let color: Color
    var showAbout: Binding<Bool>? = nil

    @State private var selectedPeriod: TimePeriod = .week
    @State private var selectedPointDate: Date?
    @State private var selectedUnit: LiquidDisplayUnit = .milliliter
    @StateObject private var scrollManager: WaterLineChartScrollManager
    @StateObject private var unitPrefs = UnitPreferencesViewModel()
    @State private var scrollPosition: Date

    private let metricId = "DISP_WATER_ML"

    private var selectedPoint: ChartDataPoint? {
        guard let selectedDate = selectedPointDate else { return nil }
        return scrollManager.chartData.first(where: {
            Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: getDateGranularity())
        })
    }

    /// Get only the data points that have actual values (non-zero)
    private var dataPointsWithValues: [ChartDataPoint] {
        scrollManager.chartData.filter { $0.value > 0 }
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
        _scrollManager = StateObject(wrappedValue: WaterLineChartScrollManager(period: initialPeriod))
    }

    var body: some View {
        VStack(spacing: 0) {
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
                        scrollPosition = calculateScrollPosition(for: newPeriod)
                    }
                    .onChange(of: scrollManager.chartData.count) { oldCount, newCount in
                        if oldCount == 0 && newCount > 0 {
                            scrollPosition = calculateScrollPosition(for: selectedPeriod)
                        }
                    }

                    // Unit dropdown - aligned right
                    HStack {
                        Spacer()
                        Menu {
                            ForEach(LiquidDisplayUnit.allCases) { unit in
                                Button(action: { selectedUnit = unit }) {
                                    HStack {
                                        Text(unit.displayName)
                                        if selectedUnit == unit {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedUnit.shortLabel)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .foregroundColor(color)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(color.opacity(0.1))
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Value display with optional info button
                    HStack(alignment: .top, spacing: 40) {
                        VStack(alignment: .leading, spacing: 4) {
                            if let selected = selectedPoint, selected.value > 0 {
                                if selectedPeriod == .sixMonth || selectedPeriod == .year {
                                    Text("AVG")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text(formatValue(convertValueForDisplay(selected.value)))
                                        .font(.system(size: 48, weight: .semibold))
                                    Text(displayUnit)
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                }
                                Text(formatSelectedDate(selected.date))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("AVG")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text(formatValue(convertValueForDisplay(getAverageValue())))
                                        .font(.system(size: 48, weight: .semibold))
                                    Text(displayUnit)
                                        .font(.title2)
                                        .foregroundColor(.secondary)
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

                    // Bar chart
                    Chart {
                        // Invisible marks for scroll domain
                        ForEach(scrollManager.chartData) { dataPoint in
                            PointMark(
                                x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
                                y: .value("Value", 0)
                            )
                            .opacity(0)
                        }

                        // Bars for water intake
                        ForEach(dataPointsWithValues) { dataPoint in
                            let displayValue = convertValueForDisplay(dataPoint.value)
                            let isSelected = selectedPointDate != nil &&
                                Calendar.current.isDate(dataPoint.date, equalTo: selectedPointDate!, toGranularity: getDateGranularity())

                            BarMark(
                                x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
                                y: .value("Value", displayValue)
                            )
                            .foregroundStyle(isSelected ? color : color.opacity(0.7))
                            .cornerRadius(4)
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
                                    Text(formatAxisValue(numValue))
                                }
                            }
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
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
        }
        .task {
            await unitPrefs.loadPreferences()
            selectedUnit = unitPrefs.liquidUnit
        }
    }

    // MARK: - Computed Properties

    private var displayUnit: String {
        selectedUnit.shortLabel
    }

    /// Convert value from canonical mL to display unit
    private func convertValueForDisplay(_ mlValue: Double) -> Double {
        mlValue / selectedUnit.mlPerUnit
    }

    private var yAxisDomain: ClosedRange<Double> {
        let values = scrollManager.chartData
            .map { convertValueForDisplay($0.value) }
            .filter { $0 > 0 }
        guard !values.isEmpty else { return 0...100 }

        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 100
        let range = maxVal - minVal
        let padding = max(range * 0.1, maxVal * 0.05, 1.0)

        let lowerBound = max(0, minVal - padding)
        let upperBound = maxVal + padding

        return lowerBound...upperBound
    }

    // MARK: - Helper Functions

    private func calculateScrollPosition(for period: TimePeriod) -> Date {
        let mostRecentDataDate = dataPointsWithValues.first?.date ?? Date()
        let visibleDuration = period.numberOfBars
        let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
        return Calendar.current.date(
            byAdding: period.calendarComponent,
            value: -offsetFromEnd,
            to: mostRecentDataDate
        ) ?? mostRecentDataDate
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

        if let newestDate = scrollManager.chartData.first?.date {
            let diff = calendar.dateComponents([component], from: position, to: newestDate)
            let units = abs(diff.value(for: component) ?? 0)

            if units < 5 && !scrollManager.isLoadingNewer {
                scrollManager.loadNewerData()
            }
        }
    }

    private func getAverageValue() -> Double {
        let visibleData = getVisibleDataPoints()
        let values = visibleData.compactMap { $0.value > 0 ? $0.value : nil }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
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

    private func formatValue(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func formatAxisValue(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func formatSelectedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()

        switch selectedPeriod {
        case .day:
            formatter.dateFormat = "MMM d, yyyy, h:mm a"
            return formatter.string(from: date)
        case .week, .month:
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
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
        case .week: return .dateTime.weekday(.narrow)
        case .month: return .dateTime.day(.defaultDigits)
        case .sixMonth: return .dateTime.month(.abbreviated)
        case .year: return .dateTime.month(.narrow)
        }
    }
}

// MARK: - Water Line Chart Scroll Manager

@MainActor
class WaterLineChartScrollManager: ObservableObject {
    @Published var chartData: [ChartDataPoint] = []
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

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            struct SampleResult: Codable {
                let canonicalValue: Double
                let startTime: Date

                enum CodingKeys: String, CodingKey {
                    case canonicalValue = "canonical_value"
                    case startTime = "start_time"
                }
            }

            // Query water samples - canonical_value is always in mL
            let results: [SampleResult] = try await supabase
                .from("patient_quantity_samples")
                .select("canonical_value, start_time")
                .eq("patient_id", value: patientId)
                .eq("quantity_type", value: "water_ml")
                .gte("start_time", value: formatter.string(from: startDate))
                .lte("start_time", value: formatter.string(from: endDate))
                .order("start_time", ascending: false)
                .execute()
                .value

            print("📊 WaterLineChart: Fetched \(results.count) water samples")

            // Aggregate by period
            let calendar = Calendar.current
            let aggregationGranularity: Calendar.Component = {
                switch selectedPeriod {
                case .day: return .hour
                case .week, .month: return .day
                case .sixMonth: return .weekOfYear
                case .year: return .month
                }
            }()

            // Group readings by period bucket - SUM water intake
            var bucketData: [Date: Double] = [:]

            for result in results {
                let bucketStart: Date
                switch aggregationGranularity {
                case .hour:
                    bucketStart = calendar.dateInterval(of: .hour, for: result.startTime)?.start ?? result.startTime
                case .day:
                    bucketStart = calendar.startOfDay(for: result.startTime)
                case .weekOfYear:
                    bucketStart = calendar.dateInterval(of: .weekOfYear, for: result.startTime)?.start ?? result.startTime
                case .month:
                    bucketStart = calendar.dateInterval(of: .month, for: result.startTime)?.start ?? result.startTime
                default:
                    bucketStart = result.startTime
                }

                bucketData[bucketStart, default: 0] += result.canonicalValue
            }

            // Create chart points
            var aggregatedPoints: [ChartDataPoint] = []
            for (bucketStart, totalValue) in bucketData {
                aggregatedPoints.append(ChartDataPoint(date: bucketStart, value: totalValue, label: ""))
            }

            print("📊 WaterLineChart: Aggregated to \(aggregatedPoints.count) points for period \(selectedPeriod.rawValue)")

            return aggregatedPoints.sorted { $0.date > $1.date }

        } catch {
            print("❌ Error fetching water chart data: \(error)")
            return []
        }
    }
}

#Preview {
    WaterLineChart(color: .cyan)
}
