//
//  TrendLineChart.swift
//  WellPath
//
//  Line/trend chart for showing trends over time
//

import SwiftUI
import Charts

struct TrendLineChart: View {
    let metricName: String
    let chartType: String?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(metricName)
                .font(.title2)
                .fontWeight(.bold)

            // Placeholder line chart
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.2))
                .frame(height: 250)
                .overlay(
                    VStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 48))
                            .foregroundColor(color.opacity(0.5))
                        Text("Trend Line Chart")
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
