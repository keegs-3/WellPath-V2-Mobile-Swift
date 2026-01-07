//
//  BaselineEditViewModel.swift
//  WellPath
//
//  ViewModel for editing baseline values during onboarding or between cycles.
//  Loads questions from baseline_questions, pre-populates with existing values,
//  and saves updates to patient_baseline_samples.
//

import Foundation
import SwiftUI
import Supabase

// MARK: - Models

// Note: Uses BaselineQuestion from WellPath/Models/Wizard/BaselineQuestion.swift

struct BaselineEditQuestionOption: Identifiable, Codable {
    let id: UUID
    let questionId: String
    let optionValue: String
    let optionLabel: String
    let displayOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case questionId = "question_id"
        case optionValue = "option_value"
        case optionLabel = "option_label"
        case displayOrder = "display_order"
    }
}

struct ExistingBaseline: Codable {
    let id: UUID
    let baselineType: String
    let value: Double?           // actual column name in DB
    let canonicalValue: Double?
    let metadata: [String: String]?  // For string values stored as metadata

    enum CodingKeys: String, CodingKey {
        case id
        case baselineType = "baseline_type"
        case value
        case canonicalValue = "canonical_value"
        case metadata
    }

    // Computed for compatibility with existing code
    var numericValue: Double? { value }
    var stringValue: String? { metadata?["string_value"] }
}

/// Current value for a question (for editing)
struct QuestionValue {
    var stringValue: String?
    var numericValue: Double?
    var canonicalValue: Double?
}

// MARK: - ViewModel

@MainActor
class BaselineEditViewModel: ObservableObject {
    // Questions and options
    @Published var questions: [BaselineQuestion] = []
    @Published var questionOptions: [String: [BaselineEditQuestionOption]] = [:]  // questionId -> options

    // Current values (keyed by baseline_type)
    @Published var values: [String: QuestionValue] = [:]
    @Published var existingBaselines: [String: ExistingBaseline] = [:]

    // Unit preferences (for liquid/water questions)
    @Published var liquidUnit: LiquidDisplayUnit = .cup

    // Loading/saving states
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var error: String?
    @Published var saveSuccess = false

    private let supabase = SupabaseManager.shared.client
    let baselineTypes: [String]

    init(baselineTypes: [String]) {
        self.baselineTypes = baselineTypes
    }

    // MARK: - Load Data

    func loadAll() async {
        isLoading = true
        error = nil

        do {
            // Load questions - select all fields needed by BaselineQuestion model
            let questionResults: [BaselineQuestion] = try await supabase
                .from("baseline_questions")
                .select("""
                    id, question_id, category_id, question_text, question_text_template,
                    question_subtext, baseline_type, quantity_type, category_type_reference,
                    unit_label, unit_id, question_type, placeholder, min_value, max_value,
                    step_value, display_order, is_required, is_active, baseline_subpage_id,
                    options_question_id
                """)
                .in("baseline_type", values: baselineTypes)
                .eq("is_active", value: true)
                .order("display_order", ascending: true)
                .execute()
                .value

            questions = questionResults

            // Load options for choice questions
            let choiceQuestionIds = questionResults
                .filter { ["single_choice", "multiple_choice"].contains($0.questionType) }
                .map { $0.questionId }

            if !choiceQuestionIds.isEmpty {
                let optionResults: [BaselineEditQuestionOption] = try await supabase
                    .from("baseline_question_options")
                    .select("id, question_id, option_value, option_label, display_order")
                    .in("question_id", values: choiceQuestionIds)
                    .eq("is_active", value: true)
                    .order("display_order", ascending: true)
                    .execute()
                    .value

                var optionsMap: [String: [BaselineEditQuestionOption]] = [:]
                for option in optionResults {
                    optionsMap[option.questionId, default: []].append(option)
                }
                questionOptions = optionsMap
            }

            // Load existing baseline values
            let userId = try await supabase.auth.session.user.id

            let existingResults: [ExistingBaseline] = try await supabase
                .from("patient_baseline_samples")
                .select("id, baseline_type, value, canonical_value, metadata")
                .eq("patient_id", value: userId.uuidString)
                .in("baseline_type", values: baselineTypes)
                .eq("is_current", value: true)
                .execute()
                .value

            var existingMap: [String: ExistingBaseline] = [:]
            var valuesMap: [String: QuestionValue] = [:]

            for baseline in existingResults {
                existingMap[baseline.baselineType] = baseline
                valuesMap[baseline.baselineType] = QuestionValue(
                    stringValue: baseline.stringValue,
                    numericValue: baseline.numericValue,
                    canonicalValue: baseline.canonicalValue
                )
            }

            existingBaselines = existingMap
            values = valuesMap

            // Load unit preferences (for water/liquid questions)
            await loadUnitPreferences(userId: userId)

        } catch {
            self.error = error.localizedDescription
            print("Error loading baseline data: \(error)")
        }

        isLoading = false
    }

