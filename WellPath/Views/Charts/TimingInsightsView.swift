//
//  TimingInsightsView.swift
//  WellPath
//
//  Provides guidance-based insights about protein timing patterns
//

import SwiftUI

struct TimingInsightsView: View {
    let color: Color
    let mealData: [(name: String, grams: Double, percentage: Double)]

    private var insights: [String] {
        var tips: [String] = []

        // Find highest and lowest meals
        if let highest = mealData.max(by: { $0.grams < $1.grams }),
           let lowest = mealData.min(by: { $0.grams < $1.grams }) {

            // Distribution balance insight
            if highest.percentage > 40 {
                tips.append("\(Int(highest.percentage))% at \(highest.name.lowercased()) - consider spreading more evenly throughout the day")
            }

            // Consistency insight
            if lowest.grams > 0 && highest.grams / lowest.grams > 3 {
                tips.append("Large variation between meals - aim for more consistent protein distribution")
            }
        }

        // Check for breakfast protein
        if let breakfast = mealData.first(where: { $0.name.lowercased().contains("breakfast") }) {
            if breakfast.grams >= 20 {
                tips.append("Great start! Consistent breakfast protein supports muscle maintenance")
            } else if breakfast.grams > 0 && breakfast.grams < 15 {
                tips.append("Consider increasing breakfast protein to 20-30g for optimal absorption")
            }
        }

        // Best practices (always show if no specific insights)
        if tips.count < 2 {
            tips.append("Aim for 20-30g of protein per major meal for optimal absorption")
        }

        if tips.count < 3 {
            tips.append("Spacing protein intake 3-4 hours apart maximizes muscle protein synthesis")
        }

        return Array(tips.prefix(3)) // Maximum 3 insights
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(color)
                Text("Insights")
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(insights.enumerated()), id: \.offset) { index, insight in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.body)
                            .foregroundColor(color)
                        Text(insight)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

#Preview {
    TimingInsightsView(
        color: .green,
        mealData: [
            (name: "Breakfast", grams: 28, percentage: 35),
            (name: "Lunch", grams: 18, percentage: 23),
            (name: "Dinner", grams: 30, percentage: 38),
            (name: "Snacks", grams: 4, percentage: 5)
        ]
    )
}
