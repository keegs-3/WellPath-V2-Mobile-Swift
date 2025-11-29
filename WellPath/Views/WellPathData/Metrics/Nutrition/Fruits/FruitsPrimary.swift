//
//  FruitsPrimary.swift
//  WellPath
//
//  Primary view for Fruits metric
//  Shows D/W/M/6M/Y bar chart from ParentMetricBarChart
//

import SwiftUI

struct FruitsPrimary: View {
    let pillar: String
    let color: Color
    @StateObject private var viewModel = StandardMetricViewModel(metricId: "DISP_FRUITS_SERVINGS")
    @State private var showingDetailView = false
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false
    @State private var showAbout = false

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Fruits")
    }

    var body: some View {
        contentView
            .background(
                ZStack {
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [color.opacity(0.65), color.opacity(0.45), color.opacity(0.25), color.opacity(0.1), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 900)
                        Spacer()
                    }

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
            .navigationTitle("Fruits")
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
            .sheet(isPresented: $showingDetailView) {
                NavigationStack {
                    FruitsDetail()
                }
            }
            .sheet(isPresented: $showingEntryForm) {
                FruitsEntryView()
            }
            .sheet(isPresented: $showingDataManagement) {
                MetricDataManagementView(config: .fruits(color: color))
            }
            .task {
                await viewModel.loadPrimaryScreen()
            }
    }

    private var contentView: some View {
        VStack(spacing: 0) {
            if showAbout {
                aboutContentView
            } else {
                chartView
            }
        }
    }

    private var chartView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Show the fruits servings chart
                if let metric = viewModel.metrics.first {
                    ParentMetricBarChart(metric: metric.metric, color: color, showAbout: $showAbout)

                    // View More button
                    Button(action: {
                        showingDetailView = true
                    }) {
                        Text("View More Fruits Data")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    private var aboutContentView: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 24) {
                    if viewModel.isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Loading content...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else if let error = viewModel.error {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            Text("Unable to load content")
                                .font(.headline)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        // About content
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

                        // Health Impact
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

                        // Quick Tips
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
                }
                .padding()
                .padding(.top, 40) // Space for close button
            }
            .background(Color.clear)

            // Close button (floating, top-right)
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
        .background(Color.clear)
    }
}
