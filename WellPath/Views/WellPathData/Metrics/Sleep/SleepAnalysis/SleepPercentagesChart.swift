//
//  SleepPercentagesChart.swift
//  WellPath
//
//  Sleep stage percentages chart using aggregation cache
//

import SwiftUI
import Charts

struct SleepPercentagesChart: View {
    let color: Color
    @StateObject private var viewModel: SleepPercentagesViewModel
    @StateObject private var educationViewModel = TabEducationViewModel(metricId: "DISP_SLEEP_ANALYSIS_PERCENTAGES")

    @State private var showAbout = false
    @State private var selectedPeriod: TimePeriod = .week
    @State private var selectedStage: SleepStage?
    @State private var selectedBarDate: Date?
    @State private var scrollPosition: Date

    // Helper to get date granularity for period matching
    private func getDateGranularity(for period: TimePeriod) -> Calendar.Component {
        switch period {
        case .day: return .day
        case .week, .month: return .day
        case .sixMonth: return .weekOfYear
        case .year: return .month
        }
    }

    init(color: Color) {
        self.color = color
        _viewModel = StateObject(wrappedValue: SleepPercentagesViewModel(baseColor: color))

        // Initialize scroll position to today (normalized to start of day for day view matching)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        _scrollPosition = State(initialValue: today)
    }

    private static func calculateScrollPosition(for period: TimePeriod, referenceDate: Date) -> Date {
        let calendar = Calendar.current
        let visibleDuration = period.numberOfBars

        switch period {
        case .day:
            // Show today - visible window shows 1 day at a time (24 hours)
            // But we load multiple days of data so user can scroll left/right
            return referenceDate

        case .week:
            // Show today at 90% across
            let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
            return calendar.date(
                byAdding: period.calendarComponent,
                value: -offsetFromEnd,
                to: referenceDate
            ) ?? referenceDate

        case .month:
            // End at today + small buffer
            let endWithBuffer = calendar.date(byAdding: .day, value: 2, to: referenceDate) ?? referenceDate
            return calendar.date(
                byAdding: .day,
                value: -visibleDuration,
                to: endWithBuffer
            ) ?? referenceDate

        case .sixMonth:
            // Add 2 week buffer after most recent data
            let endWithBuffer = calendar.date(byAdding: .weekOfYear, value: 2, to: referenceDate) ?? referenceDate
            return calendar.date(
                byAdding: .weekOfYear,
                value: -visibleDuration,
                to: endWithBuffer
            ) ?? referenceDate

        case .year:
            // Add 1 month buffer after most recent data
            let endWithBuffer = calendar.date(byAdding: .month, value: 1, to: referenceDate) ?? referenceDate
            return calendar.date(
                byAdding: .month,
                value: -visibleDuration,
                to: endWithBuffer
            ) ?? referenceDate
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content
            if showAbout {
                aboutContentView
            } else {
                chartView
            }
        }
        .task {
            await educationViewModel.loadEducation()
            await viewModel.loadData(for: selectedPeriod)

            // Set scroll position after initial load
            if selectedPeriod == .day {
                // For day view, scroll to most recent data (LAST item, not first)
                scrollPosition = viewModel.chartData.last?.date ?? Date()
            } else {
                scrollPosition = Self.calculateScrollPosition(for: selectedPeriod, referenceDate: Date())
            }
        }
    }

