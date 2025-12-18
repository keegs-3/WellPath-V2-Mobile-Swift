//
//  CardioDurationView.swift
//  WellPath
//
//  Full view for Cardio Duration metric.
//  Uses standard MetricEducationModal for about content.
//

import SwiftUI
import Charts

struct CardioDurationView: View {
    let color: Color
    let pillar: String
    let sectionId: String

    @StateObject private var viewModel = WorkoutDurationViewModel(category: "cardio")
    @State private var showAboutModal = false
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private let metricId = "DISP_CARDIO_DURATION"
    private let metricName = "Cardio Duration"

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                WorkoutDurationChart(
                    viewModel: viewModel,
                    color: color,
                    showAboutModal: $showAboutModal
                )
            }
        }
        .metricScreenBackground(color: color)
        .navigationTitle(metricName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingDataManagement = true
                } label: {
                    Image(systemName: "list.bullet")
                }
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                FavoriteButton(
                    itemType: .metric,
                    itemId: metricId,
                    displayName: metricName,
                    pillar: pillar,
                    cardId: "CARD_CARDIO_DURATION",
                    sectionId: sectionId
                )

                Button {
                    showingEntryForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEntryForm) {
            WorkoutEntryView(category: "cardio", categoryName: "Cardio", color: color, icon: "figure.run")
        }
        .sheet(isPresented: $showingDataManagement) {
            WorkoutDataManagementView(category: "cardio", categoryName: "Cardio", color: color)
        }
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(
                viewId: metricId,
                metricName: metricName,
                color: color,
                isPresented: $showAboutModal
            )
        }
        .task {
            await viewModel.loadData(period: .week)
        }
    }
}

// MARK: - Workout Duration Chart

struct WorkoutDurationChart: View {
    @ObservedObject var viewModel: WorkoutDurationViewModel
    let color: Color
    @Binding var showAboutModal: Bool

    @State private var selectedPeriod: WorkoutPeriod = .week
    @State private var selectedBar: WorkoutChartPoint?
    @State private var selectedDayWorkout: DayWorkoutEvent?
    @State private var scrollPosition: Date

