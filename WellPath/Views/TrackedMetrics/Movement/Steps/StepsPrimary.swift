//
//  StepsPrimary.swift
//  WellPath
//
//  Primary view for Daily Steps metric
//  Shows D/W/M/6M/Y bar chart from ParentMetricBarChart
//

import SwiftUI

struct StepsPrimary: View {
    let pillar: String
    let color: Color
    @StateObject private var viewModel = StepsPrimaryViewModel()
    @State private var showingEntryForm = false
    @State private var selectedView: PrimaryView = .chart

    enum PrimaryView: String, CaseIterable {
        case chart = "Chart"
        case about = "About"
    }

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Steps")
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
            .navigationTitle("Steps")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingEntryForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEntryForm) {
                StepsEntryView()
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
            // Show the steps chart
            if let metric = viewModel.metrics.first {
                ParentMetricBarChart(metric: metric.metric, color: color)
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
                                Text("About Steps")
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
        StepsPrimary(pillar: "Movement", color: .blue)
    }
}
