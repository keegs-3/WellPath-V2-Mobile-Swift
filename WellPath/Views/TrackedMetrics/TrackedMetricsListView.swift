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
            AnyView(SleepAnalysisPrimary(pillar: pillar, color: color))
        },
        "SCREEN_SLEEP_CONSISTENCY": { pillar, color in
            AnyView(SleepConsistencyPrimary(pillar: pillar, color: color))
        },

        // Healthful Nutrition
        "SCREEN_PROTEIN": { pillar, color in
            AnyView(ProteinPrimary(pillar: pillar, color: color))
        },
        "SCREEN_LEGUMES": { pillar, color in
            AnyView(LegumesPrimary(pillar: pillar, color: color))
        },
        "SCREEN_LEGUMES_PRIMARY": { pillar, color in
            AnyView(LegumesPrimary(pillar: pillar, color: color))
        },
        "SCREEN_VEGETABLES": { pillar, color in
            AnyView(VegetablesPrimary(pillar: pillar, color: color))
        },
        "SCREEN_VEGETABLES_PRIMARY": { pillar, color in
            AnyView(VegetablesPrimary(pillar: pillar, color: color))
        },
        "SCREEN_WHOLE_GRAINS": { pillar, color in
            AnyView(WholeGrainsPrimary(pillar: pillar, color: color))
        },
        "SCREEN_WHOLE_GRAINS_PRIMARY": { pillar, color in
            AnyView(WholeGrainsPrimary(pillar: pillar, color: color))
        },
        "SCREEN_FRUITS": { pillar, color in
            AnyView(FruitsPrimary(pillar: pillar, color: color))
        },
        "SCREEN_FRUITS_PRIMARY": { pillar, color in
            AnyView(FruitsPrimary(pillar: pillar, color: color))
        },

        // Movement + Exercise
        "SCREEN_STEPS": { pillar, color in
            AnyView(StepsPrimary(pillar: pillar, color: color))
        },
        "SCREEN_STRENGTH": { pillar, color in
            AnyView(StrengthTrainingPrimary(pillar: pillar, color: color))
        },
        "SCREEN_STRENGTH_TRAINING": { pillar, color in
            AnyView(StrengthTrainingPrimary(pillar: pillar, color: color))
        }
    ]

    /// Get custom view for screen, or nil if should use fallback MetricDetailView
    static func getView(for screen: DisplayScreen, pillar: String, color: Color) -> AnyView? {
        return registry[screen.screenId]?(pillar, color)
    }
}

struct TrackedMetricsListView: View {
    @StateObject private var viewModel = TrackedMetricsViewModel()
    @State private var searchText = ""

    // Show 7 pillars with screen count (or filtered screens when searching)
    var filteredPillars: [PillarItem] {
        let allPillars = viewModel.pillars.map { pillar in
            let screens = viewModel.getScreens(forPillar: pillar)
            return PillarItem(
                name: pillar,
                icon: MetricsUIConfig.getPillarIcon(for: pillar),
                color: MetricsUIConfig.getPillarColor(for: pillar),
                screenCount: screens.count
            )
        }

        return allPillars
    }

    // When searching, show matching screens grouped by pillar
    var searchResults: [(pillar: String, screens: [DisplayScreen])] {
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

    var isSearching: Bool {
        !searchText.isEmpty
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading pillars...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Unable to load metrics")
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
            } else if viewModel.pillars.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No pillars available")
                        .font(.headline)
                    Text("Contact support if this issue persists")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    if isSearching {
                        // Show search results
                        List {
                            ForEach(searchResults, id: \.pillar) { result in
                                Section(result.pillar) {
                                    ForEach(result.screens) { screen in
                                        NavigationLink(destination: screenDestination(for: screen, pillar: result.pillar)) {
                                            ScreenRow(
                                                screen: screen,
                                                color: MetricsUIConfig.getPillarColor(for: result.pillar),
                                                metricCount: viewModel.getMetricCount(forScreen: screen.screenId)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    } else {
                        // Connected container with all pillars
                        VStack(spacing: 0) {
                            ForEach(Array(filteredPillars.enumerated()), id: \.element.id) { index, pillar in
                                NavigationLink(destination: PillarScreensView(pillar: pillar.name, viewModel: viewModel)) {
                                    PillarListRow(pillar: pillar)
                                }
                                .buttonStyle(PlainButtonStyle())

                                // Add divider between pillars (except after last one)
                                if index < filteredPillars.count - 1 {
                                    Divider()
                                        .background(Color.gray.opacity(0.3))
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                }
                .searchable(text: $searchText, prompt: "Search screens")
            }
        }
        .background(
            ZStack {
                // Background gradient
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

                // Large background logo
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
        )
        .navigationTitle("Wellpath Data")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadMetricsData()
        }
    }

    // Route to custom views using central registry
    @ViewBuilder
    private func screenDestination(for screen: DisplayScreen, pillar: String) -> some View {
        let color = MetricsUIConfig.getPillarColor(for: pillar)

        if let customView = MetricViewRegistry.getView(for: screen, pillar: pillar, color: color) {
            customView
        } else {
            // Fallback to generic view for screens without custom views yet
            MetricDetailView(screen: screen, pillar: pillar)
        }
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

// Pillar row view for tracked metrics list
struct PillarListRow: View {
    let pillar: PillarItem

    var body: some View {
        HStack(spacing: 16) {
            // Circle filled with lighter pillar color
            ZStack {
                Circle()
                    .fill(pillar.color.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: pillar.icon)
                    .foregroundColor(pillar.color)
                    .font(.title2)
            }

            Text(pillar.name)
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            // Pillar-colored chevron inside container
            Image(systemName: "chevron.right")
                .foregroundColor(pillar.color)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
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
            // Fallback to generic view for screens without custom views yet
            MetricDetailView(screen: screen, pillar: pillar)
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
    NavigationView {
        TrackedMetricsListView()
    }
}