    init(viewModel: WorkoutDurationViewModel, color: Color, showAboutModal: Binding<Bool>) {
        self.viewModel = viewModel
        self.color = color
        self._showAboutModal = showAboutModal

        // Initialize scroll position to today
        _scrollPosition = State(initialValue: Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            // Period picker
            Picker("Period", selection: $selectedPeriod) {
                ForEach(WorkoutPeriod.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 16)
            .onChange(of: selectedPeriod) { _, newPeriod in
                selectedBar = nil
                selectedDayWorkout = nil

                // Recalculate scroll position based on period
                if newPeriod == .day {
                    initializeDayScrollPosition()
                } else {
                    initializeScrollPosition()
                }

                Task {
                    await viewModel.loadData(period: newPeriod)
                }
            }

            // Value display with info button
            HStack(alignment: .top, spacing: 40) {
                VStack(alignment: .leading, spacing: 4) {
                    if let dayWorkout = selectedDayWorkout, selectedPeriod == .day {
                        // Day view SELECTED: Show workout duration and time range (no label, no workout count)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatDuration(dayWorkout.durationMinutes))
                                .font(.system(size: 48, weight: .semibold))
                        }
                        Text(formatWorkoutTimeRange(dayWorkout))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else if let bar = selectedBar {
                        // Bar selected (W/M/6M/Y views)
                        Text(selectedBarLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatDuration(selectedBarDuration(bar)))
                                .font(.system(size: 48, weight: .semibold))
                        }
                        workoutCountView(for: bar.workoutCount)
                        Text(formatSelectedBarDate(bar.date))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        // Unselected state
                        Text(unselectedLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatDuration(unselectedDuration))
                                .font(.system(size: 48, weight: .semibold))
                        }
                        workoutCountView(for: visibleWorkoutCount)
                        Text(visibleDateRangeString)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Info button - opens modal
                Button(action: {
                    showAboutModal = true
                }) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(color)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 12)

            // Chart
            if viewModel.isLoading {
                ProgressView()
                    .frame(height: 280)
                    .frame(maxWidth: .infinity)
            } else if selectedPeriod == .day {
                // Day view: Horizontal timeline bar
                dayTimelineChart
            } else {
                // W/M/6M/Y views: Standard vertical bar chart with infinite scroll
                standardBarChart
            }
        }
        .padding(.vertical)
        .background(Color(uiColor: .systemGroupedBackground))
        // Move onChange to top level so it fires regardless of loading state
        .onChange(of: viewModel.chartData.count) { oldCount, newCount in
            // Reposition to most recent data when data first loads
            if oldCount == 0 && newCount > 0 {
                if selectedPeriod == .day {
                    initializeDayScrollPosition()
                } else {
                    initializeScrollPosition()
                }
            }
        }
        .onChange(of: viewModel.dayWorkouts.count) { oldCount, newCount in
            // Reposition for day view when data first loads
            if oldCount == 0 && newCount > 0 && selectedPeriod == .day {
                initializeDayScrollPosition()
            }
        }
    }

    // MARK: - Day Timeline Chart (horizontal bar like Apple Health)

    private var dayTimelineChart: some View {
        Chart {
            // Invisible placeholder points to establish the timeline (needed for scroll)
            ForEach(dayTimelinePlaceholders, id: \.self) { hour in
                PointMark(
                    x: .value("Hour", hour),
                    y: .value("Y", 0.5)
                )
                .opacity(0)
            }

            // Workout duration bars - thin horizontal bars like Apple Health
            ForEach(viewModel.dayWorkouts) { workout in
                RectangleMark(
                    xStart: .value("Start", workout.startTime),
                    xEnd: .value("End", workout.endTime),
                    yStart: .value("Bottom", 0.485),
                    yEnd: .value("Top", 0.515)
                )
                .foregroundStyle(selectedDayWorkout?.id == workout.id ? color.opacity(0.6) : color)
                .cornerRadius(4)
            }
        }
        .chartYScale(domain: 0...1)
        .chartYAxis(.hidden)
        .frame(height: 280)
        .chartScrollableAxes(.horizontal)
        .chartScrollPosition(x: $scrollPosition)
        .chartXVisibleDomain(length: 24 * 3600)  // 24 hours visible
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                AxisGridLine()
                    .foregroundStyle(Color.secondary.opacity(0.2))
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                    .font(.caption2)
                AxisTick()
            }
        }
        .chartGesture { proxy in
            SpatialTapGesture()
                .onEnded { value in
                    if let tappedDate: Date = proxy.value(atX: value.location.x) {
                        // Find workout that contains this time
                        let tappedWorkout = viewModel.dayWorkouts.first { workout in
                            tappedDate >= workout.startTime && tappedDate <= workout.endTime
                        }
                        if selectedDayWorkout?.id == tappedWorkout?.id {
                            selectedDayWorkout = nil
                        } else {
                            selectedDayWorkout = tappedWorkout
                        }
                    }
                }
        }
        .chartPlotStyle { plotArea in
            plotArea.frame(height: 280)
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .onChange(of: scrollPosition) { _, newPosition in
            handleChartScrolling(position: newPosition)
        }
    }

