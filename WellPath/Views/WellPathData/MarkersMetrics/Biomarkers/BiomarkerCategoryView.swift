//
//  BiomarkerCategoryView.swift
//  WellPath
//
//  Shows all biomarkers within a specific category
//  Uses shared BiomarkerViewModel for data
//

import SwiftUI

struct BiomarkerCategoryView: View {
    let category: BiomarkerCategory
    @ObservedObject var viewModel: BiomarkerViewModel
    @EnvironmentObject private var searchState: WellPathDataSearchState
    @FocusState private var isSearchFocused: Bool

    private var biomarkers: [BiomarkerDisplayData] {
        let categoryBiomarkers = viewModel.biomarkers(for: category.categoryId)

        if searchState.searchText.isEmpty || !searchState.isSearchActive {
            return categoryBiomarkers
        }

        return categoryBiomarkers.filter {
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
                        placeholder: "Search \(category.name.lowercased())"
                    )
                }
            }
            .metricScreenBackground(color: viewModel.sectionColor)
            .navigationTitle(category.name)
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
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                if viewModel.isLoading {
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
                sectionColor: viewModel.sectionColor,
                sectionId: category.sectionId ?? "NAV_BIOMARKERS",
                viewModel: viewModel
            )
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: category.icon)
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.5))

            Text(searchState.searchText.isEmpty ? "No \(category.name.lowercased()) markers" : "No matching biomarkers")
                .font(.headline)

            Text("Lab results will appear here when available")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Biomarker Card (Oura-style dark gradient)

struct BiomarkerCard: View {
    let biomarker: BiomarkerDisplayData
    let sectionColor: Color
    let sectionId: String  // For favorites: NAV_BIOMARKERS
    @ObservedObject var viewModel: BiomarkerViewModel

    private var statusLabel: String {
        biomarker.status.rawValue.uppercased()
    }

    private var statusColor: Color {
        biomarker.status.color
    }

    /// Format the date for display
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: biomarker.lastUpdated)
    }

    var body: some View {
        NavigationLink {
            GenericBiomarkerDetailView(
                biomarkerName: biomarker.name,
                viewModel: viewModel
            )
            .navigationTitle(biomarker.name)
            .navigationBarTitleDisplayMode(.large)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Top row: Name + Favorite + Chevron
                HStack {
                    Text(biomarker.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    FavoriteButton(
                        itemType: .biomarker,
                        itemId: biomarker.viewId ?? biomarker.cardId,
                        displayName: biomarker.name,
                        pillar: "Biomarker",
                        cardId: biomarker.cardId,
                        sectionId: sectionId,
                        size: .compact
                    )

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }

                // Content row: Icon + Value + Range
                HStack(spacing: 16) {
                    // Icon in circle
                    Image(systemName: "testtube.2")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(sectionColor)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(sectionColor.opacity(0.2))
                        )

                    // Value and date
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(biomarker.formattedValue)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            if !biomarker.unitDisplay.isEmpty {
                                Text(biomarker.unitDisplay)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Text(formattedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Status and range indicator
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(statusLabel)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(statusColor)

                        if !biomarker.rangeSegments.isEmpty {
                            RangeIndicatorView(
                                segments: biomarker.rangeSegments,
                                patientValue: biomarker.value
                            )
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        sectionColor.opacity(0.15),
                                        sectionColor.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(sectionColor.opacity(0.25), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Biomarker Mini Card (content inside MetricCardView)

struct BiomarkerMiniCard: View {
    let biomarker: BiomarkerDisplayData
    let color: Color

    /// Format the date for display
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: biomarker.lastUpdated)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon in circle (matches BiometricMiniCard)
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "testtube.2")
                    .font(.title3)
                    .foregroundColor(color)
            }

            // Value and description
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(biomarker.formattedValue)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    if !biomarker.unitDisplay.isEmpty {
                        Text(biomarker.unitDisplay)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Date of last value
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status indicator with range bar
            VStack(alignment: .trailing, spacing: 4) {
                Text(biomarker.status.rawValue.uppercased())
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if !biomarker.rangeSegments.isEmpty {
                    RangeIndicatorView(
                        segments: biomarker.rangeSegments,
                        patientValue: biomarker.value
                    )
                } else {
                    Circle()
                        .fill(biomarker.status.color)
                        .frame(width: 10, height: 10)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        BiomarkerCategoryView(
            category: BiomarkerCategory(
                id: UUID(),
                categoryId: "CAT_BIOMARKER_CARDIO",
                name: "Cardiovascular Health",
                overview: nil,
                pillar: nil,
                sectionId: "NAV_BIOMARKERS",
                iconName: "heart.circle.fill",
                displayOrder: 1,
                isActive: true
            ),
            viewModel: BiomarkerViewModel()
        )
        .environmentObject(WellPathDataSearchState.shared)
    }
}