    private var chartView: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading sleep data...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 300)
            } else {
                // Period selector
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 16)
                .onChange(of: selectedPeriod) { _, newPeriod in
                    selectedStage = nil
                    selectedBarDate = nil

                    Task {
                        await viewModel.loadData(for: newPeriod)

                        // Reset scroll position after data loads
                        if newPeriod == .day {
                            // Use normalized date (start of day) to match chartData dates
                            let calendar = Calendar.current
                            let today = calendar.startOfDay(for: Date())
                            scrollPosition = viewModel.chartData.last?.date ?? today
                        } else {
                            scrollPosition = Self.calculateScrollPosition(for: newPeriod, referenceDate: Date())
                        }
                    }
                }

                // Chart header with time in bed and time asleep
                chartHeader

                // Chart - different view for day vs other periods
                if selectedPeriod == .day {
                    scrollableDayChart
                } else {
                    chart
                }

                // Stage percentage selectors
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(stagePercentagesData, id: \.stage) { item in
                            stageButton(for: item)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var chartHeader: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(getTimeInBedLabel())
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text(formatDuration(getDisplayTimeInBed()))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(getTimeAsleepLabel())
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text(formatDuration(getDisplayTimeAsleep()))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                Spacer()

                // Info button (top-aligned with metrics)
                Button(action: {
                    withAnimation {
                        showAbout = true
                    }
                }) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(color)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(getSummaryDateLabel())
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    private func getTimeInBedLabel() -> String {
        if selectedPeriod == .day {
            return "TIME IN BED"
        } else if selectedBarDate != nil {
            // Bar selected
            switch selectedPeriod {
            case .week, .month: return "TIME IN BED"  // Specific day
            case .sixMonth, .year: return "AVG. TIME IN BED"  // Weekly/monthly average
            default: return "TIME IN BED"
            }
        } else {
            return "AVG. TIME IN BED"  // Average of visible window
        }
    }

    private func getTimeAsleepLabel() -> String {
        if selectedPeriod == .day {
            return "TIME ASLEEP"
        } else if selectedBarDate != nil {
            // Bar selected
            switch selectedPeriod {
            case .week, .month: return "TIME ASLEEP"  // Specific day
            case .sixMonth, .year: return "AVG. TIME ASLEEP"  // Weekly/monthly average
            default: return "TIME ASLEEP"
            }
        } else {
            return "AVG. TIME ASLEEP"  // Average of visible window
        }
    }

    // MARK: - Day Chart (Paginated 4-bar view, swipe between days)

    private var scrollableDayChart: some View {
        let _ = print("📊 Building day chart with \(viewModel.chartData.count) days, scrollPosition: \(scrollPosition)")

        return TabView(selection: Binding(
            get: { scrollPosition },
            set: { newValue in
                print("🔄 TabView selection changing to: \(newValue)")
                scrollPosition = newValue

                // Check if we're within 3 days of the oldest date - load more if so
                if selectedPeriod == .day, let oldestDate = viewModel.chartData.first?.date {
                    let calendar = Calendar.current
                    let daysDiff = calendar.dateComponents([.day], from: oldestDate, to: newValue).day ?? 0

                    if daysDiff <= 3 {
                        print("📥 Near edge (\(daysDiff) days from oldest), loading more data...")
                        Task {
                            await viewModel.loadMoreDaysBackward()
                        }
                    }
                }
            }
        )) {
            // Don't reverse - keep chronological order so swipe left = previous day
            ForEach(viewModel.chartData) { dateData in
                Chart {
                    // 6 bars: In Bed, Asleep, Deep, Core, REM, Awake
                    BarMark(
                        x: .value("Type", "In Bed"),
                        y: .value("Hours", dateData.timeInBedHours),
                        width: .fixed(40)
                    )
                    .foregroundStyle((Color(hex: "80CBC4") ?? .teal).opacity(0.3))

                    BarMark(
                        x: .value("Type", "Asleep"),
                        y: .value("Hours", dateData.timeAsleepHours),
                        width: .fixed(40)
                    )
                    .foregroundStyle((Color(hex: "80CBC4") ?? .teal).opacity(0.5))

                    BarMark(
                        x: .value("Type", "Deep"),
                        y: .value("Hours", dateData.stageHours["Deep"] ?? 0.0),
                        width: .fixed(40)
                    )
                    .foregroundStyle(selectedStage == nil || selectedStage == .deep ? SleepStage.deep.color : SleepStage.deep.color.opacity(0.3))

                    BarMark(
                        x: .value("Type", "Core"),
                        y: .value("Hours", dateData.stageHours["Core"] ?? 0.0),
                        width: .fixed(40)
                    )
                    .foregroundStyle(selectedStage == nil || selectedStage == .core ? SleepStage.core.color : SleepStage.core.color.opacity(0.3))

                    BarMark(
                        x: .value("Type", "REM"),
                        y: .value("Hours", dateData.stageHours["REM"] ?? 0.0),
                        width: .fixed(40)
                    )
                    .foregroundStyle(selectedStage == nil || selectedStage == .rem ? SleepStage.rem.color : SleepStage.rem.color.opacity(0.3))

                    BarMark(
                        x: .value("Type", "Awake"),
                        y: .value("Hours", dateData.stageHours["Awake"] ?? 0.0),
                        width: .fixed(40)
                    )
                    .foregroundStyle(selectedStage == nil || selectedStage == .awake ? SleepStage.awake.color : SleepStage.awake.color.opacity(0.3))
                }
                .frame(height: 220)
                .chartYScale(domain: 0...getMaxYValue())
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisValueLabel()
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                    }
                }
                .tag(dateData.date)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 220)
        .padding(.horizontal)
        .padding(.bottom, 24)
        .id(viewModel.chartData.count)  // Force rebuild when data changes
    }

    // MARK: - Scrollable Chart (W/M/6M/Y)

    private var chart: some View {
        ZStack(alignment: .center) {
            // Layer 1: TIME IN BED (background - light green/teal)
            Chart {
                ForEach(viewModel.chartData) { dateData in
                    BarMark(
                        x: .value("Date", dateData.date),
                        y: .value("Hours", dateData.timeInBedHours),
                        width: .fixed(getBarWidth())
                    )
                    .foregroundStyle((Color(hex: "80CBC4") ?? .teal).opacity(selectedBarDate != nil ? 0.15 : 0.3))
                }
            }
            .frame(height: 220)
            .chartScrollableAxes(.horizontal)
            .chartScrollPosition(x: $scrollPosition)
            .chartXVisibleDomain(length: getVisibleDomainTimeInterval())
            .chartYScale(domain: 0...getMaxYValue())
            .chartXAxis {
                AxisMarks(values: .stride(by: getAxisStride(), count: getAxisMultiplier())) { value in
                    if value.as(Date.self) != nil {
                        AxisValueLabel(format: getAxisFormat())
                            .foregroundStyle(Color.clear)  // Invisible but takes up space
                        AxisGridLine()
                            .foregroundStyle(Color.clear)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { value in
                    AxisValueLabel()
                        .foregroundStyle(Color.clear)  // Invisible but takes up space
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(Color.clear)
                }
            }
            .allowsHitTesting(false)  // Let touches pass through to top layer

            // Layer 2: TIME ASLEEP (middle - medium teal)
            Chart {
                ForEach(viewModel.chartData) { dateData in
                    BarMark(
                        x: .value("Date", dateData.date),
                        y: .value("Hours", dateData.timeAsleepHours),
                        width: .fixed(getBarWidth())
                    )
                    .foregroundStyle((Color(hex: "80CBC4") ?? .teal).opacity(selectedBarDate != nil ? 0.25 : 0.5))
                }
            }
            .frame(height: 220)
            .chartScrollableAxes(.horizontal)
            .chartScrollPosition(x: $scrollPosition)
            .chartXVisibleDomain(length: getVisibleDomainTimeInterval())
            .chartYScale(domain: 0...getMaxYValue())
            .chartXAxis {
                AxisMarks(values: .stride(by: getAxisStride(), count: getAxisMultiplier())) { value in
                    if value.as(Date.self) != nil {
                        AxisValueLabel(format: getAxisFormat())
                            .foregroundStyle(Color.clear)  // Invisible but takes up space
                        AxisGridLine()
                            .foregroundStyle(Color.clear)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { value in
                    AxisValueLabel()
                        .foregroundStyle(Color.clear)  // Invisible but takes up space
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(Color.clear)
                }
            }
            .allowsHitTesting(false)  // Let touches pass through to top layer

            // Layer 3: STAGE BARS (foreground - stacked colored bars with interaction)
            Chart {
                // Selection indicator
                if let selectedDate = selectedBarDate {
                    RuleMark(x: .value("Selected", selectedDate))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .foregroundStyle(Color.black.opacity(0.3))
                }

                ForEach(viewModel.chartData) { dateData in
                    let sortedStages = selectedStage != nil ? getSortedStagesForStacking() : [.deep, .core, .rem, .awake]

                    ForEach(sortedStages, id: \.self) { stage in
                        let hours = dateData.stageHours[stage.rawValue] ?? 0.0
                        BarMark(
                            x: .value("Date", dateData.date),
                            y: .value("Hours", hours),
                            width: .fixed(getBarWidth())
                        )
                        .foregroundStyle(getStageColorForChart(stage: stage, isBarSelected: selectedBarDate == dateData.date))
                        .opacity(getStageOpacity(for: stage))
                    }
                }
            }
            .frame(height: 220)
            .chartScrollableAxes(.horizontal)
            .chartScrollPosition(x: $scrollPosition)
            .chartXVisibleDomain(length: getVisibleDomainTimeInterval())
            .chartYScale(domain: 0...getMaxYValue())
            .chartGesture { proxy in
                SpatialTapGesture()
                    .onEnded { value in
                        if let tappedDate: Date = proxy.value(atX: value.location.x) {
                            let closest = viewModel.chartData.min(by: {
                                abs($0.date.timeIntervalSince(tappedDate)) < abs($1.date.timeIntervalSince(tappedDate))
                            })

                            if selectedBarDate == closest?.date {
                                selectedBarDate = nil
                            } else {
                                selectedBarDate = closest?.date
                            }
                        }
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: getAxisStride(), count: getAxisMultiplier())) { value in
                    if value.as(Date.self) != nil {
                        AxisValueLabel(format: getAxisFormat())
                        AxisGridLine()
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { value in
                    AxisValueLabel()
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(Color.secondary.opacity(0.2))
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
        .onChange(of: scrollPosition) { _, _ in
            selectedBarDate = nil
        }
    }

    // MARK: - Helper Functions

    private func getSortedStagesForStacking() -> [SleepStage] {
        // Put selected stage first (bottom of stack), then others
        guard let selected = selectedStage else {
            return [.deep, .core, .rem, .awake]
        }
        var stages: [SleepStage] = [.deep, .core, .rem, .awake]
        stages.removeAll { $0 == selected }
        return [selected] + stages
    }

    private func getStageColorForChart(stage: SleepStage, isBarSelected: Bool) -> Color {
        // Always use stage colors so they're visible when stacked
        return stage.color
    }

    private func getStageOpacity(for stage: SleepStage) -> Double {
        if selectedStage == nil {
            // No selection - show all stages stacked
            return 1.0
        } else {
            // Stage selected - show selected at full opacity, others at 30%
            return selectedStage == stage ? 1.0 : 0.3
        }
    }

    private func getMaxYValue() -> Double {
        if selectedPeriod == .day {
            // For day view, use time in bed for the currently visible day
            let calendar = Calendar.current
            let visibleDayData = viewModel.chartData.filter {
                calendar.isDate($0.date, equalTo: scrollPosition, toGranularity: .day)
            }

            guard let dayData = visibleDayData.first else {
                // Default to 5 hours if no data
                return 5.0
            }

            // Use time in bed (the background layer) for scaling
            let timeInBed = dayData.timeInBedHours

            if timeInBed == 0.0 {
                // No data - default to 5 hours
                return 5.0
            }

            // Add 20% buffer and round up
            return ceil(timeInBed * 1.2)
        } else {
            // For other views, use time in bed (which includes awake time)
            let maxTimeInBed = viewModel.chartData.map { $0.timeInBedHours }.max() ?? 8.0
            // Add 20% buffer
            return ceil(maxTimeInBed * 1.2)
        }
    }

    private func getBarWidth() -> CGFloat {
        switch selectedPeriod {
        case .day: return 10
        case .week: return 35
        case .month: return 8
        case .sixMonth: return 10
        case .year: return 22
        }
    }

    private func getVisibleDomainTimeInterval() -> TimeInterval {
        let duration = selectedPeriod.numberOfBars
        switch selectedPeriod {
        case .day: return TimeInterval(duration * 3600) // hours
        case .week, .month: return TimeInterval(duration * 24 * 3600) // days
        case .sixMonth: return TimeInterval(duration * 7 * 24 * 3600) // weeks
        case .year: return TimeInterval(duration * 30 * 24 * 3600) // months (approximate)
        }
    }

    private func getAxisStride() -> Calendar.Component {
        switch selectedPeriod {
        case .day: return .hour
        case .week: return .day
        case .month: return .weekOfYear
        case .sixMonth: return .month
        case .year: return .month
        }
    }

    private func getAxisMultiplier() -> Int {
        switch selectedPeriod {
        case .day: return 6
        case .week: return 1
        case .month: return 1
        case .sixMonth: return 1
        case .year: return 1
        }
    }

    private func getAxisFormat() -> Date.FormatStyle {
        switch selectedPeriod {
        case .day: return .dateTime.hour(.defaultDigits(amPM: .abbreviated))
        case .week: return .dateTime.weekday(.narrow)
        case .month: return .dateTime.day(.defaultDigits)
        case .sixMonth: return .dateTime.month(.abbreviated)
        case .year: return .dateTime.month(.narrow)
        }
    }

    private func getSummaryDateLabel() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let calendar = Calendar.current

        if let selectedDate = selectedBarDate {
            // Show appropriate range/format based on period
            switch selectedPeriod {
            case .sixMonth:
                // Show week range: Monday-Sunday
                // Database uses Monday start (same as date_trunc('week', ...) in Postgres)
                var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)
                components.weekday = 2  // Monday (1 = Sunday, 2 = Monday)
                let mondayStart = calendar.date(from: components) ?? selectedDate
                guard let sundayEnd = calendar.date(byAdding: .day, value: 6, to: mondayStart) else {
                    formatter.dateFormat = "MMM d, yyyy"
                    return formatter.string(from: selectedDate)
                }
                let yearFormatter = DateFormatter()
                yearFormatter.dateFormat = ", yyyy"
                return "\(formatter.string(from: mondayStart)) - \(formatter.string(from: sundayEnd))\(yearFormatter.string(from: sundayEnd))"

            case .year:
                // Show month name: "Nov 2025"
                formatter.dateFormat = "MMM yyyy"
                return formatter.string(from: selectedDate)

            default:
                // W/M/D: Show single date
                formatter.dateFormat = "MMM d, yyyy"
                return formatter.string(from: selectedDate)
            }
        } else if selectedPeriod == .day {
            // For day view, show the currently visible day from scroll position
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: scrollPosition)
        } else {
            // For other periods, show date range
            let calendar = Calendar.current
            let visibleDuration = selectedPeriod.numberOfBars
            // Subtract 1 because we're showing inclusive range (start date counts as day 1)
            guard let endDate = calendar.date(byAdding: selectedPeriod.calendarComponent, value: visibleDuration - 1, to: scrollPosition) else {
                return ""
            }
            return "\(formatter.string(from: scrollPosition)) - \(formatter.string(from: endDate))"
        }
    }

    private func getDisplayTimeInBed() -> TimeInterval {
        if let selectedDate = selectedBarDate {
            // Show specific bar's time in bed using appropriate granularity
            let granularity = getDateGranularity(for: selectedPeriod)
            if let data = viewModel.chartData.first(where: { Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: granularity) }) {
                return data.timeInBedHours * 3600
            }
            return 0
        } else if selectedPeriod == .day {
            // For day view, show the value for the currently visible day
            let calendar = Calendar.current
            let normalizedScroll = calendar.startOfDay(for: scrollPosition)

            if let data = viewModel.chartData.first(where: {
                let normalizedData = calendar.startOfDay(for: $0.date)
                return normalizedData == normalizedScroll
            }) {
                print("📊 Day view showing time in bed for \(data.date): \(data.timeInBedHours)h")
                return data.timeInBedHours * 3600
            }
            print("⚠️ No matching data found for scrollPosition: \(scrollPosition)")
            return 0
        } else {
            // Show average for visible window
            return viewModel.getAverageTimeInBed(scrollPosition: scrollPosition, period: selectedPeriod)
        }
    }

    private func getDisplayTimeAsleep() -> TimeInterval {
        if let selectedDate = selectedBarDate {
            // Show specific bar's time asleep using appropriate granularity
            let granularity = getDateGranularity(for: selectedPeriod)
            if let data = viewModel.chartData.first(where: { Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: granularity) }) {
                return data.timeAsleepHours * 3600
            }
            return 0
        } else if selectedPeriod == .day {
            // For day view, show the value for the currently visible day
            let calendar = Calendar.current
            let normalizedScroll = calendar.startOfDay(for: scrollPosition)

            if let data = viewModel.chartData.first(where: {
                let normalizedData = calendar.startOfDay(for: $0.date)
                return normalizedData == normalizedScroll
            }) {
                print("📊 Day view showing time asleep for \(data.date): \(data.timeAsleepHours)h")
                return data.timeAsleepHours * 3600
            }
            print("⚠️ No matching data found for scrollPosition: \(scrollPosition)")
            return 0
        } else {
            // Show average for visible window
            return viewModel.getAverageTimeAsleep(scrollPosition: scrollPosition, period: selectedPeriod)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds / 3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private var stagePercentagesData: [(stage: SleepStage, percentage: Double)] {
        let dataToAnalyze: [SleepStageChartData]

        if let selectedDate = selectedBarDate {
            // Use appropriate granularity based on period (.day for W/M, .weekOfYear for 6M, .month for Y)
            let granularity = getDateGranularity(for: selectedPeriod)
            dataToAnalyze = viewModel.chartData.filter { Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: granularity) }
        } else if selectedPeriod == .day {
            // For day view, only analyze the currently visible day from scrollPosition
            dataToAnalyze = viewModel.chartData.filter { Calendar.current.isDate($0.date, equalTo: scrollPosition, toGranularity: .day) }
        } else {
            // For other periods, analyze the visible window
            let calendar = Calendar.current
            let visibleDuration = selectedPeriod.numberOfBars
            guard let endDate = calendar.date(byAdding: selectedPeriod.calendarComponent, value: visibleDuration, to: scrollPosition) else {
                return defaultStageData
            }
            dataToAnalyze = viewModel.chartData.filter { $0.date >= scrollPosition && $0.date <= endDate }
        }

        guard !dataToAnalyze.isEmpty else {
            return defaultStageData
        }

        // Sum stage hours and total sleep duration across all data points
        var stageTotals: [SleepStage: Double] = [:]
        var totalSleepDuration: Double = 0

        for data in dataToAnalyze {
            // Sum each stage
            for (key, value) in data.stageHours {
                if let stage = SleepStage(rawValue: key) {
                    stageTotals[stage, default: 0] += value
                }
            }
            // Sum total sleep duration (AGG_SLEEP_DURATION)
            totalSleepDuration += data.timeAsleepHours
        }

        // Calculate percentages relative to total sleep duration (not sum of stages)
        guard totalSleepDuration > 0 else {
            return defaultStageData
        }

        let deepPct = (stageTotals[.deep] ?? 0) / totalSleepDuration * 100
        let corePct = (stageTotals[.core] ?? 0) / totalSleepDuration * 100
        let remPct = (stageTotals[.rem] ?? 0) / totalSleepDuration * 100
        let awakePct = (stageTotals[.awake] ?? 0) / totalSleepDuration * 100

        print("📊 Percentage calc - Deep: \(stageTotals[.deep] ?? 0)h, Core: \(stageTotals[.core] ?? 0)h, REM: \(stageTotals[.rem] ?? 0)h, Awake: \(stageTotals[.awake] ?? 0)h, Total Sleep: \(totalSleepDuration)h")
        print("📊 Percentages - Deep: \(deepPct)%, Core: \(corePct)%, REM: \(remPct)%, Awake: \(awakePct)%, Sum: \(deepPct + corePct + remPct + awakePct)%")

        return [
            (.deep, deepPct),
            (.core, corePct),
            (.rem, remPct),
            (.awake, awakePct)
        ]
    }

    private var defaultStageData: [(stage: SleepStage, percentage: Double)] {
        [(.deep, 0), (.core, 0), (.rem, 0), (.awake, 0)]
    }

    private func stageButton(for item: (stage: SleepStage, percentage: Double)) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if selectedStage == item.stage {
                    selectedStage = nil
                } else {
                    selectedStage = item.stage
                }
            }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(item.stage.color)
                    .frame(width: 12, height: 12)

                Text(stageName(for: item.stage))
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(String(format: "%.0f%%", item.percentage))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedStage == item.stage ? item.stage.color.opacity(0.15) : Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
    }

    private func stageName(for stage: SleepStage) -> String {
        switch stage {
        case .awake: return "Awake"
        case .rem: return "REM"
        case .core: return "Core"
        case .deep: return "Deep"
        default: return ""
        }
    }

    private var aboutContentView: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                if let education = educationViewModel.education {
                    VStack(alignment: .leading, spacing: 24) {
                        if let about = education.aboutContent {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 10) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(color)
                                    Text("About")
                                        .font(.headline)
                                }
                                Text(about)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if let impact = education.longevityImpact {
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

                        if let tips = education.quickTips {
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
                    .padding(.top, 40) // Space for close button
                }
            }
            .background(Color.clear)

            // Close button (floating, top-right)
            Button(action: {
                withAnimation {
                    showAbout = false
                }
            }) {
                Image(systemName: "chart.bar")
                    .font(.title3)
                    .foregroundColor(color)
            }
            .padding(.top, 8)
            .padding(.trailing, 16)
        }
        .background(Color.clear)
    }
}

