//
//  PillarDonutChart.swift
//  WellPath
//
//  Donut chart showing equal 7-pillar contribution
//

import SwiftUI
import Charts

struct PillarDonutChart: View {
    @State private var selectedPillar: String?

    private let pillars = [
        "Healthful Nutrition",
        "Movement + Exercise",
        "Restorative Sleep",
        "Cognitive Health",
        "Stress Management",
        "Connection + Purpose",
        "Core Care"
    ]

    private let percentage = 14.3 // 100 / 7

    var body: some View {
        VStack(spacing: 16) {
            // Donut chart
            Chart {
                ForEach(pillars, id: \.self) { pillar in
                    SectorMark(
                        angle: .value("Count", percentage),
                        innerRadius: .ratio(0.618),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(MetricsUIConfig.getPillarColor(for: pillar))
                    .opacity(selectedPillar == nil || selectedPillar == pillar ? 1.0 : 0.3)
                }
            }
            .frame(height: 200)
            .chartBackground { chartProxy in
                GeometryReader { geometry in
                    if let plotFrame = chartProxy.plotFrame {
                        let frame = geometry[plotFrame]

                        // Building columns icon in center
                        VStack(spacing: 8) {
                            Image(systemName: "building.columns")
                                .font(.system(size: 48))
                                .foregroundColor(.primary)
                            Text("7 Pillars")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }
                        .position(x: frame.midX, y: frame.midY)
                    }
                }
            }

            // Legend
            VStack(spacing: 12) {
                ForEach(pillars, id: \.self) { pillar in
                    Button(action: {
                        // Toggle selection: tap again to deselect
                        if selectedPillar == pillar {
                            selectedPillar = nil
                        } else {
                            selectedPillar = pillar
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: MetricsUIConfig.getPillarIcon(for: pillar))
                                .font(.system(size: 20))
                                .foregroundColor(MetricsUIConfig.getPillarColor(for: pillar))
                                .frame(width: 24)

                            Text(pillar)
                                .font(.body)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Spacer()

                            Text("\(Int(percentage.rounded()))%")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            selectedPillar == pillar ?
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
    PillarDonutChart()
}
