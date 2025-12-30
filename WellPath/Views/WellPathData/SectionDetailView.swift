//
//  SectionDetailView.swift
//  WellPath
//
//  Container view for My Data section details
//  - Shows section content
//  - Contextual bottom nav for switching sections
//  - Search functionality
//

import SwiftUI

struct SectionDetailView: View {
    @State var selectedSection: DataSection
    @State private var isSearchActive = false
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    init(initialSection: DataSection) {
        _selectedSection = State(initialValue: initialSection)
    }

    var body: some View {
        ZStack {
            // Section content
            sectionContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            // Contextual bottom nav
            if isSearchActive {
                CollapsedSearchNavBar(
                    currentSection: selectedSection,
                    searchText: $searchText,
                    isSearchActive: $isSearchActive
                )
            } else {
                ContextualDataNavBar(
                    selectedSection: $selectedSection,
                    isSearchActive: $isSearchActive,
                    searchText: $searchText
                )
            }
        }
        .navigationTitle(selectedSection.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    // MARK: - Section Content

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .favorites:
            FavoritesSectionView(searchText: searchText, isSearchActive: isSearchActive)
        case .pillars:
            PillarsSectionView(searchText: searchText, isSearchActive: isSearchActive)
        case .markers:
            MarkersSectionView(searchText: searchText, isSearchActive: isSearchActive)
        case .lifestyle:
            LifestyleSectionView(searchText: searchText, isSearchActive: isSearchActive)
        case .records:
            RecordsSectionView(searchText: searchText, isSearchActive: isSearchActive)
        }
    }
}

// MARK: - Section Content Views

struct FavoritesSectionView: View {
    let searchText: String
    let isSearchActive: Bool
    @StateObject private var favoritesService = FavoritesService.shared

    private var filteredFavorites: [PatientFavorite] {
        guard !searchText.isEmpty else { return favoritesService.favorites }
        return favoritesService.favorites.filter {
            ($0.displayName ?? $0.itemId).localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ScrollView {
            if favoritesService.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
            } else if filteredFavorites.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredFavorites) { favorite in
                        FavoriteRowCard(favorite: favorite)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .task {
            await favoritesService.loadFavorites()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.fill")
                .font(.system(size: 48))
                .foregroundColor(.yellow.opacity(0.5))

            Text("No Favorites Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Pin your most-used metrics for quick access.\nTap the star on any metric to add it here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PillarsSectionView: View {
    let searchText: String
    let isSearchActive: Bool
    @ObservedObject private var displayConfig = DisplayConfigurationService.shared

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredSections) { section in
                    NavigationLink {
                        CategorySectionDetailView(section: section)
                    } label: {
                        DatabaseCategoryCard(section: section)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var pillarSections: [CategorySectionConfig] {
        displayConfig.categorySections(for: "SEC_PILLARS")
    }

    private var filteredSections: [CategorySectionConfig] {
        guard !searchText.isEmpty else { return pillarSections }
        return pillarSections.filter { $0.sectionName.localizedCaseInsensitiveContains(searchText) }
    }
}

struct MarkersSectionView: View {
    let searchText: String
    let isSearchActive: Bool
    @ObservedObject private var displayConfig = DisplayConfigurationService.shared

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredSections) { section in
                    NavigationLink {
                        CategorySectionDetailView(section: section)
                    } label: {
                        DatabaseCategoryCard(section: section)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var markerSections: [CategorySectionConfig] {
        displayConfig.categorySections(for: "SEC_MARKERS")
    }

    private var filteredSections: [CategorySectionConfig] {
        guard !searchText.isEmpty else { return markerSections }
        return markerSections.filter { $0.sectionName.localizedCaseInsensitiveContains(searchText) }
    }
}

struct LifestyleSectionView: View {
    let searchText: String
    let isSearchActive: Bool
    @ObservedObject private var displayConfig = DisplayConfigurationService.shared

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredSections) { section in
                    NavigationLink {
                        CategorySectionDetailView(section: section)
                    } label: {
                        DatabaseCategoryCard(section: section)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var lifestyleSections: [CategorySectionConfig] {
        displayConfig.categorySections(for: "SEC_LIFESTYLE")
    }

    private var filteredSections: [CategorySectionConfig] {
        guard !searchText.isEmpty else { return lifestyleSections }
        return lifestyleSections.filter { $0.sectionName.localizedCaseInsensitiveContains(searchText) }
    }
}

struct RecordsSectionView: View {
    let searchText: String
    let isSearchActive: Bool
    @ObservedObject private var displayConfig = DisplayConfigurationService.shared

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredSections) { section in
                    NavigationLink {
                        CategorySectionDetailView(section: section)
                    } label: {
                        DatabaseCategoryCard(section: section)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var recordSections: [CategorySectionConfig] {
        displayConfig.categorySections(for: "SEC_RECORDS")
    }

    private var filteredSections: [CategorySectionConfig] {
        guard !searchText.isEmpty else { return recordSections }
        return recordSections.filter { $0.sectionName.localizedCaseInsensitiveContains(searchText) }
    }
}

// MARK: - Reusable Cards

struct PillarCategoryCard: View {
    let name: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }

            Text(name)
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct CategoryCard: View {
    let name: String
    let icon: String
    let color: Color
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct FavoriteRowCard: View {
    let favorite: PatientFavorite
    @ObservedObject private var displayConfig = DisplayConfigurationService.shared

    /// Get section color from database, fall back to yellow if not found
    private var sectionColor: Color {
        guard let sectionId = favorite.sectionId else { return .yellow }
        return displayConfig.categorySectionColor(for: sectionId)
    }

    var body: some View {
        // Use CardRegistry to get the proper card view with routing
        CardRegistry.card(
            for: favorite.itemId,
            color: sectionColor,
            pillar: favorite.pillar ?? "",
            displayName: favorite.displayName,
            sectionId: favorite.sectionId
        )
    }
}

// MARK: - Database-Driven Category Card (Oura-style with gradient)

struct DatabaseCategoryCard: View {
    let section: CategorySectionConfig

    var body: some View {
        HStack(spacing: 16) {
            // Icon with gradient background
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [section.color.opacity(0.9), section.color.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)

                Image(systemName: section.icon)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(section.sectionName)
                    .font(.headline)
                    .foregroundColor(.primary)

                if let description = section.description {
                    Text(description)
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
                .shadow(color: section.color.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SectionDetailView(initialSection: .pillars)
    }
}
