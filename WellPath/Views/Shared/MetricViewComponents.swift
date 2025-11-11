//
//  MetricViewComponents.swift
//  WellPath
//
//  Shared components for custom metric views
//

import SwiftUI

// MARK: - Show More Button

struct ShowMoreButton: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text("Show More Data")
                    .font(.body)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .foregroundColor(.blue)
            .padding()
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - About Section
// NOTE: MetricAboutSection removed - About fields (aboutWhat, aboutWhy, etc.)
// are not in the simplified DisplayMetric model. Educational content should be
// added to custom Primary/Detail views instead.

struct MetricAboutItem: View {
    let icon: String
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
            }
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Error View

struct MetricErrorView: View {
    let error: String
    let retry: () -> Void

    var body: some View {
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
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty State

struct EmptyMetricsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No metrics configured")
                .font(.headline)
            Text("This screen hasn't been set up with metrics yet")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Child Metrics Sheet

struct MetricChildSheet: View {
    @Environment(\.dismiss) var dismiss
    let metrics: [DisplayMetric]
    let parentName: String
    let color: Color

    var body: some View {
        NavigationView {
            List(metrics) { metric in
                VStack(alignment: .leading, spacing: 8) {
                    Text(metric.metricName)
                        .font(.headline)
                    if let description = metric.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("\(parentName) Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
