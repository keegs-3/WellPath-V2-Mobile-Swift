//
//  BiometricsScreen.swift
//  WellPath
//
//  Card-based layout for Biometrics
//  Shows all biometric metrics as tappable mini cards
//

import SwiftUI

struct BiometricsScreen: View {
    let pillar: String
    let color: Color

    @StateObject private var viewModel = BiometricsPrimaryViewModel()
    @EnvironmentObject private var searchState: WellPathDataSearchState
    @FocusState private var isSearchFocused: Bool

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Biometrics")
    }

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
                } else if viewModel.biometricMetrics.isEmpty {
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
                    // Body Composition Section
                    if hasBodyCompositionMetrics {
                        sectionHeader("Body Composition")

                        if let metric = viewModel.weightMetric {
                            BiometricMetricCard(
                                metric: metric,
                                color: color,
                                pillar: pillar
                            )
                        }

                        if let metric = viewModel.bmiMetric {
                            BiometricMetricCard(
                                metric: metric,
                                color: color,
                                pillar: pillar
                            )
                        }

                        if let metric = viewModel.bodyFatMetric {
                            BiometricMetricCard(
                                metric: metric,
                                color: color,
                                pillar: pillar
                            )
                        }

                        if let metric = viewModel.visceralFatMetric {
                            BiometricMetricCard(
                                metric: metric,
                                color: color,
                                pillar: pillar
                            )
                        }

                        if let metric = viewModel.waistCircumferenceMetric {
                            BiometricMetricCard(
                                metric: metric,
                                color: color,
                                pillar: pillar
                            )
                        }

                        if let metric = viewModel.hipCircumferenceMetric {
                            BiometricMetricCard(
                                metric: metric,
                                color: color,
                                pillar: pillar
                            )
                        }

                        if let metric = viewModel.waistHipMetric {
                            BiometricMetricCard(
                                metric: metric,
                                color: color,
                                pillar: pillar
                            )
                        }

                        if let metric = viewModel.smmFfmMetric {
                            BiometricMetricCard(
                                metric: metric,
                                color: color,
                                pillar: pillar
                            )
                        }
                    }

                    // Cardiovascular Section
                    if hasCardiovascularMetrics {
                        sectionHeader("Cardiovascular")

                        if let metric = viewModel.bloodPressureMetric {
                            BiometricMetricCard(
                                metric: metric,
                                color: color,
                                pillar: pillar
                            )
                        }

                        if let metric = viewModel.restingHrMetric {
                            BiometricMetricCard(
                                metric: metric,
                                color: color,
                                pillar: pillar
                            )
                        }

                        if let metric = viewModel.hrvMetric {
                            BiometricMetricCard(
                                metric: metric,
                                color: color,
                                pillar: pillar
                            )
                        }

                        if let metric = viewModel.vo2MaxMetric {
                            BiometricMetricCard(
                                metric: metric,
                                color: color,
                                pillar: pillar
                            )
                        }
                    }

                    // Strength Section
                    if hasStrengthMetrics {
                        sectionHeader("Strength")

                        if let metric = viewModel.gripStrengthMetric {
                            BiometricMetricCard(
                                metric: metric,
                                color: color,
                                pillar: pillar
                            )
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
            await viewModel.loadPrimaryScreen()
        }
    }

    private var hasBodyCompositionMetrics: Bool {
        viewModel.weightMetric != nil ||
        viewModel.bmiMetric != nil ||
        viewModel.bodyFatMetric != nil ||
        viewModel.visceralFatMetric != nil ||
        viewModel.waistCircumferenceMetric != nil ||
        viewModel.hipCircumferenceMetric != nil ||
        viewModel.waistHipMetric != nil ||
        viewModel.smmFfmMetric != nil
    }

    private var hasCardiovascularMetrics: Bool {
        viewModel.bloodPressureMetric != nil ||
        viewModel.restingHrMetric != nil ||
        viewModel.hrvMetric != nil ||
        viewModel.vo2MaxMetric != nil
    }

    private var hasStrengthMetrics: Bool {
        viewModel.gripStrengthMetric != nil
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
