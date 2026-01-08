//
//  TrackedMetricsListView.swift
//  WellPath
//
//  Created on 2025-10-22
//  Updated 2025-12-01: Removed hardcoded registries - now database-driven via chart_type_id
//

import SwiftUI

// MARK: - Database-Driven Navigation
// All routing now handled by:
// - CategoryCardsListView → shows categories for a section
// - ViewCardsListView → shows cards for a category
// - ChartTypeRouter → renders views based on chart_type_id

/// Metric detail view that loads by viewId
struct MetricDetailByIdView: View {
    let viewId: String
    let pillar: String
    let color: Color
    @StateObject private var viewModel: StandardMetricViewModel

    init(viewId: String, pillar: String, color: Color) {
        self.viewId = viewId
        self.pillar = pillar
        self.color = color
        _viewModel = StateObject(wrappedValue: StandardMetricViewModel(metricId: viewId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let metric = viewModel.displayMetric {
                ParentMetricBarChart(metric: metric, color: color, showAbout: .constant(false))
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No data available")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await viewModel.loadPrimaryScreen()
        }
    }
}

// MARK: - Mini Card (Generic, Database-Driven)

/// Generic mini card that displays today's value and weekly average
struct GenericMiniCard: View {
    let viewId: String
    let color: Color
    let displayName: String?
    @StateObject private var viewModel: StandardMetricViewModel

    init(viewId: String, color: Color, displayName: String? = nil) {
        self.viewId = viewId
        self.color = color
        self.displayName = displayName
        _viewModel = StateObject(wrappedValue: StandardMetricViewModel(metricId: viewId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(height: 50)
            } else if viewModel.todayValue != nil || viewModel.weeklyAverageValue != nil {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(viewModel.todayValue.map { String(format: "%.1f", $0) } ?? "--")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Text(viewModel.displayUnit)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Weekly Avg")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(viewModel.weeklyAverageValue.map { String(format: "%.1f", $0) } ?? "--")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(color)
                            Text(viewModel.displayUnit)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                // No data state - show icon and name
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 20))
                        .foregroundColor(color.opacity(0.6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName ?? "Metric")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Tap to view")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(height: 50)
            }
        }
        .task {
            await viewModel.loadPrimaryScreen()
        }
    }
}

struct TrackedMetricsListView: View {
    @StateObject private var viewModel = TrackedMetricsViewModel()
    @StateObject private var favoritesService = FavoritesService.shared
    @EnvironmentObject private var displayConfig: DisplayConfigurationService
    @EnvironmentObject private var searchState: WellPathDataSearchState
    @State private var selectedCategory: DataCategory = .favorites
    @State private var localSearchText = ""
    @State private var isLocalSearchActive = false
    @FocusState private var isSearchFocused: Bool

    /// Backwards compatibility - favorites shown when category is .favorites
    private var showingFavorites: Bool {
        selectedCategory == .favorites && !isLocalSearchActive
    }

    var body: some View {
        mainContent
            .background(backgroundView)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Data")
                        .font(.headline)
                        .fontWeight(.semibold)
                }

