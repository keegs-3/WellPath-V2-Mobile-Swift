//
//  WaistHipView.swift
//  WellPath
//
//  Waist-to-Hip Ratio view with two stacked charts
//  Shows measurements (waist/hip lines) on top, ratio below
//  Both charts share synchronized scrolling and point selection
//

import SwiftUI

struct WaistHipView: View {
    let color: Color

    @StateObject private var waistLoader = BiometricValueLoader()
    @StateObject private var hipLoader = BiometricValueLoader()
    @StateObject private var scrollManager: MeasurementsChartScrollManager
    @State private var showAboutModal = false
    @State private var showAddEntry = false
    @State private var showDataManagement = false
    @State private var selectedUnit: HeightDisplayUnit2 = .ftIn
    @State private var selectedPeriod: TimePeriod = .week
    @State private var scrollPosition: Date
    @State private var selectedPointDate: Date?  // Shared selection across both charts

    private let metricId = "DISP_WAIST_HIP"
    private let metricName = "Waist-to-Hip Ratio"


    // Computed waist-to-hip ratio
    private var waistToHipRatio: Double? {
        guard let waist = waistLoader.rawValue, waist > 0,
              let hip = hipLoader.rawValue, hip > 0 else { return nil }
        return waist / hip
    }

    private var displayWaist: Double? {
        guard let rawValue = waistLoader.rawValue else { return nil }
        switch selectedUnit {
        case .cm: return rawValue
        case .ftIn: return rawValue / 2.54
        }
    }

    private var displayHip: Double? {
        guard let rawValue = hipLoader.rawValue else { return nil }
        switch selectedUnit {
        case .cm: return rawValue
        case .ftIn: return rawValue / 2.54
        }
    }

    private var displayUnitString: String {
        selectedUnit == .cm ? "cm" : "in"
    }

    init(color: Color) {
        self.color = color

        // Initialize scroll position
        let now = Date()
        let initialPeriod = TimePeriod.week
        let visibleDuration = initialPeriod.numberOfBars
        let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
        let scrollStart = Calendar.current.date(
            byAdding: initialPeriod.calendarComponent,
            value: -offsetFromEnd,
            to: now
        ) ?? now

        _scrollPosition = State(initialValue: scrollStart)
        _scrollManager = StateObject(wrappedValue: MeasurementsChartScrollManager(period: initialPeriod))
    }

    var body: some View {
        mainContentView
            .metricScreenBackground(color: color)
        .navigationTitle("Waist-to-Hip")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { showDataManagement = true } label: {
                    Image(systemName: "list.bullet")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddEntry = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddEntry) {
            WaistHipEntryView()
        }
        .sheet(isPresented: $showDataManagement) {
            BodyMeasurementsDataManagementView(color: color)
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
            await waistLoader.loadValue(for: "DISP_WAIST_CIRCUMFERENCE")
            await hipLoader.loadValue(for: "DISP_HIP_CIRCUMFERENCE")
            selectedUnit = waistLoader.preferredLengthUnit
        }
        .onReceive(NotificationCenter.default.publisher(for: .biometricDataDidChange)) { _ in
            // Refresh chart data when biometric data changes
            scrollManager.refresh()
            Task {
                await waistLoader.loadValue(for: "DISP_WAIST_CIRCUMFERENCE")
                await hipLoader.loadValue(for: "DISP_HIP_CIRCUMFERENCE")
            }
        }
        .onChange(of: selectedPeriod) { oldValue, newPeriod in
            scrollManager.updatePeriod(newPeriod)

            // Use optimal position if available, otherwise calculate based on now
            if let optimalPosition = scrollManager.optimalScrollPosition {
                scrollPosition = optimalPosition
            } else {
                let now = Date()
                let visibleDuration = newPeriod.numberOfBars
                let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
                scrollPosition = Calendar.current.date(
                    byAdding: newPeriod.calendarComponent,
                    value: -offsetFromEnd,
                    to: now
                ) ?? now
            }
        }
        // Removed unused optimalScrollPosition handler - StackedMeasurementsChart manages its own scroll
    }

    private var mainContentView: some View {
        ScrollView {
            // 3 stacked charts with integrated header (pickers, info, unit toggle)
            StackedMeasurementsChart(
                color: color,
                selectedUnit: $selectedUnit,
                selectedPeriod: $selectedPeriod,
                scrollManager: scrollManager,
                showAbout: $showAboutModal
            )
            .padding(.top, 8)
            .padding(.bottom)
        }
    }

    // MARK: - Current Values Card

    private var currentValuesCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                // Waist
                VStack(alignment: .leading, spacing: 4) {
                    Text("WAIST")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if waistLoader.isLoading {
                        ProgressView()
                    } else if let waist = displayWaist {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.1f", waist))
                                .font(.title)
                                .fontWeight(.bold)
                            Text(displayUnitString)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("--")
                            .font(.title)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()
                    .frame(height: 40)

                // Hip
                VStack(alignment: .leading, spacing: 4) {
                    Text("HIP")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if hipLoader.isLoading {
                        ProgressView()
                    } else if let hip = displayHip {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.1f", hip))
                                .font(.title)
                                .fontWeight(.bold)
                            Text(displayUnitString)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("--")
                            .font(.title)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()
                    .frame(height: 40)

                // Ratio
                VStack(alignment: .leading, spacing: 4) {
                    Text("RATIO")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if waistLoader.isLoading || hipLoader.isLoading {
                        ProgressView()
                    } else if let ratio = waistToHipRatio {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "%.2f", ratio))
                                .font(.title)
                                .fontWeight(.bold)
                            let (classification, statusColor) = classifyWHR(ratio)
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 6, height: 6)
                                Text(classification)
                                    .font(.caption2)
                                    .foregroundColor(statusColor)
                            }
                        }
                    } else {
                        Text("--")
                            .font(.title)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            // Last updated
            if let waistDate = waistLoader.lastUpdated {
                HStack {
                    Spacer()
                    Text("Last updated: \(formatDate(waistDate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Charts

    private var measurementsChartCard: some View {
        BodyMeasurementsRangeChart(
            color: color,
            selectedUnit: $selectedUnit,
            scrollPosition: $scrollPosition,
            selectedPeriod: $selectedPeriod,
            selectedPointDate: $selectedPointDate,
            scrollManager: scrollManager
        )
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var ratioChartCard: some View {
        WaistHipRatioChart(
            color: color,
            selectedUnit: selectedUnit,
            scrollPosition: $scrollPosition,
            selectedPeriod: $selectedPeriod,
            selectedPointDate: $selectedPointDate,
            scrollManager: scrollManager
        )
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func classifyWHR(_ value: Double) -> (String, Color) {
        if value < 0.80 {
            return ("Low Risk", .green)
        } else if value < 0.90 {
            return ("Moderate", .yellow)
        } else if value < 1.0 {
            return ("High Risk", .orange)
        } else {
            return ("Very High", .red)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        WaistHipView(color: .cyan)
    }
}
