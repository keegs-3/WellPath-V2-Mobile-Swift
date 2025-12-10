//
//  LegumesTypeCard.swift
//  WellPath
//
//  Card component for Legumes Type metric.
//

import SwiftUI

struct LegumesTypeCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        NutrientTypeCard(config: .legumes, color: color, pillar: pillar)
    }
}

#Preview {
    LegumesTypeCard(color: .brown, pillar: "Healthful Nutrition")
        .padding()
}
