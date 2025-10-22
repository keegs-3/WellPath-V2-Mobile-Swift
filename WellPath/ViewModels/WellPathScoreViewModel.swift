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
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    func loadWellPathScore() async {
        isLoading = true
        error = nil

        do {
            // Get current user
            let userId = try await supabase.auth.session.user.id

            // Fetch overall WellPath score from view
            let response: [WellPathScoreOverall] = try await supabase
                .from("patient_wellpath_score_overall")
                .select()
                .eq("user_id", value: userId.uuidString)
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

            // Fetch pillar scores
            let response: [PillarScore] = try await supabase
                .from("patient_wellpath_score_by_pillar")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("pillar_name", ascending: true)
                .execute()
                .value

            pillarScores = response

        } catch {
            print("Error loading pillar scores: \(error)")
        }
    }

    var scorePercentage: Int {
        currentScore?.scorePercentage ?? 0
    }

    var formattedCalculatedDate: String {
        return "Updated today"
    }
}
