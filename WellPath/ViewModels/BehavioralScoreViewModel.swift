//
//  BehavioralScoreViewModel.swift
//  WellPath
//
//  ViewModel for fetching and managing behavioral scores with display configuration
//

import Foundation
import Supabase

@MainActor
class BehavioralScoreViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var displayConfig: BehavioralScoreDisplay?
    @Published var components: [BehavioralScoreComponent] = []
    @Published var baselines: [String: Double] = [:]
    @Published var previousBaselines: [String: Double] = [:]  // Previous cycle baselines
    @Published var baselineAssessmentDate: String?  // When current baseline was set
    @Published var previousBaselineDate: String?  // When previous baseline was set
    @Published var weightUnit: String = "kg"  // Default to kg (canonical)
    @Published var dailyScore: Double?  // Today's calculated score
    @Published var dailyScoreComponents: [String: Double] = [:]  // Today's component scores
    @Published var baselineScores: [String: Double] = [:]  // Baseline scores from behavioral_scores view
    @Published var actualDaysTracked: Int = 0  // Real count from database
    @Published var isLoading = false
    @Published var error: String?

    // Editability
    @Published var isEditable = true
    @Published var editabilityReason: String?
    @Published var cyclePhase: String?

    // MARK: - Private Properties

    private let scoreId: String
    private let scoreType: String

    // MARK: - Initialization

    init(scoreId: String, scoreType: String) {
        self.scoreId = scoreId
        self.scoreType = scoreType
    }

    // MARK: - Quantity type for daily score (override in subclass)

    var dailyScoreQuantityType: String? { nil }
    var dailyScoreComponentTypes: [String] { [] }
    var trackingQuantityType: String? { nil }  // For counting days tracked
    var baselineTypes: [String] { [] }  // Baseline types to check for wizard completion

    // MARK: - Load All Data

    func loadData() async {
        isLoading = true
        error = nil

        async let configTask: () = loadDisplayConfig()
        async let componentsTask: () = loadComponents()
        async let scoreTask: () = loadScore()
        async let baselinesTask: () = loadBaselines()
        async let baselineScoresTask: () = loadBaselineScores()
        async let prefsTask: () = loadWeightPreference()
        async let dailyTask: () = loadDailyScore()
        async let daysTask: () = loadActualDaysTracked()
        async let editabilityTask: () = checkEditability()

        _ = await (configTask, componentsTask, scoreTask, baselinesTask, baselineScoresTask, prefsTask, dailyTask, daysTask, editabilityTask)

        isLoading = false
    }

    // MARK: - Check Editability

    private func checkEditability() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            struct EditabilityResult: Decodable {
                let is_editable: Bool
                let reason: String
                let phase: String?
                let cycle_number: Int?
            }

            let result: EditabilityResult = try await client.rpc(
                "check_baselines_editable",
                params: ["p_patient_id": AnyJSON.string(userId.uuidString)]
            ).execute().value

            isEditable = result.is_editable
            editabilityReason = result.reason
            cyclePhase = result.phase
        } catch {
            print("Error checking editability: \(error)")
            // Default to editable if check fails (fail open for onboarding)
            isEditable = true
        }
    }

    // MARK: - Load Display Configuration

    private func loadDisplayConfig() async {
        do {
            let client = SupabaseManager.shared.client

            let results: [BehavioralScoreDisplay] = try await client
                .from("display_behavioral_scores")
                .select()
                .eq("score_id", value: scoreId)
                .eq("is_active", value: true)
                .limit(1)
                .execute()
                .value

            displayConfig = results.first
        } catch {
            print("Error loading display config: \(error)")
        }
    }

    // MARK: - Load Components

    private func loadComponents() async {
        do {
            let client = SupabaseManager.shared.client

            // Query scoring_component_weights using score_type (e.g., "hydration_score")
            let results: [BehavioralScoreComponent] = try await client
                .from("scoring_component_weights")
                .select()
                .eq("output_score_type", value: scoreType)
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            components = results
        } catch {
            print("Error loading components: \(error)")
        }
    }

    // MARK: - Load Current Score

    /// Note: The patient_behavioral_scores table was removed. Scores are now
    /// calculated dynamically via the behavioral_scores VIEW. This method is
    /// kept for backwards compatibility but does nothing - scores are loaded
    /// by loadDailyScore() and loadBaselineScores() instead.
    private func loadScore() async {
        // No-op: scores now come from behavioral_scores VIEW via loadDailyScore()
        // The 'score' property is legacy - use dailyScore and baselineScores instead
    }

    // MARK: - Load Baselines

    func refreshBaselines() async {
        await loadBaselines()
    }

    private func loadBaselines() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            struct BaselineData: Decodable {
                let baselineType: String
                let value: Double
                let canonicalValue: Double?
                let isCurrent: Bool
                let assessmentDate: String?

                enum CodingKeys: String, CodingKey {
                    case baselineType = "baseline_type"
                    case value
                    case canonicalValue = "canonical_value"
                    case isCurrent = "is_current"
                    case assessmentDate = "assessment_date"
                }

                // PostgreSQL numeric comes as string in JSON
                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    baselineType = try container.decode(String.self, forKey: .baselineType)
                    isCurrent = (try? container.decode(Bool.self, forKey: .isCurrent)) ?? true
                    assessmentDate = try? container.decode(String.self, forKey: .assessmentDate)

                    // Parse value (handles both string and number)
                    if let doubleValue = try? container.decode(Double.self, forKey: .value) {
                        value = doubleValue
                    } else if let stringValue = try? container.decode(String.self, forKey: .value),
                              let parsed = Double(stringValue) {
                        value = parsed
                    } else {
                        value = 0
                    }

                    // Parse canonical_value (handles both string and number)
                    if let doubleValue = try? container.decode(Double.self, forKey: .canonicalValue) {
                        canonicalValue = doubleValue
                    } else if let stringValue = try? container.decode(String.self, forKey: .canonicalValue),
                              let parsed = Double(stringValue) {
                        canonicalValue = parsed
                    } else {
                        canonicalValue = nil
                    }
                }
            }

            // Load both current and previous baselines (most recent 2 per type)
            let results: [BaselineData] = try await client
                .from("patient_baseline_samples")
                .select("baseline_type, value, canonical_value, is_current, assessment_date")
                .eq("patient_id", value: userId.uuidString)
                .order("assessment_date", ascending: false)
                .execute()
                .value

            // Group by baseline_type, separating current and previous
            var currentBaselines: [String: (value: Double, date: String?)] = [:]
            var prevBaselines: [String: (value: Double, date: String?)] = [:]

            for baseline in results {
                let effectiveValue = baseline.canonicalValue ?? baseline.value

                if baseline.isCurrent {
                    if currentBaselines[baseline.baselineType] == nil {
                        currentBaselines[baseline.baselineType] = (effectiveValue, baseline.assessmentDate)
                    }
                } else {
                    // Store the most recent previous baseline for each type
                    if prevBaselines[baseline.baselineType] == nil {
                        prevBaselines[baseline.baselineType] = (effectiveValue, baseline.assessmentDate)
                    }
                }
            }

            // Populate published properties
            for (type, data) in currentBaselines {
                baselines[type] = data.value
                if baselineAssessmentDate == nil {
                    baselineAssessmentDate = data.date
                }
            }

            for (type, data) in prevBaselines {
                previousBaselines[type] = data.value
                if previousBaselineDate == nil {
                    previousBaselineDate = data.date
                }
            }
        } catch {
            print("Error loading baselines: \(error)")
        }
    }

    // MARK: - Load Baseline Scores from behavioral_scores VIEW

    private func loadBaselineScores() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            struct BaselineScore: Decodable {
                let scoreType: String
                let scoreValue: Double

                enum CodingKeys: String, CodingKey {
                    case scoreType = "score_type"
                    case scoreValue = "score_value"
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    scoreType = try container.decode(String.self, forKey: .scoreType)
                    if let doubleValue = try? container.decode(Double.self, forKey: .scoreValue) {
                        scoreValue = doubleValue
                    } else if let stringValue = try? container.decode(String.self, forKey: .scoreValue),
                              let parsed = Double(stringValue) {
                        scoreValue = parsed
                    } else {
                        scoreValue = 0
                    }
                }
            }

            // Fetch composite score and component scores for this score type
            var typesToFetch = [scoreType]
            typesToFetch.append(contentsOf: dailyScoreComponentTypes)

            let results: [BaselineScore] = try await client
                .from("behavioral_scores")
                .select("score_type, score_value")
                .eq("patient_id", value: userId.uuidString)
                .in("score_type", values: typesToFetch)
                .eq("score_context", value: "baseline")
                .execute()
                .value

            for score in results {
                baselineScores[score.scoreType] = score.scoreValue
            }
        } catch {
            print("Error loading baseline scores: \(error)")
        }
    }

    // MARK: - Load Weight Preference

    private func loadWeightPreference() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            struct PrefData: Decodable {
                let weightUnit: String

                enum CodingKeys: String, CodingKey {
                    case weightUnit = "weight_unit"
                }
            }

            let results: [PrefData] = try await client
                .from("patient_unit_preferences")
                .select("weight_unit")
                .eq("patient_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            if let pref = results.first {
                weightUnit = pref.weightUnit
            }
        } catch {
            print("Error loading weight preference: \(error)")
        }
    }

    // MARK: - Load Actual Days Tracked

    private func loadActualDaysTracked() async {
        guard let quantityType = trackingQuantityType else { return }

        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            // Rolling window default to 30 days
            let windowDays: Int = 30

            // Calculate start date for window
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            guard let windowStart = calendar.date(byAdding: .day, value: -windowDays, to: today) else { return }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let windowStartString = dateFormatter.string(from: windowStart)

            // Get distinct dates with data in the rolling window
            struct DateResult: Decodable {
                let aggregationDate: String

                enum CodingKeys: String, CodingKey {
                    case aggregationDate = "aggregation_date"
                }
            }

            let dateResults: [DateResult] = try await client
                .from("patient_quantity_samples")
                .select("aggregation_date")
                .eq("patient_id", value: userId.uuidString)
                .eq("quantity_type", value: quantityType)
                .in("source", values: ["wellpath_input", "healthkit"])
                .gte("aggregation_date", value: windowStartString)
                .execute()
                .value

            // Count unique dates
            let uniqueDates = Set(dateResults.map { $0.aggregationDate })
            actualDaysTracked = uniqueDates.count

        } catch {
            print("Error loading actual days tracked: \(error)")
        }
    }

    // MARK: - Load Daily Score

    private func loadDailyScore() async {
        guard let scoreType = dailyScoreQuantityType else { return }

        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            // Get today's date in user's timezone
            let today = Calendar.current.startOfDay(for: Date())
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let todayString = dateFormatter.string(from: today)

            struct DailyScore: Decodable {
                let scoreType: String
                let scoreValue: Double

                enum CodingKeys: String, CodingKey {
                    case scoreType = "score_type"
                    case scoreValue = "score_value"
                }

                // PostgreSQL numeric comes as string in JSON
                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    scoreType = try container.decode(String.self, forKey: .scoreType)
                    if let doubleValue = try? container.decode(Double.self, forKey: .scoreValue) {
                        scoreValue = doubleValue
                    } else if let stringValue = try? container.decode(String.self, forKey: .scoreValue),
                              let parsed = Double(stringValue) {
                        scoreValue = parsed
                    } else {
                        scoreValue = 0
                    }
                }
            }

            // Fetch all daily score types for today from the unified behavioral_scores VIEW
            var typesToFetch = [scoreType]
            typesToFetch.append(contentsOf: dailyScoreComponentTypes)

            let results: [DailyScore] = try await client
                .from("behavioral_scores")
                .select("score_type, score_value")
                .eq("patient_id", value: userId.uuidString)
                .in("score_type", values: typesToFetch)
                .eq("score_date", value: todayString)
                .eq("score_context", value: "daily")
                .execute()
                .value

            for score in results {
                if score.scoreType == scoreType {
                    dailyScore = score.scoreValue
                } else {
                    dailyScoreComponents[score.scoreType] = score.scoreValue
                }
            }
        } catch {
            print("Error loading daily score: \(error)")
        }
    }

    // MARK: - Unit Conversion Helpers

    /// Whether to display ratio in lb instead of kg
    var usePounds: Bool {
        weightUnit == "lb"
    }

    /// Ratio unit string for display
    var ratioUnitDisplay: String {
        usePounds ? "g/lb" : "g/kg"
    }

    /// Convert ratio from canonical g/kg to display unit
    func convertRatioForDisplay(_ ratioGPerKg: Double) -> Double {
        if usePounds {
            // g/kg to g/lb: divide by 2.205
            return ratioGPerKg / 2.205
        }
        return ratioGPerKg
    }

    /// Baseline ratio converted for display
    var baselineRatioDisplay: Double? {
        guard let ratio = baselines["daily_protein_ratio"] else { return nil }
        return convertRatioForDisplay(ratio)
    }

    // MARK: - Reload Score Only

    func reloadScore() async {
        await loadScore()
    }

    // MARK: - Calculate/Update Score

    /// Note: Behavioral scores now calculate on-the-fly via behavioral_scores VIEW
    /// This method simply reloads the score which will be computed when queried
    func calculateScore() async -> Bool {
        isLoading = true
        error = nil

        // Scores are now calculated on-the-fly via behavioral_scores VIEW
        // Just reload to get the latest computed score
        await loadScore()
        isLoading = false
        return true
    }

    // MARK: - Score Properties

    /// Whether a daily score exists (from behavioral_scores VIEW)
    var hasScore: Bool {
        dailyScore != nil || baselineScores[scoreType] != nil
    }

    /// Whether baseline data exists for this score type (wizard was completed)
    var hasBaselineData: Bool {
        guard !baselineTypes.isEmpty else { return false }
        return baselineTypes.contains { baselines[$0] != nil }
    }

    /// Current score value - uses daily score if available, otherwise baseline
    var scoreValue: Int {
        if let daily = dailyScore {
            return Int(daily)
        }
        if let baseline = baselineScores[scoreType] {
            return Int(baseline)
        }
        return 0
    }

    /// Whether current score is from baseline (no daily tracked data)
    var isBaseline: Bool {
        dailyScore == nil && baselineScores[scoreType] != nil
    }

    /// Whether current score is from tracked data
    var isTracked: Bool {
        dailyScore != nil
    }

    // MARK: - Threshold Properties

    var thresholdProgress: Double {
        let required = daysRequired
        guard required > 0 else { return 0 }
        return Double(daysTracked) / Double(required)
    }

    var daysTracked: Int {
        // Use actual count from database query
        actualDaysTracked
    }

    var daysRequired: Int {
        displayConfig?.thresholdDaysRequired ?? 21
    }

    var daysRemaining: Int {
        max(0, daysRequired - daysTracked)
    }

    var thresholdExplanation: String? {
        displayConfig?.thresholdExplanation
    }

    // MARK: - Component Scores

    var componentScores: [String: Double] {
        dailyScoreComponents
    }

    func componentScoreValue(for component: BehavioralScoreComponent) -> Int? {
        guard let value = componentScores[component.componentType] else { return nil }
        return Int(value)
    }

    // MARK: - Display Properties

    var displayName: String {
        displayConfig?.displayName ?? "Score"
    }

    var scoringExplanation: String? {
        displayConfig?.scoringExplanation
    }

    var iconName: String {
        displayConfig?.iconName ?? "chart.bar.fill"
    }
}

