//
//  DataCategoryNavBar.swift
//  WellPath
//
//  App Store / Oura-style bottom navigation for Data tab
//  - Category icons on left with underline selection
//  - Search icon on right that expands when active
//  - Favorites as first option (starred metrics)
//

import SwiftUI

enum DataCategory: Int, CaseIterable {
    case favorites = 0
    case pillars = 1
    case markers = 2
    case lifestyle = 3
    case records = 4

    var icon: String {
        switch self {
        case .favorites: return "star.fill"
        case .pillars: return "heart.circle.fill"
        case .markers: return "waveform.path.ecg"
        case .lifestyle: return "leaf.fill"
        case .records: return "folder.fill"
        }
    }

    var title: String {
        switch self {
        case .favorites: return "Favorites"
        case .pillars: return "Pillars"
        case .markers: return "Markers"
        case .lifestyle: return "Lifestyle"
        case .records: return "Records"
        }
    }

    /// Maps to database section header IDs
    var headerIds: [String] {
        switch self {
        case .favorites: return [] // Special case - handled separately
        case .pillars: return ["HDR_HEALTH_PILLARS"]
        case .markers: return ["HDR_MARKERS_METRICS"]
        case .lifestyle: return ["HDR_LIFESTYLE_FACTORS"]
        case .records: return ["HDR_HEALTH_RECORDS"]
        }
    }
}

struct DataCategoryNavBar: View {
    @Binding var selectedCategory: DataCategory
    @Binding var searchText: String
    @Binding var isSearchActive: Bool

    var body: some View {
        HStack(spacing: 0) {
            if isSearchActive {
                // Collapsed state: single icon + search field + cancel
                collapsedSearchView
            } else {
                // Normal state: category icons + search button
                normalCategoryView
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -4)
        )
    }

    // MARK: - Normal View (Categories + Search Icon)

    private var normalCategoryView: some View {
        HStack(spacing: 0) {
            // Category icons grouped on left
            HStack(spacing: 4) {
                ForEach(DataCategory.allCases, id: \.rawValue) { category in
                    CategoryTabItem(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )

            Spacer()

            // Search button isolated on right
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isSearchActive = true
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Collapsed Search View

    private var collapsedSearchView: some View {
        HStack(spacing: 12) {
            // Single category icon (current selection indicator)
            Image(systemName: "chart.bar.fill")
                .font(.title3)
                .foregroundColor(.secondary)
                .frame(width: 36, height: 36)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(Circle())

            // Expanded search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search metrics...", text: $searchText)
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
            .padding(.vertical, 10)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(Capsule())

            // Cancel button
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isSearchActive = false
                    searchText = ""
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(Circle())
            }
        }
    }
}

// MARK: - Category Tab Item

struct CategoryTabItem: View {
    let category: DataCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .green : .secondary)
                    .frame(width: 44, height: 32)

                // Underline indicator (Oura-style)
                Rectangle()
                    .fill(isSelected ? Color.green : Color.clear)
                    .frame(height: 2)
                    .frame(width: 24)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Pill (Horizontal Scrolling Selector)

struct CategoryPill: View {
    let category: DataCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 14))
                Text(category.title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundColor(isSelected ? .white : .primary)
            .background(
                Capsule()
                    .fill(isSelected ? Color.green : Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()

        DataCategoryNavBar(
            selectedCategory: .constant(.pillars),
            searchText: .constant(""),
            isSearchActive: .constant(false)
        )
    }
}

#Preview("Search Active") {
    VStack {
        Spacer()

        DataCategoryNavBar(
            selectedCategory: .constant(.pillars),
            searchText: .constant("protein"),
            isSearchActive: .constant(true)
        )
    }
}
