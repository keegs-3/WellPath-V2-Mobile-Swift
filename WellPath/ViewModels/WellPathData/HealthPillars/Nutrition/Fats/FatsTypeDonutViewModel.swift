//
//  FatsTypeDonutViewModel.swift
//  WellPath
//
//  ViewModel for fat type donut chart with tier-based scoring
//

import Foundation
import SwiftUI
import Supabase

// Tier configuration for fats (reuses TierConfig structure from Protein)
struct FatTierConfig: Codable {
    let tiers: [Tier]

    struct Tier: Codable, Identifiable {
        let tierId: String
        let tierName: String
        let targetPercentage: Int
        let multiplier: Double
        let fatTypes: [String]
        let tierDescription: String
        let displayOrder: Int

        var id: String { tierId }

        enum CodingKeys: String, CodingKey {
            case tierId = "tier_id"
            case tierName = "tier_name"
            case targetPercentage = "target_percentage"
            case multiplier
            case fatTypes = "fat_types"
            case tierDescription = "tier_description"
            case displayOrder = "display_order"
        }
    }
}

@MainActor
class FatsTypeDonutViewModel: ObservableObject {
    @Published var typeData: [String: Double] = [:]  // fat_type -> grams
    @Published var isLoading = false
    @Published var tierConfig: FatTierConfig?
    @Published var tierDescription: String?
    @Published var scoringExplanation: String?

    let supabase = SupabaseManager.shared.client
    private let baseColor: Color

    // Tier-based color families for fat types
    private let typeColors: [String: Color] = [
        // Tier 1 - Healthy fats (green family)
        "olive_oil": Color(red: 0.2, green: 0.78, blue: 0.35),
        "avocado": Color(red: 0.0, green: 0.78, blue: 0.75),
        "fatty_fish": Color(red: 0.2, green: 0.7, blue: 0.6),
        "nuts_almonds": Color(red: 0.25, green: 0.72, blue: 0.45),
        "nuts_walnuts": Color(red: 0.3, green: 0.75, blue: 0.5),
        "other_nuts": Color(red: 0.35, green: 0.7, blue: 0.55),
        "seeds": Color(red: 0.15, green: 0.68, blue: 0.4),

        // Tier 2 - Moderate fats (blue family)
        "peanut_butter": Color(red: 0.4, green: 0.6, blue: 1.0),
        "vegetable_oil": Color(red: 0.0, green: 0.48, blue: 1.0),
        "tahini": Color(red: 0.35, green: 0.55, blue: 0.95),
        "canola_oil": Color(red: 0.3, green: 0.5, blue: 0.9),

        // Tier 3 - Limit fats (orange/red family)
        "butter": Color(red: 1.0, green: 0.58, blue: 0.0),
        "coconut_oil": Color(red: 1.0, green: 0.5, blue: 0.1),
        "coconut_products": Color(red: 0.95, green: 0.55, blue: 0.15),
        "lard": Color(red: 1.0, green: 0.27, blue: 0.23),
        "palm_oil": Color(red: 0.95, green: 0.35, blue: 0.2),
        "shortening": Color(red: 0.9, green: 0.4, blue: 0.25),

        // Other - Gray
        "other": Color(red: 0.56, green: 0.56, blue: 0.58),
        "unassigned": Color(red: 0.68, green: 0.68, blue: 0.70)
    ]

    // Display names keyed by reference_key from sample_category_types_reference
    @Published var fatTypeDisplayNames: [String: String] = [:]

    private let fallbackDisplayNames: [String: String] = [
        "olive_oil": "Olive Oil",
        "avocado": "Avocado",
        "fatty_fish": "Fatty Fish",
        "nuts_almonds": "Almonds",
        "nuts_walnuts": "Walnuts",
        "other_nuts": "Other Nuts",
        "seeds": "Seeds",
        "peanut_butter": "Peanut Butter",
        "vegetable_oil": "Vegetable Oil",
        "tahini": "Tahini",
        "canola_oil": "Canola Oil",
        "butter": "Butter",
        "coconut_oil": "Coconut Oil",
        "coconut_products": "Coconut Products",
        "lard": "Lard",
        "palm_oil": "Palm Oil",
        "shortening": "Shortening",
        "other": "Other",
        "unassigned": "Unassigned"
    ]

