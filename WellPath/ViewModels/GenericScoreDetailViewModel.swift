//
//  GenericScoreDetailViewModel.swift
//  WellPath
//
//  ViewModel for database-driven score detail views.
//  Loads calculation_method, components, and patient data.
//

import Foundation
import SwiftUI
import Supabase

// MARK: - Score Type Info

struct ScoreTypeInfo: Codable {
    let scoreType: String
    let displayName: String?
    let calculationMethod: String?
    let calculationConfig: String?  // JSON config if needed
    let iconName: String?
    let colorHex: String?

    enum CodingKeys: String, CodingKey {
        case scoreType = "score_type"
        case displayName = "display_name"
        case calculationMethod = "calculation_method"
        case calculationConfig = "calculation_config"
        case iconName = "icon_name"
        case colorHex = "color_hex"
    }
}

// MARK: - Component Weight

struct ScoreComponentWeight: Identifiable, Codable {
    let id: UUID
    let componentScoreType: String
    let weight: Double
    let displayName: String?
    let iconName: String?
    let displayOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case componentScoreType = "component_score_type"
        case weight
        case displayName = "display_name"
        case iconName = "icon_name"
        case displayOrder = "display_order"
    }

    var weightPercentage: String {
        "\(Int(weight * 100))%"
    }
}

// MARK: - Patient Cycle Status

struct PatientCycleStatus: Codable {
    let phase: String
}

// MARK: - Daily Score Result

struct DailyScoreResult: Codable {
    let scoreType: String
    let scoreValue: Double
    let scoreDate: String

    enum CodingKeys: String, CodingKey {
        case scoreType = "score_type"
        case scoreValue = "score_value"
        case scoreDate = "score_date"
    }
}

// MARK: - Score Component (from behavioral_score_components view)

struct ScoreComponent: Codable, Identifiable {
    var id: String { "\(scoreType)_\(componentKey)_\(scoreDate)" }

    let scoreType: String
    let scoreDate: String
    let scoreContext: String
    let componentKey: String
    let componentValue: Double?
    let componentPct: Double?
    let targetPct: Double?

    enum CodingKeys: String, CodingKey {
        case scoreType = "score_type"
        case scoreDate = "score_date"
        case scoreContext = "score_context"
        case componentKey = "component_key"
        case componentValue = "component_value"
        case componentPct = "component_pct"
        case targetPct = "target_pct"
    }
}

// MARK: - Baseline History Entry

struct BaselineHistoryEntry: Codable, Identifiable {
    let id: UUID
    let baselineType: String
    let value: Double
    let assessmentDate: String
    let source: String
    let supersededAt: String?
    let cycleId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case baselineType = "baseline_type"
        case value
        case assessmentDate = "assessment_date"
        case source
        case supersededAt = "superseded_at"
        case cycleId = "cycle_id"
    }

    var sourceDisplayName: String {
        switch source {
        case "onboarding", "onboarding_calculated": return "Onboarding"
        case "tracked": return "From Tracked Data"
        case "manual", "manual_update": return "Manual Entry"
        case "healthkit": return "HealthKit"
        case "assessment": return "Assessment"
        default: return source.capitalized
        }
    }
}

// MARK: - ViewModel

@MainActor
class GenericScoreDetailViewModel: ObservableObject {
    // Configuration
    @Published var scoreTypeInfo: ScoreTypeInfo?
    @Published var calculationMethod: ScoreCalculationMethod = .unknown
    @Published var components: [ScoreComponentWeight] = []
    @Published var componentScoreTypes: [String: ScoreTypeInfo] = [:]

    // Descriptions (for accordions)
    @Published var mainDescription: String?  // From display_behavioral_scores
    @Published var scoringExplanation: String?  // From display_behavioral_scores
    @Published var componentDescriptions: [String: String] = [:]  // From sample_behavioral_score_types

    // Scores
    @Published var dailyCompositeScore: Int?
    @Published var dailyComponentScores: [String: Int] = [:]  // component_score_type -> score
    @Published var baselineCompositeScore: Int?
    @Published var baselineComponentScores: [String: Int] = [:]
    @Published var scoreHistory: [String: Int] = [:]  // date -> composite score

