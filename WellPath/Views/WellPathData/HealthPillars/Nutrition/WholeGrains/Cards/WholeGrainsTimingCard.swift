//
//  WholeGrainsTimingCard.swift
//  WellPath
//
//  Card component for Whole Grains Timing metric.
//

import SwiftUI

struct WholeGrainsTimingCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        NutrientTimingCard(config: .wholeGrains, color: color, pillar: pillar)
    }
}

#Preview {
    WholeGrainsTimingCard(color: .orange, pillar: "Healthful Nutrition")
        .padding()
}
