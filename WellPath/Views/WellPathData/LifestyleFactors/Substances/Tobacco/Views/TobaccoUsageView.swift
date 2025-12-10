//
//  TobaccoUsageView.swift
//  WellPath
//
//  Database-driven view for tracking cigarette usage.
//  Loads about content from display_views table.
//

import SwiftUI
import Charts

struct TobaccoUsageView: View {
    let color: Color
    @StateObject private var viewModel = TobaccoTrackingViewModel()
    @StateObject private var metricViewModel = StandardMetricViewModel(metricId: "DISP_TOBACCO_USAGE")
    @State private var showingEntrySheet = false
    @State private var showAboutModal = false

    private let metricId = "DISP_TOBACCO_USAGE"
    private let metricName = "Tobacco Usage"

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Today's usage
                todaySection

                // History Chart
                chartSection

                // Log Button
                logButton
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Cigarette Usage")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAboutModal = true
                } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
        .sheet(isPresented: $showingEntrySheet) {
            CigaretteEntrySheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(viewId: metricId, metricName: metricName, color: color, isPresented: $showAboutModal)
        }
        .task {
            await viewModel.loadHistory()
            await metricViewModel.loadPrimaryScreen()
        }
    }

    private var todaySection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 120, height: 120)

                VStack(spacing: 4) {
                    Text("\(viewModel.cigaretteHistory.last?.value ?? 0)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(color)
                    Text("cigarettes today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text("Track cigarettes smoked to identify patterns and support reduction")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily History")
                .font(.headline)
                .padding(.horizontal)

            if viewModel.cigaretteHistory.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart {
                    ForEach(viewModel.cigaretteHistory) { dataPoint in
                        BarMark(
                            x: .value("Date", dataPoint.date),
                            y: .value("Cigarettes", dataPoint.value)
                        )
                        .foregroundStyle(color)
                    }
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 200)
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    private var emptyChartPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(uiColor: .secondarySystemGroupedBackground))
            .frame(height: 200)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("History will appear here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            )
            .padding(.horizontal)
    }

    private var logButton: some View {
        Button {
            showingEntrySheet = true
        } label: {
            HStack {
                Image(systemName: "smoke.fill")
                Text("Log Cigarettes")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .background(color)
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
}

// MARK: - Entry Sheet

struct CigaretteEntrySheet: View {
    @ObservedObject var viewModel: TobaccoTrackingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var cigaretteCount: Int = 1
    @State private var entryDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Number of Cigarettes") {
                    Stepper("\(cigaretteCount) cigarette\(cigaretteCount == 1 ? "" : "s")", value: $cigaretteCount, in: 1...60)
                }

                Section("Date") {
                    DatePicker("Date", selection: $entryDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Log Cigarettes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.logCigarettes(cigaretteCount, date: entryDate)
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TobaccoUsageView(color: .orange)
    }
}
