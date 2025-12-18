//
//  FoodEntryView.swift
//  WellPath
//
//  Universal food logging with two modes:
//  1. Database lookup - search USDA/custom foods + portion
//  2. Quick log - attributes only (food type, meal size)
//

import SwiftUI
import Supabase

// MARK: - Entry Mode

enum FoodEntryMode: String, CaseIterable {
    case search = "Quick Entry"
    case quickLog = "Meal Builder"
}

// MARK: - Quick Portion Options

enum QuickPortion: String, CaseIterable, Identifiable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case half = "half"
    case full = "full"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .half: return "½ Serving"
        case .full: return "1 Serving"
        }
    }

    var multiplier: Double {
        switch self {
        case .small: return 0.5
        case .medium: return 1.0
        case .large: return 1.5
        case .half: return 0.5
        case .full: return 1.0
        }
    }
}

// MARK: - Meal Context (where/how the food was prepared)

enum MealContext: String, CaseIterable, Identifiable {
    case homemade = "homemade"
    case sitDown = "sit_down"
    case takeout = "takeout"
    case fastFood = "fast_food"
    case preparedMeal = "prepared_meal"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .homemade: return "Homemade"
        case .sitDown: return "Sit-Down"
        case .takeout: return "Takeout"
        case .fastFood: return "Fast Food"
        case .preparedMeal: return "Prepared"
        }
    }

    var icon: String {
        switch self {
        case .homemade: return "house.fill"
        case .sitDown: return "fork.knife"
        case .takeout: return "bag.fill"
        case .fastFood: return "car.fill"
        case .preparedMeal: return "shippingbox.fill"
        }
    }

    var color: Color {
        switch self {
        case .homemade: return .green
        case .sitDown: return .blue
        case .takeout: return .orange
        case .fastFood: return .red
        case .preparedMeal: return .purple
        }
    }
}

// MARK: - Food Type Attributes (multi-select)

enum FoodTypeAttribute: String, CaseIterable, Identifiable {
    case wholeFoods = "whole_foods"
    case plantBased = "plant_based"
    case processed = "processed"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wholeFoods: return "Whole Foods"
        case .plantBased: return "Plant-Based"
        case .processed: return "Processed"
        }
    }

    var icon: String {
        switch self {
        case .wholeFoods: return "leaf.fill"
        case .plantBased: return "carrot.fill"
        case .processed: return "shippingbox.fill"
        }
    }

    var color: Color {
        switch self {
        case .wholeFoods: return .green
        case .plantBased: return .mint
        case .processed: return .orange
        }
    }
}

// MARK: - Meal Size

enum MealSize: String, CaseIterable, Identifiable {
    case snack = "snack"
    case small = "small"
    case medium = "medium"
    case large = "large"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .snack: return "Snack"
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}

// MARK: - Food Favorite Model

struct FoodFavorite: Codable, Identifiable {
    let id: UUID
    let patientId: UUID
    let usdaFoodId: UUID?
    let customFoodId: UUID?
    let defaultPortionGrams: Double?
    let displayOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case usdaFoodId = "usda_food_id"
        case customFoodId = "custom_food_id"
        case defaultPortionGrams = "default_portion_grams"
        case displayOrder = "display_order"
    }
}

struct FoodEntryView: View {
    @Environment(\.dismiss) var dismiss

    // Mode selection
    @State private var entryMode: FoodEntryMode = .search

    // Database search state
    @State private var searchText = ""
    @State private var searchResults: [FoodSearchResult] = []
    @State private var searchOffset: Int = 0
    @State private var hasMoreSearchResults: Bool = false
    @State private var isLoadingMore: Bool = false
    private let searchPageSize = 20
    @State private var favorites: [FoodSearchResult] = []
    @State private var selectedFood: FoodSearchResult?
    @State private var foodPortions: [USDAFoodPortion] = []
    @State private var selectedPortion: USDAFoodPortion?
    @State private var selectedQuickPortion: QuickPortion = .medium
    @State private var useCustomAmount = false
    @State private var customAmount: String = "1"
    @State private var baseGrams: Double = 100