// MARK: - ViewModel

@MainActor
class SleepPercentagesViewModel: ObservableObject {
    @Published var chartData: [SleepStageChartData] = []
    @Published var isLoading = false

    private var stageDataCache: [String: [SleepChartDataPoint]] = [:]  // agg_metric_id -> data points
    private var timeInBedCache: [SleepChartDataPoint] = []
    private var timeAsleepCache: [SleepChartDataPoint] = []

    // Daily sums for calculating true averages (not average of averages)
    private var dailyTimeInBedCache: [SleepChartDataPoint] = []
    private var dailyTimeAsleepCache: [SleepChartDataPoint] = []

    // Track loaded date range for pagination
    private var currentOldestDate: Date?
    private var currentNewestDate: Date?
    private var currentPeriod: TimePeriod?
    private var isLoadingMore = false

    private let supabase = SupabaseManager.shared.client
    private let baseColor: Color

    // Sleep stage aggregation IDs
    private let stageAggIds = [
        "AGG_DEEP_SLEEP_DURATION",
        "AGG_CORE_SLEEP_DURATION",
        "AGG_REM_SLEEP_DURATION",
        "AGG_AWAKE_DURATION"
    ]

    init(baseColor: Color) {
        self.baseColor = baseColor
    }

    func loadData(for period: TimePeriod) async {
        isLoading = true
        stageDataCache.removeAll()
        timeInBedCache.removeAll()
        timeAsleepCache.removeAll()
        dailyTimeInBedCache.removeAll()
        dailyTimeAsleepCache.removeAll()

        do {
            let userId = try await supabase.auth.session.user.id
            // For percentages, day view shows daily data (4 bars per day), not hourly
            let periodType = period == .day ? "daily" : period.databasePeriodType
            let calculationType = period == .day ? "SUM" : period.calculationType

            // Calculate date range
            let now = Date()
            let calendar = Calendar.current

            // For day view, only load data up to today (not into the future)
            let newestDate: Date
            if period == .day {
                newestDate = now
            } else {
                newestDate = calendar.date(byAdding: .month, value: 1, to: now) ?? now
            }

            var oldestDate: Date
            switch period {
            case .day:
                oldestDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            case .week:
                oldestDate = calendar.date(byAdding: .weekOfYear, value: -8, to: now) ?? now
            case .month:
                oldestDate = calendar.date(byAdding: .month, value: -6, to: now) ?? now
            case .sixMonth:
                let tempDate = calendar.date(byAdding: .month, value: -18, to: now) ?? now
                // Align to Monday for weekly bars
                var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: tempDate)
                components.weekday = 2  // Monday
                oldestDate = calendar.date(from: components) ?? tempDate
            case .year:
                let tempDate = calendar.date(byAdding: .year, value: -3, to: now) ?? now
                // Align to 1st of month for monthly bars
                oldestDate = calendar.dateComponents([.calendar, .year, .month], from: tempDate).date ?? tempDate
            }

            // Fetch stage duration data
            let stageResults: [AggregationResult] = try await supabase
                .from("aggregation_results_cache")
                .select()
                .eq("patient_id", value: userId)
                .in("agg_metric_id", values: stageAggIds)
                .eq("period_type", value: periodType)
                .eq("calculation_type_id", value: calculationType)
                .gte("period_start", value: oldestDate.ISO8601Format())
                .lte("period_start", value: newestDate.ISO8601Format())
                .order("period_start", ascending: true)
                .execute()
                .value

            // Fetch time in bed and time asleep for chart display
            let timeResults: [AggregationResult] = try await supabase
                .from("aggregation_results_cache")
                .select()
                .eq("patient_id", value: userId)
                .in("agg_metric_id", values: ["AGG_TIME_IN_BED", "AGG_SLEEP_DURATION"])
                .eq("period_type", value: periodType)
                .eq("calculation_type_id", value: calculationType)
                .gte("period_start", value: oldestDate.ISO8601Format())
                .lte("period_start", value: newestDate.ISO8601Format())
                .order("period_start", ascending: true)
                .execute()
                .value

            // ALWAYS fetch daily sums for true average calculations (avoid averaging averages)
            let dailyTimeResults: [AggregationResult] = try await supabase
                .from("aggregation_results_cache")
                .select()
                .eq("patient_id", value: userId)
                .in("agg_metric_id", values: ["AGG_TIME_IN_BED", "AGG_SLEEP_DURATION"])
                .eq("period_type", value: "daily")
                .eq("calculation_type_id", value: "SUM")
                .gte("period_start", value: oldestDate.ISO8601Format())
                .lte("period_start", value: newestDate.ISO8601Format())
                .order("period_start", ascending: true)
                .execute()
                .value

            print("🌙 Fetched \(stageResults.count) stage data points for \(period.rawValue)")
            print("🌙 Fetched \(dailyTimeResults.count) daily time data points for average calculations")

            // Group stage data by agg_metric_id
            for result in stageResults {
                if stageDataCache[result.aggMetricId] == nil {
                    stageDataCache[result.aggMetricId] = []
                }
                let isHourly = periodType == "hourly"
                let localDate = result.periodStart.toLocalDateForTimeline(preserveTime: isHourly)
                stageDataCache[result.aggMetricId]?.append(SleepChartDataPoint(
                    date: localDate,
                    value: result.value ?? 0,
                    label: ""
                ))
            }

            // Group time data for chart display
            for result in timeResults {
                let isHourlyTime = periodType == "hourly"
                let localDate = result.periodStart.toLocalDateForTimeline(preserveTime: isHourlyTime)
                let dataPoint = SleepChartDataPoint(date: localDate, value: result.value ?? 0, label: "")

                if result.aggMetricId == "AGG_TIME_IN_BED" {
                    timeInBedCache.append(dataPoint)
                } else if result.aggMetricId == "AGG_SLEEP_DURATION" {
                    timeAsleepCache.append(dataPoint)
                }
            }

            // Group daily time data for average calculations (always daily, never hourly)
            for result in dailyTimeResults {
                let localDate = result.periodStart.toLocalDateForTimeline(preserveTime: false)
                let dataPoint = SleepChartDataPoint(date: localDate, value: result.value ?? 0, label: "")

                if result.aggMetricId == "AGG_TIME_IN_BED" {
                    dailyTimeInBedCache.append(dataPoint)
                } else if result.aggMetricId == "AGG_SLEEP_DURATION" {
                    dailyTimeAsleepCache.append(dataPoint)
                }
            }

            // Build chart data
            buildChartData(for: period, oldestDate: oldestDate, newestDate: newestDate)

            // Store current date range for pagination
            currentOldestDate = oldestDate
            currentNewestDate = newestDate
            currentPeriod = period

        } catch {
            print("❌ Error loading sleep percentages data: \(error)")
        }

