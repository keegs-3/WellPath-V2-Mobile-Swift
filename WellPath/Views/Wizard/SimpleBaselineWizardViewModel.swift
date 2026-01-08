//
//  SimpleBaselineWizardViewModel.swift
//  WellPath
//
//  Generic ViewModel for simple baseline wizards.
//  Works for categories that just need servings/variety without complex calculations.
//  Used by: Vegetables, Fruits, Whole Grains, Legumes, Nuts & Seeds, Hydration, Ultra-Processed
//

import SwiftUI
import Supabase

@MainActor
class SimpleBaselineWizardViewModel: ObservableObject {
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

    // Checklist options and selections (for multi_select_checklist questions)
    @Published var checklistOptions: [String: [ViewAssessmentResponseOption]] = [:]  // optionsQuestionId -> options
    @Published var checklistSelections: [String: Set<Int>] = [:]  // questionId -> selected displayOrders

    // Summary data
    @Published var savedBaselines: [String: Double] = [:]
    @Published var savedBaselineUnits: [String: String] = [:]  // Stored units for display
    @Published var scoreDisplayConfig: BehavioralScoreDisplay?

    // Wizard completion
    @Published var isComplete = false

    // MARK: - Configuration

    let baselineViewId: String
    let categoryId: String
    let pillarName: String
    let scoreId: String?
    let scoreType: String?

    // MARK: - Initialization

    init(
        baselineViewId: String,
        categoryId: String,
        pillarName: String,
        scoreId: String? = nil,
        scoreType: String? = nil
    ) {
        self.baselineViewId = baselineViewId
        self.categoryId = categoryId
        self.pillarName = pillarName
        self.scoreId = scoreId
        self.scoreType = scoreType
    }

    // MARK: - Computed Properties

    var totalSteps: Int {
        subpages.count
    }

    var currentSubpage: BaselineViewSubpage? {
        subpages.first { $0.displayOrder == currentStep }
    }

    var hasAnsweredAny: Bool {
        !baselineResponses.isEmpty
    }

    var answeredCount: Int {
        baselineResponses.count
    }

    var pillarColor: Color {
        MetricsUIConfig.getPillarColor(for: pillarName)
    }

    /// Check if THIS category has existing baselines (not any baseline)
    var hasExistingBaseline: Bool {
        // Only consider this category's baseline types
        let categoryBaselineTypes = baselineQuestions.compactMap { $0.baselineType }
        guard !categoryBaselineTypes.isEmpty else { return false }

        // Check if all required baselines for this category are set
        return categoryBaselineTypes.allSatisfy { savedBaselines[$0] != nil }
    }

    /// Questions for the current subpage only
    var currentSubpageQuestions: [BaselineQuestion] {
        guard let subpageId = currentSubpage?.subpageId else { return baselineQuestions }
        let filtered = baselineQuestions.filter { $0.baselineSubpageId == subpageId }
        // If no questions match this subpage, fall back to all (for backwards compatibility)
        return filtered.isEmpty ? baselineQuestions : filtered
    }

    /// Check if all required questions are answered
    var allQuestionsAnswered: Bool {
        let requiredQuestions = currentSubpageQuestions.filter { $0.isRequired }
        let allAnswered = requiredQuestions.allSatisfy { question in
            if question.isChecklistQuestion {
                // For checklists, require at least one selection (they can submit zero if not required)
                return true  // Checklists with zero selections still produce a valid score of 0
            }
            return baselineResponses[question.questionId] != nil
        }

        // For timing percentage questions, also require they sum to 100%
        if hasTimingQuestions && !timingPercentagesValid {
            return false
        }

        return allAnswered
    }

    // MARK: - Timing Percentage Validation (for hydration timing)

    /// Whether current questions include timing percentage questions
    var hasTimingQuestions: Bool {
        baselineQuestions.contains { $0.baselineType?.contains("timing") == true }
    }

    /// Sum of timing percentages
    var timingPercentageSum: Double {
        baselineQuestions
            .filter { $0.baselineType?.contains("timing") == true }
            .compactMap { baselineResponses[$0.questionId] }
            .reduce(0, +)
    }

    /// Whether timing percentages add to 100%
    var timingPercentagesValid: Bool {
        // If no timing questions, always valid
        guard hasTimingQuestions else { return true }
        return abs(timingPercentageSum - 100) < 0.01
    }