    /// Load user's liquid unit preference from patient_unit_preferences
    private func loadUnitPreferences(userId: UUID) async {
        struct UnitPrefResult: Codable {
            let liquidUnit: String?

            enum CodingKeys: String, CodingKey {
                case liquidUnit = "liquid_unit"
            }
        }

        do {
            let results: [UnitPrefResult] = try await supabase
                .from("patient_unit_preferences")
                .select("liquid_unit")
                .eq("patient_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            if let result = results.first, let unitStr = result.liquidUnit {
                liquidUnit = LiquidDisplayUnit(rawValue: unitStr) ?? LiquidDisplayUnit.fromLegacy(unitStr)
            }
        } catch {
            print("Error loading unit preferences: \(error)")
            // Keep default (cup) on error
        }
    }

    // MARK: - Update Values

    func updateStringValue(_ value: String, for baselineType: String) {
        if values[baselineType] == nil {
            values[baselineType] = QuestionValue()
        }
        values[baselineType]?.stringValue = value
    }

    func updateNumericValue(_ value: Double, for baselineType: String) {
        if values[baselineType] == nil {
            values[baselineType] = QuestionValue()
        }
        values[baselineType]?.numericValue = value
        values[baselineType]?.canonicalValue = value  // For simple cases; override for unit conversion
    }

    func updateCanonicalValue(_ value: Double, for baselineType: String) {
        if values[baselineType] == nil {
            values[baselineType] = QuestionValue()
        }
        values[baselineType]?.canonicalValue = value
    }

    // MARK: - Save

    func saveAll() async -> Bool {
        isSaving = true
        error = nil
        saveSuccess = false

        do {
            let userId = try await supabase.auth.session.user.id

            // Check if we're in onboarding phase (updates in place) vs retrospective (creates history)
            let isOnboarding = await checkIsOnboarding(userId: userId)

            for (baselineType, value) in values {
                // Build metadata - include string value and unit for water
                var metadata: [String: String]? = nil
                if let stringVal = value.stringValue, !stringVal.isEmpty {
                    metadata = ["string_value": stringVal]
                }

                // Calculate values - handle water unit conversion
                var displayValue = value.numericValue
                var canonicalValue = value.canonicalValue

                if isWaterBaseline(baselineType), let numVal = value.numericValue {
                    // Convert display value (cups, mL, etc.) to canonical mL
                    canonicalValue = numVal * liquidUnit.mlPerUnit
                    // Store unit info in metadata
                    if metadata == nil { metadata = [:] }
                    metadata?["display_unit"] = liquidUnit.rawValue
                    metadata?["display_value"] = String(format: "%.1f", numVal)
                }

                if let existing = existingBaselines[baselineType] {
                    if isOnboarding {
                        // ONBOARDING: Update existing baseline in place (no history)
                        struct BaselineInPlaceUpdate: Codable {
                            let value: Double?
                            let canonicalValue: Double?
                            let metadata: [String: String]?

                            enum CodingKeys: String, CodingKey {
                                case value
                                case canonicalValue = "canonical_value"
                                case metadata
                            }
                        }

                        let update = BaselineInPlaceUpdate(
                            value: displayValue ?? canonicalValue,
                            canonicalValue: canonicalValue,
                            metadata: metadata
                        )

                        try await supabase
                            .from("patient_baseline_samples")
                            .update(update)
                            .eq("id", value: existing.id.uuidString)
                            .execute()
                    } else {
                        // RETROSPECTIVE: Mark old as superseded, insert new (creates history)
                        struct BaselineSupersede: Codable {
                            let isCurrent: Bool
                            let supersededAt: String

                            enum CodingKeys: String, CodingKey {
                                case isCurrent = "is_current"
                                case supersededAt = "superseded_at"
                            }
                        }

                        let supersede = BaselineSupersede(
                            isCurrent: false,
                            supersededAt: ISO8601DateFormatter().string(from: Date())
                        )

                        try await supabase
                            .from("patient_baseline_samples")
                            .update(supersede)
                            .eq("id", value: existing.id.uuidString)
                            .execute()

                        // Insert new baseline
                        try await insertBaseline(
                            userId: userId,
                            baselineType: baselineType,
                            value: displayValue ?? canonicalValue,
                            canonicalValue: canonicalValue,
                            metadata: metadata
                        )
                    }
                } else {
                    // No existing baseline - always insert
                    try await insertBaseline(
                        userId: userId,
                        baselineType: baselineType,
                        value: displayValue ?? canonicalValue,
                        canonicalValue: canonicalValue,
                        metadata: metadata
                    )
                }
            }

            saveSuccess = true
            isSaving = false
            return true

        } catch {
            self.error = error.localizedDescription
            print("Error saving baselines: \(error)")
            isSaving = false
            return false
        }
    }

