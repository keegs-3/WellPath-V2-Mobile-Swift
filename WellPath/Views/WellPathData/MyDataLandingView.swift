//
//  MyDataLandingView.swift
//  WellPath
//
//  My Data tab landing page with big section cards
//  - Favorites, Pillars, Markers & Metrics
//  - Tapping a card navigates to section detail with contextual bottom nav
//

import SwiftUI

struct MyDataLandingView: View {
    @EnvironmentObject private var displayConfig: DisplayConfigurationService
    @EnvironmentObject private var searchState: WellPathDataSearchState
    @StateObject private var favoritesService = FavoritesService.shared

    /// Sections to display (excludes favorites - accessible via toolbar star)
    private var displayedSections: [DataSection] {
        DataSection.allCases.filter { $0 != .favorites }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar when search is active
            if searchState.isSearchActive {
                searchBar
            }

            ScrollView {
                VStack(spacing: 12) {
                    // Section cards (favorites excluded - accessible via toolbar star)
                    ForEach(displayedSections) { section in
                        NavigationLink(destination: sectionDestination(for: section)) {
                            LandingSectionCard(section: section)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 100) // Space for tab bar
            }
        }
        .background(WellPathColors.backgroundBase.ignoresSafeArea())
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search all data...", text: $searchState.searchText)
                    .textFieldStyle(.plain)

                if !searchState.searchText.isEmpty {
                    Button {
                        searchState.clearSearchText()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(WellPathColors.cardBackground)
            .cornerRadius(12)

            Button("Cancel") {
                searchState.deactivateSearch()
            }
            .foregroundColor(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func favoritesCount(for section: DataSection) -> Int {
        guard section == .favorites else { return 0 }
        return favoritesService.favorites.count
    }

    @ViewBuilder
    private func sectionDestination(for section: DataSection) -> some View {
        SectionDetailView(initialSection: section)
    }
}

// MARK: - Data Sections

enum DataSection: String, CaseIterable, Identifiable {
    case favorites
    case pillars
    case markers

    var id: String { rawValue }

    /// Maps to database section header IDs
    var headerId: String {
        switch self {
        case .favorites: return "" // Special case - not in database
        case .pillars: return "SEC_PILLARS"
        case .markers: return "SEC_MARKERS"
        }
    }

    /// Title (hardcoded - database provides same values)
    var title: String {
        switch self {
        case .favorites: return "Favorites"
        case .pillars: return "Health Pillars"
        case .markers: return "Markers & Metrics"
        }
    }

    var subtitle: String {
        switch self {
        case .favorites: return "Your pinned metrics"
        case .pillars: return "Nutrition, Sleep, Movement & more"
        case .markers: return "Biomarkers & Biometrics"
        }
    }

    /// Fallback icon (used if database not loaded)
    var fallbackIcon: String {
        switch self {
        case .favorites: return "star.fill"
        case .pillars: return "heart.circle.fill"
        case .markers: return "waveform.path.ecg"
        }
    }

    /// Fallback color (used if database not loaded)
    var fallbackColor: Color {
        switch self {
        case .favorites: return .yellow
        case .pillars: return .green
        case .markers: return .blue
        }
    }
}

// MARK: - Landing Section Card (matches DatabaseCategoryCard aesthetic)

struct LandingSectionCard: View {
    let section: DataSection
    @ObservedObject private var displayConfig = DisplayConfigurationService.shared

    private var sectionColor: Color {
        guard section != .favorites else { return .yellow }
        let header = displayConfig.sectionHeader(id: section.headerId)
        return header?.color ?? section.fallbackColor
    }

    private var sectionIcon: String {
        guard section != .favorites else { return "star.fill" }
        let header = displayConfig.sectionHeader(id: section.headerId)
        return header?.icon ?? section.fallbackIcon
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: Icon + Name + Score ring
            HStack(alignment: .top) {
                // Small circular icon (matches DatabaseCategoryCard)
                Image(systemName: sectionIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(sectionColor)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(sectionColor.opacity(0.2))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("NOT SCORED")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Score ring placeholder
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 3)
                        .frame(width: 44, height: 44)

                    // Score text placeholder
                    Text("--")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }

            // Description
            Text(section.subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
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
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MyDataLandingView()
            .environmentObject(DisplayConfigurationService.shared)
    }
}
