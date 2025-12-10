//
//  ScrollableSleepChart.swift
//  WellPath
//
//  Scrollable chart for Week and Month views with stacked sleep stages.
//  Supports both hypnogram and bar chart visualization modes.
//

import SwiftUI
import Charts

struct ScrollableSleepChart: View {
    enum ViewMode {
        case week, month

        var visibleDays: Int {
            switch self {
            case .week: return 7
            case .month: return 33
            }
        }

        var barWidthRatio: CGFloat {
            switch self {
            case .week: return 0.6
            case .month: return 0.75
            }
        }

        var showDayNumbers: Bool {
            self == .month
        }

        var daysToLoad: (back: Int, ahead: Int) {
            switch self {
            case .week: return (14, 7)
            case .month: return (60, 30)
            }
        }
    }

    let viewMode: ViewMode
    @ObservedObject var viewModel: SleepAnalysisViewModel
    @Binding var selectedStage: SleepStage?
    @Binding var visibleRangeBinding: (start: Date, end: Date)?
    var height: CGFloat = 340 // Default total height (280 chart + 60 controls)
    var onVisibleRangeChange: ((Date, Date) -> Void)? = nil
    var showAbout: Binding<Bool>? = nil

    init(viewMode: ViewMode, viewModel: SleepAnalysisViewModel, selectedStage: Binding<SleepStage?>, visibleRangeBinding: Binding<(start: Date, end: Date)?>? = nil, height: CGFloat = 340, onVisibleRangeChange: ((Date, Date) -> Void)? = nil, showAbout: Binding<Bool>? = nil) {
        self.viewMode = viewMode
        self.viewModel = viewModel
        self._selectedStage = selectedStage
        self._visibleRangeBinding = visibleRangeBinding ?? .constant(nil)
        self.height = height
        self.onVisibleRangeChange = onVisibleRangeChange
        self.showAbout = showAbout
    }

    private var chartHeight: CGFloat { height - 60 } // Subtract space for controls
    private let baseDaySpacing: CGFloat = 4
    private let yAxisWidth: CGFloat = 50

    private var daySpacing: CGFloat {
        switch viewMode {
        case .week:
            return baseDaySpacing
        case .month:
            return 1
        }
    }

    private typealias ChartTimeRange = (startHour: Double, endHour: Double, totalHours: Double)
    private let defaultTimeRange: ChartTimeRange = (startHour: 2.0, endHour: 14.0, totalHours: 12.0)

    private struct ChartLayout {
        let dayWidth: CGFloat
        let barWidth: CGFloat
        let barXOffset: CGFloat

        init(totalWidth: CGFloat, yAxisWidth: CGFloat, daySpacing: CGFloat, visibleDays: Int, barWidthRatio: CGFloat, minimumDayWidth: CGFloat) {
            let chartAreaWidth = max(totalWidth - yAxisWidth, 0)
            let spacing = daySpacing * CGFloat(max(visibleDays - 1, 0))

            if visibleDays > 0 {
                let computedDayWidth = (chartAreaWidth - spacing) / CGFloat(visibleDays)
                dayWidth = max(computedDayWidth, minimumDayWidth)
            } else {
                dayWidth = max(minimumDayWidth, 0)
            }

            barWidth = dayWidth * barWidthRatio
            barXOffset = (dayWidth - barWidth) / 2.0
        }
    }

    @State private var scrolledID: Date? = nil
    @State private var visibleDateRange: (start: Date, end: Date)?
    @State private var lastScrollUpdate: Date = Date.distantPast
    @State private var hasInitializedScroll = false  // Track if we've scrolled to initial position

    // Cached data to prevent recomputation during scrolling
    @State private var cachedGroupedData: [(date: Date, sessions: [SleepSession])] = []
    @State private var cachedTimeRange: ChartTimeRange?
    @State private var lastDataVersion: Int = 0  // Track when data changes

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryMetrics

