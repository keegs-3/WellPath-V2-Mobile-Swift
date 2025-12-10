//
//  SleepPercentagesCard.swift
//  WellPath
//
//  Reusable card for Sleep Stage Percentages metric.
//  Can be used in SleepAnalysisScreen and Favorites.
//

import SwiftUI

struct SleepPercentagesCard: View {
    let color: Color
    let pillar: String
    let viewId: String

    @StateObject private var chartViewModel = SleepAnalysisViewModel()
    @StateObject private var primaryViewModel: SleepAnalysisPrimaryViewModel

    init(color: Color, pillar: String, viewId: String = "DISP_SLEEP_PERCENTAGES") {
        self.color = color
        self.pillar = pillar
        self.viewId = viewId
        self._primaryViewModel = StateObject(wrappedValue: SleepAnalysisPrimaryViewModel(viewId: viewId))
    }

    var body: some View {
        MetricCardView(
            title: "Stage Percentages",
            color: color,
            metricId: viewId,
            pillar: pillar
        ) {
            SleepPercentagesMiniCard(color: color, chartViewModel: chartViewModel)
        } fullScreen: {
            SleepPercentagesView(color: color, viewId: viewId, chartViewModel: chartViewModel, primaryViewModel: primaryViewModel)
        }
        .task {
            await chartViewModel.loadInitialSleepStages(daysBack: 7, daysAhead: 0)
            await primaryViewModel.loadPrimaryScreen()
        }
    }
}

#Preview {
    SleepPercentagesCard(color: .indigo, pillar: "Restorative Sleep")
        .padding()
}