                // Search button on right
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation {
                            isLocalSearchActive.toggle()
                            if isLocalSearchActive {
                                searchState.activateSearch()
                            } else {
                                searchState.deactivateSearch()
                                localSearchText = ""
                            }
                        }
                    } label: {
                        Image(systemName: isLocalSearchActive ? "xmark" : "magnifyingglass")
                    }
                }
            }
            .onChange(of: localSearchText) { _, newValue in
                searchState.searchText = newValue
            }
            .task {
                await viewModel.loadMetricsData()
                await favoritesService.loadFavorites()
            }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Category Pills (Oura-style at top)
            if !isLocalSearchActive {
                categoryPillsBar
            }

            if viewModel.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error {
                errorView(error)
            } else if showingFavorites {
                favoritesView
            } else {
                browseView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Category Pills Bar

    private var categoryPillsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DataCategory.allCases, id: \.rawValue) { category in
                    CategoryPill(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(WellPathColors.backgroundBase)
    }

    // MARK: - Favorites View (grouped by pillar)

    /// Maps pillar names to section IDs for database lookup
    private func sectionIdForPillar(_ pillar: String) -> String? {
        switch pillar {
        case "Biomarker": return "NAV_BIOMARKERS"
        case "Biometrics": return "NAV_BIOMETRICS"
        default: return nil
        }
    }

    /// Gets color for a pillar/section - tries section first, then pillar
    private func colorForPillar(_ pillar: String) -> Color {
        if let sectionId = sectionIdForPillar(pillar) {
            return displayConfig.categorySectionColor(for: sectionId)
        }
        return displayConfig.pillarColor(for: pillar)
    }

    /// Gets icon for a pillar/section - tries section first, then pillar
    private func iconForPillar(_ pillar: String) -> String {
        if let sectionId = sectionIdForPillar(pillar) {
            return displayConfig.categorySectionIcon(for: sectionId)
        }
        return displayConfig.pillarIcon(for: pillar)
    }

    private var favoritesView: some View {
        ScrollView {
            VStack(spacing: 20) {
                if favoritesService.favorites.isEmpty {
                    emptyFavoritesPrompt
                } else {
                    // Group favorites by section (sectionId from database)
                    ForEach(favoritesByPillar, id: \.pillar) { group in
                        // Use sectionId from the group if available, otherwise derive from pillar
                        let groupSectionId = group.sectionId ?? sectionIdForPillar(group.pillar)
                        let groupColor = groupSectionId.map { displayConfig.categorySectionColor(for: $0) } ?? colorForPillar(group.pillar)
                        let groupIcon = groupSectionId.map { displayConfig.categorySectionIcon(for: $0) } ?? iconForPillar(group.pillar)

                        VStack(alignment: .leading, spacing: 8) {
                            // Pillar header - uses database colors/icons
                            HStack(spacing: 8) {
                                Image(systemName: groupIcon)
                                    .foregroundColor(groupColor)
                                Text(group.pillar)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 4)

                            // Separate card-based favorites from others
                            // Includes: metric, biometric, biomarker, and screen types that have cardId
                            let cardFavorites = group.favorites.filter {
                                $0.itemType == "metric" ||
                                $0.itemType == "biometric" ||
                                $0.itemType == "biomarker" ||
                                ($0.itemType == "screen" && $0.cardId != nil)
                            }
                            let otherFavorites = group.favorites.filter {
                                !($0.itemType == "metric" ||
                                  $0.itemType == "biometric" ||
                                  $0.itemType == "biomarker" ||
                                  ($0.itemType == "screen" && $0.cardId != nil))
                            }

                            // Card-based favorites - use CardRegistry for consistent cards
                            if !cardFavorites.isEmpty {
                                VStack(spacing: 12) {
                                    ForEach(cardFavorites) { favorite in
                                        // Use sectionId from favorite if available, otherwise derive from pillar
                                        let sectionId = favorite.sectionId ?? groupSectionId
                                        let cardColor = sectionId.map { displayConfig.categorySectionColor(for: $0) } ?? groupColor

                                        // For screen types, use cardId for routing; otherwise use itemId
                                        let cardLookupId = (favorite.itemType == "screen" ? favorite.cardId : nil) ?? favorite.itemId

                                        CardRegistry.card(
                                            for: cardLookupId,
                                            color: cardColor,
                                            pillar: favorite.pillar ?? "Core Care",
                                            displayName: favorite.displayName,
                                            sectionId: sectionId
                                        )
                                    }
                                }
                            }

                            // Other favorites (screens, etc.) as simple rows
                            if !otherFavorites.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(Array(otherFavorites.enumerated()), id: \.element.id) { index, favorite in
                                        NavigationLink(destination: favoriteDestination(for: favorite)) {
                                            FavoriteRow(favorite: favorite)
                                        }
                                        .buttonStyle(PlainButtonStyle())

                                        if index < otherFavorites.count - 1 {
                                            Divider()
                                                .padding(.horizontal, 16)
                                        }
                                    }
                                }
                                .background(WellPathColors.cardBackground)
                                .cornerRadius(12)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    private var emptyFavoritesPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.fill")
                .font(.system(size: 48))
                .foregroundColor(.yellow.opacity(0.7))

            Text("No Favorites Yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Pin your most-used metrics for quick access.\nTap the star on any metric to add it here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                withAnimation {
                    selectedCategory = .pillars
                }
            } label: {
                Text("Browse Pillars")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(10)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Browse View (Database-driven navigation)

    /// Filter section headers based on selected category
    private var filteredSectionHeaders: [SectionHeaderConfig] {
        let headerIds = selectedCategory.headerIds
        if headerIds.isEmpty {
            return [] // Favorites doesn't use headers
        }
        return displayConfig.sectionHeaders.filter { header in
            headerIds.contains(header.headerId)
        }
    }

    private var browseView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Show search results if searching
                if !localSearchText.isEmpty && isLocalSearchActive {
                    searchResultsContent
                } else {
                    // Database-driven navigation sections filtered by category
                    ForEach(filteredSectionHeaders) { header in
                        sectionView(for: header)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Section View (renders category sections under a header)

    @ViewBuilder
    private func sectionView(for header: SectionHeaderConfig) -> some View {
        let sections = displayConfig.categorySections(for: header.headerId)

        VStack(alignment: .leading, spacing: 8) {
            // Section header
            Text(header.headerName)
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                    NavigationLink(destination: sectionDestination(for: section)) {
                        CategorySectionRow(section: section)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if index < sections.count - 1 {
                        Divider()
                            .padding(.horizontal, 12)
                    }
                }
            }
            .background(WellPathColors.cardBackground)
            .cornerRadius(12)
        }
    }

    // MARK: - Section Destination Router

    @ViewBuilder
    private func sectionDestination(for section: CategorySectionConfig) -> some View {
        let color = section.color

        // Route based on section_id - maps to appropriate list/screen views
        switch section.sectionId {
        // Health Pillars - show categories with their cards
        case "NAV_NUTRITION", "NAV_MOVEMENT", "NAV_SLEEP", "NAV_STRESS", "NAV_COGNITION", "NAV_CONNECTION", "NAV_CORE_CARE":
            CategoryCardsListView(section: section)

        // Markers & Metrics - route to category cards first
        case "NAV_BIOMARKERS":
            BiomarkerSectionView()
        case "NAV_BIOMETRICS":
            // Show categories (Body Composition, Vitals, Strength) as cards first
            CategoryCardsListView(section: section)
        case "NAV_BIO_AGE":
            BiologicalAgeScreen(pillar: section.sectionName, color: color)

        // Legacy sections (now inactive - categories moved to Core Care)
        case "NAV_SUBSTANCES", "NAV_MENTAL_HEALTH":
            CategoryCardsListView(section: section)
        case "NAV_THERAPEUTICS":
            TherapeuticsEntryView()
        case "NAV_HEALTH_HISTORY":
            ConditionsListView()
        case "NAV_SCREENINGS":
            ScreeningsListView()

        default:
            // Fallback - show categories list
            CategoryCardsListView(section: section)
        }
    }

    // MARK: - Search Results Content

    @ViewBuilder
    private var searchResultsContent: some View {
        if allMatchingCards.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No results for \"\(searchState.searchText)\"")
                    .font(.headline)
                Text("Try searching for a different term")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 80)
        } else {
            // Show matching cards as actual card components (flat list, no section groupings)
            VStack(spacing: 12) {
                ForEach(allMatchingCards) { card in
                    let color = cardColor(for: card)
                    DatabaseDrivenCard(card: card, color: color)
                }
            }
        }
    }

    /// Get the color for a card based on its category/section
    private func cardColor(for card: ViewCardConfig) -> Color {
        if let categoryId = card.categoryId,
           let category = displayConfig.cardCategory(id: categoryId),
           let sectionId = category.sectionId {
            return displayConfig.categorySectionColor(for: sectionId)
        }
        return .gray
    }

    // Destination for card search results
    @ViewBuilder
    private func cardSearchDestination(for card: ViewCardConfig, color: Color, sectionId: String?) -> some View {
        if let viewId = card.viewId,
           let viewConfig = displayConfig.view(id: viewId) {
            ViewRouter.viewForViewId(viewConfig, color: color, sectionId: sectionId)
        } else {
            // Fallback
            Text("View not found for \(card.cardName)")
                .foregroundColor(.secondary)
        }
    }

    // All cards matching search (searches viewCards from displayConfig)
    private var allMatchingCards: [ViewCardConfig] {
        guard !searchState.searchText.isEmpty else { return [] }
        return displayConfig.viewCards.filter { card in
            card.cardName.localizedCaseInsensitiveContains(searchState.searchText) ||
            (card.description?.localizedCaseInsensitiveContains(searchState.searchText) ?? false)
        }
    }

    // Card search results grouped by category/section
    private var cardSearchResultsBySection: [(sectionName: String, sectionId: String?, color: Color, cards: [ViewCardConfig])] {
        guard !searchState.searchText.isEmpty else { return [] }

        var grouped: [String: (sectionId: String?, color: Color, cards: [ViewCardConfig])] = [:]

        for card in allMatchingCards {
            // Get the category for this card
            if let categoryId = card.categoryId,
               let category = displayConfig.cardCategory(id: categoryId) {
                let sectionId = category.sectionId
                let sectionName = sectionId.flatMap { displayConfig.categorySectionName(for: $0) } ?? category.name
                let color = sectionId.map { displayConfig.categorySectionColor(for: $0) } ?? .gray

                if grouped[sectionName] == nil {
                    grouped[sectionName] = (sectionId: sectionId, color: color, cards: [])
                }
                grouped[sectionName]?.cards.append(card)
            } else {
                // Fallback for cards without category
                let sectionName = "Other"
                if grouped[sectionName] == nil {
                    grouped[sectionName] = (sectionId: nil, color: .gray, cards: [])
                }
                grouped[sectionName]?.cards.append(card)
            }
        }

        // Convert to array and sort by section name
        return grouped.sorted { lhs, rhs in
            if lhs.key == "Other" { return false }
            if rhs.key == "Other" { return true }
            return lhs.key < rhs.key
        }.map { (sectionName: $0.key, sectionId: $0.value.sectionId, color: $0.value.color, cards: $0.value.cards) }
    }

    // Legacy: All metrics matching search (for backwards compatibility)
    private var allMatchingMetrics: [DisplayMetric] {
        guard !searchState.searchText.isEmpty else { return [] }
        return viewModel.allMetrics.filter { metric in
            metric.metricName.localizedCaseInsensitiveContains(searchState.searchText)
        }
    }

    // Legacy: Metric search results grouped by pillar
    private var metricSearchResultsByPillar: [(pillar: String, metrics: [DisplayMetric])] {
        guard !searchState.searchText.isEmpty else { return [] }

        var grouped: [String: [DisplayMetric]] = [:]

        for metric in viewModel.allMetrics {
            if metric.metricName.localizedCaseInsensitiveContains(searchState.searchText) {
                let pillar = metric.pillar ?? "Other"
                if grouped[pillar] == nil {
                    grouped[pillar] = []
                }
                grouped[pillar]?.append(metric)
            }
        }

        // Convert to array and sort by pillar order
        return grouped.sorted { lhs, rhs in
            if lhs.key == "Other" { return false }
            if rhs.key == "Other" { return true }
            return lhs.key < rhs.key
        }.map { (pillar: $0.key, metrics: $0.value) }
    }

    // Destination for metric search results - database-driven via chart_type_id
    @ViewBuilder
    private func metricSearchDestination(for metric: DisplayMetric, pillar: String) -> some View {
        let color = MetricsUIConfig.getPillarColor(for: pillar)

        // Route to generic metric detail view which loads chart config from database
        MetricFavoriteDetailView(metricId: metric.metricId, pillar: pillar, color: color)
    }

    // Group favorites by section for sectioned display
    // Uses sectionId (database-driven) with pillar as fallback for backwards compatibility
    private var favoritesByPillar: [(pillar: String, sectionId: String?, favorites: [PatientFavorite])] {
        var grouped: [String: (sectionId: String?, favorites: [PatientFavorite])] = [:]

        for favorite in favoritesService.favorites {
            // Prefer sectionId for grouping, fall back to pillar for backwards compatibility
            let groupKey: String
            let groupSectionId: String?

            if let sectionId = favorite.sectionId {
                // Use section name from displayConfig if available
                groupKey = displayConfig.categorySectionName(for: sectionId) ?? favorite.pillar ?? sectionId
                groupSectionId = sectionId
            } else {
                // Fallback to pillar (legacy favorites without sectionId)
                groupKey = favorite.pillar ?? "Other"
                groupSectionId = sectionIdForPillar(groupKey)
            }

            if grouped[groupKey] == nil {
                grouped[groupKey] = (sectionId: groupSectionId, favorites: [])
            }
            grouped[groupKey]?.favorites.append(favorite)
        }

        // Sort by group name, with "Other" at the end
        return grouped.sorted { lhs, rhs in
            if lhs.key == "Other" { return false }
            if rhs.key == "Other" { return true }
            return lhs.key < rhs.key
        }.map { (pillar: $0.key, sectionId: $0.value.sectionId, favorites: $0.value.favorites) }
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Unable to load data")
                .font(.headline)
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") {
                Task {
                    await viewModel.loadMetricsData()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Background

    private var backgroundView: some View {
        WellPathAmbientBackground(accentColor: WellPathColors.brandGreen)
    }

    // MARK: - Navigation Helpers

    @ViewBuilder
    private func screenDestination(for screen: DisplayScreen, pillar: String) -> some View {
        let color = MetricsUIConfig.getPillarColor(for: pillar)

        // Database-driven - look up category and show its cards
        if let category = displayConfig.cardCategory(id: screen.screenId) {
            ViewCardsListView(category: category, sectionColor: color)
        } else {
            // Fallback for unknown screens
            MetricFavoriteDetailView(metricId: screen.screenId, pillar: pillar, color: color)
        }
    }

    /// Destination for non-metric favorites (screens, biomarkers, biometrics)
    /// Uses database-driven routing via card_id and section_id when available
    @ViewBuilder
    private func favoriteDestination(for favorite: PatientFavorite) -> some View {
        // Get color from section_id (database) or fallback to pillar
        let color: Color = {
            if let sectionId = favorite.sectionId {
                return displayConfig.categorySectionColor(for: sectionId)
            }
            return MetricsUIConfig.getPillarColor(for: favorite.pillar ?? "Core Care")
        }()

        let pillar = favorite.pillar ?? "Core Care"

        // Biomarkers and biometrics always use their dedicated views (not ViewRouter)
        // because they need special handling with their own viewmodels
        switch favorite.itemType {
        case "biomarker":
            // Use displayName (actual biomarker name like "HDL") not itemId (which could be cardId)
            GenericBiomarkerDetailView(biomarkerName: favorite.displayName ?? favorite.itemId, viewModel: BiomarkerViewModel())
        case "biometric":
            // Biometrics: use ViewRouter like metrics for proper routing with info modal
            if let viewConfig = displayConfig.view(id: favorite.itemId) {
                ViewRouter.viewForViewId(viewConfig, color: color, sectionId: favorite.sectionId)
            } else if let cardId = favorite.cardId, let viewConfig = displayConfig.view(id: cardId) {
                ViewRouter.viewForViewId(viewConfig, color: color, sectionId: favorite.sectionId)
            } else {
                // Fallback to legacy view
                BiometricFavoriteDetailView(biometricName: favorite.displayName ?? favorite.itemId)
            }
        case "metric":
            // Metrics: try view_id lookup first (DISP_* ids), then card_id lookup
            if let cardId = favorite.cardId {
                // First try direct view lookup (for DISP_* view IDs)
                if let viewConfig = displayConfig.view(id: cardId) {
                    ViewRouter.viewForViewId(viewConfig, color: color)
                }
                // Then try card lookup (for CARD_* card IDs)
                else if let card = displayConfig.viewCard(id: cardId),
                        let viewConfig = displayConfig.viewForCard(card) {
                    ViewRouter.viewForViewId(viewConfig, color: color)
                }
                // Fallback to itemId lookup
                else if let viewConfig = displayConfig.view(id: favorite.itemId) {
                    ViewRouter.viewForViewId(viewConfig, color: color)
                } else {
                    MetricFavoriteDetailView(metricId: favorite.itemId, pillar: pillar, color: color)
                }
            } else if let viewConfig = displayConfig.view(id: favorite.itemId) {
                ViewRouter.viewForViewId(viewConfig, color: color)
            } else {
                MetricFavoriteDetailView(metricId: favorite.itemId, pillar: pillar, color: color)
            }

        case "screen":
            // Database-driven - look up category and show its cards
            if let category = displayConfig.cardCategory(id: favorite.itemId) {
                ViewCardsListView(category: category, sectionColor: color)
            } else if let viewConfig = displayConfig.view(id: favorite.itemId) {
                ViewRouter.viewForViewId(viewConfig, color: color)
            } else {
                MetricFavoriteDetailView(metricId: favorite.itemId, pillar: pillar, color: color)
            }

        default:
            Text("Unknown favorite type: \(favorite.itemType)")
        }
    }
}

// MARK: - Metric Favorite Detail View

struct MetricFavoriteDetailView: View {
    let metricId: String
    let pillar: String
    let color: Color

    @StateObject private var viewModel = MetricFavoriteDetailViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let metric = viewModel.metric {
                ParentMetricBarChart(metric: metric, color: color, showAbout: .constant(false))
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Metric not found")
                        .font(.headline)
                    Text(metricId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .metricScreenBackground(color: color)
        .navigationTitle(viewModel.metric?.metricName ?? "Metric")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadMetric(metricId: metricId)
        }
    }
}

@MainActor
class MetricFavoriteDetailViewModel: ObservableObject {
    @Published var metric: DisplayMetric?
    @Published var isLoading = false

    private let supabase = SupabaseManager.shared.client

    func loadMetric(metricId: String) async {
        isLoading = true
        do {
            let views: [DisplayMetric] = try await supabase
                .from("display_views")
                .select()
                .eq("view_id", value: metricId)
                .limit(1)
                .execute()
                .value

            metric = views.first
        } catch {
            print("❌ Error loading metric: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Favorite Row (Database-driven colors/icons via sectionId)

struct FavoriteRow: View {
    let favorite: PatientFavorite
    @EnvironmentObject private var displayConfig: DisplayConfigurationService

    /// Get color from database via section_id, fallback to pillar, then hardcoded
    var sectionColor: Color {
        // 1. Try section_id from favorite (database-driven)
        if let sectionId = favorite.sectionId {
            return displayConfig.categorySectionColor(for: sectionId)
        }
        // 2. Fallback to pillar-based lookup
        if let pillar = favorite.pillar {
            return displayConfig.pillarColor(for: pillar)
        }
        // 3. Final fallback
        return MetricsUIConfig.getPillarColor(for: favorite.pillar ?? "Core Care")
    }

    /// Get icon from database via section_id, fallback to hardcoded
    var icon: String {
        // 1. Try section_id from favorite (database-driven)
        if let sectionId = favorite.sectionId {
            return displayConfig.categorySectionIcon(for: sectionId)
        }
        // 2. Fallback to type-based hardcoded icons
        if favorite.itemType == "screen" {
            return MetricsUIConfig.getIcon(for: favorite.itemId)
        } else if favorite.itemType == "metric" {
            return MetricsUIConfig.getIcon(for: favorite.displayName ?? "")
        } else if favorite.itemType == "biomarker" {
            return "testtube.2"
        } else if favorite.itemType == "biometric" {
            return "waveform.path.ecg"
        }
        return "star.fill"
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(sectionColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(sectionColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(favorite.displayName ?? favorite.itemId)
                    .font(.headline)
                    .foregroundColor(.primary)

                if let pillar = favorite.pillar {
                    Text(pillar)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(sectionColor)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(16)
    }
}

// Search result row for display metrics with highlighted match
struct MetricSearchResultRow: View {
    let metric: DisplayMetric
    let pillar: String
    let searchText: String

    private var color: Color {
        MetricsUIConfig.getPillarColor(for: pillar)
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: MetricsUIConfig.getIcon(for: metric.metricName))
                    .foregroundColor(color)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Highlighted name
                highlightedText(metric.metricName, highlight: searchText)
                    .font(.headline)

                if let description = metric.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(color)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(16)
    }

    // Highlight matching text
    private func highlightedText(_ text: String, highlight: String) -> Text {
        guard !highlight.isEmpty else {
            return Text(text)
        }

        let lowercaseText = text.lowercased()
        let lowercaseHighlight = highlight.lowercased()

        guard let range = lowercaseText.range(of: lowercaseHighlight) else {
            return Text(text)
        }

        let startIndex = text.index(text.startIndex, offsetBy: lowercaseText.distance(from: lowercaseText.startIndex, to: range.lowerBound))
        let endIndex = text.index(text.startIndex, offsetBy: lowercaseText.distance(from: lowercaseText.startIndex, to: range.upperBound))

        let before = String(text[..<startIndex])
        let match = String(text[startIndex..<endIndex])
        let after = String(text[endIndex...])

        return Text(before) + Text(match).foregroundColor(color).bold() + Text(after)
    }
}

// Search result row for view cards with highlighted match
struct CardSearchResultRow: View {
    let card: ViewCardConfig
    let color: Color
    let searchText: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: MetricsUIConfig.getIcon(for: card.cardName, viewId: card.viewId ?? ""))
                    .foregroundColor(color)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Highlighted name
                highlightedText(card.cardName, highlight: searchText)
                    .font(.headline)

                if let description = card.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(color)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(16)
    }

    // Highlight matching text
    private func highlightedText(_ text: String, highlight: String) -> Text {
        guard !highlight.isEmpty else {
            return Text(text)
        }

        let lowercaseText = text.lowercased()
        let lowercaseHighlight = highlight.lowercased()

        guard let range = lowercaseText.range(of: lowercaseHighlight) else {
            return Text(text)
        }

        let startIndex = text.index(text.startIndex, offsetBy: lowercaseText.distance(from: lowercaseText.startIndex, to: range.lowerBound))
        let endIndex = text.index(text.startIndex, offsetBy: lowercaseText.distance(from: lowercaseText.startIndex, to: range.upperBound))

        let before = String(text[..<startIndex])
        let match = String(text[startIndex..<endIndex])
        let after = String(text[endIndex...])

        return Text(before) + Text(match).foregroundColor(color).bold() + Text(after)
    }
}

// MARK: - Category Section Row (Database-driven navigation item)

struct CategorySectionRow: View {
    let section: CategorySectionConfig

    var body: some View {
        HStack(spacing: 12) {
            // Compact circle icon
            ZStack {
                Circle()
                    .fill(section.color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: section.icon)
                    .foregroundColor(section.color)
                    .font(.system(size: 16))
            }

            Text(section.sectionName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(section.color)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Category Cards List View (Shows card categories for a section)

struct CategoryCardsListView: View {
    let section: CategorySectionConfig
    @EnvironmentObject private var displayConfig: DisplayConfigurationService
    @EnvironmentObject private var searchState: WellPathDataSearchState
    @FocusState private var isSearchFocused: Bool

    var categories: [CardCategoryConfig] {
        displayConfig.cardCategories(forSection: section.sectionId)
    }

    /// Cards in this section that match the search query
    private var matchingCards: [ViewCardConfig] {
        guard !searchState.searchText.isEmpty else { return [] }
        return displayConfig.viewCards.filter { card in
            // Only include cards from this section
            guard let categoryId = card.categoryId,
                  let category = displayConfig.cardCategory(id: categoryId),
                  category.sectionId == section.sectionId else { return false }

            // Match against card name or description
            return card.cardName.localizedCaseInsensitiveContains(searchState.searchText) ||
                   (card.description?.localizedCaseInsensitiveContains(searchState.searchText) ?? false)
        }
    }

    /// Categories that match the search query (by name) or contain matching cards
    private var matchingCategories: [CardCategoryConfig] {
        guard !searchState.searchText.isEmpty else { return [] }
        return categories.filter { category in
            // Match category name
            if category.name.localizedCaseInsensitiveContains(searchState.searchText) {
                return true
            }
            // Or check if any cards in this category match
            let categoryCards = displayConfig.viewCards(forCategory: category.categoryId)
            return categoryCards.contains { card in
                card.cardName.localizedCaseInsensitiveContains(searchState.searchText) ||
                (card.description?.localizedCaseInsensitiveContains(searchState.searchText) ?? false)
            }
        }
    }

    /// Search results view showing matching categories and cards
    @ViewBuilder
    private var searchResultsView: some View {
        if matchingCategories.isEmpty && matchingCards.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("No results for \"\(searchState.searchText)\"")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    // Show matching categories
                    if !matchingCategories.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Categories")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            ForEach(matchingCategories) { category in
                                NavigationLink(destination: categoryDestination(for: category)) {
                                    CategoryCardRow(category: category, sectionColor: section.color)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Show matching cards directly
                    if !matchingCards.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Metrics")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            ForEach(matchingCards) { card in
                                DatabaseDrivenCard(card: card, color: section.color)
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }

    var body: some View {
        Group {
            if searchState.isSearchActive && !searchState.searchText.isEmpty {
                // Search results
                searchResultsView
            } else {
                // Normal category list
                List {
                    ForEach(categories) { category in
                        NavigationLink(destination: categoryDestination(for: category)) {
                            CategoryCardRow(category: category, sectionColor: section.color)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if searchState.isSearchActive {
                WellPathDataSearchBar(
                    searchState: searchState,
                    isFocused: $isSearchFocused,
                    placeholder: "Search \(section.sectionName.lowercased())"
                )
            }
        }
        .wellPathAmbientBackground(color: section.color)
        .navigationTitle(section.sectionName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation {
                        searchState.activateSearch()
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.primary)
                }
            }
        }
    }

    // MARK: - Category Destination Router (Swift-driven custom screens)

    @ViewBuilder
    private func categoryDestination(for category: CardCategoryConfig) -> some View {
        let color = displayConfig.cardCategoryColor(for: category.categoryId)
        let pillar = section.sectionName
        let cards = displayConfig.viewCards(forCategory: category.categoryId)

        // Route to custom Swift screens for categories that need special layouts
        switch category.categoryId {
        // Nutrition categories with custom multi-card layouts
        case "CAT_PROTEIN":
            ProteinScreen(pillar: pillar, color: color)
        case "CAT_VEGETABLES":
            VegetablesScreen(pillar: pillar, color: color)
        case "CAT_LEGUMES":
            LegumesScreen(pillar: pillar, color: color)
        case "CAT_FRUITS":
            FruitsScreen(pillar: pillar, color: color)
        case "CAT_WHOLE_GRAINS":
            WholeGrainsScreen(pillar: pillar, color: color)
        case "CAT_FATS":
            FatsScreen(pillar: pillar, color: color)
        case "CAT_FIBER":
            FiberScreen(pillar: pillar, color: color)
        case "CAT_CAFFEINE":
            CaffeineScreen(pillar: pillar, color: color)
        case "CAT_HYDRATION":
            WaterScreen(pillar: pillar, color: color)
        case "CAT_NUTS_SEEDS":
            NutsSeedsScreen(pillar: pillar, color: color)
        case "CAT_MEAL_PATTERNS":
            MealPatternsScreen(pillar: pillar, color: color)
        case "CAT_ULTRA_PROCESSED":
            UltraProcessedScreen(pillar: pillar, color: color)

        // Sleep categories - each needs its own screen with score
        case "CAT_SLEEP_ANALYSIS":
            ViewCardsListView(category: category, sectionColor: section.color)
        case "CAT_SLEEP_CONSISTENCY":
            SleepConsistencyScreen(pillar: pillar, color: color)
        case "CAT_SLEEP_ROUTINE":
            SleepRoutineScreen(pillar: pillar, color: color)
        case "CAT_SLEEP_ENVIRONMENT":
            SleepEnvironmentScreen(pillar: pillar, color: color)

        // Biometrics categories - show cards for subcategories
        case "CAT_BIOMETRICS_BODY_COMP", "CAT_BIOMETRICS_VITALS", "CAT_BIOMETRICS_STRENGTH", "CAT_FITNESS_METRICS":
            BiometricCategoryScreen(
                category: BiometricCategory(rawValue: category.categoryId) ?? .bodyComposition,
                pillar: pillar,
                color: color
            )

        // Default - check for subcategories first, then cards
        default:
            // If category has subcategories, show subcategory list
            if displayConfig.hasSubcategories(categoryId: category.categoryId) {
                SubcategoriesListView(parentCategory: category, sectionColor: section.color)
            } else if cards.count == 1,
               let singleCard = cards.first,
               let viewId = singleCard.viewId,
               let viewConfig = displayConfig.view(id: viewId) {
                // Single card: route directly to the view (skip card list)
                ViewRouter.viewForViewId(viewConfig, color: color, sectionId: section.sectionId)
            } else {
                // Multi-card category: show card list
                ViewCardsListView(category: category, sectionColor: section.color)
            }
        }
    }
}

// MARK: - Subcategories List View (Shows subcategories for a parent category)

struct SubcategoriesListView: View {
    let parentCategory: CardCategoryConfig
    let sectionColor: Color
    @EnvironmentObject private var displayConfig: DisplayConfigurationService

    var subcategories: [CardCategoryConfig] {
        displayConfig.subcategories(forCategory: parentCategory.categoryId)
    }

    var color: Color {
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
                            SubcategoryDestinationView(
                                category: subcategory,
                                parentColor: color
                            )
                        } label: {
                            SubcategoryCard(category: subcategory, color: color)
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

// MARK: - Subcategory Card

struct SubcategoryCard: View {
    let category: CardCategoryConfig
    let color: Color
    @EnvironmentObject private var displayConfig: DisplayConfigurationService

    var cardCount: Int {
        displayConfig.viewCards(forCategory: category.categoryId).count
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: category.iconName ?? "folder")
                    .font(.title3)
                    .foregroundColor(color)
            }

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                if let overview = category.overview {
                    Text(overview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else if cardCount > 0 {
                    Text("\(cardCount) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Subcategory Destination View

struct SubcategoryDestinationView: View {
    let category: CardCategoryConfig
    let parentColor: Color
    @EnvironmentObject private var displayConfig: DisplayConfigurationService

    var cards: [ViewCardConfig] {
        displayConfig.viewCards(forCategory: category.categoryId)
    }

    var color: Color {
        displayConfig.cardCategoryColor(for: category.categoryId)
    }

    var body: some View {
        // Subcategories show their cards (not further nesting for now)
        ViewCardsListView(category: category, sectionColor: parentColor)
    }
}

// MARK: - View Cards List View (Shows cards for a category - database-driven)

struct ViewCardsListView: View {
    let category: CardCategoryConfig
    let sectionColor: Color
    @EnvironmentObject private var displayConfig: DisplayConfigurationService
    @EnvironmentObject private var searchState: WellPathDataSearchState
    @FocusState private var isSearchFocused: Bool

    var cards: [ViewCardConfig] {
        displayConfig.viewCards(forCategory: category.categoryId)
    }

    var color: Color {
        displayConfig.cardCategoryColor(for: category.categoryId)
    }

    var icon: String {
        displayConfig.cardCategoryIcon(for: category.categoryId)
    }

    // NOTE: Category views should NOT have toolbar buttons (data management, entry, favorite)
    // These buttons belong on the individual detail VIEWS, not category listings
    // EXCEPT: Search button is allowed at all levels

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if cards.isEmpty {
                    emptyState
                } else {
                    ForEach(cards) { card in
                        DatabaseDrivenCard(card: card, color: color)
                    }
                }
            }
            .padding()
            .padding(.bottom, searchState.isSearchActive ? 80 : 24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if searchState.isSearchActive {
                WellPathDataSearchBar(
                    searchState: searchState,
                    isFocused: $isSearchFocused,
                    placeholder: "Search \(category.name.lowercased())"
                )
            }
        }
        .wellPathAmbientBackground(color: color)
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation {
                        searchState.activateSearch()
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.primary)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
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

// MARK: - Database-Driven Card (renders based on chart_type_id)

struct DatabaseDrivenCard: View {
    let card: ViewCardConfig
    let color: Color
    @EnvironmentObject private var displayConfig: DisplayConfigurationService

    var viewConfig: ViewConfig? {
        displayConfig.viewForCard(card)
    }

    var chartType: String {
        viewConfig?.chartTypeId ?? "bar_vertical"
    }

    /// Check if this is a biometric view (uses patient_samples, not aggregations)
    var isBiometric: Bool {
        guard let config = viewConfig else { return false }
        // Biometrics have pillar = "Biometrics" or are in biometric categories
        // Dependencies now stored in display_views_dependencies junction table
        if config.pillar == "Biometrics" {
            return true
        }
        // Check category for biometric categories
        if let categoryId = config.categoryId,
           categoryId.hasPrefix("CAT_BIOMETRICS") || categoryId == "CAT_FITNESS_METRICS" {
            return true
        }
        return false
    }

    /// Check if this is a biomarker view (uses biomarker_readings, not aggregations)
    var isBiomarker: Bool {
        // Check viewConfig if available
        if let config = viewConfig {
            // Biomarkers have pillar = "Biomarker" or are in biomarker categories
            if config.pillar == "Biomarker" {
                return true
            }
            // Check category for biomarker categories
            if let categoryId = config.categoryId, categoryId.hasPrefix("CAT_BIOMARKER") {
                return true
            }
            // Check view_id pattern for biomarkers (DISP_BIO_*)
            if config.viewId.hasPrefix("DISP_BIO_") {
                return true
            }
        }
        // Fallback: check the card itself
        // Card's categoryId may indicate biomarker
        if let categoryId = card.categoryId, categoryId.hasPrefix("CAT_BIOMARKER") {
            return true
        }
        // Card's view_id or card_id may indicate biomarker (DISP_BIO_* or CARD_BIO_*)
        if let viewId = card.viewId, viewId.hasPrefix("DISP_BIO_") {
            return true
        }
        if card.cardId.hasPrefix("CARD_BIO_") {
            return true
        }
        return false
    }

    var body: some View {
        // Check if CardRegistry has a custom card for this view_id
        // This ensures category views use the same cards as Favorites
        if let viewId = card.viewId, CardRegistry.hasCustomCard(for: viewId) {
            CardRegistry.card(
                for: viewId,
                color: color,
                pillar: viewConfig?.pillar ?? "",
                displayName: card.cardName
            )
        } else if isBiomarker {
            // Biomarkers use CardRegistry which routes to BiomarkerFavoriteCard
            CardRegistry.card(
                for: card.viewId ?? card.cardId,
                color: color,
                pillar: viewConfig?.pillar ?? "Biomarker",
                displayName: card.cardName,
                sectionId: "NAV_BIOMARKERS"
            )
        } else {
            // Fallback to generic database-driven rendering
            genericCardContent
        }
    }

    @ViewBuilder
    private var genericCardContent: some View {
        MetricCardView(
            title: card.cardName,
            color: color,
            metricId: card.viewId ?? "",
            pillar: viewConfig?.pillar ?? ""
        ) {
            // Mini card content - biometrics use BiometricMiniCard, others use GenericMiniCard
            miniCardContent
        } fullScreen: {
            // Full screen view based on chart_type_id
            fullScreenContent
        }
    }

    @ViewBuilder
    private var miniCardContent: some View {
        // Biometrics use BiometricMiniCard which queries patient_samples
        if isBiometric, let config = viewConfig {
            let metric = DisplayMetric(from: config)
            let icon = config.iconName ?? MetricsUIConfig.getIcon(for: card.cardName, viewId: card.viewId ?? "")
            BiometricMiniCard(metric: metric, color: color, icon: icon)
        } else {
            // Non-biometrics use GenericMiniCard which queries aggregations
            GenericMiniCard(viewId: card.viewId ?? "", color: color)
        }
    }

    @ViewBuilder
    private var fullScreenContent: some View {
        if let viewConfig = viewConfig {
            ViewRouter.viewForViewId(viewConfig, color: color)
        } else {
            Text("View not found")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - View Router (Swift-driven - routes by view_id first, then chart_type_id)

struct ViewRouter {
    /// Routes to the correct Swift view based on view_id
    /// Database provides hierarchy/names, Swift defines rendering
    /// sectionId: optional, used for views that need it for favorites (e.g., single-card categories)
    @MainActor @ViewBuilder
    static func viewForViewId(_ viewConfig: ViewConfig, color: Color, sectionId: String? = nil) -> some View {
        let viewId = viewConfig.viewId
        let pillar = viewConfig.pillar ?? ""

        // First check view_id for custom Swift implementations
        switch viewId {
        // Protein views
        case "DISP_PROTEIN_GRAMS":
            ProteinAmountView(color: color)
        case "DISP_PROTEIN_TYPE":
            ProteinTypeView(color: color)
        case "DISP_PROTEIN_RATIO":
            ProteinRatioView(color: color)

        // Vegetable views
        case "DISP_VEGETABLES_SERVINGS":
            VegetablesServingsView(color: color)
        case "DISP_VEGETABLES_TYPE":
            VegetablesTypeView(color: color)

        // Legume views
        case "DISP_LEGUMES_SERVINGS":
            LegumesServingsView(color: color)
        case "DISP_LEGUMES_TYPE":
            LegumesTypeView(color: color)

        // Fruit views
        case "DISP_FRUITS_SERVINGS":
            FruitsServingsView(color: color)
        case "DISP_FRUITS_TYPE":
            FruitsTypeView(color: color)

        // Whole Grain views
        case "DISP_WHOLE_GRAINS_SERVINGS":
            WholeGrainsServingsView(color: color)
        case "DISP_WHOLE_GRAINS_TYPE":
            WholeGrainsTypeView(color: color)

        // Fats views
        case "DISP_FATS_GRAMS":
            FatsAmountView(color: color)
        case "DISP_FATS_TYPE":
            FatsTypeView(color: color)

        // Fiber views
        case "DISP_FIBER_GRAMS":
            FiberAmountView(color: color)

        // Caffeine views
        case "DISP_CAFFEINE_MG":
            CaffeineAmountView(color: color)
        case "DISP_CAFFEINE_TYPE":
            CaffeineTypeView(color: color)
        case "DISP_CAFFEINE_TIMING":
            CaffeineTimingView(color: color)

        // Water/Hydration views
        case "DISP_HYDRATION_AMOUNT", "DISP_WATER_ML":
            WaterAmountView(color: color)
        case "DISP_HYDRATION_TIMING", "DISP_WATER_TIMING":
            WaterTimingView(color: color)

        // Nuts & Seeds views
        case "DISP_NUTS_SEEDS_SERVINGS":
            NutsSeedsServingsView(color: color)
        case "DISP_NUTS_SEEDS_TYPE":
            NutsSeedsTypeView(color: color)

        // Ultra-Processed views
        case "DISP_ULTRA_PROCESSED_SERVINGS":
            UltraProcessedServingsView(color: color)

        // Meal Patterns views
        case "DISP_MEAL_TYPE":
            MealTypeView(color: color)
        case "DISP_WHOLE_FOOD_MEALS":
            WholeFoodMealsView(color: color)
        case "DISP_PLANT_BASED_MEALS":
            PlantBasedMealsView(color: color)
        case "DISP_HOMEMADE_MEALS":
            HomemadeMealsView(color: color)

        // Sleep views - each routes to its own full view (database-driven viewId)
        case "DISP_SLEEP_STAGES":
            SleepStagesFullView(color: color, viewId: viewId)
        case "DISP_SLEEP_AMOUNTS":
            SleepAmountsFullView(color: color, viewId: viewId)
        case "DISP_SLEEP_PERCENTAGES":
            SleepPercentagesFullView(color: color, viewId: viewId)
        case "DISP_SLEEP_COMPARISONS":
            SleepComparisonsFullView(color: color, viewId: viewId)
        case "DISP_SLEEP_DURATION":
            SleepDurationView(pillar: pillar, color: color, sectionId: sectionId ?? "NAV_SLEEP")
        case "DISP_SLEEP_CONSISTENCY":
            SleepConsistencyView(pillar: pillar, color: color, sectionId: sectionId ?? "NAV_SLEEP")

        // Steps view
        case "DISP_STEPS":
            StepsScreen(pillar: pillar, color: color, sectionId: sectionId ?? "NAV_MOVEMENT")

        // Workout duration views
        case "DISP_CARDIO_DURATION":
            CardioScreen(pillar: pillar, color: color, sectionId: sectionId ?? "NAV_MOVEMENT")
        case "DISP_STRENGTH_DURATION":
            StrengthScreen(pillar: pillar, color: color, sectionId: sectionId ?? "NAV_MOVEMENT")
        case "DISP_HIIT_DURATION":
            HIITScreen(pillar: pillar, color: color, sectionId: sectionId ?? "NAV_MOVEMENT")
        case "DISP_MOBILITY_DURATION":
            MobilityScreen(pillar: pillar, color: color, sectionId: sectionId ?? "NAV_MOVEMENT")

        // Alcohol views
        case "DISP_ALCOHOL_QUANTITY":
            AlcoholQuantityView(color: color)
        case "DISP_ALCOHOL_TYPE":
            AlcoholTypeView(color: color)

        // Tobacco views
        case "DISP_TOBACCO_STREAK":
            TobaccoStreakView(color: color)
        case "DISP_TOBACCO_USAGE":
            TobaccoUsageView(color: color)
        case "DISP_TOBACCO_TYPE":
            TobaccoTypeView(color: color)

        // Nicotine views
        case "DISP_NICOTINE_QUANTITY":
            NicotineQuantityView(color: color)
        case "DISP_NICOTINE_TYPE":
            NicotineTypeView(color: color)

        // Cannabis views
        case "DISP_CANNABIS_QUANTITY":
            CannabisQuantityView(color: color)
        case "DISP_CANNABIS_TYPE":
            CannabisTypeView(color: color)

        // Biometric views (use patient_samples, not aggregations)
        case "DISP_BODYFAT":
            BodyFatView(color: color)
        case "DISP_BODYWEIGHT":
            BodyWeightView(color: color)
        case "DISP_BMI":
            BMIView(color: color)
        case "DISP_VISCERAL_FAT":
            VisceralFatView(color: color)
        case "DISP_WAIST_CIRCUMFERENCE":
            WaistCircumferenceView(color: color)
        case "DISP_HIP_CIRCUMFERENCE":
            HipCircumferenceView(color: color)
        case "DISP_WAIST_HIP":
            WaistHipView(color: color)
        case "DISP_ASMI":
            ASMIView(color: color)
        case "DISP_BLOOD_PRESSURE", "DISP_SYSTOLIC_BP":
            BloodPressureView(color: color)
        case "DISP_HRV":
            HRVView(color: color)
        case "DISP_RESTING_HR":
            RestingHRView(metric: DisplayMetric(from: viewConfig), color: color)
        case "DISP_VO2_MAX":
            VO2MaxView(metric: DisplayMetric(from: viewConfig), color: color)
        case "DISP_GRIP_STRENGTH":
            GripStrengthView(color: color)

        // Mental Health Assessment views
        case "DISP_WELLBEING":
            AssessmentScreenTemplate(assessmentId: "ASSESS_SWLS", color: color, viewId: "DISP_WELLBEING")
        case "DISP_ANXIETY":
            AssessmentScreenTemplate(assessmentId: "ASSESS_GAD2", color: color, viewId: "DISP_ANXIETY")
        case "DISP_DEPRESSION":
            AssessmentScreenTemplate(assessmentId: "ASSESS_PHQ2", color: color, viewId: "DISP_DEPRESSION")
        case "DISP_STRESS":
            AssessmentScreenTemplate(assessmentId: "ASSESS_STRESS_LEVEL", color: color, viewId: "DISP_STRESS")

        // Sleep Assessment views
        case "DISP_SLEEP_ROUTINE":
            AssessmentScreenTemplate(assessmentId: "ASSESS_SLEEP_ROUTINE", color: color, viewId: "DISP_SLEEP_ROUTINE")
        case "DISP_SLEEP_ENVIRONMENT":
            AssessmentScreenTemplate(assessmentId: "ASSESS_SLEEP_ENVIRONMENT", color: color, viewId: "DISP_SLEEP_ENVIRONMENT")

        // Core Care - Therapeutics views
        case "DISP_MY_THERAPEUTICS":
            MyTherapeuticsView()
        case "DISP_SUPPLEMENTS":
            TherapeuticsExploreView(therapeuticType: .supplement)
        case "DISP_MEDICATIONS":
            TherapeuticsExploreView(therapeuticType: .medication)
        case "DISP_PEPTIDES":
            TherapeuticsExploreView(therapeuticType: .peptide)
        case "DISP_HORMONES":
            TherapeuticsExploreView(therapeuticType: .hormone)

        // Core Care - Health History views
        case "DISP_PERSONAL_HISTORY":
            PersonalHistoryView(viewModel: MedicalHistoryViewModel(), color: .red)
        case "DISP_FAMILY_HISTORY":
            FamilyHistoryView(viewModel: MedicalHistoryViewModel(), color: .red)
        case "DISP_MEDICAL_HISTORY":
            MedicalHistoryEntryView()

        // Core Care - Screenings views
        case "DISP_MY_SCREENINGS":
            ScreeningsListView()

        // Default - for views without explicit routing
        default:
            // Check if this is a biomarker (naming convention: DISP_BIOMARKER_*)
            if viewId.hasPrefix("DISP_BIOMARKER_") {
                // Biomarkers all share the same structure - use generic view
                GenericBiomarkerDetailView(biomarkerName: viewId, viewModel: BiomarkerViewModel())
            } else {
                // All other views MUST have dedicated Swift implementations
                // If we reach here, the view needs to be added to ViewRouter
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("View Not Implemented")
                        .font(.headline)
                    Text("Add dedicated view for: \(viewId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(WellPathColors.backgroundBase)
            }
        }
    }
}

// MARK: - DisplayMetric Extension for ViewConfig

extension DisplayMetric {
    init(from viewConfig: ViewConfig) {
        self.id = viewConfig.viewId
        self.metricId = viewConfig.viewId
        self.metricName = viewConfig.viewName
        self.pillar = viewConfig.pillar
        self.description = nil
        self.chartTypeId = viewConfig.chartTypeId
        self.isActive = true
        self.aboutContent = viewConfig.aboutContent
        self.longevityImpact = viewConfig.longevityImpact
        self.quickTips = viewConfig.quickTips
    }
}

// MARK: - Category Card Row

struct CategoryCardRow: View {
    let category: CardCategoryConfig
    let sectionColor: Color
    @EnvironmentObject private var displayConfig: DisplayConfigurationService

    var icon: String {
        displayConfig.cardCategoryIcon(for: category.categoryId)
    }

    var color: Color {
        displayConfig.cardCategoryColor(for: category.categoryId)
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.headline)

                if let overview = category.overview {
                    Text(overview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(color)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        TrackedMetricsListView()
            .environmentObject(DisplayConfigurationService.shared)
    }
}
