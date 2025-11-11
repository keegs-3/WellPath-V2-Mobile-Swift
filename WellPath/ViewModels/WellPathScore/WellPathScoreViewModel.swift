//
//  WellPathScoreViewModel.swift
//  WellPath
//
//  Created on 2025-10-22
//

import Foundation
import Supabase

@MainActor
class WellPathScoreViewModel: ObservableObject {
    @Published var currentScore: WellPathScoreOverall?
    @Published var pillarScores: [PillarScore] = []
    @Published var componentScores: [ComponentScoreCurrent] = []
    @Published var scoreAboutSections: [WellPathScoreAbout] = []
    @Published var pillarAboutSections: [String: [PillarAbout]] = [:]  // Keyed by pillarName, array of sections
    @Published var pillarMarkersAbout: [String: [PillarMarkersAbout]] = [:]  // Keyed by pillarName, array of sections
    @Published var pillarBehaviorsAbout: [String: [PillarBehaviorsAbout]] = [:]  // Keyed by pillarName, array of sections
    @Published var pillarEducationAbout: [String: [PillarEducationAbout]] = [:]  // Keyed by pillarName, array of sections
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    func loadWellPathScore() async {
        isLoading = true
        error = nil

        do {
            // Get current user
            let userId = try await supabase.auth.session.user.id

            // Fetch overall WellPath score from current table
            let response: [WellPathScoreOverall] = try await supabase
                .from("patient_wellpath_scores_current")
                .select()
                .eq("patient_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            currentScore = response.first

            if currentScore == nil {
                error = "No WellPath score found. Complete your health assessment to get your score."
            }

        } catch {
            self.error = "Failed to load WellPath score: \(error.localizedDescription)"
            print("Error loading WellPath score: \(error)")
        }

        isLoading = false
    }

    func loadPillarScores() async {
        do {
            // Get current user
            let userId = try await supabase.auth.session.user.id

            // Fetch pillar scores from current table
            let response: [PillarScore] = try await supabase
                .from("patient_pillar_scores_current")
                .select()
                .eq("patient_id", value: userId.uuidString)
                .order("pillar_name", ascending: true)
                .execute()
                .value

            pillarScores = response

        } catch {
            print("Error loading pillar scores: \(error)")
        }
    }

    func loadComponentScores(for pillarName: String) async {
        do {
            // Get current user
            let userId = try await supabase.auth.session.user.id

            // Fetch component scores from current table
            let response: [ComponentScoreCurrent] = try await supabase
                .from("patient_component_scores_current")
                .select()
                .eq("patient_id", value: userId.uuidString)
                .eq("pillar_name", value: pillarName)
                .order("component_type", ascending: true)
                .execute()
                .value

            componentScores = response

        } catch {
            print("Error loading component scores: \(error)")
        }
    }

    var scorePercentage: Int {
        currentScore?.scorePercentageInt ?? 0
    }

    var formattedCalculatedDate: String {
        return "Updated today"
    }

    // MARK: - Component Score Calculation

    func getComponentScores(for pillarName: String) -> PillarComponentScore? {
        guard let pillarScore = pillarScores.first(where: { $0.pillarName == pillarName }) else {
            return nil
        }

        let biomarkersWeight = PillarWeightConfig.weight(for: pillarName, component: "biomarkers")
        let behaviorsWeight = PillarWeightConfig.weight(for: pillarName, component: "behaviors")
        let educationWeight = PillarWeightConfig.weight(for: pillarName, component: "education")

        let totalScore = pillarScore.pillarPercentage
        let biomarkersScore = PillarWeightConfig.calculateComponentScore(pillarScore: totalScore, weight: biomarkersWeight)
        let behaviorsScore = PillarWeightConfig.calculateComponentScore(pillarScore: totalScore, weight: behaviorsWeight)
        let educationScore = PillarWeightConfig.calculateComponentScore(pillarScore: totalScore, weight: educationWeight)

        return PillarComponentScore(
            pillarName: pillarName,
            totalScore: totalScore,
            biomarkersScore: biomarkersScore,
            behaviorsScore: behaviorsScore,
            educationScore: educationScore,
            biomarkersWeight: biomarkersWeight,
            behaviorsWeight: behaviorsWeight,
            educationWeight: educationWeight
        )
    }

    // MARK: - Load About Content

    func loadScoreAboutContent() async {
        do {
            let sections: [WellPathScoreAbout] = try await supabase
                .from("wellpath_score_about")
                .select()
                .eq("is_active", value: true)
                .order("display_order", ascending: true)
                .execute()
                .value

            scoreAboutSections = sections
        } catch {
            print("Error loading score about content: \(error)")
        }
    }

    func loadPillarAboutContent() async {
        do {
            // Load pillar about sections
            let pillars: [PillarAbout] = try await supabase
                .from("wellpath_pillars_about")
                .select()
                .eq("is_active", value: true)
                .order("display_order", ascending: true)
                .execute()
                .value

            // Group sections by pillarName
            pillarAboutSections = Dictionary(grouping: pillars, by: { $0.pillarName })

            // Load markers about sections
            let markers: [PillarMarkersAbout] = try await supabase
                .from("wellpath_pillars_markers_about")
                .select()
                .eq("is_active", value: true)
                .order("display_order", ascending: true)
                .execute()
                .value

            // Group sections by pillarName
            pillarMarkersAbout = Dictionary(grouping: markers, by: { $0.pillarName })

            // Load behaviors about sections
            let behaviors: [PillarBehaviorsAbout] = try await supabase
                .from("wellpath_pillars_behaviors_about")
                .select()
                .eq("is_active", value: true)
                .order("display_order", ascending: true)
                .execute()
                .value

            // Group sections by pillarName
            pillarBehaviorsAbout = Dictionary(grouping: behaviors, by: { $0.pillarName })

            // Load education about sections
            let education: [PillarEducationAbout] = try await supabase
                .from("wellpath_pillars_education_about")
                .select()
                .eq("is_active", value: true)
                .order("display_order", ascending: true)
                .execute()
                .value

            // Group sections by pillarName
            pillarEducationAbout = Dictionary(grouping: education, by: { $0.pillarName })

        } catch {
            print("Error loading pillar about content: \(error)")
        }
    }
}
