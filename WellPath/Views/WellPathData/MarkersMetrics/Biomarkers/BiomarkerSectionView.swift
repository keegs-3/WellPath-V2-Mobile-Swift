//
//  BiomarkerSectionView.swift
//  WellPath
//
//  Shows biomarker categories in a list layout (like Biometrics)
//  Backend-driven from display_card_categories
//

import SwiftUI

struct BiomarkerSectionView: View {
    @StateObject private var viewModel = BiomarkerViewModel()
    @EnvironmentObject private var searchState: WellPathDataSearchState
    @FocusState private var isSearchFocused: Bool

    /// All biomarkers flattened for search
    private var allBiomarkers: [BiomarkerDisplayData] {
        viewModel.categories.flatMap { viewModel.biomarkers(for: $0.categoryId) }
    }

    /// Filtered biomarkers based on search text
    private var filteredBiomarkers: [BiomarkerDisplayData] {
        guard !searchState.searchText.isEmpty else { return [] }
        return allBiomarkers.filter {
            $0.name.localizedCaseInsensitiveContains(searchState.searchText)
        }
    }

    var body: some View {
        mainContent
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if searchState.isSearchActive {
                    WellPathDataSearchBar(
                        searchState: searchState,
                        isFocused: $isSearchFocused,
                        placeholder: "Search biomarkers"
                    )
                }
            }
            .metricScreenBackground(color: viewModel.sectionColor)
            .navigationTitle("Biomarkers")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
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
            .task {
                await viewModel.loadAll()
            }
            .refreshable {
                await viewModel.loadAll()
            }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading && viewModel.categories.isEmpty {
                    loadingView
                } else if searchState.isSearchActive && !searchState.searchText.isEmpty {
                    // Search results
                    searchResultsView
                } else if viewModel.categories.isEmpty {
                    emptyState
                } else {
                    // Categories list (like Biometrics)
                    categoriesListView
                }
            }
            .padding(.top, 8)
            .padding(.bottom, searchState.isSearchActive ? 80 : 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Categories List

    private var categoriesListView: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.categories) { category in
                NavigationLink(destination: BiomarkerCategoryView(
                    category: category,
                    viewModel: viewModel
                )) {
                    BiomarkerCategoryRow(
                        category: category,
                        sectionColor: viewModel.sectionColor
                    )
                }
                .buttonStyle(PlainButtonStyle())

                if category.id != viewModel.categories.last?.id {
                    Divider()
                        .padding(.leading, 72)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Search Results

    private var searchResultsView: some View {
        VStack(spacing: 12) {
            if filteredBiomarkers.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("No results for \"\(searchState.searchText)\"")
                        .font(.headline)

                    Text("Try searching for a different biomarker")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                ForEach(filteredBiomarkers) { biomarker in
                    BiomarkerCard(
                        biomarker: biomarker,
                        sectionColor: viewModel.sectionColor,
                        sectionId: "NAV_BIOMARKERS",
                        viewModel: viewModel
                    )
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Loading & Empty States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading biomarkers...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "testtube.2")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No Biomarker Data")
                .font(.headline)

            Text("Lab results will appear here when uploaded")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 32)
    }
}

// MARK: - Category Row (like Biometrics)

private struct BiomarkerCategoryRow: View {
    let category: BiomarkerCategory
    let sectionColor: Color

    var body: some View {
        HStack(spacing: 16) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(sectionColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: category.icon)
                    .font(.system(size: 20))
                    .foregroundColor(sectionColor)
            }

            // Name and description
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.primary)

                if let overview = category.overview {
                    Text(overview)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Chevrons
            HStack(spacing: -4) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(sectionColor.opacity(0.6))
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(sectionColor)
            }
        }
        .padding(.vertical, 12)
    }
}

#Preview {
    NavigationStack {
        BiomarkerSectionView()
            .environmentObject(WellPathDataSearchState.shared)
    }
}