    // Editability
    @Published var isEditable = false
    @Published var editabilityReason: String?
    @Published var patientCycleStatus: String?

    // Loading states
    @Published var isLoading = false
    @Published var isLoadingHistory = false
    @Published var error: String?

    // Baseline data
    @Published var baselineAssessmentDate: String?
    @Published var baselines: [String: Double] = [:]
    @Published var relatedBaselineTypes: [String] = []
    @Published var baselineHistory: [BaselineHistoryEntry] = []  // Historical baselines (superseded)

    private let supabase = SupabaseManager.shared.client
    let scoreType: String
    let viewId: String?  // Optional display_views reference

    init(scoreType: String, viewId: String? = nil) {
        self.scoreType = scoreType
        self.viewId = viewId
    }

    // MARK: - Load All Data

    func loadAll() async {
        isLoading = true
        error = nil

        // First, try to populate from cache for instant display
        populateFromCache()

        do {
            // Load metadata (components, score type info) - these are small queries
            async let scoreTypeTask = loadScoreTypeInfo()
            async let componentsTask = loadComponents()
            async let cycleTask = loadPatientCycleStatus()

            _ = try await (scoreTypeTask, componentsTask, cycleTask)

            // After components loaded, load baseline types (depends on components for composite scores)
            try await loadRelatedBaselineTypes()

            // After components loaded, load component type info
            await loadComponentScoreTypes()

            // Load scores - use cache where available, otherwise load from DB
            if dailyCompositeScore == nil {
                // No daily score in cache - load from DB
                try await loadDailyScores()
            } else {
                // Populate daily component scores from cache
                var componentScores: [String: Int] = [:]
                for component in components {
                    if let score = ScoreCacheService.shared.dailyScore(for: component.componentScoreType) {
                        componentScores[component.componentScoreType] = score
                    }
                }
                dailyComponentScores = componentScores
            }

            // Always load baseline scores from DB if not in cache
            // (baseline scores may not be cached even when daily scores are)
            if baselineCompositeScore == nil {
                try await loadBaselineScores()
            } else {
                // Populate baseline component scores from cache
                var baselineComp: [String: Int] = [:]
                for component in components {
                    if let score = ScoreCacheService.shared.baselineScore(for: component.componentScoreType) {
                        baselineComp[component.componentScoreType] = score
                    }
                }
                baselineComponentScores = baselineComp
            }

        } catch {
            self.error = error.localizedDescription
            print("Error loading score detail: \(error)")
        }

        isLoading = false
    }

    /// Populate scores from cache for instant display
    private func populateFromCache() {
        let cache = ScoreCacheService.shared
        guard cache.isLoaded else { return }

        // Get composite score
        if let score = cache.dailyScore(for: scoreType) {
            dailyCompositeScore = score
        }

        // Get baseline composite
        if let score = cache.baselineScore(for: scoreType) {
            baselineCompositeScore = score
        }
    }

    /// Refresh baseline data after editing
    func refreshBaselines() async {
        // Invalidate the score cache first since baseline data changed
        ScoreCacheService.shared.invalidate()

        // Clear cached values so they get reloaded
        baselineCompositeScore = nil
        baselineComponentScores = [:]

        do {
            try await loadBaselineScores()

            // Also refresh the score cache in background
            Task.detached { @MainActor in
                await ScoreCacheService.shared.refresh()
            }
        } catch {
            print("Error refreshing baselines: \(error)")
        }
    }

    // MARK: - Score Type Info

    private func loadScoreTypeInfo() async throws {
        let results: [ScoreTypeInfo] = try await supabase
            .from("sample_behavioral_score_types")
            .select("score_type, display_name, calculation_method, calculation_config, icon_name, color_hex")
            .eq("score_type", value: scoreType)
            .limit(1)
            .execute()
            .value

        if let info = results.first {
            scoreTypeInfo = info
            calculationMethod = ScoreCalculationMethod(rawValue: info.calculationMethod ?? "") ?? .unknown
        }

        // Also load display description from display_behavioral_scores
        struct DisplayScore: Codable {
            let description: String?
            let scoringExplanation: String?

            enum CodingKeys: String, CodingKey {
                case description
                case scoringExplanation = "scoring_explanation"
            }
        }

        let displayResults: [DisplayScore] = try await supabase
            .from("display_behavioral_scores")
            .select("description, scoring_explanation")
            .eq("score_type", value: scoreType)
            .limit(1)
            .execute()
            .value

        if let display = displayResults.first {
            mainDescription = display.description
            scoringExplanation = display.scoringExplanation
        }
    }

