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
    @State private var isSearchActive = false
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

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
                    ForEach(filteredCategories) { category in
                        NavigationLink {
                            CategoryDetailView(category: category, sectionColor: currentSection.color)
                        } label: {
                            CardCategoryCard(category: category, sectionColor: currentSection.color)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(currentSection.sectionName)
        .navigationBarTitleDisplayMode(.inline)
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
                // Icon (small, top-left)
                Image(systemName: categoryIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.2))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    // Category name
                    Text(category.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    // Score label
                    Text(scoreLabel)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(score != nil ? scoreLabelColor : .white.opacity(0.5))
                }

                Spacer()

                // Score ring (right side)
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 3)
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
                        .foregroundColor(.white)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.6))
            }

            // Description at bottom
            if let overview = category.overview {
                Text(overview)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            sectionColor.opacity(0.85),
                            sectionColor.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
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
        .background(Color(uiColor: .systemGroupedBackground))
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
                    .fill(isSelected ? section.color.opacity(0.15) : Color.clear)
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
                    .fill(Color(uiColor: .tertiarySystemGroupedBackground))
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
        .background(Color(uiColor: .systemGroupedBackground))
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