    // Quick log state
    @State private var selectedFoodTypes: Set<FoodTypeAttribute> = []
    @State private var selectedMealSize: MealSize = .medium
    @State private var selectedMealContext: MealContext = .homemade

    // Common state
    @State private var selectedMealType: MealType = .suggestedForTime(Date())
    @State private var selectedDateTime = Date()
    @State private var isSearching = false
    @State private var isSaving = false
    @State private var isLoadingFavorites = false
    @State private var errorMessage: String?
    @State private var showingCustomFoodSheet = false
    @State private var showingMyFoodsManagement = false
    @State private var editingCustomFood: CustomFood?
    @State private var recentFoods: [FoodSearchResult] = []
    @State private var allRecentFoods: [FoodSearchResult] = []  // Full list for "See All"
    @State private var showingAllRecentFoods = false
    @State private var myFoods: [CustomFood] = []  // User's custom foods
    @State private var showingQuickLogWizard = false

    // WellPath category info state
    @State private var showingCategoryInfo = false

    private let supabase = SupabaseManager.shared.client

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode picker at top
                if selectedFood == nil {
                    modePicker
                }

                if entryMode == .search {
                    if selectedFood == nil {
                        searchView
                    } else {
                        portionEntryView
                    }
                } else {
                    quickLogView
                }
            }
            .navigationTitle(selectedFood == nil ? "Log Food" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(selectedFood != nil ? "Back" : "Cancel", action: handleBackAction)
                        .disabled(isSaving)
                }
            }
            .sheet(isPresented: $showingCustomFoodSheet) {
                CustomFoodEntryView { customFood in
                    selectedFood = .custom(customFood)
                    baseGrams = customFood.defaultServingGrams ?? 100
                    Task { await loadMyFoods() }
                }
            }
            .sheet(isPresented: $showingMyFoodsManagement) {
                MyFoodsManagementView(foods: $myFoods, onDelete: { food in
                    Task { await deleteCustomFood(food) }
                }, onEdit: { food in
                    editingCustomFood = food
                })
            }
            .sheet(item: $editingCustomFood) { food in
                EditCustomFoodView(food: food) { updatedFood in
                    if let index = myFoods.firstIndex(where: { $0.id == updatedFood.id }) {
                        myFoods[index] = updatedFood
                    }
                }
            }
            .sheet(isPresented: $showingAllRecentFoods) {
                AllRecentFoodsView(
                    foods: allRecentFoods,
                    isFavorite: isFavorite,
                    onSelect: { food in
                        showingAllRecentFoods = false
                        selectFood(food)
                    },
                    onToggleFavorite: { food in
                        Task { await toggleFavorite(food) }
                    }
                )
            }
            .task {
                await loadFavorites()
                await loadMyFoods()
                await loadRecentFoods()
            }
        }
    }

    private func handleBackAction() {
        if selectedFood != nil {
            selectedFood = nil
            selectedPortion = nil
            foodPortions = []
        } else {
            dismiss()
        }
    }

    // MARK: - Meal Type Selector

    private var mealTypeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(MealType.allCases) { mealType in
                    MealTypeButton(
                        mealType: mealType,
                        isSelected: selectedMealType == mealType,
                        action: { selectedMealType = mealType }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        Picker("", selection: $entryMode) {
            ForEach(FoodEntryMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Search View

    private var searchView: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.body)
                TextField("Search foods...", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .onSubmit { Task { await searchFoods() } }
                if !searchText.isEmpty {
                    Button(action: { clearSearch() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(12)
            .padding()

            if isSearching {
                Spacer()
                ProgressView()
                Spacer()
            } else if !searchResults.isEmpty {
                searchResultsList
            } else if searchText.isEmpty {
                emptyStateView
            } else {
                noResultsView
            }
        }
        .onChange(of: searchText) { _, newValue in
            if newValue.count >= 2 {
                Task { await searchFoods() }
            } else if newValue.isEmpty {
                clearSearch()
            }
        }
    }

    private var searchResultsList: some View {
        List {
            ForEach(searchResults) { result in
                FoodResultRow(
                    result: result,
                    isFavorite: isFavorite(result),
                    onSelect: { selectFood(result) },
                    onToggleFavorite: { Task { await toggleFavorite(result) } }
                )
            }

            if hasMoreSearchResults {
                Button(action: { Task { await loadMoreResults() } }) {
                    HStack {
                        Spacer()
                        if isLoadingMore {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Loading...")
                        } else {
                            Text("Load More Results")
                        }
                        Spacer()
                    }
                    .foregroundColor(.blue)
                    .padding(.vertical, 8)
                }
                .disabled(isLoadingMore)
            }

            Button(action: { showingCustomFoodSheet = true }) {
                Label("Add Custom Food", systemImage: "plus.circle")
                    .foregroundColor(.green)
            }
        }
        .listStyle(.plain)
    }

    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Favorites section
                if !favorites.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("Favorites")
                                .font(.headline)
                        }
                        .padding(.horizontal)

                        ForEach(favorites) { food in
                            FoodResultRow(
                                result: food,
                                isFavorite: true,
                                onSelect: { selectFood(food) },
                                onToggleFavorite: { Task { await toggleFavorite(food) } }
                            )
                            .padding(.horizontal)
                        }
                    }
                }

                // My Foods section (custom foods)
                if !myFoods.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundColor(.purple)
                            Text("My Foods")
                                .font(.headline)
                            Spacer()
                            Button("Manage") {
                                showingMyFoodsManagement = true
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal)

                        ForEach(myFoods) { food in
                            let result = FoodSearchResult.custom(food)
                            FoodResultRow(
                                result: result,
                                isFavorite: isFavorite(result),
                                onSelect: { selectFood(result) },
                                onToggleFavorite: { Task { await toggleFavorite(result) } }
                            )
                            .padding(.horizontal)
                        }
                    }
                }

                // Recent foods section
                if !recentFoods.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.blue)
                            Text("Recent")
                                .font(.headline)
                            Spacer()
                            if allRecentFoods.count > 5 {
                                Button("See All") {
                                    showingAllRecentFoods = true
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)

                        ForEach(recentFoods) { food in
                            FoodResultRow(
                                result: food,
                                isFavorite: isFavorite(food),
                                onSelect: { selectFood(food) },
                                onToggleFavorite: { Task { await toggleFavorite(food) } }
                            )
                            .padding(.horizontal)
                        }
                    }
                }

                // Empty prompt (only show if nothing to show)
                if favorites.isEmpty && myFoods.isEmpty && recentFoods.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))

                        Text("Search 350+ whole foods")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                }

                Button(action: { showingCustomFoodSheet = true }) {
                    Label("Add Custom Food", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(.green)
                .padding(.top, 8)
            }
            .padding(.top, 16)
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No results for \"\(searchText)\"")
                .foregroundColor(.secondary)

            Button(action: { showingCustomFoodSheet = true }) {
                Label("Add Custom Food", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.bordered)
            .tint(.green)
            Spacer()
        }
    }

    // MARK: - Portion Entry View

    private var portionEntryView: some View {
        VStack(spacing: 0) {
            // Food header
            if let food = selectedFood {
                foodDetailHeader(food)
            }

            // Main content - MFP style list
            List {
                // Serving Size row
                servingSizeRow

                // Amount row (type grams directly)
                amountRow

                // Meal row
                mealRow

                // Date row
                dateRow

                // Nutrition section
                nutritionSection

                // Error message section
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .listStyle(.insetGrouped)

            saveButton(title: "Log Food")
        }
    }

    private func foodDetailHeader(_ food: FoodSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row with food name and info button
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(food.displayName)
                            .font(.title3.weight(.semibold))
                            .lineLimit(2)

                        HStack(spacing: 4) {
                            if food.isWellPathCategory {
                                Text("WellPath")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(food.displayCategory)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // About button for WellPath category foods
                    if food.isWellPathCategory {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showingCategoryInfo.toggle()
                            }
                        }) {
                            Image(systemName: showingCategoryInfo ? "info.circle.fill" : "info.circle")
                                .font(.title3)
                                .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()

            // Info section (collapsed by default) - data comes directly from usda_foods
            if food.isWellPathCategory && showingCategoryInfo {
                VStack(alignment: .leading, spacing: 12) {
                    if let examples = food.exampleFoods, !examples.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Examples")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                            Text(examples)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }

                    if let serving = food.servingSize, !serving.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Serving Size")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                            Text(serving)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }

                    if let tip = food.servingTip, !tip.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tip")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.5))
                            Text(tip)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    @State private var customGramsText: String = "100"
    @State private var customServingLabel: String? = nil  // For custom food's serving description

    private var servingSizeRow: some View {
        HStack {
            Text("Serving Size")
            Spacer()
            Menu {
                // Custom food's default serving (e.g., "1 bar")
                if let food = selectedFood, case .custom(let customFood) = food {
                    if let servingDesc = customFood.servingDescription,
                       let servingGrams = customFood.defaultServingGrams {
                        Button("\(servingDesc) (\(Int(servingGrams))g)") {
                            selectedPortion = nil
                            baseGrams = servingGrams
                            customServingLabel = servingDesc
                            servingMultiplier = "1"
                        }
                    }
                }

                // USDA portions from database (includes 1 serving, 1 oz, 100g, 1g)
                if !foodPortions.isEmpty {
                    ForEach(foodPortions) { portion in
                        Button(portion.displayString) {
                            selectedPortion = portion
                            baseGrams = portion.gramWeight
                            customServingLabel = nil
                            servingMultiplier = "1"
                        }
                    }
                } else {
                    // Fallback if no portions in database
                    Button("100g") {
                        selectedPortion = nil
                        baseGrams = 100
                        customServingLabel = nil
                        servingMultiplier = "1"
                    }
                    Button("1g") {
                        selectedPortion = nil
                        baseGrams = 1
                        customServingLabel = "1g"
                        servingMultiplier = "1"
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
    }

    private var currentServingLabel: String {
        if let portion = selectedPortion {
            // Use clean unit label from database directly
            return portion.unit
        }
        if let label = customServingLabel {
            return label
        }
        return "\(Int(baseGrams))g"
    }

    @State private var servingMultiplier: String = "1"

    private var amountRow: some View {
        HStack {
            Text("Number of Servings")
            Spacer()
            TextField("1", text: $servingMultiplier)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(width: 70)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(uiColor: .systemGray5))
                .cornerRadius(6)
            Text("= \(Int(totalGrams))g")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }

    private var totalGrams: Double {
        // Multiply serving size by number of servings
        let multiplier = Double(servingMultiplier) ?? 1.0
        return baseGrams * max(multiplier, 0.1)
    }

    private var mealRow: some View {
        HStack {
            Text("Meal")
            Spacer()
            Menu {
                ForEach(MealType.allCases) { meal in
                    Button {
                        selectedMealType = meal
                    } label: {
                        Label(meal.displayName, systemImage: meal.icon)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: selectedMealType.icon)
                        .foregroundColor(selectedMealType.color)
                    Text(selectedMealType.displayName)
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
    }

    private var dateRow: some View {
        HStack {
            Text("Date")
            Spacer()
            DatePicker("", selection: $selectedDateTime, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
        }
    }

    private var nutritionSection: some View {
        Section {
            if let food = selectedFood {
                let nutrients = food.nutrients(forGrams: calculatedGrams)

                NutritionDonutView(
                    calories: Int(nutrients.calories),
                    protein: nutrients.proteinG,
                    carbs: nutrients.carbsG,
                    fat: nutrients.fatTotalG
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        } header: {
            Text("Nutrition")
        }
    }

    private var calculatedGrams: Double {
        totalGrams
    }

    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("When")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            DatePicker("", selection: $selectedDateTime)
                .labelsHidden()
                .datePickerStyle(.compact)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }


    // MARK: - Quick Log View

    private var quickLogView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Wizard intro
            VStack(spacing: 16) {
                Image(systemName: "fork.knife.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.green.opacity(0.8))

                Text("Meal Builder")
                    .font(.title2.weight(.bold))

                Text("Build your meal in a few simple steps.\nNo calorie counting required!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Start wizard button
            Button(action: { showingQuickLogWizard = true }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Logging")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal)

            // Info about what's logged
            VStack(spacing: 10) {
                Text("What gets tracked:")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)

                // Row 1: 4 items
                HStack(spacing: 16) {
                    QuickLogInfoItem(icon: "fish.fill", label: "Protein")
                    QuickLogInfoItem(icon: "carrot.fill", label: "Veggies")
                    QuickLogInfoItem(icon: "apple.logo", label: "Fruits")
                    QuickLogInfoItem(icon: "basket.fill", label: "Grains")
                }
                // Row 2: 3 items centered
                HStack(spacing: 16) {
                    QuickLogInfoItem(icon: "leaf.fill", label: "Legumes")
                    QuickLogInfoItem(icon: "seal.fill", label: "Nuts")
                    QuickLogInfoItem(icon: "takeoutbag.and.cup.and.straw.fill", label: "Processed")
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)

            Spacer()
            Spacer()
        }
        .fullScreenCover(isPresented: $showingQuickLogWizard) {
            QuickLogWizardView()
        }
    }

    // MARK: - Save Button

    private func saveButton(title: String) -> some View {
        Button(action: {
            Task {
                if entryMode == .search {
                    await saveDatabaseEntry()
                } else {
                    await saveQuickLogEntry()
                }
            }
        }) {
            if isSaving {
                ProgressView()
                    .tint(.white)
            } else {
                Text(title)
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(canSave ? Color.green : Color.gray.opacity(0.3))
        .foregroundColor(.white)
        .cornerRadius(12)
        .padding()
        .disabled(!canSave || isSaving)
    }

    private var canSave: Bool {
        if entryMode == .search {
            return selectedFood != nil && calculatedGrams > 0
        } else {
            return !selectedFoodTypes.isEmpty
        }
    }

    // MARK: - Data Functions

    private func selectFood(_ food: FoodSearchResult) {
        selectedFood = food
        servingMultiplier = "1"
        showingCategoryInfo = false

        if case .usda(let usdaFood) = food {
            baseGrams = 100 // Default to 100g for USDA
            Task { await loadPortions(for: usdaFood) }
        } else if case .custom(let customFood) = food {
            baseGrams = customFood.defaultServingGrams ?? 100
        }
    }

    private func loadFavorites() async {
        isLoadingFavorites = true
        do {
            let userId = try await supabase.auth.session.user.id

            // Load favorite records
            let favRecords: [FoodFavorite] = try await supabase
                .from("patient_food_favorites")
                .select()
                .eq("patient_id", value: userId.uuidString)
                .order("display_order")
                .limit(10)
                .execute()
                .value

            // Load the actual food data for each favorite
            var loadedFavorites: [FoodSearchResult] = []
            for fav in favRecords {
                if let usdaId = fav.usdaFoodId {
                    if let food: USDAFood = try? await supabase
                        .from("usda_foods")
                        .select()
                        .eq("id", value: usdaId.uuidString)
                        .single()
                        .execute()
                        .value {
                        loadedFavorites.append(.usda(food))
                    }
                } else if let customId = fav.customFoodId {
                    if let food: CustomFood = try? await supabase
                        .from("patient_custom_foods")
                        .select()
                        .eq("id", value: customId.uuidString)
                        .single()
                        .execute()
                        .value {
                        loadedFavorites.append(.custom(food))
                    }
                }
            }

            await MainActor.run {
                favorites = loadedFavorites
                isLoadingFavorites = false
            }
        } catch {
            await MainActor.run {
                isLoadingFavorites = false
            }
        }
    }

    private func loadRecentFoods() async {
        do {
            let userId = try await supabase.auth.session.user.id

            // Query from patient_recent_foods with joined food data
            let recentRecords: [RecentFood] = try await supabase
                .from("patient_recent_foods")
                .select("*, usda_foods(*), patient_custom_foods(*)")
                .eq("patient_id", value: userId.uuidString)
                .order("last_logged_at", ascending: false)
                .limit(20)
                .execute()
                .value

            // Convert to FoodSearchResults
            let loadedRecents = recentRecords.compactMap { $0.asFoodSearchResult }

            await MainActor.run {
                // Show first 5 in main view
                recentFoods = Array(loadedRecents.prefix(5))
                // Keep all for "See All" sheet
                allRecentFoods = loadedRecents
            }
        } catch {
            // Silently fail - recent foods is not critical
            print("Failed to load recent foods: \(error)")
        }
    }

    private func loadMyFoods() async {
        do {
            let userId = try await supabase.auth.session.user.id

            let foods: [CustomFood] = try await supabase
                .from("patient_custom_foods")
                .select()
                .eq("patient_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value

            await MainActor.run {
                myFoods = foods
            }
        } catch {
            print("Failed to load my foods: \(error)")
        }
    }

    private func deleteCustomFood(_ food: CustomFood) async {
        do {
            let userId = try await supabase.auth.session.user.id

            try await supabase
                .from("patient_custom_foods")
                .delete()
                .eq("id", value: food.id.uuidString)
                .eq("patient_id", value: userId.uuidString)
                .execute()

            await MainActor.run {
                myFoods.removeAll { $0.id == food.id }
            }
            print("✅ Deleted custom food: \(food.name)")
        } catch {
            print("❌ Failed to delete custom food: \(error)")
        }
    }

    private func isFavorite(_ food: FoodSearchResult) -> Bool {
        favorites.contains { $0.id == food.id }
    }

    private func toggleFavorite(_ food: FoodSearchResult) async {
        do {
            let userId = try await supabase.auth.session.user.id

            if isFavorite(food) {
                // Remove from favorites
                switch food {
                case .usda(let usdaFood):
                    try await supabase
                        .from("patient_food_favorites")
                        .delete()
                        .eq("patient_id", value: userId.uuidString)
                        .eq("usda_food_id", value: usdaFood.id.uuidString)
                        .execute()
                case .custom(let customFood):
                    try await supabase
                        .from("patient_food_favorites")
                        .delete()
                        .eq("patient_id", value: userId.uuidString)
                        .eq("custom_food_id", value: customFood.id.uuidString)
                        .execute()
                }

                await MainActor.run {
                    favorites.removeAll { $0.id == food.id }
                }
            } else {
                // Add to favorites
                var record: [String: AnyJSON] = [
                    "patient_id": .string(userId.uuidString)
                ]

                switch food {
                case .usda(let usdaFood):
                    record["usda_food_id"] = .string(usdaFood.id.uuidString)
                case .custom(let customFood):
                    record["custom_food_id"] = .string(customFood.id.uuidString)
                }

                try await supabase
                    .from("patient_food_favorites")
                    .insert(record)
                    .execute()

                await MainActor.run {
                    favorites.append(food)
                }
            }
        } catch {
            print("Failed to toggle favorite: \(error)")
        }
    }

    private func clearSearch() {
        searchText = ""
        searchResults = []
        searchOffset = 0
        hasMoreSearchResults = false
    }

    private func searchFoods() async {
        guard searchText.count >= 2 else { return }

        // Reset pagination for new search
        searchOffset = 0
        hasMoreSearchResults = false
        isSearching = true

        do {
            // Split search text into words for flexible matching
            let searchWords = searchText.lowercased().split(separator: " ").map(String.init)

            // Build search pattern - search for each word with wildcards
            // e.g., "chicken breast" becomes pattern that matches any food containing both words
            let pattern = searchWords.map { "%\($0)%" }.joined(separator: "")

            // Also try the original search text as-is for exact matches
            let exactPattern = "%\(searchText)%"

            // Search USDA foods with flexible pattern - try description and display_name
            let usdaResults: [USDAFood] = try await supabase
                .from("usda_foods")
                .select()
                .or("description.ilike.\(exactPattern),display_name.ilike.\(exactPattern),description.ilike.\(pattern)")
                .order("description", ascending: true)
                .range(from: 0, to: searchPageSize - 1)
                .execute()
                .value

            let userId = try await supabase.auth.session.user.id
            let customResults: [CustomFood] = try await supabase
                .from("patient_custom_foods")
                .select()
                .eq("patient_id", value: userId.uuidString)
                .or("name.ilike.\(exactPattern),name.ilike.\(pattern)")
                .limit(10)
                .execute()
                .value

            await MainActor.run {
                var results: [FoodSearchResult] = []
                results.append(contentsOf: customResults.map { .custom($0) })
                results.append(contentsOf: usdaResults.map { .usda($0) })
                searchResults = results
                searchOffset = usdaResults.count
                hasMoreSearchResults = usdaResults.count >= searchPageSize
                isSearching = false
            }
        } catch {
            print("❌ Search error: \(error)")
            await MainActor.run {
                errorMessage = "Search failed: \(error.localizedDescription)"
                isSearching = false
            }
        }
    }

    private func loadMoreResults() async {
        guard !isLoadingMore, hasMoreSearchResults else { return }

        isLoadingMore = true

        do {
            let searchWords = searchText.lowercased().split(separator: " ").map(String.init)
            let pattern = searchWords.map { "%\($0)%" }.joined(separator: "")
            let exactPattern = "%\(searchText)%"

            // Load next page of USDA foods
            let usdaResults: [USDAFood] = try await supabase
                .from("usda_foods")
                .select()
                .or("description.ilike.\(exactPattern),display_name.ilike.\(exactPattern),description.ilike.\(pattern)")
                .order("description", ascending: true)
                .range(from: searchOffset, to: searchOffset + searchPageSize - 1)
                .execute()
                .value

            await MainActor.run {
                searchResults.append(contentsOf: usdaResults.map { .usda($0) })
                searchOffset += usdaResults.count
                hasMoreSearchResults = usdaResults.count >= searchPageSize
                isLoadingMore = false
            }
        } catch {
            print("❌ Load more error: \(error)")
            await MainActor.run {
                isLoadingMore = false
            }
        }
    }

    private func loadPortions(for food: USDAFood) async {
        do {
            let portions: [USDAFoodPortion] = try await supabase
                .from("usda_food_portions")
                .select()
                .eq("food_id", value: food.id.uuidString)
                .order("sequence_number")
                .execute()
                .value

            await MainActor.run {
                foodPortions = portions
                // Auto-select first portion if available
                if let first = portions.first {
                    selectedPortion = first
                    baseGrams = first.gramWeight
                    useCustomAmount = false
                    selectedQuickPortion = .full
                }
                servingMultiplier = "1"
            }
        } catch {
            await MainActor.run {
                foodPortions = []
                servingMultiplier = "1"
            }
        }
    }

    private func saveDatabaseEntry() async {
        guard let food = selectedFood else {
            print("❌ No food selected")
            errorMessage = "No food selected"
            return
        }

        guard calculatedGrams > 0 else {
            print("❌ Invalid portion: \(calculatedGrams)g")
            errorMessage = "Please enter a valid amount"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            let userId = try await supabase.auth.session.user.id
            let eventInstanceId = UUID()

            print("📝 Saving food log...")
            print("   Food: \(food.displayName)")
            print("   Grams: \(calculatedGrams)")
            print("   Meal: \(selectedMealType.rawValue)")

            var metadata: [String: AnyJSON] = [
                "portion_grams": .double(calculatedGrams),
                "entry_type": .string("database"),
                "meal_type": .string(selectedMealType.rawValue)
            ]

            switch food {
            case .usda(let usdaFood):
                metadata["usda_food_id"] = .string(usdaFood.id.uuidString)
                metadata["food_name"] = .string(usdaFood.displayName)
            case .custom(let customFood):
                metadata["custom_food_id"] = .string(customFood.id.uuidString)
                metadata["food_name"] = .string(customFood.name)
            }

            let timeString = ISO8601DateFormatter().string(from: selectedDateTime)
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

            print("📤 Inserting into patient_category_samples...")

            try await supabase
                .from("patient_category_samples")
                .insert(foodLog)
                .execute()

            print("✅ Food log saved successfully!")
            await MainActor.run { dismiss() }
        } catch {
            print("❌ Save failed: \(error)")
            print("   Error details: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }

    private func saveQuickLogEntry() async {
        guard !selectedFoodTypes.isEmpty else { return }

        isSaving = true
        errorMessage = nil

        do {
            let userId = try await supabase.auth.session.user.id
            let eventInstanceId = UUID()

            let metadata: [String: AnyJSON] = [
                "entry_type": .string("quick_log"),
                "food_types": .array(selectedFoodTypes.map { .string($0.rawValue) }),
                "meal_size": .string(selectedMealSize.rawValue),
                "meal_type": .string(selectedMealType.rawValue),
                "meal_context": .string(selectedMealContext.rawValue)
            ]

            let timeString = ISO8601DateFormatter().string(from: selectedDateTime)
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
                errorMessage = "Failed to save"
                isSaving = false
            }
        }
    }
}

// MARK: - Supporting Views

private struct FoodResultRow: View {
    let result: FoodSearchResult
    let isFavorite: Bool
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.displayName)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text(result.displayCategory)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundColor(isFavorite ? .yellow : .secondary)
                    .font(.body)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

private struct PortionRow: View {
    let title: String
    let grams: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                    Text("\(grams)g")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.green.opacity(0.08) : Color(uiColor: .systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.green.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MultiplierButton: View {
    let title: String
    var grams: Int? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let grams = grams {
                    Text("\(grams)g")
                        .font(.caption2)
                        .foregroundColor(isSelected ? .green.opacity(0.8) : .secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.green.opacity(0.1) : Color(uiColor: .systemGray6))
            .foregroundColor(isSelected ? .green : .primary)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MealTypeButton: View {
    let mealType: MealType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: mealType.icon)
                    .font(.subheadline)
                Text(mealType.displayName)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? mealType.color.opacity(0.15) : Color(uiColor: .systemGray5))
            .foregroundColor(isSelected ? mealType.color : .secondary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? mealType.color.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct NutrientPill: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title3.weight(.semibold))
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .cornerRadius(8)
    }
}

// MARK: - Nutrition Donut View (MFP-style)

private struct NutritionDonutView: View {
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
                // Background circle
                Circle()
                    .stroke(Color(uiColor: .systemGray5), lineWidth: 12)
                    .frame(width: 100, height: 100)

                // Macro segments
                DonutSegments(
                    protein: protein,
                    carbs: carbs,
                    fat: fat
                )
                .frame(width: 100, height: 100)

                // Calories in center
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
                MacroRow(
                    color: .blue,
                    name: "Carbs",
                    percent: carbsPercent,
                    grams: Int(carbs)
                )
                MacroRow(
                    color: .orange,
                    name: "Fat",
                    percent: fatPercent,
                    grams: Int(fat)
                )
                MacroRow(
                    color: .red,
                    name: "Protein",
                    percent: proteinPercent,
                    grams: Int(protein)
                )
            }
        }
        .padding()
    }
}

private struct DonutSegments: View {
    let protein: Double
    let carbs: Double
    let fat: Double

    private var total: Double {
        protein + carbs + fat
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let lineWidth: CGFloat = 12

            ZStack {
                // Carbs segment (blue)
                if total > 0 {
                    Circle()
                        .trim(from: 0, to: carbs / total)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        .rotationEffect(.degrees(-90))

                    // Fat segment (orange)
                    Circle()
                        .trim(from: carbs / total, to: (carbs + fat) / total)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        .rotationEffect(.degrees(-90))

                    // Protein segment (red)
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

private struct MacroRow: View {
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

private struct FoodTypeChip: View {
    let attribute: FoodTypeAttribute
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: attribute.icon)
                    .font(.title2)
                Text(attribute.displayName)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? attribute.color.opacity(0.12) : Color(uiColor: .systemGray6))
            .foregroundColor(isSelected ? attribute.color : .primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? attribute.color.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MealSizeChip: View {
    let size: MealSize
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(size.displayName)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.green.opacity(0.12) : Color(uiColor: .systemGray6))
                .foregroundColor(isSelected ? .green : .primary)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct MealTypeChip: View {
    let mealType: MealType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: mealType.icon)
                    .font(.title3)
                Text(mealType.displayName)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? mealType.color.opacity(0.12) : Color(uiColor: .systemGray6))
            .foregroundColor(isSelected ? mealType.color : .primary)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? mealType.color.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MealContextChip: View {
    let context: MealContext
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: context.icon)
                    .font(.caption)
                Text(context.displayName)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? context.color.opacity(0.12) : Color(uiColor: .systemGray6))
            .foregroundColor(isSelected ? context.color : .primary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? context.color.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Log Info Item

private struct QuickLogInfoItem: View {
    let icon: String
    let label: String

    // Nutrition pillar color
    private let nutritionColor = Color(hex: "#8DD8FF") ?? .blue

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(nutritionColor)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    FoodEntryView()
}
