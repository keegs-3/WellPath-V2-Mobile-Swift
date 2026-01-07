//
//  ChallengesViewModel.swift
//  WellPath
//
//  ViewModel for Challenges - loads all challenge data by status
//

import Foundation

@MainActor
class ChallengesViewModel: ObservableObject {
    @Published var activeChallenges: [PatientChallenge] = []
    @Published var recommendedChallenges: [PatientChallenge] = []
    @Published var completedChallenges: [PatientChallenge] = []
    @Published var skippedChallenges: [PatientChallenge] = []
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    func loadData() async {
        guard let userId = try? await supabase.auth.session.user.id else { return }
        let patientId = userId.uuidString

        isLoading = true

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadActiveChallenges(patientId: patientId) }
            group.addTask { await self.loadRecommendedChallenges(patientId: patientId) }
            group.addTask { await self.loadCompletedChallenges(patientId: patientId) }
            group.addTask { await self.loadSkippedChallenges(patientId: patientId) }
        }

        isLoading = false
    }

    private func loadActiveChallenges(patientId: String) async {
        do {
            let challenges: [PatientChallenge] = try await supabase
                .from("patient_challenges")
                .select("*")
                .eq("patient_id", value: patientId)
                .eq("status", value: "active")
                .order("start_date", ascending: false)
                .execute()
                .value

            self.activeChallenges = challenges
        } catch {
            print("[Challenges] Error loading active: \(error)")
        }
    }

    private func loadRecommendedChallenges(patientId: String) async {
        do {
            let challenges: [PatientChallenge] = try await supabase
                .from("patient_challenges")
                .select("*")
                .eq("patient_id", value: patientId)
                .eq("status", value: "suggested")
                .order("created_at", ascending: false)
                .execute()
                .value

            self.recommendedChallenges = challenges
        } catch {
            print("[Challenges] Error loading recommended: \(error)")
        }
    }

    private func loadCompletedChallenges(patientId: String) async {
        do {
            let challenges: [PatientChallenge] = try await supabase
                .from("patient_challenges")
                .select("*")
                .eq("patient_id", value: patientId)
                .eq("status", value: "completed")
                .order("completed_at", ascending: false)
                .execute()
                .value

            self.completedChallenges = challenges
        } catch {
            print("[Challenges] Error loading completed: \(error)")
        }
    }

    private func loadSkippedChallenges(patientId: String) async {
        do {
            let challenges: [PatientChallenge] = try await supabase
                .from("patient_challenges")
                .select("*")
                .eq("patient_id", value: patientId)
                .eq("status", value: "skipped")
                .order("skipped_at", ascending: false)
                .execute()
                .value

            self.skippedChallenges = challenges
        } catch {
            print("[Challenges] Error loading skipped: \(error)")
        }
    }

    // MARK: - Actions

    func acceptChallenge(_ challenge: PatientChallenge) async {
        do {
            let dateFormatter = ISO8601DateFormatter()
            let now = dateFormatter.string(from: Date())

            // Calculate end date
            let durationDays = challenge.durationDays ?? 7
            let endDate = Calendar.current.date(byAdding: .day, value: durationDays, to: Date()) ?? Date()
            let endDateString = dateFormatter.string(from: endDate)

            try await supabase
                .from("patient_challenges")
                .update([
                    "status": "active",
                    "start_date": now,
                    "end_date": endDateString
                ])
                .eq("challenge_id", value: challenge.challengeId)
                .execute()

            // Refresh data
            await loadData()
        } catch {
            print("[Challenges] Error accepting challenge: \(error)")
            self.error = "Failed to accept challenge"
        }
    }

    func skipChallenge(_ challenge: PatientChallenge, reason: ChallengeSkipReason) async {
        do {
            let dateFormatter = ISO8601DateFormatter()
            let now = dateFormatter.string(from: Date())

            try await supabase
                .from("patient_challenges")
                .update([
                    "status": "skipped",
                    "skip_reason": reason.rawValue,
                    "skipped_at": now
                ])
                .eq("challenge_id", value: challenge.challengeId)
                .execute()

            // Refresh data
            await loadData()
        } catch {
            print("[Challenges] Error skipping challenge: \(error)")
            self.error = "Failed to skip challenge"
        }
    }
}
