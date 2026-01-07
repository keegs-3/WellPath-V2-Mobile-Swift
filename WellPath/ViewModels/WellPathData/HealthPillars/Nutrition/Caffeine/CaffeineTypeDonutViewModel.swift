//
//  CaffeineTypeDonutViewModel.swift
//  WellPath
//
//  ViewModel for caffeine type donut chart with tier-based scoring.
//  Quality Sources (Tier 1) vs Limit Sources (Tier 2).
//

import Foundation
import SwiftUI
import Supabase

// Tier configuration for caffeine
struct CaffeineTierConfig: Codable {
    let tiers: [Tier]

    struct Tier: Codable, Identifiable {
        let tierId: String
        let tierName: String
        let targetPercentage: Int
        let multiplier: Double
        let caffeineTypes: [String]
        let tierDescription: String
        let displayOrder: Int
        let colorHex: String?

        var id: String { tierId }

        enum CodingKeys: String, CodingKey {
            case tierId = "tier_id"
            case tierName = "tier_name"
            case targetPercentage = "target_percentage"
            case multiplier
            case caffeineTypes = "caffeine_types"
            case tierDescription = "tier_description"
            case displayOrder = "display_order"
            case colorHex = "color_hex"
        }
    }
}

@MainActor
class CaffeineTypeDonutViewModel: ObservableObject {
    @Published var typeData: [String: Double] = [:]  // caffeine_type -> mg
    @Published var isLoading = false
    @Published var tierConfig: CaffeineTierConfig?
    @Published var scoringExplanation: String?

    let supabase = SupabaseManager.shared.client
    private let baseColor: Color

    // Display names keyed by reference_key
    @Published var caffeineTypeDisplayNames: [String: String] = [:]

    private let fallbackDisplayNames: [String: String] = [
        "caffeine_types_tea_green": "Green Tea",
        "caffeine_types_tea_black": "Black Tea",
        "caffeine_types_tea_white": "White Tea",
        "caffeine_types_tea_oolong": "Oolong Tea",
        "caffeine_types_matcha": "Matcha",
        "caffeine_types_coffee_brewed": "Brewed Coffee",
        "caffeine_types_coffee_espresso": "Espresso",
        "caffeine_types_coffee_instant": "Instant Coffee",
        "caffeine_types_energy_drink": "Energy Drink",
        "caffeine_types_soda_caffeinated": "Caffeinated Soda",
        "caffeine_types_pre_workout": "Pre-Workout",
        "caffeine_types_caffeine_pill": "Caffeine Pill"
    ]

    init(baseColor: Color) {
        self.baseColor = baseColor
    }

    var totalCaffeine: Double {
        typeData.values.reduce(0, +)
    }

    func getColor(for typeId: String) -> Color {
        // Determine tier and return appropriate color
        guard let tierConfig = tierConfig else { return .gray }

        for tier in tierConfig.tiers {
            if tier.caffeineTypes.contains(typeId) {
                if tier.tierId == "CAFFEINE_TIER_1" {
                    return MetricsUIConfig.tierGood
                } else if tier.tierId == "CAFFEINE_TIER_2" {
                    return MetricsUIConfig.tierPoor
                }
            }
        }
        return .gray
    }

