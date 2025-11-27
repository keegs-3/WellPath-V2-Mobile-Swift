//
//  ProteinTierGroupsView.swift
//  WellPath
//
//  Tier-based protein groups with progress bars and expandable types
//

import SwiftUI

struct ProteinTierGroupsView: View {
    let tierConfig: TierConfig
    let typeData: [String: Double]
    let totalProtein: Double
    @Binding var selectedType: String?
    let viewModel: ProteinTypeDonutViewModel
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            ForEach(tierConfig.tiers) { tier in
                ProteinTierGroupCard(
                    tier: tier,
                    typeData: typeData,
                    totalProtein: totalProtein,
                    selectedType: $selectedType,
                    viewModel: viewModel,
                    color: color
                )
            }
        }
    }
}

struct ProteinTierGroupCard: View {
    let tier: TierConfig.Tier
    let typeData: [String: Double]
    let totalProtein: Double
    @Binding var selectedType: String?
    let viewModel: ProteinTypeDonutViewModel
    let color: Color

    @State private var isExpanded = false

    private var tierGrams: Double {
        tier.proteinTypes.reduce(0.0) { sum, typeId in
            sum + (typeData[typeId] ?? 0)
        }
    }

    private var tierPercentage: Double {
        guard totalProtein > 0 else { return 0 }
        return (tierGrams / totalProtein) * 100
    }

    private var progressValue: Double {
        guard tier.targetPercentage > 0 else { return 0 }
        return tierPercentage / Double(tier.targetPercentage)
    }

    private var progressColor: Color {
        if tier.targetPercentage == 0 {
            return Color.gray
        }

        if progressValue >= 0.9 {
            return Color.green
        } else if progressValue >= 0.6 {
            return Color.yellow
        } else {
            return Color.orange
        }
    }

    // Types in this tier that have data
    private var typesWithData: [String] {
        tier.proteinTypes.filter { typeId in
            (typeData[typeId] ?? 0) > 0
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header (collapsed view)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                VStack(spacing: 12) {
                    HStack {
                        Text(tier.tierName)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(formatValue(tierGrams))g")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Text("(\(Int(tierPercentage.rounded()))%)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                    }

                    // Progress bar
                    if tier.targetPercentage > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Target: \(tier.targetPercentage)%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text("\(Int(tierPercentage.rounded()))/\(tier.targetPercentage)%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(progressColor)
                            }

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // Background
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                                        .frame(height: 8)

                                    // Progress fill (can exceed 100%)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(progressColor)
                                        .frame(width: geometry.size.width * min(progressValue, 1.0), height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Expanded content (individual types with data)
            if isExpanded && !typesWithData.isEmpty {
                VStack(spacing: 8) {
                    ForEach(typesWithData, id: \.self) { typeId in
                        individualTypeRow(typeId)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
            }
        }
    }

    @ViewBuilder
    private func individualTypeRow(_ typeId: String) -> some View {
        let grams = typeData[typeId] ?? 0
        let percentage = totalProtein > 0 ? (grams / totalProtein) * 100 : 0
        let isSelected = selectedType == nil || selectedType == typeId
        let opacity = isSelected ? 1.0 : 0.3

        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                if selectedType == typeId {
                    selectedType = nil
                } else {
                    selectedType = typeId
                }
            }
        }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(viewModel.getColor(for: typeId))
                    .frame(width: 12, height: 12)
                    .opacity(opacity)

                Text(viewModel.getDisplayName(for: typeId))
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .opacity(opacity)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(formatValue(grams))g")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .opacity(opacity)
                    Text("(\(Int(percentage.rounded()))%)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .opacity(opacity)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedType == typeId ? viewModel.getColor(for: typeId).opacity(0.12) : Color(uiColor: .tertiarySystemGroupedBackground))
            )
        }
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

#Preview {
    let sampleConfig = TierConfig(tiers: [
        TierConfig.Tier(tierId: "tier_1", tierName: "Tier 1", targetPercentage: 75, multiplier: 1.233, proteinTypes: ["AGG_PROTEIN_TYPE_PLANT_BASED", "AGG_PROTEIN_TYPE_FATTY_FISH"], tierDescription: "Highest quality protein sources", displayOrder: 1),
        TierConfig.Tier(tierId: "tier_2", tierName: "Tier 2", targetPercentage: 20, multiplier: 0.5, proteinTypes: ["AGG_PROTEIN_TYPE_EGGS", "AGG_PROTEIN_TYPE_DAIRY"], tierDescription: "Beneficial protein sources", displayOrder: 2),
        TierConfig.Tier(tierId: "tier_3", tierName: "Tier 3", targetPercentage: 5, multiplier: -0.5, proteinTypes: ["AGG_PROTEIN_TYPE_RED_MEAT"], tierDescription: "Limit these sources", displayOrder: 3)
    ])

    let sampleData: [String: Double] = [
        "AGG_PROTEIN_TYPE_PLANT_BASED": 50,
        "AGG_PROTEIN_TYPE_EGGS": 30,
        "AGG_PROTEIN_TYPE_RED_MEAT": 10
    ]

    ProteinTierGroupsView(
        tierConfig: sampleConfig,
        typeData: sampleData,
        totalProtein: 90,
        selectedType: .constant(nil),
        viewModel: ProteinTypeDonutViewModel(baseColor: .green),
        color: .green
    )
    .padding()
}
