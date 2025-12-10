//
//  LegumesScreen.swift
//  WellPath
//
//  Card-based layout for Legumes metric.
//  Uses shared NutrientScreen with legumes configuration.
//

import SwiftUI

struct LegumesScreen: View {
    let pillar: String
    let color: Color

    var body: some View {
        NutrientScreen(config: .legumes, pillar: pillar, color: color)
    }
}

#Preview {
    NavigationStack {
        LegumesScreen(pillar: "Healthful Nutrition", color: .green)
    }
}
