//
//  SleepAmountsView.swift
//  WellPath
//
//  Full view for Sleep Stage Amounts (duration in minutes per stage).
//  Standalone view - receives viewId from navigation for database-driven content.
//

import SwiftUI

struct SleepAmountsView: View {
    let color: Color
    let viewId: String
    @ObservedObject private var chartViewModel: SleepAnalysisViewModel
    @ObservedObject private var primaryViewModel: SleepAnalysisPrimaryViewModel
    @State private var showEntry = false
    @State private var showDataManagement = false
    @State private var showAboutModal = false
    @State private var selectedPeriod: SleepPeriod = .week
    @State private var selectedStage: SleepStage?
    @State private var visibleDateRange: (start: Date, end: Date)?

    // Track if we own the view models (for standalone use)
    private let ownsViewModels: Bool

    enum SleepPeriod: String, CaseIterable {
        case day = "D"
        case week = "W"
        case month = "M"
        case sixMonth = "6M"
    }

    private var metricId: String { viewId }
    private let metricName = "Stage Amounts"

    /// Standalone initializer - creates its own view models
    init(color: Color, viewId: String = "DISP_SLEEP_AMOUNTS") {
        self.color = color
        self.viewId = viewId
        self._chartViewModel = ObservedObject(wrappedValue: SleepAnalysisViewModel())
        self._primaryViewModel = ObservedObject(wrappedValue: SleepAnalysisPrimaryViewModel(viewId: viewId))
        self.ownsViewModels = true
    }

    /// Card initializer - uses passed view models
    init(color: Color, viewId: String, chartViewModel: SleepAnalysisViewModel, primaryViewModel: SleepAnalysisPrimaryViewModel) {
        self.color = color
        self.viewId = viewId
        self._chartViewModel = ObservedObject(wrappedValue: chartViewModel)
        self._primaryViewModel = ObservedObject(wrappedValue: primaryViewModel)
        self.ownsViewModels = false
    }

    var body: some View {
        chartView
            .metricScreenBackground(color: color)
            .sheet(isPresented: $showAboutModal) {
                MetricEducationModal(
                    viewId: metricId,
                    metricName: metricName,
                    color: color,
                    isPresented: $showAboutModal
                )
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showDataManagement = true
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    FavoriteButton(
                        itemType: .metric,
                        itemId: viewId,
                        displayName: metricName,
                        pillar: "Restorative Sleep",
                        cardId: nil,
                        sectionId: "NAV_SLEEP"
                    )

                    Button {
                        showEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showEntry) {
                SleepEntryView()
            }
            .sheet(isPresented: $showDataManagement) {
                SleepDataManagementView(color: color)
            }
            .task {
                // Only load data if we own the view models (standalone mode)
                if ownsViewModels {
                    await loadSleepDataForPeriod(selectedPeriod)
                    await primaryViewModel.loadPrimaryScreen()
                }
            }
    }

    private func loadSleepDataForPeriod(_ period: SleepPeriod) async {
        // Load 10 years back, 1 year forward for smooth scrolling
        switch period {
        case .day:
            await chartViewModel.loadInitialSleepStages(daysBack: 365 * 10, daysAhead: 365)
        case .week:
            await chartViewModel.loadInitialSleepStages(daysBack: 365 * 10, daysAhead: 365)
        case .month:
            await chartViewModel.loadInitialSleepStages(daysBack: 365 * 10, daysAhead: 365)
        case .sixMonth:
            break // 6M view uses WeeklySleepDataManager which loads on its own
        }
    }

    private var chartView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Period selector (D/W/M/6M)
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(SleepPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, MetricScreenLayout.pickerTopPadding)
                .onChange(of: selectedPeriod) { _, newPeriod in
                    selectedStage = nil
                    Task {
                        await loadSleepDataForPeriod(newPeriod)
                    }
                }

                // Chart content
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
                        DayViewChart(
                            color: color,
                            viewModel: chartViewModel,
                            selectedStage: $selectedStage,
                            onVisibleRangeChange: { start, end in
                                visibleDateRange = (start, end)
                            },
                            height: 340,
                            showAbout: $showAboutModal
                        )
                    case .week:
                        ScrollableSleepChart(viewMode: .week, viewModel: chartViewModel, selectedStage: $selectedStage, visibleRangeBinding: $visibleDateRange, height: 340, showAbout: $showAboutModal)
                    case .month:
                        ScrollableSleepChart(viewMode: .month, viewModel: chartViewModel, selectedStage: $selectedStage, visibleRangeBinding: $visibleDateRange, height: 340, showAbout: $showAboutModal)
                    case .sixMonth:
                        WeeklySleepChart(viewModel: chartViewModel, selectedStage: $selectedStage, visibleRangeBinding: $visibleDateRange, height: 340, showAbout: $showAboutModal)
                    }
                }

                // Stage duration buttons
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
                .padding(.bottom, 20)
            }
            .padding(.vertical)
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }

    // MARK: - Helpers

    private var stageDurations: [(stage: SleepStage, duration: Double?)] {
        let stages: [SleepStage] = [.awake, .rem, .core, .deep]
        let calendar = Calendar.current

        // Get visible segments based on period
        let visibleSegments: [SleepStageSegment]

        if selectedPeriod == .day {
            if let range = visibleDateRange {
                let visibleSession = chartViewModel.sleepSessions.first { session in
                    let sessionDate = calendar.startOfDay(for: session.date)
                    return sessionDate >= range.start && sessionDate < range.end
                }
                visibleSegments = visibleSession?.segments ?? []
            } else {
                visibleSegments = chartViewModel.sleepSessions.first?.segments ?? []
            }
        } else if let range = visibleDateRange {
            let visibleSessions = chartViewModel.sleepSessions.filter { session in
                let sessionDate = calendar.startOfDay(for: session.date)
                return sessionDate >= range.start && sessionDate <= range.end
            }
            visibleSegments = visibleSessions.flatMap { $0.segments }
        } else {
            visibleSegments = chartViewModel.sleepStageSegments
        }

        return stages.map { stage in
            let seconds = visibleSegments
                .filter { $0.stage == stage }
                .reduce(0.0) { total, segment in
                    total + segment.endTime.timeIntervalSince(segment.startTime)
                }

            let minutes = seconds / 60.0

            if selectedPeriod != .day {
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
                return (stage, minutes > 0 ? minutes : nil)
            }
        }
    }

    private func stageName(for stage: SleepStage) -> String {
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

// MARK: - Legacy alias for backwards compatibility
typealias SleepAmountsFullView = SleepAmountsView

#Preview {
    NavigationStack {
        SleepAmountsView(color: .indigo, viewId: "DISP_SLEEP_AMOUNTS")
    }
}
