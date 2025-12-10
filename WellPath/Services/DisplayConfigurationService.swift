//
//  DisplayConfigurationService.swift
//  WellPath
//
//  Created on 2025-11-30
//
//  Database-driven display configuration service.
//  Replaces hardcoded MetricsUIConfig with extensible DB queries.
//

import SwiftUI
import Supabase

// MARK: - Display Hierarchy Models
// Hierarchy: display_section_headers → display_category_sections → display_card_categories → display_view_cards → display_views

/// Level 1: Section Headers (groups sections like "Health Pillars", "Markers & Metrics")
struct SectionHeaderConfig: Codable, Identifiable {
    let id: UUID
    let headerId: String
    let headerName: String
    let description: String?
    let iconName: String?
    let displayOrder: Int?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case headerId = "header_id"
        case headerName = "header_name"
        case description
        case iconName = "icon_name"
        case displayOrder = "display_order"
        case isActive = "is_active"
    }

    var icon: String { iconName ?? "circle.fill" }
}

/// Level 2: Category Sections (e.g., "Healthful Nutrition", "Biometrics")
struct CategorySectionConfig: Codable, Identifiable {
    let id: UUID
    let sectionId: String
    let sectionName: String
    let headerId: String
    let description: String?
    let iconName: String?
    let colorHex: String?
    let displayOrder: Int?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case sectionId = "section_id"
        case sectionName = "section_name"
        case headerId = "header_id"
        case description
        case iconName = "icon_name"
        case colorHex = "color_hex"
        case displayOrder = "display_order"
        case isActive = "is_active"
    }

    var icon: String { iconName ?? "circle.fill" }

    var color: Color {
        guard let hex = colorHex else { return .gray }
        return Color(hex: hex) ?? .gray
    }
}

// MARK: - Configuration Models (Level 3+)

struct PillarConfig: Codable, Identifiable {
    let id: UUID
    let pillarName: String
    let description: String?
    let icon: String?
    let color: String?
    let displayOrder: Int?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case pillarName = "pillar_name"
        case description
        case icon
        case color
        case displayOrder = "display_order"
        case isActive = "is_active"
    }

    var colorValue: Color {
        guard let hex = color else { return .gray }
        return Color(hex: hex) ?? .gray
    }

    var iconName: String {
        icon ?? "circle.fill"
    }
}

/// Level 3: Card Categories (e.g., "Protein", "Sleep Duration")
struct CardCategoryConfig: Codable, Identifiable {
    let id: UUID
    let categoryId: String
    let name: String
    let overview: String?
    let pillar: String?  // Optional - categories may not belong to a pillar
    let sectionId: String?  // Links to display_category_sections
    let displayOrder: Int?
    let iconName: String?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case categoryId = "category_id"
        case name
        case overview
        case pillar
        case sectionId = "section_id"
        case displayOrder = "display_order"
        case iconName = "icon_name"
        case isActive = "is_active"
    }
}

struct ViewConfig: Codable, Identifiable {
    let id: UUID
    let viewId: String
    let viewName: String
    let categoryId: String?
    let pillar: String?
    let chartTypeId: String?
    let defaultTimePeriod: String?
    let aboutContent: String?
    let longevityImpact: String?
    let quickTips: [String]?
    let hasGoal: Bool?
    let iconName: String?
    let isActive: Bool?
    // Note: sample_quantity_type moved to display_views_dependencies junction table

    enum CodingKeys: String, CodingKey {
        case id
        case viewId = "view_id"
        case viewName = "view_name"
        case categoryId = "category_id"
        case pillar
        case chartTypeId = "chart_type_id"
        case defaultTimePeriod = "default_time_period"
        case aboutContent = "about_content"
        case longevityImpact = "longevity_impact"
        case quickTips = "quick_tips"
        case hasGoal = "has_goal"
        case iconName = "icon_name"
        case isActive = "is_active"
    }
}

/// Level 4: View Cards - individual cards within a category
/// Rendering determined by linked view's chart_type_id
struct ViewCardConfig: Codable, Identifiable {
    let id: UUID
    let cardId: String
    let cardName: String
    let description: String?
    let displayOrder: Int?
    let viewId: String?
    let categoryId: String?
    let canFavorite: Bool?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case cardId = "card_id"
        case cardName = "card_name"
        case description
        case displayOrder = "display_order"
        case viewId = "view_id"
        case categoryId = "category_id"
        case canFavorite = "can_favorite"
        case isActive = "is_active"
    }
}