// MARK: - Protein Score ViewModel

class ProteinScoreViewModel: BehavioralScoreViewModel {
    init() {
        super.init(scoreId: "SCORE_PROTEIN", scoreType: "protein_score")
    }

    // Daily score configuration
    override var dailyScoreQuantityType: String? { "protein_score" }
    override var dailyScoreComponentTypes: [String] {
        ["protein_type_score", "protein_ratio_score"]
    }
    override var trackingQuantityType: String? { "protein_grams" }
    override var baselineTypes: [String] {
        ["daily_protein_g", "daily_protein_ratio", "protein_tier1_pct", "protein_tier2_pct", "protein_tier3_pct", "body_mass_kg"]
    }

    // Behavioral component scores
    var typeScore: Int? {
        guard let value = componentScores["protein_type_score"] else { return nil }
        return Int(value)
    }

    var ratioScore: Int? {
        guard let value = componentScores["protein_ratio_score"] else { return nil }
        return Int(value)
    }

    // Daily component scores
    var dailyTypeScore: Int? {
        guard let value = dailyScoreComponents["protein_type_score"] else { return nil }
        return Int(value)
    }

    var dailyRatioScore: Int? {
        guard let value = dailyScoreComponents["protein_ratio_score"] else { return nil }
        return Int(value)
    }