    // MARK: - Helpers

    func question(for baselineType: String) -> BaselineQuestion? {
        questions.first { $0.baselineType == baselineType }
    }

    func options(for question: BaselineQuestion) -> [BaselineEditQuestionOption] {
        questionOptions[question.questionId] ?? []
    }

    func currentValue(for baselineType: String) -> QuestionValue? {
        values[baselineType]
    }

    func hasChanges(for baselineType: String) -> Bool {
        guard let value = values[baselineType] else { return false }
        guard let existing = existingBaselines[baselineType] else { return true }

        if value.stringValue != existing.stringValue { return true }
        if value.numericValue != existing.numericValue { return true }
        if value.canonicalValue != existing.canonicalValue { return true }

        return false
    }

    var hasAnyChanges: Bool {
        for baselineType in baselineTypes {
            if hasChanges(for: baselineType) { return true }
        }
        return false
    }

    // MARK: - Timing Percentage Validation

    /// Whether current questions include timing percentage questions
    var hasTimingQuestions: Bool {
        baselineTypes.contains { $0.contains("timing") && $0.contains("pct") }
    }

    /// Sum of timing percentages
    var timingPercentageSum: Double {
        baselineTypes
            .filter { $0.contains("timing") && $0.contains("pct") }
            .compactMap { values[$0]?.numericValue }
            .reduce(0, +)
    }

    /// Whether timing percentages add to 100%
    var timingPercentagesValid: Bool {
        guard hasTimingQuestions else { return true }
        return abs(timingPercentageSum - 100) < 0.01
    }

    /// Error message for timing validation
    var timingValidationMessage: String? {
        guard hasTimingQuestions, !timingPercentagesValid else { return nil }
        let sum = Int(timingPercentageSum.rounded())
        let diff = 100 - sum
        if diff > 0 {
            return "Percentages must add to 100% (currently \(sum)%, need \(diff)% more)"
        } else {
            return "Percentages must add to 100% (currently \(sum)%, reduce by \(abs(diff))%)"
        }
    }

    /// Whether the form is valid for saving
    var canSave: Bool {
        hasAnyChanges && timingPercentagesValid
    }

    /// Whether this baseline type is for water/hydration amount (needs unit conversion)
    private func isWaterBaseline(_ baselineType: String) -> Bool {
        baselineType == "baseline_water_amount"
    }

    /// Check if patient is in onboarding phase (edits update in place, no history)
    private func checkIsOnboarding(userId: UUID) async -> Bool {
        struct CycleResult: Codable {
            let phase: String

            enum CodingKeys: String, CodingKey {
                case phase
            }
        }

        do {
            let results: [CycleResult] = try await supabase
                .from("patient_cycles")
                .select("phase")
                .eq("patient_id", value: userId.uuidString)
                .order("cycle_number", ascending: false)
                .limit(1)
                .execute()
                .value

            if let cycle = results.first {
                return cycle.phase == "onboarding"
            }
            // No cycle = still in onboarding
            return true
        } catch {
            print("Error checking cycle phase: \(error)")
            // Default to onboarding behavior on error
            return true
        }
    }

    /// Insert a new baseline record
    private func insertBaseline(
        userId: UUID,
        baselineType: String,
        value: Double?,
        canonicalValue: Double?,
        metadata: [String: String]?
    ) async throws {
        struct BaselineInsert: Codable {
            let patientId: String
            let baselineType: String
            let value: Double?
            let canonicalValue: Double?
            let metadata: [String: String]?
            let isCurrent: Bool
            let source: String

            enum CodingKeys: String, CodingKey {
                case patientId = "patient_id"
                case baselineType = "baseline_type"
                case value
                case canonicalValue = "canonical_value"
                case metadata
                case isCurrent = "is_current"
                case source
            }
        }

        let insert = BaselineInsert(
            patientId: userId.uuidString,
            baselineType: baselineType,
            value: value,
            canonicalValue: canonicalValue,
            metadata: metadata,
            isCurrent: true,
            source: "onboarding"
        )

        try await supabase
            .from("patient_baseline_samples")
            .insert(insert)
            .execute()
    }
}
