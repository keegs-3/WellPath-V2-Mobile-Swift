//
//  FruitsScreen.swift
//  WellPath
//
//  Card-based layout for Fruits metric.
//  Uses shared NutrientScreen with fruits configuration.
//

import SwiftUI

struct FruitsScreen: View {
    let pillar: String
    let color: Color

    var body: some View {
        NutrientScreen(config: .fruits, pillar: pillar, color: color)
    }
}

#Preview {
    NavigationStack {
        FruitsScreen(pillar: "Healthful Nutrition", color: .red)
    }
}