    // MARK: - Components

    private func loadComponents() async throws {
        let results: [ScoreComponentWeight] = try await supabase
            .from("scoring_component_weights")
            .select("id, component_score_type, weight, display_name, icon_name, display_order")
            .eq("output_score_type", value: scoreType)
            .eq("is_active", value: true)
            .order("display_order", ascending: true)
            .execute()
            .value

        components = results
    }

    private func loadComponentScoreTypes() async {
        let componentTypes = components.map { $0.componentScoreType }
        guard !componentTypes.isEmpty else { return }

        do {
            // Load both score type info and descriptions
            struct ComponentInfo: Codable {
                let scoreType: String
                let displayName: String?
                let calculationMethod: String?
                let iconName: String?
                let colorHex: String?
                let description: String?

                enum CodingKeys: String, CodingKey {
                    case scoreType = "score_type"
                    case displayName = "display_name"
                    case calculationMethod = "calculation_method"
                    case iconName = "icon_name"
                    case colorHex = "color_hex"
                    case description
                }
            }

            // Note: calculation_config removed from query - it's JSONB and not needed here
            let results: [ComponentInfo] = try await supabase
                .from("sample_behavioral_score_types")
                .select("score_type, display_name, calculation_method, icon_name, color_hex, description")
                .in("score_type", values: componentTypes)
                .execute()
                .value

            var typeMap: [String: ScoreTypeInfo] = [:]
            var descMap: [String: String] = [:]
            for info in results {
                typeMap[info.scoreType] = ScoreTypeInfo(
                    scoreType: info.scoreType,
                    displayName: info.displayName,
                    calculationMethod: info.calculationMethod,
                    calculationConfig: nil,  // Not needed for display
                    iconName: info.iconName,
                    colorHex: info.colorHex
                )
                if let desc = info.description {
                    descMap[info.scoreType] = desc
                }
            }
            componentScoreTypes = typeMap
            componentDescriptions = descMap
            print("[ViewModel] Loaded \(typeMap.count) component score types: \(typeMap.keys.sorted())")
            for (key, info) in typeMap {
                print("  - \(key): method=\(info.calculationMethod ?? "nil")")
            }
        } catch {
            print("Error loading component score types: \(error)")
        }
    }

    // MARK: - Patient Cycle Status

