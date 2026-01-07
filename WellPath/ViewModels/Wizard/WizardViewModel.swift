//
//  WizardViewModel.swift
//  WellPath
//
//  Manages wizard state - tracks which categories have baselines set.
//  Supports hierarchical view: Pillars → Categories → Questions.
//  The wizard is a navigation container; actual baseline UI lives in each category's folder.
//

import Foundation
import Supabase
import SwiftUI

@MainActor
class WizardViewModel: ObservableObject {
    @Published var categories: [WizardCategory] = []
    @Published var isLoading = true
    @Published var hasCompletedWizard = false

    private let wizardCompletedKey = "wellpath_wizard_completed"

    // MARK: - Pillar Configuration

    private let pillarOrder: [String] = [
        "Healthful Nutrition",
        "Movement + Exercise",
        "Restorative Sleep",
        "Stress Management",
        "Cognitive Health",
        "Connection + Purpose",
        "Core Care"
    ]

    private let pillarConfigs: [String: (description: String, icon: String, colorHex: String)] = [
        "Healthful Nutrition": ("Optimizing what, when, and how you eat", "fork.knife", "8DD8FF"),
        "Movement + Exercise": ("Building and maintaining physical capacity", "figure.run", "EB875D"),
        "Restorative Sleep": ("Achieving consistent, high-quality sleep", "bed.double.fill", "80CBC4"),
        "Stress Management": ("Developing resilience and adaptive capacity", "heart.fill", "ED8D8D"),
        "Cognitive Health": ("Mental sharpness and brain health", "brain.head.profile", "C6B5FF"),
        "Connection + Purpose": ("Relationships and meaningful engagement", "person.2.fill", "ADD399"),
        "Core Care": ("Preventive care and health maintenance", "cross.fill", "F4D284")
    ]

    // MARK: - Initialization

    init() {
        hasCompletedWizard = UserDefaults.standard.bool(forKey: wizardCompletedKey)
    }

    // MARK: - Computed Properties

    /// Categories grouped by pillar with completion stats
    var pillarsWithBaselines: [PillarBaselineData] {
        let grouped = Dictionary(grouping: categories, by: { $0.pillar })

        return pillarOrder.compactMap { pillar in
            guard let pillarCategories = grouped[pillar], !pillarCategories.isEmpty else { return nil }
            let config = pillarConfigs[pillar] ?? ("", "circle.fill", "808080")
            let completedCount = pillarCategories.filter { $0.isComplete }.count

            return PillarBaselineData(
                pillar: pillar,
                description: config.description,
                icon: config.icon,
                color: Color(hex: config.colorHex) ?? .gray,
                categories: pillarCategories.sorted { $0.displayName < $1.displayName },
                totalCategories: pillarCategories.count,
                completedCategories: completedCount
            )
        }
    }

    /// Overall progress (0.0 - 1.0)
    var overallProgress: CGFloat {
        guard !categories.isEmpty else { return 0 }
        return CGFloat(completedCount) / CGFloat(categories.count)
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
            return ("Whole Grains", "Healthful Nutrition", "carrot.fill", "green")
        case "CAT_LEGUMES":
            return ("Legumes", "Healthful Nutrition", "circle.grid.3x3.fill", "green")
        case "CAT_NUTS_SEEDS":
            return ("Nuts & Seeds", "Healthful Nutrition", "leaf.arrow.triangle.circlepath", "green")
        case "CAT_FATS":
            return ("Fats & Oils", "Healthful Nutrition", "drop.fill", "green")
        case "CAT_HYDRATION":
            return ("Hydration", "Healthful Nutrition", "drop.fill", "blue")
        case "CAT_CAFFEINE":
            return ("Caffeine", "Healthful Nutrition", "cup.and.saucer.fill", "green")
        case "CAT_MEAL_PATTERNS":
            return ("Meal Patterns", "Healthful Nutrition", "clock.fill", "green")
        case "CAT_ULTRA_PROCESSED":
            return ("Ultra-Processed", "Healthful Nutrition", "exclamationmark.triangle.fill", "orange")
        case "CAT_SLEEP":
            return ("Sleep", "Restorative Sleep", "moon.zzz.fill", "indigo")
        case "CAT_STEPS":
            return ("Steps", "Movement + Exercise", "figure.walk", "orange")
        case "CAT_CARDIO":
            return ("Cardio", "Movement + Exercise", "figure.run", "orange")
        case "CAT_STRENGTH":
            return ("Strength", "Movement + Exercise", "dumbbell.fill", "orange")
        case "CAT_HIIT":
            return ("HIIT", "Movement + Exercise", "bolt.heart.fill", "orange")
        case "CAT_MOBILITY":
            return ("Mobility", "Movement + Exercise", "figure.flexibility", "orange")
        case "CAT_DAILY_ACTIVITY":
            return ("Daily Activity", "Movement + Exercise", "figure.stand", "orange")
        default:
            return (categoryId, "Unknown", "questionmark.circle", "gray")
        }
    }
}
