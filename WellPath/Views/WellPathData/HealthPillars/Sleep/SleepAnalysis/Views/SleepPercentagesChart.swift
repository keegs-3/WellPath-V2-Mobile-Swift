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
    @ObservedObject var sleepViewModel: SleepAnalysisViewModel  // Shared with SleepAnalysisView for Day view

    @State private var showAboutModal = false
    @State private var selectedPeriod: TimePeriod = .week
    @State private var selectedStage: SleepStage?
    @State private var selectedBarDate: Date?
    @State private var scrollPosition: Date  // For W/M/6M/Y scrollable charts
    @State private var dayViewIndex: Int = 0  // Int index for Day view TabView (like DayViewChart)
    @State private var hasInitializedScroll = false

    // Explicit state for Day view - updated via onChange to force UI refresh
    @State private var currentDayTimeInBed: Double = 0
    @State private var currentDayTimeAsleep: Double = 0
    @State private var currentDayStageHours: [String: Double] = [:]
    @State private var currentDayDateValue: Date = Date()

    // Helper to get date granularity for period matching
    private func getDateGranularity(for period: TimePeriod) -> Calendar.Component {
        switch period {
        case .day: return .day
        case .week, .month: return .day
        case .sixMonth: return .weekOfYear
        case .year: return .month
        }
    }

    init(color: Color, sleepViewModel: SleepAnalysisViewModel) {
        self.color = color
        self.sleepViewModel = sleepViewModel
        _viewModel = StateObject(wrappedValue: SleepPercentagesViewModel(baseColor: color))

        // Initialize scroll position to today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        _scrollPosition = State(initialValue: today)
        // dayViewIndex defaults to 0 (today = last item in reversed array)
    }

    /// Use simple pattern from ParentMetricBarChart:
    /// Position scroll so today is ~90% across the visible window
    /// NOTE: Only used for W/M/6M/Y views. Day view uses dayViewIndex instead.
    private func initializeScrollPosition() {
        let calendar = Calendar.current
        let now = Date()

        let visibleDuration = selectedPeriod.numberOfBars
        let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
        scrollPosition = calendar.date(
            byAdding: selectedPeriod.calendarComponent,
            value: -offsetFromEnd,
            to: now
        ) ?? now
    }

    private let metricId = "DISP_SLEEP_ANALYSIS_PERCENTAGES"
    private let metricName = "Sleep Percentages"

    var body: some View {
        chartView
            .sheet(isPresented: $showAboutModal) {
                MetricEducationModal(
                    viewId: metricId,
                    metricName: metricName,
                    color: color,
                    isPresented: $showAboutModal
                )
            }
            .task {
                await viewModel.loadData(for: selectedPeriod)
                // Set initial dayViewIndex to most recent (last index = today)
                if selectedPeriod == .day && !hasInitializedScroll {
                    dayViewIndex = findTodayIndex()
                    hasInitializedScroll = true
                }
            }
    }

    /// Single layout for ALL periods - matches AmountsTabView pattern exactly
    /// ScrollView > VStack > background for everything including Day view
    private var chartView: some View {
        ScrollView {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    loadingView
                } else {
                    periodSelector
                    chartHeader

                    // Chart content based on period
                    if selectedPeriod == .day {
                        dayChart
                    } else {
                        chart
                    }

                    stageButtonsView
                }
            }
            .padding(.vertical)
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading sleep data...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
    }

    private var periodSelector: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(TimePeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.top, 16)
        .onChange(of: selectedPeriod) { _, newPeriod in
            // Reset all state - don't carry over from previous period
            selectedStage = nil
            selectedBarDate = nil
            hasInitializedScroll = false

            Task {
                await viewModel.loadData(for: newPeriod)

                if newPeriod == .day {
                    // Set index to most recent day (last in chronological order)
                    dayViewIndex = findTodayIndex()
                } else {
                    // For W/M/6M/Y views: use scroll-based initialization
                    initializeScrollPosition()
                }
                hasInitializedScroll = true
            }
        }
    }

    private var stageButtonsView: some View {
        // Create unique ID to force re-render when day changes
        let buttonsId = selectedPeriod == .day ? "buttons-day-\(dayViewIndex)" : "buttons-other-\(selectedBarDate?.timeIntervalSince1970 ?? 0)"

        return VStack(spacing: 8) {
            ForEach(stagePercentagesData, id: \.stage) { item in
                stageButton(for: item)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .id(buttonsId)  // Force re-render when index changes
    }

    private var chartHeader: some View {
        // Create a unique ID that changes when dayViewIndex changes (for Day view)
        // This forces SwiftUI to re-evaluate the header content
        let headerId = selectedPeriod == .day ? "day-\(dayViewIndex)" : "other-\(selectedBarDate?.timeIntervalSince1970 ?? 0)"

        return VStack(spacing: 8) {
            // When stage is selected (Day view uses dayViewIndex, W/M/6M/Y uses selectedBarDate)
            if let stage = selectedStage, (selectedBarDate != nil || selectedPeriod == .day) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stageName(for: stage).uppercased())
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatDuration(getStageTimeForHeader(stage: stage)))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    // Info button
                    Button(action: {
                        withAnimation {
                            showAboutModal = true
                        }
                    }) {
                        Image(systemName: "info.circle")
                            .font(.title3)
                            .foregroundColor(color)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // Default: show Time in Bed / Time Asleep
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
                            showAboutModal = true
                        }
                    }) {
                        Image(systemName: "info.circle")
                            .font(.title3)
                            .foregroundColor(color)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(getSummaryDateLabel())
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .id(headerId)  // Force re-render when index changes
    }

    /// Get display time for a specific sleep stage (for header when stage + bar selected)
    private func getDisplayStageTime(for stage: SleepStage) -> TimeInterval {
        guard let selectedDate = selectedBarDate else { return 0 }

        let granularity = getDateGranularity(for: selectedPeriod)
        if let data = viewModel.chartData.first(where: { Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: granularity) }) {
            let hours = data.stageHours[stage.rawValue] ?? 0.0
            return hours * 3600  // Convert hours to seconds
        }
        return 0
    }

    /// Get stage time for header - uses currentDayDate for Day view, selectedBarDate for other views
    private func getStageTimeForHeader(stage: SleepStage) -> TimeInterval {
        // Day view uses currentDayDate as the selected date (NOT scrollPosition)
        let targetDate: Date
        if selectedPeriod == .day {
            targetDate = currentDayDate
        } else if let barDate = selectedBarDate {
            targetDate = barDate
        } else {
            return 0
        }

        let granularity = getDateGranularity(for: selectedPeriod)
        if let data = viewModel.chartData.first(where: { Calendar.current.isDate($0.date, equalTo: targetDate, toGranularity: granularity) }) {
            let hours = data.stageHours[stage.rawValue] ?? 0.0
            return hours * 3600  // Convert hours to seconds
        }
        return 0
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

    // MARK: - Day Chart Helpers

    /// Get the current day's date from the index (for header display)
    /// NOTE: For Day view, use currentDayDateValue @State instead (updated via onChange)
    private var currentDayDate: Date {
        if selectedPeriod == .day {
            return currentDayDateValue
        }
        return Date()
    }

    /// Update Day view state when index changes - call this from onChange
    /// Uses sleepViewModel.sleepSessions - the exact same data as DayViewChart
    private func updateDayViewState(for index: Int) {
        let sessions = sleepViewModel.sleepSessions
        guard !sessions.isEmpty, index >= 0, index < sessions.count else { return }

        let session = sessions[index]
        currentDayDateValue = session.date

        // Use calculateBarData for consistency
        let barData = calculateBarData(from: session)

        currentDayTimeInBed = barData.timeInBed
        currentDayTimeAsleep = barData.timeAsleep
        currentDayStageHours = [
            SleepStage.deep.rawValue: barData.deep,
            SleepStage.core.rawValue: barData.core,
            SleepStage.rem.rawValue: barData.rem,
            SleepStage.awake.rawValue: barData.awake
        ]

        print("📊 Day view state updated for index \(index): \(session.date), inBed: \(currentDayTimeInBed)h, asleep: \(currentDayTimeAsleep)h")
    }

    /// Find today's index in sleepViewModel.sleepSessions (index 0 = most recent)
    private func findTodayIndex() -> Int {
        let calendar = Calendar.current
        if let index = sleepViewModel.sleepSessions.firstIndex(where: { calendar.isDateInToday($0.date) }) {
            return index
        }
        return 0  // Fallback to most recent
    }

    @ViewBuilder
    private var dayChart: some View {
        // Use sleepViewModel.sleepSessions - the exact same data source as DayViewChart
        if sleepViewModel.sleepSessions.isEmpty {
            VStack(spacing: 12) {
                if sleepViewModel.isLoading {
                    ProgressView()
                    Text("Loading sleep data...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "moon.zzz")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No sleep data available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
        } else {
            // Use Int index like DayViewChart (not Date - Date matching is unreliable)
            // With RTL layout, index 0 appears on the RIGHT (most recent)
            TabView(selection: $dayViewIndex) {
                ForEach(Array(sleepViewModel.sleepSessions.enumerated()), id: \.element.id) { index, session in
                    // Calculate bar values from session segments
                    let barData = calculateBarData(from: session)

                    Chart {
                        // 6 bars: In Bed, Asleep, Deep, Core, REM, Awake
                        BarMark(
                            x: .value("Type", "In Bed"),
                            y: .value("Hours", barData.timeInBed),
                            width: .fixed(40)
                        )
                        .foregroundStyle((Color(hex: "80CBC4") ?? .teal).opacity(0.3))

                        BarMark(
                            x: .value("Type", "Asleep"),
                            y: .value("Hours", barData.timeAsleep),
                            width: .fixed(40)
                        )
                        .foregroundStyle((Color(hex: "80CBC4") ?? .teal).opacity(0.5))

                        BarMark(
                            x: .value("Type", "Deep"),
                            y: .value("Hours", barData.deep),
                            width: .fixed(40)
                        )
                        .foregroundStyle(selectedStage == nil || selectedStage == .deep ? SleepStage.deep.color : Color(uiColor: .secondarySystemGroupedBackground))

                        BarMark(
                            x: .value("Type", "Core"),
                            y: .value("Hours", barData.core),
                            width: .fixed(40)
                        )
                        .foregroundStyle(selectedStage == nil || selectedStage == .core ? SleepStage.core.color : Color(uiColor: .secondarySystemGroupedBackground))

                        BarMark(
                            x: .value("Type", "REM"),
                            y: .value("Hours", barData.rem),
                            width: .fixed(40)
                        )
                        .foregroundStyle(selectedStage == nil || selectedStage == .rem ? SleepStage.rem.color : Color(uiColor: .secondarySystemGroupedBackground))

                        BarMark(
                            x: .value("Type", "Awake"),
                            y: .value("Hours", barData.awake),
                            width: .fixed(40)
                        )
                        .foregroundStyle(selectedStage == nil || selectedStage == .awake ? SleepStage.awake.color : Color(uiColor: .secondarySystemGroupedBackground))
                    }
                    .frame(height: 220)
                    .chartYScale(domain: 0...max(barData.timeInBed * 1.2, 5.0))
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
                    .environment(\.layoutDirection, .leftToRight) // Reset chart content to normal LTR
                    .tag(index)  // Int tag, not Date!
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 220)
            .padding(.horizontal)
            .padding(.bottom, 24)
            .environment(\.layoutDirection, .rightToLeft) // TabView paging: most recent on right
            .onChange(of: dayViewIndex) { _, newIndex in
                // Update state for header/buttons
                updateDayViewState(for: newIndex)

                // Load more data when near the beginning (older dates)
                if newIndex >= sleepViewModel.sleepSessions.count - 2 {
                    Task {
                        await sleepViewModel.loadEarlierSleepStages()
                    }
                }
            }
            .onAppear {
                // Initialize state when view first appears
                updateDayViewState(for: dayViewIndex)
            }
        }
    }

    /// Calculate bar chart data from a SleepSession
    /// Uses same logic as SleepAnalysisViewModel.calculateSummaryMetrics
    private func calculateBarData(from session: SleepSession) -> (timeInBed: Double, timeAsleep: Double, deep: Double, core: Double, rem: Double, awake: Double) {
        var deep: Double = 0
        var core: Double = 0
        var rem: Double = 0
        var awake: Double = 0
        var timeInBed: Double = 0

        for segment in session.segments {
            let hours = segment.endTime.timeIntervalSince(segment.startTime) / 3600.0

            // Skip .inBed to avoid double-counting (same as calculateSummaryMetrics)
            guard segment.stage != .inBed else { continue }

            // Add to timeInBed (all stages except .inBed)
            timeInBed += hours

            switch segment.stage {
            case .deep:
                deep += hours
            case .core:
                core += hours
            case .rem:
                rem += hours
            case .awake:
                awake += hours
            case .asleep:
                // Basic asleep (no detailed stages) - counts toward time in bed but not specific stage
                break
            default:
                break
            }
        }

        // Time asleep = time in bed - awake (same as calculateSummaryMetrics)
        let timeAsleep = timeInBed - awake

        return (timeInBed: timeInBed, timeAsleep: timeAsleep, deep: deep, core: core, rem: rem, awake: awake)
    }

    // MARK: - Scrollable Chart (W/M/6M/Y)

    private var chart: some View {
        // Single chart with stacked stage bars (no background layers since stages include all sleep time)
        Chart {
            // Selection indicator line (behind all bars - Apple Health style)
            if let selectedDate = selectedBarDate {
                RuleMark(x: .value("Selected", selectedDate))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .foregroundStyle(Color.primary.opacity(0.3))
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
        .frame(height: 280)
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
        .padding(.horizontal)
        .padding(.bottom, 24)
        .onAppear {
            // Only initialize scroll position if we haven't already
            guard !hasInitializedScroll else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                initializeScrollPosition()
                hasInitializedScroll = true
            }
        }
        .onChange(of: scrollPosition) { _, _ in
            selectedBarDate = nil
        }
    }

    // MARK: - Helper Functions

    private func getSortedStagesForStacking() -> [SleepStage] {
        // Put selected stage first so it's drawn at the bottom (starts from 0)
        // This allows easier visual comparison of the selected stage's duration
        let baseOrder: [SleepStage] = [.deep, .core, .rem, .awake]
        guard let selected = selectedStage else {
            return baseOrder
        }
        // Move selected to front (bottom of stack), keep others in relative order
        var sorted = baseOrder.filter { $0 != selected }
        sorted.insert(selected, at: 0)
        return sorted
    }

    private func getStageColorForChart(stage: SleepStage, isBarSelected: Bool) -> Color {
        // When a stage is selected, show selected stage in its color, others in secondary background
        if selectedStage == nil {
            return stage.color
        }
        return selectedStage == stage ? stage.color : Color(uiColor: .secondarySystemGroupedBackground)
    }

    private func getStageOpacity(for stage: SleepStage) -> Double {
        // Always full opacity - color change handles selection state
        return 1.0
    }

    private func getMaxYValue() -> Double {
        if selectedPeriod == .day {
            // For day view, use time in bed for the currently visible day (includes all bars)
            let calendar = Calendar.current
            let visibleDayData = viewModel.chartData.filter {
                calendar.isDate($0.date, equalTo: currentDayDate, toGranularity: .day)
            }

            guard let dayData = visibleDayData.first else {
                // Default to 5 hours if no data
                return 5.0
            }

            // Use time in bed (the tallest bar in Day view)
            let timeInBed = dayData.timeInBedHours

            if timeInBed == 0.0 {
                // No data - default to 5 hours
                return 5.0
            }

            // Add 20% buffer and round up
            return ceil(timeInBed * 1.2)
        } else {
            // For W/M/6M/Y views, use total stage hours (stacked bar height)
            let maxTotalHours = viewModel.chartData.map { $0.totalSleepHours }.max() ?? 8.0
            // Add 20% buffer
            return ceil(maxTotalHours * 1.2)
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
            // For day view, show the currently visible day from currentDayDate
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: currentDayDate)
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
            // For day view, use @State value that's updated via onChange
            return currentDayTimeInBed * 3600
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
            // For day view, use @State value that's updated via onChange
            return currentDayTimeAsleep * 3600
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
        // For Day view, use @State values directly
        if selectedPeriod == .day && selectedBarDate == nil {
            let totalTimeInBed = currentDayTimeInBed
            guard totalTimeInBed > 0 else {
                return defaultStageData
            }

            let deepPct = (currentDayStageHours[SleepStage.deep.rawValue] ?? 0) / totalTimeInBed * 100
            let corePct = (currentDayStageHours[SleepStage.core.rawValue] ?? 0) / totalTimeInBed * 100
            let remPct = (currentDayStageHours[SleepStage.rem.rawValue] ?? 0) / totalTimeInBed * 100
            let awakePct = (currentDayStageHours[SleepStage.awake.rawValue] ?? 0) / totalTimeInBed * 100

            return [
                (.deep, deepPct),
                (.core, corePct),
                (.rem, remPct),
                (.awake, awakePct)
            ]
        }

        let dataToAnalyze: [SleepStageChartData]

        if let selectedDate = selectedBarDate {
            // Use appropriate granularity based on period (.day for W/M, .weekOfYear for 6M, .month for Y)
            let granularity = getDateGranularity(for: selectedPeriod)
            dataToAnalyze = viewModel.chartData.filter { Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: granularity) }
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

        // Sum stage hours and total time in bed across all data points
        var stageTotals: [SleepStage: Double] = [:]
        var totalTimeInBed: Double = 0

        for data in dataToAnalyze {
            // Sum each stage
            for (key, value) in data.stageHours {
                if let stage = SleepStage(rawValue: key) {
                    stageTotals[stage, default: 0] += value
                }
            }
            // Sum total time in bed (Deep + Core + REM + Awake should = 100% of time in bed)
            totalTimeInBed += data.timeInBedHours
        }

        // Calculate percentages relative to total time in bed (so Deep + Core + REM + Awake = 100%)
        guard totalTimeInBed > 0 else {
            return defaultStageData
        }

        let deepPct = (stageTotals[.deep] ?? 0) / totalTimeInBed * 100
        let corePct = (stageTotals[.core] ?? 0) / totalTimeInBed * 100
        let remPct = (stageTotals[.rem] ?? 0) / totalTimeInBed * 100
        let awakePct = (stageTotals[.awake] ?? 0) / totalTimeInBed * 100

        print("📊 Percentage calc - Deep: \(stageTotals[.deep] ?? 0)h, Core: \(stageTotals[.core] ?? 0)h, REM: \(stageTotals[.rem] ?? 0)h, Awake: \(stageTotals[.awake] ?? 0)h, Total In Bed: \(totalTimeInBed)h")
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
                // Circle or ring indicator based on selection
                if selectedStage == item.stage {
                    Circle()
                        .strokeBorder(item.stage.color, lineWidth: 2)
                        .frame(width: 12, height: 12)
                } else {
                    Circle()
                        .fill(item.stage.color)
                        .frame(width: 12, height: 12)
                }

                // Label: "Average [Stage]" or "[Stage]" when bar selected
                Text(getStageLabel(for: item.stage))
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Always show percentage - header shows the selected value (hours)
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

    /// Get label for stage button - includes "Average" prefix for W/M/6M when no bar selected
    private func getStageLabel(for stage: SleepStage) -> String {
        let baseName = stageName(for: stage)
        // If a bar is selected, show plain name; otherwise show "Average [Stage]" for non-day periods
        if selectedBarDate != nil || selectedPeriod == .day {
            return baseName
        } else {
            return "Average \(baseName)"
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
}

// MARK: - ViewModel

@MainActor
class SleepPercentagesViewModel: ObservableObject {
    @Published var chartData: [SleepStageChartData] = []
    @Published var dayViewSessions: [SleepStageChartData] = []  // For Day view TabView: newest first, only days with data
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
            let now = Date()
            let calendar = Calendar.current
            // Extend into future by 1 month so user can scroll ahead
            let newestDate: Date = (period == .day) ? now : (calendar.date(byAdding: .month, value: 1, to: now) ?? now)
            var oldestDate: Date
            switch period {
            case .day:
                oldestDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            case .week:
                oldestDate = calendar.date(byAdding: .weekOfYear, value: -8, to: now) ?? now
            case .month:
                oldestDate = calendar.date(byAdding: .month, value: -6, to: now) ?? now
            case .sixMonth:
                oldestDate = calendar.date(byAdding: .month, value: -18, to: now) ?? now
            case .year:
                oldestDate = calendar.date(byAdding: .year, value: -3, to: now) ?? now
            }

            // STEP 1: Generate empty data points for ALL dates in range (enables scrolling)
            var allDataPoints = generateEmptyDataPoints(from: oldestDate, to: newestDate, period: period)

            // STEP 2: Fetch actual sleep stage breakdown data
            let service = PatientSamplesQueryService.shared
            let dailyStageData = try await service.fetchSleepStageBreakdownDaily(
                startDate: oldestDate,
                endDate: newestDate
            )

            print("📊 SleepPercentages: Loaded \(dailyStageData.count) days of stage data for \(period.rawValue) view")

            // STEP 3: Populate data points based on period granularity
            let granularity = getDateGranularity(for: period)

            // For 6M/Y, aggregate daily values into weekly/monthly bars
            if period == .sixMonth || period == .year {
                // Group daily data by bar date (using granularity matching)
                for i in 0..<allDataPoints.count {
                    let barDate = allDataPoints[i].date

                    // Find all daily data that falls within this bar's period
                    let matchingDays = dailyStageData.filter { dayData in
                        calendar.isDate(dayData.date, equalTo: barDate, toGranularity: granularity)
                    }

                    guard !matchingDays.isEmpty else { continue }

                    // Calculate averages from matching days
                    let count = Double(matchingDays.count)
                    let avgDeep = matchingDays.reduce(0) { $0 + $1.deepMinutes } / count
                    let avgRem = matchingDays.reduce(0) { $0 + $1.remMinutes } / count
                    let avgCore = matchingDays.reduce(0) { $0 + $1.coreMinutes } / count
                    let avgAwake = matchingDays.reduce(0) { $0 + $1.awakeMinutes } / count
                    let avgTimeInBed = matchingDays.reduce(0) { $0 + $1.timeInBedMinutes } / count
                    let avgSleepDuration = matchingDays.reduce(0) { $0 + $1.sleepDurationMinutes } / count

                    let stageHours: [String: Double] = [
                        SleepStage.deep.rawValue: avgDeep / 60.0,
                        SleepStage.rem.rawValue: avgRem / 60.0,
                        SleepStage.core.rawValue: avgCore / 60.0,
                        SleepStage.awake.rawValue: avgAwake / 60.0
                    ]
                    allDataPoints[i] = SleepStageChartData(
                        date: barDate,
                        stageHours: stageHours,
                        timeInBedHours: avgTimeInBed / 60.0,
                        timeAsleepHours: avgSleepDuration / 60.0
                    )
                }
            } else {
                // D/W/M: Direct 1:1 daily mapping
                var valuesByDate: [Date: DailySleepStageData] = [:]
                for dayData in dailyStageData {
                    let dateKey = calendar.startOfDay(for: dayData.date)
                    valuesByDate[dateKey] = dayData
                }

                for i in 0..<allDataPoints.count {
                    let dateKey = calendar.startOfDay(for: allDataPoints[i].date)
                    if let actualData = valuesByDate[dateKey] {
                        let stageHours: [String: Double] = [
                            SleepStage.deep.rawValue: actualData.deepMinutes / 60.0,
                            SleepStage.rem.rawValue: actualData.remMinutes / 60.0,
                            SleepStage.core.rawValue: actualData.coreMinutes / 60.0,
                            SleepStage.awake.rawValue: actualData.awakeMinutes / 60.0
                        ]
                        allDataPoints[i] = SleepStageChartData(
                            date: allDataPoints[i].date,
                            stageHours: stageHours,
                            timeInBedHours: actualData.timeInBedMinutes / 60.0,
                            timeAsleepHours: actualData.sleepDurationMinutes / 60.0
                        )
                    }
                }
            }

            // Also store daily values for summary stats calculation
            dailyTimeInBedCache = dailyStageData.map { SleepChartDataPoint(date: $0.date, value: $0.timeInBedMinutes, label: "Time in Bed") }
            dailyTimeAsleepCache = dailyStageData.map { SleepChartDataPoint(date: $0.date, value: $0.sleepDurationMinutes, label: "Time Asleep") }

            chartData = allDataPoints

            // Build Day view sessions ONLY for Day period: only days with data, newest first (reversed)
            // This is a stable array that doesn't change during scrolling
            if period == .day {
                dayViewSessions = Array(allDataPoints.filter { $0.timeAsleepHours > 0 }.reversed())
                print("📊 SleepPercentages: Built \(chartData.count) chart data points, \(dayViewSessions.count) day sessions (\(dailyStageData.count) days of data)")
            } else {
                dayViewSessions = []  // Clear for non-Day periods
                print("📊 SleepPercentages: Built \(chartData.count) chart data points for \(period.rawValue) view (\(dailyStageData.count) days of data)")
            }

            // Store current date range for pagination
            currentOldestDate = oldestDate
            currentNewestDate = newestDate
            currentPeriod = period

        } catch {
            print("❌ Error loading sleep percentages data: \(error)")
        }

        isLoading = false
    }

    /// Generate empty data points (all zeros) for all dates in range - enables chart scrolling
    /// Uses period.calendarComponent for stepping (daily for W/M, weekly for 6M, monthly for Y)
    private func generateEmptyDataPoints(from startDate: Date, to endDate: Date, period: TimePeriod) -> [SleepStageChartData] {
        var points: [SleepStageChartData] = []
        let calendar = Calendar.current
        var currentDate = startDate
        let incrementComponent: Calendar.Component = period.calendarComponent

        let emptyStageHours: [String: Double] = [
            SleepStage.deep.rawValue: 0,
            SleepStage.rem.rawValue: 0,
            SleepStage.core.rawValue: 0,
            SleepStage.awake.rawValue: 0
        ]

        while currentDate <= endDate {
            // Calculate bar date with proper centering based on period
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
                // D/W/M: daily bars, center at noon
                let startOfDay = calendar.startOfDay(for: currentDate)
                barDate = calendar.date(byAdding: .hour, value: 12, to: startOfDay) ?? currentDate
            }

            points.append(SleepStageChartData(
                date: barDate,
                stageHours: emptyStageHours,
                timeInBedHours: 0,
                timeAsleepHours: 0
            ))

            guard let nextDate = calendar.date(byAdding: incrementComponent, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return points
    }

    func loadMoreDaysBackward() async {
        // Prevent multiple simultaneous loads
        guard !isLoadingMore, let period = currentPeriod, period == .day else { return }
        guard let oldestDate = currentOldestDate else { return }

        isLoadingMore = true
        print("📥 Loading 7 more days backward from \(oldestDate)...")

        do {
            let calendar = Calendar.current
            // Load 7 more days going backward
            let newOldestDate = calendar.date(byAdding: .day, value: -7, to: oldestDate) ?? oldestDate

            // Use the database view for efficient pre-computed aggregations
            let summaries = try await PatientSamplesQueryService.shared.fetchSleepSessionSummaries(
                startDate: newOldestDate,
                endDate: oldestDate
            )

            print("📊 Loaded \(summaries.count) daily summaries for pagination")

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            // Convert to chart data
            var newChartData: [SleepStageChartData] = []
            for row in summaries {
                guard let date = dateFormatter.date(from: row.sleepDate) else { continue }

                let stageHours: [String: Double] = [
                    SleepStage.deep.rawValue: row.deepMinutes / 60.0,
                    SleepStage.rem.rawValue: row.remMinutes / 60.0,
                    SleepStage.core.rawValue: row.lightMinutes / 60.0,  // "light" in view = "core" stage
                    SleepStage.awake.rawValue: row.awakeMinutes / 60.0
                ]

                newChartData.append(SleepStageChartData(
                    date: date,
                    stageHours: stageHours,
                    timeInBedHours: row.timeInBedMinutes / 60.0,
                    timeAsleepHours: row.totalSleepMinutes / 60.0
                ))
            }

            // Sort by date and prepend to existing chart data
            newChartData.sort { $0.date < $1.date }
            chartData = newChartData + chartData

            // Rebuild dayViewSessions (newest first, only days with data)
            dayViewSessions = Array(chartData.filter { $0.timeAsleepHours > 0 }.reversed())

            // Update stored oldest date
            currentOldestDate = newOldestDate

            print("✅ Loaded more data, now showing \(chartData.count) days, \(dayViewSessions.count) sessions")

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

        // Normalize scroll position to start of day for comparison
        // Daily cache dates are at midnight (from database aggregation_date)
        let normalizedStart = calendar.startOfDay(for: scrollPosition)

        // Calculate the end of the visible window
        guard let endDate = calendar.date(byAdding: period.calendarComponent, value: period.numberOfBars, to: normalizedStart) else {
            return 0
        }

        // Filter daily data that falls within the visible window
        // Use startOfDay for both sides to handle any time component differences
        let visibleDailyData = dailyTimeInBedCache.filter { dataPoint in
            guard dataPoint.value > 0 else { return false }
            let normalizedDataDate = calendar.startOfDay(for: dataPoint.date)
            return normalizedDataDate >= normalizedStart && normalizedDataDate < endDate
        }

        guard !visibleDailyData.isEmpty else {
            print("⚠️ getAverageTimeInBed: No data in range \(normalizedStart) to \(endDate), cache has \(dailyTimeInBedCache.count) items")
            return 0
        }

        // Sum all daily values and divide by number of days with data
        let totalMinutes = visibleDailyData.reduce(0.0) { $0 + $1.value }
        let averageMinutes = totalMinutes / Double(visibleDailyData.count)
        print("📊 getAverageTimeInBed: \(visibleDailyData.count) days, avg \(averageMinutes)min")
        return (averageMinutes / 60.0) * 3600 // Convert minutes to hours to seconds
    }

    func getAverageTimeAsleep(scrollPosition: Date, period: TimePeriod) -> TimeInterval {
        let calendar = Calendar.current

        // Normalize scroll position to start of day for comparison
        // Daily cache dates are at midnight (from database aggregation_date)
        let normalizedStart = calendar.startOfDay(for: scrollPosition)

        // Calculate the end of the visible window
        guard let endDate = calendar.date(byAdding: period.calendarComponent, value: period.numberOfBars, to: normalizedStart) else {
            return 0
        }

        // Filter daily data that falls within the visible window
        // Use startOfDay for both sides to handle any time component differences
        let visibleDailyData = dailyTimeAsleepCache.filter { dataPoint in
            guard dataPoint.value > 0 else { return false }
            let normalizedDataDate = calendar.startOfDay(for: dataPoint.date)
            return normalizedDataDate >= normalizedStart && normalizedDataDate < endDate
        }

        guard !visibleDailyData.isEmpty else {
            print("⚠️ getAverageTimeAsleep: No data in range \(normalizedStart) to \(endDate), cache has \(dailyTimeAsleepCache.count) items")
            return 0
        }

        // Sum all daily values and divide by number of days with data
        let totalMinutes = visibleDailyData.reduce(0.0) { $0 + $1.value }
        let averageMinutes = totalMinutes / Double(visibleDailyData.count)
        print("📊 getAverageTimeAsleep: \(visibleDailyData.count) days, avg \(averageMinutes)min")
        return (averageMinutes / 60.0) * 3600 // Convert minutes to hours to seconds
    }
}

// MARK: - Data Models

struct SleepStageChartData: Identifiable {
    // Use date as stable identifier (like SleepSession does)
    // This prevents TabView from resetting when data reloads
    var id: Date { date }
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
    SleepPercentagesChart(color: MetricsUIConfig.getPillarColor(for: "Sleep"), sleepViewModel: SleepAnalysisViewModel())
}
