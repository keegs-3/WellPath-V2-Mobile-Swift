//
//  MealLogWizardView.swift
//  WellPath
//
//  Multi-page meal logging wizard
//  Flow: Meal+Time → Source → Mode → [Categories → Type Pages] OR [Quick Questions]
//

import SwiftUI
import Supabase

// MARK: - Wizard Page

enum WizardPage: Equatable {
    case mealAndTime
    case source
    case mode
    case categorySelection
    case categoryDetail(NutrientCategory)
    case typeAmountEntry(NutrientCategory, Int)  // Individual entry for each selected type (category, typeIndex)
    case detailedReview  // Review page for detailed logging
    // Quick mode questions
    case quickProteinQuestion
    case quickProteinTypes
    case quickTypeAmountEntry(NutrientCategory, Int)  // Individual entry in quick mode
    case quickPlantBasedQuestion
    case quickWholeFoodsQuestion
    case quickProcessedQuestion
    case quickProcessedTypes
    case quickSummaryReview

    var title: String {
        switch self {
        case .mealAndTime: return "Meal"
        case .source: return "Source"
        case .mode: return "How to Log"
        case .categorySelection: return "Categories"
        case .categoryDetail(let cat): return cat.displayName
        case .typeAmountEntry(let cat, _): return cat.displayName
        case .detailedReview: return "Review"
        case .quickProteinQuestion: return "Protein"
        case .quickProteinTypes: return "Protein Type"
        case .quickTypeAmountEntry(let cat, _): return cat.displayName
        case .quickPlantBasedQuestion: return "Plant-Based"
        case .quickWholeFoodsQuestion: return "Whole Foods"
        case .quickProcessedQuestion: return "Processed Foods"
        case .quickProcessedTypes: return "Processed Type"
        case .quickSummaryReview: return "Review"
        }
    }
}

// MARK: - Logging Mode