    /// Generate hourly placeholder points for day timeline (enables scrolling)
    /// Dynamically extends based on loaded data range
    private var dayTimelinePlaceholders: [Date] {
        let calendar = Calendar.current
        let now = Date()
        var placeholders: [Date] = []

        // Calculate range based on loaded data or default
        let oldestDate: Date
        if let oldest = viewModel.dayWorkouts.map({ $0.startTime }).min() {
            // Extend 7 days before oldest data
            oldestDate = calendar.date(byAdding: .day, value: -7, to: oldest) ?? oldest
        } else {
            // Default: 30 days back
            oldestDate = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        }

        // Generate points from oldest to tomorrow
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        var currentDay = calendar.startOfDay(for: oldestDate)

        while currentDay <= tomorrow {
            for hour in stride(from: 0, to: 24, by: 6) {
                if let hourDate = calendar.date(byAdding: .hour, value: hour, to: currentDay) {
                    placeholders.append(hourDate)
                }
            }
            currentDay = calendar.date(byAdding: .day, value: 1, to: currentDay) ?? tomorrow
        }

        return placeholders
    }

    // MARK: - Standard Bar Chart (W/M/6M/Y)

    /// Get days count for a week, with date normalization to match ViewModel cache keys
    private func daysInWeek(for date: Date) -> Int {
        let calendar = Calendar.current
        // Normalize to midnight to match how ViewModel stores keys
        let normalizedDate = calendar.startOfDay(for: date)
        return viewModel.daysPerWeek[normalizedDate] ?? 0
    }

    /// Get days count for a month, with date normalization to match ViewModel cache keys
    private func daysInMonth(for date: Date) -> Int {
        let calendar = Calendar.current
        // Normalize to first of month at midnight to match how ViewModel stores keys
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let monthStart = calendar.date(from: components) else { return 0 }
        return viewModel.daysPerMonth[monthStart] ?? 0
    }

    /// Bar display value: daily average for 6M/Y, raw total for W/M
    private func barDisplayValue(_ point: WorkoutChartPoint) -> Double {
        let value: Double

        switch selectedPeriod {
        case .day, .week, .month:
            // Show raw value (daily total)
            value = point.durationMinutes
        case .sixMonths:
            // Show daily average for that week - use cached lookup from ViewModel
            let days = daysInWeek(for: point.date)
            value = days > 0 ? point.durationMinutes / Double(days) : point.durationMinutes
        case .year:
            // Show daily average for that month - use cached lookup from ViewModel
            let days = daysInMonth(for: point.date)
            value = days > 0 ? point.durationMinutes / Double(days) : point.durationMinutes
        }
        return useHoursScale ? value / 60.0 : value
    }

    private var standardBarChart: some View {
        Chart(chartDataWithPlaceholders) { point in
            BarMark(
                x: .value("Date", point.date, unit: selectedPeriod.chartUnit),
                y: .value("Duration", barDisplayValue(point))
            )
            .foregroundStyle(selectedBar?.date == point.date ? color.opacity(0.6) : color)
        }
        .frame(height: 280)
        .chartScrollableAxes(.horizontal)
        .chartScrollPosition(x: $scrollPosition)
        .chartXVisibleDomain(length: selectedPeriod.visibleDomainSeconds)
        .chartGesture { proxy in
            SpatialTapGesture()
                .onEnded { value in
                    if let tappedDate: Date = proxy.value(atX: value.location.x) {
                        let closest = chartDataWithPlaceholders.filter { $0.durationMinutes > 0 }.min(by: {
                            abs($0.date.timeIntervalSince(tappedDate)) < abs($1.date.timeIntervalSince(tappedDate))
                        })
                        if selectedBar?.date == closest?.date {
                            selectedBar = nil
                        } else {
                            selectedBar = closest
                        }
                    }
                }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: selectedPeriod.chartComponent, count: selectedPeriod.strideCount)) { _ in
                AxisGridLine()
                    .foregroundStyle(Color.secondary.opacity(0.2))
                AxisValueLabel(format: selectedPeriod.dateFormat)
                    .font(.caption2)
                AxisTick()
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let val = value.as(Double.self) {
                        Text(formatYAxisValue(val))
                            .font(.caption2)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(Color.secondary.opacity(0.2))
            }
        }
        .chartYScale(domain: 0...maxYValue)
        .chartPlotStyle { plotArea in
            plotArea.frame(height: 280)
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .onChange(of: scrollPosition) { _, newPosition in
            handleChartScrolling(position: newPosition)
        }
    }