    var dailyScoreValue: Int? {
        guard let value = dailyScore else { return nil }
        return Int(value)
    }

    var hasDailyScore: Bool {
        dailyScore != nil
    }

    // Baseline scores from behavioral_scores VIEW
    var baselineCompositeScore: Int? {
        guard let value = baselineScores["protein_score"] else { return nil }
        return Int(value.rounded())
    }

    var baselineTypeScore: Int? {
        guard let value = baselineScores["protein_type_score"] else { return nil }
        return Int(value.rounded())
    }

    var baselineRatioScore: Int? {
        guard let value = baselineScores["protein_ratio_score"] else { return nil }
        return Int(value.rounded())
    }

    var hasBaselineScores: Bool {
        baselineScores["protein_score"] != nil
    }
}

// MARK: - Fats Score ViewModel

class FatsScoreViewModel: BehavioralScoreViewModel {
    init() {
        super.init(scoreId: "SCORE_FATS", scoreType: "fat_score")
    }

    override var dailyScoreQuantityType: String? { "fat_score" }
    override var dailyScoreComponentTypes: [String] {
        ["fat_type_score", "fat_amount_score"]
    }
    override var trackingQuantityType: String? { "fats_total_grams" }
    override var baselineTypes: [String] {
        ["daily_fat_g", "fats_good_pct", "fats_limit_pct"]
    }