struct DisplayTierConfig: Codable, Identifiable {
    var id: String { tierId + (viewId ?? "") }
    let tierId: String
    let viewId: String?
    let tierName: String
    let tierDescription: String?
    let targetPercentage: Int?
    let multiplier: Double?
    let displayOrder: Int?
    let colorHex: String?

    enum CodingKeys: String, CodingKey {
        case tierId = "tier_id"
        case viewId = "view_id"
        case tierName = "tier_name"
        case tierDescription = "tier_description"
        case targetPercentage = "target_percentage"
        case multiplier
        case displayOrder = "display_order"
        case colorHex = "color_hex"
    }

    var colorValue: Color {
        guard let hex = colorHex else { return .gray }
        return Color(hex: hex) ?? .gray
    }
}

// MARK: - Configuration Service

@MainActor
class DisplayConfigurationService: ObservableObject {
    static let shared = DisplayConfigurationService()

    // Display hierarchy (Level 1 & 2)
    @Published private(set) var sectionHeaders: [SectionHeaderConfig] = []
    @Published private(set) var categorySections: [CategorySectionConfig] = []

    // Display config (Level 3+)
    @Published private(set) var pillars: [PillarConfig] = []
    @Published private(set) var cardCategories: [CardCategoryConfig] = []
    @Published private(set) var viewCards: [ViewCardConfig] = []
    @Published private(set) var views: [ViewConfig] = []
    @Published private(set) var tiers: [String: [DisplayTierConfig]] = [:] // keyed by view_id

    @Published private(set) var isLoaded: Bool = false
    @Published private(set) var loadError: Error?

    // Lookup dictionaries for fast access
    private var sectionHeadersById: [String: SectionHeaderConfig] = [:]
    private var categorySectionsById: [String: CategorySectionConfig] = [:]
    private var pillarsByName: [String: PillarConfig] = [:]
    private var cardCategoriesById: [String: CardCategoryConfig] = [:]
    private var viewCardsById: [String: ViewCardConfig] = [:]
    private var viewCardsByCategory: [String: [ViewCardConfig]] = [:]
    private var viewsById: [String: ViewConfig] = [:]

    private init() {}

    // MARK: - Loading

    func loadConfiguration() async {
        do {
            // Load all configuration in parallel
            async let headersTask = loadSectionHeaders()
            async let sectionsTask = loadCategorySections()
            async let pillarsTask = loadPillars()
            async let categoriesTask = loadCardCategories()
            async let viewCardsTask = loadViewCards()
            async let viewsTask = loadViews()
            async let tiersTask = loadTiers()

            let (loadedHeaders, loadedSections, loadedPillars, loadedCategories, loadedViewCards, loadedViews, loadedTiers) = try await (
                headersTask,
                sectionsTask,
                pillarsTask,
                categoriesTask,
                viewCardsTask,
                viewsTask,
                tiersTask
            )

            self.sectionHeaders = loadedHeaders
            self.categorySections = loadedSections
            self.pillars = loadedPillars
            self.cardCategories = loadedCategories
            self.viewCards = loadedViewCards
            self.views = loadedViews
            self.tiers = Dictionary(grouping: loadedTiers, by: { $0.viewId ?? "" })

            // Build lookup dictionaries
            self.sectionHeadersById = Dictionary(uniqueKeysWithValues: loadedHeaders.map { ($0.headerId, $0) })
            self.categorySectionsById = Dictionary(uniqueKeysWithValues: loadedSections.map { ($0.sectionId, $0) })
            self.pillarsByName = Dictionary(uniqueKeysWithValues: loadedPillars.map { ($0.pillarName, $0) })
            self.cardCategoriesById = Dictionary(uniqueKeysWithValues: loadedCategories.map { ($0.categoryId, $0) })
            self.viewCardsById = Dictionary(uniqueKeysWithValues: loadedViewCards.map { ($0.cardId, $0) })
            self.viewCardsByCategory = Dictionary(grouping: loadedViewCards, by: { $0.categoryId ?? "" })
            self.viewsById = Dictionary(uniqueKeysWithValues: loadedViews.map { ($0.viewId, $0) })

            self.isLoaded = true
            self.loadError = nil

            print("DisplayConfigurationService: Loaded \(sectionHeaders.count) headers, \(categorySections.count) sections, \(pillars.count) pillars, \(cardCategories.count) categories, \(viewCards.count) cards, \(views.count) views, \(loadedTiers.count) tiers")

        } catch {
            self.loadError = error
            print("DisplayConfigurationService: Failed to load - \(error)")
        }
    }

