//
//  ProteinTypeBreakdownList.swift
//  WellPath
//
//  List showing protein type breakdown with toggle between detailed/grouped views
//

import SwiftUI

struct ProteinTypeBreakdownList: View {
    let color: Color
    @ObservedObject var viewModel: ProteinTypeChartViewModel
    let selectedPeriod: TimePeriod
    let scrollPosition: Date
    @Binding var showGrouped: Bool
    @Binding var selectedType: String?

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

    private let highQualityTypes = ["Plant-based", "Fatty Fish", "Eggs", "Lean Protein"]
    private let moderateQualityTypes = ["Dairy", "Supplement"]
    private let limitTypes = ["Red Meat", "Processed Meat"]

    var body: some View {
        VStack(spacing: 12) {
            // Toggle between detailed and grouped
            HStack {
                Spacer()
                Picker("View", selection: $showGrouped) {
                    Text("Detailed").tag(false)
                    Text("Grouped").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // List
            if showGrouped {
                groupedListView
            } else {
                detailedListView
            }
        }
        .padding(.bottom, 16)
    }

    private var detailedListView: some View {
        VStack(spacing: 8) {
            ForEach(proteinTypeAggIds, id: \.self) { aggId in
                if let typeName = typeDisplayNames[aggId],
                   let typeColor = typeColors[aggId] {
                    let percentage = viewModel.getPercentageFor(typeName, period: selectedPeriod, scrollPosition: scrollPosition)
                    let grams = viewModel.getAverageFor(typeName, period: selectedPeriod, scrollPosition: scrollPosition)

                    // Only show types with data
                    if percentage > 0 || grams > 0 {
                        typeRow(
                            name: typeName,
                            grams: grams,
                            percentage: percentage,
                            color: typeColor
                        )
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var groupedListView: some View {
        VStack(spacing: 12) {
            // High Quality group
            if let groupData = groupedCategoryData(for: highQualityTypes) {
                groupCard(
                    title: "High Quality",
                    subtitle: "Plant-based, Fish, Eggs, Lean Protein",
                    grams: groupData.grams,
                    percentage: groupData.percentage,
                    color: Color(red: 0.2, green: 0.8, blue: 0.3)
                )
            }

            // Moderate group
            if let groupData = groupedCategoryData(for: moderateQualityTypes) {
                groupCard(
                    title: "Moderate",
                    subtitle: "Dairy, Supplement",
                    grams: groupData.grams,
                    percentage: groupData.percentage,
                    color: Color(red: 0.3, green: 0.6, blue: 0.95)
                )
            }

            // Limit group
            if let groupData = groupedCategoryData(for: limitTypes) {
                groupCard(
                    title: "Limit",
                    subtitle: "Red Meat, Processed Meat",
                    grams: groupData.grams,
                    percentage: groupData.percentage,
                    color: Color(red: 1.0, green: 0.3, blue: 0.3)
                )
            }
        }
        .padding(.horizontal)
    }

    private func typeRow(name: String, grams: Double, percentage: Double, color: Color) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if selectedType == name {
                    selectedType = nil
                } else {
                    selectedType = name
                }
            }
        } label: {
            HStack(spacing: 12) {
                // Color indicator
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)

                // Type name
                Text(name)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Grams and percentage
                Text(formatValue(grams))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text("g")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("(\(Int(percentage.rounded()))%)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .trailing)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedType == name ? color.opacity(0.15) : Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func groupCard(title: String, subtitle: String, grams: Double, percentage: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 16, height: 16)

                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(formatValue(grams))g")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("(\(Int(percentage.rounded()))%)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private func groupedCategoryData(for typeNames: [String]) -> (grams: Double, percentage: Double)? {
        var totalGrams = 0.0
        var totalPercentage = 0.0

        for typeName in typeNames {
            totalGrams += viewModel.getAverageFor(typeName, period: selectedPeriod, scrollPosition: scrollPosition)
            totalPercentage += viewModel.getPercentageFor(typeName, period: selectedPeriod, scrollPosition: scrollPosition)
        }

        guard totalGrams > 0 || totalPercentage > 0 else { return nil }

        return (grams: totalGrams, percentage: totalPercentage)
    }

    private func formatValue(_ value: Double) -> String {
        if value == 0 {
            return "0"
        } else if value >= 100 {
            return String(format: "%.0f", value)
        } else if value >= 10 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}