    var dailyScoreValue: Int? {
        guard let value = dailyScore else { return nil }
        return Int(value)
    }

    var hasDailyScore: Bool {
        dailyScore != nil
    }

    // Baseline scores from behavioral_scores VIEW
    var baselineCompositeScore: Int? {
        guard let value = baselineScores["fat_score"] else { return nil }
        return Int(value.rounded())
    }

    var baselineTypeScore: Int? {
        guard let value = baselineScores["fat_type_score"] else { return nil }
        return Int(value.rounded())
    }

    var baselineAmountScore: Int? {
        guard let value = baselineScores["fat_amount_score"] else { return nil }
        return Int(value.rounded())
    }

    var hasBaselineScores: Bool {
        baselineScores["fat_score"] != nil
    }
}

// MARK: - Vegetables Score ViewModel

class VegetablesScoreViewModel: BehavioralScoreViewModel {
    init() {
        super.init(scoreId: "SCORE_VEGETABLES", scoreType: "vegetables_score")
    }

    override var dailyScoreQuantityType: String? { "vegetables_score" }
    override var dailyScoreComponentTypes: [String] { [] }
    override var trackingQuantityType: String? { "vegetables_servings" }
    override var baselineTypes: [String] {
        ["daily_vegetables_servings", "daily_vegetables_variety"]
    }

