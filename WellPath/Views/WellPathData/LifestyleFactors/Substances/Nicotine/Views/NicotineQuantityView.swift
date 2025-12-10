//
//  NicotineQuantityView.swift
//  WellPath
//
//  Database-driven view for tracking nicotine usage.
//  Loads about content from display_views table.
//

import SwiftUI
import Charts

struct NicotineQuantityView: View {
    let color: Color
    @StateObject private var viewModel = NicotineTrackingViewModel()
    @StateObject private var metricViewModel = StandardMetricViewModel(metricId: "DISP_NICOTINE_QUANTITY")
    @State private var showingEntrySheet = false
    @State private var showAboutModal = false

    private let metricId = "DISP_NICOTINE_QUANTITY"
    private let metricName = "Nicotine Quantity"

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Today's Usage
                todaySection

                // History Chart
                chartSection

                // Log Button
                logButton
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Nicotine Usage")
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
            NicotineEntrySheet(viewModel: viewModel)
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
                    Text("\(viewModel.todayUsage)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(color)
                    Text("uses today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text("Includes vaping, e-cigarettes, pouches, and other nicotine products")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Usage History")
                .font(.headline)
                .padding(.horizontal)

            if viewModel.usageHistory.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart {
                    ForEach(viewModel.usageHistory) { dataPoint in
                        BarMark(
                            x: .value("Date", dataPoint.date),
                            y: .value("Uses", dataPoint.value)
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
                Image(systemName: "plus.circle.fill")
                Text("Log Nicotine Use")
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

struct NicotineEntrySheet: View {
    @ObservedObject var viewModel: NicotineTrackingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var usageCount: Int = 1
    @State private var entryDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Number of Uses") {
                    Stepper("\(usageCount) use\(usageCount == 1 ? "" : "s")", value: $usageCount, in: 1...50)
                }

                Section("Date") {
                    DatePicker("Date", selection: $entryDate, displayedComponents: .date)
                }

                Section {
                    Text("Count each vape session, pod, pouch, or nicotine product use")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Log Nicotine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.logUsage(usageCount, date: entryDate)
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
        NicotineQuantityView(color: .purple)
    }
}
