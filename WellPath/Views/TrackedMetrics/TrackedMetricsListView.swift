//
//  TrackedMetricsListView.swift
//  WellPath
//
//  Created on 2025-10-22
//

import SwiftUI

// MARK: - View Registry
// Central registry for custom metric views - eliminates duplicate navigation logic
struct MetricViewRegistry {
    typealias ViewFactory = (String, Color) -> AnyView

    private static let registry: [String: ViewFactory] = [
        // Restorative Sleep
        "SCREEN_SLEEP": { pillar, color in
            AnyView(SleepDurationPrimary(pillar: pillar, color: color))
        },
        "SCREEN_SLEEP_ANALYSIS": { pillar, color in
            AnyView(SleepAnalysisScreen(pillar: pillar, color: color))
        },
        "SCREEN_SLEEP_CONSISTENCY": { pillar, color in
            AnyView(SleepConsistencyPrimary(pillar: pillar, color: color))
        },

        // Healthful Nutrition
        "SCREEN_PROTEIN": { pillar, color in
            AnyView(ProteinScreen(pillar: pillar, color: color))
        },
        "SCREEN_LEGUMES": { pillar, color in
            AnyView(LegumesScreen(pillar: pillar, color: color))
        },
        "SCREEN_LEGUMES_PRIMARY": { pillar, color in
            AnyView(LegumesScreen(pillar: pillar, color: color))
        },
        "SCREEN_VEGETABLES": { pillar, color in
            AnyView(VegetablesScreen(pillar: pillar, color: color))
        },
        "SCREEN_VEGETABLES_PRIMARY": { pillar, color in
            AnyView(VegetablesScreen(pillar: pillar, color: color))
        },
        "SCREEN_WHOLE_GRAINS": { pillar, color in
            AnyView(WholeGrainsScreen(pillar: pillar, color: color))
        },
        "SCREEN_WHOLE_GRAINS_PRIMARY": { pillar, color in
            AnyView(WholeGrainsScreen(pillar: pillar, color: color))
        },
        "SCREEN_FRUITS": { pillar, color in
            AnyView(FruitsScreen(pillar: pillar, color: color))
        },
        "SCREEN_FRUITS_PRIMARY": { pillar, color in
            AnyView(FruitsScreen(pillar: pillar, color: color))
        },

        // Movement + Exercise
        "SCREEN_STEPS": { pillar, color in
            AnyView(StepsScreen(pillar: pillar, color: color))
        },
        "SCREEN_STRENGTH": { pillar, color in
            AnyView(StrengthTrainingScreen(pillar: pillar, color: color))
        },
        "SCREEN_STRENGTH_TRAINING": { pillar, color in
            AnyView(StrengthTrainingScreen(pillar: pillar, color: color))
        },

        // Core Care
        "SCREEN_BIOMETRICS": { pillar, color in
            AnyView(BiometricsScreen(pillar: pillar, color: color))
        },

        // Bio3 - Biometrics Categories
        "SCREEN_BIOMETRICS_BODY_COMP": { pillar, color in
            AnyView(BiometricCategoryScreen(category: .bodyComposition, pillar: pillar, color: color))
        },
        "SCREEN_BIOMETRICS_CARDIO": { pillar, color in
            AnyView(BiometricCategoryScreen(category: .cardiovascular, pillar: pillar, color: color))
        },
        "SCREEN_BIOMETRICS_STRENGTH": { pillar, color in
            AnyView(BiometricCategoryScreen(category: .strength, pillar: pillar, color: color))
        },

        // Bio3 - Biomarkers Categories
        "SCREEN_BIOMARKERS": { pillar, color in
            AnyView(BiomarkersScreen(pillar: pillar, color: color))
        },
        "SCREEN_BIOMARKERS_CARDIO": { pillar, color in
            AnyView(BiomarkerCategoryScreen(category: .cardiovascular, pillar: pillar, color: color))
        },
        "SCREEN_BIOMARKERS_METABOLISM": { pillar, color in
            AnyView(BiomarkerCategoryScreen(category: .metabolism, pillar: pillar, color: color))
        },
        "SCREEN_BIOMARKERS_INFLAMMATION": { pillar, color in
            AnyView(BiomarkerCategoryScreen(category: .inflammation, pillar: pillar, color: color))
        },
        "SCREEN_BIOMARKERS_HORMONES": { pillar, color in
            AnyView(BiomarkerCategoryScreen(category: .hormones, pillar: pillar, color: color))
        },
        "SCREEN_BIOMARKERS_IMMUNE": { pillar, color in
            AnyView(BiomarkerCategoryScreen(category: .immune, pillar: pillar, color: color))
        },

        // Bio3 - Biological Age
        "SCREEN_BIOLOGICAL_AGE": { pillar, color in
            AnyView(BiologicalAgeScreen(pillar: pillar, color: color))
        }
    ]

