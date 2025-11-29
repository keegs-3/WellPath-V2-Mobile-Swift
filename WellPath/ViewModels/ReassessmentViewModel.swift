//
//  ReassessmentViewModel.swift
//  WellPath
//
//  ViewModel for the smart reassessment flow.
//  Manages proposed survey changes from tracked data and category check-ins.
//

import SwiftUI

@MainActor
class ReassessmentViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var proposedChanges: [SurveyProposedChange] = []
    @Published var categoriesWithoutTracking: [SurveyCategory] = []
    @Published var categoryCheckInStatus: [String: CategoryCheckInStatus] = [:]
    @Published var isLoading = false
    @Published var error: String?

    // Track which proposed changes user has accepted/kept
    @Published var acceptedChangeIds: Set<String> = []
    @Published var keptChangeIds: Set<String> = []

    // MARK: - Services

    private let surveyService = SurveyService.shared
    private let supabase = SupabaseManager.shared.client

    // MARK: - Computed Properties

    var proposedChangeCount: Int {
        proposedChanges.count
    }

    var categoriesNeedingReview: [SurveyCategory] {
        categoriesWithoutTracking.filter { category in
            let status = categoryCheckInStatus[category.categoryId]
            return status == nil || status == .needsReview
        }
    }

    var isReassessmentComplete: Bool {
        // All proposed changes have been addressed
        let allChangesAddressed = proposedChanges.allSatisfy { change in
            acceptedChangeIds.contains(change.id) || keptChangeIds.contains(change.id)
        }

        // All categories without tracking have been addressed
        let allCategoriesAddressed = categoriesWithoutTracking.allSatisfy { category in
            let status = categoryCheckInStatus[category.categoryId]
            return status == .noChanges || status == .reviewed
        }

        return allChangesAddressed && allCategoriesAddressed
    }

    /// Group proposed changes by section
    var proposedChangesBySection: [String: [SurveyProposedChange]] {
        Dictionary(grouping: proposedChanges) { $0.sectionId }
    }

    // MARK: - Load Data

    func loadReassessmentData() async {
        guard let userId = try? await supabase.auth.session.user.id else {
            error = "Not logged in"
            return
        }

        isLoading = true
        error = nil

        do {
            async let proposedTask = surveyService.fetchProposedChanges(patientId: userId)
            async let categoriesTask = surveyService.fetchCategoriesWithoutTracking()

            let (proposed, categories) = try await (proposedTask, categoriesTask)

            proposedChanges = proposed
            categoriesWithoutTracking = categories

            // Initialize category check-in status
            for category in categories {
                if categoryCheckInStatus[category.categoryId] == nil {
                    categoryCheckInStatus[category.categoryId] = .notReviewed
                }
            }

        } catch {
            self.error = error.localizedDescription
            print("ReassessmentViewModel: Error loading data - \(error)")
        }

        isLoading = false
    }

    // MARK: - Accept/Keep Changes

    func acceptChange(_ change: SurveyProposedChange) async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        do {
            let success = try await surveyService.acceptProposedChange(
                patientId: userId,
                questionNumber: change.questionNumber,
                newOptionId: change.proposedOptionId,
                sourceMetricId: change.sourceMetricId ?? "unknown"
            )

            if success {
                acceptedChangeIds.insert(change.id)
                keptChangeIds.remove(change.id)
            }
        } catch {
            print("ReassessmentViewModel: Error accepting change - \(error)")
        }
    }

    func keepCurrentResponse(_ change: SurveyProposedChange) {
        keptChangeIds.insert(change.id)
        acceptedChangeIds.remove(change.id)
    }

    func acceptAllChanges() async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        do {
            let count = try await surveyService.acceptAllProposedChanges(patientId: userId)
            print("ReassessmentViewModel: Accepted \(count) changes")

            // Mark all as accepted
            for change in proposedChanges {
                acceptedChangeIds.insert(change.id)
            }
            keptChangeIds.removeAll()
        } catch {
            print("ReassessmentViewModel: Error accepting all changes - \(error)")
        }
    }

    // MARK: - Category Check-in

    func markCategoryNoChanges(_ categoryId: String) {
        categoryCheckInStatus[categoryId] = .noChanges
    }

    func markCategoryReviewed(_ categoryId: String) {
        categoryCheckInStatus[categoryId] = .reviewed
    }

    func markCategoryNeedsReview(_ categoryId: String) {
        categoryCheckInStatus[categoryId] = .needsReview
    }

    // MARK: - Complete Reassessment

    func completeReassessment() async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw NSError(domain: "ReassessmentViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not logged in"])
        }

        // Update the survey state to start a new active plan
        // This would typically trigger backend logic to generate a new plan
        try await supabase
            .from("patient_survey_state")
            .update([
                "lifecycle_phase": "active_plan",
                "plan_started_at": ISO8601DateFormatter().string(from: Date()),
                "last_reassessment_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("patient_id", value: userId.uuidString)
            .execute()
    }
}

// MARK: - Category Check-in Status

enum CategoryCheckInStatus: String, Codable {
    case notReviewed
    case noChanges
    case needsReview
    case reviewed
}
