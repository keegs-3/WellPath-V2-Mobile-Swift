//
//  ProteinTypeDonutViewModel.swift
//  WellPath
//
//  ViewModel for protein type donut chart with tier-based scoring
//

import Foundation
import SwiftUI
import Supabase

// Tier configuration from database
struct TierConfig: Codable {
    let tiers: [Tier]

    struct Tier: Codable, Identifiable {
        let tierId: String
        let tierName: String
        let targetPercentage: Int
        let multiplier: Double
        let proteinTypes: [String]
        let tierDescription: String
        let displayOrder: Int

        var id: String { tierId }

        enum CodingKeys: String, CodingKey {
            case tierId = "tier_id"
            case tierName = "tier_name"
            case targetPercentage = "target_percentage"
            case multiplier
            case proteinTypes = "protein_types"
            case tierDescription = "tier_description"
            case displayOrder = "display_order"
        }
    }
}

@MainActor
class ProteinTypeDonutViewModel: ObservableObject {
    @Published var typeData: [String: Double] = [:]  // agg_id -> grams
    @Published var isLoading = false
    @Published var tierConfig: TierConfig?
    @Published var tierDescription: String?
    @Published var scoringExplanation: String?

    let supabase = SupabaseManager.shared.client
    private let baseColor: Color

    // Tier-based color families for protein types
    private let typeColors: [String: Color] = [
        // Tier 1 - Modern green family
        "AGG_PROTEIN_TYPE_PLANT_BASED": Color(red: 0.2, green: 0.78, blue: 0.35),   // bright green
        "AGG_PROTEIN_TYPE_FATTY_FISH": Color(red: 0.0, green: 0.78, blue: 0.75),    // teal

        // Tier 2 - Modern blue family
        "AGG_PROTEIN_TYPE_EGGS": Color(red: 0.4, green: 0.6, blue: 1.0),            // light blue
        "AGG_PROTEIN_TYPE_LEAN_PROTEIN": Color(red: 0.0, green: 0.48, blue: 1.0),   // system blue
        "AGG_PROTEIN_TYPE_DAIRY": Color(red: 0.35, green: 0.34, blue: 0.84),        // indigo
        "AGG_PROTEIN_TYPE_SUPPLEMENT": Color(red: 0.5, green: 0.4, blue: 0.9),      // purple-blue

        // Tier 3 - Modern red family
        "AGG_PROTEIN_TYPE_RED_MEAT": Color(red: 1.0, green: 0.58, blue: 0.0),       // orange-red
        "AGG_PROTEIN_TYPE_PROCESSED_MEAT": Color(red: 1.0, green: 0.27, blue: 0.23), // bright red

        // Other - Gray
        "AGG_PROTEIN_TYPE_OTHER": Color(red: 0.56, green: 0.56, blue: 0.58),        // systemGray
        "AGG_PROTEIN_TYPE_UNASSIGNED": Color(red: 0.68, green: 0.68, blue: 0.70)    // systemGray2
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

    init(baseColor: Color) {
        self.baseColor = baseColor
    }

    var totalProtein: Double {
        typeData.values.reduce(0, +)
    }

    func getColor(for typeId: String) -> Color {
        typeColors[typeId] ?? Color.gray
    }

    func getDisplayName(for typeId: String) -> String {
        typeDisplayNames[typeId] ?? typeId
    }

    /// Load tier configuration from database (relational structure)
    func loadTierConfig() async {
        do {
            // Load scoring explanation from display_metrics
            struct MetricScoring: Codable {
                let scoringExplanation: String?

                enum CodingKeys: String, CodingKey {
                    case scoringExplanation = "scoring_explanation"
                }
            }

            let scoringResults: [MetricScoring] = try await supabase
                .from("display_metrics")
                .select("scoring_explanation")
                .eq("metric_id", value: "DISP_PROTEIN_TYPE")
                .limit(1)
                .execute()
                .value

            scoringExplanation = scoringResults.first?.scoringExplanation

            // Load tier configuration
            struct DBTier: Codable {
                let tierId: String
                let tierName: String
                let tierDescription: String
                let targetPercentage: Int
                let multiplier: Double
                let displayOrder: Int

                enum CodingKeys: String, CodingKey {
                    case tierId = "tier_id"
                    case tierName = "tier_name"
                    case tierDescription = "tier_description"
                    case targetPercentage = "target_percentage"
                    case multiplier
                    case displayOrder = "display_order"
                }
            }

            let tierResults: [DBTier] = try await supabase
                .from("display_metric_tiers")
                .select()
                .eq("metric_id", value: "DISP_PROTEIN_TYPE")
                .order("display_order", ascending: true)
                .execute()
                .value

            // Load protein types for each tier
            struct DBTierType: Codable {
                let tierId: String
                let aggMetricId: String
                let displayOrder: Int

                enum CodingKeys: String, CodingKey {
                    case tierId = "tier_id"
                    case aggMetricId = "agg_metric_id"
                    case displayOrder = "display_order"
                }
            }

            let tierTypeResults: [DBTierType] = try await supabase
                .from("display_metric_tier_types")
                .select()
                .in("tier_id", values: tierResults.map { $0.tierId })
                .order("display_order", ascending: true)
                .execute()
                .value

            // Build tier config
            var tiers: [TierConfig.Tier] = []
            for dbTier in tierResults {
                let proteinTypes = tierTypeResults
                    .filter { $0.tierId == dbTier.tierId }
                    .map { $0.aggMetricId }

                tiers.append(TierConfig.Tier(
                    tierId: dbTier.tierId,
                    tierName: dbTier.tierName,
                    targetPercentage: dbTier.targetPercentage,
                    multiplier: dbTier.multiplier,
                    proteinTypes: proteinTypes,
                    tierDescription: dbTier.tierDescription,
                    displayOrder: dbTier.displayOrder
                ))
            }

            tierConfig = TierConfig(tiers: tiers)
            print("✅ Loaded tier config: \(tiers.count) tiers")

        } catch {
            print("❌ Error loading tier config: \(error)")
        }
    }

    /// Calculate Type Score using tier multipliers
    func calculateTypeScore() -> Double {
        guard let tierConfig = tierConfig, totalProtein > 0 else { return 0 }

        var score: Double = 0

        for tier in tierConfig.tiers {
            // Get total grams for this tier
            let tierGrams = tier.proteinTypes.reduce(0.0) { sum, typeId in
                sum + (typeData[typeId] ?? 0)
            }

            // Calculate percentage
            let percentage = (tierGrams / totalProtein) * 100

            // Apply multiplier
            score += percentage * tier.multiplier
        }

        // Clamp to 0-100 range
        return min(100, max(0, score))
    }

    /// Get tier for a specific protein type
    func getTier(for typeId: String) -> TierConfig.Tier? {
        guard let tierConfig = tierConfig else { return nil }
        return tierConfig.tiers.first { $0.proteinTypes.contains(typeId) }
    }
}