    private func loadPatientCycleStatus() async throws {
        let userId = try await supabase.auth.session.user.id

        let results: [PatientCycleStatus] = try await supabase
            .from("patient_cycles")
            .select("phase")
            .eq("patient_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value

        if let cycle = results.first {
            patientCycleStatus = cycle.phase
            // Editable during onboarding or retrospective (between cycles)
            isEditable = ["onboarding", "retrospective"].contains(cycle.phase)
            editabilityReason = isEditable
                ? "You can update your baseline during \(cycle.phase)"
                : "Baselines can only be edited during onboarding or between cycles"
        } else {
            // No active cycle = editable
            isEditable = true
            editabilityReason = "No active cycle - baselines are editable"
        }
    }

    // MARK: - Daily Scores

    private func loadDailyScores() async throws {
        let userId = try await supabase.auth.session.user.id

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFormatter.string(from: Date())

        // Get all relevant score types (composite + components)
        var scoreTypes = [scoreType]
        scoreTypes.append(contentsOf: components.map { $0.componentScoreType })

        let results: [DailyScoreResult] = try await supabase
            .from("behavioral_scores")
            .select("score_type, score_value, score_date")
            .eq("patient_id", value: userId.uuidString)
            .eq("score_date", value: todayStr)
            .eq("score_context", value: "daily")
            .in("score_type", values: scoreTypes)
            .execute()
            .value

        var componentScores: [String: Int] = [:]
        for result in results {
            let score = Int(result.scoreValue.rounded())
            if result.scoreType == scoreType {
                dailyCompositeScore = score
            } else {
                componentScores[result.scoreType] = score
            }
        }
        dailyComponentScores = componentScores
    }

    // MARK: - Baseline Scores

    private func loadRelatedBaselineTypes() async throws {
        // Query score_data_sources to get baseline types for this score and its components
        // For composite scores, we need to get baselines from all component scores

        struct DataSourceResult: Codable {
            let baselineType: String?

            enum CodingKeys: String, CodingKey {
                case baselineType = "baseline_type"
            }
        }

        // Build list of score types to query: this score + its component scores
        var scoreTypesToQuery = [scoreType]
        scoreTypesToQuery.append(contentsOf: components.map { $0.componentScoreType })

        let results: [DataSourceResult] = try await supabase
            .from("score_data_sources")
            .select("baseline_type")
            .in("score_type", values: scoreTypesToQuery)
            .eq("source_context", value: "baseline")
            .execute()
            .value

        // Filter out nil values and dedupe
        relatedBaselineTypes = Array(Set(results.compactMap { $0.baselineType }))
    }

    private func loadBaselineScores() async throws {
        let userId = try await supabase.auth.session.user.id

        var scoreTypes = [scoreType]
        scoreTypes.append(contentsOf: components.map { $0.componentScoreType })

        let results: [DailyScoreResult] = try await supabase
            .from("behavioral_scores")
            .select("score_type, score_value, score_date")
            .eq("patient_id", value: userId.uuidString)
            .eq("score_context", value: "baseline")
            .in("score_type", values: scoreTypes)
            .order("score_date", ascending: false)
            .limit(scoreTypes.count)
            .execute()
            .value

        var componentScores: [String: Int] = [:]
        for result in results {
            let score = Int(result.scoreValue.rounded())
            if result.scoreType == scoreType {
                baselineCompositeScore = score
                baselineAssessmentDate = String(result.scoreDate.prefix(10))
            } else {
                componentScores[result.scoreType] = score
            }
        }
        baselineComponentScores = componentScores
    }

    /// Load historical baselines (superseded entries) for this score's related baseline types
    func loadBaselineHistory() async {
        guard !relatedBaselineTypes.isEmpty else { return }

        do {
            let userId = try await supabase.auth.session.user.id

            // Query superseded baselines (is_current = false)
            let results: [BaselineHistoryEntry] = try await supabase
                .from("patient_baseline_samples")
                .select("id, baseline_type, value, assessment_date, source, superseded_at, cycle_id")
                .eq("patient_id", value: userId.uuidString)
                .in("baseline_type", values: relatedBaselineTypes)
                .eq("is_current", value: false)
                .order("superseded_at", ascending: false)
                .limit(50)  // Reasonable limit for history
                .execute()
                .value

            baselineHistory = results
        } catch {
            print("Error loading baseline history: \(error)")
        }
    }

    // MARK: - Score History

    func loadScoreHistory(days: Int = 90) async {
        isLoadingHistory = true

        do {
            let userId = try await supabase.auth.session.user.id

            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            guard let startDate = calendar.date(byAdding: .day, value: -days, to: today) else { return }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let startStr = dateFormatter.string(from: startDate)

            let results: [DailyScoreResult] = try await supabase
                .from("behavioral_scores")
                .select("score_type, score_value, score_date")
                .eq("patient_id", value: userId.uuidString)
                .eq("score_type", value: scoreType)
                .eq("score_context", value: "daily")
                .gte("score_date", value: startStr)
                .order("score_date", ascending: false)
                .execute()
                .value

            var history: [String: Int] = [:]
            for result in results {
                let dateKey = String(result.scoreDate.prefix(10))
                history[dateKey] = Int(result.scoreValue.rounded())
            }
            scoreHistory = history

        } catch {
            print("Error loading score history: \(error)")
        }

        isLoadingHistory = false
    }

    // MARK: - Load Scores for Specific Date

    func loadScoresForDate(_ date: Date) async -> (composite: Int?, components: [String: Int]) {
        do {
            let userId = try await supabase.auth.session.user.id

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateStr = dateFormatter.string(from: date)

            var scoreTypes = [scoreType]
            scoreTypes.append(contentsOf: components.map { $0.componentScoreType })

            let results: [DailyScoreResult] = try await supabase
                .from("behavioral_scores")
                .select("score_type, score_value, score_date")
                .eq("patient_id", value: userId.uuidString)
                .eq("score_date", value: dateStr)
                .eq("score_context", value: "daily")
                .in("score_type", values: scoreTypes)
                .execute()
                .value

            var composite: Int?
            var componentScores: [String: Int] = [:]

            for result in results {
                let score = Int(result.scoreValue.rounded())
                if result.scoreType == scoreType {
                    composite = score
                } else {
                    componentScores[result.scoreType] = score
                }
            }

            return (composite, componentScores)

        } catch {
            print("Error loading scores for date: \(error)")
            return (nil, [:])
        }
    }

    // MARK: - Refresh

    func refresh() async {
        await loadAll()
    }

    // MARK: - Helpers

    /// Get calculation method for a component score type
    func calculationMethod(for componentType: String) -> ScoreCalculationMethod {
        guard let info = componentScoreTypes[componentType],
              let method = info.calculationMethod else {
            return .unknown
        }
        return ScoreCalculationMethod(rawValue: method) ?? .unknown
    }

    /// Get component by score type
    func component(for scoreType: String) -> ScoreComponentWeight? {
        components.first { $0.componentScoreType == scoreType }
    }

    /// Check if this is a composite score
    var isComposite: Bool {
        calculationMethod == .composite || !components.isEmpty
    }

    /// Get display color
    var displayColor: Color {
        if let hex = scoreTypeInfo?.colorHex {
            return Color(hex: hex) ?? .blue
        }
        return .blue
    }
}

// MARK: - Component Detail Data

extension GenericScoreDetailViewModel {
    /// Load tier type values for weighted_tiers calculation method (e.g., protein_type_score)
    /// Returns: [type_reference_key: total_grams] for the given date
    func loadTierTypeValues(for date: Date, category: String) async -> [String: Double] {
        do {
            let userId = try await supabase.auth.session.user.id

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateStr = dateFormatter.string(from: date)

            // Use different struct for each category since columns are different
            switch category {
            case "protein_types":
                struct ProteinRow: Codable {
                    let proteinTier: String?
                    let proteinG: Double?

                    enum CodingKeys: String, CodingKey {
                        case proteinTier = "protein_tier"
                        case proteinG = "protein_g"
                    }
                }

                let results: [ProteinRow] = try await supabase
                    .from("patient_food_log_view")
                    .select("protein_tier, protein_g")
                    .eq("patient_id", value: userId.uuidString)
                    .eq("aggregation_date", value: dateStr)
                    .execute()
                    .value

                var typeValues: [String: Double] = [:]
                for row in results {
                    if let tier = row.proteinTier, let grams = row.proteinG, !tier.isEmpty {
                        typeValues[tier, default: 0] += grams
                    }
                }
                return typeValues

            case "fat_types":
                struct FatRow: Codable {
                    let fatTier: String?
                    let fatTotalG: Double?

                    enum CodingKeys: String, CodingKey {
                        case fatTier = "fat_tier"
                        case fatTotalG = "fat_total_g"
                    }
                }

                let results: [FatRow] = try await supabase
                    .from("patient_food_log_view")
                    .select("fat_tier, fat_total_g")
                    .eq("patient_id", value: userId.uuidString)
                    .eq("aggregation_date", value: dateStr)
                    .execute()
                    .value

                var typeValues: [String: Double] = [:]
                for row in results {
                    if let tier = row.fatTier, let grams = row.fatTotalG, !tier.isEmpty {
                        typeValues[tier, default: 0] += grams
                    }
                }
                return typeValues

            default:
                return [:]
            }

        } catch {
            print("Error loading tier type values: \(error)")
            return [:]
        }
    }

