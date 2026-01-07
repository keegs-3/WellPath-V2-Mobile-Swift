//
//  MovementWizardViews.swift
//  WellPath
//
//  Wizard views for Movement + Exercise baseline categories.
//  Uses SimpleBaselineWizardView with category-specific configuration.
//

import SwiftUI

// MARK: - Steps Wizard

struct StepsWizardView: View {
    var body: some View {
        SimpleBaselineWizardView(
            baselineViewId: "BASELINE_VIEW_STEPS",
            categoryId: "CAT_STEPS",
            categoryName: "Steps",
            pillarName: "Movement + Exercise"
        )
    }
}

// MARK: - Cardio Wizard

struct CardioWizardView: View {
    var body: some View {
        SimpleBaselineWizardView(
            baselineViewId: "BASELINE_VIEW_CARDIO",
            categoryId: "CAT_CARDIO",
            categoryName: "Cardio",
            pillarName: "Movement + Exercise"
        )
    }
}

// MARK: - Strength Wizard

struct StrengthWizardView: View {
    var body: some View {
        SimpleBaselineWizardView(
            baselineViewId: "BASELINE_VIEW_STRENGTH",
            categoryId: "CAT_STRENGTH",
            categoryName: "Strength Training",
            pillarName: "Movement + Exercise"
        )
    }
}

// MARK: - HIIT Wizard

struct HIITWizardView: View {
    var body: some View {
        SimpleBaselineWizardView(
            baselineViewId: "BASELINE_VIEW_HIIT",
            categoryId: "CAT_HIIT",
            categoryName: "HIIT",
            pillarName: "Movement + Exercise"
        )
    }
}

// MARK: - Mobility Wizard

struct MobilityWizardView: View {
    var body: some View {
        SimpleBaselineWizardView(
            baselineViewId: "BASELINE_VIEW_MOBILITY",
            categoryId: "CAT_MOBILITY",
            categoryName: "Mobility",
            pillarName: "Movement + Exercise"
        )
    }
}

// MARK: - Daily Activity Wizard

struct DailyActivityWizardView: View {
    var body: some View {
        SimpleBaselineWizardView(
            baselineViewId: "BASELINE_VIEW_DAILY_ACTIVITY",
            categoryId: "CAT_DAILY_ACTIVITY",
            categoryName: "Daily Activity",
            pillarName: "Movement + Exercise"
        )
    }
}

// MARK: - Previews

#Preview("Steps") {
    StepsWizardView()
}

#Preview("Cardio") {
    CardioWizardView()
}

#Preview("Strength") {
    StrengthWizardView()
}

#Preview("HIIT") {
    HIITWizardView()
}

#Preview("Mobility") {
    MobilityWizardView()
}

#Preview("Daily Activity") {
    DailyActivityWizardView()
}
