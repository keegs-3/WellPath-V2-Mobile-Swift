//
//  BiometricCategoryScreen.swift
//  WellPath
//
//  Shows biometric metrics for a specific category
//  Updated 2025-12-01: Database-driven - queries display_views by category_id
//

import SwiftUI

enum BiometricCategory: String {
    case bodyComposition = "CAT_BIOMETRICS_BODY_COMP"
    case vitals = "CAT_BIOMETRICS_VITALS"
    case strength = "CAT_BIOMETRICS_STRENGTH"
    case fitnessMetrics = "CAT_FITNESS_METRICS"

    var title: String {
        switch self {
        case .bodyComposition: return "Body Composition"
        case .vitals: return "Vitals"
        case .strength: return "Strength"
        case .fitnessMetrics: return "Fitness Metrics"
        }
    }

    var icon: String {
        switch self {
        case .bodyComposition: return "figure.stand"
        case .vitals: return "heart.fill"
        case .strength: return "dumbbell.fill"
        case .fitnessMetrics: return "figure.run"
        }
    }

    /// The category_id used in display_card_categories and display_views
    var categoryId: String {
        self.rawValue
    }
}

struct BiometricCategoryScreen: View {
    let category: BiometricCategory
    let pillar: String
    let color: Color

    @StateObject private var viewModel: BiometricCategoryViewModel
    @EnvironmentObject private var searchState: WellPathDataSearchState
    @FocusState private var isSearchFocused: Bool

    init(category: BiometricCategory, pillar: String, color: Color) {
        self.category = category
        self.pillar = pillar
        self.color = color
        _viewModel = StateObject(wrappedValue: BiometricCategoryViewModel(categoryId: category.categoryId))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if viewModel.metrics.isEmpty {
                    emptyState
                } else {
                    metricsGrid
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
                    placeholder: "Search \(category.title.lowercased())"
                )
            }
        }
        .metricScreenBackground(color: color)
        .navigationTitle(category.title)
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
            await viewModel.loadMetrics()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: category.icon)
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No \(category.title.lowercased()) data")
                .font(.headline)
            Text("Add measurements to see them here")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 40)
    }

    @ViewBuilder
    private var metricsGrid: some View {
        ForEach(viewModel.metrics) { metric in
            BiometricMetricCard(metric: metric, color: color, pillar: pillar)
        }
    }
}

// MARK: - Database-Driven ViewModel

@MainActor
class BiometricCategoryViewModel: ObservableObject {
    let categoryId: String

    @Published var metrics: [DisplayMetric] = []
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    init(categoryId: String) {
        self.categoryId = categoryId
    }

    func loadMetrics() async {
        isLoading = true
        error = nil

        do {
            // Query display_views for this category
            let fetchedMetrics: [DisplayMetric] = try await supabase
                .from("display_views")
                .select()
                .eq("category_id", value: categoryId)
                .eq("is_active", value: true)
                .execute()
                .value

            metrics = fetchedMetrics
            print("✅ Loaded \(fetchedMetrics.count) metrics for category \(categoryId)")

        } catch {
            self.error = error.localizedDescription
            print("❌ Error loading biometric category metrics: \(error)")
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        BiometricCategoryScreen(
            category: .bodyComposition,
            pillar: "Biometrics",
            color: Color(hex: "#66CCFF") ?? .cyan
        )
    }
}