    /// Calculated hydration timing baseline score (0-100)
    /// Based on deviation from target distribution (same as WaterTimingView)
    var calculatedTimingScore: Double? {
        guard hasTimingQuestions, timingPercentagesValid else { return nil }

        // Get timing percentages from responses
        let morning = baselineQuestions
            .first { $0.baselineType == "hydration_timing_morning_pct" }
            .flatMap { baselineResponses[$0.questionId] } ?? 0
        let afternoon = baselineQuestions
            .first { $0.baselineType == "hydration_timing_afternoon_pct" }
            .flatMap { baselineResponses[$0.questionId] } ?? 0
        let evening = baselineQuestions
            .first { $0.baselineType == "hydration_timing_evening_pct" }
            .flatMap { baselineResponses[$0.questionId] } ?? 0
        let night = baselineQuestions
            .first { $0.baselineType == "hydration_timing_night_pct" }
            .flatMap { baselineResponses[$0.questionId] } ?? 0

        // Target percentages: Morning 40%, Afternoon 40%, Evening 15%, Night 5%
        let totalDeviation = abs(morning - 40) + abs(afternoon - 40) + abs(evening - 15) + abs(night - 5)

        // Perfect distribution = 0 deviation = 100 score
        // Max deviation = ~190 = 0 score
        let maxDeviation: Double = 190.0
        let score = max(0, 100 - (totalDeviation / maxDeviation * 100))

        return score.rounded()
    }

    // MARK: - Lifecycle

    func loadInitialData() async {
        isLoading = true

        async let viewTask: () = loadBaselineView()
        async let questionsTask: () = loadBaselineQuestions()
        async let baselinesTask: () = loadExistingBaselines()
        async let scoreConfigTask: () = loadScoreDisplayConfig()
        async let editabilityTask: () = checkEditability()

        _ = await (viewTask, questionsTask, baselinesTask, scoreConfigTask, editabilityTask)

        // Load checklist options for any multi_select_checklist questions
        await loadChecklistOptions()

        await loadSubpages()

        // Pre-populate form with existing baseline values (for editing)
        prepopulateResponses()

        isLoading = false
    }

