//
//  NutrientTypeViewModel.swift
//  WellPath
//
//  Generic ViewModel for nutrient type distribution (legumes, vegetables, whole grains, fruits)
//  Uses Variety Score (count toward target) instead of tier-based Quality Score
//

import Foundation
import SwiftUI
import Supabase

/// Represents a discovered type aggregation for a nutrient
struct TypeAggregation: Identifiable {
    let aggId: String
    let displayName: String
    var color: Color
    var description: String?

    var id: String { aggId }
}

/// Target count for variety score calculation per period
struct VarietyTarget {
    let target: Int  // types needed for 100% count score
}

@MainActor
class NutrientTypeViewModel: ObservableObject {
    @Published var typeAggregations: [TypeAggregation] = []
    @Published var typeData: [String: Double] = [:]  // agg_id -> servings
    @Published var isLoading = false
    @Published var scoringExplanation: String?
    private var targets: [String: VarietyTarget] = [:]  // period_type -> target

    let supabase = SupabaseManager.shared.client
    private let baseColor: Color
    let nutrientType: NutrientTimingType

    init(nutrientType: NutrientTimingType, baseColor: Color) {
        self.nutrientType = nutrientType
        self.baseColor = baseColor
    }

    /// Returns the display_metrics metric_id for this nutrient type
    private var typeMetricId: String {
        "DISP_\(nutrientType.rawValue)_TYPE"
    }

    var totalServings: Double {
        typeData.values.reduce(0, +)
    }

    var hasData: Bool {
        totalServings > 0
    }

    /// Discovers type aggregations for this nutrient type from the database
    /// Queries sample_category_types_reference to get available type options
    func discoverTypeAggregations() async {
        do {
            // Fetch scoring explanation and thresholds from database
            await loadScoringExplanation()
            await loadVarietyThresholds()

            struct TypeReference: Codable {
                let referenceKey: String
                let displayName: String
                let displayOrder: Int?
                let description: String?

                enum CodingKeys: String, CodingKey {
                    case referenceKey = "reference_key"
                    case displayName = "display_name"
                    case displayOrder = "display_order"
                    case description
                }
            }

            // Query sample_category_types_reference for type options
            // Use typeReferenceCategory property for correct category name (handles singular/plural)
            let category = nutrientType.typeReferenceCategory

            let results: [TypeReference] = try await supabase
                .from("sample_category_types_reference")
                .select("reference_key, display_name, display_order, description")
                .eq("reference_category", value: category)
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            print("🍽️ Discovered \(results.count) type options for \(nutrientType.displayName) from sample_category_types_reference")

            // Sort by display order, but put "Other" last
            let sortedResults = results.sorted { a, b in
                let aIsOther = a.referenceKey.lowercased() == "other"
                let bIsOther = b.referenceKey.lowercased() == "other"

                if aIsOther && !bIsOther { return false }
                if !aIsOther && bIsOther { return true }
                return (a.displayOrder ?? 99) < (b.displayOrder ?? 99)
            }

            // Prefix to strip from reference_keys (e.g., "vegetables_types_" from "vegetables_types_root")
            let categoryPrefix = category + "_"

            // Assign gradient colors based on position
            let colorCount = Double(sortedResults.count)
            typeAggregations = sortedResults.enumerated().map { index, ref in
                let isOther = ref.referenceKey.lowercased() == "other" || ref.referenceKey.lowercased().hasSuffix("_other")

                let color: Color
                if isOther {
                    color = Color(red: 0.56, green: 0.56, blue: 0.58) // System gray
                } else {
                    // Gradient from dark to light based on position
                    let progress = colorCount > 1 ? Double(index) / (colorCount - 1) : 0
                    let opacity = 1.0 - (progress * 0.5) // Range from 1.0 to 0.5
                    color = baseColor.opacity(opacity)
                }

                // Normalize reference_key by stripping category prefix if present
                // e.g., "vegetables_types_root" -> "root"
                var normalizedKey = ref.referenceKey
                if normalizedKey.hasPrefix(categoryPrefix) {
                    normalizedKey = String(normalizedKey.dropFirst(categoryPrefix.count))
                }

                // Construct aggId for compatibility with existing display logic
                // Format: AGG_{NUTRIENT}_TYPE_{NORMALIZED_KEY_UPPER}
                let aggId = "AGG_\(nutrientType.rawValue)_TYPE_\(normalizedKey.uppercased())"

                return TypeAggregation(
                    aggId: aggId,
                    displayName: ref.displayName,
                    color: color,
                    description: ref.description
                )
            }

        } catch {
            print("❌ Error discovering type aggregations: \(error)")
        }
    }

