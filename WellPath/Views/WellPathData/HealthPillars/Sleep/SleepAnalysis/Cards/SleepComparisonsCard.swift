//
//  SleepComparisonsCard.swift
//  WellPath
//
//  Reusable card for Sleep Comparisons metric.
//  Can be used in SleepAnalysisScreen and Favorites.
//

import SwiftUI

struct SleepComparisonsCard: View {
    let color: Color
    let pillar: String
    let viewId: String

    @StateObject private var primaryViewModel: SleepAnalysisPrimaryViewModel

    init(color: Color, pillar: String, viewId: String = "DISP_SLEEP_COMPARISONS") {
        self.color = color
        self.pillar = pillar
        self.viewId = viewId
        self._primaryViewModel = StateObject(wrappedValue: SleepAnalysisPrimaryViewModel(viewId: viewId))
    }

    var body: some View {
        MetricCardView(
            title: "Comparisons",
            color: color,
            metricId: viewId,
            pillar: pillar
        ) {
            SleepComparisonsMiniCard(color: color)
        } fullScreen: {
            SleepComparisonsView(color: color, viewId: viewId, primaryViewModel: primaryViewModel)
        }
        .task {
            await primaryViewModel.loadPrimaryScreen()
        }
    }
}

#Preview {
    SleepComparisonsCard(color: .indigo, pillar: "Restorative Sleep")
        .padding()
}
