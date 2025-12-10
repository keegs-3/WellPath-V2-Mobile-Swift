//
//  WholeGrainsServingsCard.swift
//  WellPath
//
//  Card component for Whole Grains Servings metric.
//

import SwiftUI

struct WholeGrainsServingsCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        NutrientServingsCard(config: .wholeGrains, color: color, pillar: pillar)
    }
}

#Preview {
    WholeGrainsServingsCard(color: .orange, pillar: "Healthful Nutrition")
        .padding()
}
