//
//  SleepAmountsCard.swift
//  WellPath
//
//  Reusable card for Sleep Stage Amounts metric.
//  Can be used in SleepAnalysisScreen and Favorites.
//

import SwiftUI

struct SleepAmountsCard: View {
    let color: Color
    let pillar: String
    let viewId: String

    @StateObject private var chartViewModel = SleepAnalysisViewModel()
    @StateObject private var primaryViewModel: SleepAnalysisPrimaryViewModel

    init(color: Color, pillar: String, viewId: String = "DISP_SLEEP_AMOUNTS") {
        self.color = color
        self.pillar = pillar
        self.viewId = viewId
        self._primaryViewModel = StateObject(wrappedValue: SleepAnalysisPrimaryViewModel(viewId: viewId))
    }

    var body: some View {
        MetricCardView(
            title: "Stage Amounts",
            color: color,
            metricId: viewId,
            pillar: pillar
        ) {
            SleepAmountsMiniCard(color: color, chartViewModel: chartViewModel)
        } fullScreen: {
            SleepAmountsView(color: color, viewId: viewId, chartViewModel: chartViewModel, primaryViewModel: primaryViewModel)
        }
        .task {
            await chartViewModel.loadInitialSleepStages(daysBack: 7, daysAhead: 0)
            await primaryViewModel.loadPrimaryScreen()
        }
    }
}

#Preview {
    SleepAmountsCard(color: .indigo, pillar: "Restorative Sleep")
        .padding()
}