    /// Load timing window values for timing_distribution calculation method
    /// Groups individual samples by time window based on start_time hour
    /// Returns: [threshold_key: total_value] for the given date (e.g., ["morning": 500, "afternoon": 1200])
    func loadTimingWindowValues(for date: Date, scoreType: String) async -> [String: Double] {
        do {
            let userId = try await supabase.auth.session.user.id

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateStr = dateFormatter.string(from: date)

            // Map score_type to quantity_type (matches score_data_sources table)
            let quantityType: String
            switch scoreType {
            case "hydration_timing_score":
                quantityType = "water_ml"
            case "caffeine_timing_score":
                quantityType = "caffeine_mg"
            default:
                print("Unknown timing score type: \(scoreType)")
                return [:]
            }

            // Query individual samples with their timestamps
            struct TimingRow: Codable {
                let canonicalValue: Double
                let startTime: Date

                enum CodingKeys: String, CodingKey {
                    case canonicalValue = "canonical_value"
                    case startTime = "start_time"
                }
            }

            let results: [TimingRow] = try await supabase
                .from("patient_quantity_samples")
                .select("canonical_value, start_time")
                .eq("patient_id", value: userId.uuidString)
                .eq("quantity_type", value: quantityType)
                .eq("aggregation_date", value: dateStr)
                .execute()
                .value

            // Group by time window based on hour (matching calculate_timing_distribution_score function)
            // Morning: 6-11 (6am-12pm), Afternoon: 12-17 (12pm-6pm), Evening: 18-21 (6pm-10pm), Night: 22-5 (10pm-6am)
            var windowValues: [String: Double] = [
                "morning": 0,
                "afternoon": 0,
                "evening": 0,
                "night": 0
            ]

            let calendar = Calendar.current
            for row in results {
                let hour = calendar.component(.hour, from: row.startTime)
                let window: String
                if hour >= 6 && hour < 12 {
                    window = "morning"
                } else if hour >= 12 && hour < 18 {
                    window = "afternoon"
                } else if hour >= 18 && hour < 22 {
                    window = "evening"
                } else {
                    window = "night"
                }
                windowValues[window, default: 0] += row.canonicalValue
            }

            return windowValues

        } catch {
            print("Error loading timing window values: \(error)")
            return [:]
        }
    }