    var dailyScoreValue: Int? {
        guard let value = dailyScore else { return nil }
        return Int(value)
    }

    var hasDailyScore: Bool {
        dailyScore != nil
    }
}

// MARK: - Fruits Score ViewModel

class FruitsScoreViewModel: BehavioralScoreViewModel {
    init() {
        super.init(scoreId: "SCORE_FRUITS", scoreType: "fruits_score")
    }

    override var dailyScoreQuantityType: String? { "fruits_score" }
    override var dailyScoreComponentTypes: [String] { [] }
    override var trackingQuantityType: String? { "fruits_servings" }
    override var baselineTypes: [String] {
        ["daily_fruits_servings", "daily_fruits_variety"]
    }

    var dailyScoreValue: Int? {
        guard let value = dailyScore else { return nil }
        return Int(value)
    }

    var hasDailyScore: Bool {
        dailyScore != nil
    }
}

// MARK: - Legumes Score ViewModel

class LegumesScoreViewModel: BehavioralScoreViewModel {
    init() {
        super.init(scoreId: "SCORE_LEGUMES", scoreType: "legumes_score")
    }

    override var dailyScoreQuantityType: String? { "legumes_score" }
    override var dailyScoreComponentTypes: [String] { [] }
    override var trackingQuantityType: String? { "legumes_servings" }
    override var baselineTypes: [String] {
        ["daily_legumes_servings", "daily_legumes_variety"]
    }

    var dailyScoreValue: Int? {
        guard let value = dailyScore else { return nil }
        return Int(value)
    }

    var hasDailyScore: Bool {
        dailyScore != nil
    }
}

// MARK: - Whole Grains Score ViewModel

class WholeGrainsScoreViewModel: BehavioralScoreViewModel {
    init() {
        super.init(scoreId: "SCORE_WHOLE_GRAINS", scoreType: "whole_grains_score")
    }

    override var dailyScoreQuantityType: String? { "whole_grains_score" }
    override var dailyScoreComponentTypes: [String] { [] }
    override var trackingQuantityType: String? { "whole_grains_servings" }
    override var baselineTypes: [String] {
        ["daily_whole_grains_servings", "daily_whole_grains_variety"]
    }

    var dailyScoreValue: Int? {
        guard let value = dailyScore else { return nil }
        return Int(value)
    }

    var hasDailyScore: Bool {
        dailyScore != nil
    }
}

// MARK: - Nuts & Seeds Score ViewModel

class NutsSeedsScoreViewModel: BehavioralScoreViewModel {
    init() {
        super.init(scoreId: "SCORE_NUTS_SEEDS", scoreType: "nuts_seeds_score")
    }

    override var dailyScoreQuantityType: String? { "nuts_seeds_score" }
    override var dailyScoreComponentTypes: [String] { [] }
    override var trackingQuantityType: String? { "nuts_seeds_servings" }
    override var baselineTypes: [String] {
        ["daily_nuts_seeds_servings", "daily_nuts_seeds_variety"]
    }

    var dailyScoreValue: Int? {
        guard let value = dailyScore else { return nil }
        return Int(value)
    }

    var hasDailyScore: Bool {
        dailyScore != nil
    }
}

// MARK: - Caffeine Score ViewModel

class CaffeineScoreViewModel: BehavioralScoreViewModel {
    init() {
        super.init(scoreId: "SCORE_CAFFEINE", scoreType: "caffeine_score")
    }

    override var dailyScoreQuantityType: String? { "caffeine_score" }
    override var dailyScoreComponentTypes: [String] {
        ["caffeine_timing_score", "caffeine_type_score", "caffeine_amount_score"]
    }
    override var trackingQuantityType: String? { "caffeine_mg" }
    override var baselineTypes: [String] {
        ["daily_caffeine_mg", "caffeine_cutoff_hour", "caffeine_tier1_pct"]
    }

    var dailyScoreValue: Int? {
        guard let value = dailyScore else { return nil }
        return Int(value)
    }

    var hasDailyScore: Bool {
        dailyScore != nil
    }

    // Baseline scores from behavioral_scores VIEW
    var baselineCompositeScore: Int? {
        guard let value = baselineScores["caffeine_score"] else { return nil }
        return Int(value.rounded())
    }

    var baselineTimingScore: Int? {
        guard let value = baselineScores["caffeine_timing_score"] else { return nil }
        return Int(value.rounded())
    }

    var baselineTypeScore: Int? {
        guard let value = baselineScores["caffeine_type_score"] else { return nil }
        return Int(value.rounded())
    }

    var baselineAmountScore: Int? {
        guard let value = baselineScores["caffeine_amount_score"] else { return nil }
        return Int(value.rounded())
    }

    var hasBaselineScores: Bool {
        baselineScores["caffeine_score"] != nil
    }
}

