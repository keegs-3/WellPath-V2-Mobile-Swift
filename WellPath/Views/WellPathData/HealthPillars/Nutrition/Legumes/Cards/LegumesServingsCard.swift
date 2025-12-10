//
//  LegumesServingsCard.swift
//  WellPath
//
//  Card component for Legumes Servings metric.
//

import SwiftUI

struct LegumesServingsCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        NutrientServingsCard(config: .legumes, color: color, pillar: pillar)
    }
}

#Preview {
    LegumesServingsCard(color: .brown, pillar: "Healthful Nutrition")
        .padding()
}
