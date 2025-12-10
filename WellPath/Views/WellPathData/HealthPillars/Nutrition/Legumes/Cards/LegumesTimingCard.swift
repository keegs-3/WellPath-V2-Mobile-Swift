//
//  LegumesTimingCard.swift
//  WellPath
//
//  Card component for Legumes Timing metric.
//

import SwiftUI

struct LegumesTimingCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        NutrientTimingCard(config: .legumes, color: color, pillar: pillar)
    }
}

#Preview {
    LegumesTimingCard(color: .brown, pillar: "Healthful Nutrition")
        .padding()
}