    /// Load quantity value for scoring_ranges calculation method
    /// Returns: total value for the quantity type on the given date
    /// NOTE: quantityType param is the scoring_ranges key - we map to actual data quantity_type
    func loadQuantityValue(for date: Date, quantityType: String) async -> Double? {
        do {
            let userId = try await supabase.auth.session.user.id

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateStr = dateFormatter.string(from: date)

            // Use quantity type directly - scoring_ranges and daily_summary now use consistent types
            let dataQuantityType = quantityType

            struct SummaryRow: Codable {
                let totalValue: Double?

                enum CodingKeys: String, CodingKey {
                    case totalValue = "total_value"
                }
            }

            let results: [SummaryRow] = try await supabase
                .from("patient_quantity_daily_summary")
                .select("total_value")
                .eq("patient_id", value: userId.uuidString)
                .eq("sample_date", value: dateStr)
                .eq("quantity_type", value: dataQuantityType)
                .limit(1)
                .execute()
                .value

            return results.first?.totalValue

        } catch {
            print("Error loading quantity value: \(error)")
            return nil
        }
    }

    /// Derive reference category from score type (e.g., protein_type_score -> protein_types)
    func referenceCategory(for scoreType: String) -> String {
        scoreType
            .replacingOccurrences(of: "_score", with: "s")
            .replacingOccurrences(of: "_types", with: "_types")  // preserve if already there
    }