    // MARK: - Helpers

    private func initializeScrollPosition() {
        let calendar = Calendar.current

        // Get most recent data point, default to now if no data
        let mostRecentDataDate = viewModel.chartData.filter { $0.durationMinutes > 0 }.max(by: { $0.date < $1.date })?.date ?? Date()

        // Use 90% offset so most recent data appears near (but not at) the right edge
        let visibleDuration = selectedPeriod.numberOfBars
        let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
        scrollPosition = calendar.date(
            byAdding: selectedPeriod.chartComponent,
            value: -offsetFromEnd,
            to: mostRecentDataDate
        ) ?? mostRecentDataDate
    }

    /// Initialize day view scroll to show most recent workout at right edge
    private func initializeDayScrollPosition() {
        let calendar = Calendar.current

        // Get most recent workout date, default to now if no data
        let mostRecentDataDate = viewModel.dayWorkouts.max(by: { $0.startTime < $1.startTime })?.startTime ?? Date()

        // Use 90% offset so most recent data appears near (but not at) the right edge
        // Day view shows 24 hours, so offset by ~21 hours
        let offsetHours = Int(24.0 * 0.9)
        scrollPosition = calendar.date(
            byAdding: .hour,
            value: -offsetHours,
            to: mostRecentDataDate
        ) ?? mostRecentDataDate
    }

    /// Handle chart scrolling - no longer needed as all data is loaded upfront
    private func handleChartScrolling(position: Date) {
        // No-op: All data is pre-loaded from database views
        // Keeping method for compatibility with existing .onChange calls
    }

    // MARK: - Computed Properties

    private var chartDataWithPlaceholders: [WorkoutChartPoint] {
        // Generate a complete timeline from oldestLoadedDate to now + small future buffer
        // This enables true infinite scroll by extending placeholders as data is loaded
        let calendar = Calendar.current
        let now = Date()
        let (_, component) = selectedPeriod.placeholderConfig

        // Use the ViewModel's tracked oldest date (updated when loading older data)
        let startDate = viewModel.oldestLoadedDate

        // End date is tomorrow to allow scrolling into today
        let endDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now

        var timeline: [WorkoutChartPoint] = []

        // Generate placeholder points from oldest loaded date to end
        var currentDate = startDate
        while currentDate <= endDate {
            timeline.append(WorkoutChartPoint(date: currentDate, durationMinutes: 0, workoutCount: 0))
            currentDate = calendar.date(byAdding: component, value: 1, to: currentDate) ?? endDate
        }

        // Overlay actual data on timeline
        for dataPoint in viewModel.chartData {
            if let index = timeline.firstIndex(where: { isSameTimePeriod($0.date, dataPoint.date, component: component) }) {
                timeline[index] = dataPoint
            }
        }

        return timeline.sorted { $0.date < $1.date }
    }

    private func isSameTimePeriod(_ date1: Date, _ date2: Date, component: Calendar.Component) -> Bool {
        let calendar = Calendar.current
        switch component {
        case .hour:
            return calendar.isDate(date1, equalTo: date2, toGranularity: .hour)
        case .day:
            return calendar.isDate(date1, equalTo: date2, toGranularity: .day)
        case .weekOfYear:
            return calendar.isDate(date1, equalTo: date2, toGranularity: .weekOfYear)
        case .month:
            return calendar.isDate(date1, equalTo: date2, toGranularity: .month)
        default:
            return calendar.isDate(date1, equalTo: date2, toGranularity: .day)
        }
    }

