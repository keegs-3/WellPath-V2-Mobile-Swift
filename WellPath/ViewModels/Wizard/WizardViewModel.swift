//
//  WizardViewModel.swift
//  WellPath
//
//  Manages wizard state - tracks which categories have baselines set.
//  The wizard is a navigation container; actual baseline UI lives in each category's folder.
//

import Foundation
import Supabase

@MainActor
class WizardViewModel: ObservableObject {
    @Published var categories: [WizardCategory] = []
    @Published var isLoading = true
    @Published var hasCompletedWizard = false

    private let wizardCompletedKey = "wellpath_wizard_completed"

    // MARK: - Initialization

    init() {
        hasCompletedWizard = UserDefaults.standard.bool(forKey: wizardCompletedKey)
    }

    // MARK: - Load Data

    func loadCategories() async {
        isLoading = true

        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            // Load all baseline questions grouped by category
            let questions: [BaselineQuestion] = try await client
                .from("baseline_questions")
                .select()
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            // Load existing baselines for this user
            struct ExistingBaseline: Decodable {
                let baselineType: String
                enum CodingKeys: String, CodingKey {
                    case baselineType = "baseline_type"
                }
            }

            let existingBaselines: [ExistingBaseline] = try await client
                .from("patient_baseline_samples")
                .select("baseline_type")
                .eq("patient_id", value: userId.uuidString)
                .eq("is_current", value: true)
                .execute()
                .value

            let completedBaselineTypes = Set(existingBaselines.map { $0.baselineType })

            // Group questions by category
            var categoryMap: [String: [BaselineQuestion]] = [:]
            for question in questions {
                guard let categoryId = question.categoryId else { continue }
                categoryMap[categoryId, default: []].append(question)
            }

            // Build category list with completion status
            var builtCategories: [WizardCategory] = []

            for (categoryId, categoryQuestions) in categoryMap {
                let config = categoryConfig(for: categoryId)

                // Check if all required baselines for this category are set
                let requiredBaselineTypes = categoryQuestions.compactMap { $0.baselineType }
                let isComplete = !requiredBaselineTypes.isEmpty &&
                    requiredBaselineTypes.allSatisfy { completedBaselineTypes.contains($0) }

                builtCategories.append(WizardCategory(
                    id: categoryId,
                    displayName: config.displayName,
                    pillar: config.pillar,
                    iconName: config.iconName,
                    color: config.color,
                    questions: categoryQuestions,
                    isComplete: isComplete
                ))
            }

            // Sort by pillar, then by name
            categories = builtCategories.sorted { $0.displayName < $1.displayName }

        } catch {
            print("WizardViewModel: Error loading categories - \(error)")
        }

        isLoading = false
    }

    // MARK: - Completion

    func markWizardComplete() {
        hasCompletedWizard = true
        UserDefaults.standard.set(true, forKey: wizardCompletedKey)
    }

    func resetWizard() {
        hasCompletedWizard = false
        UserDefaults.standard.set(false, forKey: wizardCompletedKey)
    }

    var allCategoriesComplete: Bool {
        !categories.isEmpty && categories.allSatisfy { $0.isComplete }
    }

    var completedCount: Int {
        categories.filter { $0.isComplete }.count
    }

    // MARK: - Category Config

    private func categoryConfig(for categoryId: String) -> (displayName: String, pillar: String, iconName: String, color: String) {
        switch categoryId {
        case "CAT_PROTEIN":
            return ("Protein", "Healthful Nutrition", "fish.fill", "green")
        case "CAT_VEGETABLES":
            return ("Vegetables", "Healthful Nutrition", "leaf.fill", "green")
        case "CAT_FRUITS":
            return ("Fruits", "Healthful Nutrition", "apple.logo", "green")
        case "CAT_WHOLE_GRAINS":
            return ("Whole Grains", "Healthful Nutrition", "wheat", "green")
        case "CAT_LEGUMES":
            return ("Legumes", "Healthful Nutrition", "circle.grid.3x3.fill", "green")
        case "CAT_NUTS_SEEDS":
            return ("Nuts & Seeds", "Healthful Nutrition", "leaf.arrow.triangle.circlepath", "green")
        case "CAT_FATS":
            return ("Fats & Oils", "Healthful Nutrition", "drop.fill", "green")
        case "CAT_WATER":
            return ("Water", "Healthful Nutrition", "drop.fill", "blue")
        case "CAT_SLEEP":
            return ("Sleep", "Restorative Sleep", "moon.zzz.fill", "indigo")
        case "CAT_STEPS":
            return ("Steps", "Movement & Exercise", "figure.walk", "orange")
        default:
            return (categoryId, "Unknown", "questionmark.circle", "gray")
        }
    }
}