            if viewModel.sleepSessions.isEmpty {
                Text("No sleep data available")
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .foregroundColor(.secondary)
            } else {
                chartView
            }
        }
        .onAppear {
            // Load initial data if empty
            if viewModel.sleepSessions.isEmpty {
                Task {
                    let load = viewMode.daysToLoad
                    await viewModel.loadInitialSleepStages(daysBack: load.back, daysAhead: load.ahead)
                }
            }
        }
        .onChange(of: viewModel.sleepSessions.count) { _, newCount in
            // Refresh cached data when sessions change
            refreshCachedData()
        }
    }

    // MARK: - Data Caching

    /// Refresh cached data only when underlying data changes
    private func refreshCachedData() {
        let newVersion = viewModel.sleepSessions.count
        guard newVersion != lastDataVersion else { return }

        lastDataVersion = newVersion
        cachedGroupedData = computeGroupedByDate()
        cachedTimeRange = computeTimeRange()
    }

    /// Get cached grouped data, computing if necessary
    private func getGroupedData() -> [(date: Date, sessions: [SleepSession])] {
        if cachedGroupedData.isEmpty && !viewModel.sleepSessions.isEmpty {
            cachedGroupedData = computeGroupedByDate()
        }
        return cachedGroupedData
    }

    /// Get cached time range, computing if necessary
    private func getTimeRange() -> ChartTimeRange {
        if let cached = cachedTimeRange {
            return cached
        }
        let computed = computeTimeRange()
        cachedTimeRange = computed
        return computed
    }

    private var chartView: some View {
        GeometryReader { geometry in
            let minimumDayWidth: CGFloat = viewMode == .month ? 0 : 24
            let layout = ChartLayout(
                totalWidth: geometry.size.width,
                yAxisWidth: yAxisWidth,
                daySpacing: daySpacing,
                visibleDays: viewMode.visibleDays,
                barWidthRatio: viewMode.barWidthRatio,
                minimumDayWidth: minimumDayWidth
            )
            // Compute time range dynamically based on visible date range
            // This allows Y-axis to adjust when scrolling (e.g., nap goes out of view)
            let timeRange = computeTimeRangeForVisibleDays()

            chartContent(layout: layout, timeRange: timeRange)
        }
        .frame(height: height)
    }

    @ViewBuilder
    private func chartContent(layout: ChartLayout, timeRange: ChartTimeRange) -> some View {
        HStack(alignment: .top, spacing: 0) {
            scrollableDayColumns(layout: layout, timeRange: timeRange)
            yAxisView(timeRange: timeRange)
                .frame(width: yAxisWidth)
        }
    }

    @ViewBuilder
    private func scrollableDayColumns(layout: ChartLayout, timeRange: ChartTimeRange) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: daySpacing) {
                    // Use cached grouped data to avoid recomputation during scrolling
                    ForEach(getGroupedData(), id: \.date) { group in
                        dayColumn(for: group, layout: layout, timeRange: timeRange)
                            .id(group.date)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 12)
            }
            .scrollPosition(id: $scrolledID, anchor: .leading)
            .scrollTargetBehavior(.viewAligned)
            .onChange(of: scrolledID) { _, newID in
                guard let newID = newID else { return }
                updateVisibleRange(leadingDate: newID)
            }
            .onAppear {
                // Ensure cached data is initialized on appear
                if cachedGroupedData.isEmpty && !viewModel.sleepSessions.isEmpty {
                    refreshCachedData()
                }
                scrollToTodayIfNeeded(proxy: proxy)
            }
        }
    }

    @ViewBuilder
    private func dayColumn(for group: (date: Date, sessions: [SleepSession]), layout: ChartLayout, timeRange: ChartTimeRange) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .leading) {
                Canvas { context, size in
                    drawGridLines(context: context, size: size, timeRange: timeRange)
                }
                .frame(width: layout.dayWidth, height: chartHeight)

                if viewMode == .month && shouldShowDayNumber(for: group.date) {
                    Canvas { context, size in
                        let path = Path { p in
                            p.move(to: CGPoint(x: layout.dayWidth / 2, y: 0))
                            p.addLine(to: CGPoint(x: layout.dayWidth / 2, y: size.height))
                        }
                        context.stroke(path, with: .color(Color.gray.opacity(0.15)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                    }
                    .frame(width: layout.dayWidth, height: chartHeight)
                }

                Canvas { context, size in
                    drawDayBars(
                        context: context,
                        size: size,
                        sessions: group.sessions,
                        timeRange: timeRange,
                        barXOffset: layout.barXOffset,
                        barWidth: layout.barWidth,
                        isSelected: isBarSelected(groupDate: group.date)
                    )
                }
                .frame(width: layout.dayWidth, height: chartHeight)

                if isBarSelected(groupDate: group.date) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 1)
                        .frame(height: chartHeight)
                        .offset(x: layout.barXOffset)
                    Rectangle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 1)
                        .frame(height: chartHeight)
                        .offset(x: layout.barXOffset + layout.barWidth)
                }
            }
            .frame(width: layout.dayWidth, height: chartHeight)
            .contentShape(Rectangle())
            .onTapGesture {
                if let bar = createSleepBar(from: group.sessions, date: group.date) {
                    viewModel.selectBar(bar)
                }
            }

            if viewMode == .month {
                if shouldShowDayNumber(for: group.date) {
                    Text("\(Calendar.current.component(.day, from: group.date))")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                        .frame(height: 20)
                        .frame(minWidth: layout.dayWidth)
                } else {
                    Color.clear
                        .frame(width: layout.dayWidth, height: 20)
                }
            } else {
                Text(formatDateLabel(group.date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: layout.dayWidth, height: 20)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
    }

    private func scrollToTodayIfNeeded(proxy: ScrollViewProxy) {
        // Only scroll to today if we haven't initialized yet
        // This prevents the chart from snapping back to today when switching tabs or re-appearing
        guard !hasInitializedScroll else { return }
        hasInitializedScroll = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let groups = getGroupedData()  // Use cached data
            guard let lastGroupDate = groups.last?.date else { return }

            let targetDate = groups.first(where: { calendar.isDate($0.date, inSameDayAs: today) })?.date
                ?? groups.last(where: { $0.date <= today })?.date
                ?? lastGroupDate

            // Scroll to tomorrow (or day after today) at trailing edge
            // This gives today breathing room and prevents cutoff
            let scrollTarget = calendar.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate
            let leadingDate = calendar.date(byAdding: .day, value: -(viewMode.visibleDays - 1), to: scrollTarget) ?? scrollTarget

            visibleDateRange = nil
            updateVisibleRange(leadingDate: leadingDate)
            proxy.scrollTo(scrollTarget, anchor: .trailing)
        }
    }

    // MARK: - Visible Range Management

    private func updateVisibleRange(leadingDate: Date) {
        // Increased debounce threshold from 0.2s to 0.5s for smoother fast scrolling
        guard Date().timeIntervalSince(lastScrollUpdate) > 0.5 else { return }
        lastScrollUpdate = Date()

        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: viewMode.visibleDays - 1, to: leadingDate)!

        if visibleDateRange?.start != leadingDate || visibleDateRange?.end != endDate {
            visibleDateRange = (leadingDate, endDate)

            // Update binding for parent
            visibleRangeBinding = (leadingDate, endDate)

            // Notify parent of visible range change
            onVisibleRangeChange?(leadingDate, endDate)

            // Update metrics
            Task {
                // Calculate fallback from visible sessions
                let calendar = Calendar.current
                let visibleSessions = viewModel.sleepSessions.filter { session in
                    let sessionDate = calendar.startOfDay(for: session.date)
                    return sessionDate >= leadingDate && sessionDate <= endDate && hasSleepData(session)
                }

                guard !visibleSessions.isEmpty else {
                    await MainActor.run {
                        if visibleDateRange?.start == leadingDate {
                            viewModel.totalTimeInBed = "No Data"
                            viewModel.totalTimeAsleep = "No Data"
                            viewModel.currentDateText = formatDateRange(leadingDate, endDate)
                        }
                    }
                    checkEdges(visibleStart: leadingDate, visibleEnd: endDate)
                    return
                }

                let fallbackAverages = calculateDailyAverages(for: visibleSessions)
                let fallbackTimeInBed = fallbackAverages.timeInBed
                let fallbackTimeAsleep = fallbackAverages.timeAsleep

                // Use local calculation from visible sessions
                await MainActor.run {
                    if visibleDateRange?.start == leadingDate {
                        viewModel.totalTimeInBed = formatDuration(fallbackTimeInBed)
                        viewModel.totalTimeAsleep = formatDuration(fallbackTimeAsleep)
                        viewModel.currentDateText = formatDateRange(leadingDate, endDate)
                    }
                }

                checkEdges(visibleStart: leadingDate, visibleEnd: endDate)
            }
        }
    }

    private func checkEdges(visibleStart: Date, visibleEnd: Date) {
        let calendar = Calendar.current
        let sessionDates = viewModel.sleepSessions.map { calendar.startOfDay(for: $0.date) }

        guard let oldestData = sessionDates.min(), let newestData = sessionDates.max() else { return }

        if let diff = calendar.dateComponents([.day], from: visibleStart, to: oldestData).day, diff >= 0, diff <= 3, !viewModel.isLoadingOlder {
            Task { await viewModel.loadEarlierSleepStages() }
        }

        if let diff = calendar.dateComponents([.day], from: newestData, to: visibleEnd).day, diff >= 0, diff <= 3, !viewModel.isLoadingNewer {
            Task { await viewModel.loadLaterSleepStages() }
        }
    }

    // MARK: - Canvas Drawing

    private func drawGridLines(context: GraphicsContext, size: CGSize, timeRange: ChartTimeRange) {
        let hourLabels = generateHourLabels(timeRange: timeRange)
        for adjustedHour in hourLabels {
            let yPosition = ((adjustedHour - timeRange.startHour) / timeRange.totalHours) * size.height
            let path = Path { p in
                p.move(to: CGPoint(x: 0, y: yPosition))
                p.addLine(to: CGPoint(x: size.width, y: yPosition))
            }
            context.stroke(path, with: .color(Color.gray.opacity(0.15)), style: StrokeStyle(lineWidth: 0.5))
        }
    }

    private func drawDayBars(context: GraphicsContext, size: CGSize, sessions: [SleepSession], timeRange: ChartTimeRange, barXOffset: CGFloat, barWidth: CGFloat, isSelected: Bool) {
        for session in sessions {
            // Handle manual entries (no segments)
            if session.isManual, let manualEntry = session.manualEntry {
                // Draw two vertical bars: time in bed (background) and time asleep (foreground)
                // Both have same width, potentially different heights (duration)

                let asleepStart = adjustedHour(from: manualEntry.bedtime)
                let asleepEnd = adjustedHour(from: manualEntry.waketime)
                let asleepDuration = asleepEnd - asleepStart

                let yPosition = ((asleepStart - timeRange.startHour) / timeRange.totalHours) * size.height
                let barHeight = max((asleepDuration / timeRange.totalHours) * size.height, 1.0)

                // Draw time in bed bar (background) - same dimensions as asleep for now
                // TODO: Support separate time_in_bed duration when available
                let inBedRect = CGRect(x: barXOffset, y: yPosition, width: barWidth, height: barHeight)
                var inBedContext = context
                if isSelected { inBedContext.opacity = 1.0 } else { inBedContext.opacity = 0.5 }
                inBedContext.fill(Path(inBedRect), with: .color(Color.gray.opacity(0.4)))

                // Draw time asleep bar (foreground) - overlaid on time in bed
                let asleepRect = CGRect(x: barXOffset, y: yPosition, width: barWidth, height: barHeight)
                var asleepContext = context
                if isSelected { asleepContext.opacity = 1.0 }
                asleepContext.fill(Path(asleepRect), with: .color(stageColor(.core)))

                continue
            }

            // Handle HealthKit data (segments)
            guard !session.segments.isEmpty else { continue }

            // Check if we have detailed stage data (REM/Core/Deep) or just basic (asleep/awake)
            let hasDetailedStages = session.segments.contains {
                $0.stage == .rem || $0.stage == .core || $0.stage == .deep
            }

            if hasDetailedStages {
                // Draw all segments including in bed (light green background)
                for segment in session.segments.sorted(by: { $0.startTime < $1.startTime }) {
                    let segmentStart = adjustedHour(from: segment.startTime)
                    let segmentEnd = adjustedHour(from: segment.endTime)
                    let segmentDuration = segmentEnd - segmentStart

                    let yPosition = ((segmentStart - timeRange.startHour) / timeRange.totalHours) * size.height
                    let height = max((segmentDuration / timeRange.totalHours) * size.height, 1.0)

                    let segmentWidth = barWidth  // All stages same width
                    let segmentXOffset = barXOffset

                    let rect = CGRect(x: segmentXOffset, y: yPosition, width: segmentWidth, height: height)
                    var segmentContext = context

                    // In bed segments: light green with lower opacity (background layer)
                    if segment.stage == .inBed {
                        if isSelected { segmentContext.opacity = 0.5 } else { segmentContext.opacity = 0.3 }
                        segmentContext.fill(Path(rect), with: .color(Color(hex: "C8E6C9") ?? .green)) // Very light green
                    } else {
                        // Other stages: normal rendering
                        if isSelected { segmentContext.opacity = 1.0 }
                        segmentContext.fill(Path(rect), with: .color(stageColor(segment.stage)))
                    }
                }
            } else {
                // Basic sessions: Draw three layers
                // 1. Time in bed (light green background) - shows full session time
                // 2. Time asleep (teal middle layer)
                // 3. Awake periods (red on top)

                // Layer 1: Draw "in bed" bar as background (light green) for the full session
                let sessionStart = adjustedHour(from: session.sessionStart)
                let sessionEnd = adjustedHour(from: session.sessionEnd)
                let sessionDuration = sessionEnd - sessionStart
                let sessionYPosition = ((sessionStart - timeRange.startHour) / timeRange.totalHours) * size.height
                let sessionHeight = max((sessionDuration / timeRange.totalHours) * size.height, 1.0)

                let inBedRect = CGRect(x: barXOffset, y: sessionYPosition, width: barWidth, height: sessionHeight)
                var inBedContext = context
                if isSelected { inBedContext.opacity = 0.5 } else { inBedContext.opacity = 0.3 }
                inBedContext.fill(Path(inBedRect), with: .color(Color(hex: "C8E6C9") ?? .green)) // Very light green

                let awakeSegments = session.segments.filter { $0.stage == .awake }
                let sleepSegments = session.segments.filter { $0.stage != .inBed && $0.stage != .awake }

                // Layer 2: Draw time asleep as middle layer (sleep pillar color)
                if let sleepStart = sleepSegments.map({ $0.startTime }).min(),
                   let sleepEnd = sleepSegments.map({ $0.endTime }).max() {
                    let start = adjustedHour(from: sleepStart)
                    let end = adjustedHour(from: sleepEnd)
                    let yPosition = ((start - timeRange.startHour) / timeRange.totalHours) * size.height
                    let height = max((end - start) / timeRange.totalHours * size.height, 1.0)

                    let rect = CGRect(x: barXOffset, y: yPosition, width: barWidth, height: height)
                    var asleepContext = context
                    if isSelected { asleepContext.opacity = 1.0 } else { asleepContext.opacity = 0.8 }
                    asleepContext.fill(Path(rect), with: .color(Color(hex: "80CBC4") ?? .teal))
                }

                // Layer 3: Draw awake periods (red) on top
                for awakeSegment in awakeSegments {
                    let segmentStart = adjustedHour(from: awakeSegment.startTime)
                    let segmentEnd = adjustedHour(from: awakeSegment.endTime)
                    let segmentDuration = segmentEnd - segmentStart

                    let yPosition = ((segmentStart - timeRange.startHour) / timeRange.totalHours) * size.height
                    let height = max((segmentDuration / timeRange.totalHours) * size.height, 1.0)

                    let rect = CGRect(x: barXOffset, y: yPosition, width: barWidth, height: height)
                    var awakeContext = context
                    if isSelected { awakeContext.opacity = 1.0 } else { awakeContext.opacity = 0.8 }
                    awakeContext.fill(Path(rect), with: .color(.red))
                }
            }
        }
    }

    // MARK: - Time Calculations

    /// Compute time range dynamically based on currently visible days
    /// This is called on each render to allow Y-axis to adjust when scrolling
    private func computeTimeRangeForVisibleDays() -> ChartTimeRange {
        guard let range = visibleDateRange else {
            return defaultTimeRange
        }

        let calendar = Calendar.current
        let visibleSessions = viewModel.sleepSessions.filter { session in
            let sessionDate = calendar.startOfDay(for: session.date)
            return sessionDate >= range.start && sessionDate <= range.end && hasSleepData(session)
        }

        guard !visibleSessions.isEmpty else {
            return defaultTimeRange
        }

        var earliestStart: Double?
        var latestEnd: Double?

        for session in visibleSessions {
            // Check ALL segments (including naps) not just session start/end
            // This ensures daytime naps are included in the time range
            for segment in session.segments {
                let segmentStart = adjustedHour(from: segment.startTime)
                let segmentEnd = adjustedHour(from: segment.endTime)

                if let currentStart = earliestStart {
                    earliestStart = min(currentStart, segmentStart)
                } else {
                    earliestStart = segmentStart
                }

                if let currentEnd = latestEnd {
                    latestEnd = max(currentEnd, segmentEnd)
                } else {
                    latestEnd = segmentEnd
                }
            }

            // Also check manual entries
            if let manual = session.manualEntry {
                let manualStart = adjustedHour(from: manual.bedtime)
                let manualEnd = adjustedHour(from: manual.waketime)

                if let currentStart = earliestStart {
                    earliestStart = min(currentStart, manualStart)
                } else {
                    earliestStart = manualStart
                }

                if let currentEnd = latestEnd {
                    latestEnd = max(currentEnd, manualEnd)
                } else {
                    latestEnd = manualEnd
                }
            }
        }

        guard let minStart = earliestStart, let maxEnd = latestEnd else {
            return defaultTimeRange
        }

        // Round to whole hours for cleaner Y-axis labels
        let startBuffer: Double = 1.0
        let endBuffer: Double = 1.0

        var bufferedStart = floor(max(minStart - startBuffer, 0))
        var bufferedEnd = ceil(maxEnd + endBuffer)

        // Cap at 24 hours max (6PM to 6PM next day)
        // If a segment somehow crosses this boundary (extremely rare),
        // it would be split into 2 days at the database level anyway
        bufferedEnd = min(bufferedEnd, 24.0)

        let totalHours = bufferedEnd - bufferedStart

        guard totalHours >= 1 else { return defaultTimeRange }

        return (bufferedStart, bufferedEnd, totalHours)
    }

    /// Legacy cached version (kept for reference but no longer used)
    private func computeTimeRange() -> ChartTimeRange {
        return computeTimeRangeForVisibleDays()
    }

    private func adjustedHour(from date: Date) -> Double {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0)
        let clockHour = hour + (minute / 60.0)

        return clockHour >= 18.0 ? clockHour - 18.0 : clockHour + 6.0
    }

    private func clockHour(from adjustedHour: Double) -> Int {
        let rounded = Int((adjustedHour).rounded())
        let normalized = (rounded % 24 + 24) % 24
        return normalized < 6 ? normalized + 18 : normalized - 6
    }

    private func generateHourLabels(timeRange: ChartTimeRange) -> [Double] {
        // Calculate interval to get max 6 labels (including start and end)
        // For 9 hours (10PM-7AM): interval = 2-3 hours → labels at 10, 1, 4, 7
        // For 20 hours (with nap): interval = 4 hours → more spread out
        let totalHours = timeRange.totalHours
        let maxLabels = 6

        // Calculate ideal interval (round up to nice values: 1, 2, 3, 4, 6)
        let rawInterval = totalHours / Double(maxLabels - 1)
        let interval: Double
        if rawInterval <= 1 {
            interval = 1
        } else if rawInterval <= 2 {
            interval = 2
        } else if rawInterval <= 3 {
            interval = 3
        } else if rawInterval <= 4 {
            interval = 4
        } else {
            interval = 6
        }

        var labels: [Double] = []

        // Start at the first whole hour after startHour
        let firstLabel = ceil(timeRange.startHour)
        var currentHour = firstLabel

        while currentHour <= timeRange.endHour && labels.count < maxLabels {
            labels.append(currentHour)
            currentHour += interval
        }

        return labels
    }

    // MARK: - Y-Axis

    private func yAxisView(timeRange: ChartTimeRange) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(generateHourLabels(timeRange: timeRange), id: \.self) { adjustedHour in
                    let yPosition = ((adjustedHour - timeRange.startHour) / timeRange.totalHours) * chartHeight
                    let displayHour = clockHour(from: adjustedHour)

                    Text(formatHourLabel(displayHour))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .position(x: max(geometry.size.width - 10, 0), y: yPosition)
                }
            }
        }
        .frame(height: chartHeight)
    }

    private func formatHourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12AM" }
        else if hour < 12 { return "\(hour)AM" }
        else if hour == 12 { return "12PM" }
        else { return "\(hour - 12)PM" }
    }

    // MARK: - Helpers

    /// Compute grouped data (called once when data changes, result is cached)
    private func computeGroupedByDate() -> [(date: Date, sessions: [SleepSession])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: viewModel.sleepSessions) { session in
            calendar.startOfDay(for: session.date)
        }

        let sortedDates = grouped.keys.sorted()
        let today = calendar.startOfDay(for: Date())

        let pastBuffer = max(7, viewMode.visibleDays)
        let futureBuffer = viewMode == .month ? 3 : max(3, viewMode.visibleDays / 2)

        let startDate: Date
        let endDate: Date

        if let first = sortedDates.first, let last = sortedDates.last {
            let desiredStart = calendar.date(byAdding: .day, value: -pastBuffer, to: first) ?? first
            let desiredEndFromData = calendar.date(byAdding: .day, value: futureBuffer, to: last) ?? last
            let desiredEndFromToday = calendar.date(byAdding: .day, value: futureBuffer, to: today) ?? today
            startDate = desiredStart
            endDate = max(desiredEndFromData, desiredEndFromToday)
        } else {
            startDate = calendar.date(byAdding: .day, value: -viewMode.visibleDays, to: today) ?? today
            endDate = calendar.date(byAdding: .day, value: futureBuffer, to: today) ?? today
        }

        var groups: [(date: Date, sessions: [SleepSession])] = []
        var current = startDate

        while current <= endDate {
            groups.append((date: current, sessions: grouped[current] ?? []))
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return groups
    }

    private func shouldShowDayNumber(for date: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let daysFromToday = calendar.dateComponents([.day], from: date, to: today).day ?? 0
        return daysFromToday % 7 == 0
    }

    private func isBarSelected(groupDate: Date) -> Bool {
        guard let selectedBar = viewModel.selectedBar else { return false }
        let calendar = Calendar.current
        return calendar.isDate(selectedBar.sessionEnd, inSameDayAs: groupDate)
    }

    private func createSleepBar(from sessions: [SleepSession], date: Date) -> SleepBar? {
        guard !sessions.isEmpty else { return nil }

        // Combine all sessions for this date
        var totalDeep: TimeInterval = 0
        var totalCore: TimeInterval = 0
        var totalRem: TimeInterval = 0
        var totalAwake: TimeInterval = 0
        var totalAsleep: TimeInterval = 0
        var totalInBed: TimeInterval = 0
        var earliestStart: Date?
        var latestEnd: Date?

        for session in sessions {
            // Handle manual entries (no segments)
            if session.isManual, let manualEntry = session.manualEntry {
                // For manual entries, add all duration to asleep (not core)
                totalAsleep += manualEntry.sleepDuration

                if earliestStart == nil || manualEntry.bedtime < earliestStart! {
                    earliestStart = manualEntry.bedtime
                }
                if latestEnd == nil || manualEntry.waketime > latestEnd! {
                    latestEnd = manualEntry.waketime
                }
            } else if !session.segments.isEmpty {
                // Handle HealthKit data (segments)
                let durations = calculateStageDurations(for: session.segments)
                totalDeep += durations.deep
                totalCore += durations.core
                totalRem += durations.rem
                totalAwake += durations.awake
                totalAsleep += durations.asleep
                totalInBed += durations.inBed

                if earliestStart == nil || session.sessionStart < earliestStart! {
                    earliestStart = session.sessionStart
                }
                if latestEnd == nil || session.sessionEnd > latestEnd! {
                    latestEnd = session.sessionEnd
                }
            }
        }

        guard let start = earliestStart, let end = latestEnd else { return nil }

        return SleepBar(
            sleepDate: date,
            sessionStart: start,
            sessionEnd: end,
            isNap: false,
            deepDuration: totalDeep,
            coreDuration: totalCore,
            remDuration: totalRem,
            awakeDuration: totalAwake,
            asleepDuration: totalAsleep,
            inBedDuration: totalInBed
        )
    }

    private func calculateStageDurations(for segments: [SleepStageSegment]) -> (deep: TimeInterval, core: TimeInterval, rem: TimeInterval, awake: TimeInterval, asleep: TimeInterval, inBed: TimeInterval) {
        var deep: TimeInterval = 0
        var core: TimeInterval = 0
        var rem: TimeInterval = 0
        var awake: TimeInterval = 0
        var asleep: TimeInterval = 0
        var inBed: TimeInterval = 0

        for segment in segments {
            let duration = segment.endTime.timeIntervalSince(segment.startTime)
            switch segment.stage {
            case .deep: deep += duration
            case .core: core += duration
            case .rem: rem += duration
            case .awake: awake += duration
            case .asleep: asleep += duration  // Track basic sleep separately
            case .inBed: inBed += duration     // Track in bed time
            case .asleepSummary: break  // Don't count summary
            }
        }

        return (deep, core, rem, awake, asleep, inBed)
    }

    private func stageColor(_ stage: SleepStage) -> Color {
        // If a stage is selected, highlight matching segments, dim non-matching ones
        if let selected = selectedStage {
            if stage == selected {
                // Selected stage: normal color
                return getBaseStageColor(stage)
            } else {
                // Non-selected stage: moderately darker grey (like picker background)
                return Color(uiColor: .secondarySystemGroupedBackground)
            }
        }
        // No selection: normal color
        return getBaseStageColor(stage)
    }
    
    private func getBaseStageColor(_ stage: SleepStage) -> Color {
        // Use the standard colors from SleepStageData.swift
        // (These colors are used for both Day view hypnogram and Week/Month bar charts)
        return stage.color
    }

    private func formatDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        if viewMode == .week {
            formatter.dateFormat = "EEE"  // Mon, Tue, Wed
        } else {
            formatter.dateFormat = "M/d"
        }
        return formatter.string(from: date)
    }

    private func formatSelectedBarDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func formatDateRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let year = Calendar.current.component(.year, from: start)
        return "\(formatter.string(from: start)) - \(formatter.string(from: end)), \(year)"
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    private func calculateDailyAverages(for sessions: [SleepSession]) -> (timeInBed: TimeInterval, timeAsleep: TimeInterval) {
        guard !sessions.isEmpty else { return (0, 0) }

        let calendar = Calendar.current
        var dailyTotals: [Date: (timeInBed: TimeInterval, timeAsleep: TimeInterval)] = [:]

        for session in sessions {
            let day = calendar.startOfDay(for: session.date)

            let timeInBed = max(session.sessionEnd.timeIntervalSince(session.sessionStart), 0)
            let timeAsleep = session.segments
                .filter { $0.stage != .awake && $0.stage != .inBed }
                .reduce(0.0) { partial, segment in
                    partial + max(segment.endTime.timeIntervalSince(segment.startTime), 0)
                }

            if var existing = dailyTotals[day] {
                existing.timeInBed += timeInBed
                existing.timeAsleep += timeAsleep
                dailyTotals[day] = existing
            } else {
                dailyTotals[day] = (timeInBed, timeAsleep)
            }
        }

        guard !dailyTotals.isEmpty else { return (0, 0) }

        let dayCount = Double(dailyTotals.count)
        let totalInBed = dailyTotals.reduce(0.0) { $0 + $1.value.timeInBed }
        let totalAsleep = dailyTotals.reduce(0.0) { $0 + $1.value.timeAsleep }

        return (totalInBed / dayCount, totalAsleep / dayCount)
    }

    private func hasSleepData(_ session: SleepSession) -> Bool {
        guard session.sessionEnd > session.sessionStart else { return false }

        // Check if this is a manual entry (no segments but has manual data)
        if session.isManual {
            return true
        }

        // Check for meaningful HealthKit segments
        let meaningfulSegments = session.segments.contains { segment in
            segment.stage != .awake && segment.stage != .inBed && segment.endTime > segment.startTime
        }
        return meaningfulSegments
    }

    // MARK: - Summary Metrics

    private var summaryMetrics: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let selectedBar = viewModel.selectedBar {
                HStack(alignment: .top, spacing: 40) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TIME IN BED").font(.caption).foregroundColor(.secondary)
                        Text(viewModel.selectedBarTimeInBed).font(.title2).fontWeight(.semibold)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TIME ASLEEP").font(.caption).foregroundColor(.secondary)
                        Text(viewModel.selectedBarTimeAsleep).font(.title2).fontWeight(.semibold)
                    }

                    Spacer()

                    // Info button (top-aligned with metrics)
                    if let showAboutBinding = showAbout {
                        Button(action: {
                            withAnimation {
                                showAboutBinding.wrappedValue = true
                            }
                        }) {
                            Image(systemName: "info.circle")
                                .font(.title3)
                                .foregroundColor(Color(red: 0x6E / 255.0, green: 0x7C / 255.0, blue: 0xFF / 255.0))
                        }
                    }
                }
                Text(formatSelectedBarDate(selectedBar.sleepDate)).font(.subheadline).foregroundColor(.secondary)
            } else {
                HStack(alignment: .top, spacing: 40) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AVG. TIME IN BED").font(.caption).foregroundColor(.secondary)
                        Text(viewModel.totalTimeInBed).font(.title2).fontWeight(.semibold)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AVG. TIME ASLEEP").font(.caption).foregroundColor(.secondary)
                        Text(viewModel.totalTimeAsleep).font(.title2).fontWeight(.semibold)
                    }

                    Spacer()

                    // Info button (top-aligned with metrics)
                    if let showAboutBinding = showAbout {
                        Button(action: {
                            withAnimation {
                                showAboutBinding.wrappedValue = true
                            }
                        }) {
                            Image(systemName: "info.circle")
                                .font(.title3)
                                .foregroundColor(Color(red: 0x6E / 255.0, green: 0x7C / 255.0, blue: 0xFF / 255.0))
                        }
                    }
                }

                if let range = visibleDateRange {
                    Text(formatDateRange(range.start, range.end)).font(.subheadline).foregroundColor(.secondary)
                } else {
                    Text(viewModel.currentDateText).font(.subheadline).foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.deselectBar()
        }
    }
}

