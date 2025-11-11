//
//  StackedBarChart.swift
//  WellPath
//
//  Stacked bar chart for metrics like protein by source
//

import SwiftUI
import Charts

struct StackedBarChart: View {
    let metricName: String
    let chartType: String?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(metricName)
                .font(.title2)
                .fontWeight(.bold)

            // Placeholder stacked bar chart
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.2))
                .frame(height: 250)
                .overlay(
                    VStack {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 48))
                            .foregroundColor(color.opacity(0.5))
                        Text("Stacked Bar Chart")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Chart implementation coming soon")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                )
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}