    /// Get max bar value considering daily averages for 6M/Y views
    private var maxDisplayedBarValue: Double {
        switch selectedPeriod {
        case .day, .week, .month:
            return visibleChartData.map { $0.durationMinutes }.max() ?? 0
        case .sixMonths:
            // Use daily averages from cached ViewModel lookups
            return visibleChartData.map { point in
                let days = daysInWeek(for: point.date)
                return days > 0 ? point.durationMinutes / Double(days) : point.durationMinutes
            }.max() ?? 0
        case .year:
            return visibleChartData.map { point in
                let days = daysInMonth(for: point.date)
                return days > 0 ? point.durationMinutes / Double(days) : point.durationMinutes
            }.max() ?? 0
        }
    }

    /// Whether to display Y-axis in hours (true) or minutes (false)
    /// Based on max DISPLAYED value (daily avg for 6M/Y)
    private var useHoursScale: Bool {
        return maxDisplayedBarValue >= 120  // 2 hours threshold
    }

    /// Max Y value in the appropriate unit (hours or minutes)
    /// Based on max DISPLAYED value to properly scale the chart
    private var maxYValue: Double {
        let maxMinutes = maxDisplayedBarValue
        if useHoursScale {
            // Use hours - round up to whole hours
            let maxHours = ceil(maxMinutes / 60.0)
            return max(maxHours, 2)
        } else {
            // Use minutes - auto-scale with smart increments
            if maxMinutes <= 0 {
                return 60  // Default 1 hour when no data in view
            } else if maxMinutes <= 15 {
                return 20
            } else if maxMinutes <= 30 {
                return 40
            } else if maxMinutes <= 45 {
                return 60
            } else if maxMinutes <= 60 {
                return 80
            } else if maxMinutes <= 90 {
                return 100
            } else {
                return 120  // Cap at 2 hours for minutes display
            }
        }
    }

    private var visibleDateRangeString: String {
        let calendar = Calendar.current
        let visibleDuration = selectedPeriod.numberOfBars
        let endDate = calendar.date(byAdding: selectedPeriod.chartComponent, value: visibleDuration - 1, to: scrollPosition) ?? scrollPosition

        // Check if start and end are in same year
        let startYear = calendar.component(.year, from: scrollPosition)
        let endYear = calendar.component(.year, from: endDate)
        let sameYear = startYear == endYear

        switch selectedPeriod {
        case .day:
            // Day: "Mon DD, Time AM/PM - Mon DD, Time AM/PM, Year"
            // Unless spans year then: "Mon DD, Time AM/PM, Year - Mon DD, Time AM/PM, Year"
            let dayEndDate = calendar.date(byAdding: .hour, value: 24, to: scrollPosition) ?? scrollPosition
            let dayEndYear = calendar.component(.year, from: dayEndDate)
            if startYear == dayEndYear {
                let startFormatter = DateFormatter()
                startFormatter.dateFormat = "MMM d, h a"
                let endFormatter = DateFormatter()
                endFormatter.dateFormat = "MMM d, h a, yyyy"
                return "\(startFormatter.string(from: scrollPosition)) - \(endFormatter.string(from: dayEndDate))"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, h a, yyyy"
                return "\(formatter.string(from: scrollPosition)) - \(formatter.string(from: dayEndDate))"
            }
        case .year:
            // Year: "Mon YYYY - Mon YYYY"
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yyyy"
            return "\(formatter.string(from: scrollPosition)) - \(formatter.string(from: endDate))"
        default:
            // Week, Month, 6M: "Mon DD - Mon DD, Year"
            // Unless cross year then: "Mon DD, Year 1 - Mon DD, Year 2"
            if sameYear {
                let startFormatter = DateFormatter()
                startFormatter.dateFormat = "MMM d"
                let endFormatter = DateFormatter()
                endFormatter.dateFormat = "MMM d, yyyy"
                return "\(startFormatter.string(from: scrollPosition)) - \(endFormatter.string(from: endDate))"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, yyyy"
                return "\(formatter.string(from: scrollPosition)) - \(formatter.string(from: endDate))"
            }
        }
    }

    // MARK: - Labels

