import SwiftUI
import Supabase
import Charts

struct SleepConsistencyPrimary: View {
    let pillar: String
    let color: Color
    @StateObject private var viewModel = SleepConsistencyViewModel()
    @StateObject private var primaryViewModel = SleepAnalysisPrimaryViewModel(metricId: "DISP_SLEEP_CONSISTENCY")
    @State private var selectedPeriod: ConsistencyPeriod = .week
    @State private var selectedView: PrimaryView = .chart
    @State private var scrollPosition: Date
    @State private var selectedDate: Date?
    @State private var selectedWeek: WeeklySleepAverage?
    @State private var selectedMonth: MonthlySleepAverage?

    init(pillar: String, color: Color) {
        self.pillar = pillar
        self.color = color
        _scrollPosition = State(initialValue: Date())
    }

    enum PrimaryView: String, CaseIterable {
        case chart = "Chart"
        case about = "About"
    }

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Sleep Consistency")
    }

    enum ConsistencyPeriod: String, CaseIterable {
        case week = "W"
        case month = "M"
        case sixMonth = "6M"
        case year = "Y"
    }

    var body: some View {
        chartContent
            .background(
                ZStack {
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [color.opacity(0.65), color.opacity(0.45), color.opacity(0.25), color.opacity(0.1), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 900)
                        Spacer()
                    }

                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: screenIcon)
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
            .navigationTitle("Sleep Consistency")
            .navigationBarTitleDisplayMode(.large)
    }

    private var chartContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // View picker (Chart/About)
                Picker("View", selection: $selectedView) {
                    ForEach(PrimaryView.allCases, id: \.self) { view in
                        Text(view.rawValue).tag(view)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 8)

                if selectedView == .chart {
                    chartView
                } else {
                    aboutView
                }
            }
        }
    }

    private var chartView: some View {
        VStack(spacing: 0) {
            // Period selector (W/M/6M/Y)
            Picker("Period", selection: $selectedPeriod) {
                ForEach(ConsistencyPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .onChange(of: selectedPeriod) { oldValue, newValue in
                // Reset selections when switching periods
                selectedDate = nil
                selectedWeek = nil
                selectedMonth = nil

                Task {
                    switch newValue {
                    case .week:
                        // W view: 5 weeks of daily data (35 days)
                        await viewModel.loadDailySleepTimes(daysBack: 35, daysAhead: 0)
                    case .month:
                        // M view: 33 days of daily data
                        await viewModel.loadDailySleepTimes(daysBack: 33, daysAhead: 0)
                    case .sixMonth:
                        // 6M view: 26 weeks of weekly averages
                        await viewModel.loadWeeklySleepAverages(weeksBack: 26, weeksAhead: 0)
                    case .year:
                        // Y view: 12 months of monthly averages
                        await viewModel.loadMonthlySleepAverages(monthsBack: 12, monthsAhead: 0)
                    }
                }
            }

            // Chart content based on period
            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading sleep consistency data...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 300)
            } else {
                summaryMetrics
                consistencyChart
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .task {
            // Initial load defaults to week view (35 days)
            await viewModel.loadDailySleepTimes(daysBack: 35, daysAhead: 0)
            // Also load About content
            await primaryViewModel.loadPrimaryScreen()
        }
    }

    // MARK: - Summary Metrics

    private var summaryMetrics: some View {
        let averages = calculateVisibleAverages()

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 40) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Avg Bedtime").font(.caption).foregroundColor(.secondary)
                    if let selectedData = getSelectedData() {
                        Text(formatTime(selectedData.bedtime))
                            .font(.title2).fontWeight(.semibold)
                    } else if let avg = averages {
                        Text(formatTime(avg.bedtime))
                            .font(.title2).fontWeight(.semibold)
                    } else {
                        Text("No Data")
                            .font(.title2).fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Avg Waketime").font(.caption).foregroundColor(.secondary)
                    if let selectedData = getSelectedData() {
                        Text(formatTime(selectedData.waketime))
                            .font(.title2).fontWeight(.semibold)
                    } else if let avg = averages {
                        Text(formatTime(avg.waketime))
                            .font(.title2).fontWeight(.semibold)
                    } else {
                        Text("No Data")
                            .font(.title2).fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Text(getDateRangeString())
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Consistency Chart

    private var consistencyChart: some View {
        let visibleLength = getVisibleDomainLength()

        return Chart {
            // Consistency box (±30 min from visible average)
            if !isAnyItemSelected(), let avg = calculateVisibleAverages() {
                consistencyBox(avg: avg)
            }

            // Sleep bars based on period
            switch selectedPeriod {
            case .week, .month:
                ForEach(dailyChartData) { dayData in
                    if dayData.hasData {
                        BarMark(
                            x: .value("Date", dayData.date, unit: .day),
                            yStart: .value("Bedtime", dayData.chartBedtime),
                            yEnd: .value("Waketime", dayData.chartWaketime),
                            width: .ratio(0.6)
                        )
                        .foregroundStyle(getDailyBarColor(for: dayData))
                    }
                }
            case .sixMonth:
                ForEach(weeklyChartData) { weekData in
                    if weekData.hasData {
                        BarMark(
                            x: .value("Week", weekData.weekStartDate, unit: .weekOfYear),
                            yStart: .value("Bedtime", weekData.chartBedtime),
                            yEnd: .value("Waketime", weekData.chartWaketime),
                            width: .ratio(0.6)
                        )
                        .foregroundStyle(getWeeklyBarColor(for: weekData))
                    }
                }
            case .year:
                ForEach(monthlyChartData) { monthData in
                    if monthData.hasData {
                        BarMark(
                            x: .value("Month", monthData.monthStartDate, unit: .month),
                            yStart: .value("Bedtime", monthData.chartBedtime),
                            yEnd: .value("Waketime", monthData.chartWaketime),
                            width: .ratio(0.6)
                        )
                        .foregroundStyle(getMonthlyBarColor(for: monthData))
                    }
                }
            }
        }
        .chartXAxis {
            switch selectedPeriod {
            case .week, .month:
                AxisMarks(values: .stride(by: .day, count: 7)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                    AxisGridLine()
                }
            case .sixMonth:
                AxisMarks(values: .stride(by: .month)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                    AxisGridLine()
                }
            case .year:
                AxisMarks(values: .stride(by: .month, count: 2)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                    AxisGridLine()
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .stride(by: 3600)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel(formatYAxisLabel(date))
                }
                AxisGridLine()
            }
        }
        .chartYScale(domain: yAxisDomain)
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: visibleLength)
        .chartScrollPosition(x: $scrollPosition)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        handleChartTap(proxy: proxy, location: location)
                    }
            }
        }
        .frame(height: 280)
        .padding(.horizontal)
        .onAppear {
            initializeScrollPosition()
        }
    }

    // MARK: - Consistency Box

    @ChartContentBuilder
    private func consistencyBox(avg: (bedtime: Date, waketime: Date)) -> some ChartContent {
        let visibleRange = getVisibleDateRange()
        let calendar = Calendar.current

        let bedtimeLower = calendar.date(byAdding: .minute, value: -30, to: avg.bedtime) ?? avg.bedtime
        let bedtimeUpper = calendar.date(byAdding: .minute, value: 30, to: avg.bedtime) ?? avg.bedtime
        let waketimeLower = calendar.date(byAdding: .minute, value: -30, to: avg.waketime) ?? avg.waketime
        let waketimeUpper = calendar.date(byAdding: .minute, value: 30, to: avg.waketime) ?? avg.waketime

        // Bedtime consistency band
        RectangleMark(
            xStart: .value("Start", visibleRange.start),
            xEnd: .value("End", visibleRange.end),
            yStart: .value("Lower", bedtimeLower),
            yEnd: .value("Upper", bedtimeUpper)
        )
        .foregroundStyle(color.opacity(0.15))

        // Waketime consistency band
        RectangleMark(
            xStart: .value("Start", visibleRange.start),
            xEnd: .value("End", visibleRange.end),
            yStart: .value("Lower", waketimeLower),
            yEnd: .value("Upper", waketimeUpper)
        )
        .foregroundStyle(color.opacity(0.15))
    }

    // MARK: - Chart Data Structures

    private struct ChartDayData: Identifiable {
        let id = UUID()
        let date: Date
        let chartBedtime: Date
        let chartWaketime: Date
        let hasData: Bool
    }

    private struct ChartWeekData: Identifiable {
        let id = UUID()
        let weekStartDate: Date
        let chartBedtime: Date
        let chartWaketime: Date
        let week: WeeklySleepAverage?
        let hasData: Bool
    }

    private struct ChartMonthData: Identifiable {
        let id = UUID()
        let monthStartDate: Date
        let chartBedtime: Date
        let chartWaketime: Date
        let month: MonthlySleepAverage?
        let hasData: Bool
    }

    // MARK: - Chart Data Generation

    private var dailyChartData: [ChartDayData] {
        let daysCount = selectedPeriod == .week ? 35 : 33
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -daysCount, to: today) else {
            return []
        }

        let sixPMReference = createSixPMReference()
        var allDays: [ChartDayData] = []

        for dayOffset in 0..<daysCount {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else {
                continue
            }

            if let sleepData = viewModel.dailySleepTimes.first(where: {
                calendar.isDate($0.date, inSameDayAs: date)
            }) {
                let bedtimeOffset = calculateOffsetFromSixPM(sleepData.bedtime)
                let waketimeOffset = calculateOffsetFromSixPM(sleepData.waketime)

                let chartBedtime = calendar.date(byAdding: .minute, value: bedtimeOffset, to: sixPMReference) ?? sixPMReference
                let chartWaketime = calendar.date(byAdding: .minute, value: waketimeOffset, to: sixPMReference) ?? sixPMReference

                allDays.append(ChartDayData(
                    date: date,
                    chartBedtime: chartBedtime,
                    chartWaketime: chartWaketime,
                    hasData: true
                ))
            } else {
                allDays.append(ChartDayData(
                    date: date,
                    chartBedtime: sixPMReference,
                    chartWaketime: sixPMReference,
                    hasData: false
                ))
            }
        }

        return allDays
    }

    private var weeklyChartData: [ChartWeekData] {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2 // Monday

        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .weekOfYear, value: -26, to: today) else {
            return []
        }

        let sixPMReference = createSixPMReference()
        var allWeeks: [ChartWeekData] = []

        for weekOffset in 0..<26 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: startDate) else {
                continue
            }

            if let weekAverage = viewModel.weeklySleepAverages.first(where: {
                calendar.isDate($0.weekStartDate, equalTo: weekStart, toGranularity: .day)
            }) {
                let bedtimeOffset = calculateOffsetFromSixPM(weekAverage.avgBedtime)
                let waketimeOffset = calculateOffsetFromSixPM(weekAverage.avgWaketime)

                let chartBedtime = calendar.date(byAdding: .minute, value: bedtimeOffset, to: sixPMReference) ?? sixPMReference
                let chartWaketime = calendar.date(byAdding: .minute, value: waketimeOffset, to: sixPMReference) ?? sixPMReference

                allWeeks.append(ChartWeekData(
                    weekStartDate: weekStart,
                    chartBedtime: chartBedtime,
                    chartWaketime: chartWaketime,
                    week: weekAverage,
                    hasData: true
                ))
            } else {
                allWeeks.append(ChartWeekData(
                    weekStartDate: weekStart,
                    chartBedtime: sixPMReference,
                    chartWaketime: sixPMReference,
                    week: nil,
                    hasData: false
                ))
            }
        }

        return allWeeks
    }

    private var monthlyChartData: [ChartMonthData] {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .month, value: -12, to: today) else {
            return []
        }

        let startComponents = calendar.dateComponents([.year, .month], from: startDate)
        guard let alignedStart = calendar.date(from: startComponents) else {
            return []
        }

        let sixPMReference = createSixPMReference()
        var allMonths: [ChartMonthData] = []

        for monthOffset in 0..<12 {
            guard let monthStart = calendar.date(byAdding: .month, value: monthOffset, to: alignedStart) else {
                continue
            }

            if let monthAverage = viewModel.monthlySleepAverages.first(where: {
                let components1 = calendar.dateComponents([.year, .month], from: $0.monthStartDate)
                let components2 = calendar.dateComponents([.year, .month], from: monthStart)
                return components1.year == components2.year && components1.month == components2.month
            }) {
                let bedtimeOffset = calculateOffsetFromSixPM(monthAverage.avgBedtime)
                let waketimeOffset = calculateOffsetFromSixPM(monthAverage.avgWaketime)

                let chartBedtime = calendar.date(byAdding: .minute, value: bedtimeOffset, to: sixPMReference) ?? sixPMReference
                let chartWaketime = calendar.date(byAdding: .minute, value: waketimeOffset, to: sixPMReference) ?? sixPMReference

                allMonths.append(ChartMonthData(
                    monthStartDate: monthStart,
                    chartBedtime: chartBedtime,
                    chartWaketime: chartWaketime,
                    month: monthAverage,
                    hasData: true
                ))
            } else {
                allMonths.append(ChartMonthData(
                    monthStartDate: monthStart,
                    chartBedtime: sixPMReference,
                    chartWaketime: sixPMReference,
                    month: nil,
                    hasData: false
                ))
            }
        }

        return allMonths
    }

    // MARK: - Y-Axis Domain

    private var yAxisDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let sixPMReference = createSixPMReference()

        let hasData: Bool
        let bedtimeOffsets: [Int]
        let waketimeOffsets: [Int]

        switch selectedPeriod {
        case .week, .month:
            let daysWithData = dailyChartData.filter { $0.hasData }
            hasData = !daysWithData.isEmpty
            bedtimeOffsets = daysWithData.map { calendar.dateComponents([.minute], from: sixPMReference, to: $0.chartBedtime).minute ?? 0 }
            waketimeOffsets = daysWithData.map { calendar.dateComponents([.minute], from: sixPMReference, to: $0.chartWaketime).minute ?? 0 }
        case .sixMonth:
            let weeksWithData = weeklyChartData.filter { $0.hasData }
            hasData = !weeksWithData.isEmpty
            bedtimeOffsets = weeksWithData.map { calendar.dateComponents([.minute], from: sixPMReference, to: $0.chartBedtime).minute ?? 0 }
            waketimeOffsets = weeksWithData.map { calendar.dateComponents([.minute], from: sixPMReference, to: $0.chartWaketime).minute ?? 0 }
        case .year:
            let monthsWithData = monthlyChartData.filter { $0.hasData }
            hasData = !monthsWithData.isEmpty
            bedtimeOffsets = monthsWithData.map { calendar.dateComponents([.minute], from: sixPMReference, to: $0.chartBedtime).minute ?? 0 }
            waketimeOffsets = monthsWithData.map { calendar.dateComponents([.minute], from: sixPMReference, to: $0.chartWaketime).minute ?? 0 }
        }

        let domainStartMinutes: Int
        let domainEndMinutes: Int

        if !hasData {
            domainStartMinutes = 120  // 8 PM
            domainEndMinutes = 840     // 8 AM
        } else {
            domainStartMinutes = (bedtimeOffsets.min() ?? 120) - 60
            domainEndMinutes = (waketimeOffsets.max() ?? 840) + 60
        }

        guard let domainStart = calendar.date(byAdding: .minute, value: domainStartMinutes, to: sixPMReference),
              let domainEnd = calendar.date(byAdding: .minute, value: domainEndMinutes, to: sixPMReference) else {
            return sixPMReference...sixPMReference
        }

        return domainStart...domainEnd
    }

    // MARK: - Helper Functions

    private func createSixPMReference() -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!

        var components = DateComponents()
        components.year = 2000
        components.month = 1
        components.day = 1
        components.hour = 18
        components.minute = 0
        components.second = 0

        return calendar.date(from: components) ?? Date()
    }

    private func calculateOffsetFromSixPM(_ time: Date) -> Int {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)

        if hour >= 18 {
            return (hour - 18) * 60 + minute
        } else {
            return (24 - 18 + hour) * 60 + minute
        }
    }

    private func formatYAxisLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        let sixPMReference = createSixPMReference()

        let minutesSinceReference = calendar.dateComponents([.minute], from: sixPMReference, to: date).minute ?? 0
        let hour = (minutesSinceReference / 60 + 18) % 24
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let period = hour < 12 ? "a" : "p"

        return "\(displayHour)\(period)"
    }

    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)

        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let period = hour < 12 ? "AM" : "PM"

        return String(format: "%d:%02d %@", displayHour, minute, period)
    }

    private func getVisibleDomainLength() -> TimeInterval {
        switch selectedPeriod {
        case .week:
            return 35 * 24 * 60 * 60
        case .month:
            return 33 * 24 * 60 * 60
        case .sixMonth:
            return 26 * 7 * 24 * 60 * 60
        case .year:
            return 12 * 30 * 24 * 60 * 60
        }
    }

    private func getVisibleDateRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let visibleLength = getVisibleDomainLength()
        let endDate = calendar.date(byAdding: .second, value: Int(visibleLength), to: scrollPosition) ?? scrollPosition
        return (scrollPosition, endDate)
    }

    private func initializeScrollPosition() {
        let calendar = Calendar.current
        let today = Date()
        let visibleLength = getVisibleDomainLength()

        let ninetyPercentOffset = visibleLength * 0.90
        scrollPosition = calendar.date(byAdding: .second, value: -Int(ninetyPercentOffset), to: today) ?? today
    }

    private func isAnyItemSelected() -> Bool {
        return selectedDate != nil || selectedWeek != nil || selectedMonth != nil
    }

    private func getSelectedData() -> (bedtime: Date, waketime: Date)? {
        if let date = selectedDate,
           let dayData = viewModel.dailySleepTimes.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            return (dayData.bedtime, dayData.waketime)
        }
        if let week = selectedWeek {
            return (week.avgBedtime, week.avgWaketime)
        }
        if let month = selectedMonth {
            return (month.avgBedtime, month.avgWaketime)
        }
        return nil
    }

    private func getDateRangeString() -> String {
        // Return selected item date or visible range
        if let date = selectedDate {
            return formatDateOnly(date)
        }
        if let week = selectedWeek {
            return formatWeekRange(week.weekStartDate, week.weekEndDate)
        }
        if let month = selectedMonth {
            return formatMonthRange(month.monthStartDate)
        }
        return visibleDateRangeString()
    }

    private func formatDateOnly(_ date: Date) -> String {
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        formatter.timeZone = TimeZone(identifier: "UTC")!

        return formatter.string(from: date)
    }

    private func formatWeekRange(_ start: Date, _ end: Date) -> String {
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.timeZone = TimeZone(identifier: "UTC")!

        let year = utcCalendar.component(.year, from: end)
        return "\(formatter.string(from: start)) - \(formatter.string(from: end)), \(year)"
    }

    private func formatMonthRange(_ date: Date) -> String {
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.timeZone = TimeZone(identifier: "UTC")!

        return formatter.string(from: date)
    }

    private func visibleDateRangeString() -> String {
        let range = getVisibleDateRange()
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")!

        switch selectedPeriod {
        case .week, .month:
            formatter.dateFormat = "MMM d"
            let year = utcCalendar.component(.year, from: range.end)
            return "\(formatter.string(from: range.start)) - \(formatter.string(from: range.end)), \(year)"
        case .sixMonth:
            formatter.dateFormat = "MMM d"
            let year = utcCalendar.component(.year, from: range.end)
            return "\(formatter.string(from: range.start)) - \(formatter.string(from: range.end)), \(year)"
        case .year:
            formatter.dateFormat = "MMM yyyy"
            return "\(formatter.string(from: range.start)) - \(formatter.string(from: range.end))"
        }
    }

    private func calculateVisibleAverages() -> (bedtime: Date, waketime: Date)? {
        let visibleRange = getVisibleDateRange()
        let calendar = Calendar.current

        switch selectedPeriod {
        case .week, .month:
            let visibleData = viewModel.dailySleepTimes.filter {
                $0.date >= visibleRange.start && $0.date <= visibleRange.end
            }
            guard !visibleData.isEmpty else { return nil }

            let totalBedtime = visibleData.reduce(0) { sum, data in
                sum + calculateOffsetFromSixPM(data.bedtime)
            }
            let totalWaketime = visibleData.reduce(0) { sum, data in
                sum + calculateOffsetFromSixPM(data.waketime)
            }

            let avgBedtimeMinutes = totalBedtime / visibleData.count
            let avgWaketimeMinutes = totalWaketime / visibleData.count

            let sixPMReference = createSixPMReference()
            guard let avgBedtime = calendar.date(byAdding: .minute, value: avgBedtimeMinutes, to: sixPMReference),
                  let avgWaketime = calendar.date(byAdding: .minute, value: avgWaketimeMinutes, to: sixPMReference) else {
                return nil
            }
            return (avgBedtime, avgWaketime)

        case .sixMonth:
            let visibleData = viewModel.weeklySleepAverages.filter {
                $0.weekStartDate >= visibleRange.start && $0.weekStartDate <= visibleRange.end
            }
            guard !visibleData.isEmpty else { return nil }

            let totalBedtime = visibleData.reduce(0) { sum, data in
                sum + calculateOffsetFromSixPM(data.avgBedtime)
            }
            let totalWaketime = visibleData.reduce(0) { sum, data in
                sum + calculateOffsetFromSixPM(data.avgWaketime)
            }

            let avgBedtimeMinutes = totalBedtime / visibleData.count
            let avgWaketimeMinutes = totalWaketime / visibleData.count

            let sixPMReference = createSixPMReference()
            guard let avgBedtime = calendar.date(byAdding: .minute, value: avgBedtimeMinutes, to: sixPMReference),
                  let avgWaketime = calendar.date(byAdding: .minute, value: avgWaketimeMinutes, to: sixPMReference) else {
                return nil
            }
            return (avgBedtime, avgWaketime)

        case .year:
            let visibleData = viewModel.monthlySleepAverages.filter {
                $0.monthStartDate >= visibleRange.start && $0.monthStartDate <= visibleRange.end
            }
            guard !visibleData.isEmpty else { return nil }

            let totalBedtime = visibleData.reduce(0) { sum, data in
                sum + calculateOffsetFromSixPM(data.avgBedtime)
            }
            let totalWaketime = visibleData.reduce(0) { sum, data in
                sum + calculateOffsetFromSixPM(data.avgWaketime)
            }

            let avgBedtimeMinutes = totalBedtime / visibleData.count
            let avgWaketimeMinutes = totalWaketime / visibleData.count

            let sixPMReference = createSixPMReference()
            guard let avgBedtime = calendar.date(byAdding: .minute, value: avgBedtimeMinutes, to: sixPMReference),
                  let avgWaketime = calendar.date(byAdding: .minute, value: avgWaketimeMinutes, to: sixPMReference) else {
                return nil
            }
            return (avgBedtime, avgWaketime)
        }
    }

    private func getDailyBarColor(for dayData: ChartDayData) -> Color {
        if let date = selectedDate, Calendar.current.isDate(dayData.date, inSameDayAs: date) {
            return color.opacity(0.6)
        }
        return color
    }

    private func getWeeklyBarColor(for weekData: ChartWeekData) -> Color {
        if let week = weekData.week, selectedWeek?.id == week.id {
            return color.opacity(0.6)
        }
        return color
    }

    private func getMonthlyBarColor(for monthData: ChartMonthData) -> Color {
        if let month = monthData.month, selectedMonth?.id == month.id {
            return color.opacity(0.6)
        }
        return color
    }

    private func handleChartTap(proxy: ChartProxy, location: CGPoint) {
        guard let tappedDate: Date = proxy.value(atX: location.x) else { return }

        switch selectedPeriod {
        case .week, .month:
            let closest = dailyChartData.filter { $0.hasData }.min(by: {
                abs($0.date.timeIntervalSince(tappedDate)) < abs($1.date.timeIntervalSince(tappedDate))
            })
            if let day = closest {
                let calendar = Calendar.current
                if let current = selectedDate, calendar.isDate(current, inSameDayAs: day.date) {
                    selectedDate = nil
                } else {
                    selectedDate = day.date
                }
            }

        case .sixMonth:
            let closest = weeklyChartData.compactMap { $0.week }.min(by: {
                abs($0.weekStartDate.timeIntervalSince(tappedDate)) < abs($1.weekStartDate.timeIntervalSince(tappedDate))
            })
            if let week = closest {
                if selectedWeek?.id == week.id {
                    selectedWeek = nil
                } else {
                    selectedWeek = week
                }
            }

        case .year:
            let closest = monthlyChartData.compactMap { $0.month }.min(by: {
                abs($0.monthStartDate.timeIntervalSince(tappedDate)) < abs($1.monthStartDate.timeIntervalSince(tappedDate))
            })
            if let month = closest {
                if selectedMonth?.id == month.id {
                    selectedMonth = nil
                } else {
                    selectedMonth = month
                }
            }
        }
    }

    // MARK: - About View

    private var aboutView: some View {
        ScrollView {
            if primaryViewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading content...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else if let error = primaryViewModel.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Unable to load content")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.top, 40)
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    if let about = primaryViewModel.aboutContent {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(color)
                                Text("About Sleep Consistency")
                                    .font(.headline)
                            }
                            Text(about)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let impact = primaryViewModel.longevityImpact {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: "heart.circle.fill")
                                    .foregroundColor(color)
                                Text("Health Impact")
                                    .font(.headline)
                            }
                            Text(impact)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let tips = primaryViewModel.quickTips, !tips.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "lightbulb.circle.fill")
                                    .foregroundColor(color)
                                Text("Quick Tips")
                                    .font(.headline)
                            }

                            ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1).")
                                        .fontWeight(.semibold)
                                        .foregroundColor(color)
                                    Text(tip)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }
}
