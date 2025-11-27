//
//  TimingStatsView.swift
//  WellPath
//
//  Simple factual stats about protein timing (no recommendations)
//

import SwiftUI

struct TimingStatsView: View {
    let color: Color
    let mealData: [(name: String, grams: Double, percentage: Double)]
    let avgPerMeal: Double    // Total protein / number of entries
    let entriesCount: Int     // From patient_samples count

    private var topMeal: String? {
        mealData.max(by: { $0.grams < $1.grams })?.name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 18))
                    .foregroundColor(color)
                Text("Summary")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }

            // Stats row - cleaner layout
            HStack(spacing: 16) {
                // Average per meal
                VStack(alignment: .center, spacing: 4) {
                    Text(formatValue(avgPerMeal))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    Text("avg per meal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Divider()
                    .frame(height: 40)

                // Entries
                VStack(alignment: .center, spacing: 4) {
                    Text("\(entriesCount)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    Text("entries")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                // Top meal (if we have one)
                if let top = topMeal {
                    Divider()
                        .frame(height: 40)

                    VStack(alignment: .center, spacing: 4) {
                        Text(top)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text("top meal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func formatValue(_ value: Double) -> String {
        if value == 0 {
            return "0g"
        } else if value >= 100 {
            return String(format: "%.0fg", value)
        } else {
            return String(format: "%.1fg", value)
        }
    }
}

#Preview {
    TimingStatsView(
        color: .green,
        mealData: [
            (name: "Breakfast", grams: 200, percentage: 80),
            (name: "Dinner", grams: 50, percentage: 20)
        ],
        avgPerMeal: 62.5,
        entriesCount: 4
    )
}