    /// Unselected label: "AVG" for Y/6M/M/W, "TOTAL" for D
    private var unselectedLabel: String {
        switch selectedPeriod {
        case .day: return "TOTAL"
        case .week, .month, .sixMonths, .year: return "DAILY AVG"
        }
    }

    /// Selected bar label: "DAILY AVG" for Y/6M, "TOTAL" for M/W
    private var selectedBarLabel: String {
        switch selectedPeriod {
        case .day: return ""  // Not used for day view
        case .week, .month: return "TOTAL"
        case .sixMonths, .year: return "DAILY AVG"
        }
    }

    // MARK: - Duration Calculations

    /// Chart data points within the currently visible window
    private var visibleChartData: [WorkoutChartPoint] {
        let calendar = Calendar.current
        let visibleDuration = selectedPeriod.numberOfBars
        let endDate = calendar.date(byAdding: selectedPeriod.chartComponent, value: visibleDuration, to: scrollPosition) ?? scrollPosition
        return viewModel.chartData.filter { point in
            point.date >= scrollPosition && point.date <= endDate && point.durationMinutes > 0
        }
    }

    /// Unselected duration: Daily average for Y/6M/M/W, total for D
    private var unselectedDuration: Double {
        let calendar = Calendar.current

        switch selectedPeriod {
        case .day:
            // Total duration in visible window
            return visibleDayDuration
        case .week, .month:
            // Daily average over visible window - each chart point IS a day
            let visibleData = visibleChartData
            let totalDuration = visibleData.reduce(0) { $0 + $1.durationMinutes }
            let daysWithData = visibleData.count
            return daysWithData > 0 ? totalDuration / Double(daysWithData) : 0
        case .sixMonths, .year:
            // Daily average over visible window - use dailyData to count actual workout days
            let visibleDuration = selectedPeriod.numberOfBars
            let endDate = calendar.date(byAdding: selectedPeriod.chartComponent, value: visibleDuration, to: scrollPosition) ?? scrollPosition

            // Get total duration from visible chart points (weekly/monthly aggregates)
            let totalDuration = visibleChartData.reduce(0) { $0 + $1.durationMinutes }

            // Count actual workout days from dailyData within visible range
            let daysInRange = viewModel.dailyData.filter { point in
                point.date >= scrollPosition && point.date <= endDate && point.durationMinutes > 0
            }
            let daysWithData = daysInRange.count
            return daysWithData > 0 ? totalDuration / Double(daysWithData) : 0
        }
    }

    /// Selected bar duration:
    /// - Y: Daily average for that month
    /// - 6M: Daily average for that week
    /// - M/W: Total duration for that day
    private func selectedBarDuration(_ bar: WorkoutChartPoint) -> Double {
        switch selectedPeriod {
        case .day:
            return bar.durationMinutes
        case .week, .month:
            // Total for that day
            return bar.durationMinutes
        case .sixMonths:
            // Daily average for that week - use cached ViewModel lookup
            let days = daysInWeek(for: bar.date)
            return days > 0 ? bar.durationMinutes / Double(days) : bar.durationMinutes
        case .year:
            // Daily average for that month - use cached ViewModel lookup
            let days = daysInMonth(for: bar.date)
            return days > 0 ? bar.durationMinutes / Double(days) : bar.durationMinutes
        }
    }

    /// Duration for the currently visible day window (for day view)
    private var visibleDayDuration: Double {
        guard selectedPeriod == .day else { return 0 }
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .hour, value: 24, to: scrollPosition) ?? scrollPosition
        return viewModel.dayWorkouts
            .filter { $0.startTime >= scrollPosition && $0.startTime <= endDate }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    /// Workout count within the currently visible window (total workouts)
    private var visibleWorkoutCount: Int {
        if selectedPeriod == .day {
            let calendar = Calendar.current
            let endDate = calendar.date(byAdding: .hour, value: 24, to: scrollPosition) ?? scrollPosition
            return viewModel.dayWorkouts.filter { $0.startTime >= scrollPosition && $0.startTime <= endDate }.count
        } else {
            // Sum workout counts from visible chart data
            return visibleChartData.reduce(0) { $0 + $1.workoutCount }
        }
    }