        isLoading = false
    }

    func loadMoreDaysBackward() async {
        // Prevent multiple simultaneous loads
        guard !isLoadingMore, let period = currentPeriod, period == .day else { return }
        guard let oldestDate = currentOldestDate else { return }

        isLoadingMore = true
        print("📥 Loading 7 more days backward from \(oldestDate)...")

        do {
            let userId = try await supabase.auth.session.user.id
            let calendar = Calendar.current

            // Load 7 more days going backward
            let newOldestDate = calendar.date(byAdding: .day, value: -7, to: oldestDate) ?? oldestDate

            // Fetch stage duration data for new date range
            let stageResults: [AggregationResult] = try await supabase
                .from("aggregation_results_cache")
                .select()
                .eq("patient_id", value: userId)
                .in("agg_metric_id", values: stageAggIds)
                .eq("period_type", value: "daily")
                .eq("calculation_type_id", value: "SUM")
                .gte("period_start", value: newOldestDate.ISO8601Format())
                .lt("period_start", value: oldestDate.ISO8601Format())  // Only new data
                .order("period_start", ascending: true)
                .execute()
                .value

            // Merge new data into cache (loadMoreDaysBackward uses daily period_type)
            for result in stageResults {
                let localDate = result.periodStart.toLocalDateForTimeline(preserveTime: false)
                let dataPoint = SleepChartDataPoint(
                    date: localDate,
                    value: result.value ?? 0,
                    label: ""
                )
                stageDataCache[result.aggMetricId, default: []].append(dataPoint)
            }

            // Sort caches after adding new data
            for key in stageDataCache.keys {
                stageDataCache[key]?.sort { $0.date < $1.date }
            }

            // Fetch time in bed and time asleep for new range
            let timeResults: [AggregationResult] = try await supabase
                .from("aggregation_results_cache")
                .select()
                .eq("patient_id", value: userId)
                .in("agg_metric_id", values: ["AGG_TIME_IN_BED", "AGG_SLEEP_DURATION"])
                .eq("period_type", value: "daily")
                .eq("calculation_type_id", value: "SUM")
                .gte("period_start", value: newOldestDate.ISO8601Format())
                .lt("period_start", value: oldestDate.ISO8601Format())
                .order("period_start", ascending: true)
                .execute()
                .value

            for result in timeResults {
                let localDate = result.periodStart.toLocalDateForTimeline(preserveTime: false)
                let dataPoint = SleepChartDataPoint(
                    date: localDate,
                    value: result.value ?? 0,
                    label: ""
                )
                if result.aggMetricId == "AGG_TIME_IN_BED" {
                    timeInBedCache.append(dataPoint)
                    dailyTimeInBedCache.append(dataPoint)
                } else if result.aggMetricId == "AGG_SLEEP_DURATION" {
                    timeAsleepCache.append(dataPoint)
                    dailyTimeAsleepCache.append(dataPoint)
                }
            }

            // Sort time caches
            timeInBedCache.sort { $0.date < $1.date }
            timeAsleepCache.sort { $0.date < $1.date }
            dailyTimeInBedCache.sort { $0.date < $1.date }
            dailyTimeAsleepCache.sort { $0.date < $1.date }

            // Rebuild chart data with extended range
            buildChartData(for: period, oldestDate: newOldestDate, newestDate: currentNewestDate ?? Date())

            // Update stored oldest date
            currentOldestDate = newOldestDate

            print("✅ Loaded more data, now showing \(chartData.count) days")

        } catch {
            print("❌ Error loading more days: \(error)")
        }

        isLoadingMore = false
    }

    private func buildChartData(for period: TimePeriod, oldestDate: Date, newestDate: Date) {
        var timeline: [SleepStageChartData] = []
        let calendar = Calendar.current
        let granularity = getDateGranularity(for: period)

        // For D view, only use cache dates (no timeline needed)
        // For W/M/6M/Y views, generate full timeline so chart is scrollable
        if period == .day {
            // Day view: only show actual dates with data
            var allDates = Set<Date>()

            for dataPoint in timeInBedCache {
                allDates.insert(dataPoint.date)
            }
            for dataPoint in timeAsleepCache {
                allDates.insert(dataPoint.date)
            }
            for (_, dataPoints) in stageDataCache {
                for dataPoint in dataPoints {
                    allDates.insert(dataPoint.date)
                }
            }

            let sortedDates = allDates.sorted()

            for barDate in sortedDates {
                let normalizedDate = calendar.startOfDay(for: barDate)

                var stageHours: [String: Double] = [:]
                for (aggId, dataPoints) in stageDataCache {
                    if let value = dataPoints.first(where: { calendar.isDate($0.date, equalTo: barDate, toGranularity: granularity) })?.value {
                        let hours = value / 60.0
                        let stage = stageNameFromAggId(aggId)
                        stageHours[stage] = hours
                    }
                }

                let timeInBedMinutes = timeInBedCache.first(where: {
                    calendar.isDate($0.date, equalTo: barDate, toGranularity: granularity)
                })?.value ?? 0

                let timeAsleepMinutes = timeAsleepCache.first(where: {
                    calendar.isDate($0.date, equalTo: barDate, toGranularity: granularity)
                })?.value ?? 0

                timeline.append(SleepStageChartData(
                    date: normalizedDate,
                    stageHours: stageHours,
                    timeInBedHours: timeInBedMinutes / 60.0,
                    timeAsleepHours: timeAsleepMinutes / 60.0
                ))
            }
        } else {
            // W/M/6M/Y views: Generate full timeline from oldestDate to newestDate
            // This ensures scrollability even with sparse data
            var currentDate = oldestDate
            let incrementComponent: Calendar.Component = period.calendarComponent

            while currentDate <= newestDate {
                let barDate: Date
                if period == .year {
                    // Yearly: center bar at noon on 15th of month
                    var components = calendar.dateComponents([.year, .month], from: currentDate)
                    components.day = 15
                    components.hour = 12
                    barDate = calendar.date(from: components) ?? currentDate
                } else if period == .sixMonth {
                    // 6M: weekly bars, align to Wednesday noon (middle of Mon-Sun week)
                    var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: currentDate)
                    components.weekday = 2  // Monday
                    let monday = calendar.date(from: components) ?? currentDate
                    barDate = calendar.date(byAdding: .init(day: 2, hour: 12), to: monday) ?? monday
                } else {
                    // W/M: daily bars, center at noon
                    let startOfDay = calendar.startOfDay(for: currentDate)
                    barDate = calendar.date(byAdding: .hour, value: 12, to: startOfDay) ?? currentDate
                }

                // Get stage durations for this date (values are in MINUTES, convert to hours)
                var stageHours: [String: Double] = [:]
                for (aggId, dataPoints) in stageDataCache {
                    if let value = dataPoints.first(where: { calendar.isDate($0.date, equalTo: barDate, toGranularity: granularity) })?.value {
                        let hours = value / 60.0
                        let stage = stageNameFromAggId(aggId)
                        stageHours[stage] = hours
                    }
                }

                // Get time in bed and time asleep (values are in MINUTES, convert to hours)
                let timeInBedMinutes = timeInBedCache.first(where: {
                    calendar.isDate($0.date, equalTo: barDate, toGranularity: granularity)
                })?.value ?? 0

                let timeAsleepMinutes = timeAsleepCache.first(where: {
                    calendar.isDate($0.date, equalTo: barDate, toGranularity: granularity)
                })?.value ?? 0

                timeline.append(SleepStageChartData(
                    date: barDate,
                    stageHours: stageHours,
                    timeInBedHours: timeInBedMinutes / 60.0,
                    timeAsleepHours: timeAsleepMinutes / 60.0
                ))

                guard let nextDate = calendar.date(byAdding: incrementComponent, value: 1, to: currentDate) else {
                    break
                }
                currentDate = nextDate
            }
        }

        chartData = timeline
        let dataCount = timeline.filter { $0.totalSleepHours > 0 }.count
        print("🌙 Built chart with \(timeline.count) timeline points (\(dataCount) with data)")
    }

    private func stageNameFromAggId(_ aggId: String) -> String {
        switch aggId {
        case "AGG_DEEP_SLEEP_DURATION": return SleepStage.deep.rawValue
        case "AGG_CORE_SLEEP_DURATION": return SleepStage.core.rawValue
        case "AGG_REM_SLEEP_DURATION": return SleepStage.rem.rawValue
        case "AGG_AWAKE_DURATION": return SleepStage.awake.rawValue
        default: return ""
        }
    }

    private func getDateGranularity(for period: TimePeriod) -> Calendar.Component {
        switch period {
        case .day: return .day  // For percentages, day view uses daily data
        case .week, .month: return .day
        case .sixMonth: return .weekOfYear
        case .year: return .month
        }
    }

    func getAverageTimeInBed(scrollPosition: Date, period: TimePeriod) -> TimeInterval {
        let calendar = Calendar.current

        // Calculate the end of the visible window
        guard let endDate = calendar.date(byAdding: period.calendarComponent, value: period.numberOfBars, to: scrollPosition) else {
            return 0
        }

        // Filter daily data that falls within the visible window
        let visibleDailyData = dailyTimeInBedCache.filter { dataPoint in
            guard dataPoint.value > 0 else { return false }
            return dataPoint.date >= scrollPosition && dataPoint.date < endDate
        }
        guard !visibleDailyData.isEmpty else { return 0 }

        // Sum all daily values and divide by number of days with data
        let totalMinutes = visibleDailyData.reduce(0.0) { $0 + $1.value }
        let averageMinutes = totalMinutes / Double(visibleDailyData.count)
        return (averageMinutes / 60.0) * 3600 // Convert minutes to hours to seconds
    }

    func getAverageTimeAsleep(scrollPosition: Date, period: TimePeriod) -> TimeInterval {
        let calendar = Calendar.current

        // Calculate the end of the visible window
        guard let endDate = calendar.date(byAdding: period.calendarComponent, value: period.numberOfBars, to: scrollPosition) else {
            return 0
        }

        // Filter daily data that falls within the visible window
        let visibleDailyData = dailyTimeAsleepCache.filter { dataPoint in
            guard dataPoint.value > 0 else { return false }
            return dataPoint.date >= scrollPosition && dataPoint.date < endDate
        }
        guard !visibleDailyData.isEmpty else { return 0 }

        // Sum all daily values and divide by number of days with data
        let totalMinutes = visibleDailyData.reduce(0.0) { $0 + $1.value }
        let averageMinutes = totalMinutes / Double(visibleDailyData.count)
        return (averageMinutes / 60.0) * 3600 // Convert minutes to hours to seconds
    }
}

// MARK: - Data Models

struct SleepStageChartData: Identifiable {
    let id = UUID()
    let date: Date
    let stageHours: [String: Double]  // stage.rawValue -> hours
    let timeInBedHours: Double
    let timeAsleepHours: Double

    var totalSleepHours: Double {
        stageHours.values.reduce(0, +)
    }
}

private struct SleepChartDataPoint {
    let date: Date
    let value: Double
    let label: String
}

#Preview {
    SleepPercentagesChart(color: MetricsUIConfig.getPillarColor(for: "Sleep"))
}
