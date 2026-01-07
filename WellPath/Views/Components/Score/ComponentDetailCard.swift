//
//  ComponentDetailCard.swift
//  WellPath
//
//  Router component that renders the appropriate detail view
//  based on the score's calculation_method from sample_behavioral_score_types.
//

import SwiftUI
import Supabase

// MARK: - Calculation Methods

enum ScoreCalculationMethod: String, Codable {
    case scoringRanges = "scoring_ranges"
    case weightedTiers = "weighted_tiers"
    case timingDistribution = "timing_distribution"
    case variety = "variety"
    case assessment = "assessment"
    case composite = "composite"
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = ScoreCalculationMethod(rawValue: rawValue) ?? .unknown
    }
}

// MARK: - Component Data Model

/// Data needed to render a score component detail
struct ComponentDetailData: Identifiable {
    let id: String
    let scoreType: String
    let calculationMethod: ScoreCalculationMethod
    let displayName: String
    let iconName: String?
    let weight: Double?
    let color: Color

    // Data for rendering (depends on calculation_method)
    var scoringRangesData: ScoringRangesConfig?
    var tierBreakdownData: TierBreakdownConfig?
    var timingDistributionData: TimingDistributionConfig?
    var varietyData: VarietyConfig?
    var assessmentData: AssessmentConfig?

    var score: Int?
}

// MARK: - Calculation-Specific Data Types

struct ScoringRangesConfig {
    let title: String
    let value: Double
    let unit: String
    let quantityType: String
}

struct TierBreakdownConfig {
    let title: String
    let referenceCategory: String  // e.g., "protein_types"
    let typeValues: [String: Double]
    let unit: String
}

struct TimingDistributionConfig {
    let title: String
    let windowValues: [String: Double]  // threshold_key -> value
    let unit: String
}

struct VarietyConfig {
    let title: String
    let typeValues: [String: Double]
    let typeDisplayNames: [String: String]
    let unit: String
}

struct AssessmentConfig {
    let title: String
    let baselineTypes: [String]
}

// MARK: - Router View

struct ComponentDetailCard: View {
    let data: ComponentDetailData

    var body: some View {
        switch data.calculationMethod {
        case .scoringRanges:
            if let rangesData = data.scoringRangesData {
                ScoringRangesDetailView(
                    title: rangesData.title,
                    value: rangesData.value,
                    unit: rangesData.unit,
                    quantityType: rangesData.quantityType,
                    score: data.score,
                    color: data.color
                )
            } else {
                fallbackView
            }

        case .weightedTiers:
            if let tierData = data.tierBreakdownData {
                TierBreakdownView(
                    title: tierData.title,
                    scoreType: data.scoreType,
                    referenceCategory: tierData.referenceCategory,
                    typeValues: tierData.typeValues,
                    unit: tierData.unit,
                    score: data.score,
                    baseColor: data.color
                )
            } else {
                fallbackView
            }

        case .timingDistribution:
            if let timingData = data.timingDistributionData {
                TimingDistributionDetailView(
                    title: timingData.title,
                    scoreType: data.scoreType,
                    windowValues: timingData.windowValues,
                    unit: timingData.unit,
                    score: data.score,
                    color: data.color
                )
            } else {
                fallbackView
            }

        case .variety:
            if let varietyData = data.varietyData {
                VarietyDetailView(
                    title: varietyData.title,
                    scoreType: data.scoreType,
                    typeValues: varietyData.typeValues,
                    typeDisplayNames: varietyData.typeDisplayNames,
                    unit: varietyData.unit,
                    score: data.score,
                    color: data.color
                )
            } else {
                fallbackView
            }

        case .assessment:
            if let assessmentData = data.assessmentData {
                AssessmentSummaryView(
                    title: assessmentData.title,
                    baselineTypes: assessmentData.baselineTypes,
                    score: data.score,
                    color: data.color
                )
            } else {
                fallbackView
            }

        case .composite:
            // Composite scores are expanded into their components
            // This shouldn't be called directly
            fallbackView

        case .unknown:
            fallbackView
        }
    }

    private var fallbackView: some View {
        SimpleScoreRow(
            title: data.displayName,
            score: data.score,
            iconName: data.iconName ?? "questionmark.circle",
            color: data.color
        )
    }
}

// MARK: - Simple Score Row (Fallback)

/// Simple score display for unknown calculation methods
struct SimpleScoreRow: View {
    let title: String
    let score: Int?
    let iconName: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(color)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            if let score = score {
                Text("\(score)/100")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(scoreColor(for: score))
            } else {
                Text("--")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func scoreColor(for score: Int) -> Color {
        if score >= 80 { return .green }
        else if score >= 60 { return .yellow }
        else if score >= 40 { return .orange }
        else { return .red }
    }
}

// MARK: - Component Score Ring

/// Score ring pill for a component (used in component breakdowns)
struct ComponentScoreRing: View {
    let data: ComponentDetailData
    let size: CGFloat

    init(data: ComponentDetailData, size: CGFloat = 60) {
        self.data = data
        self.size = size
    }

    var body: some View {
        VStack(spacing: 8) {
            ScoreRingPill(
                score: data.score,
                iconName: data.iconName ?? "questionmark.circle",
                label: data.displayName,
                size: size
            )

            if let weight = data.weight {
                Text("\(Int(weight * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Component Grid

/// Grid of component score rings
struct ComponentScoreGrid: View {
    let components: [ComponentDetailData]
    let ringSize: CGFloat

    init(components: [ComponentDetailData], ringSize: CGFloat = 60) {
        self.components = components
        self.ringSize = ringSize
    }

    var body: some View {
        HStack(spacing: 24) {
            ForEach(components) { component in
                ComponentScoreRing(data: component, size: ringSize)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            // Scoring Ranges example
            ComponentDetailCard(data: ComponentDetailData(
                id: "amount",
                scoreType: "hydration_amount_score",
                calculationMethod: .scoringRanges,
                displayName: "Amount",
                iconName: "drop.fill",
                weight: 0.7,
                color: .cyan,
                scoringRangesData: ScoringRangesConfig(
                    title: "Daily Water Intake",
                    value: 2500,
                    unit: "ml",
                    quantityType: "water_ml"
                ),
                score: 85
            ))

            // Tier Breakdown example
            ComponentDetailCard(data: ComponentDetailData(
                id: "type",
                scoreType: "protein_type_score",
                calculationMethod: .weightedTiers,
                displayName: "Type",
                iconName: "chart.pie.fill",
                weight: 0.5,
                color: .blue,
                tierBreakdownData: TierBreakdownConfig(
                    title: "Protein Types",
                    referenceCategory: "protein_types",
                    typeValues: ["plant_based": 30, "lean_protein": 40, "red_meat": 10],
                    unit: "g"
                ),
                score: 72
            ))

            // Timing Distribution example
            ComponentDetailCard(data: ComponentDetailData(
                id: "timing",
                scoreType: "hydration_timing_score",
                calculationMethod: .timingDistribution,
                displayName: "Timing",
                iconName: "clock.fill",
                weight: 0.3,
                color: .cyan,
                timingDistributionData: TimingDistributionConfig(
                    title: "Hydration Timing",
                    windowValues: ["MORNING": 1200, "AFTERNOON": 800, "EVENING": 400],
                    unit: "ml"
                ),
                score: 65
            ))

            // Simple fallback
            SimpleScoreRow(
                title: "Unknown Score",
                score: 50,
                iconName: "questionmark.circle",
                color: .gray
            )
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
