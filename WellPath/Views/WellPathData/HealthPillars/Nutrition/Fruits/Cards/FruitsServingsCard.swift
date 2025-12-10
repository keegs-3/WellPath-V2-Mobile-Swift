//
//  FruitsServingsCard.swift
//  WellPath
//
//  Card component for Fruits Servings metric.
//

import SwiftUI

struct FruitsServingsCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        NutrientServingsCard(config: .fruits, color: color, pillar: pillar)
    }
}

#Preview {
    FruitsServingsCard(color: .red, pillar: "Healthful Nutrition")
        .padding()
}
