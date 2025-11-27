//
//  MealTimingCard.swift
//  WellPath
//
//  Individual meal card for timeline view showing protein distribution
//

import SwiftUI

struct MealTimingCard: View {
    let mealName: String
    let grams: Double
    let percentage: Double
    let color: Color
    let showConnectingLine: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Vertical timeline with dot
            VStack(spacing: 0) {
                if showConnectingLine {
                    Rectangle()
                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                        .frame(width: 2)
                        .frame(height: 20)
                }

                // Simple dot marker
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)

                Rectangle()
                    .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                    .frame(width: 2)
                    .frame(height: 20)
            }
            .frame(width: 40)

            // Card content
            VStack(alignment: .leading, spacing: 8) {
                // Meal name
                Text(mealName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

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
            }
            .padding(.horizontal, 12)

            // Values
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatValue(grams))
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("\(Int(percentage.rounded()))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 60)
            .padding(.trailing, 12)
        }
        .padding(.vertical, 12)
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
    VStack(spacing: 0) {
        MealTimingCard(
            mealName: "Breakfast",
            grams: 28.5,
            percentage: 35,
            color: .green,
            showConnectingLine: false
        )

        MealTimingCard(
            mealName: "Lunch",
            grams: 18.2,
            percentage: 23,
            color: .green.opacity(0.7),
            showConnectingLine: true
        )

        MealTimingCard(
            mealName: "Dinner",
            grams: 30.0,
            percentage: 38,
            color: .green.opacity(0.4),
            showConnectingLine: true
        )
    }
    .padding()
}
