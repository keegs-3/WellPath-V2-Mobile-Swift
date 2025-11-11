//
//  ComponentDetailViewModel.swift
//  WellPath
//
//  Fetches individual metrics for a pillar component
//

import Foundation
import Supabase

@MainActor
class ComponentDetailViewModel: ObservableObject {
    @Published var metrics: [ComponentMetric] = []
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    func loadComponentMetrics(pillar: String, componentType: ComponentMetric.ComponentType) async {
        isLoading = true
        error = nil

        do {
            // Get current user
            let userId = try await supabase.auth.session.user.id

            // TODO: This will need to query the appropriate table based on component type
            // For now, create mock data structure
            // In production, you'll query from:
            // - biomarkers/biometrics tables for biomarkers
            // - patient_behaviors or weekly_goals for behaviors
            // - education_engagement for education

            switch componentType {
            case .biomarkers:
                await loadBiomarkerMetrics(userId: userId, pillar: pillar)
            case .behaviors:
                await loadBehaviorMetrics(userId: userId, pillar: pillar)
            case .education:
                await loadEducationMetrics(userId: userId, pillar: pillar)
            }

        } catch {
            self.error = "Failed to load metrics: \(error.localizedDescription)"
            print("Error loading component metrics: \(error)")
        }

        isLoading = false
    }

    private func loadBiomarkerMetrics(userId: UUID, pillar: String) async {
        // TODO: Query from actual scoring tables
        // This is a placeholder structure
        // You'll need to query from your scoring system tables that track:
        // - which biomarkers belong to which pillar
        // - the weight of each biomarker within the pillar
        // - the points earned for each biomarker

        // Example query structure (adjust based on your actual schema):
        // SELECT biomarker_name, points_earned, max_points, weight, current_value
        // FROM patient_biomarker_scores
        // WHERE patient_id = userId AND pillar = pillar
        // ORDER BY weight DESC, biomarker_name ASC

        // For now, return empty until you have the scoring tables set up
        metrics = []
    }

    private func loadBehaviorMetrics(userId: UUID, pillar: String) async {
        // TODO: Query from behavior scoring tables
        // Similar structure to biomarkers but from behavior tracking

        metrics = []
    }

    private func loadEducationMetrics(userId: UUID, pillar: String) async {
        // TODO: Query from education engagement tables
        // Articles read, quizzes completed, etc.

        metrics = []
    }
}
