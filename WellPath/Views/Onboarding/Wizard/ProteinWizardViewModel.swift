//
//  ProteinWizardViewModel.swift
//  WellPath
//
//  ViewModel for the Protein Wizard flow.
//  Loads ONE baseline view, with subpages representing each step.
//  Questions from baseline_questions (linked by category_id = CAT_PROTEIN).
//

import SwiftUI
import Supabase

@MainActor
class ProteinWizardViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var currentStep = 1
    @Published var isLoading = true
    @Published var isSaving = false

    // Database-driven configuration
    @Published var baselineView: BaselineView?
    @Published var subpages: [BaselineViewSubpage] = []

    // Baseline questions and responses
    @Published var baselineQuestions: [BaselineQuestion] = []
    @Published var baselineResponses: [String: Double] = [:]

    // Summary data
    @Published var savedBaselines: [String: Double] = [:]
    @Published var currentDailyAverage: Double?

    // Patient biometrics for ratio calculation
    @Published var patientWeightKg: Double?

    // Wizard completion
    @Published var isComplete = false

    // MARK: - Constants

    let baselineViewId = "BASELINE_VIEW_PROTEIN"
    let categoryId = "CAT_PROTEIN"

    // Tier score weights (for calculating type score from percentages)
    let tierScoreWeights: [String: Double] = [
        "protein_tier1_pct": 100,   // Tier 1 = 100 points
        "protein_tier2_pct": 60,    // Tier 2 = 60 points
        "protein_tier3_pct": 20     // Tier 3 = 20 points
    ]

    // MARK: - Computed Properties

    /// Total steps = number of subpages
    var totalSteps: Int {
        subpages.count
    }

    /// Get current subpage based on currentStep (which maps to display_order)
    var currentSubpage: BaselineViewSubpage? {
        subpages.first { $0.displayOrder == currentStep }
    }

    var hasAnsweredAny: Bool {
        !baselineResponses.isEmpty
    }

    var answeredCount: Int {
        baselineResponses.count
    }

    var primaryBaselineValue: Double? {
        savedBaselines["daily_protein_g"]
    }

    var pillarColor: Color {
        MetricsUIConfig.getPillarColor(for: "Healthful Nutrition")
    }

    /// True if user already has a baseline set (tour-only mode)
    var hasExistingBaseline: Bool {
        savedBaselines["daily_protein_g"] != nil
    }

    // MARK: - Tier Validation

    /// Sum of tier percentages (should equal 100)
    var tierPercentageSum: Double {
        let best = baselineResponses["BQ_PROTEIN_TIER_BEST"] ?? 0
        let good = baselineResponses["BQ_PROTEIN_TIER_GOOD"] ?? 0
        let limit = baselineResponses["BQ_PROTEIN_TIER_LIMIT"] ?? 0
        return best + good + limit
    }

    /// Whether tier percentages add to 100%
    var tierPercentagesValid: Bool {
        abs(tierPercentageSum - 100) < 0.01
    }

    /// Calculated type score from tier percentages (0-100)
    var calculatedTypeScore: Double? {
        guard tierPercentagesValid else { return nil }
        let best = baselineResponses["BQ_PROTEIN_TIER_BEST"] ?? 0
        let good = baselineResponses["BQ_PROTEIN_TIER_GOOD"] ?? 0
        let limit = baselineResponses["BQ_PROTEIN_TIER_LIMIT"] ?? 0

        // Weighted average: (best% * 100 + good% * 60 + limit% * 20) / 100
        return (best * 100 + good * 60 + limit * 20) / 100
    }

    /// Calculated protein ratio (g/kg) from daily protein and weight
    var calculatedRatio: Double? {
        guard let dailyProtein = baselineResponses["BQ_PROTEIN_TOTAL"],
              let weight = patientWeightKg,
              weight > 0 else { return nil }
        return dailyProtein / weight
    }

    /// Whether ratio is in optimal range (1.2-1.6 g/kg)
    var ratioIsOptimal: Bool {
        guard let ratio = calculatedRatio else { return false }
        return ratio >= 1.2 && ratio <= 1.6
    }

    // MARK: - Lifecycle

    func loadInitialData() async {
        isLoading = true

        // Load in parallel where possible
        async let viewTask: () = loadBaselineView()
        async let questionsTask: () = loadBaselineQuestions()
        async let baselinesTask: () = loadExistingBaselines()
        async let currentTask: () = loadCurrentData()
        async let weightTask: () = loadPatientWeight()

        _ = await (viewTask, questionsTask, baselinesTask, currentTask, weightTask)

        // Load subpages after view is loaded
        await loadSubpages()

        // Pre-populate responses from existing baselines
        for question in baselineQuestions {
            if let baselineType = question.baselineType,
               let existingValue = savedBaselines[baselineType] {
                baselineResponses[question.questionId] = existingValue
            }
        }

        isLoading = false
    }

    // MARK: - Data Loading

    private func loadBaselineView() async {
        do {
            let client = SupabaseManager.shared.client

            let views: [BaselineView] = try await client
                .from("display_baseline_views")
                .select()
                .eq("view_id", value: baselineViewId)
                .eq("is_active", value: true)
                .limit(1)
                .execute()
                .value

            baselineView = views.first
        } catch {
            print("Error loading baseline view: \(error)")
        }
    }

    private func loadSubpages() async {
        guard baselineView != nil else { return }

        do {
            let client = SupabaseManager.shared.client

            let loadedSubpages: [BaselineViewSubpage] = try await client
                .from("display_baseline_view_subpages")
                .select()
                .eq("baseline_view_id", value: baselineViewId)
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            // If baseline already exists, skip questions and summary steps (tour-only mode)
            if hasExistingBaseline {
                let tourSubpages = loadedSubpages.filter { subpage in
                    subpage.subpageType != "questions" && subpage.subpageType != "summary_card"
                }
                // Renumber display_order for filtered subpages
                subpages = tourSubpages.enumerated().map { index, subpage in
                    var modified = subpage
                    modified.displayOrder = index + 1
                    return modified
                }
            } else {
                subpages = loadedSubpages
            }
        } catch {
            print("Error loading subpages: \(error)")
        }
    }

    private func loadBaselineQuestions() async {
        do {
            let client = SupabaseManager.shared.client

            let questions: [BaselineQuestion] = try await client
                .from("baseline_questions")
                .select()
                .eq("category_id", value: categoryId)
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            baselineQuestions = questions
        } catch {
            print("Error loading baseline questions: \(error)")
        }
    }

    private func loadExistingBaselines() async {
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

            let baselines: [BaselineData] = try await client
                .from("patient_baseline_samples")
                .select("baseline_type, value")
                .eq("patient_id", value: userId.uuidString)
                .eq("is_current", value: true)
                .execute()
                .value

            for baseline in baselines {
                savedBaselines[baseline.baselineType] = baseline.value
            }
        } catch {
            print("Error loading baselines: \(error)")
        }
    }

    private func loadCurrentData() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) else { return }

            struct AggData: Decodable {
                let value: Double
                let canonicalValue: Double?

                enum CodingKeys: String, CodingKey {
                    case value = "quantity_value"
                    case canonicalValue = "canonical_value"
                }
            }

            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFullDate]

            let results: [AggData] = try await client
                .from("patient_quantity_samples")
                .select("quantity_value, canonical_value")
                .eq("patient_id", value: userId.uuidString)
                .eq("quantity_type", value: "protein_grams")
                .gte("aggregation_date", value: dateFormatter.string(from: weekAgo))
                .execute()
                .value

            if !results.isEmpty {
                let totalProtein = results.reduce(0.0) { $0 + ($1.canonicalValue ?? $1.value) }
                currentDailyAverage = totalProtein / Double(results.count)
            }
        } catch {
            print("Error loading current data: \(error)")
        }
    }

    private func loadPatientWeight() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            // Get weight from patient_quantity_samples (most recent)
            struct WeightData: Decodable {
                let value: Double
                let unit: String?

                enum CodingKeys: String, CodingKey {
                    case value = "quantity_value"
                    case unit = "quantity_unit"
                }
            }

            let results: [WeightData] = try await client
                .from("patient_quantity_samples")
                .select("quantity_value, quantity_unit")
                .eq("patient_id", value: userId.uuidString)
                .eq("quantity_type", value: "bodyweight")
                .order("aggregation_date", ascending: false)
                .limit(1)
                .execute()
                .value

            if let weight = results.first {
                // Convert to kg if needed
                if weight.unit == "lb" || weight.unit == "pound" || weight.unit == "lbs" {
                    patientWeightKg = weight.value * 0.453592
                } else {
                    // Assume kg
                    patientWeightKg = weight.value
                }
            }
        } catch {
            print("Error loading patient weight: \(error)")
        }
    }

    // MARK: - Response Handler

    func setValue(_ value: Double?, for question: BaselineQuestion) {
        if let value = value {
            baselineResponses[question.questionId] = value
        } else {
            baselineResponses.removeValue(forKey: question.questionId)
        }
    }

    func getValue(for question: BaselineQuestion) -> Double? {
        baselineResponses[question.questionId]
    }

    // MARK: - Save Responses

    func saveResponses() async -> Bool {
        isSaving = true

        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFullDate]
            let today = dateFormatter.string(from: Date())

            // Save question responses (INSERT triggers handle_baseline_update to mark old as superseded)
            for question in baselineQuestions {
                guard let baselineType = question.baselineType,
                      let value = baselineResponses[question.questionId] else { continue }

                let unit = unitForBaselineType(baselineType)

                let record: [String: AnyJSON] = [
                    "patient_id": .string(userId.uuidString),
                    "baseline_type": .string(baselineType),
                    "value": .double(value),
                    "unit": .string(unit),
                    "source": .string("onboarding"),
                    "assessment_date": .string(today),
                    "is_current": .bool(true)
                ]

                try await client
                    .from("patient_baseline_samples")
                    .insert(record)
                    .execute()

                savedBaselines[baselineType] = value
            }

            // Save calculated type score (if tier percentages are valid)
            if let typeScore = calculatedTypeScore {
                let typeRecord: [String: AnyJSON] = [
                    "patient_id": .string(userId.uuidString),
                    "baseline_type": .string("protein_type_score"),
                    "value": .double(typeScore),
                    "unit": .string("score"),
                    "source": .string("onboarding_calculated"),
                    "assessment_date": .string(today),
                    "is_current": .bool(true)
                ]

                try await client
                    .from("patient_baseline_samples")
                    .insert(typeRecord)
                    .execute()

                savedBaselines["protein_type_score"] = typeScore
            }

            // Save calculated ratio (if we have weight)
            if let ratio = calculatedRatio {
                let ratioRecord: [String: AnyJSON] = [
                    "patient_id": .string(userId.uuidString),
                    "baseline_type": .string("daily_protein_ratio"),
                    "value": .double(ratio),
                    "unit": .string("grams_per_kg"),
                    "source": .string("onboarding_calculated"),
                    "assessment_date": .string(today),
                    "is_current": .bool(true)
                ]

                try await client
                    .from("patient_baseline_samples")
                    .insert(ratioRecord)
                    .execute()

                savedBaselines["daily_protein_ratio"] = ratio
            }

            // Calculate and store the behavioral score
            let _: AnyJSON = try await client.rpc(
                "update_behavioral_score",
                params: [
                    "p_patient_id": AnyJSON.string(userId.uuidString),
                    "p_score_type": AnyJSON.string("protein_score")
                ]
            ).execute().value

            isSaving = false
            return true

        } catch {
            print("Error saving baselines: \(error)")
            isSaving = false
            return false
        }
    }

    private func unitForBaselineType(_ type: String) -> String {
        switch type {
        case "daily_protein_g":
            return "gram"
        case let t where t.contains("pct"):
            return "percent"
        case let t where t.contains("servings"):
            return "serving"
        default:
            return "unit"
        }
    }

    // MARK: - Navigation

    func nextStep() {
        if currentStep < totalSteps {
            withAnimation {
                currentStep += 1
            }
        }
    }

    func previousStep() {
        if currentStep > 1 {
            withAnimation {
                currentStep -= 1
            }
        }
    }

    func completeWizard() {
        UserDefaults.standard.set(true, forKey: "baseline_wizard_\(categoryId)_completed")
        isComplete = true
    }
}
