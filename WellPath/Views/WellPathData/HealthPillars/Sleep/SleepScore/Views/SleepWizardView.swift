//
//  SleepWizardView.swift
//  WellPath
//
//  Baseline wizard for unified Sleep Score category.
//

import SwiftUI

struct SleepWizardView: View {
    var body: some View {
        SimpleBaselineWizardView(
            baselineViewId: "BASELINE_VIEW_SLEEP",
            categoryId: "CAT_SLEEP",
            categoryName: "Sleep",
            pillarName: "Restorative Sleep",
            scoreId: "SCORE_SLEEP",
            scoreType: "sleep_score"
        )
    }
}

#Preview {
    SleepWizardView()
}