    /// Fetches type descriptions from sample_category_types_reference
    private func fetchTypeDescriptions() async -> [String: String] {
        do {
            struct ReferenceData: Codable {
                let referenceKey: String
                let description: String?

                enum CodingKeys: String, CodingKey {
                    case referenceKey = "reference_key"
                    case description
                }
            }

            // Use typeReferenceCategory property for correct category name
            let category = nutrientType.typeReferenceCategory

            let results: [ReferenceData] = try await supabase
                .from("sample_category_types_reference")
                .select("reference_key, description")
                .eq("reference_category", value: category)
                .execute()
                .value

            // Build dictionary of reference_key -> description
            var descriptions: [String: String] = [:]
            for ref in results {
                if let desc = ref.description {
                    descriptions[ref.referenceKey] = desc
                }
            }

            print("🍽️ Loaded \(descriptions.count) type descriptions for \(category)")
            return descriptions

        } catch {
            print("❌ Error fetching type descriptions: \(error)")
            return [:]
        }
    }

    /// Loads scoring explanation from display_metrics
    private func loadScoringExplanation() async {
        do {
            struct MetricScoring: Codable {
                let scoringExplanation: String?

                enum CodingKeys: String, CodingKey {
                    case scoringExplanation = "scoring_explanation"
                }
            }

            let results: [MetricScoring] = try await supabase
                .from("display_views")
                .select("scoring_explanation")
                .eq("view_id", value: typeMetricId)
                .limit(1)
                .execute()
                .value

            scoringExplanation = results.first?.scoringExplanation
            print("🍽️ Loaded scoring explanation for \(typeMetricId): \(scoringExplanation != nil ? "found" : "not found")")

        } catch {
            print("❌ Error loading scoring explanation: \(error)")
        }
    }

    /// Loads variety score targets from database (scoring_thresholds table)
    private func loadVarietyThresholds() async {
        do {
            struct TargetRow: Codable {
                let periodType: String
                let targetValue: Double

                enum CodingKeys: String, CodingKey {
                    case periodType = "period_type"
                    case targetValue = "target_value"
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    periodType = try container.decode(String.self, forKey: .periodType)
                    // Handle numeric that may come as string
                    if let doubleValue = try? container.decode(Double.self, forKey: .targetValue) {
                        targetValue = doubleValue
                    } else if let stringValue = try? container.decode(String.self, forKey: .targetValue),
                              let parsed = Double(stringValue) {
                        targetValue = parsed
                    } else {
                        targetValue = 3
                    }
                }
            }

            // Query from consolidated scoring_thresholds table
            let results: [TargetRow] = try await supabase
                .from("scoring_thresholds")
                .select("period_type, target_value")
                .eq("view_id", value: typeMetricId)
                .eq("threshold_type", value: "variety")
                .eq("is_active", value: true)
                .execute()
                .value

            // Build targets dictionary
            for row in results {
                targets[row.periodType] = VarietyTarget(target: Int(row.targetValue))
            }

            print("🍽️ Loaded \(targets.count) variety targets for \(typeMetricId)")

        } catch {
            print("❌ Error loading variety targets: \(error)")
            // Fallback defaults if database fails
            targets = [
                "daily": VarietyTarget(target: 3),
                "weekly": VarietyTarget(target: 4),
                "monthly": VarietyTarget(target: 5),
                "yearly": VarietyTarget(target: 5)
            ]
        }
    }

    /// Extracts reference_key from aggId (e.g., AGG_LEGUMES_TYPE_LENTILS -> lentils)
    private func extractReferenceKey(from aggId: String, prefix: String) -> String {
        // Remove prefix and convert to lowercase
        let key = aggId.replacingOccurrences(of: prefix, with: "").lowercased()
        return key
    }

    /// Cleans the display name by removing nutrient prefix
    private func cleanTypeName(_ displayName: String) -> String {
        var name = displayName

        // Remove nutrient name from display (e.g., "Legumes Lentils" -> "Lentils")
        for nutrient in NutrientTimingType.allCases {
            name = name.replacingOccurrences(of: "\(nutrient.displayName) ", with: "")
        }

        return name.trimmingCharacters(in: .whitespaces)
    }

