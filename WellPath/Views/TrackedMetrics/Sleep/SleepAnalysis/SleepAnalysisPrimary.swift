import SwiftUI
import Supabase
import Charts

// Preference keys for scroll tracking
struct SleepScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct SleepScrollContentSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct SleepAnalysisPrimary: View {
    let pillar: String
    let color: Color
    @StateObject private var chartViewModel = SleepAnalysisViewModel()
    @StateObject private var primaryViewModel = SleepAnalysisPrimaryViewModel(metricId: "DISP_SLEEP_ANALYSIS")
    @State private var selectedPeriod: SleepPeriod = .day
    @State private var selectedView: PrimaryView = .chart
    @State private var showingDetailView = false

    enum PrimaryView: String, CaseIterable {
        case chart = "Chart"
        case about = "About"
    }

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Sleep Analysis")
    }
    enum SleepPeriod: String, CaseIterable {
        case day = "D"
        case week = "W"
        case month = "M"
        case sixMonth = "6M"
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
            .navigationTitle("Sleep Analysis")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingDetailView) {
                NavigationStack {
                    SleepDetailView()
                }
            }
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
            // Period selector
            Picker("Period", selection: $selectedPeriod) {
                ForEach(SleepPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .onChange(of: selectedPeriod) { oldValue, newValue in
                Task {
                    switch newValue {
                    case .day:
                        // Day view: 7 days back, 0 ahead (edge detection loads more)
                        await chartViewModel.loadInitialSleepStages(daysBack: 7, daysAhead: 0)
                    case .week:
                        // Week view: 14 days back, 7 ahead
                        await chartViewModel.loadInitialSleepStages(daysBack: 14, daysAhead: 7)
                    case .month:
                        // Month view: 60 days back, 30 ahead
                        await chartViewModel.loadInitialSleepStages(daysBack: 60, daysAhead: 30)
                    default:
                        // 6 Month and Year views coming soon
                        break
                    }
                }
            }
            // Chart content based on period
            if chartViewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading sleep data...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 300)
            } else {
                switch selectedPeriod {
                case .day:
                    DayViewChart(color: color, viewModel: chartViewModel, selectedStage: .constant(nil))
                case .week:
                    ScrollableSleepChart(viewMode: .week, viewModel: chartViewModel, selectedStage: .constant(nil))
                case .month:
                    ScrollableSleepChart(viewMode: .month, viewModel: chartViewModel, selectedStage: .constant(nil))
                case .sixMonth:
                    WeeklySleepChart(viewModel: chartViewModel, selectedStage: .constant(nil))
                }
            }

            // View More Sleep Data button
            Button(action: {
                showingDetailView = true
            }) {
                Text("View More Sleep Data")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .task {
            // Initial load defaults to day view range (7 days)
            await chartViewModel.loadInitialSleepStages(daysBack: 7, daysAhead: 0)
            // Also load About content
            await primaryViewModel.loadPrimaryScreen()
        }
    }

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
                .padding()
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    if let about = primaryViewModel.aboutContent {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(color)
                                Text("About Sleep Analysis")
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

// MARK: - Day View with Session Paging
struct DayViewChart: View {
    let color: Color
    @ObservedObject var viewModel: SleepAnalysisViewModel
    @Binding var selectedStage: SleepStage?
    @State private var selectedSegment: SleepStageSegment?
    @State private var currentSessionIndex: Int = 0
    @State private var hasInitializedIndex: Bool = false // Track if we've set initial index
    var height: CGFloat = 300 // Default height, can be overridden
    var onVisibleRangeChange: ((Date, Date) -> Void)? = nil

    init(color: Color, viewModel: SleepAnalysisViewModel, selectedStage: Binding<SleepStage?> = .constant(nil), onVisibleRangeChange: ((Date, Date) -> Void)? = nil, height: CGFloat = 300) {
        self.color = color
        self.viewModel = viewModel
        self._selectedStage = selectedStage
        self.onVisibleRangeChange = onVisibleRangeChange
        self.height = height
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

                // Don't notify parent during scroll - causes snap-back issues
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

                    // Don't notify parent - causes recalculation and snap-back issues
                    // Parent loads static totals for today instead
                }
            }
        }
    }
    // MARK: - Summary Metrics
    private var summaryMetrics: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let selected = selectedSegment {
                selectedSegmentSummary(selected)
            } else {
                overallSummary
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    private var overallSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 40) {
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
    // Filter to only show sleep stages (exclude In Bed and Asleep Unspecified)
    private var displaySegments: [SleepStageSegment] {
        session.segments.filter { segment in
            segment.stage != .inBed && segment.stage != .asleepUnspecified
        }
    }
    // Y-axis order: Awake at top, Deep at bottom
    private let orderedSleepStages: [SleepStage] = [.awake, .rem, .core, .deep]
    
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
                    // Solid bars for each segment
                    ForEach(displaySegments) { segment in
                        RectangleMark(
                            xStart: .value("Start", segment.startTime),
                            xEnd: .value("End", segment.endTime),
                            y: .value("Stage", segment.stage),
                            height: .ratio(0.7)
                        )
                        .foregroundStyle(getSegmentColor(for: segment))
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
                    segmentPath.move(to: CGPoint(x: prevEndX, y: prevYPos))
                    segmentPath.addLine(to: CGPoint(x: startX, y: yPos))
                } else {
                    // Gap > 2 hours - start new path (don't connect separate sessions)
                    segmentPath.move(to: CGPoint(x: startX, y: yPos))
                }
            } else {
                segmentPath.move(to: CGPoint(x: startX, y: yPos))
            }
            // Horizontal line for this segment
            segmentPath.addLine(to: CGPoint(x: endX, y: yPos))
            
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
            highlightPath.move(to: CGPoint(x: startX, y: yPos))
            highlightPath.addLine(to: CGPoint(x: endX, y: yPos))
            
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

    init(viewMode: ViewMode, viewModel: SleepAnalysisViewModel, selectedStage: Binding<SleepStage?>, visibleRangeBinding: Binding<(start: Date, end: Date)?>? = nil, height: CGFloat = 340, onVisibleRangeChange: ((Date, Date) -> Void)? = nil) {
        self.viewMode = viewMode
        self.viewModel = viewModel
        self._selectedStage = selectedStage
        self._visibleRangeBinding = visibleRangeBinding ?? .constant(nil)
        self.height = height
        self.onVisibleRangeChange = onVisibleRangeChange
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
            let timeRange = calculateTimeRange()

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
                    ForEach(groupedByDate(), id: \.date) { group in
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
            let groups = groupedByDate()
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
        guard Date().timeIntervalSince(lastScrollUpdate) > 0.2 else { return }
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

                let period = viewMode == .week ? "daily" : "daily"
                if let avg = await viewModel.fetchAveragesFromCache(startDate: leadingDate, endDate: endDate, periodType: period, calculationType: "SUM"), avg.timeInBed > 0 || avg.timeAsleep > 0 {
                    await MainActor.run {
                        if visibleDateRange?.start == leadingDate {
                            viewModel.totalTimeInBed = formatDuration(avg.timeInBed * 60)
                            viewModel.totalTimeAsleep = formatDuration(avg.timeAsleep * 60)
                            viewModel.currentDateText = formatDateRange(leadingDate, endDate)
                        }
                    }
                } else {
                    await MainActor.run {
                        if visibleDateRange?.start == leadingDate {
                            viewModel.totalTimeInBed = formatDuration(fallbackTimeInBed)
                            viewModel.totalTimeAsleep = formatDuration(fallbackTimeAsleep)
                            viewModel.currentDateText = formatDateRange(leadingDate, endDate)
                        }
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

            for segment in session.segments.sorted(by: { $0.startTime < $1.startTime }) {
                guard segment.stage != .inBed && segment.stage != .asleepUnspecified else { continue }

                let segmentStart = adjustedHour(from: segment.startTime)
                let segmentEnd = adjustedHour(from: segment.endTime)
                let segmentDuration = segmentEnd - segmentStart

                let yPosition = ((segmentStart - timeRange.startHour) / timeRange.totalHours) * size.height
                let height = max((segmentDuration / timeRange.totalHours) * size.height, 1.0)

                let segmentWidth = segment.stage == .awake ? barWidth * 1.1 : barWidth
                let segmentXOffset = barXOffset - (segmentWidth - barWidth) / 2

                let rect = CGRect(x: segmentXOffset, y: yPosition, width: segmentWidth, height: height)
                var segmentContext = context
                if isSelected { segmentContext.opacity = 1.0 }
                segmentContext.fill(Path(rect), with: .color(stageColor(segment.stage)))
            }
        }
    }

    // MARK: - Time Calculations

    private func calculateTimeRange() -> ChartTimeRange {
        // Get only sessions in the visible date range
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
            let sessionStart = adjustedHour(from: session.sessionStart)
            let sessionEnd = adjustedHour(from: session.sessionEnd)

            if let currentStart = earliestStart {
                earliestStart = min(currentStart, sessionStart)
            } else {
                earliestStart = sessionStart
            }

            if let currentEnd = latestEnd {
                latestEnd = max(currentEnd, sessionEnd)
            } else {
                latestEnd = sessionEnd
            }
        }

        guard let minStart = earliestStart, let maxEnd = latestEnd else {
            return defaultTimeRange
        }

        let startBuffer: Double = 1.0
        let endBuffer: Double = 1.0

        let bufferedStart = max(minStart - startBuffer, 0)
        let bufferedEnd = min(maxEnd + endBuffer, 24)
        let totalHours = bufferedEnd - bufferedStart

        guard totalHours >= 1 else { return defaultTimeRange }

        return (bufferedStart, bufferedEnd, totalHours)
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
        var labels: [Double] = []
        let interval: Double = 3

        labels.append(timeRange.startHour)

        var currentHour = (floor(timeRange.startHour / interval) + 1) * interval

        while currentHour < timeRange.endHour {
            labels.append(currentHour)
            currentHour += interval
        }

        if let last = labels.last, abs(last - timeRange.endHour) > 0.01 {
            labels.append(timeRange.endHour)
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

    private func groupedByDate() -> [(date: Date, sessions: [SleepSession])] {
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
        guard let session = sessions.first else { return nil }

        // Handle manual entries (no segments)
        if session.isManual, let manualEntry = session.manualEntry {
            // For manual entries, put all duration in coreDuration (blue color)
            return SleepBar(
                sleepDate: session.date,
                sessionStart: manualEntry.bedtime,
                sessionEnd: manualEntry.waketime,
                isNap: false,
                deepDuration: 0,
                coreDuration: manualEntry.sleepDuration,
                remDuration: 0,
                awakeDuration: 0
            )
        }

        // Handle HealthKit data (segments)
        guard !session.segments.isEmpty else { return nil }

        let durations = calculateStageDurations(for: session.segments)

        return SleepBar(
            sleepDate: session.date,
            sessionStart: session.sessionStart,
            sessionEnd: session.sessionEnd,
            isNap: false,
            deepDuration: durations.deep,
            coreDuration: durations.core,
            remDuration: durations.rem,
            awakeDuration: durations.awake
        )
    }

    private func calculateStageDurations(for segments: [SleepStageSegment]) -> (deep: TimeInterval, core: TimeInterval, rem: TimeInterval, awake: TimeInterval) {
        var deep: TimeInterval = 0
        var core: TimeInterval = 0
        var rem: TimeInterval = 0
        var awake: TimeInterval = 0

        for segment in segments {
            let duration = segment.endTime.timeIntervalSince(segment.startTime)
            switch segment.stage {
            case .deep: deep += duration
            case .core: core += duration
            case .rem: rem += duration
            case .awake: awake += duration
            default: break
            }
        }

        return (deep, core, rem, awake)
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
        switch stage {
        case .deep: return Color(red: 0.0, green: 0.4, blue: 0.8)
        case .core: return Color(red: 0.3, green: 0.6, blue: 1.0)
        case .rem: return Color(red: 0.6, green: 0.8, blue: 1.0)
        case .awake: return Color.red.opacity(0.7)
        case .inBed: return Color.gray.opacity(0.3)
        case .asleepUnspecified: return Color.blue.opacity(0.3)
        }
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
        VStack(alignment: .leading, spacing: 12) {
            if let selectedBar = viewModel.selectedBar {
                HStack(spacing: 40) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TIME IN BED").font(.caption).foregroundColor(.secondary)
                        Text(viewModel.selectedBarTimeInBed).font(.title2).fontWeight(.semibold)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TIME ASLEEP").font(.caption).foregroundColor(.secondary)
                        Text(viewModel.selectedBarTimeAsleep).font(.title2).fontWeight(.semibold)
                    }
                }
                Text(formatSelectedBarDate(selectedBar.sleepDate)).font(.subheadline).foregroundColor(.secondary)
            } else {
                HStack(spacing: 40) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AVG. TIME IN BED").font(.caption).foregroundColor(.secondary)
                        Text(viewModel.totalTimeInBed).font(.title2).fontWeight(.semibold)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AVG. TIME ASLEEP").font(.caption).foregroundColor(.secondary)
                        Text(viewModel.totalTimeAsleep).font(.title2).fontWeight(.semibold)
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
        .padding(.top, 16)
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
    private let supabase = SupabaseManager.shared.client
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
            guard let userId = try? await supabase.auth.session.user.id else {
                NSLog("[SLEEP] ⚠️ No user session available")
                return []
            }
            
            struct WeeklyCacheEntry: Codable {
                let aggMetricId: String
                let periodStart: Date
                let periodEnd: Date
                let valueTime: String?
                
                enum CodingKeys: String, CodingKey {
                    case aggMetricId = "agg_metric_id"
                    case periodStart = "period_start"
                    case periodEnd = "period_end"
                    case valueTime = "value_time"
                }
            }
            
            // Fetch ALL weekly data (no date filters for infinite scroll)
            // Note: value_time is absolute (e.g., "23:00:00" = 11 PM always, no timezone conversion needed)
            let cacheResults: [WeeklyCacheEntry] = try await supabase
                .from("aggregation_results_cache")
                .select("agg_metric_id, period_start, period_end, value_time")
                .eq("patient_id", value: userId)
                .in("agg_metric_id", values: ["AGG_SLEEP_BEDTIME", "AGG_SLEEP_WAKETIME"])
                .eq("period_type", value: "weekly")
                .eq("calculation_type_id", value: "AVG")
                .order("period_start", ascending: true)
                .execute()
                .value
            
            NSLog("[SLEEP] 📊 Fetched \(cacheResults.count) weekly cache entries")
            
            // Group by week start date (period_start is already the Monday of the week)
            // Use periodStart directly like MetricDetailView does
            let groupedByWeek = Dictionary(grouping: cacheResults) { entry -> Date in
                entry.periodStart
            }
            
            var averages: [(weekStartDate: Date, week: WeeklyAverage)] = []
            
            for (weekStart, entries) in groupedByWeek {
                let bedtimeEntries = entries.filter { $0.aggMetricId == "AGG_SLEEP_BEDTIME" }
                let waketimeEntries = entries.filter { $0.aggMetricId == "AGG_SLEEP_WAKETIME" }
                
                guard bedtimeEntries.count == 1, waketimeEntries.count == 1,
                      let bedtimeEntry = bedtimeEntries.first,
                      let waketimeEntry = waketimeEntries.first,
                      let bedtimeTime = bedtimeEntry.valueTime, !bedtimeTime.isEmpty,
                      let waketimeTime = waketimeEntry.valueTime, !waketimeTime.isEmpty else {
                    continue
                }
                
                // Calculate week end like MetricDetailView: period_start + 6 days
                // (period_start is Monday, so +6 days = Sunday)
                let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
                
                NSLog("[SLEEP] 📅 fetchWeeklyData: Week - period_start: \(weekStart), calculated weekEnd: \(weekEnd) (weekStart + 6 days)")
                
                // Parse time strings - value_time is absolute (e.g., "23:00:00" = 11 PM always)
                let bedtime = parseTimeString(bedtimeTime)
                let waketime = parseTimeString(waketimeTime)
                
                NSLog("[SLEEP] 📅 fetchWeeklyData: Times - bedtime: '\(bedtimeTime)' → \(bedtime), waketime: '\(waketimeTime)' → \(waketime)")
                
                // Use dates directly - no timezone conversion needed
                let localWeekStart = weekStart
                let localWeekEnd = weekEnd
                
                averages.append((
                    weekStartDate: localWeekStart,
                    week: WeeklyAverage(
                        weekStartDate: localWeekStart,
                        weekEndDate: localWeekEnd,
                        avgTimeInBed: 0,
                        avgTimeAsleep: 0,
                        avgBedtime: bedtime,
                        avgWaketime: waketime
                    )
                ))
                
                NSLog("[SLEEP] 📅 fetchWeeklyData: Added week - \(localWeekStart) to \(localWeekEnd)")
            }
            
            NSLog("[SLEEP] ✅ Processed \(averages.count) weekly averages")
            return averages
            
        } catch {
            NSLog("[SLEEP] ❌ Error fetching weekly data: \(error)")
            return []
        }
    }
    
    private func parseTimeString(_ timeString: String) -> Date {
        let calendar = Calendar.current
        let components = timeString.split(separator: ":")
        
        guard components.count >= 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            // Default to 8 PM
            return calendar.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
        }
        
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
}

// MARK: - 6M View (Weekly Aggregations)
struct WeeklySleepChart: View {
    @ObservedObject var viewModel: SleepAnalysisViewModel
    @Binding var selectedStage: SleepStage?
    @Binding var visibleRangeBinding: (start: Date, end: Date)?
    @StateObject private var dataManager = WeeklySleepDataManager()
    @State private var scrollPosition: Date
    @State private var selectedWeek: WeeklyAverage?
    @State private var hasInitializedScroll = false  // Track if we've set initial scroll position
    var height: CGFloat = 340 // Default total height
    var onVisibleRangeChange: ((Date, Date) -> Void)? = nil

    init(viewModel: SleepAnalysisViewModel, selectedStage: Binding<SleepStage?> = .constant(nil), visibleRangeBinding: Binding<(start: Date, end: Date)?>? = nil, height: CGFloat = 340, onVisibleRangeChange: ((Date, Date) -> Void)? = nil) {
        self.viewModel = viewModel
        self._selectedStage = selectedStage
        self._visibleRangeBinding = visibleRangeBinding ?? .constant(nil)
        self.height = height
        self.onVisibleRangeChange = onVisibleRangeChange
        // Initialize scroll position to today (will be adjusted in onAppear)
        _scrollPosition = State(initialValue: Date())
    }

    private let barColor = Color(red: 0x6E / 255.0, green: 0x7C / 255.0, blue: 0xFF / 255.0)
    
    // Chart data model for BarMark
    private struct ChartWeekData: Identifiable {
        let id: UUID
        let weekStartDate: Date
        let week: WeeklyAverage?
        let chartBedtime: Date // Bedtime adjusted for 6 PM to 6 PM day span
        let chartWaketime: Date // Waketime adjusted for 6 PM to 6 PM day span
        
        init(weekStartDate: Date, week: WeeklyAverage?, referenceDate: Date) {
            self.id = UUID()
            self.weekStartDate = weekStartDate
            self.week = week
            
            let calendar = Calendar.current
            
            if let week = week {
                // Extract hour and minute from actual bedtime/waketime
                let bedtimeComponents = calendar.dateComponents([.hour, .minute], from: week.avgBedtime)
                let waketimeComponents = calendar.dateComponents([.hour, .minute], from: week.avgWaketime)
                
                let bedtimeHour = bedtimeComponents.hour ?? 20
                let bedtimeMinute = bedtimeComponents.minute ?? 0
                let waketimeHour = waketimeComponents.hour ?? 8
                let waketimeMinute = waketimeComponents.minute ?? 0
                
                // Calculate minutes from 6 PM (0 = 6 PM, 1440 = next day 6 PM)
                let bedtimeMinutes: Int
                let waketimeMinutes: Int
                
                if bedtimeHour >= 18 {
                    bedtimeMinutes = (bedtimeHour - 18) * 60 + bedtimeMinute
                } else {
                    bedtimeMinutes = (24 - 18 + bedtimeHour) * 60 + bedtimeMinute
                }
                
                if waketimeHour >= 18 {
                    waketimeMinutes = (waketimeHour - 18) * 60 + waketimeMinute
                } else {
                    waketimeMinutes = (24 - 18 + waketimeHour) * 60 + waketimeMinute
                }
                
                // Map times directly to 6 PM to 6 PM sleep day using Date objects
                // Use reference date at 6 PM, then ADD minutes to create Date values
                guard let sixPMReference = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: referenceDate) else {
                    self.chartBedtime = referenceDate
                    self.chartWaketime = referenceDate
                    return
                }
                
                // Use DIRECT offsets representing actual times from 6 PM
                // 6 PM = 0, 11 PM = 300 min, 7 AM = 780 min, 6 PM next = 1440 min
                let bedtimeOffset = bedtimeMinutes  // 11 PM = 300 min
                let waketimeOffset = waketimeMinutes  // 7 AM = 780 min

                if let bedtimeFinal = calendar.date(byAdding: .minute, value: bedtimeOffset, to: sixPMReference),
                   let waketimeFinal = calendar.date(byAdding: .minute, value: waketimeOffset, to: sixPMReference) {
                    self.chartBedtime = bedtimeFinal  // 11 PM (actual time)
                    self.chartWaketime = waketimeFinal  // 7 AM next day (actual time)
                } else {
                    // Fallback: use direct minutes
                    if let bedtimeDate = calendar.date(byAdding: .minute, value: bedtimeMinutes, to: sixPMReference),
                       let waketimeDate = calendar.date(byAdding: .minute, value: waketimeMinutes, to: sixPMReference) {
                        self.chartBedtime = bedtimeDate
                        self.chartWaketime = waketimeDate
                    } else {
                        self.chartBedtime = sixPMReference
                        self.chartWaketime = sixPMReference
                    }
                }
            } else {
                // Default data: 8 PM to 8 AM
                // 8 PM = 120 min, 8 AM = 840 min
                guard let sixPMReference = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: referenceDate) else {
                    self.chartBedtime = referenceDate
                    self.chartWaketime = referenceDate
                    return
                }
                
                let maxMinutes = 24 * 60
                let bedtimeOffset = maxMinutes - 120  // 8 PM: larger offset = larger Date (top)
                let waketimeOffset = maxMinutes - 840  // 8 AM: smaller offset = smaller Date (bottom)
                
                if let bedtimeDate = calendar.date(byAdding: .minute, value: bedtimeOffset, to: sixPMReference),
                   let waketimeDate = calendar.date(byAdding: .minute, value: waketimeOffset, to: sixPMReference) {
                    self.chartBedtime = bedtimeDate
                    self.chartWaketime = waketimeDate
                } else {
                    self.chartBedtime = sixPMReference
                    self.chartWaketime = sixPMReference
                }
            }
        }
    }
    
    // Generate chart data - continuous 26-week range from data manager
    // Sort by date: oldest (left) to newest (right) - like MetricDetailView
    private var chartData: [ChartWeekData] {
        let calendar = Calendar.current
        let referenceDate = calendar.startOfDay(for: Date())
        
        // Use data manager's timeline and sort oldest to newest (left to right)
        let result = dataManager.chartWeekData
            .map { weekGroup in
                ChartWeekData(weekStartDate: weekGroup.weekStartDate, week: weekGroup.week, referenceDate: referenceDate)
            }
            .sorted { $0.weekStartDate < $1.weekStartDate }
        
        NSLog("[SLEEP] 📊 chartData: Generated \(result.count) weeks (dataManager has \(dataManager.chartWeekData.count) weeks)")
        let weeksWithData = result.filter { $0.week != nil }
        NSLog("[SLEEP] 📊 chartData: \(weeksWithData.count) weeks have data")
        
        return result
    }
    
    // Y-axis domain: Dynamic range based on data
    // Default: 8PM to 8AM (120 to 840 minutes from 6PM)
    // Can flex to 6PM-6PM (0 to 1440 minutes) based on data range
    // Uses inverted mapping: date = sixPMReference + (maxMinutes - actualMinutes)
    private var yAxisDomain: ClosedRange<Date> {
        NSLog("[SLEEP] 📊 Y-axis domain calculation started")
        let calendar = Calendar.current
        // Use a fixed reference date (today) - all times will be relative to this
        let referenceDate = calendar.startOfDay(for: Date())
        guard let sixPMReference = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: referenceDate) else {
            NSLog("[SLEEP] ⚠️ Failed to create sixPMReference")
            let fallback = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
            return fallback...fallback
        }
        
        NSLog("[SLEEP] 📊 Y-axis: sixPMReference = \(sixPMReference) (referenceDate: \(referenceDate))")
        
        let maxMinutes = 24 * 60
        
        // Get visible weeks based on scroll position (like MetricDetailView)
        let visibleWeeks = getVisibleWeeks()
        let weeksWithData = visibleWeeks.compactMap { $0.week }
        NSLog("[SLEEP] 📊 Y-axis: Found \(weeksWithData.count) weeks with data out of \(visibleWeeks.count) visible weeks")
        
        // Initialize with extremes so any data will update them
        // Default range: 8PM to 8AM (120 to 840 minutes from 6PM)
        var earliestBedtimeMinutes: Int? = nil  // Will find minimum from data
        var latestWaketimeMinutes: Int? = nil   // Will find maximum from data
        
        if !weeksWithData.isEmpty {
            // Calculate actual range from data
            for week in weeksWithData {
                let bedtimeComponents = calendar.dateComponents([.hour, .minute], from: week.avgBedtime)
                let waketimeComponents = calendar.dateComponents([.hour, .minute], from: week.avgWaketime)
                
                guard let bedtimeHour = bedtimeComponents.hour,
                      let bedtimeMinute = bedtimeComponents.minute,
                      let waketimeHour = waketimeComponents.hour,
                      let waketimeMinute = waketimeComponents.minute else {
                    continue
                }
                
                // Calculate minutes from 6PM
                let bedtimeMinutes: Int
                let waketimeMinutes: Int
                
                if bedtimeHour >= 18 {
                    bedtimeMinutes = (bedtimeHour - 18) * 60 + bedtimeMinute
                } else {
                    bedtimeMinutes = (24 - 18 + bedtimeHour) * 60 + bedtimeMinute
                }
                
                if waketimeHour >= 18 {
                    waketimeMinutes = (waketimeHour - 18) * 60 + waketimeMinute
                } else {
                    waketimeMinutes = (24 - 18 + waketimeHour) * 60 + waketimeMinute
                }
                
                // Track earliest bedtime (smallest value) and latest waketime (largest value)
                if earliestBedtimeMinutes == nil || bedtimeMinutes < earliestBedtimeMinutes! {
                    earliestBedtimeMinutes = bedtimeMinutes
                }
                if latestWaketimeMinutes == nil || waketimeMinutes > latestWaketimeMinutes! {
                    latestWaketimeMinutes = waketimeMinutes
                }
                NSLog("[SLEEP] 📊 Y-axis: Week data - bedtime: \(bedtimeHour):\(String(format: "%02d", bedtimeMinute)) (\(bedtimeMinutes) min), waketime: \(waketimeHour):\(String(format: "%02d", waketimeMinute)) (\(waketimeMinutes) min)")
            }
            
            NSLog("[SLEEP] 📊 Y-axis: Before buffer - earliest bedtime: \(earliestBedtimeMinutes ?? -1) min, latest waketime: \(latestWaketimeMinutes ?? -1) min")
            
            // Add 1 hour (60 minutes) buffer on each end
            if let earliest = earliestBedtimeMinutes {
                earliestBedtimeMinutes = max(0, earliest - 60)  // Can go to 6PM (0)
            }
            if let latest = latestWaketimeMinutes {
                latestWaketimeMinutes = min(maxMinutes, latest + 60)  // Can go to next 6PM (1440)
            }
            
            NSLog("[SLEEP] 📊 Y-axis: After buffer - earliest bedtime: \(earliestBedtimeMinutes ?? -1) min, latest waketime: \(latestWaketimeMinutes ?? -1) min")
        }
        
        // Use calculated range if data exists, otherwise use default 8PM-8AM
        let finalBedtimeMinutes = earliestBedtimeMinutes ?? 120  // Default to 8PM if no data
        let finalWaketimeMinutes = latestWaketimeMinutes ?? 840   // Default to 8AM if no data
        
        NSLog("[SLEEP] 📊 Y-axis: Final minutes - bedtime: \(finalBedtimeMinutes) min, waketime: \(finalWaketimeMinutes) min")
        
        // Map times to Date objects using DIRECT offsets
        // This creates actual times: 6 PM + 300 min = 11 PM, 6 PM + 780 min = 7 AM next day
        let bedtimeOffset = finalBedtimeMinutes  // 11 PM (actual time from 6 PM)
        let waketimeOffset = finalWaketimeMinutes  // 7 AM next day (actual time from 6 PM)
        
        NSLog("[SLEEP] 📊 Y-axis: Calculated offsets - bedtimeOffset: \(bedtimeOffset) min (1440 - \(finalBedtimeMinutes)), waketimeOffset: \(waketimeOffset) min (1440 - \(finalWaketimeMinutes))")
        
        // Note: bedtimeTimeAsDate and waketimeTimeAsDate are calculated but not used directly
        // The domain is calculated from minutes offsets below
        
        // Log the actual times represented
        let bedtimeHour = (finalBedtimeMinutes / 60 + 18) % 24
        let bedtimeMin = finalBedtimeMinutes % 60
        let waketimeHour = (finalWaketimeMinutes / 60 + 18) % 24
        let waketimeMin = finalWaketimeMinutes % 60
        NSLog("[SLEEP] 📊 Y-axis: Domain represents times - bedtime: \(String(format: "%02d:%02d", bedtimeHour, bedtimeMin)) (\(finalBedtimeMinutes) min), waketime: \(String(format: "%02d:%02d", waketimeHour, waketimeMin)) (\(finalWaketimeMinutes) min)")
        
        // Create domain based on data range, or default to 8 PM - 8 AM if no data
        let domainStartMinutes: Int
        let domainEndMinutes: Int

        if weeksWithData.isEmpty {
            // No data: default to 8 PM (120 min) to 8 AM (840 min)
            domainStartMinutes = 120   // 8 PM
            domainEndMinutes = 840     // 8 AM
        } else {
            // Use actual data range (already has buffer added)
            domainStartMinutes = finalBedtimeMinutes  // Earliest bedtime
            domainEndMinutes = finalWaketimeMinutes    // Latest waketime
        }

        guard let domainStart = calendar.date(byAdding: .minute, value: domainStartMinutes, to: sixPMReference),
              let domainEnd = calendar.date(byAdding: .minute, value: domainEndMinutes, to: sixPMReference) else {
            NSLog("[SLEEP] ⚠️ Y-axis: Failed to create domain dates")
            return sixPMReference...sixPMReference
        }

        // Domain: earliest bedtime to latest waketime (adjusted to data)
        let startHour = (domainStartMinutes / 60 + 18) % 24
        let endHour = (domainEndMinutes / 60 + 18) % 24
        NSLog("[SLEEP] ✅ Y-axis: Domain set - [\(domainStart) (\(startHour):00) ... \(domainEnd) (\(endHour):00)]")
        return domainStart...domainEnd
    }
    

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryMetrics

            if dataManager.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
            } else if chartData.isEmpty {
                Text("No weekly data available")
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .foregroundColor(.secondary)
            } else {
                chartView
            }
        }
        .onAppear {
            Task {
                await dataManager.generateInitialData()
            }
        }
    }

    // Calculate average bedtime and waketime from visible weeks with data (like MetricDetailView's calculateAggregate)
    private func calculateVisibleWeeklyAverages() -> (bedtime: Date, waketime: Date)? {
        NSLog("[SLEEP] 📊 calculateVisibleWeeklyAverages: Starting calculation")
        // Get visible weeks based on scroll position (like MetricDetailView's getVisibleData)
        let visibleWeeks = getVisibleWeeks().compactMap { $0.week }
        NSLog("[SLEEP] 📊 calculateVisibleWeeklyAverages: Found \(visibleWeeks.count) weeks with data")
        guard !visibleWeeks.isEmpty else {
            NSLog("[SLEEP] ⚠️ calculateVisibleWeeklyAverages: No visible weeks with data, returning nil")
            return nil  // Return nil to indicate "No Data"
        }
        
        // Calculate average by averaging the time components
        let calendar = Calendar.current
        var totalBedtimeSeconds: TimeInterval = 0
        var totalWaketimeSeconds: TimeInterval = 0
        var count = 0
        
        for week in visibleWeeks {
            let bedtimeComponents = calendar.dateComponents([.hour, .minute, .second], from: week.avgBedtime)
            let waketimeComponents = calendar.dateComponents([.hour, .minute, .second], from: week.avgWaketime)
            
            if let bedtimeHour = bedtimeComponents.hour, let bedtimeMinute = bedtimeComponents.minute,
               let waketimeHour = waketimeComponents.hour, let waketimeMinute = waketimeComponents.minute {
                totalBedtimeSeconds += Double(bedtimeHour * 3600 + bedtimeMinute * 60)
                totalWaketimeSeconds += Double(waketimeHour * 3600 + waketimeMinute * 60)
                count += 1
            }
        }
        
        guard count > 0 else {
            NSLog("[SLEEP] ⚠️ calculateVisibleWeeklyAverages: count is 0 after processing, returning nil")
            return nil  // Return nil to indicate "No Data"
        }
        
        let avgBedtimeSeconds = totalBedtimeSeconds / Double(count)
        let avgWaketimeSeconds = totalWaketimeSeconds / Double(count)
        
        let bedtimeHour = Int(avgBedtimeSeconds) / 3600
        let bedtimeMinute = (Int(avgBedtimeSeconds) % 3600) / 60
        let waketimeHour = Int(avgWaketimeSeconds) / 3600
        let waketimeMinute = (Int(avgWaketimeSeconds) % 3600) / 60
        
        let avgBedtime = calendar.date(bySettingHour: bedtimeHour, minute: bedtimeMinute, second: 0, of: Date()) ?? Date()
        let avgWaketime = calendar.date(bySettingHour: waketimeHour, minute: waketimeMinute, second: 0, of: Date()) ?? Date()
        
        NSLog("[SLEEP] ✅ calculateVisibleWeeklyAverages: Result - bedtime: \(bedtimeHour):\(String(format: "%02d", bedtimeMinute)), waketime: \(waketimeHour):\(String(format: "%02d", waketimeMinute)) (from \(count) weeks)")
        return (avgBedtime, avgWaketime)
    }
    
    private var summaryMetrics: some View {
        let averages = selectedWeek == nil ? calculateVisibleWeeklyAverages() : nil
        
        if let selected = selectedWeek {
            NSLog("[SLEEP] 📊 summaryMetrics: Showing selected week data - \(formatTime(selected.avgBedtime)) to \(formatTime(selected.avgWaketime))")
        } else if let avg = averages {
            NSLog("[SLEEP] 📊 summaryMetrics: Showing visible range average - \(formatTime(avg.bedtime)) to \(formatTime(avg.waketime))")
        } else {
            NSLog("[SLEEP] ⚠️ summaryMetrics: No selected week and no averages available")
        }
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 40) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Avg Bedtime").font(.caption).foregroundColor(.secondary)
                    if let week = selectedWeek {
                        Text(formatTime(week.avgBedtime))
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
                    if let week = selectedWeek {
                        Text(formatTime(week.avgWaketime))
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
            if let week = selectedWeek {
                Text(formatWeekRange(week.weekStartDate, week.weekEndDate))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text(visibleDateRangeString())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    // Get visible weeks based on scroll position (like MetricDetailView's getVisibleData)
    private func getVisibleWeeks() -> [ChartWeekData] {
        NSLog("[SLEEP] 📊 getVisibleWeeks: chartData count = \(chartData.count), scrollPosition = \(scrollPosition)")
        guard !chartData.isEmpty else {
            NSLog("[SLEEP] ⚠️ getVisibleWeeks: chartData is empty")
            return []
        }
        
        let calendar = Calendar.current
        let visibleDomainLength: TimeInterval = 26 * 7 * 24 * 60 * 60 // 26 weeks in seconds
        
        // scrollPosition is the LEFT/START edge of the visible domain (like MetricDetailView)
        guard let endDate = calendar.date(byAdding: .second, value: Int(visibleDomainLength), to: scrollPosition) else {
            NSLog("[SLEEP] ⚠️ getVisibleWeeks: Failed to calculate endDate, using fallback")
            // Fallback to most recent weeks
            let count = min(26, chartData.count)
            let startIndex = max(0, chartData.count - count)
            let fallback = Array(chartData[startIndex..<chartData.count])
            NSLog("[SLEEP] 📊 getVisibleWeeks: Fallback - returning \(fallback.count) weeks")
            return fallback
        }
        
        NSLog("[SLEEP] 📊 getVisibleWeeks: Visible window from \(scrollPosition) to \(endDate) (26 weeks = \(visibleDomainLength) seconds)")
        
        // Get first and last week dates for logging
        if let firstWeek = chartData.first, let lastWeek = chartData.last {
            NSLog("[SLEEP] 📊 getVisibleWeeks: chartData range - first: \(firstWeek.weekStartDate), last: \(lastWeek.weekStartDate)")
        }
        
        // Filter weeks that fall within the visible window (from scrollPosition to endDate)
        // A week is visible if its start date falls within [scrollPosition, endDate]
        // Use <= for endDate to match MetricDetailView's behavior
        let visibleWeeks = chartData.filter { weekData in
            weekData.weekStartDate >= scrollPosition && weekData.weekStartDate <= endDate
        }
        
        NSLog("[SLEEP] 📊 getVisibleWeeks: Found \(visibleWeeks.count) weeks in visible window")
        if let firstVisible = visibleWeeks.first, let lastVisible = visibleWeeks.last {
            NSLog("[SLEEP] 📊 getVisibleWeeks: Visible range - first: \(firstVisible.weekStartDate), last: \(lastVisible.weekStartDate)")
        }
        
        if visibleWeeks.isEmpty {
            let fallback = Array(chartData.prefix(26))
            NSLog("[SLEEP] ⚠️ getVisibleWeeks: No visible weeks, using fallback - returning \(fallback.count) weeks")
            return fallback
        }
        
        return visibleWeeks
    }
    
    // Generate dynamic date range string based on visible weeks (like MetricDetailView)
    private func visibleDateRangeString() -> String {
        NSLog("[SLEEP] 📅 visibleDateRangeString: Calculating date range")
        let visibleWeeks = getVisibleWeeks()
        guard !visibleWeeks.isEmpty else {
            NSLog("[SLEEP] ⚠️ visibleDateRangeString: No visible weeks")
            return ""
        }

        let dates = visibleWeeks.map { $0.weekStartDate }
        guard let firstDate = dates.min(),
              let lastDate = dates.max() else {
            NSLog("[SLEEP] ⚠️ visibleDateRangeString: Failed to get min/max dates")
            return ""
        }

        // Calculate week end for last week (Monday + 6 days = Sunday)
        // Use UTC calendar since weekStartDate is in UTC
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let lastWeekEnd = utcCalendar.date(byAdding: .day, value: 6, to: lastDate) ?? lastDate

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.timeZone = TimeZone(identifier: "UTC")! // Format in UTC to match database dates
        let year = utcCalendar.component(.year, from: lastWeekEnd)
        let result = "\(formatter.string(from: firstDate)) - \(formatter.string(from: lastWeekEnd)), \(year)"
        NSLog("[SLEEP] 📅 visibleDateRangeString: Result = '\(result)' (from \(firstDate) to \(lastWeekEnd) in UTC)")
        return result
    }
    
    private func formatWeeklyDateRange() -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Calculate Monday of the week that is 26 weeks ago
        var startComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        startComponents.weekOfYear = (startComponents.weekOfYear ?? 0) - 26
        startComponents.weekday = 2 // Monday
        guard let startWeekMonday = calendar.date(from: startComponents) else {
            return ""
        }
        
        // Calculate Sunday of the current week (the 26th week)
        // Get the current week's Monday using yearForWeekOfYear, then add 6 days to get Sunday
        var currentWeekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        currentWeekComponents.weekday = 2 // Monday
        guard let currentWeekMonday = calendar.date(from: currentWeekComponents) else {
            return ""
        }
        guard let currentWeekSunday = calendar.date(byAdding: .day, value: 6, to: currentWeekMonday) else {
            return ""
        }
        
        // Use local dates directly (no UTC normalization needed)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let year = Calendar.current.component(.year, from: currentWeekSunday)
        return "\(formatter.string(from: startWeekMonday)) - \(formatter.string(from: currentWeekSunday)), \(year)"
    }
    
    @ViewBuilder
    private var dateRangeText: some View {
        Text(formatWeeklyDateRange())
            .font(.subheadline)
            .foregroundColor(.secondary)
    }

    private var chartHeight: CGFloat { height - 60 } // Subtract space for controls
    private let weekSpacing: CGFloat = 4
    private let visibleWeeks: Int = 26
    private let barWidthRatio: CGFloat = 0.8

    private var chartView: some View {
                                VStack(spacing: 0) {
            sleepChart
            loadingIndicators
        }
        .onAppear {
            // Only initialize scroll position if we haven't already
            // This prevents the chart from snapping back to today when switching tabs
            guard !hasInitializedScroll else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                initializeScrollPosition()
                hasInitializedScroll = true
            }
        }
        .onChange(of: dataManager.chartWeekData.count) { oldValue, newValue in
            // Re-initialize scroll position only on first data load
            if oldValue == 0 && newValue > 0 && !hasInitializedScroll {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    initializeScrollPosition()
                    hasInitializedScroll = true
                }
            }
        }
    }
    
    // Chart content - extracted to avoid type-checking issues
    // Use ALL chartData (like MetricDetailView) - includes empty weeks for proper X-axis and scrolling
    private var sleepChart: some View {
        let visibleDomainLength: TimeInterval = 26 * 7 * 24 * 60 * 60 // 26 weeks in seconds
        
        return Chart(chartData) { weekData in
            // Render BarMark for all weeks to ensure X-axis labels appear
            // Only show actual bars when data exists
            if weekData.week != nil {
                BarMark(
                    x: .value("Week", weekData.weekStartDate, unit: .weekOfYear),
                    // yStart must be < yEnd: bedtime (300 min, 11 PM) < waketime (780 min, 7 AM)
                    yStart: .value("Bedtime", weekData.chartBedtime),     // Earlier time (11 PM)
                    yEnd: .value("Waketime", weekData.chartWaketime),     // Later time (7 AM)
                    width: .ratio(0.6)
                )
                .foregroundStyle(getBarColor(for: weekData))
                .cornerRadius(4)
                                    } else {
                // Render invisible bar for empty weeks to maintain X-axis structure
                BarMark(
                    x: .value("Week", weekData.weekStartDate, unit: .weekOfYear),
                    yStart: .value("Bedtime", weekData.chartBedtime),     // Earlier
                    yEnd: .value("Waketime", weekData.chartWaketime),     // Later
                    width: .ratio(0.6)
                )
                .foregroundStyle(Color.clear)
            }
        }
        .frame(height: chartHeight)
        .chartYScale(domain: yAxisDomain)
        .chartScrollableAxes(.horizontal)
        .chartScrollPosition(x: $scrollPosition)
        .chartXVisibleDomain(length: visibleDomainLength)
        .chartGesture { proxy in
            SpatialTapGesture()
                .onEnded { value in
                    handleChartTap(proxy: proxy, location: value.location)
                }
        }
        .onChange(of: scrollPosition) { oldValue, newValue in
            NSLog("[SLEEP] 📍 scrollPosition changed: \(oldValue) → \(newValue)")
            handleChartScrolling(position: newValue)
            // Force view update to refresh date range
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                if let dateValue = value.as(Date.self) {
                    AxisValueLabel {
                        Text(formatYAxisTimeLabel(for: dateValue))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    AxisGridLine()
                        .foregroundStyle(Color.gray.opacity(0.2))
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: 1)) { value in
                if value.as(Date.self) != nil {
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                    AxisGridLine()
                    AxisTick()
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }
    
    // Loading indicators
    private var loadingIndicators: some View {
        HStack {
            if dataManager.isLoadingOlder {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Loading older data...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if dataManager.isLoadingNewer {
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
    
    // Helper: Get bar color based on selection
    private func getBarColor(for weekData: ChartWeekData) -> Color {
        // If a stage is selected, make all bars darker grey
        if selectedStage != nil {
            return Color(uiColor: .secondarySystemGroupedBackground)
        }
        // Normal selection highlighting
        if let week = weekData.week, selectedWeek?.id == week.id {
            return barColor.opacity(0.6)
        }
        return barColor
    }
    
    // Helper: Handle chart tap gesture
    private func handleChartTap(proxy: ChartProxy, location: CGPoint) {
        NSLog("[SLEEP] 📍 handleChartTap: Tap at location \(location)")
        guard let tappedDate: Date = proxy.value(atX: location.x) else {
            NSLog("[SLEEP] ⚠️ handleChartTap: Could not get date from tap location")
            return
        }
        
        NSLog("[SLEEP] 📍 handleChartTap: Tapped date = \(tappedDate)")
        
        // Find closest week with data
        let closest = chartData.compactMap { $0.week }.min(by: {
            abs($0.weekStartDate.timeIntervalSince(tappedDate)) < abs($1.weekStartDate.timeIntervalSince(tappedDate))
        })
        
        if let week = closest {
            if selectedWeek?.id == week.id {
                NSLog("[SLEEP] 📍 handleChartTap: Deselecting week \(week.weekStartDate)")
                selectedWeek = nil
            } else {
                NSLog("[SLEEP] 📍 handleChartTap: Selecting week \(week.weekStartDate) - \(formatTime(week.avgBedtime)) to \(formatTime(week.avgWaketime))")
                selectedWeek = week
            }
        } else {
            NSLog("[SLEEP] ⚠️ handleChartTap: No closest week found")
        }
    }
    
    // Helper: Initialize scroll position (like MetricDetailView lines 630-643)
    // Position scroll so today is ~90% across visible window (leaving 10% for future)
    private func initializeScrollPosition() {
        NSLog("[SLEEP] 📍 initializeScrollPosition: Starting, chartData count = \(chartData.count)")
        guard !chartData.isEmpty else {
            NSLog("[SLEEP] ⚠️ initializeScrollPosition: chartData is empty, skipping")
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let visibleDuration = 26 // 26 weeks for sixMonth
        
        // Position scroll so today is ~90% across the visible window (leaving 10% for future)
        // scrollPosition is the LEFT edge of the visible window
        let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
        let newPosition = calendar.date(
            byAdding: .weekOfYear,
            value: -offsetFromEnd,
            to: now
        ) ?? now
        
        // Calculate what the visible window will be
        let visibleDomainLength: TimeInterval = 26 * 7 * 24 * 60 * 60
        let visibleEnd = calendar.date(byAdding: .second, value: Int(visibleDomainLength), to: newPosition) ?? newPosition
        
        NSLog("[SLEEP] 📍 initializeScrollPosition: Setting scroll position to \(newPosition)")
        NSLog("[SLEEP] 📍 initializeScrollPosition: Visible window will be from \(newPosition) to \(visibleEnd)")
        if let firstWeek = chartData.first, let lastWeek = chartData.last {
            NSLog("[SLEEP] 📍 initializeScrollPosition: chartData range - first: \(firstWeek.weekStartDate), last: \(lastWeek.weekStartDate)")
        }
        
        scrollPosition = newPosition
    }
    
    // Handle scrolling for infinite scroll (like MetricDetailView)
    private func handleChartScrolling(position: Date) {
        guard !dataManager.chartWeekData.isEmpty else { return }

        // Notify parent of visible range change
        let calendar = Calendar.current
        let visibleDomainLength: TimeInterval = 26 * 7 * 24 * 60 * 60 // 26 weeks
        if let endDate = calendar.date(byAdding: .second, value: Int(visibleDomainLength), to: position) {
            // Update binding for parent
            visibleRangeBinding = (position, endDate)
            onVisibleRangeChange?(position, endDate)
        }

        // Find the week at scroll position
        let weekAtPosition = dataManager.chartWeekData.first(where: { weekGroup in
            let weekStart = weekGroup.weekStartDate
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            return weekStart <= position && position < weekEnd
        })
        
        if let weekGroup = weekAtPosition, let week = weekGroup.week {
            dataManager.checkEdges(visibleWeek: week)
        } else if let weekGroup = weekAtPosition {
            // Even without data, check edges
            if let oldestTimeline = dataManager.chartWeekData.first?.weekStartDate,
               let newestTimeline = dataManager.chartWeekData.last?.weekStartDate {
                let daysFromOldest = calendar.dateComponents([.day], from: oldestTimeline, to: weekGroup.weekStartDate).day ?? 0
                let daysFromNewest = calendar.dateComponents([.day], from: weekGroup.weekStartDate, to: newestTimeline).day ?? 0
                
                if daysFromOldest >= 0 && daysFromOldest <= 21 && !dataManager.isLoadingOlder {
                    NSLog("[SLEEP] 📊 Near oldest edge (empty week), loading older data")
                    Task { await dataManager.loadOlderData() }
                } else if daysFromNewest >= 0 && daysFromNewest <= 21 && !dataManager.isLoadingNewer {
                    let now = Date()
                    let twoMonthsAhead = calendar.date(byAdding: .month, value: 2, to: now) ?? now
                    if newestTimeline < twoMonthsAhead {
                        NSLog("[SLEEP] 📊 Near newest edge (empty week), loading newer data")
                        Task { await dataManager.loadNewerData() }
                    }
                }
            }
        }
    }
    
    // Format Y-axis time label from inverted Date domain
    // Mapping: date = sixPMReference + (maxMinutes - actualMinutes)
    private func formatYAxisTimeLabel(for date: Date) -> String {
        let calendar = Calendar.current
        // Use the SAME reference date as yAxisDomain (today)
        let referenceDate = calendar.startOfDay(for: Date())
        guard let sixPMReference = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: referenceDate) else {
            NSLog("[SLEEP] ⚠️ formatYAxisTimeLabel: Failed to create sixPMReference")
            return ""
        }
        
        let maxMinutes = 24 * 60
        // Calculate minutes difference - using DIRECT offsets
        let minutesSinceReference = calendar.dateComponents([.minute], from: sixPMReference, to: date).minute ?? 0

        // Direct mapping: date = sixPMReference + actualMinutes
        let actualMinutes = minutesSinceReference

        // Handle wrap-around: ensure in range 0-1440
        let normalizedMinutes: Int
        if actualMinutes >= 0 && actualMinutes < maxMinutes {
            normalizedMinutes = actualMinutes
        } else if actualMinutes < 0 {
            normalizedMinutes = ((actualMinutes % maxMinutes) + maxMinutes) % maxMinutes
        } else {
            normalizedMinutes = actualMinutes % maxMinutes
        }
        
        // Convert to hour: 0 minutes = 6 PM (18:00), 300 minutes = 11 PM (23:00), 780 minutes = 7 AM (7:00)
        let hour = (normalizedMinutes / 60 + 18) % 24
        
        let result = formatHourLabel(hour)
        NSLog("[SLEEP] 📊 formatYAxisTimeLabel: date = \(date), actualMinutes = \(normalizedMinutes), hour = \(hour), result = '\(result)'")
        return result
    }
    

    // Format Date to readable time string (e.g., "11:00 PM", "7:15 AM")
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func monthLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    private func formatHourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12a" }
        if hour < 12 { return "\(hour)a" }
        if hour == 12 { return "12p" }
        return "\(hour - 12)p"
    }

    // Normalize date to UTC midnight
    private func normalizeToUTCMidnight(_ date: Date) -> Date {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let components = utcCalendar.dateComponents([.year, .month, .day], from: date)
        return utcCalendar.date(from: components) ?? date
    }
    
    private func formatWeekRange(_ start: Date, _ end: Date) -> String {
        NSLog("[SLEEP] 📅 formatWeekRange: Input - start: \(start), end: \(end)")
        // Dates from database are already start-of-day in UTC (e.g., 2024-11-03 00:00:00+00)
        // Use UTC calendar to extract date components to avoid timezone shifts
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.timeZone = TimeZone(identifier: "UTC")! // Format in UTC to match database dates

        let year = utcCalendar.component(.year, from: end)
        let result = "\(formatter.string(from: start)) - \(formatter.string(from: end)), \(year)"
        NSLog("[SLEEP] 📅 formatWeekRange: Result - '\(result)' (from \(start) to \(end) in UTC)")
        return result
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Year View (Monthly Aggregations)
struct MonthlySleepChart: View {
    @ObservedObject var viewModel: SleepAnalysisViewModel
    @State private var scrollPosition: Date?
    @State private var selectedMonth: MonthlyAverage?
    @State private var scrolledMonthID: Date?

    private let barColor = Color(red: 0x6E / 255.0, green: 0x7C / 255.0, blue: 0xFF / 255.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryMetrics

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
            } else if viewModel.monthlyAverages.isEmpty {
                Text("No monthly data available")
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .foregroundColor(.secondary)
            } else {
                chartView
            }
        }
        .onAppear {
            // Only load if we don't have data and aren't already loading
            guard viewModel.monthlyAverages.isEmpty && !viewModel.isLoading else { return }
            Task {
                await viewModel.loadInitialMonthlyAverages()
            }
        }
    }

    // Calculate average bedtime and waketime from visible months (first 12 months with data)
    private func calculateVisibleMonthlyAverages() -> (bedtime: Date, waketime: Date) {
        let months = groupedByMonth()
        let visibleMonths = months.compactMap { $0.month } // Only months with data
        guard !visibleMonths.isEmpty else {
            // Return default times (11 PM bedtime, 7 AM waketime)
            let calendar = Calendar.current
            let bedtime = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: Date()) ?? Date()
            let waketime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
            return (bedtime, waketime)
        }
        
        // Calculate average by averaging the time components
        let calendar = Calendar.current
        var totalBedtimeSeconds: TimeInterval = 0
        var totalWaketimeSeconds: TimeInterval = 0
        var count = 0
        
        for month in visibleMonths {
            let bedtimeComponents = calendar.dateComponents([.hour, .minute, .second], from: month.avgBedtime)
            let waketimeComponents = calendar.dateComponents([.hour, .minute, .second], from: month.avgWaketime)
            
            if let bedtimeHour = bedtimeComponents.hour, let bedtimeMinute = bedtimeComponents.minute,
               let waketimeHour = waketimeComponents.hour, let waketimeMinute = waketimeComponents.minute {
                totalBedtimeSeconds += Double(bedtimeHour * 3600 + bedtimeMinute * 60)
                totalWaketimeSeconds += Double(waketimeHour * 3600 + waketimeMinute * 60)
                count += 1
            }
        }
        
        guard count > 0 else {
            let defaultBedtime = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: Date()) ?? Date()
            let defaultWaketime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
            return (defaultBedtime, defaultWaketime)
        }
        
        let avgBedtimeSeconds = totalBedtimeSeconds / Double(count)
        let avgWaketimeSeconds = totalWaketimeSeconds / Double(count)
        
        let bedtimeHour = Int(avgBedtimeSeconds) / 3600
        let bedtimeMinute = (Int(avgBedtimeSeconds) % 3600) / 60
        let waketimeHour = Int(avgWaketimeSeconds) / 3600
        let waketimeMinute = (Int(avgWaketimeSeconds) % 3600) / 60
        
        let avgBedtime = calendar.date(bySettingHour: bedtimeHour, minute: bedtimeMinute, second: 0, of: Date()) ?? Date()
        let avgWaketime = calendar.date(bySettingHour: waketimeHour, minute: waketimeMinute, second: 0, of: Date()) ?? Date()
        
        return (avgBedtime, avgWaketime)
    }
    
    private var summaryMetrics: some View {
        let averages = selectedMonth == nil ? calculateVisibleMonthlyAverages() : nil
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 40) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Avg Bedtime").font(.caption).foregroundColor(.secondary)
                    if let month = selectedMonth {
                        Text(formatTime(month.avgBedtime))
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
                    if let month = selectedMonth {
                        Text(formatTime(month.avgWaketime))
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
            if let month = selectedMonth {
                Text(formatMonthLabel(month.monthStartDate))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                monthlyDateRangeText
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    private func formatMonthlyDateRange() -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Calculate 12 months ago (first day of that month)
        guard let startMonth = calendar.date(byAdding: .month, value: -12, to: today) else {
            return ""
        }
        var startComponents = calendar.dateComponents([.year, .month], from: startMonth)
        startComponents.day = 1
        guard let startMonthFirstDay = calendar.date(from: startComponents) else {
            return ""
        }
        
        // Calculate end of current month (last day)
        var endComponents = calendar.dateComponents([.year, .month], from: today)
        endComponents.day = 1
        guard let currentMonthFirstDay = calendar.date(from: endComponents),
              let currentMonthLastDay = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: currentMonthFirstDay) else {
            return ""
        }
        
        let normalizedStart = normalizeToUTCMidnight(startMonthFirstDay)
        let normalizedEnd = normalizeToUTCMidnight(currentMonthLastDay)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM, yyyy"
        return "\(formatter.string(from: normalizedStart)) - \(formatter.string(from: normalizedEnd))"
    }
    
    @ViewBuilder
    private var monthlyDateRangeText: some View {
        Text(formatMonthlyDateRange())
            .font(.subheadline)
            .foregroundColor(.secondary)
    }

    private let chartHeight: CGFloat = 280
    private let monthSpacing: CGFloat = 4
    private let visibleMonths: Int = 12
    private let barWidthRatio: CGFloat = 0.8
    
    // Generate continuous 12-month range (like groupedByDate for W/M views)
    private func groupedByMonth() -> [(monthStartDate: Date, month: MonthlyAverage?)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Calculate 12 months ago (first day of that month)
        guard let startMonth = calendar.date(byAdding: .month, value: -12, to: today) else {
            return []
        }
        var startComponents = calendar.dateComponents([.year, .month], from: startMonth)
        startComponents.day = 1
        guard let startMonthFirstDay = calendar.date(from: startComponents) else {
            return []
        }
        
        // Create dictionary mapping month start dates to MonthlyAverage
        let monthDataMap = Dictionary(grouping: viewModel.monthlyAverages) { month in
            calendar.startOfDay(for: month.monthStartDate)
        }.compactMapValues { $0.first }
        
        var groups: [(monthStartDate: Date, month: MonthlyAverage?)] = []
        var currentMonth = startMonthFirstDay
        
        // Generate 12 months
        for _ in 0..<12 {
            let monthStart = calendar.startOfDay(for: currentMonth)
            let monthData = monthDataMap[monthStart]
            groups.append((monthStartDate: monthStart, month: monthData))
            
            // Move to first day of next month
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) else { break }
            currentMonth = nextMonth
        }
        
        return groups
    }

    private var chartView: some View {
        GeometryReader { geometry in
            let timeRange = calculateMonthlyTimeRange()
            let chartAreaWidth = geometry.size.width - 50
            let totalSpacing = monthSpacing * CGFloat(visibleMonths - 1)
            let monthWidth = (chartAreaWidth - totalSpacing) / CGFloat(visibleMonths)
            let barWidth = monthWidth * barWidthRatio
            let barXOffset = (monthWidth - barWidth) / 2.0

            HStack(alignment: .top, spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: monthSpacing) {
                            let months = groupedByMonth()
                            ForEach(Array(months.enumerated()), id: \.offset) { _, monthGroup in
                                VStack(spacing: 0) {
                                    // Month column
                                    ZStack(alignment: .leading) {
                                        // Grid lines
                                        Canvas { context, size in
                                            drawMonthlyGridLines(context: context, size: size, timeRange: timeRange)
                                        }
                                        .frame(width: monthWidth, height: chartHeight)

                                        // Sleep bar (only if data exists)
                                        if let month = monthGroup.month {
                                            Canvas { context, size in
                                                drawMonthlyBar(
                                                    context: context,
                                                    size: size,
                                                    month: month,
                                                    timeRange: timeRange,
                                                    barXOffset: barXOffset,
                                                    barWidth: barWidth,
                                                    isSelected: selectedMonth?.id == month.id
                                                )
                                            }
                                            .frame(width: monthWidth, height: chartHeight)
                                        }

                                        // Selection indicator
                                        if let month = monthGroup.month, selectedMonth?.id == month.id {
                                            Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 1).frame(height: chartHeight).offset(x: barXOffset)
                                            Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 1).frame(height: chartHeight).offset(x: barXOffset + barWidth)
                                        }
                                    }
                                    .frame(width: monthWidth, height: chartHeight)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if let month = monthGroup.month {
                                            selectedMonth = month
                                        }
                                    }
                                    
                                    // Month label (single letter) - BELOW the chart
                                    Text(monthInitial(monthGroup.monthStartDate))
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(.secondary)
                                        .frame(height: 24)
                                        .frame(width: monthWidth)
                                }
                                .id(monthGroup.monthStartDate)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, 12)
                    }
                    .scrollPosition(id: $scrolledMonthID, anchor: .leading)
                        .scrollTargetBehavior(.viewAligned)
                        .onChange(of: scrolledMonthID) { _, newID in
                            guard let newID = newID else { return }
                            // Find the month by monthStartDate and update visible range for edge detection
                            let months = groupedByMonth()
                            if let monthGroup = months.first(where: { $0.monthStartDate == newID }),
                               let month = monthGroup.month {
                                checkMonthlyEdges(visibleMonth: month)
                            }
                        }
                        .onAppear {
                            // Find month containing today
                            let months = groupedByMonth()
                            let calendar = Calendar.current
                            let today = Date()

                            // Find the month that contains today
                            let todayMonth = months.first(where: { month in
                                guard let monthData = month.month else { return false }
                                let monthStart = monthData.monthStartDate
                                guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return false }
                                return monthStart <= today && today < monthEnd
                            })

                            if let currentMonth = todayMonth {
                                // Scroll to show today's month on the right with padding
                                scrolledMonthID = currentMonth.monthStartDate
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    proxy.scrollTo(currentMonth.monthStartDate, anchor: .trailing)
                                }
                            } else if let lastMonth = months.last {
                                scrolledMonthID = lastMonth.monthStartDate
                            }
                        }
                }

                // Y-axis
                monthlyYAxisView(timeRange: timeRange).frame(width: 50)
            }
        }
        .frame(height: chartHeight + 24) // chartHeight + X-axis label height
    }
    
    private func adjustedHour(from date: Date) -> Double {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0)
        let clockHour = hour + (minute / 60.0)
        
        return clockHour >= 18.0 ? clockHour - 18.0 : clockHour + 6.0
    }
    
    private func calculateMonthlyTimeRange() -> (startHour: Double, endHour: Double, totalHours: Double) {
        // Calculate visible months (first 12 months with data)
        let months = groupedByMonth()
        let visibleMonths = months.compactMap { $0.month } // Only months with data
        guard !visibleMonths.isEmpty else {
            // Fallback: 8PM to 8AM
            return (2.0, 14.0, 12.0)
        }
        
        var earliest = 24.0
        var latest = 0.0
        
        for month in visibleMonths {
            let bedtimeHour = adjustedHour(from: month.avgBedtime)
            let waketimeHour = adjustedHour(from: month.avgWaketime)
            earliest = min(earliest, bedtimeHour)
            latest = max(latest, waketimeHour)
        }
        
        guard earliest < 24.0 && latest > 0.0 else {
            // No valid data, use default
            return (2.0, 14.0, 12.0)
        }
        
        let bufferedStart = max(0, earliest - 1)
        let bufferedEnd = min(24, latest + 1)
        let totalHours = bufferedEnd - bufferedStart
        
        guard totalHours > 0 else {
            return (2.0, 14.0, 12.0)
        }
        
        return (bufferedStart, bufferedEnd, totalHours)
    }
    
    // Edge detection for Y view (similar to checkEdges for W/M views)
    private func checkMonthlyEdges(visibleMonth: MonthlyAverage) {
        let calendar = Calendar.current
        let monthDates = viewModel.monthlyAverages.map { calendar.startOfDay(for: $0.monthStartDate) }
        
        guard let oldestData = monthDates.min(), let newestData = monthDates.max() else { return }
        
        let visibleDate = calendar.startOfDay(for: visibleMonth.monthStartDate)
        
        // Load older data when scrolled near beginning (oldest)
        if let diff = calendar.dateComponents([.month], from: oldestData, to: visibleDate).month, diff >= 0, diff <= 3, !viewModel.isLoadingOlder {
            Task { await viewModel.loadEarlierMonthlyAverages() }
        }
        
        // Load newer data when scrolled near end (newest)
        if let diff = calendar.dateComponents([.month], from: visibleDate, to: newestData).month, diff >= 0, diff <= 3, !viewModel.isLoadingNewer {
            Task { await viewModel.loadLaterMonthlyAverages() }
        }
    }
    
    private func drawMonthlyGridLines(context: GraphicsContext, size: CGSize, timeRange: (startHour: Double, endHour: Double, totalHours: Double)) {
        let hourLabels = generateMonthlyHourLabels(timeRange: timeRange)
        for adjustedHour in hourLabels {
            let yPosition = ((adjustedHour - timeRange.startHour) / timeRange.totalHours) * size.height
            // Clamp yPosition to valid bounds
            guard yPosition >= 0 && yPosition <= size.height else { continue }
            let path = Path { p in
                p.move(to: CGPoint(x: 0, y: yPosition))
                p.addLine(to: CGPoint(x: size.width, y: yPosition))
            }
            context.stroke(path, with: .color(Color.gray.opacity(0.15)), style: StrokeStyle(lineWidth: 0.5))
        }
    }
    
    private func drawMonthlyBar(context: GraphicsContext, size: CGSize, month: MonthlyAverage, timeRange: (startHour: Double, endHour: Double, totalHours: Double), barXOffset: CGFloat, barWidth: CGFloat, isSelected: Bool) {
        let bedtimeHour = adjustedHour(from: month.avgBedtime)
        let waketimeHour = adjustedHour(from: month.avgWaketime)
        
        guard waketimeHour > bedtimeHour else { return }
        guard timeRange.totalHours > 0 else { return }
        
        let segmentStart = bedtimeHour
        let segmentEnd = waketimeHour
        let segmentDuration = segmentEnd - segmentStart
        
        let yPosition = ((segmentStart - timeRange.startHour) / timeRange.totalHours) * size.height
        let height = max((segmentDuration / timeRange.totalHours) * size.height, 2.0)
        
        // Clamp bar coordinates to valid bounds
        let clampedY = max(0, min(yPosition, size.height - height))
        let clampedHeight = min(height, size.height - clampedY)
        
        guard clampedHeight >= 2.0 else { return }
        
        let rect = CGRect(x: barXOffset, y: clampedY, width: barWidth, height: clampedHeight)
        var segmentContext = context
        if isSelected { segmentContext.opacity = 1.0 }
        segmentContext.fill(Path(rect), with: .color(barColor))
    }
    
    private func generateMonthlyHourLabels(timeRange: (startHour: Double, endHour: Double, totalHours: Double)) -> [Double] {
        var labels: [Double] = []
        let interval: Double = 3
        let startHour = (Int(timeRange.startHour) / Int(interval)) * Int(interval)
        var currentHour = Double(startHour)
        
        while currentHour <= timeRange.endHour {
            labels.append(currentHour)
            currentHour += interval
        }
        
        return labels
    }
    
    private func monthlyYAxisView(timeRange: (startHour: Double, endHour: Double, totalHours: Double)) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                // Y-axis line
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1)
                    .frame(height: geometry.size.height)
                    .offset(x: 45)
                
                ForEach(generateMonthlyHourLabels(timeRange: timeRange), id: \.self) { adjustedHour in
                    let yPosition = ((adjustedHour - timeRange.startHour) / timeRange.totalHours) * geometry.size.height
                    // Clamp yPosition to valid bounds within the geometry
                    let clampedY = max(10, min(yPosition, geometry.size.height - 10))
                    let displayHour = clockHour(from: adjustedHour)
                    
                    Text(formatHourLabel(displayHour))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .position(x: 25, y: clampedY)
                }
            }
        }
        .frame(width: 50, height: chartHeight)
    }
    
    private func clockHour(from adjustedHour: Double) -> Int {
        let adjusted = Int(adjustedHour)
        return adjusted < 6 ? adjusted + 18 : adjusted - 6
    }

    // Format Date to readable time string (e.g., "11:00 PM", "7:15 AM")
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private func monthInitial(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMMM"
        let month = formatter.string(from: date)
        return String(month.prefix(1))
    }
    

    private func formatHourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12a" }
        if hour < 12 { return "\(hour)a" }
        if hour == 12 { return "12p" }
        return "\(hour - 12)p"
    }

    // Normalize date to UTC midnight
    private func normalizeToUTCMidnight(_ date: Date) -> Date {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let components = utcCalendar.dateComponents([.year, .month, .day], from: date)
        return utcCalendar.date(from: components) ?? date
    }
    
    private func formatMonthLabel(_ date: Date) -> String {
        let normalizedDate = normalizeToUTCMidnight(date)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM, yyyy"
        return formatter.string(from: normalizedDate)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

#Preview {
    SleepAnalysisPrimary(pillar: "Restful Sleep", color: .purple)
}






