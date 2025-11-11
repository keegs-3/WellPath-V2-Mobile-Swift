//
//  ComponentScoreTrendChart.swift
//  WellPath
//
//  Reusable trend chart for component scores (markers, behaviors, education)
//

import SwiftUI
import Charts
import Supabase

struct ComponentScoreTrendChart: View {
    let componentType: String // "markers", "behaviors", "education"
    let componentName: String // Display name
    let componentColor: Color

    @State private var selectedPeriod: TimePeriod = .week
    @State private var isLoading = false
    @State private var timeline: [ComponentScoreDataPoint] = []
    @State private var scrollPosition: Date = Date()
    @State private var selectedDate: Date?
    @State private var loadTask: Task<Void, Never>?

    private let supabase = SupabaseManager.shared.client

    var body: some View {
        VStack(spacing: 0) {
            chartView
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .task {
            await loadData(for: selectedPeriod)
        }
    }

    private var chartView: some View {
        VStack(spacing: 0) {
            if !isLoading {
                VStack(spacing: 0) {
                    // Period picker (excluding Day - doesn't make sense for scores)
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(TimePeriod.allCases.filter { $0 != .day }, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .onChange(of: selectedPeriod) { oldValue, newPeriod in
                        selectedDate = nil
                        scrollPosition = calculateScrollPosition(for: newPeriod)
                        Task {
                            await loadData(for: newPeriod)
                        }
                    }

                    // Value display
                    VStack(alignment: .leading, spacing: 4) {
                        if let date = selectedDate,
                           let selected = timeline.first(where: { Calendar.current.isDate($0.date, equalTo: date, toGranularity: .day) }) {

                            Text(formatSelectedDateLabel(date))
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(String(format: "%.0f", selected.score))
                                    .font(.system(size: 48, weight: .semibold))
                                    .foregroundColor(componentColor)
                            }
                        } else {
                            Text(getAggregateLabel())
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(String(format: "%.0f", calculateAverage()))
                                    .font(.system(size: 48, weight: .semibold))
                                    .foregroundColor(componentColor)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 24)

                    // Line chart
                    Chart(timeline) { dataPoint in
                        // Invisible placeholder for ALL points to establish x-axis domain
                        PointMark(
                            x: .value("Date", dataPoint.date),
                            y: .value("Score", 0)
                        )
                        .opacity(0)

                        // Only show line/area/points for non-zero values
                        if dataPoint.score > 0 {
                            // User data line
                            LineMark(
                                x: .value("Date", dataPoint.date),
                                y: .value("Score", dataPoint.score)
                            )
                            .foregroundStyle(componentColor)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 3))

                            // Area under line
                            AreaMark(
                                x: .value("Date", dataPoint.date),
                                y: .value("Score", dataPoint.score)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [componentColor.opacity(0.2), componentColor.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)

                            // Point marks (no annotation here - will use overlay)
                            if let selectedDate = selectedDate,
                               Calendar.current.isDate(dataPoint.date, equalTo: selectedDate, toGranularity: .day) {
                                // Selected point (larger)
                                PointMark(
                                    x: .value("Date", dataPoint.date),
                                    y: .value("Score", dataPoint.score)
                                )
                                .foregroundStyle(componentColor)
                                .symbolSize(150)
                            } else {
                                // Regular point (not selected)
                                PointMark(
                                    x: .value("Date", dataPoint.date),
                                    y: .value("Score", dataPoint.score)
                                )
                                .foregroundStyle(componentColor)
                            }
                        }
                    }
                    .chartYScale(domain: 0...105)
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            // Display annotation for selected point
                            if let selectedDate = selectedDate,
                               let selectedData = timeline.first(where: { Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: .day) }),
                               selectedData.score > 0 {

                                // Get the position of the selected point
                                if let xPos = proxy.position(forX: selectedData.date),
                                   let yPos = proxy.position(forY: selectedData.score) {

                                    // Annotation content
                                    VStack(spacing: 4) {
                                        Text("Score: \(String(format: "%.0f", selectedData.score))")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(uiColor: .systemBackground))
                                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                                    )
                                    // Position the annotation above the point, but ensure it doesn't go off screen
                                    .position(x: xPos, y: max(30, yPos - 40))
                                }
                            }
                        }
                    }
                    .frame(height: 220)
                    .chartScrollableAxes(.horizontal)
                    .chartScrollPosition(x: $scrollPosition)
                    .chartXVisibleDomain(length: getVisibleDomainTimeInterval())
                    .onAppear {
                        // Position scroll so right edge of visible window is at 12AM + buffer
                        scrollPosition = calculateScrollPosition(for: selectedPeriod)
                    }
                    .onChange(of: scrollPosition) { oldPos, newPos in
                        // Infinite scroll: load more data when approaching edges
                        Task {
                            await loadMoreIfNeeded(scrollPosition: newPos, period: selectedPeriod)
                        }
                    }
                    .chartGesture { proxy in
                        SpatialTapGesture()
                            .onEnded { value in
                                if let tappedDate: Date = proxy.value(atX: value.location.x) {
                                    let closest = timeline.min(by: {
                                        abs($0.date.timeIntervalSince(tappedDate)) < abs($1.date.timeIntervalSince(tappedDate))
                                    })

                                    if selectedDate == closest?.date {
                                        selectedDate = nil
                                    } else {
                                        selectedDate = closest?.date
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
                        AxisMarks { value in
                            AxisValueLabel()
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                                .foregroundStyle(Color.secondary.opacity(0.2))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                }
                .background(Color(white: 0.95))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Helpers

    private func calculateScrollPosition(for period: TimePeriod) -> Date {
        let calendar = Calendar.current
        let now = Date()

        // Get visible window duration
        let visibleDomain = getVisibleDomainTimeInterval()

        // Position scroll so today is ~90% across the visible window (leaving 10% for future)
        // Scroll position = now - (90% of visible duration)
        let offsetFromEnd = visibleDomain * 0.9
        return now.addingTimeInterval(-offsetFromEnd)
    }

    private func getVisibleDomainTimeInterval() -> TimeInterval {
        switch selectedPeriod {
        case .day: return 24 * 3600 // 24 hours in seconds
        case .week: return 7 * 24 * 3600 // 7 days in seconds
        case .month: return 30 * 24 * 3600 // 30 days in seconds
        case .sixMonth: return 26 * 7 * 24 * 3600 // 26 weeks in seconds
        case .year: return 365 * 24 * 3600 // 1 year in seconds
        }
    }

    private func getAxisStride() -> Calendar.Component {
        switch selectedPeriod {
        case .day: return .hour
        case .week: return .day
        case .month: return .weekOfYear
        case .sixMonth: return .weekOfYear  // Points are weeks, so stride by week
        case .year: return .month
        }
    }

    private func getAxisMultiplier() -> Int {
        switch selectedPeriod {
        case .day: return 6  // Every 6 hours
        case .week: return 1  // Every day
        case .month: return 1  // Every week
        case .sixMonth: return 4  // Every 4 weeks (~monthly labels)
        case .year: return 1  // Every month
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

    private func getAggregateLabel() -> String {
        switch selectedPeriod {
        case .day: return "DAY"
        case .week: return "WEEK"
        case .month: return "MONTH"
        case .sixMonth: return "6 MONTHS"
        case .year: return "YEAR"
        }
    }

    private func formatSelectedDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        switch selectedPeriod {
        case .day:
            formatter.dateFormat = "h:00 a"
            return formatter.string(from: date)
        case .week, .month:
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        case .sixMonth:
            guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: date) else {
                formatter.dateFormat = "MMM d"
                return formatter.string(from: date)
            }
            let startFormatter = DateFormatter()
            startFormatter.dateFormat = "MMM d"
            let endFormatter = DateFormatter()
            endFormatter.dateFormat = "d"
            return "\(startFormatter.string(from: date))-\(endFormatter.string(from: weekEnd))"
        case .year:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }
    }

    // Calculate average for VISIBLE WINDOW only
    private func calculateAverage() -> Double {
        guard !timeline.isEmpty else { return 0 }

        // Calculate visible window based on scroll position
        let visibleDuration: TimeInterval
        switch selectedPeriod {
        case .day: visibleDuration = 24 * 3600
        case .week: visibleDuration = 7 * 24 * 3600
        case .month: visibleDuration = 30 * 24 * 3600
        case .sixMonth: visibleDuration = 26 * 7 * 24 * 3600
        case .year: visibleDuration = 365 * 24 * 3600
        }

        let calendar = Calendar.current
        guard let endDate = calendar.date(byAdding: .second, value: Int(visibleDuration), to: scrollPosition) else {
            return 0
        }

        // Filter to visible window
        let visibleData = timeline.filter { $0.date >= scrollPosition && $0.date <= endDate }

        // Filter out zeros
        let actualData = visibleData.filter { $0.score > 0 }

        guard !actualData.isEmpty else { return 0 }

        // Return average
        return actualData.reduce(0, { $0 + $1.score }) / Double(actualData.count)
    }

    func loadData(for period: TimePeriod) async {
        // Cancel any existing load task
        loadTask?.cancel()

        // Create new task
        loadTask = Task {
            isLoading = true
            defer { isLoading = false }

            guard let userId = try? await supabase.auth.session.user.id else { return }

            let calendar = Calendar.current
            // Use local timezone  // Use UTC for consistency with database
            let now = Date()
            let startOfToday = calendar.startOfDay(for: now)

            // Extend data loading into future with period-specific buffer from start of today
            let newestDate: Date
            switch period {
            case .day:
                newestDate = calendar.date(byAdding: .hour, value: 12, to: startOfToday) ?? now
            case .week:
                newestDate = calendar.date(byAdding: .hour, value: 32, to: startOfToday) ?? now
            case .month:
                newestDate = calendar.date(byAdding: .hour, value: 48, to: startOfToday) ?? now
            case .sixMonth:
                newestDate = calendar.date(byAdding: .day, value: 7, to: startOfToday) ?? now
            case .year:
                newestDate = calendar.date(byAdding: .day, value: 21, to: startOfToday) ?? now
            }

            // Load data from a wide range in the past to newestDate
            // This is INDEPENDENT of view window - just load lots of data
            let startDate: Date
            switch period {
            case .day:
                startDate = calendar.date(byAdding: .day, value: -7, to: startOfToday) ?? now
            case .week:
                startDate = calendar.date(byAdding: .weekOfYear, value: -8, to: startOfToday) ?? now
            case .month:
                startDate = calendar.date(byAdding: .month, value: -6, to: startOfToday) ?? now
            case .sixMonth:
                startDate = calendar.date(byAdding: .month, value: -18, to: startOfToday) ?? now
            case .year:
                startDate = calendar.date(byAdding: .year, value: -3, to: startOfToday) ?? now
            }

            // Create timeline
            var newTimeline: [ComponentScoreDataPoint] = []

            var currentDate = startDate
            while currentDate <= newestDate {
                newTimeline.append(ComponentScoreDataPoint(date: currentDate, score: 0))

                guard let nextDate = calendar.date(byAdding: getAxisStride(), value: 1, to: currentDate) else {
                    break
                }
                currentDate = nextDate
            }

            do {
                // Check for cancellation before making network request
                guard !Task.isCancelled else {
                    isLoading = false
                    return
                }

                // Format dates for ISO8601 query
                let queryFormatter = ISO8601DateFormatter()
                let oldestDateStr = queryFormatter.string(from: startDate)
                let newestDateStr = queryFormatter.string(from: newestDate)  // Use newestDate, not now!

                // Date parser for Supabase PostgreSQL timestamp format
                let dateParser = DateFormatter()
                dateParser.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
                dateParser.timeZone = TimeZone(identifier: "UTC")
                dateParser.locale = Locale(identifier: "en_US_POSIX")

                // Fetch component score HISTORY data
                let historyResponse: [ComponentScoreHistory] = try await supabase
                    .from("patient_component_scores_history")
                    .select()
                    .eq("patient_id", value: userId.uuidString)
                    .eq("component_type", value: componentType)
                    .gte("calculated_at", value: oldestDateStr)
                    .lte("calculated_at", value: newestDateStr)
                    .order("calculated_at", ascending: true)
                    .execute()
                    .value

                // Fetch component score CURRENT data
                let currentResponse: [ComponentScoreCurrent] = try await supabase
                    .from("patient_component_scores_current")
                    .select()
                    .eq("patient_id", value: userId.uuidString)
                    .eq("component_type", value: componentType)
                    .execute()
                    .value

                // Check for cancellation after network requests
                guard !Task.isCancelled else {
                    isLoading = false
                    return
                }

                // Combine history and current data
                var allRecords: [(date: Date, percentage: Double)] = []

                // Add historical records
                for record in historyResponse {
                    let utcDate = dateParser.date(from: record.calculatedAt) ?? Date()
                    allRecords.append((date: utcDate, percentage: record.componentPercentage))
                }

                // Add current record - ALWAYS place at today's date (start of today in UTC)
                for record in currentResponse {
                    // Current score always shows at today, not at calculated_at
                    let todayStartUTC = calendar.startOfDay(for: now)
                    allRecords.append((date: todayStartUTC, percentage: record.componentPercentage))
                }

                print("📊 Loaded \(historyResponse.count) historical + \(currentResponse.count) current component '\(componentType)' score records")

                // Determine granularity based on period
                let granularity: Calendar.Component
                switch period {
                case .day:
                    granularity = .hour
                case .week, .month:
                    granularity = .day
                case .sixMonth:
                    granularity = .weekOfYear
                case .year:
                    granularity = .month
                }

                // Overlay actual data on timeline
                for record in allRecords {
                    // Normalize date based on granularity
                    let normalizedRecordDate: Date
                    switch granularity {
                    case .hour:
                        normalizedRecordDate = record.date
                    case .day:
                        normalizedRecordDate = calendar.startOfDay(for: record.date)
                    case .weekOfYear:
                        normalizedRecordDate = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: record.date)) ?? record.date
                    case .month:
                        normalizedRecordDate = calendar.date(from: calendar.dateComponents([.year, .month], from: record.date)) ?? record.date
                    default:
                        normalizedRecordDate = record.date
                    }

                    if let index = newTimeline.firstIndex(where: {
                        let normalizedTimelineDate: Date
                        switch granularity {
                        case .hour:
                            normalizedTimelineDate = $0.date
                        case .day:
                            normalizedTimelineDate = calendar.startOfDay(for: $0.date)
                        case .weekOfYear:
                            normalizedTimelineDate = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: $0.date)) ?? $0.date
                        case .month:
                            normalizedTimelineDate = calendar.date(from: calendar.dateComponents([.year, .month], from: $0.date)) ?? $0.date
                        default:
                            normalizedTimelineDate = $0.date
                        }
                        return calendar.isDate(normalizedTimelineDate, equalTo: normalizedRecordDate, toGranularity: granularity)
                    }) {
                        newTimeline[index] = ComponentScoreDataPoint(
                            date: newTimeline[index].date,
                            score: record.percentage
                        )
                    }
                }

                // Add a dummy point at the end to prevent last data point from being cut off
                // This extends the domain past the last real data point
                if let lastDate = newTimeline.last?.date {
                    let dummyBuffer: TimeInterval
                    switch period {
                    case .day: dummyBuffer = 6 * 3600  // 6 hours
                    case .week: dummyBuffer = 12 * 3600  // 12 hours
                    case .month: dummyBuffer = 24 * 3600  // 1 day
                    case .sixMonth: dummyBuffer = 3 * 24 * 3600  // 3 days
                    case .year: dummyBuffer = 7 * 24 * 3600  // 7 days
                    }
                    let dummyDate = lastDate.addingTimeInterval(dummyBuffer)
                    newTimeline.append(ComponentScoreDataPoint(date: dummyDate, score: 0))
                }

                timeline = newTimeline
            } catch {
                // Only log non-cancellation errors
                if !Task.isCancelled {
                    print("❌ Error loading \(componentName) score: \(error)")
                }
            }
        }
    }

    // MARK: - Infinite Scroll

    func loadMoreIfNeeded(scrollPosition: Date, period: TimePeriod) async {
        guard !timeline.isEmpty, !isLoading else { return }
        guard let first = timeline.first?.date, let last = timeline.last?.date else { return }

        // Calculate scroll progress as percentage of total loaded range
        let totalRange = last.timeIntervalSince(first)
        guard totalRange > 0 else { return }

        let scrolledRange = scrollPosition.timeIntervalSince(first)
        let scrollProgress = scrolledRange / totalRange

        // Load older data when scrolled past 20% from start
        if scrollProgress < 0.2 {
            await loadOlderData(before: first, period: period)
        }

        // Load newer data when scrolled past 80% toward end
        else if scrollProgress > 0.8 {
            await loadNewerData(after: last, period: period)
        }
    }

    private func loadOlderData(before date: Date, period: TimePeriod) async {
        // Infinite scroll stub - will implement if needed
        print("📜 ComponentScoreTrendChart: Load older data before \(date)")
    }

    private func loadNewerData(after date: Date, period: TimePeriod) async {
        // Infinite scroll stub - will implement if needed
        print("📜 ComponentScoreTrendChart: Load newer data after \(date)")
    }
}

struct ComponentScoreDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let score: Double
}

#Preview {
    ComponentScoreTrendChart(
        componentType: "markers",
        componentName: "Markers",
        componentColor: Color(red: 0.40, green: 0.80, blue: 0.40)
    )
}
