//
//  SleepAnalysisScreen.swift
//  WellPath
//
//  Card-based layout for Sleep Analysis metric
//  All metrics shown as tappable mini cards that expand to full-screen views
//

import SwiftUI

struct SleepAnalysisScreen: View {
    let pillar: String
    let color: Color

    @StateObject private var chartViewModel = SleepAnalysisViewModel()
    @StateObject private var primaryViewModel = SleepAnalysisPrimaryViewModel(metricId: "DISP_SLEEP_ANALYSIS")
    @State private var showingEntryView = false
    @State private var showingDataManagement = false

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Sleep Analysis")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Sleep Stages card (main chart)
                MetricCardView(
                    title: "Sleep Stages",
                    color: color
                ) {
                    SleepStagesMiniCard(color: color, chartViewModel: chartViewModel)
                } fullScreen: {
                    SleepStagesFullView(color: color, chartViewModel: chartViewModel, primaryViewModel: primaryViewModel)
                }

                // Amounts card
                MetricCardView(
                    title: "Stage Amounts",
                    color: color
                ) {
                    SleepAmountsMiniCard(color: color, chartViewModel: chartViewModel)
                } fullScreen: {
                    AmountsTabView(color: color)
                        .metricScreenBackground(color: color, icon: screenIcon)
                }

                // Percentages card
                MetricCardView(
                    title: "Stage Percentages",
                    color: color
                ) {
                    SleepPercentagesMiniCard(color: color, chartViewModel: chartViewModel)
                } fullScreen: {
                    SleepPercentagesChart(color: color)
                        .metricScreenBackground(color: color, icon: screenIcon)
                }

                // Comparisons card
                MetricCardView(
                    title: "Comparisons",
                    color: color
                ) {
                    SleepComparisonsMiniCard(color: color)
                } fullScreen: {
                    ComparisonsTabView(color: color)
                        .metricScreenBackground(color: color, icon: screenIcon)
                }
            }
            .padding()
            .padding(.bottom, 24)
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
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingDataManagement = true
                } label: {
                    Image(systemName: "list.bullet")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingEntryView = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEntryView) {
            SleepEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            SleepDataManagementView(color: color)
        }
        .task {
            await chartViewModel.loadInitialSleepStages(daysBack: 7, daysAhead: 0)
            await primaryViewModel.loadPrimaryScreen()
        }
    }
}

// MARK: - Sleep Stages Mini Card

struct SleepStagesMiniCard: View {
    let color: Color
    @ObservedObject var chartViewModel: SleepAnalysisViewModel

    private var latestSleepSummary: (total: String, deep: String, rem: String)? {
        guard let latestSession = chartViewModel.sleepSessions.first else { return nil }

        var totalMinutes: Double = 0
        var deepMinutes: Double = 0
        var remMinutes: Double = 0

        for segment in latestSession.segments {
            let duration = segment.endTime.timeIntervalSince(segment.startTime) / 60.0
            totalMinutes += duration
            if segment.stage == .deep {
                deepMinutes += duration
            } else if segment.stage == .rem {
                remMinutes += duration
            }
        }

        return (
            formatDuration(totalMinutes),
            formatDuration(deepMinutes),
            formatDuration(remMinutes)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if chartViewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(height: 60)
            } else if let summary = latestSleepSummary {
                HStack(spacing: 16) {
                    // Total sleep
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Night")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(summary.total)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    // Deep + REM summary
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(SleepStage.deep.color)
                                    .frame(width: 8, height: 8)
                                Text(summary.deep)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(SleepStage.rem.color)
                                    .frame(width: 8, height: 8)
                                Text(summary.rem)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        Text("Deep / REM")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                HStack {
                    Text("No sleep data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 60)
            }
        }
    }

    private func formatDuration(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}

// MARK: - Sleep Stages Full View

struct SleepStagesFullView: View {
    let color: Color
    @ObservedObject var chartViewModel: SleepAnalysisViewModel
    @ObservedObject var primaryViewModel: SleepAnalysisPrimaryViewModel
    @State private var selectedPeriod: SleepPeriod = .day
    @State private var showAbout = false

    enum SleepPeriod: String, CaseIterable {
        case day = "D"
        case week = "W"
        case month = "M"
        case sixMonth = "6M"
    }

    var body: some View {
        VStack(spacing: 0) {
            if showAbout {
                aboutContentView
            } else {
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
                                await chartViewModel.loadInitialSleepStages(daysBack: 7, daysAhead: 0)
                            case .week:
                                await chartViewModel.loadInitialSleepStages(daysBack: 14, daysAhead: 7)
                            case .month:
                                await chartViewModel.loadInitialSleepStages(daysBack: 60, daysAhead: 30)
                            default:
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
                            DayViewChart(color: color, viewModel: chartViewModel, selectedStage: .constant(nil), showAbout: $showAbout)
                        case .week:
                            ScrollableSleepChart(viewMode: .week, viewModel: chartViewModel, selectedStage: .constant(nil), showAbout: $showAbout)
                        case .month:
                            ScrollableSleepChart(viewMode: .month, viewModel: chartViewModel, selectedStage: .constant(nil), showAbout: $showAbout)
                        case .sixMonth:
                            WeeklySleepChart(viewModel: chartViewModel, selectedStage: .constant(nil), showAbout: $showAbout)
                        }
                    }
                }
            }
        }
        .metricScreenBackground(color: color, icon: MetricsUIConfig.getIcon(for: "Sleep Analysis"))
    }

