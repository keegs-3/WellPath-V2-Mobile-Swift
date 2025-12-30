//
//  CategorySectionDetailView.swift
//  WellPath
//
//  Detail view for a category section (e.g., Nutrition, Sleep)
//  Shows card categories within the section with scrollable bottom nav
//

import SwiftUI

struct CategorySectionDetailView: View {
    let section: CategorySectionConfig
    @ObservedObject private var displayConfig = DisplayConfigurationService.shared
    @State private var isSearchActive = false
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredCategories) { category in
                    NavigationLink {
                        CategoryDetailView(category: category, sectionColor: section.color)
                    } label: {
                        CardCategoryCard(category: category, sectionColor: section.color)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            if isSearchActive {
                CollapsedCategorySearchBar(
                    currentSection: section,
                    searchText: $searchText,
                    isSearchActive: $isSearchActive
                )
            } else {
                ScrollableCategoryNavBar(
                    currentSection: section,
                    allSections: siblingsSections,
                    isSearchActive: $isSearchActive,
                    searchText: $searchText
                )
            }
        }
        .navigationTitle(section.sectionName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var cardCategories: [CardCategoryConfig] {
        displayConfig.cardCategories(forSection: section.sectionId)
    }

    private var filteredCategories: [CardCategoryConfig] {
        guard !searchText.isEmpty else { return cardCategories }
        return cardCategories.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    /// Get all sibling sections under the same header for the scrollable nav
    private var siblingsSections: [CategorySectionConfig] {
        displayConfig.categorySections(for: section.headerId)
    }
}

// MARK: - Card Category Card (Oura-style with gradient)

struct CardCategoryCard: View {
    let category: CardCategoryConfig
    let sectionColor: Color
    @ObservedObject private var displayConfig = DisplayConfigurationService.shared

    var body: some View {
        HStack(spacing: 16) {
            // Icon with gradient background
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [sectionColor.opacity(0.9), sectionColor.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)

                Image(systemName: categoryIcon)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                if let overview = category.overview {
                    Text(overview)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: sectionColor.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }

    private var categoryIcon: String {
        displayConfig.cardCategoryIcon(for: category.categoryId)
    }
}

// MARK: - Scrollable Category Nav Bar

struct ScrollableCategoryNavBar: View {
    let currentSection: CategorySectionConfig
    let allSections: [CategorySectionConfig]
    @Binding var isSearchActive: Bool
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 16) {
            // Left bubble: Scrollable section icons
            sectionsBubble

            // Right bubble: Search
            searchBubble
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Sections Bubble (Scrollable)

    private var sectionsBubble: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(allSections) { section in
                    ScrollableSectionNavIcon(
                        section: section,
                        isSelected: currentSection.sectionId == section.sectionId
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity)
        .background(glassBackground(cornerRadius: 25))
    }

    // MARK: - Search Bubble

    private var searchBubble: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                isSearchActive = true
            }
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .frame(width: 50, height: 50)
        }
        .background(glassBackground(cornerRadius: 16))
    }

    // MARK: - Glass Background

    @ViewBuilder
    private func glassBackground(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26, *) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.clear)
                .glassEffect()
        } else {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
        }
    }
}

// MARK: - Scrollable Section Nav Icon

struct ScrollableSectionNavIcon: View {
    let section: CategorySectionConfig
    let isSelected: Bool

    var body: some View {
        NavigationLink {
            CategorySectionDetailView(section: section)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: section.icon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? section.color : .secondary)
                    .frame(width: 40, height: 24)

                // Underline indicator
                Rectangle()
                    .fill(isSelected ? section.color : Color.clear)
                    .frame(width: 20, height: 2)
                    .cornerRadius(1)
            }
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

    var body: some View {
        // Route directly to the actual screen for this category
        CategoryScreenRouter.destinationView(
            for: category.categoryId,
            pillar: category.pillar ?? "",
            color: sectionColor,
            sectionId: category.sectionId ?? ""
        )
    }
}

// MARK: - Category Screen Router

/// Routes category IDs to their actual *Screen.swift views
enum CategoryScreenRouter {
    @ViewBuilder
    static func destinationView(for categoryId: String, pillar: String, color: Color, sectionId: String) -> some View {
        switch categoryId {
        // Nutrition
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

        // Sleep
        case "CAT_SLEEP_ANALYSIS":
            SleepAnalysisScreen(pillar: pillar, color: color)
        case "CAT_SLEEP_SCORE":
            SleepScoreScreen(color: color, pillar: pillar, sectionId: sectionId)

        // Movement
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

        // Cognitive
        case "CAT_BRAIN_TRAINING":
            CognitiveScreen(pillar: pillar, color: color, sectionId: sectionId)

        // Connection
        case "CAT_SOCIAL":
            SocialScreen(pillar: pillar, color: color, sectionId: sectionId)
        case "CAT_OUTDOOR_TIME":
            OutdoorTimeScreen(pillar: pillar, color: color, sectionId: sectionId)

        // Default fallback
        default:
            CategoryPlaceholderView(categoryId: categoryId, color: color)
        }
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
        .background(Color(uiColor: .systemGroupedBackground))
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
        .background(Color(uiColor: .secondarySystemGroupedBackground))
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
        .background(Color(uiColor: .systemGroupedBackground))
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
