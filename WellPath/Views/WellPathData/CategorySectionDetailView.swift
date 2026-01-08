//
//  CategorySectionDetailView.swift
//  WellPath
//
//  Detail view for a category section (e.g., Nutrition, Sleep)
//  Shows card categories within the section with scrollable bottom nav
//

import SwiftUI

struct CategorySectionDetailView: View {
    let initialSection: CategorySectionConfig
    @State private var currentSection: CategorySectionConfig
    @ObservedObject private var displayConfig = DisplayConfigurationService.shared
    @StateObject private var biomarkerViewModel = BiomarkerViewModel()
    @State private var isSearchActive = false
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    /// Check if current section is biomarkers
    private var isBiomarkerSection: Bool {
        currentSection.sectionId == "NAV_BIOMARKERS"
    }

    init(section: CategorySectionConfig) {
        self.initialSection = section
        _currentSection = State(initialValue: section)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top nav bar (below navigation title)
            if isSearchActive {
                TopCategorySearchBar(
                    currentSection: currentSection,
                    searchText: $searchText,
                    isSearchActive: $isSearchActive
                )
            } else {
                TopCategoryNavBar(
                    currentSection: $currentSection,
                    allSections: siblingsSections,
                    isSearchActive: $isSearchActive,
                    searchText: $searchText
                )
            }

            // Content
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Show search results when searching
                    if !searchText.isEmpty {
                        // For biomarker section, ONLY show biomarker results (not ViewCards which duplicate)
                        if isBiomarkerSection {
                            if !filteredBiomarkers.isEmpty {
                                ForEach(filteredBiomarkers) { biomarker in
                                    BiomarkerCard(
                                        biomarker: biomarker,
                                        sectionColor: currentSection.color,
                                        sectionId: currentSection.sectionId,
                                        viewModel: biomarkerViewModel
                                    )
                                }
                            }
                        } else {
                            // For non-biomarker sections, show card search results
                            if !searchedViewCards.isEmpty {
                                ForEach(searchedViewCards) { card in
                                    ViewCardSearchResult(card: card, sectionColor: currentSection.color)
                                }
                            }
                        }

                        // Empty state if no results
                        let hasResults = isBiomarkerSection ? !filteredBiomarkers.isEmpty : !searchedViewCards.isEmpty
                        if !hasResults && filteredCategories.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary.opacity(0.5))
                                Text("No results for \"\(searchText)\"")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        }
                    } else {
                        // Show categories when not searching
                        ForEach(cardCategories) { category in
                            NavigationLink {
                                CategoryDetailView(category: category, sectionColor: currentSection.color)
                            } label: {
                                CardCategoryCard(category: category, sectionColor: currentSection.color)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .wellPathAmbientBackground(color: currentSection.color)
        .navigationTitle(currentSection.sectionName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            // Load biomarker data if on biomarker section
            if isBiomarkerSection {
                await biomarkerViewModel.loadAll()
            }
        }
    }

    private var cardCategories: [CardCategoryConfig] {
        displayConfig.cardCategories(forSection: currentSection.sectionId)
    }

    private var filteredCategories: [CardCategoryConfig] {
        guard !searchText.isEmpty else { return cardCategories }
        return cardCategories.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    /// Get all sibling sections under the same header for the scrollable nav
    private var siblingsSections: [CategorySectionConfig] {
        displayConfig.categorySections(for: currentSection.headerId)
    }

    /// All biomarkers flattened for search (only used when isBiomarkerSection)
    private var allBiomarkers: [BiomarkerDisplayData] {
        biomarkerViewModel.categories.flatMap { biomarkerViewModel.biomarkers(for: $0.categoryId) }
    }

    /// Filtered biomarkers based on search text
    private var filteredBiomarkers: [BiomarkerDisplayData] {
        guard !searchText.isEmpty else { return [] }
        return allBiomarkers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Search view cards by name
    private var searchedViewCards: [ViewCardConfig] {
        displayConfig.searchViewCards(query: searchText)
    }
}

// MARK: - View Card Search Result (Oura-style card for search results)

struct ViewCardSearchResult: View {
    let card: ViewCardConfig
    let sectionColor: Color
    @ObservedObject private var displayConfig = DisplayConfigurationService.shared

    /// Get the icon for this card from its category
    private var cardIcon: String {
        guard let categoryId = card.categoryId else { return "doc" }
        return displayConfig.cardCategoryIcon(for: categoryId)
    }

    /// Get color from category
    private var cardColor: Color {
        guard let categoryId = card.categoryId else { return sectionColor }
        return displayConfig.cardCategoryColor(for: categoryId)
    }

    var body: some View {
        NavigationLink {
            // Route to the appropriate screen using CardRegistry
            CardRegistry.destination(
                for: card.cardId,
                color: cardColor,
                pillar: "",
                sectionId: card.categoryId
            )
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Top row: Icon + Name
                HStack(alignment: .top) {
                    // Icon in circle
                    Image(systemName: cardIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(cardColor)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(cardColor.opacity(0.2))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.cardName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text("Tap to view")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }

                // Description if available
                if let description = card.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                cardColor.opacity(0.25),
                                cardColor.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(cardColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Card Category Card (Oura-style full gradient)

struct CardCategoryCard: View {
    let category: CardCategoryConfig
    let sectionColor: Color
    var score: Int? = nil  // Optional score (0-100)
    @ObservedObject private var displayConfig = DisplayConfigurationService.shared

    private var scoreLabel: String {
        guard let score = score else { return "NOT SCORED" }
        switch score {
        case 90...100: return "OPTIMAL"
        case 75..<90: return "GOOD"
        case 50..<75: return "FAIR"
        case 25..<50: return "NEEDS WORK"
        default: return "LOW"
        }
    }

    private var scoreLabelColor: Color {
        guard let score = score else { return .secondary }
        switch score {
        case 90...100: return .green
        case 75..<90: return .blue
        case 50..<75: return .yellow
        case 25..<50: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: Icon + Name + Score pill
            HStack(alignment: .top) {
                // Icon (small circle with subtle color)
                Image(systemName: categoryIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(sectionColor)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(sectionColor.opacity(0.2))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    // Category name
                    Text(category.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    // Score label
                    Text(scoreLabel)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(score != nil ? scoreLabelColor : .secondary)
                }

                Spacer()

                // Score ring (right side)
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 3)
                        .frame(width: 44, height: 44)

                    // Progress ring
                    if let score = score {
                        Circle()
                            .trim(from: 0, to: Double(score) / 100.0)
                            .stroke(
                                scoreLabelColor,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 44, height: 44)
                    }

                    // Score text
                    Text(score != nil ? "\(score!)" : "--")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }

            // Description at bottom
            if let overview = category.overview {
                Text(overview)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            sectionColor.opacity(0.25),
                            sectionColor.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(sectionColor.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var categoryIcon: String {
        displayConfig.cardCategoryIcon(for: category.categoryId)
    }
}

// MARK: - Top Category Nav Bar (Oura-style at top)

struct TopCategoryNavBar: View {
    @Binding var currentSection: CategorySectionConfig
    let allSections: [CategorySectionConfig]
    @Binding var isSearchActive: Bool
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 12) {
            // Section icons (scrollable if needed)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(allSections) { section in
                        TopSectionNavIcon(
                            section: section,
                            isSelected: currentSection.sectionId == section.sectionId
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentSection = section
                                searchText = ""
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }

            // Search button
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isSearchActive = true
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Top Section Nav Icon

struct TopSectionNavIcon: View {
    let section: CategorySectionConfig
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: section.icon)
                    .font(.system(size: 14, weight: .medium))

                if isSelected {
                    Text(section.sectionName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
            }
            .foregroundColor(isSelected ? section.color : .secondary)
            .padding(.horizontal, isSelected ? 12 : 10)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? section.color.opacity(0.25) : Color.clear)
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? section.color.opacity(0.4) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Top Category Search Bar

struct TopCategorySearchBar: View {
    let currentSection: CategorySectionConfig
    @Binding var searchText: String
    @Binding var isSearchActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Current section icon (tap to exit search)
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isSearchActive = false
                    searchText = ""
                }
            } label: {
                Image(systemName: currentSection.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(currentSection.color)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(currentSection.color.opacity(0.15))
                    )
            }

            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search \(currentSection.sectionName)...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(WellPathColors.cardBackground)
            )

            // Cancel button
            Button("Cancel") {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isSearchActive = false
                    searchText = ""
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Compact Section Nav Icon (fits without scrolling)

struct CompactSectionNavIcon: View {
    let section: CategorySectionConfig
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: section.icon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? section.color : .secondary)
                    .frame(width: 36, height: 24)

                // Underline indicator
                Rectangle()
                    .fill(isSelected ? section.color : Color.clear)
                    .frame(width: 18, height: 2)
                    .cornerRadius(1)
            }
            .frame(minWidth: 44, minHeight: 44) // Minimum tap target
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Collapsed Category Search Bar

struct CollapsedCategorySearchBar: View {
    let currentSection: CategorySectionConfig
    @Binding var searchText: String
    @Binding var isSearchActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Collapsed section icon (tap to exit search)
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isSearchActive = false
                    searchText = ""
                }
            } label: {
                Image(systemName: currentSection.icon)
                    .font(.title3)
                    .foregroundColor(currentSection.color)
                    .frame(width: 50, height: 50)
            }
            .background(collapsedBackground)

            // Expanded search field
            searchField
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search \(currentSection.sectionName)...", text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }

            // Cancel/close button
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isSearchActive = false
                    searchText = ""
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(searchFieldBackground)
    }

    @ViewBuilder
    private var collapsedBackground: some View {
        if #available(iOS 26, *) {
            RoundedRectangle(cornerRadius: 16)
                .fill(.clear)
                .glassEffect()
        } else {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private var searchFieldBackground: some View {
        if #available(iOS 26, *) {
            Capsule()
                .fill(.clear)
                .glassEffect()
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
        }
    }
}

// MARK: - Category Detail View - Routes to actual *Screen views

struct CategoryDetailView: View {
    let category: CardCategoryConfig
    let sectionColor: Color
    @ObservedObject private var displayConfig = DisplayConfigurationService.shared

    var body: some View {
        // 1. Check if category has subcategories (e.g., CAT_SUBSTANCES → Alcohol, Tobacco, etc.)
        if displayConfig.hasSubcategories(categoryId: category.categoryId) {
            CategorySubcategoriesView(parentCategory: category, sectionColor: sectionColor)
        }
        // 2. Otherwise route to the specific screen via the router
        // The router handles categories with dedicated *Screen views (Protein, Sleep, etc.)
        // AND categories that need cards list (Therapeutics)
        else {
            CategoryScreenRouter.destinationView(
                for: category.categoryId,
                pillar: category.pillar ?? "",
                color: sectionColor,
                sectionId: category.sectionId ?? ""
            )
        }
    }
}

// MARK: - Category Subcategories View (for categories with child categories)

struct CategorySubcategoriesView: View {
    let parentCategory: CardCategoryConfig
    let sectionColor: Color
    @ObservedObject private var displayConfig = DisplayConfigurationService.shared

    private var subcategories: [CardCategoryConfig] {
        displayConfig.subcategories(forCategory: parentCategory.categoryId)
    }

    private var color: Color {
        displayConfig.cardCategoryColor(for: parentCategory.categoryId)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if subcategories.isEmpty {
                    emptyState
                } else {
                    ForEach(subcategories) { subcategory in
                        NavigationLink {
                            CategoryDetailView(category: subcategory, sectionColor: sectionColor)
                        } label: {
                            CategorySubcategoryCard(category: subcategory, color: color)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .wellPathAmbientBackground(color: color)
        .navigationTitle(parentCategory.name)
        .navigationBarTitleDisplayMode(.large)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: parentCategory.iconName ?? "folder")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No subcategories available")
                .font(.headline)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Category Subcategory Card

struct CategorySubcategoryCard: View {
    let category: CardCategoryConfig
    let color: Color
    @ObservedObject private var displayConfig = DisplayConfigurationService.shared

    private var cardCount: Int {
        displayConfig.viewCards(forCategory: category.categoryId).count
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: category.iconName ?? "folder")
                    .font(.title2)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                if let overview = category.overview {
                    Text(overview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else if cardCount > 0 {
                    Text("\(cardCount) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Simple Category Cards List View (for categories with multiple view cards)
// Note: Named "Simple" to avoid conflict with CategoryCardsListView in WellPathDataListView.swift

struct SimpleCategoryCardsListView: View {
    let category: CardCategoryConfig
    let sectionColor: Color
    @ObservedObject private var displayConfig = DisplayConfigurationService.shared

    private var cards: [ViewCardConfig] {
        displayConfig.viewCards(forCategory: category.categoryId)
    }

    private var color: Color {
        displayConfig.cardCategoryColor(for: category.categoryId)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if cards.isEmpty {
                    emptyState
                } else {
                    ForEach(cards) { card in
                        if let viewId = card.viewId,
                           let viewConfig = displayConfig.view(id: viewId) {
                            NavigationLink {
                                ViewRouter.viewForViewId(viewConfig, color: color, sectionId: category.sectionId ?? "")
                            } label: {
                                SimpleCategoryViewCardRow(card: card, color: color)
                            }
                            .buttonStyle(.plain)
                        } else {
                            // Card without view_id - show placeholder
                            SimpleCategoryViewCardRow(card: card, color: color)
                                .opacity(0.5)
                        }
                    }
                }
            }
            .padding()
        }
        .wellPathAmbientBackground(color: color)
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.large)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: category.iconName ?? "chart.bar.fill")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No data available")
                .font(.headline)
            Text("Start tracking to see your data here")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Simple Category View Card Row

struct SimpleCategoryViewCardRow: View {
    let card: ViewCardConfig
    let color: Color
    @ObservedObject private var displayConfig = DisplayConfigurationService.shared

    /// Get icon from the associated view config
    private var iconName: String {
        if let viewId = card.viewId,
           let viewConfig = displayConfig.view(id: viewId) {
            return viewConfig.iconName ?? "chart.bar.fill"
        }
        return "chart.bar.fill"
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(card.cardName)
                    .font(.headline)
                    .foregroundColor(.primary)

                if let desc = card.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Category Screen Router

/// Routes category IDs to their actual *Screen.swift views
enum CategoryScreenRouter {
    @ViewBuilder
    static func destinationView(for categoryId: String, pillar: String, color: Color, sectionId: String) -> some View {
        switch categoryId {
        // MARK: - Nutrition
        case "CAT_PROTEIN":
            ProteinScreen(pillar: pillar, color: color)
        case "CAT_FATS":
            FatsScreen(pillar: pillar, color: color)
        case "CAT_FIBER":
            FiberScreen(pillar: pillar, color: color)
        case "CAT_FRUITS":
            FruitsScreen(pillar: pillar, color: color)
        case "CAT_VEGETABLES":
            VegetablesScreen(pillar: pillar, color: color)
        case "CAT_LEGUMES":
            LegumesScreen(pillar: pillar, color: color)
        case "CAT_WHOLE_GRAINS":
            WholeGrainsScreen(pillar: pillar, color: color)
        case "CAT_HYDRATION", "CAT_WATER":
            WaterScreen(pillar: pillar, color: color)
        case "CAT_CAFFEINE":
            CaffeineScreen(pillar: pillar, color: color)
        case "CAT_MEAL_PATTERNS":
            MealPatternsScreen(pillar: pillar, color: color)
        case "CAT_NUTS_SEEDS":
            NutsSeedsScreen(pillar: pillar, color: color)
        case "CAT_ULTRA_PROCESSED":
            UltraProcessedScreen(pillar: pillar, color: color)

        // MARK: - Sleep
        case "CAT_SLEEP_ANALYSIS":
            SleepAnalysisScreen(pillar: pillar, color: color)
        case "CAT_SLEEP_SCORE":
            SleepScoreScreen(pillar: pillar, color: color)
        case "CAT_SLEEP", "CAT_SLEEP_DURATION":
            SleepDurationScreen(pillar: pillar, color: color)
        case "CAT_SLEEP_CONSISTENCY":
            SleepConsistencyScreen(pillar: pillar, color: color)
        case "CAT_SLEEP_ROUTINE":
            SleepRoutineScreen(pillar: pillar, color: color)
        case "CAT_SLEEP_ENVIRONMENT":
            SleepEnvironmentScreen(pillar: pillar, color: color)

        // MARK: - Movement
        case "CAT_STEPS":
            StepsScreen(pillar: pillar, color: color, sectionId: sectionId)
        case "CAT_CARDIO":
            CardioScreen(pillar: pillar, color: color, sectionId: sectionId)
        case "CAT_STRENGTH":
            StrengthScreen(pillar: pillar, color: color, sectionId: sectionId)
        case "CAT_HIIT":
            HIITScreen(pillar: pillar, color: color, sectionId: sectionId)
        case "CAT_MOBILITY":
            MobilityScreen(pillar: pillar, color: color, sectionId: sectionId)
        case "CAT_DAILY_ACTIVITY":
            DailyActivityScreen(pillar: pillar, color: color, sectionId: sectionId)

        // MARK: - Stress Management
        case "CAT_MINDFULNESS":
            MindfulnessScreen(pillar: pillar, color: color, sectionId: sectionId)
        case "CAT_STRESS", "CAT_STRESS_LEVEL":
            StressLevelScreen(pillar: pillar, color: color)
        case "CAT_STRESS_DIRECT":  // Keep direct route for internal use
            AssessmentScreenTemplate(
                assessmentId: "ASSESS_STRESS_LEVEL",
                color: color,
                viewId: "DISP_STRESS",
                sectionId: sectionId
            )

        // MARK: - Cognitive
        case "CAT_COGNITIVE_ACTIVITIES", "CAT_BRAIN_TRAINING":
            CognitiveScreen(pillar: pillar, color: color, sectionId: sectionId)

        // MARK: - Connection
        case "CAT_SOCIAL", "CAT_SOCIAL_CONNECTIONS":
            SocialScreen(pillar: pillar, color: color, sectionId: sectionId)
        case "CAT_OUTDOOR_TIME":
            OutdoorTimeScreen(pillar: pillar, color: color, sectionId: sectionId)

        // MARK: - Biometrics (route to category screens)
        case "CAT_BIOMETRICS_BODY_COMP":
            BiometricCategoryScreen(
                category: .bodyComposition,
                pillar: pillar,
                color: color
            )
        case "CAT_BIOMETRICS_VITALS":
            BiometricCategoryScreen(
                category: .vitals,
                pillar: pillar,
                color: color
            )
        case "CAT_FITNESS_METRICS":
            BiometricCategoryScreen(
                category: .fitnessMetrics,
                pillar: pillar,
                color: color
            )

        // MARK: - Biomarkers (route directly to category - no extra navigation level)
        case "CAT_BIOMARKER_CARDIO", "CAT_BIOMARKER_METABOLISM", "CAT_BIOMARKER_INFLAMMATION",
             "CAT_BIOMARKER_IMMUNE_RENAL", "CAT_BIOMARKER_HORMONES", "CAT_BIOMARKER_COGNITION",
             "CAT_BIOMARKER_RECOVERY", "CAT_BIOMARKER_ENDURANCE", "CAT_BIOMARKER_FITNESS",
             "CAT_BIOMARKER_SLEEP":
            BiomarkerCategoryScreen(categoryId: categoryId, pillar: pillar, color: color)

        // MARK: - Biological Age
        case "CAT_TRUDIAGNOSTIC", "CAT_PHENOAGE":
            BiologicalAgeScreen(pillar: pillar, color: color)

        // MARK: - Substances (placeholder until substance screens are built)
        case "CAT_ALCOHOL", "CAT_TOBACCO", "CAT_NICOTINE", "CAT_CANNABIS":
            CategoryPlaceholderView(categoryId: categoryId, color: color)

        // MARK: - Mental Health
        case "CAT_WELLBEING":
            WellbeingScreen(pillar: pillar, color: color)
        case "CAT_ANXIETY":
            AnxietyScreen(pillar: pillar, color: color)
        case "CAT_DEPRESSION":
            DepressionScreen(pillar: pillar, color: color)

        // MARK: - Health Records / Core Care
        // CAT_THERAPEUTICS shows the full therapeutics screen with proper toolbar and cards
        case "CAT_THERAPEUTICS":
            TherapeuticsScreen(color: color)
        // Individual therapeutics cards route directly to their views
        case "CAT_SUPPLEMENTS":
            TherapeuticsExploreView(therapeuticType: .supplement)
        case "CAT_MEDICATIONS":
            TherapeuticsExploreView(therapeuticType: .medication)
        case "CAT_PEPTIDES":
            TherapeuticsExploreView(therapeuticType: .peptide)
        case "CAT_HORMONES":
            TherapeuticsExploreView(therapeuticType: .hormone)
        case "CAT_PERSONAL_HISTORY":
            PersonalHistoryView(viewModel: MedicalHistoryViewModel(), color: color)
        case "CAT_FAMILY_HISTORY":
            FamilyHistoryView(viewModel: MedicalHistoryViewModel(), color: color)
        case "CAT_MEDICAL_HISTORY":
            MedicalHistoryEntryView(color: color)
        case "CAT_SCREENINGS":
            ScreeningsListView()

        // Default fallback
        default:
            CategoryPlaceholderView(categoryId: categoryId, color: color)
        }
    }
}

// MARK: - Therapeutics Cards List View
// Shows cards for CAT_THERAPEUTICS category using standard card styling

struct TherapeuticsCardsListView: View {
    let color: Color
    @ObservedObject private var displayConfig = DisplayConfigurationService.shared

    private var cards: [ViewCardConfig] {
        displayConfig.viewCards(forCategory: "CAT_THERAPEUTICS")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(cards) { card in
                    if let viewId = card.viewId,
                       let viewConfig = displayConfig.view(id: viewId) {
                        NavigationLink {
                            ViewRouter.viewForViewId(viewConfig, color: color, sectionId: "NAV_CORE_CARE")
                        } label: {
                            TherapeuticsCardRow(card: card, viewConfig: viewConfig, color: color)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .wellPathAmbientBackground(color: color)
        .navigationTitle("Therapeutics")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Therapeutics Card Row (standard card styling without score ring)

struct TherapeuticsCardRow: View {
    let card: ViewCardConfig
    let viewConfig: ViewConfig
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                // Icon
                Image(systemName: viewConfig.iconName ?? "pills.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(color.opacity(0.2))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(card.cardName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                Spacer()

                // Chevron (no score ring for therapeutics)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            // Description
            if let description = card.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Category Placeholder (for unimplemented categories)

struct CategoryPlaceholderView: View {
    let categoryId: String
    let color: Color

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(color.opacity(0.5))

            Text("Coming Soon")
                .font(.title2)
                .fontWeight(.semibold)

            Text("This category is being developed")
                .font(.body)
                .foregroundColor(.secondary)

            Text(categoryId)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WellPathColors.backgroundBase)
        .navigationTitle("Coming Soon")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - View Card Row

struct ViewCardRow: View {
    let card: ViewCardConfig
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "chart.bar.fill")
                    .font(.title3)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(card.cardName)
                    .font(.body)
                    .foregroundColor(.primary)

                if let description = card.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(WellPathColors.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Metric View Placeholder

struct MetricViewPlaceholder: View {
    let card: ViewCardConfig
    let color: Color

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 60))
                .foregroundColor(color.opacity(0.5))

            Text(card.cardName)
                .font(.title2)
                .fontWeight(.semibold)

            if let description = card.description {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text("Connect to actual view")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WellPathColors.backgroundBase)
        .navigationTitle(card.cardName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CategorySectionDetailView(
            section: CategorySectionConfig(
                id: UUID(),
                sectionId: "SEC_NUTRITION",
                sectionName: "Healthful Nutrition",
                headerId: "HDR_HEALTH_PILLARS",
                description: "Track your nutrition intake",
                iconName: "fork.knife",
                colorHex: "#4CAF50",
                displayOrder: 1,
                isActive: true
            )
        )
    }
}