    // MARK: - Workout Count View

    @ViewBuilder
    private func workoutCountView(for count: Int) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(count == 1 ? "workout" : "workouts")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Formatting

    /// Format Y-axis value based on scale
    /// Hours scale: value is in hours, show "1h", "2h", "3h"
    /// Minutes scale: value is in minutes, show "20m", "40m", "60m"
    private func formatYAxisValue(_ value: Double) -> String {
        if useHoursScale {
            // Value is in hours - just show whole hours
            return "\(Int(value))h"
        } else {
            // Value is in minutes
            return "\(Int(value))m"
        }
    }

    private func formatDuration(_ minutes: Double) -> String {
        if minutes < 60 {
            return "\(Int(minutes))m"
        } else {
            let hours = Int(minutes) / 60
            let mins = Int(minutes) % 60
            if mins == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(mins)m"
        }
    }

    /// Format workout time range for selected workout in day view
    /// "Mon DD, Time AM/PM - Mon DD, Time AM/PM, Year" or with year on both if cross-year
    private func formatWorkoutTimeRange(_ workout: DayWorkoutEvent) -> String {
        let calendar = Calendar.current
        let startYear = calendar.component(.year, from: workout.startTime)
        let endYear = calendar.component(.year, from: workout.endTime)
        let sameDay = calendar.isDate(workout.startTime, inSameDayAs: workout.endTime)

        if sameDay {
            // Same day: "Dec 10, 7:30 PM - 8:15 PM, 2025"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            let yearFormatter = DateFormatter()
            yearFormatter.dateFormat = "yyyy"
            return "\(dateFormatter.string(from: workout.startTime)), \(timeFormatter.string(from: workout.startTime)) - \(timeFormatter.string(from: workout.endTime)), \(yearFormatter.string(from: workout.endTime))"
        } else if startYear == endYear {
            // Different day, same year: "Dec 10, 11:30 PM - Dec 11, 12:15 AM, 2025"
            let startFormatter = DateFormatter()
            startFormatter.dateFormat = "MMM d, h:mm a"
            let endFormatter = DateFormatter()
            endFormatter.dateFormat = "MMM d, h:mm a, yyyy"
            return "\(startFormatter.string(from: workout.startTime)) - \(endFormatter.string(from: workout.endTime))"
        } else {
            // Cross year: "Dec 31, 11:30 PM, 2024 - Jan 1, 12:15 AM, 2025"
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, h:mm a, yyyy"
            return "\(formatter.string(from: workout.startTime)) - \(formatter.string(from: workout.endTime))"
        }
    }

    /// Format selected bar date based on period:
    /// - W/M: "Mon DD, Year"
    /// - 6M: "Mon DD - Mon DD, Year" (week range)
    /// - Y: "Mon Year"
    private func formatSelectedBarDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()

        switch selectedPeriod {
        case .day:
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        case .week, .month:
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        case .sixMonths:
            // Week range: "Dec 1 - Dec 7, 2025"
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
                formatter.dateFormat = "MMM d, yyyy"
                return formatter.string(from: date)
            }
            let lastDay = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.end
            let startFormatter = DateFormatter()
            startFormatter.dateFormat = "MMM d"
            let endFormatter = DateFormatter()
            endFormatter.dateFormat = "MMM d, yyyy"
            return "\(startFormatter.string(from: weekInterval.start)) - \(endFormatter.string(from: lastDay))"
        case .year:
            formatter.dateFormat = "MMM yyyy"
            return formatter.string(from: date)
        }
    }
}

#Preview {
    NavigationStack {
        CardioDurationView(color: .red, pillar: "Movement + Exercise", sectionId: "NAV_MOVEMENT")
    }
}
