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

    @Published var score: BehavioralScore?
    @Published var displayConfig: BehavioralScoreDisplay?
    @Published var components: [BehavioralScoreComponent] = []
    @Published var baselines: [String: Double] = [:]
    @Published var weightUnit: String = "kg"  // Default to kg (canonical)
    @Published var dailyScore: Double?  // Today's calculated score
    @Published var dailyScoreComponents: [String: Double] = [:]  // Today's component scores
    @Published var actualDaysTracked: Int = 0  // Real count from database
    @Published var isLoading = false
    @Published var error: String?

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

    // MARK: - Load All Data

    func loadData() async {
        isLoading = true
        error = nil

        async let configTask: () = loadDisplayConfig()
        async let componentsTask: () = loadComponents()
        async let scoreTask: () = loadScore()
        async let baselinesTask: () = loadBaselines()
        async let prefsTask: () = loadWeightPreference()
        async let dailyTask: () = loadDailyScore()
        async let daysTask: () = loadActualDaysTracked()

        _ = await (configTask, componentsTask, scoreTask, baselinesTask, prefsTask, dailyTask, daysTask)

        isLoading = false
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

            let results: [BehavioralScoreComponent] = try await client
                .from("display_behavioral_score_components")
                .select()
                .eq("score_id", value: scoreId)
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

    private func loadScore() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            // Query base table directly (view is slow due to JOIN)
            let results: [BehavioralScore] = try await client
                .from("patient_behavioral_scores")
                .select()
                .eq("patient_id", value: userId.uuidString)
                .eq("score_type", value: scoreType)
                .eq("is_current", value: true)
                .limit(1)
                .execute()
                .value

            score = results.first
        } catch {
            self.error = error.localizedDescription
            print("Error loading behavioral score: \(error)")
        }
    }

    // MARK: - Load Baselines

    private func loadBaselines() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            struct BaselineData: Decodable {
                let baselineType: String
                let value: Double

                enum CodingKeys: String, CodingKey {
                    case baselineType = "baseline_type"
                    case value
                }
            }

            let results: [BaselineData] = try await client
                .from("patient_baseline_samples")
                .select("baseline_type, value")
                .eq("patient_id", value: userId.uuidString)
                .eq("is_current", value: true)
                .execute()
                .value

            for baseline in results {
                baselines[baseline.baselineType] = baseline.value
            }
        } catch {
            print("Error loading baselines: \(error)")
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
        guard let quantityType = dailyScoreQuantityType else { return }

        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            // Get today's date in user's timezone
            let today = Calendar.current.startOfDay(for: Date())
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let todayString = dateFormatter.string(from: today)

            struct DailySample: Decodable {
                let quantityType: String
                let canonicalValue: Double

                enum CodingKeys: String, CodingKey {
                    case quantityType = "quantity_type"
                    case canonicalValue = "canonical_value"
                }
            }

            // Fetch all daily score types for today
            var typesToFetch = [quantityType]
            typesToFetch.append(contentsOf: dailyScoreComponentTypes)

            let results: [DailySample] = try await client
                .from("patient_quantity_samples")
                .select("quantity_type, canonical_value")
                .eq("patient_id", value: userId.uuidString)
                .in("quantity_type", values: typesToFetch)
                .eq("aggregation_date", value: todayString)
                .eq("source", value: "calculated")
                .execute()
                .value

            for sample in results {
                if sample.quantityType == quantityType {
                    dailyScore = sample.canonicalValue
                } else {
                    dailyScoreComponents[sample.quantityType] = sample.canonicalValue
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

    func calculateScore() async -> Bool {
        isLoading = true
        error = nil

        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            let _: AnyJSON = try await client.rpc(
                "update_behavioral_score",
                params: [
                    "p_patient_id": AnyJSON.string(userId.uuidString),
                    "p_score_type": AnyJSON.string(scoreType)
                ]
            ).execute().value

            await loadScore()
            isLoading = false
            return true
        } catch {
            self.error = error.localizedDescription
            print("Error calculating behavioral score: \(error)")
            isLoading = false
            return false
        }
    }

    // MARK: - Score Properties

    var hasScore: Bool {
        score != nil
    }

    var scoreValue: Int {
        Int(score?.scoreValue ?? 0)
    }

    var isBaseline: Bool {
        score?.scoreSource == .baseline
    }

    var isTracked: Bool {
        score?.scoreSource == .tracked
    }

    // MARK: - Threshold Properties

    var thresholdProgress: Double {
        let required = daysRequired
        guard required > 0 else { return 0 }
        return Double(daysTracked) / Double(required)
    }

    var daysTracked: Int {
        // Use actual count from database if available, otherwise fall back to stored value
        if actualDaysTracked > 0 {
            return actualDaysTracked
        }
        return score?.daysTracked ?? 0
    }

    var daysRequired: Int {
        displayConfig?.thresholdDaysRequired ?? score?.daysRequired ?? 21
    }

    var daysRemaining: Int {
        max(0, daysRequired - daysTracked)
    }

    var thresholdExplanation: String? {
        displayConfig?.thresholdExplanation
    }

    // MARK: - Component Scores

    var componentScores: [String: Double] {
        score?.componentScores ?? [:]
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
}
