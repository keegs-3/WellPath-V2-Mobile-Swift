//
//  ChartTypeFactory.swift
//  WellPath
//
//  Factory for mapping chart_type_id from database to SwiftUI chart components
//

import SwiftUI

struct ChartTypeFactory {
    /// Maps chart_type_id from the database to the appropriate chart view
    @ViewBuilder
    static func createChart(
        metricName: String,
        chartType: String?,
        color: Color
    ) -> some View {
        let type = chartType?.lowercased() ?? "bar_vertical"

        switch type {
        case "sleep_stages_horizontal", "sleep_analysis", "custom_sleep_analysis":
            // Sleep stage timeline chart - use new dedicated view
            // Note: ChartTypeFactory needs screenId to properly instantiate
            // For now, this is a placeholder - navigation should use SleepAnalysisPrimary directly
            Text("Sleep Analysis - Navigate directly to SleepAnalysisPrimary")
                .foregroundColor(.secondary)

        case "bar_vertical", "bar_horizontal":
            // Standard bar charts - use ParentMetricBarChart for protein
            // Need to get the DisplayMetric to pass to ParentMetricBarChart
            // For now, show placeholder until we can pass the metric through
            VStack(alignment: .leading, spacing: 16) {
                Text(metricName)
                    .font(.title2)
                    .fontWeight(.bold)
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.2))
                    .frame(height: 200)
                    .overlay(
                        Text("Bar Chart\n(Use ParentMetricBarChart)")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    )
            }
            .padding()

        case "bar_stacked":
            // Stacked bar charts
            StackedBarChart(metricName: metricName, chartType: chartType, color: color)

        case "trend_line", "line_chart":
            // Line/trend charts
            TrendLineChart(metricName: metricName, chartType: chartType, color: color)

        case "comparison_view":
            // Comparison charts (future implementation)
            VStack(alignment: .leading, spacing: 16) {
                Text(metricName)
                    .font(.title2)
                    .fontWeight(.bold)
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.2))
                    .frame(height: 200)
                    .overlay(
                        Text("Comparison View\n(Coming Soon)")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    )
            }
            .padding()

        case "progress_bar", "progress_ring":
            // Progress indicators (future implementation)
            VStack(alignment: .leading, spacing: 16) {
                Text(metricName)
                    .font(.title2)
                    .fontWeight(.bold)
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.2))
                    .frame(height: 200)
                    .overlay(
                        Text("Progress Indicator\n(Coming Soon)")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    )
            }
            .padding()

        default:
            // Default fallback to bar chart
            VStack(alignment: .leading, spacing: 16) {
                Text(metricName)
                    .font(.title2)
                    .fontWeight(.bold)
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.2))
                    .frame(height: 200)
                    .overlay(
                        VStack {
                            Text("Unknown: \(type)")
                                .font(.caption)
                                .foregroundColor(.red)
                            Text("Using default placeholder")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    )
            }
            .padding()
        }
    }

    /// Get a user-friendly name for a chart type
    static func chartTypeName(for chartTypeId: String?) -> String {
        guard let chartType = chartTypeId?.lowercased() else {
            return "Bar Chart"
        }

        switch chartType {
        case "sleep_stages_horizontal":
            return "Sleep Stages Timeline"
        case "bar_vertical":
            return "Vertical Bar Chart"
        case "bar_horizontal":
            return "Horizontal Bar Chart"
        case "bar_stacked":
            return "Stacked Bar Chart"
        case "trend_line", "line_chart":
            return "Line Chart"
        case "comparison_view":
            return "Comparison View"
        case "progress_bar":
            return "Progress Bar"
        case "progress_ring":
            return "Progress Ring"
        default:
            return chartType.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// Get an SF Symbol icon for a chart type
    static func chartTypeIcon(for chartTypeId: String?) -> String {
        guard let chartType = chartTypeId?.lowercased() else {
            return "chart.bar.fill"
        }

        switch chartType {
        case "sleep_stages_horizontal":
            return "bed.double.fill"
        case "bar_vertical", "bar_stacked":
            return "chart.bar.fill"
        case "bar_horizontal":
            return "chart.bar.xaxis"
        case "trend_line", "line_chart":
            return "chart.line.uptrend.xyaxis"
        case "comparison_view":
            return "chart.bar.xaxis"
        case "progress_bar":
            return "chart.bar.xaxis"
        case "progress_ring":
            return "circle.circle.fill"
        default:
            return "chart.bar.fill"
        }
    }
}

// MARK: - Supported Chart Types Documentation
/*
 Supported Chart Types (from database chart_type_id):

 - sleep_stages_horizontal: Sleep stage timeline chart
 - bar_vertical: Vertical bar chart (default)
 - bar_horizontal: Horizontal bar chart
 - bar_stacked: Stacked bar chart
 - trend_line: Line chart (future)
 - line_chart: Line chart (future)
 - comparison_view: Side-by-side comparison (future)
 - progress_bar: Horizontal progress indicator (future)
 - progress_ring: Circular progress indicator (future)

 To add a new chart type:
 1. Add a case in createChart() switch statement
 2. Create the chart component (or use existing component)
 3. Update chartTypeName() for user-friendly name
 4. Update chartTypeIcon() for SF Symbol icon
 5. Add the chart_type_id to your database chart_types table
 */