    /// Derive quantity type from score type for scoring_ranges lookup
    /// Maps score_type -> sample_scoring_ranges.quantity_type
    /// NOTE: Must match quantity_type values in sample_scoring_ranges table
    func quantityType(for scoreType: String) -> String {
        // Complete mapping from score_type to scoring_ranges.quantity_type
        let mappings: [String: String] = [
            // Hydration
            "hydration_amount_score": "water_ml",

            // Protein
            "protein_ratio_score": "daily_protein_ratio",

            // Fats
            "fat_amount_score": "daily_fat_ratio",
            "fat_ratio_score": "daily_fat_ratio",

            // Caffeine
            "caffeine_amount_score": "caffeine_mg",
            "caffeine_timing_score": "caffeine_hours_before_bed",

            // Movement
            "steps_score": "steps",
            "move_minutes_score": "move_minutes",
            "stand_time_score": "stand_time",
            "active_calories_score": "active_calories",
            "exercise_snacks_daily_score": "exercise_snacks_daily",

            // Cardio
            "cardio_duration_score": "cardio_duration",
            "cardio_sessions_weekly_score": "cardio_sessions_weekly",

            // Strength
            "strength_duration_score": "strength_duration",
            "strength_sessions_weekly_score": "strength_sessions_weekly",

            // HIIT
            "hiit_duration_score": "hiit_duration",
            "hiit_sessions_weekly_score": "hiit_sessions_weekly",

            // Mobility
            "mobility_duration_score": "mobility_duration",
            "mobility_sessions_weekly_score": "mobility_sessions_weekly",

            // Sleep
            "sleep_duration_score": "sleep_duration",
            "sleep_consistency_score": "sleep_consistency_bedtime",  // or waketime

            // Food servings
            "fruits_quantity_score": "fruits_servings",
            "vegetables_quantity_score": "vegetables_servings",
            "legumes_quantity_score": "legumes_servings",
            "whole_grains_quantity_score": "whole_grains_servings",
            "nuts_seeds_quantity_score": "nuts_seeds_servings"
        ]
        return mappings[scoreType] ?? scoreType.replacingOccurrences(of: "_score", with: "")
    }
}

// MARK: - Score Components (from behavioral_score_components view)

extension GenericScoreDetailViewModel {
    /// Load pre-calculated score components from behavioral_score_components view
    /// This is the single source of truth for component breakdowns
    /// Returns: [component_key: ScoreComponent]
    func loadScoreComponents(for date: Date, scoreType: String, context: String = "daily") async -> [String: ScoreComponent] {
        do {
            let userId = try await supabase.auth.session.user.id

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateStr = dateFormatter.string(from: date)

            let results: [ScoreComponent] = try await supabase
                .from("behavioral_score_components")
                .select("score_type, score_date, score_context, component_key, component_value, component_pct, target_pct")
                .eq("patient_id", value: userId.uuidString)
                .eq("score_type", value: scoreType)
                .eq("score_date", value: dateStr)
                .eq("score_context", value: context)
                .execute()
                .value

            var componentMap: [String: ScoreComponent] = [:]
            for component in results {
                componentMap[component.componentKey] = component
            }
            return componentMap

        } catch {
            print("Error loading score components: \(error)")
            return [:]
        }
    }

    /// Load baseline score components (uses most recent baseline)
    func loadBaselineScoreComponents(scoreType: String) async -> [String: ScoreComponent] {
        do {
            let userId = try await supabase.auth.session.user.id

            let results: [ScoreComponent] = try await supabase
                .from("behavioral_score_components")
                .select("score_type, score_date, score_context, component_key, component_value, component_pct, target_pct")
                .eq("patient_id", value: userId.uuidString)
                .eq("score_type", value: scoreType)
                .eq("score_context", value: "baseline")
                .order("score_date", ascending: false)
                .execute()
                .value

            var componentMap: [String: ScoreComponent] = [:]
            for component in results {
                componentMap[component.componentKey] = component
            }
            return componentMap

        } catch {
            print("Error loading baseline score components: \(error)")
            return [:]
        }
    }
}

// MARK: - Extension for Unit Preferences (if needed)

extension GenericScoreDetailViewModel {
    /// Load baseline values for the score
    func loadBaselines(baselineTypes: [String]) async {
        do {
            let userId = try await supabase.auth.session.user.id

            struct BaselineResult: Codable {
                let baselineType: String
                let canonicalValue: Double?

                enum CodingKeys: String, CodingKey {
                    case baselineType = "baseline_type"
                    case canonicalValue = "canonical_value"
                }
            }

            let results: [BaselineResult] = try await supabase
                .from("patient_baseline_samples")
                .select("baseline_type, canonical_value")
                .eq("patient_id", value: userId.uuidString)
                .in("baseline_type", values: baselineTypes)
                .eq("is_current", value: true)
                .execute()
                .value

            var baselineMap: [String: Double] = [:]
            for result in results {
                if let value = result.canonicalValue {
                    baselineMap[result.baselineType] = value
                }
            }
            baselines = baselineMap

        } catch {
            print("Error loading baselines: \(error)")
        }
    }
}
