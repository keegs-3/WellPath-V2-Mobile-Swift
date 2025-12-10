//
//  StepsScreen.swift
//  WellPath
//
//  Steps view - single-card category so navigates directly to view
//  Card (CARD_STEPS) exists in DB for favorites display
//

import SwiftUI

struct StepsScreen: View {
    let pillar: String
    let color: Color
    let sectionId: String

    @StateObject private var viewModel = StepsPrimaryViewModel()
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false
    @State private var showAboutModal = false

    private let metricId = "DISP_STEPS"
    private let metricName = "Steps"

    var body: some View {
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
        .metricScreenBackground(color: color)
        .navigationTitle("Steps")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingDataManagement = true
                } label: {
                    Image(systemName: "list.bullet")
                }
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                FavoriteButton(
                    itemType: .screen,
                    itemId: "SCREEN_STEPS",
                    displayName: "Steps",
                    pillar: pillar,
                    cardId: "CARD_STEPS",
                    sectionId: sectionId
                )

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
        .sheet(isPresented: $showingDataManagement) {
            MetricDataManagementView(config: .steps(color: color))
        }
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(
                viewId: metricId,
                metricName: metricName,
                color: color,
                isPresented: $showAboutModal
            )
        }
        .task {
            await viewModel.loadPrimaryScreen()
        }
    }
}

// MARK: - Steps Mini Card (for Favorites display)

struct StepsMiniCard: View {
    let color: Color
    @ObservedObject var viewModel: StepsPrimaryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(height: 60)
            } else if viewModel.metrics.first != nil {
                HStack(spacing: 16) {
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
            } else {
                HStack {
                    Text("No steps data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 60)
            }
        }
    }

    private func formatSteps(_ value: Double?) -> String {
        guard let value = value else { return "--" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

#Preview {
    NavigationStack {
        StepsScreen(pillar: "Movement + Exercise", color: .orange, sectionId: "NAV_MOVEMENT")
    }
}