    /// Pre-populate form responses from existing baselines
    func prepopulateResponses() {
        for question in baselineQuestions {
            if let baselineType = question.baselineType,
               let value = savedBaselines[baselineType] {
                baselineResponses[question.questionId] = value
            }
        }
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

            // Always show all subpages including questions (for both new and edit)
            // Pre-population of existing values happens in prepopulateResponses()
            subpages = loadedSubpages
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

            // Custom decoder to handle PostgreSQL numeric returning as string
            struct BaselineData: Decodable {
                let baselineType: String
                let value: Double
                let canonicalValue: Double?
                let unit: String?

                enum CodingKeys: String, CodingKey {
                    case baselineType = "baseline_type"
                    case value
                    case canonicalValue = "canonical_value"
                    case unit
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    baselineType = try container.decode(String.self, forKey: .baselineType)

                    // Handle value as either Double or String (PostgreSQL numeric quirk)
                    if let doubleValue = try? container.decode(Double.self, forKey: .value) {
                        value = doubleValue
                    } else if let stringValue = try? container.decode(String.self, forKey: .value),
                              let parsed = Double(stringValue) {
                        value = parsed
                    } else {
                        value = 0
                    }

                    // Handle canonical_value similarly
                    if let doubleValue = try? container.decode(Double.self, forKey: .canonicalValue) {
                        canonicalValue = doubleValue
                    } else if let stringValue = try? container.decode(String.self, forKey: .canonicalValue),
                              let parsed = Double(stringValue) {
                        canonicalValue = parsed
                    } else {
                        canonicalValue = nil
                    }

                    unit = try container.decodeIfPresent(String.self, forKey: .unit)
                }
            }

            let baselines: [BaselineData] = try await client
                .from("patient_baseline_samples")
                .select("baseline_type, value, canonical_value, unit")
                .eq("patient_id", value: userId.uuidString)
                .eq("is_current", value: true)
                .execute()
                .value

            for baseline in baselines {
                // Use canonical_value for hydration (stored in mL), otherwise use value
                if baseline.baselineType.contains("water") || baseline.baselineType.contains("hydration") {
                    savedBaselines[baseline.baselineType] = baseline.canonicalValue ?? baseline.value
                } else {
                    savedBaselines[baseline.baselineType] = baseline.value
                }
                if let unit = baseline.unit {
                    savedBaselineUnits[baseline.baselineType] = unit
                }
            }
        } catch {
            print("Error loading baselines: \(error)")
        }
    }

    private func loadScoreDisplayConfig() async {
        guard let scoreId = scoreId else { return }

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

            scoreDisplayConfig = results.first
        } catch {
            print("Error loading score display config: \(error)")
        }
    }

    /// Load options for multi_select_checklist and single_choice questions
    private func loadChecklistOptions() async {
        // Find all questions with optionsQuestionId (both checklist and single_choice)
        let questionsWithOptions = baselineQuestions.filter { $0.isChecklistQuestion || $0.isSingleChoiceQuestion }
        guard !questionsWithOptions.isEmpty else { return }

        // Get unique option question IDs
        let optionQuestionIds = Set(questionsWithOptions.compactMap { $0.optionsQuestionId })

        do {
            let client = SupabaseManager.shared.client

            let allOptions: [ViewAssessmentResponseOption] = try await client
                .from("view_assessment_response_options")
                .select()
                .in("question_id", values: Array(optionQuestionIds))
                .order("display_order")
                .execute()
                .value

            // Group by question_id
            for option in allOptions {
                checklistOptions[option.questionId, default: []].append(option)
            }
        } catch {
            print("Error loading checklist options: \(error)")
        }
    }

    // MARK: - Checklist Methods

    /// Get options for a checklist question
    func getOptions(for question: BaselineQuestion) -> [ViewAssessmentResponseOption] {
        guard let optionsId = question.optionsQuestionId else { return [] }
        return checklistOptions[optionsId] ?? []
    }

    /// Toggle an option selection for a checklist question
    func toggleOption(_ option: ViewAssessmentResponseOption, for question: BaselineQuestion) {
        var selected = checklistSelections[question.questionId] ?? []
        if selected.contains(option.displayOrder) {
            selected.remove(option.displayOrder)
        } else {
            selected.insert(option.displayOrder)
        }
        checklistSelections[question.questionId] = selected

        // Update the baseline response with the calculated score
        let score = calculateChecklistScore(for: question)
        baselineResponses[question.questionId] = Double(score)
    }

    /// Check if an option is selected
    func isOptionSelected(_ option: ViewAssessmentResponseOption, for question: BaselineQuestion) -> Bool {
        checklistSelections[question.questionId]?.contains(option.displayOrder) ?? false
    }

    /// Calculate total score for a checklist question (sum of selected option weights)
    func calculateChecklistScore(for question: BaselineQuestion) -> Int {
        guard let optionsId = question.optionsQuestionId,
              let options = checklistOptions[optionsId],
              let selectedOrders = checklistSelections[question.questionId] else { return 0 }

        return options
            .filter { selectedOrders.contains($0.displayOrder) }
            .reduce(0) { $0 + $1.optionValue }
    }

    /// Get the maximum possible score for a checklist question
    func getMaxScore(for question: BaselineQuestion) -> Int {
        guard let optionsId = question.optionsQuestionId,
              let options = checklistOptions[optionsId] else { return 0 }
        return options.reduce(0) { $0 + $1.optionValue }
    }

    // MARK: - Single Choice Methods

    /// Select a single option for a single_choice question (replaces any previous selection)
    func selectOption(_ option: ViewAssessmentResponseOption, for question: BaselineQuestion) {
        // Set the value directly - single choice means only one selection
        baselineResponses[question.questionId] = Double(option.optionValue)

        // Also track in checklistSelections for UI state (single item set)
        checklistSelections[question.questionId] = Set([option.displayOrder])
    }

    /// Get the currently selected option value for a single_choice question
    func getSelectedOption(for question: BaselineQuestion) -> Int? {
        guard let value = baselineResponses[question.questionId] else { return nil }
        return Int(value)
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

    /// Get the stored unit for a baseline type
    func getStoredUnit(for baselineType: String) -> String? {
        savedBaselineUnits[baselineType]
    }

    // MARK: - Editability Check

    @Published var isEditable = true
    @Published var editabilityReason: String?

    /// Check if baselines can be edited (pre-recommendations or end-of-cycle)
    func checkEditability() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            struct EditabilityResult: Decodable {
                let is_editable: Bool
                let reason: String
            }

            let result: EditabilityResult = try await client.rpc(
                "check_baselines_editable",
                params: ["p_patient_id": AnyJSON.string(userId.uuidString)]
            ).execute().value

            isEditable = result.is_editable
            editabilityReason = result.reason
        } catch {
            print("Error checking editability: \(error)")
            // Default to editable if check fails (fail open for onboarding)
            isEditable = true
        }
    }

    // MARK: - Save Responses

    /// Save baseline responses using upsert pattern (deactivates old, inserts new).
    /// For hydration, pass the selected liquid unit to enable canonical conversion.
    func saveResponses(liquidUnit: LiquidDisplayUnit? = nil) async -> Bool {
        isSaving = true

        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            // Save each question response using upsert_baseline function
            for question in baselineQuestions {
                guard let baselineType = question.baselineType,
                      let value = baselineResponses[question.questionId] else { continue }

                // Determine unit and canonical values
                let displayUnit: String
                let canonicalValue: Double?
                let canonicalUnit: String?

                // Timing questions use percent, not liquid units
                let isTimingQuestion = baselineType.contains("timing")
                // Hydration amount questions should use user's selected liquid unit
                let isHydrationAmount = (baselineType.contains("water") || baselineType.contains("hydration")) && !isTimingQuestion

                if isTimingQuestion {
                    // Timing percentages - use percent, no canonical conversion
                    displayUnit = "percent"
                    canonicalValue = nil
                    canonicalUnit = nil
                } else if isHydrationAmount {
                    // Water amount - use user's selected liquid unit_id with milliliter canonical
                    if let unit = liquidUnit {
                        displayUnit = unit.rawValue  // Use unit_id (gallon_us) not symbol (gal)
                        canonicalValue = value * unit.mlPerUnit
                        canonicalUnit = "milliliter"  // Use unit_id not symbol
                    } else {
                        // Fallback if no unit passed (shouldn't happen)
                        displayUnit = "milliliter"
                        canonicalValue = value
                        canonicalUnit = "milliliter"
                    }
                } else if let unitId = question.unitId, !unitId.isEmpty {
                    // Use question's configured unit for non-hydration questions
                    displayUnit = unitId
                    canonicalValue = nil
                    canonicalUnit = nil
                } else {
                    displayUnit = unitForBaselineType(baselineType)
                    canonicalValue = nil
                    canonicalUnit = nil
                }

                // Build params for upsert_baseline function
                var params: [String: AnyJSON] = [
                    "p_patient_id": .string(userId.uuidString),
                    "p_baseline_type": .string(baselineType),
                    "p_value": .double(value),
                    "p_unit": .string(displayUnit),
                    "p_source": .string("onboarding")
                ]

                if let cv = canonicalValue {
                    params["p_canonical_value"] = .double(cv)
                }
                if let cu = canonicalUnit {
                    params["p_canonical_unit"] = .string(cu)
                }

                struct UpsertResult: Decodable {
                    let success: Bool
                    let error: String?
                    let is_update: Bool?
                }

                let result: UpsertResult = try await client.rpc(
                    "upsert_baseline",
                    params: params
                ).execute().value

                if !result.success {
                    print("Failed to save baseline \(baselineType): \(result.error ?? "unknown error")")
                    isSaving = false
                    return false
                }

                // Store canonical value for hydration (mL) so score calculations work correctly
                if isHydrationAmount, let cv = canonicalValue {
                    savedBaselines[baselineType] = cv
                } else {
                    savedBaselines[baselineType] = value
                }
            }

            // Save calculated timing baseline score (if timing questions answered)
            if let timingScore = calculatedTimingScore {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let today = dateFormatter.string(from: Date())

                let scoreRecord: [String: AnyJSON] = [
                    "patient_id": .string(userId.uuidString),
                    "baseline_type": .string("hydration_timing_baseline_score"),
                    "value": .double(timingScore),
                    "unit": .string("score"),
                    "source": .string("onboarding_calculated"),
                    "assessment_date": .string(today),
                    "is_current": .bool(true)
                ]

                try await client
                    .from("patient_baseline_samples")
                    .insert(scoreRecord)
                    .execute()

                savedBaselines["hydration_timing_baseline_score"] = timingScore
            }

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
        case let t where t.contains("servings"):
            return "serving"
        case let t where t.contains("variety"):
            return "count"
        case let t where t.contains("pct"):
            return "percent"
        case let t where t.contains("cups") || t.contains("water"):
            return "cup"
        case let t where t.contains("mg"):
            return "mg"
        case let t where t.contains("hour"):
            return "hour"
        case let t where t.contains("count"):
            return "count"
        case let t where t.contains("steps"):
            return "steps"
        case let t where t.contains("minutes"):
            return "minutes"
        case let t where t.contains("sessions"):
            return "sessions"
        case let t where t.contains("duration"):
            return "minutes"
        case let t where t.contains("ratio"):
            return "ratio"
        case let t where t.contains("_g") || t.contains("grams"):
            return "grams"
        default:
            return "count"  // Better default than "unit"
        }
    }

    /// Returns (displayUnit, canonicalValue, canonicalUnit) for a baseline value
    /// For hydration, converts the user's display value to canonical mL
    private func canonicalConversion(
        for baselineType: String,
        value: Double,
        liquidUnit: LiquidDisplayUnit?
    ) -> (displayUnit: String, canonicalValue: Double?, canonicalUnit: String?) {
        // Hydration baselines - convert to mL as canonical
        if baselineType.contains("water") || baselineType.contains("hydration") {
            if let unit = liquidUnit {
                let canonicalValue = value * unit.mlPerUnit  // Convert to mL
                return (unit.shortLabel, canonicalValue, "mL")
            }
            // Fallback: assume cups if no unit specified
            return ("cup", value * 236.588, "mL")
        }

        // Non-hydration baselines - no canonical conversion needed
        let displayUnit = unitForBaselineType(baselineType)
        return (displayUnit, nil, nil)
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
