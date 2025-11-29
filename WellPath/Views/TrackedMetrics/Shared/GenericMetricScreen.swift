//
//  GenericMetricScreen.swift
//  WellPath
//
//  Generic card-based screen for any display_screen
//  Fetches linked metrics from display_screens_display_metrics
//  Shows cards for each metric with mini chart previews
//

import SwiftUI

struct GenericMetricScreen: View {
    let screen: DisplayScreen
    let pillar: String
    let color: Color

    @StateObject private var viewModel: GenericScreenViewModel
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private var screenIcon: String {
        screen.icon ?? MetricsUIConfig.getIcon(for: screen.name)
    }

    private var screenTitle: String {
        screen.title ?? screen.name
    }

    init(screen: DisplayScreen, pillar: String, color: Color) {
        self.screen = screen
        self.pillar = pillar
        self.color = color
        _viewModel = StateObject(wrappedValue: GenericScreenViewModel(screenId: screen.screenId))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if viewModel.isLoading {
                    ProgressView("Loading metrics...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                } else if let error = viewModel.error {
                    errorView(error)
                } else if viewModel.metrics.isEmpty {
                    emptyStateView
                } else {
                    // Display cards for each metric
                    ForEach(viewModel.metrics) { screenMetric in
                        MetricCardView(
                            title: screenMetric.displayName,
                            color: color,
                            metricId: screenMetric.metric.metricId,
                            pillar: pillar
                        ) {
                            // Mini card content - generic preview
                            GenericMetricMiniCard(
                                metric: screenMetric.metric,
                                color: color
                            )
                        } fullScreen: {
                            // Full screen view - ParentMetricBarChart
                            GenericMetricFullView(
                                metric: screenMetric.metric,
                                color: color,
                                screenIcon: screenIcon
                            )
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 24)
        }
        .background(
            ZStack {
                // Base background that extends to bottom
                Color(uiColor: .systemGroupedBackground)

                // Gradient overlay at top
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [color.opacity(0.65), color.opacity(0.45), color.opacity(0.25), color.opacity(0.1), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 900)
                    Spacer()
                }

                // Watermark icon
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: screenIcon)
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
        .navigationTitle(screenTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingDataManagement = true
                } label: {
                    Image(systemName: "list.bullet")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingEntryForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingDataManagement) {
            // Generic data management - show all data for this screen
            GenericDataManagementView(screen: screen, color: color)
        }
        .sheet(isPresented: $showingEntryForm) {
            // Generic entry form placeholder
            GenericEntryFormView(screen: screen, color: color)
        }
        .task {
            await viewModel.loadScreen()
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Unable to load metrics")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No metrics configured")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("This screen doesn't have any metrics linked yet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
}

// MARK: - Generic Mini Card

/// Generic mini card that shows today's value and weekly average for any metric
struct GenericMetricMiniCard: View {
    let metric: DisplayMetric
    let color: Color

    @StateObject private var viewModel: StandardMetricViewModel

    init(metric: DisplayMetric, color: Color) {
        self.metric = metric
        self.color = color
        _viewModel = StateObject(wrappedValue: StandardMetricViewModel(metricId: metric.metricId))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(height: 60)
            } else {
                HStack(spacing: 16) {
                    // Left side - Today/Latest
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("--")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    // Right side - Weekly average placeholder
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Weekly Avg")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("--")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(color)
                    }
                }
            }
        }
        .task {
            await viewModel.loadPrimaryScreen()
        }
    }
}

// MARK: - Generic Full View

/// Full screen view for any metric - shows ParentMetricBarChart
struct GenericMetricFullView: View {
    let metric: DisplayMetric
    let color: Color
    let screenIcon: String

    @StateObject private var viewModel: StandardMetricViewModel
    @State private var showAbout = false

    init(metric: DisplayMetric, color: Color, screenIcon: String) {
        self.metric = metric
        self.color = color
        self.screenIcon = screenIcon
        _viewModel = StateObject(wrappedValue: StandardMetricViewModel(metricId: metric.metricId))
    }

    var body: some View {
        VStack(spacing: 0) {
            if showAbout {
                aboutContentView
            } else {
                if let metricData = viewModel.metrics.first {
                    ParentMetricBarChart(metric: metricData.metric, color: color, showAbout: $showAbout)
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(height: 300)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("No data available")
                        .foregroundColor(.secondary)
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .background(
            ZStack {
                // Base background that extends to bottom
                Color(uiColor: .systemGroupedBackground)

                // Gradient overlay at top
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [color.opacity(0.65), color.opacity(0.45), color.opacity(0.25), color.opacity(0.1), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 900)
                    Spacer()
                }

                // Watermark icon
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: screenIcon)
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
        .task {
            await viewModel.loadPrimaryScreen()
        }
    }

    private var aboutContentView: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 24) {
                    if let about = viewModel.aboutContent {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(color)
                                Text("About")
                                    .font(.headline)
                            }
                            Text(about)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let impact = viewModel.longevityImpact {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: "heart.circle.fill")
                                    .foregroundColor(color)
                                Text("Health Impact")
                                    .font(.headline)
                            }
                            Text(impact)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let tips = viewModel.quickTips, !tips.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "lightbulb.circle.fill")
                                    .foregroundColor(color)
                                Text("Quick Tips")
                                    .font(.headline)
                            }

                            ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1).")
                                        .fontWeight(.semibold)
                                        .foregroundColor(color)
                                    Text(tip)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding()
                .padding(.top, 40)
            }

            Button(action: {
                withAnimation {
                    showAbout = false
                }
            }) {
                Image(systemName: "chart.bar")
                    .font(.title3)
                    .foregroundColor(color)
            }
            .padding(.top, 8)
            .padding(.trailing, 16)
        }
    }
}

// MARK: - Generic Data Management View

/// Placeholder for generic data management
struct GenericDataManagementView: View {
    let screen: DisplayScreen
    let color: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 60))
                    .foregroundColor(color.opacity(0.5))

                Text("Data Management")
                    .font(.headline)

                Text("View and manage your \(screen.name) data entries.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text("Coming soon...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Manage Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Generic Entry Form View

/// Placeholder for generic entry form
struct GenericEntryFormView: View {
    let screen: DisplayScreen
    let color: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 60))
                    .foregroundColor(color.opacity(0.5))

                Text("Add Entry")
                    .font(.headline)

                Text("Add a new \(screen.name) entry.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text("Coming soon...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Add \(screen.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Preview requires actual DisplayScreen from database
// Use Xcode previews with live data or test in simulator