enum LoggingMode: String, CaseIterable, Identifiable {
    case detailed = "detailed"
    case quick = "quick"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .detailed: return "Detailed Tracking"
        case .quick: return "Quick Questions"
        }
    }

    var description: String {
        switch self {
        case .detailed: return "Select food categories and specific types with amounts"
        case .quick: return "Answer a few yes/no questions about your meal"
        }
    }

    var icon: String {
        switch self {
        case .detailed: return "list.bullet.rectangle.fill"
        case .quick: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Nutrient Category

enum NutrientCategory: String, CaseIterable, Identifiable {
    case protein = "protein"
    case vegetables = "vegetables"
    case fruits = "fruits"
    case wholeGrains = "whole_grains"
    case legumes = "legumes"
    case nutsSeeds = "nuts_seeds"
    case processedFoods = "ultra_processed"

    var id: String { rawValue }

    // Consistent nutrition color (green/teal)
    static let nutritionColor = Color(red: 0.2, green: 0.7, blue: 0.5)

    var displayName: String {
        switch self {
        case .protein: return "Protein"
        case .vegetables: return "Vegetables"
        case .fruits: return "Fruits"
        case .wholeGrains: return "Whole Grains"
        case .legumes: return "Legumes"
        case .nutsSeeds: return "Nuts & Seeds"
        case .processedFoods: return "Processed"
        }
    }

    // Icons matching MetricsUIConfig
    var icon: String {
        switch self {
        case .protein: return "fish.fill"
        case .vegetables: return "carrot.fill"
        case .fruits: return "apple.logo"
        case .wholeGrains: return "basket.fill"
        case .legumes: return "leaf.fill"
        case .nutsSeeds: return "figure.mind.and.body"
        case .processedFoods: return "takeoutbag.and.cup.and.straw.fill"
        }
    }

    // All use nutrition color now
    var color: Color { Self.nutritionColor }

    var referenceCategory: String {
        switch self {
        case .protein: return "protein_types"
        case .vegetables: return "vegetables_types"
        case .fruits: return "fruits_types"
        case .wholeGrains: return "whole_grains_types"
        case .legumes: return "legumes_types"
        case .nutsSeeds: return "nuts_seeds_types"
        case .processedFoods: return "ultra_processed_types"
        }
    }

    /// Fallback grams per serving for each category (used only when DB value is unavailable)
    /// Primary source: usda_foods.serving_grams via FK join to sample_category_types_reference
    /// These defaults match typical serving sizes and are used as a safety fallback
    var gramsPerServing: Double {
        switch self {
        case .protein: return 25.0      // 1 serving = 25g protein
        case .vegetables: return 80.0   // 1 serving = ~80g or 1 cup
        case .fruits: return 80.0       // 1 serving = ~80g or 1 cup
        case .wholeGrains: return 80.0  // 1 serving = ~80g cooked
        case .legumes: return 80.0      // 1 serving = ~80g cooked or 1/2 cup
        case .nutsSeeds: return 28.0    // 1 serving = ~28g or small handful
        case .processedFoods: return 1.0 // Item-based (1 serving = 1 item)
        }
    }

    /// Whether this category uses gram-based entry (vs item-based)
    var usesGrams: Bool { self != .processedFoods }

    /// Default amount to show in the stepper (in grams for gram-based, count for item-based)
    var defaultAmount: Double {
        switch self {
        case .protein: return 25       // 25g = 1 serving
        case .vegetables: return 80    // 80g = 1 serving
        case .fruits: return 80        // 80g = 1 serving
        case .wholeGrains: return 80   // 80g = 1 serving
        case .legumes: return 80       // 80g = 1 serving
        case .nutsSeeds: return 28     // 28g = 1 serving
        case .processedFoods: return 1 // 1 item
        }
    }

    /// Label shown next to the amount stepper
    var amountLabel: String {
        switch self {
        case .protein: return "g protein"
        case .vegetables: return "g vegetables"
        case .fruits: return "g fruit"
        case .wholeGrains: return "g grains"
        case .legumes: return "g legumes"
        case .nutsSeeds: return "g nuts/seeds"
        case .processedFoods: return "items"
        }
    }

    /// Step value for the stepper (grams for gram-based, 1 for item-based)
    var amountStep: Double { usesGrams ? 10 : 1 }
}

// MARK: - Type Selection State

class TypeSelection: ObservableObject, Identifiable {
    let id = UUID()
    let typeOption: TypeOption
    @Published var isSelected: Bool = false
    @Published var amount: Double

    init(typeOption: TypeOption, defaultAmount: Double) {
        self.typeOption = typeOption
        self.amount = defaultAmount
    }
}

// MARK: - Category State

class CategoryState: ObservableObject, Identifiable {
    let id = UUID()
    let category: NutrientCategory
    @Published var isSelected: Bool = false
    @Published var typeSelections: [TypeSelection] = []

    var selectedTypes: [TypeSelection] {
        typeSelections.filter { $0.isSelected }
    }

    init(category: NutrientCategory) {
        self.category = category
    }

    func loadTypes(from options: [TypeOption]) {
        typeSelections = options.map { TypeSelection(typeOption: $0, defaultAmount: category.defaultAmount) }
    }

    /// Toggle a selection and notify observers (fixes nested ObservableObject issue)
    func toggleSelection(_ selection: TypeSelection) {
        selection.isSelected.toggle()
        objectWillChange.send()
    }
}

// MARK: - Type Option (from database)

/// Nested struct to decode usda_foods join response
/// These fields are on usda_foods WellPath category entries, not on sample_category_types_reference
private struct USDAFoodsJoin: Codable {
    let exampleFoods: String?
    let servingSize: String?
    let servingTip: String?
    let servingGrams: Double?

    enum CodingKeys: String, CodingKey {
        case exampleFoods = "example_foods"
        case servingSize = "serving_size"
        case servingTip = "serving_tip"
        case servingGrams = "serving_grams"
    }
}

/// Response struct for decoding Supabase join query
private struct TypeOptionResponse: Codable {
    let id: UUID
    let referenceKey: String
    let displayName: String
    let displayOrder: Int
    let metadata: TypeMetadata?
    // Nested array from join - contains serving info from usda_foods WellPath entries
    let usdaFoods: [USDAFoodsJoin]?

    enum CodingKeys: String, CodingKey {
        case id
        case referenceKey = "reference_key"
        case displayName = "display_name"
        case displayOrder = "display_order"
        case metadata
        case usdaFoods = "usda_foods"
    }

    /// Convert to simplified TypeOption, extracting serving info from usda_foods join
    func toTypeOption() -> TypeOption {
        let firstFood = usdaFoods?.first
        return TypeOption(
            id: id,
            referenceKey: referenceKey,
            displayName: displayName,
            displayOrder: displayOrder,
            metadata: metadata,
            exampleFoods: firstFood?.exampleFoods,
            servingSize: firstFood?.servingSize,
            servingTip: firstFood?.servingTip,
            servingGrams: firstFood?.servingGrams
        )
    }
}

struct TypeOption: Identifiable {
    let id: UUID
    let referenceKey: String
    let displayName: String
    let displayOrder: Int
    let metadata: TypeMetadata?
    // New dedicated columns for info display
    let exampleFoods: String?
    let servingSize: String?
    let servingTip: String?
    // Serving grams from joined usda_foods table (per-food, from database)
    let servingGrams: Double?
}

struct TypeMetadata: Codable {
    // App descriptions - kept in sample_category_types_reference
    let examples: String?
    let servingInfo: String?
    let servingExamples: String?
    let tier: Int?
    let tierName: String?
    let tierDescription: String?
    let description: String?
    let longevity: String?

    // Ultra-processed specific (for UI hints, not nutrition)
    let exampleItems: String?
    let servingGrams: Double?
    let category: String?
    let novaGroup: String?

    enum CodingKeys: String, CodingKey {
        case examples
        case servingInfo = "serving_info"
        case servingExamples = "serving_examples"
        case tier
        case tierName = "tier_name"
        case tierDescription = "tier_description"
        case description
        case longevity
        case exampleItems = "example_items"
        case servingGrams = "serving_grams"
        case category
        case novaGroup = "nova_group"
    }
}

// MARK: - Category Food Nutrition (from usda_foods via category_reference_id)

struct CategoryFoodNutrition: Identifiable, Codable {
    let id: UUID  // usda_foods.id - use for portion lookup
    let categoryReferenceId: UUID
    let description: String
    let calories: Double?
    let proteinG: Double?
    let fatTotalG: Double?
    let carbsG: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case categoryReferenceId = "category_reference_id"
        case description
        case calories
        case proteinG = "protein_g"
        case fatTotalG = "fat_total_g"
        case carbsG = "carbs_g"
    }
}

// MARK: - Meal Source

struct MealSource: Identifiable, Equatable {
    let id: String
    let displayName: String
    let icon: String

    static let sources: [MealSource] = [
        MealSource(id: "homemade", displayName: "Homemade", icon: "house.fill"),
        MealSource(id: "restaurant", displayName: "Restaurant", icon: "fork.knife"),
        MealSource(id: "takeout_delivery", displayName: "Takeout / Delivery", icon: "bag.fill"),
        MealSource(id: "fast_food", displayName: "Fast Food", icon: "car.fill"),
        MealSource(id: "prepared", displayName: "Prepared", icon: "takeoutbag.and.cup.and.straw.fill")
    ]

    static func == (lhs: MealSource, rhs: MealSource) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Quick Log Wizard View

struct QuickLogWizardView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    // Navigation
    @State private var currentPage: WizardPage = .mealAndTime
    @State private var pageHistory: [WizardPage] = []

    // Page 1: Meal + Time
    @State private var selectedMealType: MealType = .suggestedForTime(Date())
    @State private var selectedDateTime = Date()

    // Page 2: Source
    @State private var selectedSource: MealSource?

    // Page 3: Mode
    @State private var selectedMode: LoggingMode?

    // Detail Log: Category states
    @StateObject private var proteinState = CategoryState(category: .protein)
    @StateObject private var vegetablesState = CategoryState(category: .vegetables)
    @StateObject private var fruitsState = CategoryState(category: .fruits)
    @StateObject private var wholeGrainsState = CategoryState(category: .wholeGrains)
    @StateObject private var legumesState = CategoryState(category: .legumes)
    @StateObject private var nutsSeedsState = CategoryState(category: .nutsSeeds)
    @StateObject private var processedFoodsState = CategoryState(category: .processedFoods)

    // Quick Mode: Yes/No Questions
    @State private var quickHasProtein: Bool? = nil
    @State private var quickIsPlantBased: Bool? = nil
    @State private var quickIsMostlyWholeFoods: Bool? = nil
    @State private var quickHasProcessed: Bool? = nil

    // Quick Mode: Type selections now use proteinState and processedFoodsState (multi-select)

    // Type options from database
    @State private var typeOptions: [NutrientCategory: [TypeOption]] = [:]

    // Nutrition data from usda_foods (keyed by category_reference_id)
    @State private var categoryNutrition: [UUID: CategoryFoodNutrition] = [:]

    // Portions from usda_food_portions (keyed by usda_foods.id)
    @State private var categoryPortions: [UUID: [USDAFoodPortion]] = [:]

    // UI state
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let supabase = SupabaseManager.shared.client

    private var categoryStates: [CategoryState] {
        [proteinState, vegetablesState, fruitsState, wholeGrainsState, legumesState, nutsSeedsState, processedFoodsState]
    }

    private var selectedCategories: [NutrientCategory] {
        categoryStates.filter { $0.isSelected }.map { $0.category }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                progressBar

                // Page content
                ScrollView {
                    pageContent
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 120)
                }

                // Navigation buttons
                navigationButtons
            }
            .background(darkWizardBackground)
            .navigationTitle(currentPage.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .task {
                await loadTypeOptions()
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        let totalSteps = calculateTotalSteps()
        let currentStep = calculateCurrentStep()

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 3)

                Rectangle()
                    .fill(Color.green)
                    .frame(width: geo.size.width * CGFloat(currentStep) / CGFloat(totalSteps), height: 3)
            }
        }
        .frame(height: 3)
    }

    private func calculateTotalSteps() -> Int {
        if selectedMode == .quick {
            // Meal, Source, Mode, Protein Q, (Protein Types), Plant Q, Whole Q, Processed Q, (Processed Types), Review
            var steps = 8  // Base quick steps
            if quickHasProtein == true { steps += 1 }
            if quickHasProcessed == true { steps += 1 }
            return steps
        } else if selectedMode == .detailed {
            return 4 + selectedCategories.count  // Meal, Source, Mode, Categories + each category
        }
        return 3  // Meal, Source, Mode (before selection)
    }

    private func calculateCurrentStep() -> Int {
        switch currentPage {
        case .mealAndTime: return 1
        case .source: return 2
        case .mode: return 3
        case .categorySelection: return 4
        case .categoryDetail(let cat):
            if let idx = selectedCategories.firstIndex(of: cat) {
                return 5 + idx * 2  // Category + its type entries
            }
            return 5
        case .typeAmountEntry(let cat, let typeIndex):
            if let catIdx = selectedCategories.firstIndex(of: cat) {
                return 6 + catIdx * 2 + typeIndex
            }
            return 6
        case .detailedReview: return calculateTotalSteps()
        // Quick mode steps
        case .quickProteinQuestion: return 4
        case .quickProteinTypes: return 5
        case .quickTypeAmountEntry(let cat, let typeIndex):
            if cat == .protein {
                return 6 + typeIndex
            } else {
                // Processed foods type entry
                let baseStep = quickHasProtein == true ? 10 : 8
                return baseStep + typeIndex
            }
        case .quickPlantBasedQuestion: return quickHasProtein == true ? 6 + proteinState.selectedTypes.count : 5
        case .quickWholeFoodsQuestion: return quickHasProtein == true ? 7 : 6
        case .quickProcessedQuestion: return quickHasProtein == true ? 8 : 7
        case .quickProcessedTypes: return quickHasProtein == true ? 9 : 8
        case .quickSummaryReview: return calculateTotalSteps()
        }
    }

    // MARK: - Page Content

    @ViewBuilder
    private var pageContent: some View {
        switch currentPage {
        case .mealAndTime:
            mealAndTimePage
        case .source:
            sourcePage
        case .mode:
            modePage
        case .categorySelection:
            categorySelectionPage
        case .categoryDetail(let category):
            categoryDetailPage(for: category)
        case .typeAmountEntry(let category, let typeIndex):
            typeAmountEntryPage(for: category, typeIndex: typeIndex)
        case .detailedReview:
            detailedReviewPage
        // Quick mode pages
        case .quickProteinQuestion:
            quickYesNoPage(
                question: "Did this meal contain protein?",
                subtitle: "Fish, meat, eggs, dairy, legumes, tofu, etc.",
                icon: "fish.fill",
                answer: $quickHasProtein
            )
        case .quickProteinTypes:
            quickMultiSelectTypePage(category: .protein)
        case .quickTypeAmountEntry(let category, let typeIndex):
            typeAmountEntryPage(for: category, typeIndex: typeIndex)
        case .quickPlantBasedQuestion:
            quickYesNoPage(
                question: "Was this meal mostly plant-based?",
                subtitle: "Majority vegetables, fruits, grains, legumes",
                icon: "leaf.fill",
                answer: $quickIsPlantBased
            )
        case .quickWholeFoodsQuestion:
            quickYesNoPage(
                question: "Was this meal mostly whole foods?",
                subtitle: "Minimally processed, recognizable ingredients",
                icon: "carrot.fill",
                answer: $quickIsMostlyWholeFoods
            )
        case .quickProcessedQuestion:
            quickYesNoPage(
                question: "Did this meal contain ultra-processed foods?",
                subtitle: "Packaged snacks, fast food, sugary drinks",
                icon: "takeoutbag.and.cup.and.straw.fill",
                answer: $quickHasProcessed
            )
        case .quickProcessedTypes:
            quickMultiSelectTypePage(category: .processedFoods)
        case .quickSummaryReview:
            quickSummaryReviewPage
        }
    }

    // MARK: - Page 1: Meal + Time

    private var mealAndTimePage: some View {
        VStack(spacing: 24) {
            // Time selection
            VStack(alignment: .leading, spacing: 12) {
                Text("When did you eat?")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)

                HStack {
                    DatePicker("", selection: $selectedDateTime, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(NutrientCategory.nutritionColor)
                        .colorScheme(.dark)
                    Spacer()
                }
                .padding(16)
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
            }

            // Meal type selection - larger buttons
            VStack(alignment: .leading, spacing: 12) {
                Text("Which meal?")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(MealType.allCases) { meal in
                        Button(action: { selectedMealType = meal }) {
                            VStack(spacing: 10) {
                                Image(systemName: meal.icon)
                                    .font(.title2)
                                    .foregroundColor(selectedMealType == meal ? .white : meal.color)
                                Text(meal.displayName)
                                    .font(.subheadline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(selectedMealType == meal ? meal.color : Color.white.opacity(0.06))
                            .foregroundColor(selectedMealType == meal ? .white : .white.opacity(0.8))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(selectedMealType == meal ? meal.color : Color.white.opacity(0.1), lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Page 2: Source

    private var sourcePage: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader("Where was this meal from?")

            VStack(spacing: 12) {
                ForEach(MealSource.sources) { source in
                    Button(action: { selectedSource = source }) {
                        HStack(spacing: 16) {
                            Image(systemName: source.icon)
                                .font(.title2)
                                .frame(width: 32)
                                .foregroundColor(selectedSource?.id == source.id ? .green : .white.opacity(0.6))

                            Text(source.displayName)
                                .font(.body.weight(.medium))
                                .foregroundColor(.white)

                            Spacer()

                            if selectedSource?.id == source.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(16)
                        .background(selectedSource?.id == source.id ? Color.green.opacity(0.15) : Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedSource?.id == source.id ? Color.green : Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Page 3: Mode Selection

    private var modePage: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader("How would you like to log this meal?")

            VStack(spacing: 16) {
                ForEach(LoggingMode.allCases) { mode in
                    Button(action: { selectedMode = mode }) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: mode.icon)
                                    .font(.title2)
                                    .foregroundColor(selectedMode == mode ? .green : .white.opacity(0.6))

                                Text(mode.title)
                                    .font(.headline)
                                    .foregroundColor(.white)

                                Spacer()

                                if selectedMode == mode {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }

                            Text(mode.description)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .background(selectedMode == mode ? Color.green.opacity(0.15) : Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedMode == mode ? Color.green : Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Category Selection Page (Compact 2-Column Grid)

    private var categorySelectionPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("What did you eat?")

            Text("Tap all that apply")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))

            // 2-column grid for compact view
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(categoryStates) { state in
                    Button(action: { state.isSelected.toggle() }) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(state.isSelected ? state.category.color.opacity(0.3) : Color.white.opacity(0.08))
                                    .frame(width: 50, height: 50)

                                Image(systemName: state.category.icon)
                                    .font(.title2)
                                    .foregroundColor(state.isSelected ? state.category.color : .white.opacity(0.6))
                            }
                            .overlay(
                                state.isSelected ?
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .background(Circle().fill(state.category.color).frame(width: 18, height: 18))
                                        .offset(x: 18, y: -18)
                                    : nil
                            )

                            Text(state.category.displayName)
                                .font(.caption.weight(.medium))
                                .foregroundColor(state.isSelected ? .white : .white.opacity(0.7))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(state.isSelected ? state.category.color.opacity(0.15) : Color.white.opacity(0.03))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(state.isSelected ? state.category.color : Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Category Detail Page (Compact Chips - selection only, amounts on separate pages)

    private func categoryDetailPage(for category: NutrientCategory) -> some View {
        let state = categoryStates.first { $0.category == category }!
        let options = typeOptions[category] ?? []

        // Group by tier if protein
        let groupedOptions: [(tier: Int?, name: String, options: [TypeOption])]
        if category == .protein {
            let tiers = Dictionary(grouping: options.filter { $0.referenceKey != "other" }) { $0.metadata?.tier ?? 99 }
            groupedOptions = tiers.keys.sorted().map { tier in
                let tierName = options.first { $0.metadata?.tier == tier }?.metadata?.tierName ?? "Other"
                return (tier: tier, name: tierName, options: tiers[tier] ?? [])
            }
        } else {
            groupedOptions = [(tier: nil, name: "", options: options.filter { $0.referenceKey != "other" })]
        }

        return VStack(alignment: .leading, spacing: 16) {
            // Category header
            HStack(spacing: 10) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(category.color)
                Text("Select \(category.displayName)")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Text("Select all that apply")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))

            // Compact chip groups
            ForEach(groupedOptions, id: \.name) { group in
                VStack(alignment: .leading, spacing: 8) {
                    // Tier header (for protein only)
                    if let tier = group.tier, category == .protein {
                        tierBadge(tier: tier, name: group.name)
                    }

                    // Chips in a flow layout
                    FlowLayout(spacing: 8) {
                        ForEach(state.typeSelections.filter { sel in group.options.contains { $0.id == sel.typeOption.id } }) { selection in
                            typeChip(selection: selection, category: category)
                        }
                    }
                }
            }

            // Show selected count
            let selectedCount = state.selectedTypes.count
            if selectedCount > 0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(selectedCount) selected")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                    Spacer()
                    Text("Tap Next to set amounts")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.top, 8)
            }
        }
    }

    private func tierBadge(tier: Int, name: String) -> some View {
        let color: Color = {
            switch tier {
            case 1: return .green
            case 2: return .blue
            case 3: return .orange
            default: return .gray
            }
        }()

        return Text(name)
            .font(.caption.weight(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.2))
            .cornerRadius(6)
    }

    private func typeChip(selection: TypeSelection, category: NutrientCategory) -> some View {
        let state = categoryStates.first { $0.category == category }!
        return TypeChipView(selection: selection, onToggle: { state.toggleSelection(selection) })
    }

    private func amountRow(selection: TypeSelection, category: NutrientCategory) -> some View {
        let nutrition = categoryNutrition[selection.typeOption.id]
        let portions = nutrition.flatMap { categoryPortions[$0.id] } ?? []
        return AmountRowView(
            selection: selection,
            category: category,
            nutrition: nutrition,
            portions: portions
        )
    }

    // MARK: - Type Amount Entry Page (FoodEntryView-style for individual type)

    private func typeAmountEntryPage(for category: NutrientCategory, typeIndex: Int) -> some View {
        let state = categoryStates.first { $0.category == category }!
        let selectedTypes = state.selectedTypes

        guard typeIndex < selectedTypes.count else {
            return AnyView(Text("Error: Invalid type index").foregroundColor(.red))
        }

        let selection = selectedTypes[typeIndex]
        let nutrition = categoryNutrition[selection.typeOption.id]
        let portions = nutrition.flatMap { categoryPortions[$0.id] } ?? []
        let totalSelected = selectedTypes.count

        return AnyView(
            TypeAmountEntryView(
                selection: selection,
                category: category,
                nutrition: nutrition,
                portions: portions,
                currentIndex: typeIndex + 1,
                totalCount: totalSelected
            )
        )
    }

    // MARK: - Flow Layout for Chips

    struct FlowLayout: Layout {
        var spacing: CGFloat = 8

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let result = arrangeSubviews(proposal: proposal, subviews: subviews)
            return result.size
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            let result = arrangeSubviews(proposal: proposal, subviews: subviews)
            for (index, position) in result.positions.enumerated() {
                subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
            }
        }

        private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
            let maxWidth = proposal.width ?? .infinity
            var positions: [CGPoint] = []
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            var totalHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
                totalHeight = currentY + lineHeight
            }

            return (CGSize(width: maxWidth, height: totalHeight), positions)
        }
    }

    // MARK: - Quick Mode: Yes/No Question Page

    private func quickYesNoPage(question: String, subtitle: String, icon: String, answer: Binding<Bool?>) -> some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(NutrientCategory.nutritionColor)

            // Question
            VStack(spacing: 8) {
                Text(question)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)

            // Yes/No Buttons
            HStack(spacing: 20) {
                Button(action: { answer.wrappedValue = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.title3.weight(.bold))
                        Text("Yes")
                            .font(.title3.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(answer.wrappedValue == true ? NutrientCategory.nutritionColor : Color.white.opacity(0.08))
                    .foregroundColor(answer.wrappedValue == true ? .white : .white.opacity(0.8))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(answer.wrappedValue == true ? NutrientCategory.nutritionColor : Color.white.opacity(0.1), lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)

                Button(action: { answer.wrappedValue = false }) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.bold))
                        Text("No")
                            .font(.title3.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(answer.wrappedValue == false ? Color.white.opacity(0.2) : Color.white.opacity(0.08))
                    .foregroundColor(answer.wrappedValue == false ? .white : .white.opacity(0.8))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(answer.wrappedValue == false ? Color.white.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    // MARK: - Quick Mode: Multi-Select Type Page (chips only, amounts on separate pages)

    private func quickMultiSelectTypePage(category: NutrientCategory) -> some View {
        let state = category == .protein ? proteinState : processedFoodsState
        let options = typeOptions[category] ?? []

        // Group by tier if protein
        let groupedOptions: [(tier: Int?, name: String, options: [TypeOption])]
        if category == .protein {
            let tiers = Dictionary(grouping: options.filter { $0.referenceKey != "other" }) { $0.metadata?.tier ?? 99 }
            groupedOptions = tiers.keys.sorted().map { tier in
                let tierName = options.first { $0.metadata?.tier == tier }?.metadata?.tierName ?? "Other"
                return (tier: tier, name: tierName, options: tiers[tier] ?? [])
            }
        } else {
            groupedOptions = [(tier: nil, name: "", options: options.filter { $0.referenceKey != "other" })]
        }

        return VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("What type? (select all that apply)")
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)

            // Grouped chips with tier headers
            ForEach(groupedOptions, id: \.name) { group in
                VStack(alignment: .leading, spacing: 8) {
                    // Tier header (for protein only)
                    if let tier = group.tier, category == .protein {
                        tierBadge(tier: tier, name: group.name)
                    }

                    // Chips in a flow layout
                    FlowLayout(spacing: 10) {
                        ForEach(state.typeSelections.filter { sel in group.options.contains { $0.id == sel.typeOption.id } }) { selection in
                            QuickTypeChip(selection: selection, onToggle: { state.toggleSelection(selection) })
                        }
                    }
                }
            }

            // Show selected count
            let selectedCount = state.selectedTypes.count
            if selectedCount > 0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(selectedCount) selected")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                    Spacer()
                    Text("Tap Next to set amounts")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.top, 8)
            }
        }
        .onAppear {
            // Load type selections if not already loaded
            if state.typeSelections.isEmpty {
                state.loadTypes(from: options)
            }
        }
    }

    // MARK: - Detailed Mode: Review Page (MFP-style)

    private var detailedReviewPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review Your Meal")
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)

            // List all selected items by category
            VStack(spacing: 12) {
                ForEach(categoryStates.filter { $0.isSelected }) { state in
                    let selectedItems = state.selectedTypes
                    if !selectedItems.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            // Category header
                            HStack(spacing: 8) {
                                Image(systemName: state.category.icon)
                                    .font(.subheadline)
                                    .foregroundColor(state.category.color)
                                Text(state.category.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            // Items in category
                            ForEach(selectedItems) { selection in
                                HStack {
                                    Text(selection.typeOption.displayName)
                                        .font(.body)
                                        .foregroundColor(.white)

                                    Spacer()

                                    Text(formatDetailedAmount(selection.amount, category: state.category))
                                        .font(.body.weight(.medium))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                    }
                }

                Divider().background(Color.white.opacity(0.2))

                // Meal info summary
                HStack {
                    Image(systemName: selectedMealType.icon)
                        .foregroundColor(selectedMealType.color)
                    Text(selectedMealType.displayName)
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text(selectedDateTime.formatted(date: .abbreviated, time: .shortened))
                        .foregroundColor(.white.opacity(0.5))
                }
                .font(.subheadline)
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)

            // Show macros and doughnut for all selections
            if hasDetailedNutritionData {
                detailedNutritionSection
            }
        }
    }

    // Check if we have nutrition data for detailed review
    private var hasDetailedNutritionData: Bool {
        categoryStates.filter { $0.isSelected }.flatMap { $0.selectedTypes }.contains { selection in
            categoryNutrition[selection.typeOption.id] != nil
        }
    }

    // Calculate total macros for detailed review
    // selection.amount now stores total grams for all categories
    private var detailedTotalCalories: Int {
        var total = 0
        for state in categoryStates where state.isSelected {
            for selection in state.selectedTypes {
                if let nutrition = categoryNutrition[selection.typeOption.id] {
                    // selection.amount is in grams
                    total += Int((nutrition.calories ?? 0) * selection.amount / 100)
                }
            }
        }
        return total
    }

    private var detailedTotalProtein: Double {
        var total = 0.0
        for state in categoryStates where state.isSelected {
            for selection in state.selectedTypes {
                if let nutrition = categoryNutrition[selection.typeOption.id] {
                    total += (nutrition.proteinG ?? 0) * selection.amount / 100
                }
            }
        }
        return total
    }

    private var detailedTotalCarbs: Double {
        var total = 0.0
        for state in categoryStates where state.isSelected {
            for selection in state.selectedTypes {
                if let nutrition = categoryNutrition[selection.typeOption.id] {
                    total += (nutrition.carbsG ?? 0) * selection.amount / 100
                }
            }
        }
        return total
    }

    private var detailedTotalFat: Double {
        var total = 0.0
        for state in categoryStates where state.isSelected {
            for selection in state.selectedTypes {
                if let nutrition = categoryNutrition[selection.typeOption.id] {
                    total += (nutrition.fatTotalG ?? 0) * selection.amount / 100
                }
            }
        }
        return total
    }

    private var detailedNutritionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Estimated Nutrition")
                .font(.subheadline.weight(.medium))
                .foregroundColor(NutrientCategory.nutritionColor)
                .textCase(.uppercase)

            WizardEntryDonutView(
                calories: detailedTotalCalories,
                protein: detailedTotalProtein,
                carbs: detailedTotalCarbs,
                fat: detailedTotalFat
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private func formatDetailedAmount(_ amount: Double, category: NutrientCategory) -> String {
        // selection.amount now always stores grams
        return "\(Int(amount))g"
    }

    // MARK: - Quick Mode: Summary Review

    private var quickSummaryReviewPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Review Your Meal")
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)

            VStack(spacing: 12) {
                summaryRow(label: "Meal", value: selectedMealType.displayName, icon: selectedMealType.icon)
                summaryRow(label: "Time", value: selectedDateTime.formatted(date: .abbreviated, time: .shortened), icon: "clock.fill")
                summaryRow(label: "Source", value: selectedSource?.displayName ?? "—", icon: selectedSource?.icon ?? "questionmark")

                Divider().background(Color.white.opacity(0.2))

                // Protein - show all selected types
                if quickHasProtein == true {
                    let selectedProtein = proteinState.selectedTypes
                    if selectedProtein.isEmpty {
                        summaryRow(label: "Protein", value: "Yes (no types)", icon: "fish.fill")
                    } else {
                        ForEach(selectedProtein) { selection in
                            summaryRow(
                                label: selectedProtein.first?.id == selection.id ? "Protein" : "",
                                value: "\(selection.typeOption.displayName) (\(Int(selection.amount))g)",
                                icon: selectedProtein.first?.id == selection.id ? "fish.fill" : ""
                            )
                        }
                    }
                } else {
                    summaryRow(label: "Protein", value: quickHasProtein == false ? "No protein" : "—", icon: "fish.fill")
                }

                summaryRow(label: "Plant-Based", value: quickIsPlantBased == true ? "Yes" : (quickIsPlantBased == false ? "No" : "—"), icon: "leaf.fill")
                summaryRow(label: "Whole Foods", value: quickIsMostlyWholeFoods == true ? "Mostly" : (quickIsMostlyWholeFoods == false ? "No" : "—"), icon: "carrot.fill")

                // Processed foods - show all selected types
                if quickHasProcessed == true {
                    let selectedProcessed = processedFoodsState.selectedTypes
                    if selectedProcessed.isEmpty {
                        summaryRow(label: "Processed", value: "Yes (no types)", icon: "takeoutbag.and.cup.and.straw.fill")
                    } else {
                        ForEach(selectedProcessed) { selection in
                            summaryRow(
                                label: selectedProcessed.first?.id == selection.id ? "Processed" : "",
                                value: "\(selection.typeOption.displayName) (\(Int(selection.amount))g)",
                                icon: selectedProcessed.first?.id == selection.id ? "takeoutbag.and.cup.and.straw.fill" : ""
                            )
                        }
                    }
                } else {
                    summaryRow(label: "Processed", value: quickHasProcessed == false ? "None" : "—", icon: "takeoutbag.and.cup.and.straw.fill")
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)

            // Show macros and doughnut if protein or processed was selected with types
            if hasNutritionDataForSummary {
                summaryNutritionSection
            }
        }
    }

    // Check if we have nutrition data to show in summary
    private var hasNutritionDataForSummary: Bool {
        let hasProteinData = quickHasProtein == true && !proteinState.selectedTypes.isEmpty
        let hasProcessedData = quickHasProcessed == true && !processedFoodsState.selectedTypes.isEmpty
        return hasProteinData || hasProcessedData
    }

    // Calculate total macros for summary
    private var summaryTotalCalories: Int {
        var total = 0
        if quickHasProtein == true {
            for selection in proteinState.selectedTypes {
                if let nutrition = categoryNutrition[selection.typeOption.id] {
                    total += Int((nutrition.calories ?? 0) * selection.amount / 100)
                }
            }
        }
        if quickHasProcessed == true {
            for selection in processedFoodsState.selectedTypes {
                if let nutrition = categoryNutrition[selection.typeOption.id] {
                    // selection.amount is in grams
                    total += Int((nutrition.calories ?? 0) * selection.amount / 100)
                }
            }
        }
        return total
    }

    private var summaryTotalProtein: Double {
        var total = 0.0
        if quickHasProtein == true {
            for selection in proteinState.selectedTypes {
                if let nutrition = categoryNutrition[selection.typeOption.id] {
                    total += (nutrition.proteinG ?? 0) * selection.amount / 100
                }
            }
        }
        if quickHasProcessed == true {
            for selection in processedFoodsState.selectedTypes {
                if let nutrition = categoryNutrition[selection.typeOption.id] {
                    // selection.amount is in grams
                    total += (nutrition.proteinG ?? 0) * selection.amount / 100
                }
            }
        }
        return total
    }

    private var summaryTotalCarbs: Double {
        var total = 0.0
        if quickHasProtein == true {
            for selection in proteinState.selectedTypes {
                if let nutrition = categoryNutrition[selection.typeOption.id] {
                    total += (nutrition.carbsG ?? 0) * selection.amount / 100
                }
            }
        }
        if quickHasProcessed == true {
            for selection in processedFoodsState.selectedTypes {
                if let nutrition = categoryNutrition[selection.typeOption.id] {
                    // selection.amount is in grams
                    total += (nutrition.carbsG ?? 0) * selection.amount / 100
                }
            }
        }
        return total
    }

    private var summaryTotalFat: Double {
        var total = 0.0
        if quickHasProtein == true {
            for selection in proteinState.selectedTypes {
                if let nutrition = categoryNutrition[selection.typeOption.id] {
                    total += (nutrition.fatTotalG ?? 0) * selection.amount / 100
                }
            }
        }
        if quickHasProcessed == true {
            for selection in processedFoodsState.selectedTypes {
                if let nutrition = categoryNutrition[selection.typeOption.id] {
                    // selection.amount is in grams
                    total += (nutrition.fatTotalG ?? 0) * selection.amount / 100
                }
            }
        }
        return total
    }

    private var summaryNutritionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Estimated Nutrition")
                .font(.subheadline.weight(.medium))
                .foregroundColor(NutrientCategory.nutritionColor)
                .textCase(.uppercase)

            WizardEntryDonutView(
                calories: summaryTotalCalories,
                protein: summaryTotalProtein,
                carbs: summaryTotalCarbs,
                fat: summaryTotalFat
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private func summaryRow(label: String, value: String, icon: String) -> some View {
        HStack(alignment: .top) {
            if !icon.isEmpty {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(NutrientCategory.nutritionColor)
                    .frame(width: 24)
            } else {
                Spacer().frame(width: 24)
            }

            if !label.isEmpty {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                    .frame(minWidth: 80, alignment: .leading)
            } else {
                Spacer().frame(width: 80)
            }

            Spacer()

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
                .frame(alignment: .trailing)
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            // Back button
            if currentPage != .mealAndTime {
                Button(action: goBack) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.body.weight(.medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                }
            }

            Spacer()

            // Next/Save button
            if canProceed {
                Button(action: proceedOrSave) {
                    HStack {
                        Text(isLastPage ? (isSaving ? "Saving..." : "Save Meal") : "Next")
                        if !isLastPage {
                            Image(systemName: "chevron.right")
                        }
                    }
                    .font(.body.weight(.semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .disabled(isSaving)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LinearGradient(colors: [Color.black.opacity(0.9), Color.black], startPoint: .top, endPoint: .bottom)
        )
    }

    private var canProceed: Bool {
        switch currentPage {
        case .mealAndTime: return true
        case .source: return selectedSource != nil
        case .mode: return selectedMode != nil
        case .categorySelection: return !selectedCategories.isEmpty
        case .categoryDetail(let cat):
            let state = categoryStates.first { $0.category == cat }!
            return !state.selectedTypes.isEmpty
        case .typeAmountEntry: return true  // Can always proceed from amount entry
        case .detailedReview: return true
        // Quick mode pages
        case .quickProteinQuestion: return quickHasProtein != nil
        case .quickProteinTypes: return !proteinState.selectedTypes.isEmpty
        case .quickTypeAmountEntry: return true  // Can always proceed from amount entry
        case .quickPlantBasedQuestion: return quickIsPlantBased != nil
        case .quickWholeFoodsQuestion: return quickIsMostlyWholeFoods != nil
        case .quickProcessedQuestion: return quickHasProcessed != nil
        case .quickProcessedTypes: return !processedFoodsState.selectedTypes.isEmpty
        case .quickSummaryReview: return true
        }
    }

    private var isLastPage: Bool {
        switch currentPage {
        case .quickSummaryReview: return true
        case .detailedReview: return true
        default: return false
        }
    }

    private func goBack() {
        if let previous = pageHistory.popLast() {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentPage = previous
            }
        }
    }

    private func proceedOrSave() {
        if isLastPage {
            Task { await saveLog() }
        } else {
            goToNextPage()
        }
    }

    private func goToNextPage() {
        pageHistory.append(currentPage)

        withAnimation(.easeInOut(duration: 0.2)) {
            switch currentPage {
            case .mealAndTime:
                currentPage = .source
            case .source:
                currentPage = .mode
            case .mode:
                if selectedMode == .detailed {
                    currentPage = .categorySelection
                } else {
                    // Quick mode: start with protein question
                    currentPage = .quickProteinQuestion
                }
            case .categorySelection:
                if let firstCat = selectedCategories.first {
                    // Load type selections for all selected categories
                    for catState in categoryStates where catState.isSelected {
                        catState.loadTypes(from: typeOptions[catState.category] ?? [])
                    }
                    currentPage = .categoryDetail(firstCat)
                }
            case .categoryDetail(let cat):
                let state = categoryStates.first { $0.category == cat }!
                let selectedTypes = state.selectedTypes
                if !selectedTypes.isEmpty {
                    // Go to first type amount entry for this category
                    currentPage = .typeAmountEntry(cat, 0)
                } else if let currentIdx = selectedCategories.firstIndex(of: cat),
                          currentIdx + 1 < selectedCategories.count {
                    // No types selected, go to next category
                    currentPage = .categoryDetail(selectedCategories[currentIdx + 1])
                } else {
                    // Last category with no types - go to review
                    currentPage = .detailedReview
                }
            case .typeAmountEntry(let cat, let typeIndex):
                let state = categoryStates.first { $0.category == cat }!
                let selectedTypes = state.selectedTypes
                if typeIndex + 1 < selectedTypes.count {
                    // More types in this category
                    currentPage = .typeAmountEntry(cat, typeIndex + 1)
                } else if let currentIdx = selectedCategories.firstIndex(of: cat),
                          currentIdx + 1 < selectedCategories.count {
                    // Move to next category
                    currentPage = .categoryDetail(selectedCategories[currentIdx + 1])
                } else {
                    // Done with all categories - go to review
                    currentPage = .detailedReview
                }
            case .detailedReview:
                break  // Already last page
            // Quick mode flow
            case .quickProteinQuestion:
                if quickHasProtein == true {
                    currentPage = .quickProteinTypes
                } else {
                    currentPage = .quickPlantBasedQuestion
                }
            case .quickProteinTypes:
                let selectedTypes = proteinState.selectedTypes
                if !selectedTypes.isEmpty {
                    // Go to first type amount entry
                    currentPage = .quickTypeAmountEntry(.protein, 0)
                } else {
                    currentPage = .quickPlantBasedQuestion
                }
            case .quickTypeAmountEntry(let cat, let typeIndex):
                let state = cat == .protein ? proteinState : processedFoodsState
                let selectedTypes = state.selectedTypes
                if typeIndex + 1 < selectedTypes.count {
                    // More types to enter
                    currentPage = .quickTypeAmountEntry(cat, typeIndex + 1)
                } else if cat == .protein {
                    // Done with protein - go to plant-based question
                    currentPage = .quickPlantBasedQuestion
                } else {
                    // Done with processed - go to summary
                    currentPage = .quickSummaryReview
                }
            case .quickPlantBasedQuestion:
                currentPage = .quickWholeFoodsQuestion
            case .quickWholeFoodsQuestion:
                currentPage = .quickProcessedQuestion
            case .quickProcessedQuestion:
                if quickHasProcessed == true {
                    currentPage = .quickProcessedTypes
                } else {
                    currentPage = .quickSummaryReview
                }
            case .quickProcessedTypes:
                let selectedTypes = processedFoodsState.selectedTypes
                if !selectedTypes.isEmpty {
                    // Go to first type amount entry
                    currentPage = .quickTypeAmountEntry(.processedFoods, 0)
                } else {
                    currentPage = .quickSummaryReview
                }
            case .quickSummaryReview:
                break  // Already last page
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundColor(.white)
    }

    // MARK: - Dark Wizard Background

    private var darkWizardBackground: some View {
        Color.black.ignoresSafeArea()
    }

    // MARK: - Data Loading

    private func loadTypeOptions() async {
        for category in NutrientCategory.allCases {
            do {
                // Join with usda_foods to get serving info per food type
                // usda_foods.category_reference_id -> sample_category_types_reference.id
                // Use explicit FK name because usda_foods has multiple FKs to this table
                // example_foods, serving_size, serving_tip, serving_grams are on usda_foods
                let responses: [TypeOptionResponse] = try await supabase
                    .from("sample_category_types_reference")
                    .select("id, reference_key, display_name, display_order, metadata, usda_foods!usda_foods_category_reference_id_fkey(example_foods, serving_size, serving_tip, serving_grams)")
                    .eq("reference_category", value: category.referenceCategory)
                    .order("display_order")
                    .execute()
                    .value

                // Map responses to TypeOption, extracting serving_grams from nested join
                let options = responses.map { $0.toTypeOption() }

                await MainActor.run {
                    typeOptions[category] = options
                }
            } catch {
                print("Failed to load type options for \(category): \(error)")
            }
        }

        // Load nutrition data from usda_foods (WellPath category entries)
        await loadCategoryNutrition()

        // Load portions from usda_food_portions
        await loadCategoryPortions()
    }

    private func loadCategoryNutrition() async {
        do {
            let nutrition: [CategoryFoodNutrition] = try await supabase
                .from("usda_foods")
                .select("id, category_reference_id, description, calories, protein_g, fat_total_g, carbs_g")
                .eq("is_wellpath_category", value: true)
                .not("category_reference_id", operator: .is, value: "null")
                .execute()
                .value

            await MainActor.run {
                for item in nutrition {
                    categoryNutrition[item.categoryReferenceId] = item
                }
            }
        } catch {
            print("Failed to load category nutrition: \(error)")
        }
    }

    private func loadCategoryPortions() async {
        // Load portions for all WellPath category foods
        do {
            let foodIds = categoryNutrition.values.map { $0.id.uuidString }
            guard !foodIds.isEmpty else { return }

            let portions: [USDAFoodPortion] = try await supabase
                .from("usda_food_portions")
                .select()
                .in("food_id", values: foodIds)
                .order("sequence_number")
                .execute()
                .value

            await MainActor.run {
                for portion in portions {
                    if categoryPortions[portion.foodId] == nil {
                        categoryPortions[portion.foodId] = []
                    }
                    categoryPortions[portion.foodId]?.append(portion)
                }
            }
        } catch {
            print("Failed to load category portions: \(error)")
        }
    }

    // MARK: - Save

    private func saveLog() async {
        isSaving = true
        errorMessage = nil

        do {
            let userId = try await supabase.auth.session.user.id
            let eventInstanceId = UUID()
            let timeString = ISO8601DateFormatter().string(from: selectedDateTime)

            var metadata: [String: AnyJSON] = [
                "meal_type": .string(selectedMealType.rawValue),
                "meal_source": .string(selectedSource?.id ?? "homemade")
            ]

            if selectedMode == .detailed {
                // Build nutrients array from all selected types across categories
                metadata["entry_type"] = .string("quick_log")

                var nutrients: [[String: AnyJSON]] = []
                for catState in categoryStates where catState.isSelected {
                    for typeSelection in catState.selectedTypes {
                        var nutrient: [String: AnyJSON] = [
                            "category": .string(catState.category.rawValue),
                            "type": .string(typeSelection.typeOption.referenceKey)
                        ]

                        // Store both grams and servings
                        // typeSelection.amount is the raw input (grams for most, items for processed)
                        nutrient["grams"] = .double(typeSelection.amount)

                        // Use per-food serving_grams from database (via FK join to usda_foods)
                        // For item-based (processedFoods): servingGrams = 1.0
                        // Fallback to category default if not set
                        let gramsPerServing = typeSelection.typeOption.servingGrams ?? catState.category.gramsPerServing
                        nutrient["servings"] = .double(typeSelection.amount / gramsPerServing)

                        nutrients.append(nutrient)
                    }
                }
                metadata["nutrients"] = .array(nutrients.map { .object($0) })
            } else {
                // Quick summary mode with multi-select
                metadata["entry_type"] = .string("high_level")
                metadata["is_plant_based"] = .bool(quickIsPlantBased == true)
                metadata["is_mostly_whole_foods"] = .bool(quickIsMostlyWholeFoods == true)
                metadata["has_ultra_processed"] = .bool(quickHasProcessed == true)

                // Add protein info if selected (multi-select)
                if quickHasProtein == true {
                    let selectedProtein = proteinState.selectedTypes
                    if !selectedProtein.isEmpty {
                        // Build array of protein selections with both grams and servings
                        var proteinSelections: [[String: AnyJSON]] = []
                        for selection in selectedProtein {
                            let gramsPerServing = selection.typeOption.servingGrams ?? NutrientCategory.protein.gramsPerServing
                            proteinSelections.append([
                                "type": .string(selection.typeOption.referenceKey),
                                "grams": .double(selection.amount),
                                "servings": .double(selection.amount / gramsPerServing)
                            ])
                        }
                        metadata["protein_selections"] = .array(proteinSelections.map { .object($0) })

                        // Also include first type for backwards compatibility
                        if let first = selectedProtein.first {
                            metadata["protein_type"] = .string(first.typeOption.referenceKey)
                            metadata["protein_grams"] = .double(first.amount)
                        }
                    }
                }

                // Add processed food info if selected (multi-select)
                if quickHasProcessed == true {
                    let selectedProcessed = processedFoodsState.selectedTypes
                    if !selectedProcessed.isEmpty {
                        // Build array of processed selections with both servings and grams
                        var processedSelections: [[String: AnyJSON]] = []
                        for selection in selectedProcessed {
                            // For processed foods: amount is items/servings, grams = amount * servingGrams
                            let gramsPerServing = selection.typeOption.servingGrams ?? 1.0
                            processedSelections.append([
                                "type": .string(selection.typeOption.referenceKey),
                                "servings": .double(selection.amount),
                                "grams": .double(selection.amount * gramsPerServing)
                            ])
                        }
                        metadata["processed_selections"] = .array(processedSelections.map { .object($0) })

                        // Also include first type for backwards compatibility
                        if let first = selectedProcessed.first {
                            metadata["processed_type"] = .string(first.typeOption.referenceKey)
                            metadata["processed_servings"] = .double(first.amount)
                        }
                    }
                }
            }

            let foodLog: [String: AnyJSON] = [
                "patient_id": .string(userId.uuidString),
                "category_type": .string("food_log"),
                "category_value": .string(selectedMealType.rawValue),
                "start_time": .string(timeString),
                "end_time": .string(timeString),
                "source": .string("wellpath_input"),
                "user_timezone": .string(TimeZone.current.identifier),
                "event_instance_id": .string(eventInstanceId.uuidString),
                "metadata": .object(metadata)
            ]

            try await supabase
                .from("patient_category_samples")
                .insert(foodLog)
                .execute()

            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }
}

// MARK: - Type Chip View (proper ObservedObject wrapper)

private struct TypeChipView: View {
    @ObservedObject var selection: TypeSelection
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                if selection.isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                }
                Text(selection.typeOption.displayName)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selection.isSelected ? NutrientCategory.nutritionColor.opacity(0.3) : Color.white.opacity(0.08))
            .foregroundColor(selection.isSelected ? .white : .white.opacity(0.8))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(selection.isSelected ? NutrientCategory.nutritionColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Amount Row View (FoodEntryView-style card - same as QuickAmountRow)
// Uses the same QuickAmountRow component for consistency
private typealias AmountRowView = QuickAmountRow

// MARK: - Quick Type Chip View (for quick mode multi-select)

private struct QuickTypeChip: View {
    @ObservedObject var selection: TypeSelection
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                if selection.isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                }
                Text(selection.typeOption.displayName)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(selection.isSelected ? NutrientCategory.nutritionColor.opacity(0.3) : Color.white.opacity(0.08))
            .foregroundColor(selection.isSelected ? .white : .white.opacity(0.8))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(selection.isSelected ? NutrientCategory.nutritionColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Amount Row View (FoodEntryView-style card)

private struct QuickAmountRow: View {
    @ObservedObject var selection: TypeSelection
    let category: NutrientCategory
    let nutrition: CategoryFoodNutrition?  // From usda_foods
    let portions: [USDAFoodPortion]  // From database

    @State private var servingMultiplier: String = "1"
    @State private var baseGrams: Double = 100
    @State private var showingInfo: Bool = false

    private var typeOption: TypeOption { selection.typeOption }

    // Calculate total grams based on serving size and multiplier
    private var totalGrams: Double {
        let multiplier = Double(servingMultiplier) ?? 1.0
        return baseGrams * max(multiplier, 0.1)
    }

    // Get serving options from database portions
    private var servingOptions: [(label: String, grams: Double)] {
        // Use database portions directly if available
        if !portions.isEmpty {
            return portions.map { portion in
                (portion.unit, portion.gramWeight)
            }
        }
        // Fallback options if no portions in database
        return [
            ("100g", 100),
            ("1g", 1)
        ]
    }

    // Current serving label - shows label without duplicating grams
    private var currentServingLabel: String {
        for option in servingOptions {
            if abs(option.grams - baseGrams) < 0.1 {
                return option.label
            }
        }
        return "\(Int(baseGrams))g"
    }

    // Whether the current serving label already contains grams
    private var labelContainsGrams: Bool {
        let label = currentServingLabel.lowercased()
        return label.contains("g)") || label == "100g" || label == "1g"
    }

    // Calculate nutrition based on current grams
    private var currentCalories: Int {
        guard let cal = nutrition?.calories else { return 0 }
        return Int(cal * totalGrams / 100)
    }

    private var currentProtein: Double {
        guard let p = nutrition?.proteinG else { return 0 }
        return p * totalGrams / 100
    }

    private var currentCarbs: Double {
        guard let c = nutrition?.carbsG else { return 0 }
        return c * totalGrams / 100
    }

    private var currentFat: Double {
        guard let f = nutrition?.fatTotalG else { return 0 }
        return f * totalGrams / 100
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header - Food name and category with About button
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(typeOption.displayName) (WellPath)")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showingInfo.toggle() } }) {
                        Image(systemName: showingInfo ? "info.circle.fill" : "info.circle")
                            .font(.title3)
                            .foregroundColor(showingInfo ? NutrientCategory.nutritionColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 4) {
                    Text("WellPath")
                        .font(.caption.weight(.medium))
                        .foregroundColor(NutrientCategory.nutritionColor)
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(category.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(uiColor: .systemBackground))

            // Info section (collapsed by default)
            if showingInfo {
                VStack(alignment: .leading, spacing: 12) {
                    if let examples = typeOption.exampleFoods {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Examples")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(NutrientCategory.nutritionColor)
                            Text(examples)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                    if let servingSize = typeOption.servingSize {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Serving Size")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(NutrientCategory.nutritionColor)
                            Text(servingSize)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                    if let tip = typeOption.servingTip {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tip")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(NutrientCategory.nutritionColor)
                            Text(tip)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
            }

            // Main content - List style rows
            VStack(spacing: 0) {
                // Serving Size row
                HStack {
                    Text("Serving Size")
                        .foregroundColor(.primary)
                    Spacer()
                    Menu {
                        ForEach(servingOptions, id: \.label) { option in
                            Button(option.label) {
                                baseGrams = option.grams
                                servingMultiplier = "1"
                                updateSelectionAmount()
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(currentServingLabel)
                                .foregroundColor(.primary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(uiColor: .systemGray5))
                        .cornerRadius(6)
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))

                Divider()

                // Number of Servings row
                HStack {
                    Text("Number of Servings")
                        .foregroundColor(.primary)
                    Spacer()
                    TextField("1", text: $servingMultiplier)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 70)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(uiColor: .systemGray5))
                        .cornerRadius(6)
                        .onChange(of: servingMultiplier) { _, _ in
                            updateSelectionAmount()
                        }
                    // Only show grams total if label doesn't already show same grams or multiplier != 1
                    let multiplier = Double(servingMultiplier) ?? 1.0
                    if !labelContainsGrams || multiplier != 1.0 {
                        Text("= \(Int(totalGrams))g")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
            }
            .cornerRadius(12)
            .padding(.horizontal)

            // Nutrition section with donut
            if nutrition != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nutrition")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(NutrientCategory.nutritionColor)
                        .textCase(.uppercase)

                    WizardNutritionDonutView(
                        calories: currentCalories,
                        protein: currentProtein,
                        carbs: currentCarbs,
                        fat: currentFat
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 12)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .cornerRadius(16)
        .onAppear {
            // Set initial serving based on category-specific options
            baseGrams = servingOptions.first?.grams ?? 100
            updateSelectionAmount()
        }
    }

    private func updateSelectionAmount() {
        // Always store total grams for consistent nutrition calculations
        selection.amount = totalGrams
    }
}

// MARK: - Wizard Nutrition Donut View

private struct WizardNutritionDonutView: View {
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double

    private var total: Double {
        protein + carbs + fat
    }

    private var proteinPercent: Int {
        guard total > 0 else { return 0 }
        return Int((protein / total) * 100)
    }

    private var carbsPercent: Int {
        guard total > 0 else { return 0 }
        return Int((carbs / total) * 100)
    }

    private var fatPercent: Int {
        guard total > 0 else { return 0 }
        return Int((fat / total) * 100)
    }

    var body: some View {
        HStack(spacing: 24) {
            // Donut chart
            ZStack {
                Circle()
                    .stroke(Color(uiColor: .systemGray5), lineWidth: 12)
                    .frame(width: 100, height: 100)

                WizardDonutSegments(protein: protein, carbs: carbs, fat: fat)
                    .frame(width: 100, height: 100)

                VStack(spacing: 0) {
                    Text("\(calories)")
                        .font(.title2.weight(.bold))
                    Text("cal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)

            // Macro breakdown
            VStack(alignment: .leading, spacing: 12) {
                WizardMacroRow(color: .blue, name: "Carbs", percent: carbsPercent, grams: Int(carbs))
                WizardMacroRow(color: .orange, name: "Fat", percent: fatPercent, grams: Int(fat))
                WizardMacroRow(color: .red, name: "Protein", percent: proteinPercent, grams: Int(protein))
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

private struct WizardDonutSegments: View {
    let protein: Double
    let carbs: Double
    let fat: Double

    private var total: Double { protein + carbs + fat }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let lineWidth: CGFloat = 12

            ZStack {
                if total > 0 {
                    Circle()
                        .trim(from: 0, to: carbs / total)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        .rotationEffect(.degrees(-90))

                    Circle()
                        .trim(from: carbs / total, to: (carbs + fat) / total)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        .rotationEffect(.degrees(-90))

                    Circle()
                        .trim(from: (carbs + fat) / total, to: 1)
                        .stroke(Color.red, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(width: size, height: size)
        }
    }
}

private struct WizardMacroRow: View {
    let color: Color
    let name: String
    let percent: Int
    let grams: Int

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text("\(percent)%")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(color)
                .frame(width: 40, alignment: .leading)
            Text("\(grams)g")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(name)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Type Amount Entry View (FoodEntryView-style individual entry)

private struct TypeAmountEntryView: View {
    @ObservedObject var selection: TypeSelection
    let category: NutrientCategory
    let nutrition: CategoryFoodNutrition?
    let portions: [USDAFoodPortion]
    let currentIndex: Int
    let totalCount: Int

    @State private var servingMultiplier: String = "1"
    @State private var selectedPortionIndex: Int = 0
    @State private var showingInfo: Bool = false

    private var typeOption: TypeOption { selection.typeOption }

    private var hasInfo: Bool {
        let hasExamples = typeOption.exampleFoods != nil && !typeOption.exampleFoods!.isEmpty
        let hasServing = typeOption.servingSize != nil && !typeOption.servingSize!.isEmpty
        let hasTip = typeOption.servingTip != nil && !typeOption.servingTip!.isEmpty
        return hasExamples || hasServing || hasTip
    }

    private var selectedPortion: USDAFoodPortion? {
        guard selectedPortionIndex < portions.count else { return nil }
        return portions[selectedPortionIndex]
    }

    private var baseGrams: Double {
        selectedPortion?.gramWeight ?? 100
    }

    private var totalGrams: Double {
        let multiplier = Double(servingMultiplier) ?? 1.0
        return baseGrams * max(multiplier, 0.1)
    }

    // Display the serving size label without duplicating grams
    private var currentServingLabel: String {
        if let portion = selectedPortion {
            // Just use the unit directly since database labels are clean
            return portion.unit
        }
        return "100g"
    }

    // Whether the current serving label already contains grams info
    private var labelContainsGrams: Bool {
        let label = currentServingLabel.lowercased()
        return label.contains("g)") || label == "100g" || label == "1g"
    }

    private var currentCalories: Int {
        guard let cal = nutrition?.calories else { return 0 }
        return Int(cal * totalGrams / 100)
    }

    private var currentProtein: Double {
        guard let p = nutrition?.proteinG else { return 0 }
        return p * totalGrams / 100
    }

    private var currentCarbs: Double {
        guard let c = nutrition?.carbsG else { return 0 }
        return c * totalGrams / 100
    }

    private var currentFat: Double {
        guard let f = nutrition?.fatTotalG else { return 0 }
        return f * totalGrams / 100
    }

    var body: some View {
        VStack(spacing: 12) {
            // Dot progress indicator (centered)
            if totalCount > 1 {
                HStack(spacing: 6) {
                    Spacer()
                    ForEach(1...totalCount, id: \.self) { index in
                        Circle()
                            .fill(index <= currentIndex ? NutrientCategory.nutritionColor : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                    Spacer()
                }
            }

            // Header card - Food name and category with About button
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(typeOption.displayName) (WellPath)")
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    // About button (only if has info) - icon only, nutrition colored
                    if hasInfo {
                        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showingInfo.toggle() } }) {
                            Image(systemName: showingInfo ? "info.circle.fill" : "info.circle")
                                .font(.title3)
                                .foregroundColor(NutrientCategory.nutritionColor)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 4) {
                    Text("WellPath")
                        .font(.caption.weight(.medium))
                        .foregroundColor(NutrientCategory.nutritionColor)
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    Text("WellPath \(category.displayName)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)

            // Info section - collapsed by default with colored headers
            if hasInfo && showingInfo {
                VStack(alignment: .leading, spacing: 12) {
                    if let examples = typeOption.exampleFoods, !examples.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Examples")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(NutrientCategory.nutritionColor)
                            Text(examples)
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }

                    if let servingSize = typeOption.servingSize, !servingSize.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Serving Size")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(NutrientCategory.nutritionColor)
                            Text(servingSize)
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }

                    if let tip = typeOption.servingTip, !tip.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tip")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(NutrientCategory.nutritionColor)
                            Text(tip)
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            }

            // Serving controls card
            VStack(spacing: 0) {
                // Serving Size row - use portions from database
                HStack {
                    Text("Serving Size")
                        .foregroundColor(.white)
                    Spacer()
                    if !portions.isEmpty {
                        Picker("Serving", selection: $selectedPortionIndex) {
                            ForEach(0..<portions.count, id: \.self) { index in
                                // Use clean labels from database
                                Text(portions[index].unit)
                                    .tag(index)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.white)
                        .onChange(of: selectedPortionIndex) { _, _ in
                            servingMultiplier = "1"
                            updateSelectionAmount()
                        }
                    } else {
                        Text("100g")
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding()

                Divider().background(Color.white.opacity(0.1))

                // Number of Servings row
                HStack {
                    Text("Number of Servings")
                        .foregroundColor(.white)
                    Spacer()
                    TextField("1", text: $servingMultiplier)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 70)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .onChange(of: servingMultiplier) { _, _ in
                            updateSelectionAmount()
                        }
                    // Only show grams total if label doesn't already show same grams or multiplier != 1
                    let multiplier = Double(servingMultiplier) ?? 1.0
                    if !labelContainsGrams || multiplier != 1.0 {
                        Text("= \(Int(totalGrams))g")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.caption)
                    }
                }
                .padding()
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)

            // Nutrition section with donut - always show
            VStack(alignment: .leading, spacing: 8) {
                Text("Nutrition")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(NutrientCategory.nutritionColor)
                    .textCase(.uppercase)
                    .padding(.top, 4)

                WizardEntryDonutView(
                    calories: currentCalories,
                    protein: currentProtein,
                    carbs: currentCarbs,
                    fat: currentFat
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
        .onAppear {
            // Reset to defaults when entering each type's page
            selectedPortionIndex = 0
            servingMultiplier = "1"
            updateSelectionAmount()
        }
    }

    private func updateSelectionAmount() {
        // Always store total grams for nutrition calculations
        selection.amount = totalGrams
    }
}

// MARK: - Wizard Entry Donut View (dark theme)

private struct WizardEntryDonutView: View {
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double

    private var total: Double { protein + carbs + fat }

    private var proteinPercent: Int {
        guard total > 0 else { return 0 }
        return Int((protein / total) * 100)
    }

    private var carbsPercent: Int {
        guard total > 0 else { return 0 }
        return Int((carbs / total) * 100)
    }

    private var fatPercent: Int {
        guard total > 0 else { return 0 }
        return Int((fat / total) * 100)
    }

    var body: some View {
        HStack(spacing: 24) {
            // Donut chart
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 12)
                    .frame(width: 100, height: 100)

                WizardDonutSegments(protein: protein, carbs: carbs, fat: fat)
                    .frame(width: 100, height: 100)

                VStack(spacing: 0) {
                    Text("\(calories)")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                    Text("cal")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.vertical, 8)

            // Macro breakdown
            VStack(alignment: .leading, spacing: 12) {
                WizardEntryMacroRow(color: .blue, name: "Carbs", percent: carbsPercent, grams: Int(carbs))
                WizardEntryMacroRow(color: .orange, name: "Fat", percent: fatPercent, grams: Int(fat))
                WizardEntryMacroRow(color: .red, name: "Protein", percent: proteinPercent, grams: Int(protein))
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

private struct WizardEntryMacroRow: View {
    let color: Color
    let name: String
    let percent: Int
    let grams: Int

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text("\(percent)%")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(color)
                .frame(width: 40, alignment: .leading)
            Text("\(grams)g")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
            Text(name)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

// MARK: - Preview

#Preview {
    QuickLogWizardView()
}
