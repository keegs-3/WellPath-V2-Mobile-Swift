//
//  SleepPercentagesView.swift
//  WellPath
//
//  Full view for Sleep Stage Percentages (% of total sleep per stage).
//  Standalone view - receives viewId from navigation for database-driven content.
//

import SwiftUI

struct SleepPercentagesView: View {
    let color: Color
    let viewId: String
    @ObservedObject private var chartViewModel: SleepAnalysisViewModel
    @ObservedObject private var primaryViewModel: SleepAnalysisPrimaryViewModel
    @State private var showEntry = false
    @State private var showDataManagement = false
    @State private var showAboutModal = false

    // Track if we own the view models (for standalone use)
    private let ownsViewModels: Bool

    private var metricId: String { viewId }
    private let metricName = "Stage Percentages"

    /// Standalone initializer - creates its own view models
    init(color: Color, viewId: String = "DISP_SLEEP_PERCENTAGES") {
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
        // Use SleepPercentagesChart which is a fully self-contained chart component
        SleepPercentagesChart(color: color, sleepViewModel: chartViewModel)
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
typealias SleepPercentagesFullView = SleepPercentagesView

#Preview {
    NavigationStack {
        SleepPercentagesView(color: .indigo, viewId: "DISP_SLEEP_PERCENTAGES")
    }
}
