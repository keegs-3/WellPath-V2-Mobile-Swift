//
//  BiometricsList.swift
//  WellPath
//
//  List view for all biometrics
//  Uses shared search state from parent navigation
//

import SwiftUI

struct BiometricsList: View {
    @StateObject private var viewModel = MetricsViewModel()
    @EnvironmentObject private var searchState: WellPathDataSearchState
    @FocusState private var isSearchFocused: Bool

    private let sectionColor = Color(red: 0.40, green: 0.80, blue: 1.0)

    // Metrics that exist in both biometrics AND TrackedMetrics (hide from this list)
    private let duplicateMetrics = [
        "Steps/Day",
        "Deep Sleep",
        "REM Sleep",
        "Total Sleep",
        "Water Intake"
    ]

    var filteredBiometrics: [BiometricCardData] {
        // First filter out duplicates that exist in TrackedMetrics
        let uniqueBiometrics = viewModel.biometricCards.filter { card in
            !duplicateMetrics.contains(card.name)
        }

        // Then apply search filter if search is active
        if searchState.searchText.isEmpty || !searchState.isSearchActive {
            return uniqueBiometrics
        }
        return uniqueBiometrics.filter { $0.name.localizedCaseInsensitiveContains(searchState.searchText) }
    }

    var body: some View {
        mainContent
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if searchState.isSearchActive {
                    WellPathDataSearchBar(
                        searchState: searchState,
                        isFocused: $isSearchFocused,
                        placeholder: "Search biometrics"
                    )
                }
            }
            .metricScreenBackground(color: sectionColor)
            .navigationTitle("Biometrics")
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
                await viewModel.loadBiometrics()
            }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView("Loading biometrics...")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if filteredBiometrics.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(searchState.searchText.isEmpty ? "No biometrics available" : "No matching biometrics")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
            } else {
                VStack(spacing: 12) {
                    ForEach(filteredBiometrics) { card in
                        NavigationLink(destination: BiometricRouter(
                            biometricName: card.name,
                            color: sectionColor
                        )) {
                            // Simple row card for list
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(card.name)
                                        .font(.headline)
                                    Text(card.value)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, searchState.isSearchActive ? 80 : 24)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    func getStatusColor(_ status: String) -> Color {
        switch status {
        case "Out-of-Range": return .red
        case "In-Range": return .blue
        case "Optimal": return .green
        default: return .gray
        }
    }
}

#Preview {
    NavigationStack {
        BiometricsList()
            .environmentObject(WellPathDataSearchState.shared)
    }
}