    /// Loads data for a specific period and date
    /// Uses AggregationQueryService which queries hourly (for D) or daily (for W/M/6M/Y)
    func loadDataForPeriod(period: TimePeriod, date: Date) async {
        isLoading = true
        typeData.removeAll()

        do {
            let aggIds = typeAggregations.map { $0.aggId }
            guard !aggIds.isEmpty else {
                isLoading = false
                return
            }

            print("🥗 Querying \(nutrientType.displayName) types for period: \(period.rawValue)")
            print("🥗   Date: \(date)")

            // Query patient_quantity_samples with metadata filtering for type breakdown
            let userId = try await supabase.auth.session.user.id
            let (startDate, endDate) = PatientSamplesQueryService.shared.getDateRange(for: period, date: date)

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            let startStr = formatter.string(from: startDate)
            let endStr = formatter.string(from: endDate)

            let samples: [NutrientTypeSample] = try await supabase
                .from("patient_quantity_samples")
                .select("id, aggregation_date, quantity_value, metadata")
                .eq("patient_id", value: userId)
                .eq("quantity_type", value: nutrientType.quantityType)
                .eq("is_primary", value: true)  // Only use primary samples for analysis
                .gte("aggregation_date", value: startStr)
                .lte("aggregation_date", value: endStr)
                .execute()
                .value

            // Group by type from metadata
            var typeSums: [String: Double] = [:]
            var dailyByType: [String: [Date: Double]] = [:]

            // Prefix to strip from metadata values (e.g., "vegetables_types_" from "vegetables_types_leafy_greens")
            let typePrefix = nutrientType.typeReferenceCategory + "_"

            for sample in samples {
                guard let value = sample.quantityValue,
                      let aggDate = sample.aggregationDate else { continue }

                // Extract type from metadata (e.g., "vegetables_types": "vegetables_types_leafy_greens" or "leafy_greens")
                var typeValue = sample.metadata?[nutrientType.typeMetadataKey]?.stringValue ?? "other"

                // Normalize: strip the category prefix if present (e.g., "vegetables_types_leafy_greens" -> "leafy_greens")
                if typeValue.hasPrefix(typePrefix) {
                    typeValue = String(typeValue.dropFirst(typePrefix.count))
                }

                // Convert to agg format for compatibility with existing display logic
                let aggId = "AGG_\(nutrientType.rawValue)_TYPE_\(typeValue.uppercased())"

                if period == .day {
                    typeSums[aggId, default: 0] += value
                } else {
                    dailyByType[aggId, default: [:]][aggDate, default: 0] += value
                }
            }

            if period == .day {
                typeData = typeSums
            } else {
                // Calculate average of daily totals
                for (aggId, dailyValues) in dailyByType {
                    guard !dailyValues.isEmpty else { continue }
                    let total = dailyValues.values.reduce(0, +)
                    typeData[aggId] = total / Double(dailyValues.count)
                }
            }

            print("🥗 Found \(typeData.count) type results for period")

            // Update colors based on consumption amounts (highest = darkest)
            updateColorsBasedOnConsumption()

        } catch {
            print("❌ Error loading type data: \(error)")
        }

        isLoading = false
    }

    /// Updates colors so highest consumption = darkest shade
    /// Uses a wider opacity range for better visual differentiation
    private func updateColorsBasedOnConsumption() {
        // Get types sorted by consumption (excluding Other)
        let sortedTypes = typeAggregations
            .filter { !$0.aggId.hasSuffix("_OTHER") }
            .sorted { (typeData[$0.aggId] ?? 0) > (typeData[$1.aggId] ?? 0) }

        let count = sortedTypes.count

        // Define opacity steps for better differentiation
        // More types = more granular steps, fewer types = bigger jumps
        let opacities: [Double]
        switch count {
        case 0:
            opacities = []
        case 1:
            opacities = [1.0]
        case 2:
            opacities = [1.0, 0.55] // Big contrast for 2 types
        case 3:
            opacities = [1.0, 0.7, 0.45]
        case 4:
            opacities = [1.0, 0.8, 0.6, 0.4]
        case 5:
            opacities = [1.0, 0.85, 0.7, 0.55, 0.4]
        default:
            // For 6+ types, calculate evenly spaced opacities from 1.0 to 0.35
            opacities = (0..<count).map { index in
                1.0 - (Double(index) / Double(count - 1)) * 0.65
            }
        }

        for (index, type) in sortedTypes.enumerated() {
            if let aggIndex = typeAggregations.firstIndex(where: { $0.aggId == type.aggId }) {
                let opacity = index < opacities.count ? opacities[index] : 0.4
                typeAggregations[aggIndex].color = baseColor.opacity(opacity)
            }
        }
    }

    // MARK: - Variety Score Calculation

    /// Calculates the Variety Score (0-100) based on types consumed vs target
    /// Score = types consumed / target, capped at 100%
    func calculateVarietyScore(for period: TimePeriod = .week) -> Double {
        guard hasData else { return 0 }

        let typesConsumed = typeAggregations.filter { type in
            !type.aggId.hasSuffix("_OTHER") && (typeData[type.aggId] ?? 0) > 0
        }.count

        guard typesConsumed > 0 else { return 0 }

        // Map TimePeriod to database period_type
        let periodKey: String
        switch period {
        case .day: periodKey = "daily"
        case .week: periodKey = "weekly"
        case .month: periodKey = "monthly"
        case .sixMonth: periodKey = "monthly"  // Use monthly targets for 6M
        case .year: periodKey = "yearly"
        }

        // Get target (fallback to sensible default)
        let target = targets[periodKey]?.target ?? 3

        // Score = types consumed / target, capped at 100%
        return min(Double(typesConsumed) / Double(target), 1.0) * 100
    }