    private func loadSectionHeaders() async throws -> [SectionHeaderConfig] {
        try await SupabaseManager.shared.client
            .from("display_section_headers")
            .select()
            .eq("is_active", value: true)
            .order("display_order")
            .execute()
            .value
    }

    private func loadCategorySections() async throws -> [CategorySectionConfig] {
        try await SupabaseManager.shared.client
            .from("display_category_sections")
            .select()
            .eq("is_active", value: true)
            .order("display_order")
            .execute()
            .value
    }

    private func loadPillars() async throws -> [PillarConfig] {
        try await SupabaseManager.shared.client
            .from("pillars_base")
            .select()
            .eq("is_active", value: true)
            .order("display_order")
            .execute()
            .value
    }

    private func loadCardCategories() async throws -> [CardCategoryConfig] {
        try await SupabaseManager.shared.client
            .from("display_card_categories")
            .select()
            .eq("is_active", value: true)
            .order("display_order")
            .execute()
            .value
    }

    private func loadViewCards() async throws -> [ViewCardConfig] {
        try await SupabaseManager.shared.client
            .from("display_view_cards")
            .select()
            .eq("is_active", value: true)
            .order("display_order")
            .execute()
            .value
    }

    private func loadViews() async throws -> [ViewConfig] {
        try await SupabaseManager.shared.client
            .from("display_views")
            .select()
            .eq("is_active", value: true)
            .execute()
            .value
    }

    private func loadTiers() async throws -> [DisplayTierConfig] {
        try await SupabaseManager.shared.client
            .from("display_view_tiers")
            .select()
            .order("display_order")
            .execute()
            .value
    }

    // MARK: - Section Header Accessors (Level 1)

    func sectionHeader(id: String) -> SectionHeaderConfig? {
        sectionHeadersById[id]
    }

    func categorySections(for headerId: String) -> [CategorySectionConfig] {
        categorySections
            .filter { $0.headerId == headerId }
            .sorted { ($0.displayOrder ?? 0) < ($1.displayOrder ?? 0) }
    }

    // MARK: - Category Section Accessors (Level 2)

    func categorySection(id: String) -> CategorySectionConfig? {
        categorySectionsById[id]
    }

    func categorySectionColor(for sectionId: String) -> Color {
        categorySectionsById[sectionId]?.color ?? .gray
    }

    func categorySectionIcon(for sectionId: String) -> String {
        categorySectionsById[sectionId]?.icon ?? "circle.fill"
    }

    func categorySectionName(for sectionId: String) -> String? {
        categorySectionsById[sectionId]?.sectionName
    }

    // MARK: - Pillar Accessors

    func pillar(named name: String) -> PillarConfig? {
        pillarsByName[name]
    }

    func pillarColor(for pillarName: String) -> Color {
        pillarsByName[pillarName]?.colorValue ?? .gray
    }

    func pillarIcon(for pillarName: String) -> String {
        pillarsByName[pillarName]?.iconName ?? "circle.fill"
    }

    // MARK: - Card Category Accessors (Level 3)

    func cardCategory(id: String) -> CardCategoryConfig? {
        cardCategoriesById[id]
    }

    func cardCategories(forPillar pillarName: String) -> [CardCategoryConfig] {
        cardCategories
            .filter { $0.pillar == pillarName }
            .sorted { ($0.displayOrder ?? 0) < ($1.displayOrder ?? 0) }
    }

    /// Get card categories for a category section
    func cardCategories(forSection sectionId: String) -> [CardCategoryConfig] {
        cardCategories
            .filter { $0.sectionId == sectionId }
            .sorted { ($0.displayOrder ?? 0) < ($1.displayOrder ?? 0) }
    }

