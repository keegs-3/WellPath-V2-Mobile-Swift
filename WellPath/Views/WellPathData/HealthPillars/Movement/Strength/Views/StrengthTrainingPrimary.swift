//
//  StrengthTrainingPrimary.swift
//  WellPath
//
//  Primary view for Strength Training metric
//  Shows D/W/M/6M/Y bar chart from ParentMetricBarChart
//

import SwiftUI

struct StrengthTrainingPrimary: View {
    let pillar: String
    let color: Color
    @StateObject private var viewModel = StrengthTrainingPrimaryViewModel()
    @State private var showingDetailView = false
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false
    @State private var selectedView: PrimaryView = .chart

    enum PrimaryView: String, CaseIterable {
        case chart = "Chart"
        case about = "About"
    }

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "StrengthTraining")
    }

    var body: some View {
        contentView
            .metricScreenBackground(color: color)
            .navigationTitle("Strength Training")
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
                MetricDataManagementView(config: .strengthTraining(color: color))
            }
            .sheet(isPresented: $showingDetailView) {
                NavigationStack {
                    MetricDetailView(
                        screen: DisplayScreen(
                            id: UUID().uuidString,
                            screenId: "SCREEN_STRENGTH",
                            name: "Strength Training",
                            overview: nil,
                            pillar: pillar,
                            displayOrder: nil,
                            isActive: true
                        ),
                        pillar: pillar
                    )
                }
            }
            .sheet(isPresented: $showingEntryForm) {
                StrengthTrainingEntryView()
            }
            .task {
                await viewModel.loadPrimaryScreen()
            }
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // View picker
                Picker("View", selection: $selectedView) {
                    ForEach(PrimaryView.allCases, id: \.self) { view in
                        Text(view.rawValue).tag(view)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 8)

                if selectedView == .chart {
                    chartView
                } else {
                    aboutView
                }
            }
        }
    }

    private var chartView: some View {
        VStack(spacing: 24) {
            // Show the strength training chart
            if let metric = viewModel.metrics.first {
                ParentMetricBarChart(metric: metric.metric, color: color)

                // View More button
                Button(action: {
                    showingDetailView = true
                }) {
                    Text("View More Strength Training Data")
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

    private var aboutView: some View {
        ScrollView {
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
                VStack(alignment: .leading, spacing: 24) {
                    if let about = viewModel.aboutContent {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(color)
                                Text("About Strength Training")
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
            }
        }
    }
}

#Preview {
    NavigationStack {
        StrengthTrainingPrimary(pillar: "Movement", color: .blue)
    }
}
