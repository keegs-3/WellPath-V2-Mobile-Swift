//
//  VegetablesScreen.swift
//  WellPath
//
//  Card-based layout for Vegetables metric.
//  Uses shared NutrientScreen with vegetables configuration.
//

import SwiftUI

struct VegetablesScreen: View {
    let pillar: String
    let color: Color

    var body: some View {
        NutrientScreen(config: .vegetables, pillar: pillar, color: color)
    }
}

#Preview {
    NavigationStack {
        VegetablesScreen(pillar: "Healthful Nutrition", color: .green)
    }
}
