//
//  MealCard.swift
//  WellPath
//
//  Simple meal card without timeline (timeline is external)
//

import SwiftUI

struct MealCard: View {
    let mealName: String
    let grams: Double
    let percentage: Double
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            // Meal name
            Text(mealName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                        .frame(height: 8)

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * min(percentage / 100.0, 1.0), height: 8)
                }
            }
            .frame(height: 8)
            .frame(maxWidth: .infinity)

            // Values
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatValue(grams))
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("\(Int(percentage.rounded()))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func formatValue(_ value: Double) -> String {
        if value == 0 {
            return "0g"
        } else if value >= 100 {
            return String(format: "%.0fg", value)
        } else if value >= 10 {
            return String(format: "%.1fg", value)
        } else {
            return String(format: "%.2fg", value)
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        MealCard(
            mealName: "Breakfast",
            grams: 200.0,
            percentage: 80,
            color: .blue
        )

        MealCard(
            mealName: "Dinner",
            grams: 50.0,
            percentage: 20,
            color: .blue.opacity(0.6)
        )
    }
    .padding()
}