    private var aboutContentView: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 24) {
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
                        if let about = primaryViewModel.aboutContent {
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
                }
                .padding()
                .padding(.top, 40)
            }

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
        .frame(minHeight: 300)
    }
}

// MARK: - Mini Card Components

/// Mini preview for Stage Amounts - shows summary of sleep stages
struct SleepAmountsMiniCard: View {
    let color: Color
    @ObservedObject var chartViewModel: SleepAnalysisViewModel

    private var stageSummary: [(stage: SleepStage, minutes: Double)] {
        let stages: [SleepStage] = [.deep, .core, .rem, .awake]
        var result: [(SleepStage, Double)] = []

        // Use the latest session's data
        guard let latestSession = chartViewModel.sleepSessions.first else {
            return stages.map { ($0, 0) }
        }

        for stage in stages {
            let seconds = latestSession.segments
                .filter { $0.stage == stage }
                .reduce(0.0) { total, segment in
                    total + segment.endTime.timeIntervalSince(segment.startTime)
                }
            result.append((stage, seconds / 60.0))
        }

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if chartViewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(height: 60)
            } else if stageSummary.contains(where: { $0.minutes > 0 }) {
                HStack(spacing: 8) {
                    ForEach(stageSummary, id: \.stage) { item in
                        if item.minutes > 0 {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(item.stage.color)
                                    .frame(width: 8, height: 8)
                                Text(formatDuration(item.minutes))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Text(stageName(item.stage))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            } else {
                HStack {
                    Text("No sleep data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 60)
            }
        }
    }

    private func stageName(_ stage: SleepStage) -> String {
        switch stage {
        case .deep: return "Deep"
        case .core: return "Core"
        case .rem: return "REM"
        case .awake: return "Awake"
        default: return ""
        }
    }

    private func formatDuration(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}

/// Mini preview for Stage Percentages - shows pie/donut summary
struct SleepPercentagesMiniCard: View {
    let color: Color
    @ObservedObject var chartViewModel: SleepAnalysisViewModel

    private var stagePercentages: [(stage: SleepStage, percentage: Double)] {
        guard let latestSession = chartViewModel.sleepSessions.first else {
            return []
        }

        let stages: [SleepStage] = [.deep, .core, .rem, .awake]
        var totals: [SleepStage: Double] = [:]
        var grandTotal: Double = 0

        for segment in latestSession.segments {
            let duration = segment.endTime.timeIntervalSince(segment.startTime)
            totals[segment.stage, default: 0] += duration
            grandTotal += duration
        }

        guard grandTotal > 0 else { return [] }

        return stages.compactMap { stage in
            guard let total = totals[stage], total > 0 else { return nil }
            return (stage, (total / grandTotal) * 100)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if chartViewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(height: 60)
            } else if !stagePercentages.isEmpty {
                HStack(spacing: 12) {
                    // Mini percentage bars
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(stagePercentages, id: \.stage) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(item.stage.color)
                                    .frame(width: 8, height: 8)
                                Text(stageName(item.stage))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 40, alignment: .leading)
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                                        .frame(width: 60, height: 6)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(item.stage.color)
                                        .frame(width: 60 * min(item.percentage / 100, 1.0), height: 6)
                                }
                                Text("\(Int(item.percentage.rounded()))%")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .frame(width: 35, alignment: .trailing)
                            }
                        }
                    }
                    Spacer()
                }
            } else {
                HStack {
                    Text("No sleep data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 60)
            }
        }
    }

    private func stageName(_ stage: SleepStage) -> String {
        switch stage {
        case .deep: return "Deep"
        case .core: return "Core"
        case .rem: return "REM"
        case .awake: return "Awake"
        default: return ""
        }
    }
}

/// Mini preview for Comparisons - shows placeholder since comparisons need more data
struct SleepComparisonsMiniCard: View {
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 24))
                    .foregroundColor(color.opacity(0.6))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Compare Over Time")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text("View trends and patterns")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .frame(height: 60)
    }
}

#Preview {
    NavigationStack {
        SleepAnalysisScreen(pillar: "Restorative Sleep", color: .indigo)
    }
}