// MARK: - Hydration Score ViewModel

class HydrationScoreViewModel: BehavioralScoreViewModel {
    init() {
        super.init(scoreId: "SCORE_HYDRATION", scoreType: "hydration_score")
    }

    override var dailyScoreQuantityType: String? { "hydration_score" }
    override var dailyScoreComponentTypes: [String] {
        ["hydration_amount_score", "hydration_timing_score"]
    }
    override var trackingQuantityType: String? { "water_ml" }
    override var baselineTypes: [String] {
        ["baseline_water_amount", "hydration_timing_morning_pct", "hydration_timing_afternoon_pct",
         "hydration_timing_evening_pct", "hydration_timing_night_pct"]
    }

    var dailyScoreValue: Int? {
        guard let value = dailyScore else { return nil }
        return Int(value)
    }

    var hasDailyScore: Bool {
        dailyScore != nil
    }

    // Daily component scores
    var dailyAmountScore: Int? {
        guard let value = dailyScoreComponents["hydration_amount_score"] else { return nil }
        return Int(value)
    }

    var dailyTimingScore: Int? {
        guard let value = dailyScoreComponents["hydration_timing_score"] else { return nil }
        return Int(value)
    }

    // Baseline scores from behavioral_scores VIEW
    var baselineCompositeScore: Int? {
        guard let value = baselineScores["hydration_score"] else { return nil }
        return Int(value.rounded())
    }

    var baselineAmountScore: Int? {
        guard let value = baselineScores["hydration_amount_score"] else { return nil }
        return Int(value.rounded())
    }

    var baselineTimingScore: Int? {
        guard let value = baselineScores["hydration_timing_score"] else { return nil }
        return Int(value.rounded())
    }

    var hasBaselineScores: Bool {
        baselineScores["hydration_score"] != nil
    }
}

// MARK: - Meal Patterns Score ViewModel

class MealPatternsScoreViewModel: BehavioralScoreViewModel {
    init() {
        super.init(scoreId: "SCORE_MEAL_PATTERNS", scoreType: "meal_patterns_score")
    }

    override var dailyScoreQuantityType: String? { "meal_patterns_score" }
    override var dailyScoreComponentTypes: [String] {
        ["whole_food_score", "homemade_score", "plant_based_score"]
    }
    override var trackingQuantityType: String? { "meals_count" }
    override var baselineTypes: [String] {
        ["meals_homemade_pct", "meals_carryout_pct", "meals_restaurant_pct"]
    }

    var dailyScoreValue: Int? {
        guard let value = dailyScore else { return nil }
        return Int(value)
    }

    var hasDailyScore: Bool {
        dailyScore != nil
    }
}

// MARK: - Ultra-Processed Score ViewModel

class UltraProcessedScoreViewModel: BehavioralScoreViewModel {
    init() {
        super.init(scoreId: "SCORE_ULTRA_PROCESSED", scoreType: "ultra_processed_score")
    }

    override var dailyScoreQuantityType: String? { "ultra_processed_score" }
    override var dailyScoreComponentTypes: [String] {
        ["weekly_servings_score"]
    }
    override var trackingQuantityType: String? { "ultra_processed_servings" }
    override var baselineTypes: [String] {
        ["weekly_ultra_processed_servings"]
    }

    var dailyScoreValue: Int? {
        guard let value = dailyScore else { return nil }
        return Int(value)
    }

    var hasDailyScore: Bool {
        dailyScore != nil
    }
}

// MARK: - Steps Score ViewModel

class StepsScoreViewModel: BehavioralScoreViewModel {
    init() {
        super.init(scoreId: "SCORE_STEPS", scoreType: "steps_score")
    }

    override var dailyScoreQuantityType: String? { "steps_score" }
    override var dailyScoreComponentTypes: [String] { [] }
    override var trackingQuantityType: String? { "step_count" }
    override var baselineTypes: [String] {
        ["daily_steps"]
    }

    var dailyScoreValue: Int? {
        guard let value = dailyScore else { return nil }
        return Int(value)
    }

    var hasDailyScore: Bool {
        dailyScore != nil
    }
}

// MARK: - Cardio Score ViewModel

class CardioScoreViewModel: BehavioralScoreViewModel {
    init() {
        super.init(scoreId: "SCORE_CARDIO", scoreType: "cardio_score")
    }

    override var dailyScoreQuantityType: String? { "cardio_score" }
    override var dailyScoreComponentTypes: [String] {
        ["cardio_frequency_score", "cardio_duration_score"]
    }
    override var trackingQuantityType: String? { "cardio_sessions_weekly" }
    override var baselineTypes: [String] {
        ["cardio_sessions_weekly", "cardio_duration_avg"]
    }

    var dailyScoreValue: Int? {
        guard let value = dailyScore else { return nil }
        return Int(value)
    }

    var hasDailyScore: Bool {
        dailyScore != nil
    }

