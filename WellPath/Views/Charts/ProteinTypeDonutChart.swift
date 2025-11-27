//
//  ProteinTypeDonutChart.swift
//  WellPath
//
//  Donut chart visualization for protein type distribution
//  Replaces stacked bar chart with cleaner donut + list view
//

import SwiftUI
import Charts

struct ProteinTypeDonutChart: View {
    let color: Color
    @ObservedObject var viewModel: ProteinTypeChartViewModel
    let selectedPeriod: TimePeriod
    let scrollPosition: Date
    let showGrouped: Bool

    @State private var selectedType: String?

    // Type definitions (same as ProteinTypeStackedChart)
    private let proteinTypeAggIds = [
        "AGG_PROTEIN_TYPE_PLANT_BASED",
        "AGG_PROTEIN_TYPE_FATTY_FISH",
        "AGG_PROTEIN_TYPE_EGGS",
        "AGG_PROTEIN_TYPE_LEAN_PROTEIN",
        "AGG_PROTEIN_TYPE_DAIRY",
        "AGG_PROTEIN_TYPE_SUPPLEMENT",
        "AGG_PROTEIN_TYPE_RED_MEAT",
        "AGG_PROTEIN_TYPE_PROCESSED_MEAT",
        "AGG_PROTEIN_TYPE_OTHER",
        "AGG_PROTEIN_TYPE_UNASSIGNED"
    ]

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

    private let typeColors: [String: Color] = [
        "AGG_PROTEIN_TYPE_PLANT_BASED": Color(red: 0.2, green: 0.8, blue: 0.3),
        "AGG_PROTEIN_TYPE_FATTY_FISH": Color(red: 0.3, green: 0.9, blue: 0.5),
        "AGG_PROTEIN_TYPE_EGGS": Color(red: 0.5, green: 0.95, blue: 0.6),
        "AGG_PROTEIN_TYPE_LEAN_PROTEIN": Color(red: 0.6, green: 1.0, blue: 0.7),
        "AGG_PROTEIN_TYPE_DAIRY": Color(red: 0.3, green: 0.6, blue: 0.95),
        "AGG_PROTEIN_TYPE_SUPPLEMENT": Color(red: 0.5, green: 0.75, blue: 1.0),
        "AGG_PROTEIN_TYPE_RED_MEAT": Color(red: 1.0, green: 0.8, blue: 0.2),
        "AGG_PROTEIN_TYPE_PROCESSED_MEAT": Color(red: 1.0, green: 0.3, blue: 0.3),
        "AGG_PROTEIN_TYPE_OTHER": Color(red: 0.9, green: 0.9, blue: 0.9),
        "AGG_PROTEIN_TYPE_UNASSIGNED": Color(red: 0.85, green: 0.85, blue: 0.85)
    ]

    // Quality tier groupings
    private let highQualityTypes = ["Plant-based", "Fatty Fish", "Eggs", "Lean Protein"]
    private let moderateQualityTypes = ["Dairy", "Supplement"]
    private let limitTypes = ["Red Meat", "Processed Meat"]

    private var chartData: [(String, Double, Color)] {
        if showGrouped {
            return groupedData
        } else {
            return detailedData
        }
    }

    private var detailedData: [(String, Double, Color)] {
        proteinTypeAggIds.compactMap { aggId in
            guard let typeName = typeDisplayNames[aggId],
                  let typeColor = typeColors[aggId] else { return nil }

            let percentage = viewModel.getPercentageFor(typeName, period: selectedPeriod, scrollPosition: scrollPosition)

            // Only include types with data
            guard percentage > 0 else { return nil }

            return (typeName, percentage, typeColor)
        }
    }

    private var groupedData: [(String, Double, Color)] {
        var highQualityTotal = 0.0
        var moderateTotal = 0.0
        var limitTotal = 0.0
        var otherTotal = 0.0

        for aggId in proteinTypeAggIds {
            guard let typeName = typeDisplayNames[aggId] else { continue }
            let percentage = viewModel.getPercentageFor(typeName, period: selectedPeriod, scrollPosition: scrollPosition)

            if highQualityTypes.contains(typeName) {
                highQualityTotal += percentage
            } else if moderateQualityTypes.contains(typeName) {
                moderateTotal += percentage
            } else if limitTypes.contains(typeName) {
                limitTotal += percentage
            } else {
                otherTotal += percentage
            }
        }

        var result: [(String, Double, Color)] = []
        if highQualityTotal > 0 {
            result.append(("High Quality", highQualityTotal, Color(red: 0.2, green: 0.8, blue: 0.3)))
        }
        if moderateTotal > 0 {
            result.append(("Moderate", moderateTotal, Color(red: 0.3, green: 0.6, blue: 0.95)))
        }
        if limitTotal > 0 {
            result.append(("Limit", limitTotal, Color(red: 1.0, green: 0.3, blue: 0.3)))
        }
        if otherTotal > 0 {
            result.append(("Other", otherTotal, Color(red: 0.85, green: 0.85, blue: 0.85)))
        }

        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            if chartData.isEmpty {
                Text("No protein data for this period")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                // Donut chart
                Chart {
                    ForEach(Array(chartData.enumerated()), id: \.offset) { index, item in
                        SectorMark(
                            angle: .value("Percentage", item.1),
                            innerRadius: .ratio(0.618), // Golden ratio
                            angularInset: 1.5
                        )
                        .cornerRadius(4)
                        .foregroundStyle(item.2)
                        .opacity(selectedType == nil || selectedType == item.0 ? 1.0 : 0.3)
                    }
                }
                .frame(height: 160)
                .padding(.top, 16)
            }
        }
    }
}
