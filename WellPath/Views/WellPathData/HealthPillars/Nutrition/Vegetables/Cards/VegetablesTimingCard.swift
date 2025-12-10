//
//  VegetablesTimingCard.swift
//  WellPath
//
//  Card component for Vegetables Timing metric.
//

import SwiftUI

struct VegetablesTimingCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        NutrientTimingCard(config: .vegetables, color: color, pillar: pillar)
    }
}

#Preview {
    VegetablesTimingCard(color: .green, pillar: "Healthful Nutrition")
        .padding()
}