    var frequencyScore: Int? {
        guard let value = componentScores["cardio_frequency_score"] else { return nil }
        return Int(value)
    }

    var durationScore: Int? {
        guard let value = componentScores["cardio_duration_score"] else { return nil }
        return Int(value)
    }
}

// MARK: - Strength Score ViewModel

class StrengthScoreViewModel: BehavioralScoreViewModel {
    init() {
        super.init(scoreId: "SCORE_STRENGTH", scoreType: "strength_score")
    }

    override var dailyScoreQuantityType: String? { "strength_score" }
    override var dailyScoreComponentTypes: [String] {
        ["strength_frequency_score", "strength_duration_score"]
    }
    override var trackingQuantityType: String? { "strength_sessions_weekly" }
    override var baselineTypes: [String] {
        ["strength_sessions_weekly", "strength_duration_avg"]
    }

    var dailyScoreValue: Int? {
        guard let value = dailyScore else { return nil }
        return Int(value)
    }

    var hasDailyScore: Bool {
        dailyScore != nil
    }

    var frequencyScore: Int? {
        guard let value = componentScores["strength_frequency_score"] else { return nil }
        return Int(value)
    }

    var durationScore: Int? {
        guard let value = componentScores["strength_duration_score"] else { return nil }
        return Int(value)
    }
}

// MARK: - HIIT Score ViewModel

class HIITScoreViewModel: BehavioralScoreViewModel {
    init() {
        super.init(scoreId: "SCORE_HIIT", scoreType: "hiit_score")
    }

    override var dailyScoreQuantityType: String? { "hiit_score" }
    override var dailyScoreComponentTypes: [String] {
        ["hiit_frequency_score", "hiit_duration_score"]
    }
    override var trackingQuantityType: String? { "hiit_sessions_weekly" }
    override var baselineTypes: [String] {
        ["hiit_sessions_weekly", "hiit_duration_avg"]
    }

    var dailyScoreValue: Int? {
        guard let value = dailyScore else { return nil }
        return Int(value)
    }

    var hasDailyScore: Bool {
        dailyScore != nil
    }

    var frequencyScore: Int? {
        guard let value = componentScores["hiit_frequency_score"] else { return nil }
        return Int(value)
    }

    var durationScore: Int? {
        guard let value = componentScores["hiit_duration_score"] else { return nil }
        return Int(value)
    }
}

// MARK: - Mobility Score ViewModel

class MobilityScoreViewModel: BehavioralScoreViewModel {
    init() {
        super.init(scoreId: "SCORE_MOBILITY", scoreType: "mobility_score")
    }

    override var dailyScoreQuantityType: String? { "mobility_score" }
    override var dailyScoreComponentTypes: [String] {
        ["mobility_frequency_score", "mobility_duration_score"]
    }
    override var trackingQuantityType: String? { "mobility_sessions_weekly" }
    override var baselineTypes: [String] {
        ["mobility_sessions_weekly", "mobility_duration_avg"]
    }

    var dailyScoreValue: Int? {
        guard let value = dailyScore else { return nil }
        return Int(value)
    }

    var hasDailyScore: Bool {
        dailyScore != nil
    }

    var frequencyScore: Int? {
        guard let value = componentScores["mobility_frequency_score"] else { return nil }
        return Int(value)
    }

    var durationScore: Int? {
        guard let value = componentScores["mobility_duration_score"] else { return nil }
        return Int(value)
    }
}

// MARK: - Daily Activity Score ViewModel

class DailyActivityScoreViewModel: BehavioralScoreViewModel {
    init() {
        super.init(scoreId: "SCORE_DAILY_ACTIVITY", scoreType: "daily_activity_score")
    }

    override var dailyScoreQuantityType: String? { "daily_activity_score" }
    override var dailyScoreComponentTypes: [String] {
        ["move_minutes_score", "stand_time_score", "active_calories_score", "exercise_snacks_score"]
    }
    override var trackingQuantityType: String? { "active_energy_kcal" }
    override var baselineTypes: [String] {
        ["daily_move_minutes_goal", "daily_stand_hours_goal", "daily_active_calories_goal", "daily_exercise_snacks_goal"]
    }

    var dailyScoreValue: Int? {
        guard let value = dailyScore else { return nil }
        return Int(value)
    }

    var hasDailyScore: Bool {
        dailyScore != nil
    }

    var moveMinutesScore: Int? {
        guard let value = componentScores["move_minutes_score"] else { return nil }
        return Int(value)
    }

    var standTimeScore: Int? {
        guard let value = componentScores["stand_time_score"] else { return nil }
        return Int(value)
    }

    var activeCaloriesScore: Int? {
        guard let value = componentScores["active_calories_score"] else { return nil }
        return Int(value)
    }

    var exerciseSnacksScore: Int? {
        guard let value = componentScores["exercise_snacks_score"] else { return nil }
        return Int(value)
    }
}

