//
//  SleepStagesView.swift
//  WellPath
//
//  Full view for Sleep Stages hypnogram visualization.
//  Receives viewId from navigation for database-driven content.
//

import SwiftUI

struct SleepStagesView: View {
    let color: Color
    let viewId: String
    @ObservedObject private var chartViewModel: SleepAnalysisViewModel
    @ObservedObject private var primaryViewModel: SleepAnalysisPrimaryViewModel
    @State private var selectedPeriod: SleepPeriod = .day
    @State private var showAboutModal = false
    @State private var showEntry = false
    @State private var showDataManagement = false

    // Track if we own the view models (for standalone use)
    private let ownsViewModels: Bool

    enum SleepPeriod: String, CaseIterable {
        case day = "D"
        case week = "W"
        case month = "M"
        case sixMonth = "6M"
    }

    private var metricId: String { viewId }
    private let metricName = "Sleep Stages"

    /// Standalone initializer - creates its own view models
    init(color: Color, viewId: String = "DISP_SLEEP_STAGES") {
        self.color = color
        self.viewId = viewId
        self._chartViewModel = ObservedObject(wrappedValue: SleepAnalysisViewModel())
        self._primaryViewModel = ObservedObject(wrappedValue: SleepAnalysisPrimaryViewModel(viewId: viewId))
        self.ownsViewModels = true
    }

    /// Card initializer - uses passed view models (for SleepStagesCard)
    init(color: Color, chartViewModel: SleepAnalysisViewModel, primaryViewModel: SleepAnalysisPrimaryViewModel) {
        self.color = color
        self.viewId = primaryViewModel.viewId
        self._chartViewModel = ObservedObject(wrappedValue: chartViewModel)
        self._primaryViewModel = ObservedObject(wrappedValue: primaryViewModel)
        self.ownsViewModels = false
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Period selector
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(SleepPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, MetricScreenLayout.pickerTopPadding)
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
                } else if chartViewModel.sleepSessions.isEmpty {
                    // Empty state when no sleep data
                    VStack(spacing: 12) {
                        Image(systemName: "moon.zzz")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No sleep data")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Sleep data will appear here once synced from HealthKit or entered manually.")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                } else {
                    switch selectedPeriod {
                    case .day:
                        DayViewChart(color: color, viewModel: chartViewModel, selectedStage: .constant(nil), showAbout: $showAboutModal)
                    case .week:
                        ScrollableSleepChart(viewMode: .week, viewModel: chartViewModel, selectedStage: .constant(nil), showAbout: $showAboutModal)
                    case .month:
                        ScrollableSleepChart(viewMode: .month, viewModel: chartViewModel, selectedStage: .constant(nil), showAbout: $showAboutModal)
                    case .sixMonth:
                        WeeklySleepChart(viewModel: chartViewModel, selectedStage: .constant(nil), showAbout: $showAboutModal)
                    }
                }
            }
            .padding(.vertical)
            .background(Color(uiColor: .systemGroupedBackground))
        }
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
                await chartViewModel.loadInitialSleepStages(daysBack: 7, daysAhead: 0)
                await primaryViewModel.loadPrimaryScreen()
            }
        }
    }
}

// MARK: - Legacy alias for backwards compatibility
typealias SleepStagesFullView = SleepStagesView

#Preview {
    NavigationStack {
        SleepStagesView(color: .indigo, viewId: "DISP_SLEEP_STAGES")
    }
}
