//
//  BiomarkerCategoryScreen.swift
//  WellPath
//
//  Direct routing wrapper for biomarker categories
//  Loads data for specific category without extra navigation level
//

import SwiftUI

struct BiomarkerCategoryScreen: View {
    let categoryId: String
    let pillar: String
    let color: Color

    @StateObject private var viewModel = BiomarkerViewModel()
    @EnvironmentObject private var searchState: WellPathDataSearchState
    @FocusState private var isSearchFocused: Bool

    private var category: BiomarkerCategory? {
        viewModel.categories.first { $0.categoryId == categoryId }
    }

    private var biomarkers: [BiomarkerDisplayData] {
        guard let category = category else { return [] }
        let categoryBiomarkers = viewModel.biomarkers(for: category.categoryId)

        if searchState.searchText.isEmpty || !searchState.isSearchActive {
            return categoryBiomarkers
        }

        return categoryBiomarkers.filter {
            $0.name.localizedCaseInsensitiveContains(searchState.searchText)
        }
    }

    private var categoryName: String {
        category?.name ?? "Biomarkers"
    }

    var body: some View {
        mainContent
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if searchState.isSearchActive {
                    WellPathDataSearchBar(
                        searchState: searchState,
                        isFocused: $isSearchFocused,
                        placeholder: "Search \(categoryName.lowercased())"
                    )
                }
            }
            .metricScreenBackground(color: color)
            .navigationTitle(categoryName)
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
            VStack(spacing: 12) {
                if viewModel.isLoading && biomarkers.isEmpty {
                    loadingView
                } else if biomarkers.isEmpty {
                    emptyState
                } else {
                    biomarkersList
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, searchState.isSearchActive ? 80 : 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Biomarkers List

    private var biomarkersList: some View {
        ForEach(biomarkers) { biomarker in
            BiomarkerCard(
                biomarker: biomarker,
                sectionColor: color,
                sectionId: category?.sectionId ?? "NAV_BIOMARKERS",
                viewModel: viewModel
            )
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading biomarkers...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "testtube.2")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.5))

            Text(searchState.searchText.isEmpty ? "No biomarker data" : "No matching biomarkers")
                .font(.headline)

            Text("Lab results will appear here when available")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    NavigationStack {
        BiomarkerCategoryScreen(
            categoryId: "CAT_BIOMARKER_CARDIO",
            pillar: "Biomarkers",
            color: .purple
        )
        .environmentObject(WellPathDataSearchState.shared)
    }
}
