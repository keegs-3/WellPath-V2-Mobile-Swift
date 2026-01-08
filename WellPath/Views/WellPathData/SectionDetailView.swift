//
//  SectionDetailView.swift
//  WellPath
//
//  Container view for My Data section details
//  - Shows section content
//  - Top nav bar for switching sections (matches category screen style)
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
        VStack(spacing: 0) {
            // Top nav bar (matches category screen style)
            if isSearchActive {
                TopDataSectionSearchBar(
                    currentSection: selectedSection,
                    searchText: $searchText,
                    isSearchActive: $isSearchActive
                )
            } else {
                TopDataSectionNavBar(
                    currentSection: $selectedSection,
                    allSections: DataSection.allCases,
                    isSearchActive: $isSearchActive,
                    searchText: $searchText
                )
            }

            // Section content
            sectionContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .wellPathAmbientBackground(color: selectedSection.fallbackColor)
        .navigationTitle(selectedSection.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbarBackground(.hidden, for: .navigationBar)
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
        }
    }
}

// MARK: - Section Content Views

struct FavoritesSectionView: View {
    let searchText: String
    let isSearchActive: Bool
    @StateObject private var favoritesService = FavoritesService.shared
    @ObservedObject private var displayConfig = DisplayConfigurationService.shared

    private var filteredFavorites: [PatientFavorite] {
        guard !searchText.isEmpty else { return favoritesService.favorites }
        return favoritesService.favorites.filter {
            ($0.displayName ?? $0.itemId).localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Group favorites by section, maintaining section order
    private var groupedFavorites: [(sectionId: String, sectionName: String, color: Color, favorites: [PatientFavorite])] {
        // Group by sectionId (or "Other" if nil)
        var groups: [String: [PatientFavorite]] = [:]
        for favorite in filteredFavorites {
            let sectionId = favorite.sectionId ?? "OTHER"
            groups[sectionId, default: []].append(favorite)
        }

        // Convert to array with section metadata
        var result: [(sectionId: String, sectionName: String, color: Color, favorites: [PatientFavorite])] = []

        // Predefined section order (matching data sections)
        let sectionOrder = ["NAV_NUTRITION", "NAV_MOVEMENT", "NAV_SLEEP", "NAV_STRESS", "NAV_SOCIAL",
                           "NAV_BIOMARKERS", "NAV_BIOMETRICS", "NAV_ASSESSMENTS", "OTHER"]

        for sectionId in sectionOrder {
            if let favs = groups[sectionId], !favs.isEmpty {
                let sectionName = displayConfig.categorySectionName(for: sectionId) ?? sectionId.replacingOccurrences(of: "NAV_", with: "").capitalized
                let color = displayConfig.categorySectionColor(for: sectionId)
                result.append((sectionId: sectionId, sectionName: sectionName, color: color, favorites: favs))
            }
        }

        // Add any remaining sections not in predefined order
        for (sectionId, favs) in groups where !sectionOrder.contains(sectionId) && !favs.isEmpty {
            let sectionName = displayConfig.categorySectionName(for: sectionId) ?? sectionId.replacingOccurrences(of: "NAV_", with: "").capitalized
            let color = displayConfig.categorySectionColor(for: sectionId)
            result.append((sectionId: sectionId, sectionName: sectionName, color: color, favorites: favs))
        }

        return result
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
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(groupedFavorites, id: \.sectionId) { group in
                        VStack(alignment: .leading, spacing: 12) {
                            // Section header
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(group.color)
                                    .frame(width: 8, height: 8)
                                Text(group.sectionName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 4)

                            // Favorites in this section
                            ForEach(group.favorites) { favorite in
                                FavoriteRowCard(favorite: favorite)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
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
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
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
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
    }

    private var markerSections: [CategorySectionConfig] {
        displayConfig.categorySections(for: "SEC_MARKERS")
    }

    private var filteredSections: [CategorySectionConfig] {
        guard !searchText.isEmpty else { return markerSections }
        return markerSections.filter { $0.sectionName.localizedCaseInsensitiveContains(searchText) }
    }
}


// MARK: - Reusable Cards (Oura-style dark gradient)

struct PillarCategoryCard: View {
    let name: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            // Icon with subtle colored circle
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(color.opacity(0.2))
                )

            Text(name)
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0.25),
                            color.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct CategoryCard: View {
    let name: String
    let icon: String
    let color: Color
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            // Icon with subtle colored circle
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(color.opacity(0.2))
                )

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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0.25),
                            color.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
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

    /// Get the correct ID to look up in CardRegistry
    /// For screen types, use cardId if available; otherwise use itemId
    private var cardLookupId: String {
        if favorite.itemType == "screen", let cardId = favorite.cardId {
            return cardId
        }
        return favorite.itemId
    }

    var body: some View {
        // Use CardRegistry to get the proper card view with routing
        CardRegistry.card(
            for: cardLookupId,
            color: sectionColor,
            pillar: favorite.pillar ?? "",
            displayName: favorite.displayName,
            sectionId: favorite.sectionId
        )
    }
}

// MARK: - Database-Driven Category Card (Oura-style dark gradient with score ring)

struct DatabaseCategoryCard: View {
    let section: CategorySectionConfig
    var score: Int? = nil  // Optional score (0-100)

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
            // Top row: Icon + Name + Score ring
            HStack(alignment: .top) {
                // Icon with subtle colored circle
                Image(systemName: section.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(section.color)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(section.color.opacity(0.2))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(section.sectionName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(scoreLabel)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(score != nil ? scoreLabelColor : .secondary)
                }

                Spacer()

                // Score ring
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
            if let description = section.description {
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
                            section.color.opacity(0.25),
                            section.color.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(section.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Top Data Section Nav Bar (matches category screen style)

struct TopDataSectionNavBar: View {
    @Binding var currentSection: DataSection
    let allSections: [DataSection]
    @Binding var isSearchActive: Bool
    @Binding var searchText: String
    @ObservedObject private var displayConfig = DisplayConfigurationService.shared

    var body: some View {
        HStack(spacing: 12) {
            // Section icons (scrollable if needed)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(allSections) { section in
                        DataSectionNavIcon(
                            section: section,
                            isSelected: currentSection == section
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

// MARK: - Data Section Nav Icon

struct DataSectionNavIcon: View {
    let section: DataSection
    let isSelected: Bool
    let action: () -> Void
    @ObservedObject private var displayConfig = DisplayConfigurationService.shared

    private var sectionIcon: String {
        guard section != .favorites else { return "star.fill" }
        let header = displayConfig.sectionHeader(id: section.headerId)
        return header?.icon ?? section.fallbackIcon
    }

    private var sectionColor: Color {
        guard section != .favorites else { return .yellow }
        let header = displayConfig.sectionHeader(id: section.headerId)
        return header?.color ?? section.fallbackColor
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: sectionIcon)
                    .font(.system(size: 14, weight: .medium))

                if isSelected {
                    Text(section.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .padding(.horizontal, isSelected ? 12 : 10)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white.opacity(0.15) : Color.clear)
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Top Data Section Search Bar

struct TopDataSectionSearchBar: View {
    let currentSection: DataSection
    @Binding var searchText: String
    @Binding var isSearchActive: Bool
    @ObservedObject private var displayConfig = DisplayConfigurationService.shared

    private var sectionIcon: String {
        guard currentSection != .favorites else { return "star.fill" }
        let header = displayConfig.sectionHeader(id: currentSection.headerId)
        return header?.icon ?? currentSection.fallbackIcon
    }

    private var sectionColor: Color {
        guard currentSection != .favorites else { return .yellow }
        let header = displayConfig.sectionHeader(id: currentSection.headerId)
        return header?.color ?? currentSection.fallbackColor
    }

    var body: some View {
        HStack(spacing: 12) {
            // Current section icon (tap to exit search)
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isSearchActive = false
                    searchText = ""
                }
            } label: {
                Image(systemName: sectionIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(sectionColor)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(sectionColor.opacity(0.15))
                    )
            }

            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search \(currentSection.title)...", text: $searchText)
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

// MARK: - Preview

#Preview {
    NavigationStack {
        SectionDetailView(initialSection: .pillars)
    }
}
