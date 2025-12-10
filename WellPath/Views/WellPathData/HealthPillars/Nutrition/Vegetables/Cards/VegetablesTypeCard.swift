//
//  VegetablesTypeCard.swift
//  WellPath
//
//  Card component for Vegetables Type metric.
//

import SwiftUI

struct VegetablesTypeCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        NutrientTypeCard(config: .vegetables, color: color, pillar: pillar)
    }
}

#Preview {
    VegetablesTypeCard(color: .green, pillar: "Healthful Nutrition")
        .padding()
}