// MARK: - Sleep Duration Score ViewModel

class SleepDurationScoreViewModel: BehavioralScoreViewModel {
    init() {
        super.init(scoreId: "SCORE_SLEEP_DURATION", scoreType: "sleep_duration_score")
    }

    override var dailyScoreQuantityType: String? { "sleep_duration_score" }
    override var dailyScoreComponentTypes: [String] { [] }
    override var trackingQuantityType: String? { "sleep_duration" }
    override var baselineTypes: [String] {
        ["daily_sleep_hours"]
    }

    var dailyScoreValue: Int? {
        guard let value = dailyScore else { return nil }
        return Int(value)
    }

    var hasDailyScore: Bool {
        dailyScore != nil
    }
}

// MARK: - Sleep Score ViewModel (Unified)

class SleepScoreViewModel: BehavioralScoreViewModel {
    init() {
        super.init(scoreId: "SCORE_SLEEP", scoreType: "sleep_score")
    }

    override var dailyScoreQuantityType: String? { "sleep_score" }
    override var dailyScoreComponentTypes: [String] {
        ["sleep_duration", "sleep_consistency", "sleep_stages"]
    }
    override var trackingQuantityType: String? { "sleep_duration" }
    override var baselineTypes: [String] {
        ["baseline_sleep_hours", "baseline_bedtime", "baseline_wake_time"]
    }

    var dailyScoreValue: Int? {
        guard let value = dailyScore else { return nil }
        return Int(value)
    }

    var hasDailyScore: Bool {
        dailyScore != nil
    }

    // Component scores
    var durationScore: Int? {
        guard let value = componentScores["sleep_duration"] else { return nil }
        return Int(value)
    }

    var consistencyScore: Int? {
        guard let value = componentScores["sleep_consistency"] else { return nil }
        return Int(value)
    }

    var stagesScore: Int? {
        guard let value = componentScores["sleep_stages"] else { return nil }
        return Int(value)
    }

    // Check if user has a sleep tracker
    var hasTracker: Bool {
        baselines["has_sleep_tracker"] == 1.0
    }
}

// MARK: - Sleep Routine ViewModel (Behavioral Assessment)

class SleepRoutineViewModel: BehavioralScoreViewModel {
    init() {
        super.init(scoreId: "SCORE_SLEEP_ROUTINE", scoreType: "sleep_routine_score")
    }

    override var dailyScoreQuantityType: String? { nil } // Assessment-based, no daily tracking
    override var dailyScoreComponentTypes: [String] { [] }
    override var trackingQuantityType: String? { nil }
    override var baselineTypes: [String] {
        ["has_wind_down_routine", "wind_down_minutes", "screen_cutoff_minutes",
         "caffeine_cutoff_hours", "last_meal_hours", "naps_per_week",
         "nap_duration_minutes", "has_relaxation_routine"]
    }

    // Component baselines
    var hasWindDownRoutine: Bool { baselines["has_wind_down_routine"] == 1.0 }
    var windDownMinutes: Double? { baselines["wind_down_minutes"] }
    var screenCutoffMinutes: Double? { baselines["screen_cutoff_minutes"] }
    var caffeineCutoffHours: Double? { baselines["caffeine_cutoff_hours"] }
    var lastMealHours: Double? { baselines["last_meal_hours"] }
    var napsPerWeek: Double? { baselines["naps_per_week"] }
    var napDurationMinutes: Double? { baselines["nap_duration_minutes"] }
    var hasRelaxationRoutine: Bool { baselines["has_relaxation_routine"] == 1.0 }
}

// MARK: - Sleep Environment ViewModel (Behavioral Assessment)

class SleepEnvironmentViewModel: BehavioralScoreViewModel {
    init() {
        super.init(scoreId: "SCORE_SLEEP_ENVIRONMENT", scoreType: "sleep_environment_score")
    }

    override var dailyScoreQuantityType: String? { nil }
    override var dailyScoreComponentTypes: [String] { [] }
    override var trackingQuantityType: String? { nil }
    override var baselineTypes: [String] {
        ["room_darkness", "room_temperature", "room_noise", "mattress_quality",
         "pillow_quality", "has_electronics_in_room", "uses_blackout_curtains",
         "has_sleep_partner", "has_pets_in_bed"]
    }

    // Component baselines
    var roomDarkness: Double? { baselines["room_darkness"] }
    var roomTemperature: Double? { baselines["room_temperature"] }
    var roomNoise: Double? { baselines["room_noise"] }
    var mattressQuality: Double? { baselines["mattress_quality"] }
    var pillowQuality: Double? { baselines["pillow_quality"] }
    var hasElectronics: Bool { baselines["has_electronics_in_room"] == 1.0 }
    var usesBlackoutCurtains: Bool { baselines["uses_blackout_curtains"] == 1.0 }
    var hasSleepPartner: Bool { baselines["has_sleep_partner"] == 1.0 }
}
