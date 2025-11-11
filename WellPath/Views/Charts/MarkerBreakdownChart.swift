//
//  MarkerBreakdownChart.swift
//  WellPath
//
//  Donut chart showing breakdown of individual biomarkers and biometrics
//

import SwiftUI
import Charts

struct MarkerBreakdownChart: View {
    let markers: [MarkerItem]

    @State private var selectedTab: MarkerType = .all

    enum MarkerType: String, CaseIterable {
        case all = "All"
        case biomarkers = "Biomarkers"
        case biometrics = "Biometrics"
    }

    private var biomarkerBaseColor: Color {
        Color(red: 0.74, green: 0.56, blue: 0.94)
    }

    private var biometricBaseColor: Color {
        Color(red: 0.2, green: 0.7, blue: 0.95)
    }

    private var sortedMarkers: [MarkerItem] {
        markers.sorted { $0.itemWeightInPillar > $1.itemWeightInPillar }
    }

    private var filteredMarkers: [MarkerItem] {
        switch selectedTab {
        case .all:
            return sortedMarkers
        case .biomarkers:
            return sortedMarkers.filter { !$0.isBiometric }
        case .biometrics:
            return sortedMarkers.filter { $0.isBiometric }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Donut chart using SwiftUI Charts - FIXED, NOT IN SCROLL
            Chart {
                ForEach(Array(sortedMarkers.enumerated()), id: \.element.id) { index, marker in
                    SectorMark(
                        angle: .value("Weight", marker.itemWeightInPillar * 100),
                        innerRadius: .ratio(0.618),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(gradientForMarker(marker: marker, index: index))
                }
            }
            .frame(height: 200)
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 24)

            // Tab picker for filtering
            Picker("Filter", selection: $selectedTab) {
                ForEach(MarkerType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 12)

            // Scrollable Legend
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(filteredMarkers.enumerated()), id: \.element.id) { index, marker in
                        HStack(spacing: 12) {
                            // Colored dot (no SF symbols)
                            Circle()
                                .fill(gradientForMarker(marker: marker, index: index))
                                .frame(width: 12, height: 12)

                            Text(marker.itemDisplayName)
                                .font(.body)
                                .foregroundColor(.primary)

                            Spacer()

                            // % allocation on the right
                            Text(marker.weightPercentage)
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.horizontal)
            }
        }
        .background(Color(white: 0.95))
        .cornerRadius(12)
    }

    // Create gradient for each marker with variation
    private func gradientForMarker(marker: MarkerItem, index: Int) -> LinearGradient {
        // Get all markers of the same type
        let markersOfSameType = sortedMarkers.filter { $0.isBiometric == marker.isBiometric }
        let indexInType = markersOfSameType.firstIndex(where: { $0.id == marker.id }) ?? 0
        let totalOfType = markersOfSameType.count

        let baseColor = marker.isBiometric ? biometricBaseColor : biomarkerBaseColor

        // Create opacity variations (0.3 to 0.9) - each marker gets a different shade
        let minOpacity = 0.3
        let maxOpacity = 0.9
        let variation = totalOfType > 1 ? Double(indexInType) / Double(totalOfType - 1) : 0.5
        let baseOpacity = minOpacity + (variation * (maxOpacity - minOpacity))

        // Create gradient from lighter to darker for this specific shade
        let lighterColor = baseColor.opacity(baseOpacity * 0.7)
        let darkerColor = baseColor.opacity(baseOpacity)

        return LinearGradient(
            colors: [lighterColor, darkerColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Solid color for legend circles
    private func colorForMarker(marker: MarkerItem, index: Int) -> Color {
        let markersOfSameType = sortedMarkers.filter { $0.isBiometric == marker.isBiometric }
        let indexInType = markersOfSameType.firstIndex(where: { $0.id == marker.id }) ?? 0
        let totalOfType = markersOfSameType.count

        let baseColor = marker.isBiometric ? biometricBaseColor : biomarkerBaseColor

        let minOpacity = 0.3
        let maxOpacity = 0.9
        let variation = totalOfType > 1 ? Double(indexInType) / Double(totalOfType - 1) : 0.5
        let opacity = minOpacity + (variation * (maxOpacity - minOpacity))

        return baseColor.opacity(opacity)
    }
}

#Preview {
    MarkerBreakdownChart(markers: [
        MarkerItem(
            pillarName: "Healthful Nutrition",
            itemType: "biomarker",
            biomarkerName: "Vitamin D",
            biometricName: nil,
            itemDisplayName: "Vitamin D",
            itemPercentage: 100,
            itemWeightInPillar: 0.20,
            scoreBand: "Optimal"
        ),
        MarkerItem(
            pillarName: "Healthful Nutrition",
            itemType: "biomarker",
            biomarkerName: "Vitamin B12",
            biometricName: nil,
            itemDisplayName: "Vitamin B12",
            itemPercentage: 85,
            itemWeightInPillar: 0.15,
            scoreBand: "In-Range"
        ),
        MarkerItem(
            pillarName: "Healthful Nutrition",
            itemType: "biomarker",
            biomarkerName: "Iron",
            biometricName: nil,
            itemDisplayName: "Iron",
            itemPercentage: 75,
            itemWeightInPillar: 0.10,
            scoreBand: "In-Range"
        ),
        MarkerItem(
            pillarName: "Movement + Exercise",
            itemType: "biometric",
            biomarkerName: nil,
            biometricName: "VO2 Max",
            itemDisplayName: "VO2 Max",
            itemPercentage: 90,
            itemWeightInPillar: 0.25,
            scoreBand: "Optimal"
        ),
        MarkerItem(
            pillarName: "Movement + Exercise",
            itemType: "biometric",
            biomarkerName: nil,
            biometricName: "Heart Rate",
            itemDisplayName: "Heart Rate",
            itemPercentage: 80,
            itemWeightInPillar: 0.18,
            scoreBand: "In-Range"
        ),
        MarkerItem(
            pillarName: "Movement + Exercise",
            itemType: "biometric",
            biomarkerName: nil,
            biometricName: "Blood Pressure",
            itemDisplayName: "Blood Pressure",
            itemPercentage: 95,
            itemWeightInPillar: 0.12,
            scoreBand: "Optimal"
        )
    ])
    .padding()
}
