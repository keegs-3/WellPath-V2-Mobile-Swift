//
//  DayViewChart.swift
//  WellPath
//
//  Pageable single-day hypnogram view with infinite scroll loading.
//  Displays detailed sleep stage transitions for individual nights.
//

import SwiftUI
import Charts

struct DayViewChart: View {
    let color: Color
    @ObservedObject var viewModel: SleepAnalysisViewModel
    @Binding var selectedStage: SleepStage?
    @State private var selectedSegment: SleepStageSegment?
    @State private var currentSessionIndex: Int = 0
    @State private var hasInitializedIndex: Bool = false // Track if we've set initial index
    var height: CGFloat = 300 // Default height, can be overridden
    var onVisibleRangeChange: ((Date, Date) -> Void)? = nil
    var showAbout: Binding<Bool>? = nil  // Optional binding for about view

    init(color: Color, viewModel: SleepAnalysisViewModel, selectedStage: Binding<SleepStage?> = .constant(nil), onVisibleRangeChange: ((Date, Date) -> Void)? = nil, height: CGFloat = 300, showAbout: Binding<Bool>? = nil) {
        self.color = color
        self.viewModel = viewModel
        self._selectedStage = selectedStage
        self.onVisibleRangeChange = onVisibleRangeChange
        self.height = height
        self.showAbout = showAbout
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryMetrics
            if viewModel.sleepSessions.isEmpty {
                Text("No sleep data available")
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .foregroundColor(.secondary)
            } else {
                sessionPager
            }
        }
        .onChange(of: currentSessionIndex) { oldValue, newValue in
            // Update metrics when session changes
            if newValue >= 0 && newValue < viewModel.sleepSessions.count {
                let session = viewModel.sleepSessions[newValue]
                if session.isManual {
                    // Manual entry - calculate from manual entry data
                    viewModel.calculateMetricsForManualEntry(session.manualEntry!)
                } else if session.segments.isEmpty {
                    // No data for this date
                    viewModel.updateMetricsForNoData(date: session.date)
                } else {
                    // Has data - calculate normally
                    viewModel.calculateSummaryMetrics(for: session.segments)
                }

                // Notify parent of visible date range (for stage totals calculation)
                let calendar = Calendar.current
                let dayStart = calendar.startOfDay(for: session.date)
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
                onVisibleRangeChange?(dayStart, dayEnd)
            }
            // Load more data at edges
            checkIfNeedToLoadMore(sessionIndex: newValue)
        }
        .onAppear {
            // Only set initial index once, not every time view appears
            // This prevents snapping back to today when user is scrolling
            if !hasInitializedIndex && !viewModel.sleepSessions.isEmpty {
                hasInitializedIndex = true
                currentSessionIndex = 0
                if let firstSession = viewModel.sleepSessions.first {
                    if firstSession.isManual {
                        viewModel.calculateMetricsForManualEntry(firstSession.manualEntry!)
                    } else if firstSession.segments.isEmpty {
                        viewModel.updateMetricsForNoData(date: firstSession.date)
                    } else {
                        viewModel.calculateSummaryMetrics(for: firstSession.segments)
                    }

                    // Notify parent of initial visible date range (for stage totals calculation)
                    let calendar = Calendar.current
                    let dayStart = calendar.startOfDay(for: firstSession.date)
                    let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
                    onVisibleRangeChange?(dayStart, dayEnd)
                }
            }
        }
    }
    // MARK: - Summary Metrics
    private var summaryMetrics: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let selected = selectedSegment {
                selectedSegmentSummary(selected)
            } else {
                overallSummary
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    private var overallSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 40) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TIME IN BED")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.totalTimeInBed)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("TIME ASLEEP")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.totalTimeAsleep)
                        .font(.title2)
                        .fontWeight(.semibold)
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
                            .foregroundColor(color)
                    }
                }
            }
            Text(viewModel.currentDateText)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    private func selectedSegmentSummary(_ segment: SleepStageSegment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(segment.stage.rawValue.uppercased())
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                let hours = Int(segment.endTime.timeIntervalSince(segment.startTime) / 3600)
                let minutes = (Int(segment.endTime.timeIntervalSince(segment.startTime)) % 3600) / 60
                Text("\(hours)")
                    .font(.system(size: 28, weight: .semibold))
                Text("hr")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                Text("\(minutes)")
                    .font(.system(size: 28, weight: .semibold))
                Text("min")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            Text(formatDetailedTimeRange(segment.startTime, segment.endTime))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    private func formatDetailedTimeRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        let startStr = formatter.string(from: start)
        formatter.dateFormat = "h:mm a"
        let endStr = formatter.string(from: end)
        return "\(startStr) - \(endStr)"
    }
    // MARK: - Session Pager
    private var sessionPager: some View {
        TabView(selection: $currentSessionIndex) {
            ForEach(Array(viewModel.sleepSessions.enumerated()), id: \.element.id) { index, session in
                HypnogramView(
                    session: session,
                    selectedSegment: $selectedSegment,
                    selectedStage: selectedStage,
                    height: height
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: height + 40) // Add 40px for padding/controls
        .environment(\.layoutDirection, .rightToLeft) // Most recent on right
    }
    private func checkIfNeedToLoadMore(sessionIndex: Int) {
        // Load older data when near the beginning (left side)
        if sessionIndex <= 1 {
            Task {
                await viewModel.loadEarlierSleepStages()
            }
        }
        // Load newer data when near the end (right side)
        if sessionIndex >= viewModel.sleepSessions.count - 2 {
            Task {
                await viewModel.loadLaterSleepStages()
            }
        }
    }
}
// MARK: - Hypnogram View (Canvas-based with bars)
struct HypnogramView: View {
    let session: SleepSession
    @Binding var selectedSegment: SleepStageSegment?
    var selectedStage: SleepStage? = nil
    var height: CGFloat = 300 // Default height, can be overridden
    // Filter to only show sleep stages (exclude In Bed to avoid double-counting)
    // Include asleep for basic sessions
    private var displaySegments: [SleepStageSegment] {
        session.segments.filter { segment in
            segment.stage != .inBed
        }
    }

    // Asleep Summary segments - merged sleep periods (shows gaps for awake)
    private var asleepSummarySegments: [SleepStageSegment] {
        // Get all actual sleep segments (not awake, not in_bed)
        let sleepSegments = displaySegments.filter { segment in
            segment.stage == .rem ||
            segment.stage == .core ||
            segment.stage == .deep ||
            segment.stage == .asleep
        }.sorted { $0.startTime < $1.startTime }

        guard !sleepSegments.isEmpty else { return [] }

        // Merge contiguous segments into unified "asleep" periods
        var merged: [SleepStageSegment] = []
        var currentStart = sleepSegments[0].startTime
        var currentEnd = sleepSegments[0].endTime
        let userTimezone = sleepSegments[0].userTimezone // Use timezone from source segments

        for i in 1..<sleepSegments.count {
            let segment = sleepSegments[i]

            // If this segment is contiguous (no gap), extend current period
            if segment.startTime <= currentEnd {
                currentEnd = max(currentEnd, segment.endTime)
            } else {
                // Gap found - save current period and start new one
                merged.append(SleepStageSegment(
                    stage: .asleepSummary,
                    startTime: currentStart,
                    endTime: currentEnd,
                    userTimezone: userTimezone
                ))
                currentStart = segment.startTime
                currentEnd = segment.endTime
            }
        }

        // Add final period
        merged.append(SleepStageSegment(
            stage: .asleepSummary,
            startTime: currentStart,
            endTime: currentEnd,
            userTimezone: userTimezone
        ))

        return merged
    }

    // Y-axis order: Asleep Summary at top, then Awake, REM, Core, Deep
    private let orderedSleepStages: [SleepStage] = [.asleepSummary, .awake, .rem, .core, .deep]
    
    private func getSegmentColor(for segment: SleepStageSegment) -> Color {
        // If a stage is selected, highlight matching segments, dim non-matching ones
        if let selected = selectedStage {
            if segment.stage == selected {
                return segment.stage.color
            } else {
                // Non-selected segments: moderately darker grey (like picker background)
                return Color(uiColor: .secondarySystemGroupedBackground)
            }
        }
        // No selection: normal color
        return segment.stage.color
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if session.isManual && displaySegments.isEmpty {
                // Manual entry ONLY - show simple two-color bar
                manualEntryView
            } else if displaySegments.isEmpty {
                // No data view
                ZStack {
                    // Empty chart with axes
                    Chart {
                        // Invisible placeholder to establish chart domain
                        ForEach(orderedSleepStages, id: \.self) { stage in
                            PointMark(
                                x: .value("Time", session.sessionStart),
                                y: .value("Stage", stage)
                            )
                            .opacity(0)
                        }
                    }
                    .chartYScale(domain: orderedSleepStages)
                    .chartXScale(domain: sessionTimeRange)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .hour, count: 3)) { value in
                            AxisGridLine()
                                .foregroundStyle(Color.gray.opacity(0.2))
                            AxisValueLabel(format: .dateTime.hour())
                                .font(.caption2)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: orderedSleepStages) { value in
                            AxisGridLine()
                                .foregroundStyle(Color.gray.opacity(0.2))
                            if let stage = value.as(SleepStage.self) {
                                AxisValueLabel {
                                    Text(stage.rawValue)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .frame(height: height)
                    // No data message
                    Text("No sleep data recorded")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            } else {
                // Data exists - show normal chart
            ZStack {
                // Base chart with bars and axes
                Chart {
                    // ASLEEP SUMMARY BAR - Segments with gaps for awake periods
                    ForEach(asleepSummarySegments) { segment in
                        RectangleMark(
                            xStart: .value("Start", segment.startTime),
                            xEnd: .value("End", segment.endTime),
                            y: .value("Stage", SleepStage.asleepSummary),
                            height: .ratio(0.5)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(hex: "80CBC4") ?? .teal, // Sleep pillar color
                                    Color(hex: "60ABA4") ?? .teal  // Darker variant
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8)
                        .opacity(0.95)
                    }

                    // Solid bars for each segment (existing stages)
                    ForEach(displaySegments) { segment in
                        RectangleMark(
                            xStart: .value("Start", segment.startTime),
                            xEnd: .value("End", segment.endTime),
                            y: .value("Stage", segment.stage),
                            height: .ratio(0.7)
                        )
                        .foregroundStyle(
                            // Use gradient for basic asleep (match Asleep Summary bar), solid color for detailed stages
                            segment.stage == .asleep ?
                                LinearGradient(
                                    colors: [
                                        Color(hex: "80CBC4") ?? .teal,  // Sleep pillar color (light teal)
                                        Color(hex: "60ABA4") ?? .teal   // Darker teal variant
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ) :
                                LinearGradient(
                                    colors: [getSegmentColor(for: segment), getSegmentColor(for: segment)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                        )
                        .opacity(1.0)
                        .cornerRadius(6)
                        .shadow(color: getSegmentColor(for: segment).opacity(0.4), radius: 5, x: 0, y: 0)
                    }

                    // Add manual entry gradient bar if present (spans REM/Core/Deep)
                    if let manualEntry = session.manualEntry {
                        // REM bar with gradient
                        RectangleMark(
                            xStart: .value("Start", manualEntry.bedtime),
                            xEnd: .value("End", manualEntry.waketime),
                            y: .value("Stage", SleepStage.rem),
                            height: .ratio(0.6)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [SleepStage.rem.color, SleepStage.core.color],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .opacity(0.7)

                        // Core bar with gradient
                        RectangleMark(
                            xStart: .value("Start", manualEntry.bedtime),
                            xEnd: .value("End", manualEntry.waketime),
                            y: .value("Stage", SleepStage.core),
                            height: .ratio(0.6)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [SleepStage.core.color, SleepStage.deep.color],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .opacity(0.7)

                        // Deep bar
                        RectangleMark(
                            xStart: .value("Start", manualEntry.bedtime),
                            xEnd: .value("End", manualEntry.waketime),
                            y: .value("Stage", SleepStage.deep),
                            height: .ratio(0.6)
                        )
                        .foregroundStyle(SleepStage.deep.color)
                        .opacity(0.7)
                    }
                }
                .chartYScale(domain: orderedSleepStages)
                .chartXScale(domain: sessionTimeRange)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 3)) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.gray.opacity(0.2))
                        AxisValueLabel(format: .dateTime.hour())
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: orderedSleepStages) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.gray.opacity(0.2))
                        if let stage = value.as(SleepStage.self) {
                            AxisValueLabel {
                                Text(stage.rawValue)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        ZStack {
                            // Hypnogram line overlay (gradient across stages)
                            Canvas { context, size in
                                drawHypnogramWithGradient(context: context, size: size, proxy: proxy)
                            }
                            // Tap gesture overlay
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .onTapGesture { location in
                                    handleTap(at: location, proxy: proxy, geometry: geometry)
                                }
                        }
                    }
                }
                .frame(height: height)
                .padding(.horizontal)
            }
            }
        }
        .environment(\.layoutDirection, .leftToRight) // Keep chart itself left-to-right
    }
    // MARK: - Hypnogram Line Drawing with Gradient
    private func drawHypnogramWithGradient(context: GraphicsContext, size: CGSize, proxy: ChartProxy) {
        guard !displaySegments.isEmpty else { return }
        // Get Y positions for each sleep stage to properly align gradient
        guard let awakeY = proxy.position(forY: SleepStage.awake),
              let deepY = proxy.position(forY: SleepStage.deep) else { return }
        
        // Determine if we should use highlighting
        let useHighlighting = selectedStage != nil
        let dimmedColor = Color(uiColor: .secondarySystemGroupedBackground)
        
        // Create gradient that transitions through all sleep stage colors (top to bottom)
        // If highlighting, use dimmed color for gradient
        let gradient = Gradient(stops: [
            .init(color: useHighlighting ? dimmedColor : SleepStage.awake.color, location: 0.0),   // Awake at top
            .init(color: useHighlighting ? dimmedColor : SleepStage.rem.color, location: 0.33),     // REM
            .init(color: useHighlighting ? dimmedColor : SleepStage.core.color, location: 0.66),    // Core
            .init(color: useHighlighting ? dimmedColor : SleepStage.deep.color, location: 1.0)      // Deep at bottom
        ])
        // Set opacity for glow effect
        var transparentContext = context
        transparentContext.opacity = 0.25
        // Threshold for gap detection (2 hours = 7200 seconds) - don't connect separate sessions
        let gapThreshold: TimeInterval = 7200
        // Draw each segment with gradient
        for (index, segment) in displaySegments.enumerated() {
            // Determine color for this segment
            let segmentColor: Color
            if useHighlighting {
                if segment.stage == selectedStage {
                    // Selected stage: use normal color
                    segmentColor = segment.stage.color
                } else {
                    // Non-selected: use dimmed color
                    segmentColor = dimmedColor
                }
            } else {
                // No selection: use normal gradient
                segmentColor = segment.stage.color
            }
            guard let startX: CGFloat = proxy.position(forX: segment.startTime),
                  let endX: CGFloat = proxy.position(forX: segment.endTime),
                  let yPos: CGFloat = proxy.position(forY: segment.stage) else {
                continue
            }
            // Create path for this segment
            var segmentPath = Path()
            // Vertical connector from previous segment (if exists and no gap > 2 hours)
            if index > 0,
               let prevSegment = displaySegments[safe: index - 1],
               let prevEndX: CGFloat = proxy.position(forX: prevSegment.endTime),
               let prevYPos: CGFloat = proxy.position(forY: prevSegment.stage) {
                // Check for gap - if gap > 2 hours, don't connect (separate sessions)
                let gap = segment.startTime.timeIntervalSince(prevSegment.endTime)
                if gap <= gapThreshold {
                    segmentPath.move(to: CGPoint(x: prevEndX, y: prevYPos + 5))
                    segmentPath.addLine(to: CGPoint(x: startX, y: yPos + 5))
                } else {
                    // Gap > 2 hours - start new path (don't connect separate sessions)
                    segmentPath.move(to: CGPoint(x: startX, y: yPos + 5))
                }
            } else {
                segmentPath.move(to: CGPoint(x: startX, y: yPos + 5))
            }
            // Horizontal line for this segment
            segmentPath.addLine(to: CGPoint(x: endX, y: yPos + 5))
            
            // Use segment-specific color if highlighting, otherwise use gradient
            // GraphicsContext.stroke() expects GraphicsContext.Shading, not AnyShapeStyle
            if useHighlighting {
                // Use solid color for this segment
                // Draw glow effect first (wider, more transparent)
                transparentContext.stroke(
                    segmentPath,
                    with: .color(segmentColor),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                )
                // Draw main line on top (narrower, still transparent)
                var mainContext = context
                mainContext.opacity = 0.5
                mainContext.stroke(
                    segmentPath,
                    with: .color(segmentColor),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
            } else {
                // Use gradient - GraphicsContext.Shading.linearGradient expects CGPoint (absolute coordinates)
                let startPoint = CGPoint(x: 0, y: awakeY)
                let endPoint = CGPoint(x: 0, y: deepY)
                
                // Draw glow effect first (wider, more transparent)
                transparentContext.stroke(
                    segmentPath,
                    with: .linearGradient(
                        gradient,
                        startPoint: startPoint,
                        endPoint: endPoint
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                )
                // Draw main line on top (narrower, still transparent)
                var mainContext = context
                mainContext.opacity = 0.5
                mainContext.stroke(
                    segmentPath,
                    with: .linearGradient(
                        gradient,
                        startPoint: startPoint,
                        endPoint: endPoint
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
            }
        }
        // Highlight selected segment
        if let selected = selectedSegment,
           let startX: CGFloat = proxy.position(forX: selected.startTime),
           let endX: CGFloat = proxy.position(forX: selected.endTime),
           let yPos: CGFloat = proxy.position(forY: selected.stage) {
            var highlightPath = Path()
            highlightPath.move(to: CGPoint(x: startX, y: yPos + 5))
            highlightPath.addLine(to: CGPoint(x: endX, y: yPos + 5))
            
            // GraphicsContext.Shading.linearGradient expects CGPoint (absolute coordinates)
            let startPoint = CGPoint(x: 0, y: awakeY)
            let endPoint = CGPoint(x: 0, y: deepY)
            
            // Extra glow for selected segment
            var glowContext = context
            glowContext.opacity = 0.5
            glowContext.stroke(
                highlightPath,
                with: .linearGradient(
                    gradient,
                    startPoint: startPoint,
                    endPoint: endPoint
                ),
                style: StrokeStyle(lineWidth: 8, lineCap: .round)
            )
            // Main highlight line
            context.stroke(
                highlightPath,
                with: .linearGradient(
                    gradient,
                    startPoint: startPoint,
                    endPoint: endPoint
                ),
                style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )
        }
    }

    // MARK: - Manual Entry View
    private var manualEntryView: some View {
        guard let manual = session.manualEntry else {
            return AnyView(Text("Error: No manual entry data"))
        }

        // Add 1-hour buffer on each end like HealthKit charts
        let bufferSeconds: TimeInterval = 3600 // 1 hour
        let chartStart = manual.bedtime.addingTimeInterval(-bufferSeconds)
        let chartEnd = manual.waketime.addingTimeInterval(bufferSeconds)

        return AnyView(
            VStack(spacing: 0) {
                // Two solid bars: "in bed" (background) and "asleep" (foreground)
                Chart {
                    // Time in bed bar (background) - slightly larger to show behind asleep
                    RectangleMark(
                        xStart: .value("Start", manual.bedtime),
                        xEnd: .value("End", manual.waketime),
                        y: .value("Type", "Asleep"),
                        height: .fixed(48)
                    )
                    .foregroundStyle(Color.gray.opacity(0.5))
                    .cornerRadius(6)

                    // Time asleep bar (foreground) - overlaid on time in bed
                    RectangleMark(
                        xStart: .value("Start", manual.bedtime),
                        xEnd: .value("End", manual.waketime),
                        y: .value("Type", "Asleep"),
                        height: .fixed(40)
                    )
                    .foregroundStyle(Color.blue)
                    .cornerRadius(6)
                }
                .chartYScale(domain: ["Asleep"])
                .chartXScale(domain: chartStart...chartEnd)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 2)) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.gray.opacity(0.2))
                        AxisValueLabel(format: .dateTime.hour())
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: ["Asleep"]) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.gray.opacity(0.2))
                        AxisValueLabel {
                            Text("Asleep")
                                .font(.caption)
                        }
                    }
                }
                .frame(height: height)
                .padding(.horizontal)
            }
            .environment(\.layoutDirection, .leftToRight)
        )
    }

    // MARK: - Helper Functions
    private var sessionTimeRange: ClosedRange<Date> {
        // If no data, default to 8PM to 8AM window
        guard !session.segments.isEmpty else {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let start = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: today) ?? today
            let end = calendar.date(byAdding: .hour, value: 12, to: start) ?? start.addingTimeInterval(12 * 3600)
            return start...end
        }
        
        // Find the EARLIEST start time and LATEST end time across ALL segments
        let startTimes = session.segments.map { $0.startTime }
        let endTimes = session.segments.map { $0.endTime }
        
        guard let earliestStart = startTimes.min(),
              let latestEnd = endTimes.max() else {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let start = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: today) ?? today
            let end = calendar.date(byAdding: .hour, value: 12, to: start) ?? start.addingTimeInterval(12 * 3600)
            return start...end
        }
        
        // Full session window with buffers: (start - 10%) â†’ (end + 20%)
        let totalDuration = latestEnd.timeIntervalSince(earliestStart)
        let bufferedStart = earliestStart.addingTimeInterval(-totalDuration * 0.1)
        let bufferedEnd = latestEnd.addingTimeInterval(totalDuration * 0.2)
        return bufferedStart...bufferedEnd
    }
    private func handleTap(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let xPosition = location.x - geometry[plotFrame].origin.x
        if let date: Date = proxy.value(atX: xPosition) {
            let tappedSegment = displaySegments.first { segment in
                date >= segment.startTime && date <= segment.endTime
            }
            if tappedSegment?.id == selectedSegment?.id {
                selectedSegment = nil
            } else {
                selectedSegment = tappedSegment
            }
        }
    }
}
// Safe array subscript extension
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

