//
//  ProteinBaselineSummaryCard.swift
//  WellPath
//
//  Card showing all 3 protein baseline components.
//  Replaces "Get Started" card when baseline wizard is complete.
//

import SwiftUI

struct ProteinBaselineSummaryCard: View {
    let color: Color
    let baselineAmount: Double?     // daily_protein_g
    let baselineTypeScore: Double?  // protein_type_score
    let baselineRatio: Double?      // daily_protein_ratio (in g/kg)

    @StateObject private var unitPrefs = UnitPreferencesViewModel()

    private var hasAnyBaseline: Bool {
        baselineAmount != nil || baselineTypeScore != nil || baselineRatio != nil
    }

    // Conversion factor: 1 kg = 2.2046 lb
    private let kgToLb: Double = 2.2046

    private var usePounds: Bool {
        unitPrefs.weightUnit == .lb
    }

    /// Type score color matching the Type card (same thresholds as ProteinTypeDonutView)
    private func scoreColor(for score: Double) -> Color {
        if score >= 85 {
            return Color.green
        } else if score >= 70 {
            return Color.blue
        } else if score >= 55 {
            return Color.orange
        } else {
            return Color.red
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "flag.fill")
                    .font(.headline)
                    .foregroundColor(color)
                Text("Your Baseline")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if hasAnyBaseline {
                // Three baseline components in a row
                HStack(spacing: 0) {
                    // Amount
                    amountComponent

                    Divider()
                        .frame(height: 55)

                    // Type Score (color-coded)
                    typeScoreComponent

                    Divider()
                        .frame(height: 55)

                    // Ratio (respects unit preferences)
                    ratioComponent
                }
            } else {
                // No baseline set
                HStack(spacing: 8) {
                    Image(systemName: "flag.badge.ellipsis")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No baseline set")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Text("Tap to set your protein baseline")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .task {
            await unitPrefs.loadPreferences()
        }
    }

    // MARK: - Amount Component

    private var amountComponent: some View {
        VStack(spacing: 4) {
            Image(systemName: "scalemass")
                .font(.caption)
                .foregroundColor(color.opacity(0.7))

            if let amount = baselineAmount {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(amount))")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text("g")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("--")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }

            Text("Amount")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Type Score Component (color-coded)

    private var typeScoreComponent: some View {
        VStack(spacing: 4) {
            Image(systemName: "chart.pie")
                .font(.caption)
                .foregroundColor(color.opacity(0.7))

            if let score = baselineTypeScore {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(score))")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(scoreColor(for: score))
                    Text("/100")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("--")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }

            Text("Type")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Ratio Component (respects unit preferences)

    private var ratioComponent: some View {
        VStack(spacing: 4) {
            Image(systemName: "percent")
                .font(.caption)
                .foregroundColor(color.opacity(0.7))

            if let ratioGPerKg = baselineRatio {
                let displayValue = usePounds ? ratioGPerKg / kgToLb : ratioGPerKg
                let unitLabel = usePounds ? "g/lb" : "g/kg"

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.2f", displayValue))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(unitLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("--")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }

            Text("Ratio")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview("With All Baselines - High Score") {
    ProteinBaselineSummaryCard(
        color: MetricsUIConfig.getPillarColor(for: "Healthful Nutrition"),
        baselineAmount: 120,
        baselineTypeScore: 85,
        baselineRatio: 1.4
    )
    .padding()
}

#Preview("With All Baselines - Medium Score") {
    ProteinBaselineSummaryCard(
        color: MetricsUIConfig.getPillarColor(for: "Healthful Nutrition"),
        baselineAmount: 200,
        baselineTypeScore: 60,
        baselineRatio: 2.4
    )
    .padding()
}

#Preview("Partial Baselines") {
    ProteinBaselineSummaryCard(
        color: MetricsUIConfig.getPillarColor(for: "Healthful Nutrition"),
        baselineAmount: 100,
        baselineTypeScore: nil,
        baselineRatio: 1.2
    )
    .padding()
}

#Preview("No Baselines") {
    ProteinBaselineSummaryCard(
        color: MetricsUIConfig.getPillarColor(for: "Healthful Nutrition"),
        baselineAmount: nil,
        baselineTypeScore: nil,
        baselineRatio: nil
    )
    .padding()
}
