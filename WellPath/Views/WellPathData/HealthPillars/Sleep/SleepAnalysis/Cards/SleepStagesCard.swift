//
//  SleepStagesCard.swift
//  WellPath
//
//  Reusable card for Sleep Stages metric.
//  Can be used in SleepAnalysisScreen and Favorites.
//

import SwiftUI

struct SleepStagesCard: View {
    let color: Color
    let pillar: String
    let viewId: String

    @StateObject private var chartViewModel = SleepAnalysisViewModel()
    @StateObject private var primaryViewModel: SleepAnalysisPrimaryViewModel

    init(color: Color, pillar: String, viewId: String = "DISP_SLEEP_STAGES") {
        self.color = color
        self.pillar = pillar
        self.viewId = viewId
        self._primaryViewModel = StateObject(wrappedValue: SleepAnalysisPrimaryViewModel(viewId: viewId))
    }

    var body: some View {
        MetricCardView(
            title: "Sleep Stages",
            color: color,
            metricId: viewId,
            pillar: pillar
        ) {
            SleepStagesMiniCard(color: color, chartViewModel: chartViewModel)
        } fullScreen: {
            SleepStagesView(color: color, chartViewModel: chartViewModel, primaryViewModel: primaryViewModel)
        }
        .task {
            await chartViewModel.loadInitialSleepStages(daysBack: 7, daysAhead: 0)
            await primaryViewModel.loadPrimaryScreen()
        }
    }
}

#Preview {
    SleepStagesCard(color: .indigo, pillar: "Restorative Sleep")
        .padding()
}
