//
//  ChironViewModel.swift
//  WellPath
//
//  ViewModel for Chiron Engagement Hub
//  Manages challenges, nudges, and AI-driven patient engagement
//

import Foundation
import Combine

@MainActor
class ChironViewModel: ObservableObject {
    // MARK: - Published Properties

    // Challenges
    @Published var activeChallenges: [PatientChallenge] = []
    @Published var suggestedChallenges: [PatientChallenge] = []
    @Published var challengeHistory: [PatientChallenge] = []

    // Nudges
    @Published var recentNudges: [CoachNudge] = []
    @Published var unreadNudgeCount: Int = 0

    // State
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Computed Properties

    /// Most relevant item for ChironCard preview
    var featuredChallenge: PatientChallenge? {
        activeChallenges.first ?? suggestedChallenges.first
    }

    var latestNudge: CoachNudge? {
        recentNudges.first
    }

    var hasUnread: Bool {
        unreadNudgeCount > 0
    }

    var hasActiveEngagement: Bool {
        !activeChallenges.isEmpty || !suggestedChallenges.isEmpty || !recentNudges.isEmpty
    }

    // MARK: - Private

    private let supabase = SupabaseManager.shared.client

    // MARK: - Load All Data

    func loadAll() async {
        guard let userId = try? await supabase.auth.session.user.id else {
            error = "Not logged in"
            return
        }
        let patientId = userId.uuidString

        isLoading = true
        error = nil

        // Load in parallel
        async let challengesTask: () = loadChallenges(patientId: patientId)
        async let nudgesTask: () = loadNudges(patientId: patientId)

        await challengesTask
        await nudgesTask

        isLoading = false
    }

    // MARK: - Challenges

    private func loadChallenges(patientId: String) async {
        do {
            // Load active challenges
            let active: [PatientChallenge] = try await supabase
                .from("patient_challenges")
                .select("*")
                .eq("patient_id", value: patientId)
                .eq("status", value: "active")
                .order("start_date", ascending: false)
                .execute()
                .value

            self.activeChallenges = active

            // Load suggested challenges
            let suggested: [PatientChallenge] = try await supabase
                .from("patient_challenges")
                .select("*")
                .eq("patient_id", value: patientId)
                .eq("status", value: "suggested")
                .order("created_at", ascending: false)
                .limit(5)
                .execute()
                .value

            self.suggestedChallenges = suggested

            // Load history (completed, failed, skipped)
            let history: [PatientChallenge] = try await supabase
                .from("patient_challenges")
                .select("*")
                .eq("patient_id", value: patientId)
                .in("status", values: ["completed", "failed", "skipped", "abandoned"])
                .order("completed_at", ascending: false)
                .limit(20)
                .execute()
                .value

            self.challengeHistory = history

        } catch {
            print("[Chiron] Error loading challenges: \(error)")
            self.error = error.localizedDescription
        }
    }

    // MARK: - Challenge Actions

    func acceptChallenge(_ challenge: PatientChallenge) async -> Bool {
        guard let userId = try? await supabase.auth.session.user.id else { return false }

        let isoFormatter = ISO8601DateFormatter()
        let now = isoFormatter.string(from: Date())

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())

        // Calculate end date based on duration
        let durationDays = challenge.durationDays ?? 7
        guard let endDate = Calendar.current.date(byAdding: .day, value: durationDays, to: Date()) else {
            return false
        }
        let endDateStr = dateFormatter.string(from: endDate)

        do {
            try await supabase
                .from("patient_challenges")
                .update([
                    "status": "active",
                    "start_date": today,
                    "end_date": endDateStr,
                    "updated_at": now
                ])
                .eq("challenge_id", value: challenge.challengeId)
                .execute()

            // Reload challenges
            await loadChallenges(patientId: userId.uuidString)
            return true

        } catch {
            print("[Chiron] Error accepting challenge: \(error)")
            self.error = error.localizedDescription
            return false
        }
    }

    func skipChallenge(_ challenge: PatientChallenge, reason: ChallengeSkipReason) async -> Bool {
        guard let userId = try? await supabase.auth.session.user.id else { return false }

        let isoFormatter = ISO8601DateFormatter()
        let now = isoFormatter.string(from: Date())

        do {
            try await supabase
                .from("patient_challenges")
                .update([
                    "status": "skipped",
                    "skip_reason": reason.rawValue,
                    "skipped_at": now,
                    "updated_at": now
                ])
                .eq("challenge_id", value: challenge.challengeId)
                .execute()

            // Reload challenges
            await loadChallenges(patientId: userId.uuidString)
            return true

        } catch {
            print("[Chiron] Error skipping challenge: \(error)")
            self.error = error.localizedDescription
            return false
        }
    }

    func completeChallenge(_ challenge: PatientChallenge) async -> Bool {
        guard let userId = try? await supabase.auth.session.user.id else { return false }

        let isoFormatter = ISO8601DateFormatter()
        let now = isoFormatter.string(from: Date())

        do {
            try await supabase
                .from("patient_challenges")
                .update([
                    "status": "completed",
                    "completed_at": now,
                    "updated_at": now
                ])
                .eq("challenge_id", value: challenge.challengeId)
                .execute()

            // Reload challenges
            await loadChallenges(patientId: userId.uuidString)
            return true

        } catch {
            print("[Chiron] Error completing challenge: \(error)")
            self.error = error.localizedDescription
            return false
        }
    }

    func abandonChallenge(_ challenge: PatientChallenge) async -> Bool {
        guard let userId = try? await supabase.auth.session.user.id else { return false }

        let isoFormatter = ISO8601DateFormatter()
        let now = isoFormatter.string(from: Date())

        do {
            try await supabase
                .from("patient_challenges")
                .update([
                    "status": "abandoned",
                    "updated_at": now
                ])
                .eq("challenge_id", value: challenge.challengeId)
                .execute()

            // Reload challenges
            await loadChallenges(patientId: userId.uuidString)
            return true

        } catch {
            print("[Chiron] Error abandoning challenge: \(error)")
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Nudges

    private func loadNudges(patientId: String) async {
        do {
            let nudges: [CoachNudge] = try await supabase
                .from("patient_nudges")
                .select("*")
                .eq("patient_id", value: patientId)
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value

            self.recentNudges = nudges
            self.unreadNudgeCount = nudges.filter { !$0.isRead }.count

        } catch {
            print("[Chiron] Error loading nudges: \(error)")
        }
    }

    func markNudgeAsRead(_ nudge: CoachNudge) async {
        guard !nudge.isRead else { return }
        guard let userId = try? await supabase.auth.session.user.id else { return }

        let isoFormatter = ISO8601DateFormatter()
        let now = isoFormatter.string(from: Date())

        do {
            try await supabase
                .from("patient_nudges")
                .update(["read_at": now])
                .eq("nudge_id", value: nudge.nudgeId)
                .execute()

            // Reload nudges
            await loadNudges(patientId: userId.uuidString)

        } catch {
            print("[Chiron] Error marking nudge read: \(error)")
        }
    }
}
