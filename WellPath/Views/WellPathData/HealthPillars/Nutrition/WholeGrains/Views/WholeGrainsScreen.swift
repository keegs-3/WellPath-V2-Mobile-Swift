//
//  WholeGrainsScreen.swift
//  WellPath
//
//  Card-based layout for Whole Grains metric.
//  Uses shared NutrientScreen with whole grains configuration.
//

import SwiftUI

struct WholeGrainsScreen: View {
    let pillar: String
    let color: Color

    var body: some View {
        NutrientScreen(config: .wholeGrains, pillar: pillar, color: color)
    }
}

#Preview {
    NavigationStack {
        WholeGrainsScreen(pillar: "Healthful Nutrition", color: .orange)
    }
}
