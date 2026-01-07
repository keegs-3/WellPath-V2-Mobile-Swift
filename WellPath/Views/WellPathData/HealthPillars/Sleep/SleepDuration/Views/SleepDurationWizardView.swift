//
//  SleepDurationWizardView.swift
//  WellPath
//
//  Baseline wizard for Sleep Duration category.
//

import SwiftUI

struct SleepDurationWizardView: View {
    var body: some View {
        SimpleBaselineWizardView(
            baselineViewId: "BASELINE_VIEW_SLEEP_DURATION",
            categoryId: "CAT_SLEEP",
            categoryName: "Sleep Duration",
            pillarName: "Restorative Sleep",
            scoreId: "SCORE_SLEEP_DURATION",
            scoreType: "sleep_duration_score"
        )
    }
}

#Preview {
    SleepDurationWizardView()
}
