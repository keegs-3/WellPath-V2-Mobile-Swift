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

    // Tier-based color families for protein types (keyed by reference_key from sample_category_types_reference)
    private let typeColors: [String: Color] = [
        // Tier 1 - Modern green family
        "plant_based": Color(red: 0.2, green: 0.78, blue: 0.35),   // bright green
        "fatty_fish": Color(red: 0.0, green: 0.78, blue: 0.75),    // teal

        // Tier 2 - Modern blue family
        "eggs": Color(red: 0.4, green: 0.6, blue: 1.0),            // light blue
        "lean_protein": Color(red: 0.0, green: 0.48, blue: 1.0),   // system blue
        "dairy": Color(red: 0.35, green: 0.34, blue: 0.84),        // indigo
        "supplement": Color(red: 0.5, green: 0.4, blue: 0.9),      // purple-blue

        // Tier 3 - Modern red family
        "red_meat": Color(red: 1.0, green: 0.58, blue: 0.0),       // orange-red
        "processed_meat": Color(red: 1.0, green: 0.27, blue: 0.23), // bright red

        // Other - Gray
        "other": Color(red: 0.56, green: 0.56, blue: 0.58),        // systemGray
        "unassigned": Color(red: 0.68, green: 0.68, blue: 0.70)    // systemGray2
    ]

    // Display names keyed by reference_key from sample_category_types_reference
    // Loaded dynamically from database, with fallbacks
    @Published var proteinTypeDisplayNames: [String: String] = [:]

    private let fallbackDisplayNames: [String: String] = [
        "dairy": "Dairy",
        "eggs": "Eggs",
        "fatty_fish": "Fatty Fish",
        "lean_protein": "Lean Protein",
        "plant_based": "Plant-based",
        "processed_meat": "Processed Meat",
        "red_meat": "Red Meat",
        "supplement": "Supplement",
        "other": "Other",
        "unassigned": "Unassigned"
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
        // First try dynamically loaded names, then fallbacks
        proteinTypeDisplayNames[typeId] ?? fallbackDisplayNames[typeId] ?? typeId.replacingOccurrences(of: "_", with: " ").capitalized
    }

    /// Load protein type display names from database
    func loadProteinTypeDisplayNames() async {
        do {
            struct TypeReference: Codable {
                let referenceKey: String
                let displayName: String

                enum CodingKeys: String, CodingKey {
                    case referenceKey = "reference_key"
                    case displayName = "display_name"
                }
            }

            let results: [TypeReference] = try await supabase
                .from("sample_category_types_reference")
                .select("reference_key, display_name")
                .eq("reference_category", value: "protein_types")
                .eq("is_active", value: true)
                .execute()
                .value

            var displayNames: [String: String] = [:]
            for result in results {
                displayNames[result.referenceKey] = result.displayName
            }
            proteinTypeDisplayNames = displayNames
            print("✅ Loaded \(displayNames.count) protein type display names")

        } catch {
            print("⚠️ Could not load protein type display names: \(error)")
        }
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
                .from("display_views")
                .select("scoring_explanation")
                .eq("view_id", value: "DISP_PROTEIN_TYPE")
                .limit(1)
                .execute()
                .value

            scoringExplanation = scoringResults.first?.scoringExplanation

            // Load tier configuration from scoring_thresholds
            struct DBTier: Codable {
                let tierId: String      // threshold_key
                let tierName: String?   // display_name
                let tierDescription: String?  // display_description
                let targetPercentage: Double  // target_value
                let multiplier: Double  // weight
                let displayOrder: Int?

                enum CodingKeys: String, CodingKey {
                    case tierId = "threshold_key"
                    case tierName = "display_name"
                    case tierDescription = "display_description"
                    case targetPercentage = "target_value"
                    case multiplier = "weight"
                    case displayOrder = "display_order"
                }
            }

            let tierResults: [DBTier] = try await supabase
                .from("scoring_thresholds")
                .select("threshold_key, display_name, display_description, target_value, weight, display_order")
                .eq("view_id", value: "DISP_PROTEIN_TYPE")
                .eq("threshold_type", value: "tier")
                .eq("is_active", value: true)
                .order("display_order", ascending: true)
                .execute()
                .value

            // Load protein types with their tier_key directly from sample_category_types_reference
            struct DBTierType: Codable {
                let referenceKey: String
                let tierKey: String?

                enum CodingKeys: String, CodingKey {
                    case referenceKey = "reference_key"
                    case tierKey = "tier_key"
                }
            }

            let tierTypeResults: [DBTierType] = try await supabase
                .from("sample_category_types_reference")
                .select("reference_key, tier_key")
                .eq("reference_category", value: "protein_types")
                .eq("is_active", value: true)
                .execute()
                .value

            // Build tier config
            var tiers: [TierConfig.Tier] = []
            for dbTier in tierResults {
                let proteinTypes = tierTypeResults
                    .filter { $0.tierKey == dbTier.tierId }
                    .map { $0.referenceKey }

                tiers.append(TierConfig.Tier(
                    tierId: dbTier.tierId,
                    tierName: dbTier.tierName ?? dbTier.tierId,
                    targetPercentage: Int(dbTier.targetPercentage),
                    multiplier: dbTier.multiplier,
                    proteinTypes: proteinTypes,
                    tierDescription: dbTier.tierDescription ?? "",
                    displayOrder: dbTier.displayOrder ?? 0
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
