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

    // MARK: - Load All Data

    func loadData() async {
        isLoading = true
        error = nil

        async let configTask: () = loadDisplayConfig()
        async let componentsTask: () = loadComponents()
        async let scoreTask: () = loadScore()

        _ = await (configTask, componentsTask, scoreTask)

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

            let results: [BehavioralScore] = try await client
                .from("patient_behavioral_scores_current")
                .select()
                .eq("patient_id", value: userId.uuidString)
                .eq("score_type", value: scoreType)
                .limit(1)
                .execute()
                .value

            score = results.first
        } catch {
            self.error = error.localizedDescription
            print("Error loading behavioral score: \(error)")
        }
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
        guard let score = score else { return 0 }
        let required = displayConfig?.thresholdDaysRequired ?? score.daysRequired
        return Double(score.daysTracked) / Double(required)
    }

    var daysTracked: Int {
        score?.daysTracked ?? 0
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

    var typeScore: Int? {
        guard let value = componentScores["protein_type_score"] else { return nil }
        return Int(value)
    }

    var ratioScore: Int? {
        guard let value = componentScores["protein_ratio_score"] else { return nil }
        return Int(value)
    }
}
