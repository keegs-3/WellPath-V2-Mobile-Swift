//
//  MyDataLandingView.swift
//  WellPath
//
//  My Data tab landing page with big section cards
//  - Favorites, Pillars, Markers & Metrics, Lifestyle, Records
//  - Tapping a card navigates to section detail with contextual bottom nav
//

import SwiftUI

struct MyDataLandingView: View {
    @EnvironmentObject private var displayConfig: DisplayConfigurationService
    @StateObject private var favoritesService = FavoritesService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Section cards
                ForEach(DataSection.allCases) { section in
                    NavigationLink(destination: sectionDestination(for: section)) {
                        SectionCard(section: section, favoritesCount: favoritesCount(for: section))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 100) // Space for tab bar
        }
        .background(Color(uiColor: .systemGroupedBackground))
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
    case lifestyle
    case records

    var id: String { rawValue }

    /// Maps to database section header IDs
    var headerId: String {
        switch self {
        case .favorites: return "" // Special case - not in database
        case .pillars: return "SEC_PILLARS"
        case .markers: return "SEC_MARKERS"
        case .lifestyle: return "SEC_LIFESTYLE"
        case .records: return "SEC_RECORDS"
        }
    }

    /// Title (hardcoded - database provides same values)
    var title: String {
        switch self {
        case .favorites: return "Favorites"
        case .pillars: return "Health Pillars"
        case .markers: return "Markers & Metrics"
        case .lifestyle: return "Lifestyle Factors"
        case .records: return "Health Records"
        }
    }

    var subtitle: String {
        switch self {
        case .favorites: return "Your pinned metrics"
        case .pillars: return "Nutrition, Sleep, Movement & more"
        case .markers: return "Biomarkers & Biometrics"
        case .lifestyle: return "Substances & Mental Health"
        case .records: return "History, Therapeutics & Screenings"
        }
    }

    /// Fallback icon (used if database not loaded)
    var fallbackIcon: String {
        switch self {
        case .favorites: return "star.fill"
        case .pillars: return "heart.circle.fill"
        case .markers: return "waveform.path.ecg"
        case .lifestyle: return "leaf.fill"
        case .records: return "folder.fill"
        }
    }

    /// Fallback color (used if database not loaded)
    var fallbackColor: Color {
        switch self {
        case .favorites: return .yellow
        case .pillars: return .green
        case .markers: return .blue
        case .lifestyle: return .purple
        case .records: return .orange
        }
    }
}

// MARK: - Section Card (Oura-style with gradient)

struct SectionCard: View {
    let section: DataSection
    var favoritesCount: Int = 0
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
        HStack(spacing: 16) {
            // Icon with gradient background
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [sectionColor.opacity(0.9), sectionColor.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)

                Image(systemName: sectionIcon)
                    .font(.title)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(section.title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if section == .favorites && favoritesCount > 0 {
                        Text("\(favoritesCount)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(sectionColor)
                            .clipShape(Capsule())
                    }
                }

                Text(section.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Chevron
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
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MyDataLandingView()
            .environmentObject(DisplayConfigurationService.shared)
    }
}
