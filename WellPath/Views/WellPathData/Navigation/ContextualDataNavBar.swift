//
//  ContextualDataNavBar.swift
//  WellPath
//
//  Contextual bottom nav for My Data section details
//  Left bubble: Section icons with underline selection
//  Right bubble: Search icon
//

import SwiftUI

struct ContextualDataNavBar: View {
    @Binding var selectedSection: DataSection
    @Binding var isSearchActive: Bool
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 24) {
            // Left bubble: Section icons
            sectionsBubble

            // Right bubble: Search
            searchBubble
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Sections Bubble

    private var sectionsBubble: some View {
        HStack(spacing: 4) {
            ForEach(DataSection.allCases) { section in
                SectionNavIcon(
                    section: section,
                    isSelected: selectedSection == section
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSection = section
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
                .frame(width: 66, height: 66)
        }
        .background(glassBackground(cornerRadius: 22))
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

// MARK: - Section Nav Icon

struct SectionNavIcon: View {
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
            VStack(spacing: 4) {
                Image(systemName: sectionIcon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? sectionColor : .secondary)
                    .frame(width: 40, height: 24)

                // Underline indicator
                Rectangle()
                    .fill(isSelected ? sectionColor : Color.clear)
                    .frame(width: 20, height: 2)
                    .cornerRadius(1)
            }
            .frame(minWidth: 48, minHeight: 48) // Minimum tap target
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Collapsed Search State

struct CollapsedSearchNavBar: View {
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
            // Collapsed section icon (tap to exit search)
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isSearchActive = false
                    searchText = ""
                }
            } label: {
                Image(systemName: sectionIcon)
                    .font(.title3)
                    .foregroundColor(sectionColor)
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

            TextField("Search...", text: $searchText)
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

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            Spacer()
            ContextualDataNavBar(
                selectedSection: .constant(.pillars),
                isSearchActive: .constant(false),
                searchText: .constant("")
            )
        }
    }
}

#Preview("Search Active") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            Spacer()
            CollapsedSearchNavBar(
                currentSection: .pillars,
                searchText: .constant("protein"),
                isSearchActive: .constant(true)
            )
        }
    }
}
