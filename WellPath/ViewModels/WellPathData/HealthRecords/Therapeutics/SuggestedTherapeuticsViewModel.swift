//
//  SuggestedTherapeuticsViewModel.swift
//  WellPath
//
//  ViewModel for loading suggested therapeutics based on patient scores.
//  Queries patient_suggested_therapeutics view which joins scores with
//  score_therapeutic_links to generate personalized suggestions.
//

import SwiftUI

@MainActor
class SuggestedTherapeuticsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var suggestions: [SuggestedTherapeutic] = []
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Services

    private let supabase = SupabaseManager.shared.client

    // MARK: - Computed Properties

    var suggestionCount: Int {
        suggestions.count
    }

    var hasSuggestions: Bool {
        !suggestions.isEmpty
    }

    /// Group suggestions by therapeutic type
    var suggestionsByType: [TherapeuticType: [SuggestedTherapeutic]] {
        Dictionary(grouping: suggestions) { $0.type }
    }

    /// Top suggestions sorted by relevance (highest first)
    var topSuggestions: [SuggestedTherapeutic] {
        suggestions.sorted { ($0.relevance ?? 0) > ($1.relevance ?? 0) }
    }

    // MARK: - Load Data

    func loadSuggestions() async {
        guard let userId = try? await supabase.auth.session.user.id else {
            error = "Not logged in"
            return
        }

        isLoading = true
        error = nil

        do {
            suggestions = try await supabase
                .from("patient_suggested_therapeutics")
                .select()
                .eq("patient_id", value: userId.uuidString)
                .order("relevance", ascending: false)
                .execute()
                .value

        } catch {
            self.error = error.localizedDescription
            print("SuggestedTherapeuticsViewModel: Error loading suggestions - \(error)")
        }

        isLoading = false
    }

    /// Check if patient already has this therapeutic in their regimen
    func isAlreadyTaking(_ therapeutic: SuggestedTherapeutic) async -> Bool {
        guard let userId = try? await supabase.auth.session.user.id else {
            return false
        }

        do {
            let existing: [PatientTherapeutic] = try await supabase
                .from("patient_therapeutics")
                .select("id")
                .eq("patient_id", value: userId.uuidString)
                .eq("therapeutic_name", value: therapeutic.therapeuticName)
                .eq("is_active", value: true)
                .execute()
                .value

            return !existing.isEmpty
        } catch {
            return false
        }
    }
}
