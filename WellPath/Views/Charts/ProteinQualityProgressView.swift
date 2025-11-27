//
//  ProteinQualityProgressView.swift
//  WellPath
//
//  Shows progress toward protein quality goal (80% from high quality sources)
//

import SwiftUI

struct ProteinQualityProgressView: View {
    let color: Color
    @ObservedObject var viewModel: ProteinTypeChartViewModel
    let selectedPeriod: TimePeriod
    let scrollPosition: Date

    private let qualityGoal = 0.80 // 80% from quality sources

    private let typeDisplayNames: [String: String] = [
        "AGG_PROTEIN_TYPE_DAIRY": "Dairy",
        "AGG_PROTEIN_TYPE_EGGS": "Eggs",
        "AGG_PROTEIN_TYPE_FATTY_FISH": "Fatty Fish",
        "AGG_PROTEIN_TYPE_LEAN_PROTEIN": "Lean Protein",
        "AGG_PROTEIN_TYPE_PLANT_BASED": "Plant-based",
        "AGG_PROTEIN_TYPE_PROCESSED_MEAT": "Processed Meat",
        "AGG_PROTEIN_TYPE_RED_MEAT": "Red Meat",
        "AGG_PROTEIN_TYPE_SUPPLEMENT": "Supplement",
        "AGG_PROTEIN_TYPE_OTHER": "Other",
        "AGG_PROTEIN_TYPE_UNASSIGNED": "Unassigned"
    ]

    private let highQualityTypes = ["Plant-based", "Fatty Fish", "Eggs", "Lean Protein"]

    private var currentQualityPercentage: Double {
        var highQualityTotal = 0.0
        var allTypesTotal = 0.0

        for (_, typeName) in typeDisplayNames {
            let percentage = viewModel.getPercentageFor(typeName, period: selectedPeriod, scrollPosition: scrollPosition)
            allTypesTotal += percentage

            if highQualityTypes.contains(typeName) {
                highQualityTotal += percentage
            }
        }

        guard allTypesTotal > 0 else { return 0 }
        return highQualityTotal / allTypesTotal
    }

    private var progressColor: Color {
        if currentQualityPercentage >= qualityGoal {
            return Color(red: 0.2, green: 0.8, blue: 0.3) // Green
        } else if currentQualityPercentage >= 0.6 {
            return Color(red: 1.0, green: 0.8, blue: 0.2) // Yellow
        } else {
            return Color(red: 1.0, green: 0.3, blue: 0.3) // Red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quality Progress")
                .font(.headline)
                .foregroundColor(.primary)

            HStack(spacing: 12) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                            .frame(height: 12)

                        // Progress fill
                        RoundedRectangle(cornerRadius: 8)
                            .fill(progressColor)
                            .frame(width: geometry.size.width * min(currentQualityPercentage, 1.0), height: 12)
                    }
                }
                .frame(height: 12)

                // Percentage label
                Text(String(format: "%.0f%%", currentQualityPercentage * 100))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(progressColor)
                    .frame(width: 50, alignment: .trailing)
            }

            Text("Goal: \(Int(qualityGoal * 100))% from quality sources")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
