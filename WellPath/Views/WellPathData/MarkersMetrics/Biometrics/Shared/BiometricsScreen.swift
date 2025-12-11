//
//  BiometricsScreen.swift
//  WellPath
//
//  Database-driven card-based layout for Biometrics
//  Loads categories and metrics dynamically from display_card_categories and display_views
//

import SwiftUI

struct BiometricsScreen: View {
    let pillar: String
    let color: Color

    @StateObject private var viewModel = BiometricsViewModel()
    @EnvironmentObject private var searchState: WellPathDataSearchState
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if viewModel.isLoading {
                    ProgressView("Loading biometrics...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if let error = viewModel.error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Unable to load biometrics")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if viewModel.categories.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No biometrics configured")
                            .font(.headline)
                        Text("Contact support if this issue persists")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 40)
                } else {
                    // Dynamically render categories and their metrics
                    ForEach(viewModel.categories) { category in
                        let metrics = viewModel.displayMetrics(for: category.categoryId)
                        if !metrics.isEmpty {
                            sectionHeader(category.name)

                            ForEach(metrics) { metric in
                                BiometricMetricCard(
                                    metric: metric,
                                    color: color,
                                    pillar: pillar
                                )
                            }
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, searchState.isSearchActive ? 80 : 24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if searchState.isSearchActive {
                WellPathDataSearchBar(
                    searchState: searchState,
                    isFocused: $isSearchFocused,
                    placeholder: "Search biometrics"
                )
            }
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Biometrics")
        .navigationBarTitleDisplayMode(.large)
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
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.top, 8)
    }
}

// BiometricMetricCard is now in Cards/BiometricMetricCard.swift
// BiometricMiniCard is now in Cards/BiometricMiniCard.swift
// BiometricFullView is now in Views/BiometricFullView.swift
// BiometricValueLoader is now in ViewModels/Biometrics/BiometricValueLoader.swift

#Preview {
    NavigationStack {
        BiometricsScreen(pillar: "Core Care", color: .cyan)
    }
}
