//
//  VegetablesServingsCard.swift
//  WellPath
//
//  Card component for Vegetables Servings metric.
//

import SwiftUI

struct VegetablesServingsCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        NutrientServingsCard(config: .vegetables, color: color, pillar: pillar)
    }
}

#Preview {
    VegetablesServingsCard(color: .green, pillar: "Healthful Nutrition")
        .padding()
}
