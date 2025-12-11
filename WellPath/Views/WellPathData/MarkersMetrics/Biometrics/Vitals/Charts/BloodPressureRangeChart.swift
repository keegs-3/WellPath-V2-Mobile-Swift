//
//  BloodPressureRangeChart.swift
//  WellPath
//
//  Range/band chart showing blood pressure over time
//  Displays shaded area between systolic (top) and diastolic (bottom)
//

import SwiftUI
import Charts
import Supabase

struct BloodPressureRangeChart: View {
    let color: Color
    var showAbout: Binding<Bool>? = nil

    @State private var selectedPeriod: TimePeriod = .week
    @State private var selectedPointDate: Date?
    @StateObject private var scrollManager: BPChartScrollManager
    @State private var scrollPosition: Date
    @State private var showAskAI = false

    private var selectedPoint: BPDataPoint? {
        guard let selectedDate = selectedPointDate else { return nil }
        return scrollManager.chartData.first(where: {
            Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: getDateGranularity())
        })
    }

    private var dataPointsWithValues: [BPDataPoint] {
        scrollManager.chartData.filter { $0.systolicMax > 0 && $0.diastolicMax > 0 }
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
        _scrollManager = StateObject(wrappedValue: BPChartScrollManager(period: initialPeriod))
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

            // Value display - shows min/max ranges for systolic and diastolic
            HStack(alignment: .top, spacing: 40) {
                VStack(alignment: .leading, spacing: 4) {
                    if let selected = selectedPoint {
                        Text("RANGE")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        // Selected period values
                        VStack(alignment: .leading, spacing: 2) {
                            // Systolic display
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(formatRangeValue(min: selected.systolicMin, max: selected.systolicMax))
                                    .font(.system(size: 34, weight: .semibold))
                                    .foregroundColor(color)
                                Text("SYS")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            // Diastolic display
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(formatRangeValue(min: selected.diastolicMin, max: selected.diastolicMax))
                                    .font(.system(size: 34, weight: .semibold))
                                    .foregroundColor(color.opacity(0.7))
                                Text("DIA")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Text(formatSelectedDate(selected.date))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("RANGE")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        let overallRanges = getOverallRanges()
                        if let ranges = overallRanges {
                            VStack(alignment: .leading, spacing: 2) {
                                // Systolic range
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text(formatRangeValue(min: ranges.systolicMin, max: ranges.systolicMax))
                                        .font(.system(size: 34, weight: .semibold))
                                        .foregroundColor(color)
                                    Text("SYS")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                // Diastolic range
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text(formatRangeValue(min: ranges.diastolicMin, max: ranges.diastolicMax))
                                        .font(.system(size: 34, weight: .semibold))
                                        .foregroundColor(color.opacity(0.7))
                                    Text("DIA")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            Text("--")
                                .font(.system(size: 34, weight: .semibold))
                        }
                        Text(visibleDateRangeString())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Unit label and action buttons
                VStack(alignment: .trailing, spacing: 8) {
                    Text("mmHg")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 16) {
                        // Ask AI button
                        Button(action: {
                            showAskAI = true
                        }) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.title3)
                                .foregroundColor(color)
                        }

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
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 12)

            // Range chart - Apple Health style with separate systolic/diastolic range bars
            Chart(scrollManager.chartData) { dataPoint in
                // Invisible placeholder for x-axis domain
                PointMark(
                    x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
                    y: .value("Value", 0)
                )
                .opacity(0)

                // Only show marks for valid readings
                if dataPoint.systolicMax > 0 && dataPoint.diastolicMax > 0 {
                    let isSelected = selectedPointDate != nil &&
                        Calendar.current.isDate(dataPoint.date, equalTo: selectedPointDate!, toGranularity: getDateGranularity())

                    // Systolic range bar (upper bar - darker color)
                    if dataPoint.isSystolicRange {
                        BarMark(
                            x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
                            yStart: .value("Systolic Min", dataPoint.systolicMin),
                            yEnd: .value("Systolic Max", dataPoint.systolicMax),
                            width: .fixed(barWidth)
                        )
                        .foregroundStyle(isSelected ? color : color.opacity(0.85))
                        .clipShape(Capsule())
                    } else {
                        // Single systolic value - show as point
                        PointMark(
                            x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
                            y: .value("Systolic", dataPoint.systolicMax)
                        )
                        .foregroundStyle(isSelected ? color : color.opacity(0.85))
                        .symbolSize(isSelected ? 80 : 50)
                    }

                    // Diastolic range bar (lower bar - lighter color)
                    if dataPoint.isDiastolicRange {
                        BarMark(
                            x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
                            yStart: .value("Diastolic Min", dataPoint.diastolicMin),
                            yEnd: .value("Diastolic Max", dataPoint.diastolicMax),
                            width: .fixed(barWidth)
                        )
                        .foregroundStyle(isSelected ? color.opacity(0.6) : color.opacity(0.5))
                        .clipShape(Capsule())
                    } else {
                        // Single diastolic value - show as point
                        PointMark(
                            x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
                            y: .value("Diastolic", dataPoint.diastolicMax)
                        )
                        .foregroundStyle(isSelected ? color.opacity(0.6) : color.opacity(0.5))
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
                                .filter { $0.systolic > 0 && $0.diastolic > 0 }
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
        .sheet(isPresented: $showAskAI) {
            EducationQAModal(
                viewId: "DISP_BLOOD_PRESSURE",
                viewName: "Blood Pressure",
                color: color
            )
        }
    }

    // MARK: - Computed Properties

    private var yAxisDomain: ClosedRange<Double> {
        let values = scrollManager.chartData
            .flatMap { [$0.systolicMin, $0.systolicMax, $0.diastolicMin, $0.diastolicMax] }
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

    private func getLatestReading() -> BPDataPoint? {
        scrollManager.chartData
            .filter { $0.systolicMax > 0 && $0.diastolicMax > 0 }
            .sorted { $0.date > $1.date }
            .first
    }

    /// Format a range value - shows "120-130" for range, or "120" for single value
    private func formatRangeValue(min: Double, max: Double) -> String {
        if min == max || min == 0 {
            return "\(Int(max))"
        } else {
            return "\(Int(min))-\(Int(max))"
        }
    }

    /// Get overall min/max ranges across all visible data points
    private func getOverallRanges() -> (systolicMin: Double, systolicMax: Double, diastolicMin: Double, diastolicMax: Double)? {
        let validPoints = dataPointsWithValues
        guard !validPoints.isEmpty else { return nil }

        let systolicMin = validPoints.map { $0.systolicMin }.filter { $0 > 0 }.min() ?? 0
        let systolicMax = validPoints.map { $0.systolicMax }.max() ?? 0
        let diastolicMin = validPoints.map { $0.diastolicMin }.filter { $0 > 0 }.min() ?? 0
        let diastolicMax = validPoints.map { $0.diastolicMax }.max() ?? 0

        guard systolicMax > 0 && diastolicMax > 0 else { return nil }

        return (systolicMin, systolicMax, diastolicMin, diastolicMax)
    }

    private func visibleDateRangeString() -> String {
        let calendar = Calendar.current
        let visibleDuration = selectedPeriod.numberOfBars
        let endDate = calendar.date(byAdding: selectedPeriod.calendarComponent, value: visibleDuration - 1, to: scrollPosition) ?? scrollPosition

        let formatter = DateFormatter()
        formatter.dateFormat = selectedPeriod == .year ? "MMM yyyy" : "MMM d"

        return "\(formatter.string(from: scrollPosition)) - \(formatter.string(from: endDate))"
    }

    private func formatSelectedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch selectedPeriod {
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

// MARK: - BP Data Point (with min/max ranges for aggregation)

struct BPDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    // Systolic range (min to max for the period)
    let systolicMin: Double
    let systolicMax: Double
    // Diastolic range (min to max for the period)
    let diastolicMin: Double
    let diastolicMax: Double
    // Number of readings in this period
    let readingCount: Int

    // Convenience for single readings
    var systolic: Double { systolicMax }
    var diastolic: Double { diastolicMax }

    // Check if this is a range (multiple readings) or single value
    var isSystolicRange: Bool { systolicMin != systolicMax }
    var isDiastolicRange: Bool { diastolicMin != diastolicMax }

    init(date: Date, systolicMin: Double, systolicMax: Double, diastolicMin: Double, diastolicMax: Double, readingCount: Int = 1) {
        self.date = date
        self.systolicMin = systolicMin
        self.systolicMax = systolicMax
        self.diastolicMin = diastolicMin
        self.diastolicMax = diastolicMax
        self.readingCount = readingCount
    }

    // Convenience initializer for single readings
    init(date: Date, systolic: Double, diastolic: Double) {
        self.date = date
        self.systolicMin = systolic
        self.systolicMax = systolic
        self.diastolicMin = diastolic
        self.diastolicMax = diastolic
        self.readingCount = 1
    }
}

// MARK: - BP Chart Scroll Manager

@MainActor
class BPChartScrollManager: ObservableObject {
    @Published var chartData: [BPDataPoint] = []
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
        // Generate empty timeline
        var timeline = generateEmptyTimeline(from: startDate, to: endDate)

        // Fetch data from patient_samples
        let dataPoints = await fetchDataPoints(from: startDate, to: endDate)

        // Overlay actual data on timeline
        for dataPoint in dataPoints {
            if let index = timeline.firstIndex(where: {
                Calendar.current.isDate($0.date, equalTo: dataPoint.date, toGranularity: selectedPeriod.calendarComponent)
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

    private func generateEmptyTimeline(from startDate: Date, to endDate: Date) -> [BPDataPoint] {
        var timeline: [BPDataPoint] = []
        var currentDate = startDate
        let calendar = Calendar.current
        let component = selectedPeriod.calendarComponent

        while currentDate <= endDate {
            timeline.append(BPDataPoint(
                date: currentDate,
                systolicMin: 0,
                systolicMax: 0,
                diastolicMin: 0,
                diastolicMax: 0,
                readingCount: 0
            ))
            currentDate = calendar.date(byAdding: component, value: 1, to: currentDate) ?? endDate
        }

        return timeline
    }

    private func fetchDataPoints(from startDate: Date, to endDate: Date) async -> [BPDataPoint] {
        do {
            let patientId = try await supabase.auth.session.user.id

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            // Fetch blood pressure readings from patient_correlation_samples
            let results: [CorrelationSampleRead] = try await supabase
                .from("patient_correlation_samples")
                .select("id, patient_id, correlation_type, components, sample_time, source, user_timezone")
                .eq("patient_id", value: patientId)
                .eq("correlation_type", value: CorrelationTypes.bloodPressure)
                .gte("sample_time", value: formatter.string(from: startDate))
                .lte("sample_time", value: formatter.string(from: endDate))
                .order("sample_time", ascending: false)
                .execute()
                .value

            // Group by period and aggregate min/max for systolic and diastolic
            // Period grouping varies by selected time period:
            // - Day view: group by hour
            // - Week/Month view: group by day
            // - 6M view: group by week
            // - Year view: group by month
            struct PeriodAggregate {
                var systolicValues: [Double] = []
                var diastolicValues: [Double] = []
            }

            var groupedByPeriod: [Date: PeriodAggregate] = [:]
            let calendar = Calendar.current

            for reading in results {
                guard let systolic = reading.systolic, let diastolic = reading.diastolic else { continue }

                let periodKey = getPeriodKey(for: reading.sampleTime, calendar: calendar)

                if groupedByPeriod[periodKey] == nil {
                    groupedByPeriod[periodKey] = PeriodAggregate()
                }

                groupedByPeriod[periodKey]?.systolicValues.append(systolic)
                groupedByPeriod[periodKey]?.diastolicValues.append(diastolic)
            }

            // Convert to BPDataPoint array with min/max ranges
            return groupedByPeriod.compactMap { date, aggregate in
                guard !aggregate.systolicValues.isEmpty && !aggregate.diastolicValues.isEmpty else {
                    return nil
                }

                let systolicMin = aggregate.systolicValues.min() ?? 0
                let systolicMax = aggregate.systolicValues.max() ?? 0
                let diastolicMin = aggregate.diastolicValues.min() ?? 0
                let diastolicMax = aggregate.diastolicValues.max() ?? 0
                let readingCount = aggregate.systolicValues.count

                return BPDataPoint(
                    date: date,
                    systolicMin: systolicMin,
                    systolicMax: systolicMax,
                    diastolicMin: diastolicMin,
                    diastolicMax: diastolicMax,
                    readingCount: readingCount
                )
            }

        } catch {
            print("❌ Error fetching BP data: \(error)")
            return []
        }
    }

    /// Get the period key (start date of period) for a given reading time
    private func getPeriodKey(for date: Date, calendar: Calendar) -> Date {
        switch selectedPeriod {
        case .day:
            // Group by hour
            let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
            return calendar.date(from: components) ?? date
        case .week, .month:
            // Group by day
            return calendar.startOfDay(for: date)
        case .sixMonth:
            // Group by week (start of week)
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return calendar.date(from: components) ?? date
        case .year:
            // Group by month
            let components = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: components) ?? date
        }
    }
}

#Preview {
    BloodPressureRangeChart(color: .red)
}
