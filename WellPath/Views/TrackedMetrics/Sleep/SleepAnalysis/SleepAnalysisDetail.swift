//
//  SleepAnalysisDetail.swift
//  WellPath
//
//  Detail view for sleep analysis with Amounts, Percentages, and Comparisons tabs
//

import SwiftUI
import Charts

// MARK: - Main Detail View

enum SleepDetailTab: String, CaseIterable {
    case amounts = "Amounts"
    case percentages = "Percentages"
    case comparisons = "Comparisons"
}

struct SleepDetailView: View {
    @State private var selectedTab: SleepDetailTab = .amounts

    // Get color dynamically from pillar
    let color = MetricsUIConfig.getPillarColor(for: "Restorative Sleep")
    let screenIcon = MetricsUIConfig.getIcon(for: "Sleep Analysis")

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("View", selection: $selectedTab) {
                ForEach(SleepDetailTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Content based on selected tab (each tab handles its own layout)
            Group {
                switch selectedTab {
                case .amounts:
                    AmountsTabView(color: color)
                case .percentages:
                    SleepPercentagesChart(color: color)
                case .comparisons:
                    ComparisonsTabView(color: color)
                }
            }
        }
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
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Amounts Tab View

struct AmountsTabView: View {
    let color: Color
    @StateObject private var viewModel = SleepDetailViewModel()
    @StateObject private var chartViewModel = SleepAnalysisViewModel()
    @StateObject private var educationViewModel = TabEducationViewModel(metricId: "DISP_SLEEP_ANALYSIS_AMOUNTS")
    @State private var showAbout = false
    @State private var selectedPeriod: SleepPeriod = .week
    @State private var selectedStage: SleepStage?
    @State private var visibleDateRange: (start: Date, end: Date)?

    enum SleepPeriod: String, CaseIterable {
        case day = "D"
        case week = "W"
        case month = "M"
        case sixMonth = "6M"
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

            // Load initial sleep data based on period
            await loadSleepDataForPeriod(selectedPeriod)
        }
    }
    
    private func loadSleepDataForPeriod(_ period: SleepPeriod) async {
        // Load chart data - stage durations are calculated directly from this data
        switch period {
        case .day:
            await chartViewModel.loadInitialSleepStages(daysBack: 7, daysAhead: 0)
        case .week:
            await chartViewModel.loadInitialSleepStages(daysBack: 14, daysAhead: 7)
        case .month:
            await chartViewModel.loadInitialSleepStages(daysBack: 60, daysAhead: 30)
        case .sixMonth:
            // 6M view uses WeeklySleepDataManager which loads on its own
            break
        }
    }

    private var chartView: some View {
        VStack(spacing: 0) {
            // Period selector (D/W/M/6M)
            Picker("Period", selection: $selectedPeriod) {
                ForEach(SleepPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .onChange(of: selectedPeriod) { _, newPeriod in
                selectedStage = nil // Reset stage selection on period change
                Task {
                    await loadSleepDataForPeriod(newPeriod)
                }
            }
            // No need for onChange handlers - stage durations are calculated directly
            // from chartViewModel.sleepStageSegments which updates automatically

            // Fixed chart at top
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
                // Chart content based on period (using SleepAnalysisPrimary chart views)
                switch selectedPeriod {
                case .day:
                    DayViewChart(
                        color: color,
                        viewModel: chartViewModel,
                        selectedStage: $selectedStage,
                        onVisibleRangeChange: { start, end in
                            visibleDateRange = (start, end)
                        },
                        height: 200,
                        showAbout: $showAbout
                    )
                case .week:
                    ScrollableSleepChart(viewMode: .week, viewModel: chartViewModel, selectedStage: $selectedStage, visibleRangeBinding: $visibleDateRange, height: 200, showAbout: $showAbout)
                case .month:
                    ScrollableSleepChart(viewMode: .month, viewModel: chartViewModel, selectedStage: $selectedStage, visibleRangeBinding: $visibleDateRange, height: 200, showAbout: $showAbout)
                case .sixMonth:
                    WeeklySleepChart(viewModel: chartViewModel, selectedStage: $selectedStage, visibleRangeBinding: $visibleDateRange, height: 272, showAbout: $showAbout)
                }
            }

            // Scrollable stage selectors below chart
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(stageDurations, id: \.stage) { item in
                        Button(action: {
                            if selectedStage == item.stage {
                                selectedStage = nil
                            } else {
                                selectedStage = item.stage
                            }
                        }) {
                            HStack {
                                Circle()
                                    .fill(item.stage.color)
                                    .frame(width: 12, height: 12)

                                Text(stageName(for: item.stage))
                                    .font(.subheadline)
                                    .foregroundColor(.primary)

                                Spacer()

                                Text(formatDuration(item.duration))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(
                                selectedStage == item.stage
                                    ? item.stage.color.opacity(0.3)
                                    : Color(uiColor: .secondarySystemGroupedBackground)
                            )
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
                .padding(.bottom, 20) // Extra bottom padding to ensure last item is visible
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
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

    // MARK: - Helpers

    private var stageDurations: [(stage: SleepStage, duration: Double?)] {
        let stages: [SleepStage] = [.awake, .rem, .core, .deep]
        let calendar = Calendar.current

        // Get visible segments based on period
        let visibleSegments: [SleepStageSegment]

        if selectedPeriod == .day {
            // For day view: use only the currently visible session's segments
            if let range = visibleDateRange {
                // Find the session that matches the visible date range
                let visibleSession = chartViewModel.sleepSessions.first { session in
                    let sessionDate = calendar.startOfDay(for: session.date)
                    return sessionDate >= range.start && sessionDate < range.end
                }
                visibleSegments = visibleSession?.segments ?? []
            } else {
                // Fallback: use first session if no range set yet
                visibleSegments = chartViewModel.sleepSessions.first?.segments ?? []
            }
        } else if let range = visibleDateRange {
            // For W/M/6M views: filter by visible date range from scroll
            // Use sessions to determine which segments belong to which date
            // (matches the session grouping logic which assigns by wake-up date)
            let visibleSessions = chartViewModel.sleepSessions.filter { session in
                let sessionDate = calendar.startOfDay(for: session.date)
                return sessionDate >= range.start && sessionDate <= range.end
            }
            visibleSegments = visibleSessions.flatMap { $0.segments }
        } else {
            // Fallback: use all segments
            visibleSegments = chartViewModel.sleepStageSegments
        }

        // Calculate durations from visible segments
        return stages.map { stage in
            let seconds = visibleSegments
                .filter { $0.stage == stage }
                .reduce(0.0) { total, segment in
                    total + segment.endTime.timeIntervalSince(segment.startTime)
                }

            let minutes = seconds / 60.0

            // For week, month, 6month views: calculate average per day
            if selectedPeriod != .day {
                // Count days with actual sleep data in visible range
                let daysWithData: Int
                if let range = visibleDateRange {
                    let visibleSessionsWithData = chartViewModel.sleepSessions.filter { session in
                        let sessionDate = calendar.startOfDay(for: session.date)
                        return sessionDate >= range.start && sessionDate <= range.end && !session.segments.isEmpty
                    }
                    daysWithData = max(visibleSessionsWithData.count, 1)
                } else {
                    daysWithData = max(chartViewModel.sleepSessions.filter { !$0.segments.isEmpty }.count, 1)
                }

                return (stage, minutes > 0 ? minutes / Double(daysWithData) : nil)
            } else {
                // For day view: return total for current session
                return (stage, minutes > 0 ? minutes : nil)
            }
        }
    }

    private func stageName(for stage: SleepStage) -> String {
        // For day view, show "Total X"; for other views, show "Average X"
        let prefix = selectedPeriod == .day ? "Total" : "Average"
        switch stage {
        case .awake: return "\(prefix) Awake"
        case .rem: return "\(prefix) REM"
        case .core: return "\(prefix) Core"
        case .deep: return "\(prefix) Deep"
        default: return ""
        }
    }

    private func formatDuration(_ minutes: Double?) -> String {
        guard let minutes = minutes else {
            return "-- hr"
        }
        let hours = Int(minutes) / 60
        let remainingMinutes = Int(minutes) % 60
        if hours > 0 {
            return "\(hours) hr \(remainingMinutes) min"
        } else {
            return "\(remainingMinutes) min"
        }
    }
}

// MARK: - Comparisons Tab View (Placeholder)

struct ComparisonsTabView: View {
    let color: Color
    @StateObject private var educationViewModel = TabEducationViewModel(metricId: "DISP_SLEEP_ANALYSIS_COMPARISONS")
    @State private var selectedView: ComparisonsView = .chart

    enum ComparisonsView: String, CaseIterable {
        case chart = "Chart"
        case about = "About"
    }

    var body: some View {
        VStack(spacing: 0) {
            // View picker (Chart/About)
            Picker("View", selection: $selectedView) {
                ForEach(ComparisonsView.allCases, id: \.self) { view in
                    Text(view.rawValue).tag(view)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            if selectedView == .chart {
                chartView
            } else {
                aboutView
            }
        }
        .task {
            await educationViewModel.loadEducation()
        }
    }

    private var chartView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Comparisons")
                .font(.headline)
            Text("Compare your sleep data over time")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var aboutView: some View {
        ScrollView {
            if let education = educationViewModel.education {
                VStack(alignment: .leading, spacing: 24) {
                    if let about = education.aboutContent {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(color)
                                Text("About Sleep Comparisons")
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
            }
        }
    }
}

// MARK: - Chart Components

struct StagesHorizontalChartView: View {
    let data: [SleepStageDataPoint]
    let selectedStage: SleepStage?

    var body: some View {
        VStack(spacing: 8) {
            ForEach([SleepStage.awake, .rem, .core, .deep], id: \.self) { stage in
                HStack(spacing: 4) {
                    Text(stageName(for: stage))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .leading)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color(uiColor: .tertiarySystemBackground))

                            ForEach(data.filter { $0.stage == stage }) { segment in
                                let opacity = selectedStage == nil || selectedStage == stage ? 1.0 : 0.3
                                Rectangle()
                                    .fill(segment.stage.color.opacity(opacity))
                                    .frame(width: segmentWidth(for: segment, totalWidth: geometry.size.width))
                                    .offset(x: segmentOffset(for: segment, totalWidth: geometry.size.width))
                            }
                        }
                    }
                    .frame(height: 40)
                    .cornerRadius(4)
                }
            }
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

    private func segmentWidth(for segment: SleepStageDataPoint, totalWidth: CGFloat) -> CGFloat {
        let dayDuration: TimeInterval = 24 * 3600
        return (segment.duration / dayDuration) * totalWidth
    }

    private func segmentOffset(for segment: SleepStageDataPoint, totalWidth: CGFloat) -> CGFloat {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: segment.startDate)
        let secondsFromStartOfDay = segment.startDate.timeIntervalSince(startOfDay)
        let dayDuration: TimeInterval = 24 * 3600
        return (secondsFromStartOfDay / dayDuration) * totalWidth
    }
}

struct StagesVerticalChartView: View {
    let data: [SleepStageDataPoint]
    let selectedStage: SleepStage?
    let period: PeriodType

    private var dailyData: [DailySleepData] {
        let calendar = Calendar.current
        var grouped: [Date: [SleepStageDataPoint]] = [:]

        for point in data {
            let day = calendar.startOfDay(for: point.startDate)
            grouped[day, default: []].append(point)
        }

        return grouped.map { date, points in
            DailySleepData(date: date, stages: points)
        }.sorted { $0.date < $1.date }
    }

    var body: some View {
        Chart(dailyData) { day in
            ForEach([SleepStage.deep, .core, .rem, .awake], id: \.self) { stage in
                if let duration = day.duration(for: stage), duration > 0 {
                    let opacity = selectedStage == nil || selectedStage == stage ? 1.0 : 0.3
                    BarMark(
                        x: .value("Date", day.date),
                        y: .value("Duration", duration / 3600)
                    )
                    .foregroundStyle(stage.color.opacity(opacity))
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(formatXAxisLabel(date))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }

    private func formatXAxisLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = period == .weekly ? "EEE" : "d"
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types (reusing from original file)

enum PeriodType: String, CaseIterable {
    case daily = "D"
    case weekly = "W"
    case monthly = "M"
    case sixMonth = "6M"
    case yearly = "Y"

    var fullName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .sixMonth: return "6 Month"
        case .yearly: return "Yearly"
        }
    }

    var periodId: String {
        switch self {
        case .daily: return "daily"
        case .weekly: return "weekly"
        case .monthly: return "monthly"
        case .sixMonth: return "6month"
        case .yearly: return "yearly"
        }
    }
}

struct SleepStageDataPoint: Identifiable {
    let id = UUID()
    let stage: SleepStage
    let startDate: Date
    let endDate: Date
    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
}

struct DailySleepData: Identifiable {
    let id = UUID()
    let date: Date
    let stages: [SleepStageDataPoint]

    var totalDuration: TimeInterval {
        stages.reduce(0.0) { $0 + $1.duration }
    }

    var asleepDuration: TimeInterval {
        stages.filter { $0.stage != .awake && $0.stage != .inBed }.reduce(0.0) { $0 + $1.duration }
    }

    func duration(for stage: SleepStage) -> TimeInterval? {
        let total = stages.filter { $0.stage == stage }.reduce(0.0) { $0 + $1.duration }
        return total > 0 ? total : nil
    }
}

// MARK: - View Model

@MainActor
class SleepDetailViewModel: ObservableObject {
    @Published var sleepStageData: [SleepStageDataPoint] = []
    @Published var isLoading = false
    @Published var stageAverages: [SleepStage: Double] = [:] // Duration in minutes (for W, M, 6M views)
    @Published var stageTotals: [SleepStage: Double] = [:] // Duration in minutes (for D view - totals)

    private let supabase = SupabaseManager.shared.client

    func loadSleepData(for period: PeriodType) async {
        isLoading = true

        do {
            let userId = try await supabase.auth.session.user.id

            let calendar = Calendar.current
            let now = Date()
            let startDate: Date

            switch period {
            case .daily:
                startDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            case .weekly:
                startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            case .monthly:
                startDate = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            case .sixMonth:
                startDate = calendar.date(byAdding: .month, value: -6, to: now) ?? now
            case .yearly:
                startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            }

            print("🌙 Loading sleep data for period: \(period.rawValue)")

            // Query patient_sleep_hypnogram_data view (unified sleep data from patient_samples)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let hypnogramResponse = try await supabase
                .from("patient_sleep_hypnogram_data")
                .select()
                .eq("patient_id", value: userId)
                .gte("start_time", value: startDate.ISO8601Format())
                .lte("end_time", value: now.ISO8601Format())
                .order("start_time", ascending: true)
                .execute()

            let hypnogramData = try decoder.decode([SleepHypnogramData].self, from: hypnogramResponse.data)

            guard !hypnogramData.isEmpty else {
                sleepStageData = []
                isLoading = false
                return
            }

            // Convert SleepHypnogramData to SleepStageDataPoint
            var stageData: [SleepStageDataPoint] = []

            for entry in hypnogramData {
                // Map sleep_stage integer to SleepStage enum
                // 0=Awake, 1=REM, 2=Core, 3=Deep
                let stage: SleepStage
                switch entry.sleepStage {
                case 0: stage = .awake
                case 1: stage = .rem
                case 2: stage = .core
                case 3: stage = .deep
                default: continue
                }

                stageData.append(SleepStageDataPoint(
                    stage: stage,
                    startDate: entry.startTime,
                    endDate: entry.endTime
                ))
            }

            sleepStageData = stageData.sorted { $0.startDate < $1.startDate }

            print("✅ Loaded \(sleepStageData.count) sleep segments from hypnogram view")

        } catch {
            print("❌ Error loading sleep data: \(error)")
            sleepStageData = []
        }

        isLoading = false
    }

    /// Load stage duration averages/totals from aggregation_results_cache
    func loadStageAggregations(for period: PeriodType, startDate: Date, endDate: Date) async {
        do {
            let userId = try await supabase.auth.session.user.id

            print("📊 Loading stage aggregations for period: \(period.rawValue) from \(startDate) to \(endDate)")

            // Query aggregation_results_cache for daily SUMs of each stage
            struct AggregationResult: Codable {
                let aggMetricId: String
                let periodStart: Date
                let value: Double

                enum CodingKeys: String, CodingKey {
                    case aggMetricId = "agg_metric_id"
                    case periodStart = "period_start"
                    case value
                }
            }

            let results: [AggregationResult] = try await supabase
                .from("aggregation_results_cache")
                .select("agg_metric_id, period_start, value")
                .eq("patient_id", value: userId)
                .eq("period_type", value: "daily")
                .eq("calculation_type_id", value: "SUM")
                .in("agg_metric_id", values: [
                    "AGG_AWAKE_DURATION",
                    "AGG_REM_SLEEP_DURATION",
                    "AGG_CORE_SLEEP_DURATION",
                    "AGG_DEEP_SLEEP_DURATION"
                ])
                .gte("period_start", value: startDate.ISO8601Format())
                .lte("period_start", value: endDate.ISO8601Format())
                .execute()
                .value

            print("📊 Found \(results.count) aggregation results")

            // Group by stage and sum values
            var stageTotalsDict: [String: (total: Double, count: Int)] = [:]
            
            for result in results {
                if let existing = stageTotalsDict[result.aggMetricId] {
                    stageTotalsDict[result.aggMetricId] = (existing.total + result.value, existing.count + 1)
                } else {
                    stageTotalsDict[result.aggMetricId] = (result.value, 1)
                }
            }

            // For day view: use totals (sum all daily values in visible window)
            // For other views: use averages (total / count)
            var totals: [SleepStage: Double] = [:]
            var averages: [SleepStage: Double] = [:]

            for (aggMetricId, data) in stageTotalsDict {
                let total = data.total
                let average = data.count > 0 ? total / Double(data.count) : 0

                switch aggMetricId {
                case "AGG_AWAKE_DURATION":
                    totals[.awake] = total
                    averages[.awake] = average
                case "AGG_REM_SLEEP_DURATION":
                    totals[.rem] = total
                    averages[.rem] = average
                case "AGG_CORE_SLEEP_DURATION":
                    totals[.core] = total
                    averages[.core] = average
                case "AGG_DEEP_SLEEP_DURATION":
                    totals[.deep] = total
                    averages[.deep] = average
                default:
                    break
                }
            }

            // Store both totals and averages
            stageTotals = totals
            stageAverages = averages

            if period == .daily {
                print("✅ Stage totals: Awake=\(totals[.awake] ?? 0)m, REM=\(totals[.rem] ?? 0)m, Core=\(totals[.core] ?? 0)m, Deep=\(totals[.deep] ?? 0)m")
            } else {
                print("✅ Stage averages: Awake=\(averages[.awake] ?? 0)m, REM=\(averages[.rem] ?? 0)m, Core=\(averages[.core] ?? 0)m, Deep=\(averages[.deep] ?? 0)m")
            }

        } catch {
            print("❌ Error loading stage aggregations: \(error)")
            stageAverages = [:]
            stageTotals = [:]
        }
    }

    func dateRangeLabel(for period: PeriodType) -> String {
        guard !sleepStageData.isEmpty else { return "" }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        if let first = sleepStageData.first?.startDate,
           let last = sleepStageData.last?.startDate {
            let startStr = formatter.string(from: first)
            let endStr = formatter.string(from: last)

            // Add year if different from current year
            let calendar = Calendar.current
            let currentYear = calendar.component(.year, from: Date())
            let lastYear = calendar.component(.year, from: last)

            if lastYear != currentYear {
                return "\(startStr) – \(endStr), \(lastYear)"
            } else {
                return "\(startStr) – \(endStr), \(currentYear)"
            }
        }

        return ""
    }
}


#Preview {
    NavigationStack {
        SleepDetailView()
    }
}
