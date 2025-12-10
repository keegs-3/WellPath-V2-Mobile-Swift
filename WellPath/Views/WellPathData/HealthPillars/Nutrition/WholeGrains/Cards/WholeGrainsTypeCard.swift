//
//  WholeGrainsTypeCard.swift
//  WellPath
//
//  Card component for Whole Grains Type metric.
//

import SwiftUI

struct WholeGrainsTypeCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        NutrientTypeCard(config: .wholeGrains, color: color, pillar: pillar)
    }
}

#Preview {
    WholeGrainsTypeCard(color: .orange, pillar: "Healthful Nutrition")
        .padding()
}