// MARK: - Weekly Sleep Data Manager (similar to InfiniteScrollChartManager)
@MainActor
class WeeklySleepDataManager: ObservableObject {
    @Published var chartWeekData: [(weekStartDate: Date, week: WeeklyAverage?)] = []
    @Published var isLoading = false
    @Published var isLoadingOlder = false
    @Published var isLoadingNewer = false
    
    private var oldestDate: Date
    private var newestDate: Date
    private let calendar = Calendar.current
    
    init() {
        let now = Date()
        // Follow MetricDetailView pattern: sixMonth uses 52 weeks (1 year) per chunk
        // Initial load: 52 weeks to match loadChunkSize
        let startWeek = calendar.date(byAdding: .weekOfYear, value: -52, to: now) ?? now
        var startComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startWeek)
        startComponents.weekday = 2 // Monday
        self.oldestDate = calendar.date(from: startComponents) ?? startWeek
        
        // Extend to next week for future scrolling (1 month ahead, but cap at reasonable future)
        let oneMonthAhead = calendar.date(byAdding: .month, value: 1, to: now) ?? now
        var endComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: oneMonthAhead)
        endComponents.weekday = 2 // Monday
        guard let futureWeekMonday = calendar.date(from: endComponents) else {
            self.newestDate = now
            return
        }
        self.newestDate = calendar.date(byAdding: .weekOfYear, value: 1, to: futureWeekMonday) ?? now
    }
    
    func generateInitialData() async {
        NSLog("[SLEEP] 📊 Generating initial data from \(oldestDate) to \(newestDate)")
        await generateDataRange(from: oldestDate, to: newestDate)
        NSLog("[SLEEP] ✅ Initial data loaded: \(chartWeekData.count) weeks in timeline")
    }
    
    func checkEdges(visibleWeek: WeeklyAverage) {
        // Check against the timeline (all weeks, not just those with data)
        guard let oldestTimeline = chartWeekData.first?.weekStartDate,
              let newestTimeline = chartWeekData.last?.weekStartDate else { return }
        
        let visibleDate = calendar.startOfDay(for: visibleWeek.weekStartDate)
        
        // Load older data when scrolled near beginning (within 3 weeks of oldest timeline date)
        let daysFromOldest = calendar.dateComponents([.day], from: oldestTimeline, to: visibleDate).day ?? 0
        if daysFromOldest >= 0 && daysFromOldest <= 21 && !isLoadingOlder { // 21 days = 3 weeks
            NSLog("[SLEEP] 📊 Loading older data - visible week is \(daysFromOldest) days from oldest (\(oldestTimeline))")
            Task { await loadOlderData() }
        }
        
        // Load newer data when scrolled near end (within 3 weeks of newest timeline date)
        // But only if we're not already too far in the future
        let now = Date()
        let twoMonthsAhead = calendar.date(byAdding: .month, value: 2, to: now) ?? now
        let daysFromNewest = calendar.dateComponents([.day], from: visibleDate, to: newestTimeline).day ?? 0
        if daysFromNewest >= 0 && daysFromNewest <= 21 && !isLoadingNewer && newestTimeline < twoMonthsAhead {
            NSLog("[SLEEP] 📊 Loading newer data - visible week is \(daysFromNewest) days from newest (\(newestTimeline))")
            Task { await loadNewerData() }
        } else if newestTimeline >= twoMonthsAhead {
            NSLog("[SLEEP] 📊 Skipping newer data load - already at 2 month future limit")
        }
    }
    
    func loadOlderData() async {
        guard !isLoadingOlder else {
            NSLog("[SLEEP] ⏭️ Skipping loadOlderData - already loading")
            return
        }
        isLoadingOlder = true
        
        // Follow MetricDetailView pattern: sixMonth loads 24 months (2 years) at a time
        // But we'll use 52 weeks (1 year) per chunk to match loadChunkSize
        let newOldestDate = calendar.date(byAdding: .weekOfYear, value: -52, to: oldestDate) ?? oldestDate
        
        // Don't go beyond 10 years total (like MetricDetailView)
        let tenYearsAgo = calendar.date(byAdding: .year, value: -10, to: Date()) ?? Date()
        let cappedOldestDate = max(newOldestDate, tenYearsAgo)
        
        if cappedOldestDate >= oldestDate {
            NSLog("[SLEEP] 📊 Reached 10 year limit, not loading older data")
            isLoadingOlder = false
            return
        }
        
        NSLog("[SLEEP] 📊 Loading older data from \(cappedOldestDate) to \(oldestDate) (52 weeks)")
        await generateDataRange(from: cappedOldestDate, to: oldestDate)
        
        oldestDate = cappedOldestDate
        isLoadingOlder = false
        NSLog("[SLEEP] ✅ Finished loading older data. New oldest date: \(oldestDate)")
    }
    
    func loadNewerData() async {
        guard !isLoadingNewer else {
            NSLog("[SLEEP] ⏭️ Skipping loadNewerData - already loading")
            return
        }
        
        // Don't load future data beyond 2 months ahead
        let now = Date()
        let twoMonthsAhead = calendar.date(byAdding: .month, value: 2, to: now) ?? now
        if newestDate >= twoMonthsAhead {
            NSLog("[SLEEP] 📊 Already loaded enough future data (newestDate: \(newestDate) >= 2 months ahead)")
            return
        }
        
        isLoadingNewer = true
        
        // Load 52 weeks (1 year) per chunk, but cap at 2 months ahead
        let proposedNewestDate = calendar.date(byAdding: .weekOfYear, value: 52, to: newestDate) ?? newestDate
        let cappedNewestDate = min(proposedNewestDate, twoMonthsAhead)
        
        if cappedNewestDate <= newestDate {
            NSLog("[SLEEP] 📊 Already at future data limit, not loading more")
            isLoadingNewer = false
            return
        }
        
        NSLog("[SLEEP] 📊 Loading newer data from \(newestDate) to \(cappedNewestDate) (52 weeks, capped at 2 months)")
        await generateDataRange(from: newestDate, to: cappedNewestDate)
        
        newestDate = cappedNewestDate
        isLoadingNewer = false
        NSLog("[SLEEP] ✅ Finished loading newer data. New newest date: \(newestDate)")
    }
    
    private func generateDataRange(from startDate: Date, to endDate: Date) async {
        isLoading = true
        
        NSLog("[SLEEP] 📊 generateDataRange: from \(startDate) to \(endDate)")
        
        // Skip if date range is invalid (same or reversed dates)
        if startDate >= endDate {
            NSLog("[SLEEP] ⚠️ Skipping generateDataRange - invalid date range")
            isLoading = false
            return
        }
        
        // Generate empty timeline
        var timeline = generateEmptyTimeline(from: startDate, to: endDate)
        NSLog("[SLEEP] 📅 Generated \(timeline.count) timeline weeks")
        
        // Fetch actual data (fetch ALL data, don't filter by date range here)
        let dataPoints = await fetchWeeklyData()
        NSLog("[SLEEP] 📊 Fetched \(dataPoints.count) weekly data points")
        
        // Overlay data on timeline - match by week granularity (like MetricDetailView)
        var matchedCount = 0
        for dataPoint in dataPoints {
            // Find matching week in timeline using weekOfYear granularity
            if let index = timeline.firstIndex(where: {
                calendar.isDate($0.weekStartDate, equalTo: dataPoint.weekStartDate, toGranularity: .weekOfYear)
            }) {
                timeline[index] = (weekStartDate: dataPoint.weekStartDate, week: dataPoint.week)
                matchedCount += 1
            }
        }
        NSLog("[SLEEP] ✅ Matched \(matchedCount) data points to timeline")
        
        // Merge with existing data
        let existingCount = chartWeekData.count
        if chartWeekData.isEmpty {
            chartWeekData = timeline
            NSLog("[SLEEP] 📊 Initial load: set \(timeline.count) weeks")
        } else if let firstExisting = chartWeekData.first, let lastNew = timeline.last,
                  lastNew.weekStartDate < firstExisting.weekStartDate {
            // Loading older data - prepend
            chartWeekData = timeline + chartWeekData
            NSLog("[SLEEP] 📊 Prepended older data: \(timeline.count) weeks. Total: \(chartWeekData.count) weeks")
        } else if let lastExisting = chartWeekData.last, let firstNew = timeline.first,
                  firstNew.weekStartDate > lastExisting.weekStartDate {
            // Loading newer data - append
            chartWeekData = chartWeekData + timeline
            NSLog("[SLEEP] 📊 Appended newer data: \(timeline.count) weeks. Total: \(chartWeekData.count) weeks")
        } else {
            // Overlapping or initial load - replace
            chartWeekData = timeline
            NSLog("[SLEEP] 📊 Replaced data: \(timeline.count) weeks (overlapping or initial)")
        }
        
        isLoading = false
        NSLog("[SLEEP] ✅ generateDataRange complete: \(chartWeekData.count) total weeks (\(existingCount) → \(chartWeekData.count))")
    }
    
    private func generateEmptyTimeline(from startDate: Date, to endDate: Date) -> [(weekStartDate: Date, week: WeeklyAverage?)] {
        var timeline: [(weekStartDate: Date, week: WeeklyAverage?)] = []
        var currentWeek = startDate
        
        // Ensure we start on a Monday
        var startComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: currentWeek)
        startComponents.weekday = 2 // Monday
        currentWeek = calendar.date(from: startComponents) ?? currentWeek
        
        while currentWeek <= endDate {
            timeline.append((weekStartDate: calendar.startOfDay(for: currentWeek), week: nil))
            
            guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeek) else { break }
            currentWeek = nextWeek
        }
        
        return timeline
    }
    
    private func fetchWeeklyData() async -> [(weekStartDate: Date, week: WeeklyAverage)] {
        do {
            // Fetch daily sleep summaries from patient_sleep_sessions_summary
            // Go back 2 years to have enough data for infinite scroll
            let twoYearsAgo = calendar.date(byAdding: .year, value: -2, to: Date()) ?? Date()
            let oneMonthAhead = calendar.date(byAdding: .month, value: 1, to: Date()) ?? Date()

            let dailySummaries = try await PatientSamplesQueryService.shared.fetchSleepSessionSummaries(
                startDate: twoYearsAgo,
                endDate: oneMonthAhead
            )

            NSLog("[SLEEP] 📊 Fetched \(dailySummaries.count) daily sleep summaries from patient_sleep_sessions_summary")

            guard !dailySummaries.isEmpty else {
                NSLog("[SLEEP] ⚠️ No daily sleep summaries found")
                return []
            }

            // Group daily summaries by week (Monday start)
            var weeklyGroups: [Date: [SleepSessionSummaryRow]] = [:]

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            for summary in dailySummaries {
                guard let sleepDate = dateFormatter.date(from: summary.sleepDate) else { continue }

                // Find Monday of this week
                var weekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: sleepDate)
                weekComponents.weekday = 2 // Monday
                guard let weekStart = calendar.date(from: weekComponents) else { continue }

                let normalizedWeekStart = calendar.startOfDay(for: weekStart)
                weeklyGroups[normalizedWeekStart, default: []].append(summary)
            }

            NSLog("[SLEEP] 📊 Grouped into \(weeklyGroups.count) weeks")

            // Calculate weekly averages
            var averages: [(weekStartDate: Date, week: WeeklyAverage)] = []

            for (weekStart, dailyData) in weeklyGroups {
                guard !dailyData.isEmpty else { continue }

                // Calculate average bedtime/waketime from daily data
                var totalBedtimeMinutes: Double = 0
                var totalWaketimeMinutes: Double = 0
                var validDays = 0

                for day in dailyData {
                    // Extract hour:minute from bedtime/waketime timestamps
                    let bedtimeComponents = calendar.dateComponents([.hour, .minute], from: day.bedtime)
                    let waketimeComponents = calendar.dateComponents([.hour, .minute], from: day.waketime)

                    guard let bedHour = bedtimeComponents.hour,
                          let bedMin = bedtimeComponents.minute,
                          let wakeHour = waketimeComponents.hour,
                          let wakeMin = waketimeComponents.minute else { continue }

                    // Convert to minutes from midnight for averaging
                    // Handle overnight: bedtime after 6PM gets adjusted
                    let bedtimeMinutes: Double
                    if bedHour >= 18 {
                        bedtimeMinutes = Double((bedHour - 24) * 60 + bedMin) // Negative for PM times
                    } else {
                        bedtimeMinutes = Double(bedHour * 60 + bedMin)
                    }

                    let waketimeMinutes = Double(wakeHour * 60 + wakeMin)

                    totalBedtimeMinutes += bedtimeMinutes
                    totalWaketimeMinutes += waketimeMinutes
                    validDays += 1
                }

                guard validDays > 0 else { continue }

                let avgBedtimeMinutes = totalBedtimeMinutes / Double(validDays)
                let avgWaketimeMinutes = totalWaketimeMinutes / Double(validDays)

                // Convert back to Date objects
                let avgBedHour: Int
                let avgBedMin: Int
                if avgBedtimeMinutes < 0 {
                    // Negative means PM the night before
                    let adjustedMinutes = avgBedtimeMinutes + 24 * 60
                    avgBedHour = Int(adjustedMinutes) / 60
                    avgBedMin = Int(adjustedMinutes) % 60
                } else {
                    avgBedHour = Int(avgBedtimeMinutes) / 60
                    avgBedMin = Int(avgBedtimeMinutes) % 60
                }

                let avgWakeHour = Int(avgWaketimeMinutes) / 60
                let avgWakeMin = Int(avgWaketimeMinutes) % 60

                let avgBedtime = calendar.date(bySettingHour: avgBedHour, minute: avgBedMin, second: 0, of: Date()) ?? Date()
                let avgWaketime = calendar.date(bySettingHour: avgWakeHour, minute: avgWakeMin, second: 0, of: Date()) ?? Date()

                let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart

                averages.append((
                    weekStartDate: weekStart,
                    week: WeeklyAverage(
                        weekStartDate: weekStart,
                        weekEndDate: weekEnd,
                        avgTimeInBed: 0,
                        avgTimeAsleep: 0,
                        avgBedtime: avgBedtime,
                        avgWaketime: avgWaketime
                    )
                ))
            }

            NSLog("[SLEEP] ✅ Processed \(averages.count) weekly averages from patient_sleep_sessions_summary")
            return averages

        } catch {
            NSLog("[SLEEP] ❌ Error fetching weekly data: \(error)")
            return []
        }
    }
    
}

// MARK: - 6M View (Weekly Aggregations)