    func getDisplayName(for typeId: String) -> String {
        caffeineTypeDisplayNames[typeId] ?? fallbackDisplayNames[typeId] ?? typeId
            .replacingOccurrences(of: "caffeine_types_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    /// Load caffeine type display names from database
    func loadCaffeineTypeDisplayNames() async {
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
                .eq("reference_category", value: "caffeine_types")
                .eq("is_active", value: true)
                .execute()
                .value

            var displayNames: [String: String] = [:]
            for result in results {
                displayNames[result.referenceKey] = result.displayName
            }
            caffeineTypeDisplayNames = displayNames

        } catch {
            print("⚠️ Could not load caffeine type display names: \(error)")
        }
    }

    /// Load tier configuration from database (scoring_thresholds table)
    func loadTierConfig() async {
        do {
            // First get tier definitions from scoring_thresholds
            struct TierRow: Codable {
                let tierId: String      // threshold_key
                let tierName: String?   // display_name
                let targetPercentage: Double  // target_value
                let multiplier: Double  // weight
                let tierDescription: String?  // display_description
                let displayOrder: Int?
                let colorHex: String?

                enum CodingKeys: String, CodingKey {
                    case tierId = "threshold_key"
                    case tierName = "display_name"
                    case targetPercentage = "target_value"
                    case multiplier = "weight"
                    case tierDescription = "display_description"
                    case displayOrder = "display_order"
                    case colorHex = "color_hex"
                }
            }

            let tierRows: [TierRow] = try await supabase
                .from("scoring_thresholds")
                .select("threshold_key, display_name, target_value, weight, display_description, display_order, color_hex")
                .eq("view_id", value: "DISP_CAFFEINE_TYPE")
                .eq("threshold_type", value: "tier")
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            // Load caffeine types with their tier_key from sample_category_types_reference
            struct TierTypeRow: Codable {
                let referenceKey: String
                let tierKey: String?

                enum CodingKeys: String, CodingKey {
                    case referenceKey = "reference_key"
                    case tierKey = "tier_key"
                }
            }

            let typeRows: [TierTypeRow] = try await supabase
                .from("sample_category_types_reference")
                .select("reference_key, tier_key")
                .eq("reference_category", value: "caffeine_types")
                .eq("is_active", value: true)
                .execute()
                .value

            // Build config
            let tiers = tierRows.map { row in
                let caffeineTypes = typeRows
                    .filter { $0.tierKey == row.tierId }
                    .map { $0.referenceKey }

                return CaffeineTierConfig.Tier(
                    tierId: row.tierId,
                    tierName: row.tierName ?? row.tierId,
                    targetPercentage: Int(row.targetPercentage),
                    multiplier: row.multiplier,
                    caffeineTypes: caffeineTypes,
                    tierDescription: row.tierDescription ?? "",
                    displayOrder: row.displayOrder ?? 0,
                    colorHex: row.colorHex
                )
            }

            tierConfig = CaffeineTierConfig(tiers: tiers)

        } catch {
            print("⚠️ Could not load caffeine tier config: \(error)")
        }
    }

    /// Load data for a specific time period
    func loadDataForPeriod(period: TimePeriod, date: Date) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let userId = try await supabase.auth.session.user.id

            // Calculate date range
            let (startDate, endDate) = getDateRange(for: period, date: date)

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            let startStr = formatter.string(from: startDate)
            let endStr = formatter.string(from: endDate)

            // Query caffeine category samples for this period
            struct CaffeineSample: Codable {
                let categoryValue: String
                let quantityValue: Double?

                enum CodingKeys: String, CodingKey {
                    case categoryValue = "category_value"
                    case quantityValue = "quantity_value"
                }
            }

            let samples: [CaffeineSample] = try await supabase
                .from("patient_category_samples")
                .select("category_value, quantity_value")
                .eq("patient_id", value: userId.uuidString)
                .eq("category_type", value: "caffeine_types")
                .gte("start_time", value: startStr)
                .lte("start_time", value: endStr)
                .execute()
                .value

            // Aggregate by type
            var aggregated: [String: Double] = [:]
            for sample in samples {
                let typeKey = sample.categoryValue
                let mg = sample.quantityValue ?? 0
                aggregated[typeKey, default: 0] += mg
            }

            // For non-day periods, calculate daily average
            if period != .day {
                let calendar = Calendar.current
                let days = max(1, calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 1)
                for key in aggregated.keys {
                    aggregated[key] = aggregated[key]! / Double(days)
                }
            }

            typeData = aggregated

        } catch {
            print("⚠️ Could not load caffeine data: \(error)")
            typeData = [:]
        }
    }

    /// Calculate quality score based on tier percentages
    func calculateTypeScore() -> Double {
        guard totalCaffeine > 0, let tierConfig = tierConfig else { return 0 }

        // Get tier 1 (quality sources) percentage
        let tier1Types = tierConfig.tiers.first { $0.tierId == "CAFFEINE_TIER_1" }?.caffeineTypes ?? []
        let tier1Amount = tier1Types.reduce(0.0) { sum, typeId in
            sum + (typeData[typeId] ?? 0)
        }

        let tier1Percentage = (tier1Amount / totalCaffeine) * 100

        // Score: 100% Tier 1 = 100 points, 0% Tier 1 = 0 points
        // With target of 90%, scale so 90%+ = 80+ score
        if tier1Percentage >= 90 {
            return 80 + (tier1Percentage - 90) * 2  // 90-100% → 80-100
        } else if tier1Percentage >= 70 {
            return 60 + (tier1Percentage - 70) * 1  // 70-90% → 60-80
        } else if tier1Percentage >= 50 {
            return 40 + (tier1Percentage - 50) * 1  // 50-70% → 40-60
        } else {
            return tier1Percentage * 0.8  // 0-50% → 0-40
        }
    }

    // MARK: - Helpers

    private func getDateRange(for period: TimePeriod, date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        switch period {
        case .day:
            return (startOfDay, startOfDay)
        case .week:
            let weekday = calendar.component(.weekday, from: date)
            let daysToSubtract = weekday - calendar.firstWeekday
            let weekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: startOfDay)!
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
            return (weekStart, weekEnd)
        case .month:
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart)!
            let monthEnd = calendar.date(byAdding: .day, value: -1, to: nextMonth)!
            return (monthStart, monthEnd)
        case .sixMonth:
            let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: startOfDay)!
            return (sixMonthsAgo, startOfDay)
        case .year:
            let yearStart = calendar.date(from: calendar.dateComponents([.year], from: date))!
            let nextYear = calendar.date(byAdding: .year, value: 1, to: yearStart)!
            let yearEnd = calendar.date(byAdding: .day, value: -1, to: nextYear)!
            return (yearStart, yearEnd)
        }
    }
}
