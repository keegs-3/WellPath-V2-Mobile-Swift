//
//  FruitsTypeCard.swift
//  WellPath
//
//  Card component for Fruits Type metric.
//

import SwiftUI

struct FruitsTypeCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        NutrientTypeCard(config: .fruits, color: color, pillar: pillar)
    }
}

#Preview {
    FruitsTypeCard(color: .red, pillar: "Healthful Nutrition")
        .padding()
}
