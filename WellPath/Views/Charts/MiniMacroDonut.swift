//
//  MiniMacroDonut.swift
//  WellPath
//
//  Compact donut chart for displaying macro breakdown (Protein/Carbs/Fat)
//  Used in nutrition entry cards to show at-a-glance macro distribution
//

import SwiftUI
import Charts

/// Compact macro breakdown donut chart
struct MiniMacroDonut: View {
    let proteinGrams: Double
    let carbGrams: Double
    let fatGrams: Double
    var size: CGFloat = 40

    // Calorie calculation: P=4cal/g, C=4cal/g, F=9cal/g
    private var proteinCalories: Double { proteinGrams * 4 }
    private var carbCalories: Double { carbGrams * 4 }
    private var fatCalories: Double { fatGrams * 9 }
    private var totalCalories: Double { proteinCalories + carbCalories + fatCalories }

    private var hasData: Bool { totalCalories > 0 }

    // Standard macro colors
    static let proteinColor = Color(red: 0.2, green: 0.6, blue: 0.9)  // Blue
    static let carbColor = Color(red: 0.95, green: 0.7, blue: 0.3)     // Yellow/Gold
    static let fatColor = Color(red: 0.9, green: 0.4, blue: 0.4)       // Red/Salmon

    private var segments: [(name: String, value: Double, color: Color)] {
        guard hasData else {
            return [("Empty", 100, Color.gray.opacity(0.3))]
        }
        return [
            ("Protein", (proteinCalories / totalCalories) * 100, Self.proteinColor),
            ("Carbs", (carbCalories / totalCalories) * 100, Self.carbColor),
            ("Fat", (fatCalories / totalCalories) * 100, Self.fatColor)
        ].filter { $0.value > 0 }
    }

    var body: some View {
        Chart {
            ForEach(segments, id: \.name) { segment in
                SectorMark(
                    angle: .value("Percentage", segment.value),
                    innerRadius: .ratio(0.55),
                    angularInset: 0.5
                )
                .foregroundStyle(segment.color)
            }
        }
        .chartLegend(.hidden)
        .frame(width: size, height: size)
    }
}

/// Extended version with labels beneath
struct MiniMacroDonutWithLabels: View {
    let proteinGrams: Double
    let carbGrams: Double
    let fatGrams: Double
    var size: CGFloat = 44

    var body: some View {
        VStack(spacing: 4) {
            MiniMacroDonut(
                proteinGrams: proteinGrams,
                carbGrams: carbGrams,
                fatGrams: fatGrams,
                size: size
            )

            // Compact labels
            HStack(spacing: 6) {
                macroLabel("P", Int(proteinGrams), MiniMacroDonut.proteinColor)
                macroLabel("C", Int(carbGrams), MiniMacroDonut.carbColor)
                macroLabel("F", Int(fatGrams), MiniMacroDonut.fatColor)
            }
        }
    }

    private func macroLabel(_ letter: String, _ grams: Int, _ color: Color) -> some View {
        HStack(spacing: 2) {
            Text(letter)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
            Text("\(grams)")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

/// Horizontal layout version with macro grams on the right
struct MiniMacroDonutRow: View {
    let proteinGrams: Double
    let carbGrams: Double
    let fatGrams: Double
    let calories: Double?
    var size: CGFloat = 36

    private var displayCalories: Int {
        if let cal = calories {
            return Int(cal)
        }
        // Calculate from macros
        return Int((proteinGrams * 4) + (carbGrams * 4) + (fatGrams * 9))
    }

    var body: some View {
        HStack(spacing: 8) {
            MiniMacroDonut(
                proteinGrams: proteinGrams,
                carbGrams: carbGrams,
                fatGrams: fatGrams,
                size: size
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("\(displayCalories) cal")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    macroText("P", Int(proteinGrams), MiniMacroDonut.proteinColor)
                    macroText("C", Int(carbGrams), MiniMacroDonut.carbColor)
                    macroText("F", Int(fatGrams), MiniMacroDonut.fatColor)
                }
            }
        }
    }

    private func macroText(_ letter: String, _ grams: Int, _ color: Color) -> some View {
        HStack(spacing: 1) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(grams)g")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

#Preview("MiniMacroDonut") {
    VStack(spacing: 20) {
        // Basic donut
        MiniMacroDonut(proteinGrams: 30, carbGrams: 45, fatGrams: 15)

        // With labels
        MiniMacroDonutWithLabels(proteinGrams: 30, carbGrams: 45, fatGrams: 15)

        // Row layout
        MiniMacroDonutRow(proteinGrams: 30, carbGrams: 45, fatGrams: 15, calories: 390)

        // High protein example
        MiniMacroDonutRow(proteinGrams: 45, carbGrams: 10, fatGrams: 8, calories: nil)

        // High fat example
        MiniMacroDonutRow(proteinGrams: 10, carbGrams: 5, fatGrams: 25, calories: nil)

        // Empty state
        MiniMacroDonut(proteinGrams: 0, carbGrams: 0, fatGrams: 0)
    }
    .padding()
}