    /// Get icon for card category with fallback chain: category → section → pillar
    func cardCategoryIcon(for categoryId: String) -> String {
        if let category = cardCategoriesById[categoryId] {
            if let icon = category.iconName {
                return icon
            }
            // Fallback to category section icon
            if let sectionId = category.sectionId,
               let section = categorySectionsById[sectionId] {
                return section.icon
            }
            // Fallback to pillar icon
            if let pillarName = category.pillar {
                return pillarIcon(for: pillarName)
            }
        }
        return "circle.fill"
    }

    /// Get color for card category (from category section or pillar)
    func cardCategoryColor(for categoryId: String) -> Color {
        if let category = cardCategoriesById[categoryId] {
            // First try category section color
            if let sectionId = category.sectionId,
               let section = categorySectionsById[sectionId] {
                return section.color
            }
            // Fallback to pillar color
            if let pillarName = category.pillar {
                return pillarColor(for: pillarName)
            }
        }
        return .gray
    }

    // MARK: - View Card Accessors (Level 4)

    func viewCard(id: String) -> ViewCardConfig? {
        viewCardsById[id]
    }

    /// Get all cards for a category, sorted by display_order
    func viewCards(forCategory categoryId: String) -> [ViewCardConfig] {
        (viewCardsByCategory[categoryId] ?? [])
            .sorted { ($0.displayOrder ?? 0) < ($1.displayOrder ?? 0) }
    }

    /// Get the view config for a card (for chart_type_id lookup)
    func viewForCard(_ card: ViewCardConfig) -> ViewConfig? {
        guard let viewId = card.viewId else { return nil }
        return viewsById[viewId]
    }

    // MARK: - View Accessors (Level 5)

    func view(id: String) -> ViewConfig? {
        viewsById[id]
    }

    func views(for categoryId: String) -> [ViewConfig] {
        views.filter { $0.categoryId == categoryId }
    }

    /// Get icon for view with fallback chain: view → card category → pillar
    func viewIcon(for viewId: String) -> String {
        if let view = viewsById[viewId] {
            // 1. View's own icon
            if let icon = view.iconName {
                return icon
            }
            // 2. Card category's icon
            if let categoryId = view.categoryId {
                return cardCategoryIcon(for: categoryId)
            }
            // 3. Pillar's icon
            if let pillarName = view.pillar {
                return pillarIcon(for: pillarName)
            }
        }
        return "circle.fill"
    }

    /// Get color for view (from card category's section or pillar)
    func viewColor(for viewId: String) -> Color {
        if let view = viewsById[viewId] {
            // 1. Direct pillar reference
            if let pillarName = view.pillar {
                return pillarColor(for: pillarName)
            }
            // 2. Via card category
            if let categoryId = view.categoryId {
                return cardCategoryColor(for: categoryId)
            }
        }
        return .gray
    }

    // MARK: - Tier Accessors

    func tiers(for viewId: String) -> [DisplayTierConfig] {
        (tiers[viewId] ?? []).sorted { ($0.displayOrder ?? 0) < ($1.displayOrder ?? 0) }
    }

    func tierColor(tierId: String, viewId: String) -> Color {
        if let tierList = tiers[viewId],
           let tier = tierList.first(where: { $0.tierId == tierId }) {
            return tier.colorValue
        }
        return .gray
    }

    // MARK: - Quality Tier Colors (semantic)

    /// Standard tier colors: Good (teal), Medium (blue), Poor (orange)
    var tierGood: Color { Color(hex: "#80CBC4") ?? .teal }
    var tierMedium: Color { Color(hex: "#8DD8FF") ?? .blue }
    var tierPoor: Color { Color(hex: "#EB875D") ?? .orange }

    func tierColor(for tier: Int) -> Color {
        switch tier {
        case 1: return tierGood
        case 2: return tierMedium
        case 3: return tierPoor
        default: return .gray
        }
    }
}

// MARK: - Convenience Extensions

extension DisplayConfigurationService {
    /// Generate gradient colors within a tier
    func generateGradient(from baseColor: Color, count: Int) -> [Color] {
        guard count > 0 else { return [] }
        guard count > 1 else { return [baseColor] }

        var colors: [Color] = []
        for i in 0..<count {
            let ratio = Double(i) / Double(count - 1)
            let opacity = 0.7 + (ratio * 0.3)
            colors.append(baseColor.opacity(opacity))
        }
        return colors
    }
}