    /// Get custom view for screen, or nil if should use fallback MetricDetailView
    static func getView(for screen: DisplayScreen, pillar: String, color: Color) -> AnyView? {
        return registry[screen.screenId]?(pillar, color)
    }

    /// Get custom view for screen by ID directly
    static func getView(forScreenId screenId: String, pillar: String, color: Color) -> AnyView? {
        return registry[screenId]?(pillar, color)
    }
}

struct TrackedMetricsListView: View {
    @StateObject private var viewModel = TrackedMetricsViewModel()
    @StateObject private var favoritesService = FavoritesService.shared
    @State private var showingFavorites = true  // Default to favorites
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.error {
                    errorView(error)
                } else if showingFavorites {
                    favoritesView
                } else {
                    browseView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom search bar (when in browse/search mode)
            if !showingFavorites {
                bottomSearchBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(backgroundView)
        .navigationTitle("Data")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            // Star button on LEFT - show favorites
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    withAnimation {
                        showingFavorites = true
                        searchText = ""
                    }
                } label: {
                    Image(systemName: showingFavorites ? "star.fill" : "star")
                        .foregroundColor(showingFavorites ? .yellow : .primary)
                }
            }

            // Search button on RIGHT - show browse/search view
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation {
                        showingFavorites = false
                        isSearchFocused = true
                    }
                } label: {
                    Image(systemName: !showingFavorites ? "magnifyingglass.circle.fill" : "magnifyingglass")
                        .foregroundColor(!showingFavorites ? .accentColor : .primary)
                }
            }
        }
        .task {
            await viewModel.loadMetricsData()
            await favoritesService.loadFavorites()
        }
    }

    // MARK: - Floating Search Bar

    private var bottomSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)

            TextField("Search metrics", text: $searchText)
                .font(.subheadline)
                .autocorrectionDisabled()
                .focused($isSearchFocused)
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal, 50)
        .padding(.bottom, 16)
    }

    // MARK: - Favorites View (grouped by pillar)

    private var favoritesView: some View {
        ScrollView {
            VStack(spacing: 20) {
                if favoritesService.favorites.isEmpty {
                    emptyFavoritesPrompt
                } else {
                    // Group favorites by pillar
                    ForEach(favoritesByPillar, id: \.pillar) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            // Pillar header
                            HStack(spacing: 8) {
                                Image(systemName: MetricsUIConfig.getPillarIcon(for: group.pillar))
                                    .foregroundColor(MetricsUIConfig.getPillarColor(for: group.pillar))
                                Text(group.pillar)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 4)

                            // Favorites in this pillar
                            VStack(spacing: 0) {
                                ForEach(Array(group.favorites.enumerated()), id: \.element.id) { index, favorite in
                                    NavigationLink(destination: favoriteDestination(for: favorite)) {
                                        FavoriteRow(favorite: favorite)
                                    }
                                    .buttonStyle(PlainButtonStyle())

                                    if index < group.favorites.count - 1 {
                                        Divider()
                                            .padding(.horizontal, 16)
                                    }
                                }
                            }
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .cornerRadius(12)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    private var emptyFavoritesPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.fill")
                .font(.system(size: 48))
                .foregroundColor(.yellow.opacity(0.7))

            Text("No Favorites Yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Pin your most-used metrics for quick access.\nTap the star on any metric to add it here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                withAnimation {
                    showingFavorites = false
                }
            } label: {
                Text("Browse Metrics")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(10)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Browse View (Compact list style with search filtering)

    private var browseView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Show search results if searching
                if !searchText.isEmpty {
                    searchResultsContent
                } else {
                    // Pillars Section - compact list
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pillars")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            ForEach(Array(filteredPillars.enumerated()), id: \.element.id) { index, pillar in
                                NavigationLink(destination: PillarScreensView(pillar: pillar.name, viewModel: viewModel)) {
                                    PillarListRow(pillar: pillar)
                                }
                                .buttonStyle(PlainButtonStyle())

                                if index < filteredPillars.count - 1 {
                                    Divider()
                                        .padding(.horizontal, 12)
                                }
                            }
                        }
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }

                    // Markers & Metrics Section - compact list
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Markers & Metrics")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            NavigationLink(destination: BiomarkersScreen(pillar: "Core Care", color: .purple)) {
                                PillarListRow(pillar: PillarItem(name: "Biomarkers", icon: "testtube.2", color: .purple, screenCount: 0))
                            }
                            .buttonStyle(PlainButtonStyle())

                            Divider()
                                .padding(.horizontal, 12)

                            NavigationLink(destination: BiometricsScreen(pillar: "Core Care", color: .cyan)) {
                                PillarListRow(pillar: PillarItem(name: "Biometrics", icon: "waveform.path.ecg", color: .cyan, screenCount: 0))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }

                    // Health History Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Health History")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            NavigationLink(destination: MedicalHistoryListView()) {
                                PillarListRow(pillar: PillarItem(name: "Medical History", icon: "cross.case.fill", color: .red, screenCount: 0))
                            }
                            .buttonStyle(PlainButtonStyle())

                            Divider()
                                .padding(.horizontal, 12)

                            NavigationLink(destination: PreventiveScreeningsView()) {
                                PillarListRow(pillar: PillarItem(name: "Preventive Screenings", icon: "stethoscope", color: .teal, screenCount: 0))
                            }
                            .buttonStyle(PlainButtonStyle())

                            Divider()
                                .padding(.horizontal, 12)

                            NavigationLink(destination: TherapeuticsListView()) {
                                PillarListRow(pillar: PillarItem(name: "Therapeutics", icon: "pills.fill", color: .blue, screenCount: 0))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 60) // Space for floating search bar
        }
    }

    // MARK: - Search Results Content

    @ViewBuilder
    private var searchResultsContent: some View {
        if allMatchingScreens.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No results for \"\(searchText)\"")
                    .font(.headline)
                Text("Try searching for a different metric")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 80)
        } else {
            // Group results by pillar
            ForEach(searchResultsByPillar, id: \.pillar) { result in
                VStack(alignment: .leading, spacing: 8) {
                    // Pillar header
                    HStack(spacing: 8) {
                        Image(systemName: MetricsUIConfig.getPillarIcon(for: result.pillar))
                            .foregroundColor(MetricsUIConfig.getPillarColor(for: result.pillar))
                        Text(result.pillar)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 4)

                    // Matching screens
                    VStack(spacing: 0) {
                        ForEach(Array(result.screens.enumerated()), id: \.element.id) { index, screen in
                            NavigationLink(destination: screenDestination(for: screen, pillar: result.pillar)) {
                                SearchResultRow(
                                    screen: screen,
                                    pillar: result.pillar,
                                    searchText: searchText
                                )
                            }
                            .buttonStyle(PlainButtonStyle())

                            if index < result.screens.count - 1 {
                                Divider()
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
            }
        }
    }

    // All screens matching search across all pillars
    private var allMatchingScreens: [DisplayScreen] {
        guard !searchText.isEmpty else { return [] }
        return viewModel.allScreens.filter { screen in
            screen.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    // Search results grouped by pillar
    private var searchResultsByPillar: [(pillar: String, screens: [DisplayScreen])] {
        guard !searchText.isEmpty else { return [] }

        var results: [(String, [DisplayScreen])] = []

        for pillar in viewModel.pillars {
            let screens = viewModel.getScreens(forPillar: pillar)
            let matchingScreens = screens.filter { screen in
                screen.name.localizedCaseInsensitiveContains(searchText)
            }

            if !matchingScreens.isEmpty {
                results.append((pillar, matchingScreens))
            }
        }

        return results
    }

    // Only show the 7 health pillars (exclude Biometrics, Biomarkers, Biological Age)
    // Biometrics/Biomarkers are in "Markers & Metrics" section
    // Biological Age will be on Dashboard
    private let excludedFromPillars = ["Biometrics", "Biomarkers", "Biological Age"]

    private var filteredPillars: [PillarItem] {
        viewModel.pillars
            .filter { !excludedFromPillars.contains($0) }
            .map { pillar in
                let screens = viewModel.getScreens(forPillar: pillar)
                return PillarItem(
                    name: pillar,
                    icon: MetricsUIConfig.getPillarIcon(for: pillar),
                    color: MetricsUIConfig.getPillarColor(for: pillar),
                    screenCount: screens.count
                )
            }
    }

    // Group favorites by pillar for sectioned display
    private var favoritesByPillar: [(pillar: String, favorites: [PatientFavorite])] {
        var grouped: [String: [PatientFavorite]] = [:]

        for favorite in favoritesService.favorites {
            let pillar = favorite.pillar ?? "Other"
            if grouped[pillar] == nil {
                grouped[pillar] = []
            }
            grouped[pillar]?.append(favorite)
        }

        // Sort by pillar name, with "Other" at the end
        return grouped.sorted { lhs, rhs in
            if lhs.key == "Other" { return false }
            if rhs.key == "Other" { return true }
            return lhs.key < rhs.key
        }.map { (pillar: $0.key, favorites: $0.value) }
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Unable to load data")
                .font(.headline)
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") {
                Task {
                    await viewModel.loadMetricsData()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)

            VStack(spacing: 0) {
                LinearGradient(
                    colors: [
                        Color(red: 0.56, green: 0.82, blue: 0.31).opacity(0.65),
                        Color(red: 0.56, green: 0.82, blue: 0.31).opacity(0.45),
                        Color(red: 0.56, green: 0.82, blue: 0.31).opacity(0.25),
                        Color(red: 0.56, green: 0.82, blue: 0.31).opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 900)

                Spacer()
            }

            VStack {
                HStack {
                    Spacer()
                    Image("white_grey")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .opacity(0.35)
                        .rotationEffect(.degrees(-15))
                        .offset(x: 40, y: 20)
                }
                Spacer()
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Navigation Helpers

    @ViewBuilder
    private func screenDestination(for screen: DisplayScreen, pillar: String) -> some View {
        let color = MetricsUIConfig.getPillarColor(for: pillar)

        if let customView = MetricViewRegistry.getView(for: screen, pillar: pillar, color: color) {
            customView
        } else {
            GenericMetricScreen(screen: screen, pillar: pillar, color: color)
        }
    }

    @ViewBuilder
    private func favoriteDestination(for favorite: PatientFavorite) -> some View {
        let pillar = favorite.pillar ?? "Core Care"
        let color = MetricsUIConfig.getPillarColor(for: pillar)

        switch favorite.itemType {
        case "screen":
            screenFavoriteDestination(itemId: favorite.itemId, pillar: pillar, color: color)
        case "metric":
            metricFavoriteDestination(itemId: favorite.itemId, pillar: pillar, color: color)
        case "biomarker":
            BiomarkerDetailView(name: favorite.itemId, isBiometric: false)
        case "biometric":
            BiomarkerDetailView(name: favorite.itemId, isBiometric: true)
        default:
            Text("Unknown favorite type")
        }
    }

    @ViewBuilder
    private func screenFavoriteDestination(itemId: String, pillar: String, color: Color) -> some View {
        if let customView = MetricViewRegistry.getView(forScreenId: itemId, pillar: pillar, color: color) {
            customView
        } else if let screen = viewModel.allScreens.first(where: { $0.screenId == itemId }) {
            GenericMetricScreen(screen: screen, pillar: pillar, color: color)
        } else {
            Text("Screen not found")
        }
    }

    @ViewBuilder
    private func metricFavoriteDestination(itemId: String, pillar: String, color: Color) -> some View {
        // Direct mapping for specific metrics with custom views
        switch itemId {
        case "DISP_PROTEIN_GRAMS":
            ProteinAmountFavoriteView(color: color)
        case "DISP_PROTEIN_TIMING":
            ProteinTimingView(color: color)
                .navigationTitle("Protein Timing")
        case "DISP_PROTEIN_TYPE":
            ProteinTiersView(color: color)
                .navigationTitle("Protein Type")
        case "DISP_PROTEIN_RATIO":
            ProteinPerBodyWeightView(color: color)
                .navigationTitle("Protein Ratio")
        case "DISP_VEGETABLES_SERVINGS":
            VegetablesScreen(pillar: pillar, color: color)
        default:
            // Check screen mapping
            if let screenId = metricToScreenMapping[itemId],
               let customView = MetricViewRegistry.getView(forScreenId: screenId, pillar: pillar, color: color) {
                customView
            } else {
                MetricFavoriteDetailView(metricId: itemId, pillar: pillar, color: color)
            }
        }
    }

    // Map display metric IDs to their parent screen IDs (for screens with single metric)
    private var metricToScreenMapping: [String: String] {
        [
            // Sleep metrics → Sleep screens
            "DISP_SLEEP_DURATION": "SCREEN_SLEEP",
            "DISP_SLEEP_ANALYSIS": "SCREEN_SLEEP_ANALYSIS",
            "DISP_SLEEP_STAGES": "SCREEN_SLEEP_ANALYSIS",
            "DISP_SLEEP_STAGE_AMOUNTS": "SCREEN_SLEEP_ANALYSIS",
            "DISP_SLEEP_STAGE_PERCENTAGES": "SCREEN_SLEEP_ANALYSIS",
            "DISP_SLEEP_COMPARISONS": "SCREEN_SLEEP_ANALYSIS",
            "DISP_SLEEP_CONSISTENCY": "SCREEN_SLEEP_CONSISTENCY",
            // Steps → Steps screen
            "DISP_STEPS": "SCREEN_STEPS",
            // Strength → Strength screen
            "DISP_STRENGTH_TRAINING": "SCREEN_STRENGTH",
            // Nutrition screens (servings → their screens)
            "DISP_LEGUMES": "SCREEN_LEGUMES",
            "DISP_VEGETABLES": "SCREEN_VEGETABLES",
            "DISP_WHOLE_GRAINS": "SCREEN_WHOLE_GRAINS",
            "DISP_FRUITS": "SCREEN_FRUITS"
        ]
    }
}

// MARK: - Wrapper view for Protein Amount favorite (manages its own @StateObject)
struct ProteinAmountFavoriteView: View {
    let color: Color
    @StateObject private var viewModel = ProteinPrimaryViewModel(metricId: "DISP_PROTEIN_GRAMS")

    var body: some View {
        ProteinAmountFullView(color: color, viewModel: viewModel)
            .navigationTitle("Protein Amount")
            .task {
                await viewModel.loadPrimaryScreen()
            }
    }
}

// MARK: - Metric Favorite Detail View (fallback for unmapped metrics)

struct MetricFavoriteDetailView: View {
    let metricId: String
    let pillar: String
    let color: Color

    @StateObject private var viewModel = MetricFavoriteDetailViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let metric = viewModel.metric {
                ParentMetricBarChart(metric: metric, color: color, showAbout: .constant(false))
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Metric not found")
                        .font(.headline)
                    Text(metricId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [color.opacity(0.65), color.opacity(0.45), color.opacity(0.25), color.opacity(0.1), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 900)
                    Spacer()
                }
            }
            .ignoresSafeArea()
        )
        .navigationTitle(viewModel.metric?.metricName ?? "Metric")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadMetric(metricId: metricId)
        }
    }
}

@MainActor
class MetricFavoriteDetailViewModel: ObservableObject {
    @Published var metric: DisplayMetric?
    @Published var isLoading = false

    private let supabase = SupabaseManager.shared.client

    func loadMetric(metricId: String) async {
        isLoading = true
        do {
            let metrics: [DisplayMetric] = try await supabase
                .from("display_metrics")
                .select()
                .eq("metric_id", value: metricId)
                .limit(1)
                .execute()
                .value

            metric = metrics.first
        } catch {
            print("❌ Error loading metric: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Favorite Row

struct FavoriteRow: View {
    let favorite: PatientFavorite

    var pillarColor: Color {
        MetricsUIConfig.getPillarColor(for: favorite.pillar ?? "Core Care")
    }

    var icon: String {
        if favorite.itemType == "screen" {
            return MetricsUIConfig.getIcon(for: favorite.itemId) ?? "chart.bar.fill"
        } else if favorite.itemType == "metric" {
            // Try to get icon from display name or use chart icon
            return MetricsUIConfig.getIcon(for: favorite.displayName ?? "") ?? "chart.bar.fill"
        } else if favorite.itemType == "biomarker" {
            return "testtube.2"
        } else if favorite.itemType == "biometric" {
            return "waveform.path.ecg"
        }
        return "star.fill"
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(pillarColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(pillarColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(favorite.displayName ?? favorite.itemId)
                    .font(.headline)
                    .foregroundColor(.primary)

                if let pillar = favorite.pillar {
                    Text(pillar)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(pillarColor)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(16)
    }
}

// Model for pillar items
struct PillarItem: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let screenCount: Int
}

// Pillar row view for tracked metrics list - compact style
struct PillarListRow: View {
    let pillar: PillarItem

    var body: some View {
        HStack(spacing: 12) {
            // Compact circle icon
            ZStack {
                Circle()
                    .fill(pillar.color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: pillar.icon)
                    .foregroundColor(pillar.color)
                    .font(.system(size: 16))
            }

            Text(pillar.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(pillar.color)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// View showing display screens for a pillar
struct PillarScreensView: View {
    let pillar: String
    @ObservedObject var viewModel: TrackedMetricsViewModel
    @State private var searchText = ""

    var filteredScreens: [DisplayScreen] {
        let screens = viewModel.getScreens(forPillar: pillar)

        if !searchText.isEmpty {
            return screens.filter { screen in
                screen.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        return screens
    }

    var body: some View {
        contentView
            .background(
                ZStack {
                    // Background gradient - vertical from pillar color to white
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [
                                MetricsUIConfig.getPillarColor(for: pillar).opacity(0.65),
                                MetricsUIConfig.getPillarColor(for: pillar).opacity(0.45),
                                MetricsUIConfig.getPillarColor(for: pillar).opacity(0.25),
                                MetricsUIConfig.getPillarColor(for: pillar).opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 900)

                        Spacer()
                    }

                    // Large background icon
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: MetricsUIConfig.getPillarIcon(for: pillar))
                                .font(.system(size: 200))
                                .foregroundStyle(Color.white.opacity(0.2))
                                .rotationEffect(.degrees(-15))
                                .offset(x: 50, y: -50)
                        }
                        Spacer()
                    }
                }
                .ignoresSafeArea()
            )
            .navigationTitle(pillar)
            .navigationBarTitleDisplayMode(.large)
    }

    private var contentView: some View {
        List {
            ForEach(filteredScreens) { screen in
                NavigationLink(destination: screenDestination(for: screen)) {
                    ScreenRow(
                        screen: screen,
                        color: MetricsUIConfig.getPillarColor(for: pillar),
                        metricCount: viewModel.getMetricCount(forScreen: screen.screenId)
                    )
                }
            }
        }
        .scrollContentBackground(.hidden)
        .searchable(text: $searchText, prompt: "Search screens")
    }

    // Route to custom views using central registry
    @ViewBuilder
    private func screenDestination(for screen: DisplayScreen) -> some View {
        let color = MetricsUIConfig.getPillarColor(for: pillar)

        if let customView = MetricViewRegistry.getView(for: screen, pillar: pillar, color: color) {
            customView
        } else {
            // Fallback to generic card-based view that fetches metrics from database
            GenericMetricScreen(screen: screen, pillar: pillar, color: color)
        }
    }

    // TODO: Future custom views to add to MetricViewRegistry:
    // Healthful Nutrition: Hydration, Meal Timing, Nutrition Quality
    // Movement + Exercise: Cardio, HIIT, Mobility, Daily Activity
    // Core Care: Biometrics, Screenings, Substances, Skincare
    // Cognitive Health: Cognitive Training, Light/Circadian
    // Stress Management: Mindfulness, Meditation
    // Connection + Purpose: Social Wellness, Purpose
}

// Screen row view
struct ScreenRow: View {
    let screen: DisplayScreen
    let color: Color
    let metricCount: Int

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: MetricsUIConfig.getIcon(for: screen.name))
                    .foregroundColor(color)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(screen.name)
                    .font(.headline)

                if let overview = screen.overview {
                    Text(overview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else if metricCount > 0 {
                    Text("\(metricCount) metric\(metricCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if metricCount > 0 {
                Text("\(metricCount)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
        }
        .padding(.vertical, 4)
    }
}

// Search result row with highlighted match
struct SearchResultRow: View {
    let screen: DisplayScreen
    let pillar: String
    let searchText: String

    private var color: Color {
        MetricsUIConfig.getPillarColor(for: pillar)
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: MetricsUIConfig.getIcon(for: screen.name))
                    .foregroundColor(color)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Highlighted name
                highlightedText(screen.name, highlight: searchText)
                    .font(.headline)

                if let overview = screen.overview {
                    Text(overview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(color)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(16)
    }

    // Highlight matching text
    private func highlightedText(_ text: String, highlight: String) -> Text {
        guard !highlight.isEmpty else {
            return Text(text)
        }

        let lowercaseText = text.lowercased()
        let lowercaseHighlight = highlight.lowercased()

        guard let range = lowercaseText.range(of: lowercaseHighlight) else {
            return Text(text)
        }

        let startIndex = text.index(text.startIndex, offsetBy: lowercaseText.distance(from: lowercaseText.startIndex, to: range.lowerBound))
        let endIndex = text.index(text.startIndex, offsetBy: lowercaseText.distance(from: lowercaseText.startIndex, to: range.upperBound))

        let before = String(text[..<startIndex])
        let match = String(text[startIndex..<endIndex])
        let after = String(text[endIndex...])

        return Text(before) + Text(match).foregroundColor(color).bold() + Text(after)
    }
}

// Model for metric items
struct MetricItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let value: String
    let subtitle: String
    let destination: AnyView
}

struct MetricListRow: View {
    let title: String
    let icon: String
    let color: Color
    let value: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        TrackedMetricsListView()
    }
}