    init(baseColor: Color) {
        self.baseColor = baseColor
    }

    var totalFats: Double {
        typeData.values.reduce(0, +)
    }

    func getColor(for typeId: String) -> Color {
        typeColors[typeId] ?? Color.gray
    }

    func getDisplayName(for typeId: String) -> String {
        fatTypeDisplayNames[typeId] ?? fallbackDisplayNames[typeId] ?? typeId.replacingOccurrences(of: "_", with: " ").capitalized
    }

    /// Load fat type display names from database
    func loadFatTypeDisplayNames() async {
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
                .eq("reference_category", value: "fat_types")
                .eq("is_active", value: true)
                .execute()
                .value

            var displayNames: [String: String] = [:]
            for result in results {
                displayNames[result.referenceKey] = result.displayName
            }
            fatTypeDisplayNames = displayNames
            print("✅ Loaded \(displayNames.count) fat type display names")

        } catch {
            print("⚠️ Could not load fat type display names: \(error)")
        }
    }

    /// Load tier configuration from database (relational structure)
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
                .eq("view_id", value: "DISP_FATS_TYPE")
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
                .from("display_view_tiers")
                .select()
                .eq("view_id", value: "DISP_FATS_TYPE")
                .order("display_order", ascending: true)
                .execute()
                .value

            // Load fat types for each tier
            struct DBTierType: Codable {
                let tierId: String
                let categoryTypeReferenceKey: String?
                let displayOrder: Int

                enum CodingKeys: String, CodingKey {
                    case tierId = "tier_id"
                    case categoryTypeReferenceKey = "category_type_reference_key"
                    case displayOrder = "display_order"
                }
            }

            let tierTypeResults: [DBTierType] = try await supabase
                .from("display_view_tier_types")
                .select()
                .in("tier_id", values: tierResults.map { $0.tierId })
                .order("display_order", ascending: true)
                .execute()
                .value

            // Build tier config
            var tiers: [FatTierConfig.Tier] = []
            for dbTier in tierResults {
                let fatTypes = tierTypeResults
                    .filter { $0.tierId == dbTier.tierId }
                    .compactMap { $0.categoryTypeReferenceKey }

                tiers.append(FatTierConfig.Tier(
                    tierId: dbTier.tierId,
                    tierName: dbTier.tierName,
                    targetPercentage: dbTier.targetPercentage,
                    multiplier: dbTier.multiplier,
                    fatTypes: fatTypes,
                    tierDescription: dbTier.tierDescription,
                    displayOrder: dbTier.displayOrder
                ))
            }

            tierConfig = FatTierConfig(tiers: tiers)
            print("✅ Loaded fat tier config: \(tiers.count) tiers")

        } catch {
            print("❌ Error loading fat tier config: \(error)")
        }
    }

    /// Calculate Type Score using tier multipliers
    func calculateTypeScore() -> Double {
        guard let tierConfig = tierConfig, totalFats > 0 else { return 0 }

        var score: Double = 0

        for tier in tierConfig.tiers {
            // Get total grams for this tier
            let tierGrams = tier.fatTypes.reduce(0.0) { sum, typeId in
                sum + (typeData[typeId] ?? 0)
            }

            // Calculate percentage
            let percentage = (tierGrams / totalFats) * 100

            // Apply multiplier
            score += percentage * tier.multiplier
        }

        // Clamp to 0-100 range
        return min(100, max(0, score))
    }

    /// Get tier for a specific fat type
    func getTier(for typeId: String) -> FatTierConfig.Tier? {
        guard let tierConfig = tierConfig else { return nil }
        return tierConfig.tiers.first { $0.fatTypes.contains(typeId) }
    }
}
