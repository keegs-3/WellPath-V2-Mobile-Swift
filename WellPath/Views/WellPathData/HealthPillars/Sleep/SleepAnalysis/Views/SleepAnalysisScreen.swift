//
//  SleepAnalysisScreen.swift
//  WellPath
//
//  Card-based layout for Sleep Analysis metric.
//  Cards are reusable components defined in Cards/ folder.
//

import SwiftUI

struct SleepAnalysisScreen: View {
    let pillar: String
    let color: Color

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Sleep Analysis")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Reusable card components (defined in Cards/ folder)
                // Each card receives its viewId from the database
                SleepStagesCard(color: color, pillar: pillar, viewId: "DISP_SLEEP_STAGES")
                SleepAmountsCard(color: color, pillar: pillar, viewId: "DISP_SLEEP_AMOUNTS")
                SleepPercentagesCard(color: color, pillar: pillar, viewId: "DISP_SLEEP_PERCENTAGES")
                SleepComparisonsCard(color: color, pillar: pillar, viewId: "DISP_SLEEP_COMPARISONS")
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Sleep Analysis")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        SleepAnalysisScreen(pillar: "Restorative Sleep", color: .indigo)
    }
}
