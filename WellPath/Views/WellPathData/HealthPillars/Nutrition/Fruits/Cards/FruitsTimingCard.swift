//
//  FruitsTimingCard.swift
//  WellPath
//
//  Card component for Fruits Timing metric.
//

import SwiftUI

struct FruitsTimingCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        NutrientTimingCard(config: .fruits, color: color, pillar: pillar)
    }
}

#Preview {
    FruitsTimingCard(color: .red, pillar: "Healthful Nutrition")
        .padding()
}
