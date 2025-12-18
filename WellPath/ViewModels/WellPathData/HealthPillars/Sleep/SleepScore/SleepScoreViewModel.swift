//
//  SleepScoreViewModel.swift
//  WellPath
//
//  ViewModel for Sleep Score with tier-based scoring
//

import Foundation
import SwiftUI
import Supabase

// Tier configuration for sleep score
struct SleepScoreTierConfig: Codable {
    let tiers: [Tier]

    struct Tier: Codable, Identifiable {
        let tierId: String
        let tierName: String
        let targetPercentage: Int
        let multiplier: Double
        let tierDescription: String
        let displayOrder: Int
        let colorHex: String?

        var id: String { tierId }

        var color: Color {
            guard let hex = colorHex else { return .gray }
            return Color(hex: hex) ?? .gray
        }

        enum CodingKeys: String, CodingKey {
            case tierId = "tier_id"
            case tierName = "tier_name"
            case targetPercentage = "target_percentage"
            case multiplier
            case tierDescription = "tier_description"
            case displayOrder = "display_order"
            case colorHex = "color_hex"
        }
    }
}

@MainActor
class SleepScoreViewModel: ObservableObject {
    @Published var tierConfig: SleepScoreTierConfig?
    @Published var tierScores: [String: Double] = [:]  // tier_id -> score (0-100)
    @Published var isLoading = false
    @Published var scoringExplanation: String?

    let supabase = SupabaseManager.shared.client

    /// Overall sleep score (weighted average of tier scores)
    var totalScore: Double {
        guard let tierConfig = tierConfig else { return 0 }
        var score: Double = 0
        for tier in tierConfig.tiers {
            let tierScore = tierScores[tier.tierId] ?? 0
            score += tierScore * tier.multiplier
        }
        return min(100, max(0, score))
    }

    /// Load tier configuration from database
    func loadTierConfig() async {
        do {
            // Load scoring explanation from display_views
            struct MetricScoring: Codable {
                let scoringExplanation: String?

                enum CodingKeys: String, CodingKey {
                    case scoringExplanation = "scoring_explanation"
                }
            }

            let scoringResults: [MetricScoring] = try await supabase
                .from("display_views")
                .select("scoring_explanation")
                .eq("view_id", value: "DISP_SLEEP_SCORE")
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
                let colorHex: String?

                enum CodingKeys: String, CodingKey {
                    case tierId = "tier_id"
                    case tierName = "tier_name"
                    case tierDescription = "tier_description"
                    case targetPercentage = "target_percentage"
                    case multiplier
                    case displayOrder = "display_order"
                    case colorHex = "color_hex"
                }
            }

            let tierResults: [DBTier] = try await supabase
                .from("display_view_tiers")
                .select()
                .eq("view_id", value: "DISP_SLEEP_SCORE")
                .order("display_order", ascending: true)
                .execute()
                .value

            // Build tier config
            var tiers: [SleepScoreTierConfig.Tier] = []
            for dbTier in tierResults {
                tiers.append(SleepScoreTierConfig.Tier(
                    tierId: dbTier.tierId,
                    tierName: dbTier.tierName,
                    targetPercentage: dbTier.targetPercentage,
                    multiplier: dbTier.multiplier,
                    tierDescription: dbTier.tierDescription,
                    displayOrder: dbTier.displayOrder,
                    colorHex: dbTier.colorHex
                ))
            }

            tierConfig = SleepScoreTierConfig(tiers: tiers)
            print("Loaded sleep score tier config: \(tiers.count) tiers")

        } catch {
            print("Error loading sleep score tier config: \(error)")
        }
    }

    /// Load sleep data and calculate tier scores
    func loadData() async {
        isLoading = true

        // For now, use placeholder scores until we implement the actual calculation
        // TODO: Implement actual score calculation from patient_quantity_samples
        tierScores = [
            "SLEEP_TIER_CONSISTENCY": 75.0,
            "SLEEP_TIER_DURATION": 85.0,
            "SLEEP_TIER_STRUCTURE": 70.0,
            "SLEEP_TIER_EFFICIENCY": 90.0
        ]

        isLoading = false
    }

    /// Get the score for a specific tier
    func getScore(for tierId: String) -> Double {
        tierScores[tierId] ?? 0
    }

    /// Get tier by ID
    func getTier(by id: String) -> SleepScoreTierConfig.Tier? {
        tierConfig?.tiers.first { $0.tierId == id }
    }
}