    // MARK: - Helper Methods

    func getDisplayName(for aggId: String) -> String {
        typeAggregations.first { $0.aggId == aggId }?.displayName ?? aggId
    }

    func getColor(for aggId: String) -> Color {
        typeAggregations.first { $0.aggId == aggId }?.color ?? .gray
    }

    /// Get types sorted by consumption amount (highest first)
    func getSortedTypesByConsumption() -> [TypeAggregation] {
        typeAggregations.sorted {
            let value1 = typeData[$0.aggId] ?? 0
            let value2 = typeData[$1.aggId] ?? 0

            // "Other" always goes last
            if $0.aggId.hasSuffix("_OTHER") && !$1.aggId.hasSuffix("_OTHER") { return false }
            if !$0.aggId.hasSuffix("_OTHER") && $1.aggId.hasSuffix("_OTHER") { return true }

            return value1 > value2
        }
    }

    /// Get types with data only, sorted by consumption
    func getTypesWithData() -> [TypeAggregation] {
        getSortedTypesByConsumption().filter { (typeData[$0.aggId] ?? 0) > 0 }
    }

    // MARK: - Period Calculation Helpers

    private func getPeriodStart(for period: TimePeriod, date: Date) -> Date {
        let calendar = Calendar.current
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        switch period {
        case .day:
            let localComponents = calendar.dateComponents([.year, .month, .day], from: date)
            var utcComponents = DateComponents()
            utcComponents.year = localComponents.year
            utcComponents.month = localComponents.month
            utcComponents.day = localComponents.day
            utcComponents.hour = 0
            utcComponents.minute = 0
            utcComponents.second = 0
            utcComponents.timeZone = TimeZone(identifier: "UTC")
            return utcCalendar.date(from: utcComponents)!

        case .week:
            let localComponents = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
            let weekday = localComponents.weekday!
            let daysFromMonday = (weekday == 1) ? -6 : (2 - weekday)
            let localMonday = calendar.date(byAdding: .day, value: daysFromMonday, to: date)!
            let mondayComponents = calendar.dateComponents([.year, .month, .day], from: localMonday)

            var utcComponents = DateComponents()
            utcComponents.year = mondayComponents.year
            utcComponents.month = mondayComponents.month
            utcComponents.day = mondayComponents.day
            utcComponents.hour = 0
            utcComponents.minute = 0
            utcComponents.second = 0
            utcComponents.timeZone = TimeZone(identifier: "UTC")
            return utcCalendar.date(from: utcComponents)!

        case .month:
            let localComponents = calendar.dateComponents([.year, .month], from: date)
            var utcComponents = DateComponents()
            utcComponents.year = localComponents.year
            utcComponents.month = localComponents.month
            utcComponents.day = 1
            utcComponents.hour = 0
            utcComponents.minute = 0
            utcComponents.second = 0
            utcComponents.timeZone = TimeZone(identifier: "UTC")
            return utcCalendar.date(from: utcComponents)!

        case .sixMonth:
            let localComponents = calendar.dateComponents([.year, .month], from: date)
            let year = localComponents.year!
            let month = localComponents.month!
            let startMonth = month <= 6 ? 1 : 7

            var utcComponents = DateComponents()
            utcComponents.year = year
            utcComponents.month = startMonth
            utcComponents.day = 1
            utcComponents.hour = 0
            utcComponents.minute = 0
            utcComponents.second = 0
            utcComponents.timeZone = TimeZone(identifier: "UTC")
            return utcCalendar.date(from: utcComponents)!

        case .year:
            let localComponents = calendar.dateComponents([.year], from: date)
            var utcComponents = DateComponents()
            utcComponents.year = localComponents.year
            utcComponents.month = 1
            utcComponents.day = 1
            utcComponents.hour = 0
            utcComponents.minute = 0
            utcComponents.second = 0
            utcComponents.timeZone = TimeZone(identifier: "UTC")
            return utcCalendar.date(from: utcComponents)!
        }
    }
}

// MARK: - Sample Query Model

private struct NutrientTypeSample: Codable {
    let id: UUID
    let aggregationDateString: String?
    let quantityValue: Double?
    let metadata: [String: AnyJSON]?

    enum CodingKeys: String, CodingKey {
        case id
        case aggregationDateString = "aggregation_date"
        case quantityValue = "quantity_value"
        case metadata
    }

    /// Parse aggregation_date as a local date (noon to avoid DST issues)
    /// The database DATE represents a calendar day, not a UTC timestamp
    var aggregationDate: Date? {
        guard let dateString = aggregationDateString else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone.current  // Parse as local time, not UTC
        return formatter.date(from: dateString + " 12:00")  // Noon local to avoid DST edge cases
    }
}
