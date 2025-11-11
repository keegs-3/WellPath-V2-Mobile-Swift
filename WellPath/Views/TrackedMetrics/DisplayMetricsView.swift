//
//  DisplayMetricsView.swift
//  WellPath
//
//  Created on 2025-10-23
//

import SwiftUI

struct DisplayMetricsView: View {
    let screen: DisplayScreen
    let pillar: String
    @StateObject private var viewModel = DisplayMetricsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading metrics...")
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
                            await viewModel.loadMetrics(forScreen: screen.screenId)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.metrics.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No metrics available")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.metrics) { metric in
                        NavigationLink(destination: Text("Metric Detail: \(metric.metricName)")) {
                            MetricRow(
                                metric: metric,
                                color: MetricsUIConfig.getPillarColor(for: pillar)
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle(screen.name)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadMetrics(forScreen: screen.screenId)
        }
    }
}

// Metric row view
struct MetricRow: View {
    let metric: DisplayMetric
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(metric.metricName)
                    .font(.headline)

                Spacer()

                // Unit display removed - not in simplified DisplayMetric model
            }

            if let description = metric.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            if let chartType = metric.chartTypeId {
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption2)
                    Text(chartType.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption2)
                }
                .foregroundColor(color)
            }
        }
        .padding(.vertical, 4)
    }
}

@MainActor
class DisplayMetricsViewModel: ObservableObject {
    @Published var metrics: [DisplayMetric] = []
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    func loadMetrics(forScreen screenId: String) async {
        isLoading = true
        error = nil

        do {
            print("🔍 Loading metrics for screen: \(screenId)")

            // First, get the metric IDs from the junction table
            let links: [ScreenMetricLink] = try await supabase
                .from("display_screens_primary_display_metrics")
                .select()
                .eq("primary_screen_id", value: screenId)
                .order("display_order", ascending: true)
                .execute()
                .value

            print("✅ Found \(links.count) metric links")

            let metricIds = links.map { $0.metricId }

            // Fetch the actual metrics
            let fetchedMetrics: [DisplayMetric] = try await supabase
                .from("display_metrics")
                .select()
                .in("metric_id", values: metricIds)
                .eq("is_active", value: true)
                .execute()
                .value

            print("✅ Loaded \(fetchedMetrics.count) metrics")

            // Sort by the order from junction table
            let sortedMetrics = metricIds.compactMap { metricId in
                fetchedMetrics.first { $0.metricId == metricId }
            }

            metrics = sortedMetrics

        } catch {
            let errorMessage = error.localizedDescription
            self.error = "Failed to load metrics: \(errorMessage)"
            print("❌ Error loading metrics: \(error)")
        }

        isLoading = false
    }
}

