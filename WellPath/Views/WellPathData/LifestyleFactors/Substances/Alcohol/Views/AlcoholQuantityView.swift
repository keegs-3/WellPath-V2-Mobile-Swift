//
//  AlcoholQuantityView.swift
//  WellPath
//
//  Database-driven view for tracking alcohol consumption.
//  Uses StandardMetricViewModel and ParentMetricBarChart.
//

import SwiftUI

struct AlcoholQuantityView: View {
    let color: Color
    @StateObject private var viewModel = StandardMetricViewModel(metricId: "DISP_ALCOHOL_QUANTITY")
    @State private var showAboutModal = false

    private let screenIcon = "wineglass"
    private let metricId = "DISP_ALCOHOL_QUANTITY"
    private let metricName = "Alcohol Quantity"

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let metric = viewModel.metrics.first {
                    ParentMetricBarChart(metric: metric.metric, color: color, showAbout: $showAboutModal)
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
        .metricScreenBackground(color: color)
        .navigationTitle("Drinks")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(viewId: metricId, metricName: metricName, color: color, isPresented: $showAboutModal)
        }
        .task {
            await viewModel.loadPrimaryScreen()
        }
    }
}

#Preview {
    NavigationStack {
        AlcoholQuantityView(color: .orange)
    }
}
