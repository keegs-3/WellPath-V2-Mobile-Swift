//
//  ComponentContributionChart.swift
//  WellPath
//
//  Pie chart showing 3-component contribution (biomarkers, behaviors, education)
//

import SwiftUI
import Charts

struct ComponentContributionChart: View {
    let pillarName: String
    let pillarColor: Color
    @State private var selectedComponent: String?

    private var componentData: [(String, Double, Color)] {
        let biomarkersWeight = PillarWeightConfig.weight(for: pillarName, component: "biomarkers")
        let behaviorsWeight = PillarWeightConfig.weight(for: pillarName, component: "behaviors")
        let educationWeight = PillarWeightConfig.weight(for: pillarName, component: "education")

        return [
            ("Biomarkers", biomarkersWeight * 100, pillarColor.opacity(0.9)),
            ("Behaviors", behaviorsWeight * 100, pillarColor.opacity(0.6)),
            ("Education", educationWeight * 100, pillarColor.opacity(0.3))
        ]
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("Category Allocation")
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 8)

            // Pie chart
            Chart {
                ForEach(Array(componentData.enumerated()), id: \.offset) { index, item in
                    SectorMark(
                        angle: .value("Percentage", item.1),
                        innerRadius: .ratio(0.618),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(item.2)
                    .opacity(selectedComponent == nil || selectedComponent == item.0 ? 1.0 : 0.3)
                }
            }
            .frame(height: 200)

            // Legend
            VStack(spacing: 12) {
                ForEach(Array(componentData.enumerated()), id: \.offset) { index, item in
                    Button(action: {
                        // Toggle selection: tap again to deselect
                        if selectedComponent == item.0 {
                            selectedComponent = nil
                        } else {
                            selectedComponent = item.0
                        }
                    }) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(item.2)
                                .frame(width: 16, height: 16)

                            Text(item.0)
                                .font(.body)
                                .foregroundColor(.primary)

                            Spacer()

                            Text("\(Int(item.1.rounded()))%")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            selectedComponent == item.0 ?
                            Color(uiColor: .tertiarySystemGroupedBackground) :
                            Color(uiColor: .secondarySystemGroupedBackground)
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(white: 0.95))
        .cornerRadius(12)
    }
}

#Preview {
    ComponentContributionChart(
        pillarName: "Healthful Nutrition",
        pillarColor: MetricsUIConfig.getPillarColor(for: "Healthful Nutrition")
    )
}
