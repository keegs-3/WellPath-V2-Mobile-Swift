//
//  StressInsightsModal.swift
//  WellPath
//
//  Modal for detailed stress insights - Apple Health State of Mind style
//  Tabs: Stressors | Symptoms | Compare
//

import SwiftUI
import Charts

// MARK: - Stress Insights Modal

struct StressInsightsModal: View {
    let assessmentData: AssessmentData
    let scoreHistory: [AssessmentResult]
    let color: Color

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: InsightTab = .stressors
    @State private var selectedPeriod: InsightPeriod = .month
    @State private var selectedStressor: Int?
    @State private var selectedSymptom: Int?
    @State private var selectedComparisonMetric: ComparisonMetric = .sleep
    @State private var selectedDate: Date?
    @State private var comparisonData: [ComparisonDataPoint] = []
    @State private var scrollPosition: Date = Date()
    @State private var showingMetricInfo = false
    @State private var infoMetric: ComparisonMetric?

    enum InsightTab: String, CaseIterable {
        case stressors = "Stressors"
        case symptoms = "Symptoms"
        case compare = "Compare"
    }

    enum InsightPeriod: String, CaseIterable {
        case week = "W"
        case month = "M"
        case sixMonth = "6M"
        case year = "Y"

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 33
            case .sixMonth: return 180
            case .year: return 365
            }
        }

        /// Number of bars/columns visible in view
        var columnCount: Int {
            switch self {
            case .week: return 7
            case .month: return 33
            case .sixMonth: return 26
            case .year: return 12
            }
        }

        /// Calendar component for x-axis grouping
        var calendarComponent: Calendar.Component {
            switch self {
            case .week, .month: return .day
            case .sixMonth: return .weekOfYear
            case .year: return .month
            }
        }

        /// Time interval for visible domain
        var visibleDomainSeconds: TimeInterval {
            switch self {
            case .week: return 7 * 24 * 3600
            case .month: return 33 * 24 * 3600
            case .sixMonth: return 26 * 7 * 24 * 3600
            case .year: return 365 * 24 * 3600
            }
        }

        /// Whether this period shows averaged data (weekly/monthly averages)
        var showsAverage: Bool {
            switch self {
            case .week, .month: return false  // Single day values
            case .sixMonth, .year: return true  // Averaged values
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Period selector
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(InsightPeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .onChange(of: selectedPeriod) { _, _ in
                        selectedDate = nil
                        updateScrollPosition()
                        Task { await loadComparisonData() }
                    }

                    // Header - entry count and date range (Apple Health style)
                    headerSection
                        .padding(.top, 16)

                    // Main stress chart (scrollable, with x-axis)
                    stressChartSection
                        .padding(.top, 12)

                    // Second chart for Compare tab (linked scroll/selection)
                    if selectedTab == .compare {
                        comparisonChartSection
                            .padding(.top, 8)
                    }

                    // Tab selector
                    Picker("Tab", selection: $selectedTab) {
                        ForEach(InsightTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .onChange(of: selectedTab) { _, newTab in
                        if newTab != .compare {
                            selectedDate = nil
                        }
                    }

                    // Cards based on selected tab
                    cardsSection
                        .padding(.top, 16)
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                }
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Stress Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onChange(of: selectedComparisonMetric) { _, _ in
                Task { await loadComparisonData() }
            }
            .task {
                updateScrollPosition()
                await loadComparisonData()
            }
        }
    }

    private func updateScrollPosition() {
        let calendar = Calendar.current
        let now = Date()
        // Start scroll near the end so recent data is visible
        let offsetDays = -Int(Double(selectedPeriod.columnCount) * 0.8)
        scrollPosition = calendar.date(byAdding: .day, value: offsetDays, to: now) ?? now
    }

    // MARK: - Header (Apple Health style - TOTAL entries)

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if selectedTab == .compare && selectedDate != nil {
                // Show comparison values when a bar is selected
                comparisonSelectionHeader
            } else if selectedDate != nil, let selectedResult = selectedStressResult {
                // Show selected entry details
                let tier = assessmentData.tier(for: selectedResult.score)
                Text(tier?.tierName ?? "Unknown")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                Text(formatSelectedDate(selectedResult.date))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                // Default: show TOTAL entries
                Text("TOTAL")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(filteredScoreHistory.count)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                + Text(" entries")
                    .font(.title2)
                    .foregroundColor(.primary)
                Text(dateRangeString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var comparisonSelectionHeader: some View {
        if selectedComparisonMetric == .sleep {
            // Show both Time In Bed and Time Asleep
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.indigo.opacity(0.4))
                            .frame(width: 8, height: 8)
                        Text(selectedPeriod.showsAverage ? "AVG. TIME IN BED" : "TIME IN BED")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Text(formatDuration(selectedTimeInBed))
                        .font(.system(size: 20, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.indigo)
                            .frame(width: 8, height: 8)
                        Text(selectedPeriod.showsAverage ? "AVG. TIME ASLEEP" : "TIME ASLEEP")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Text(formatDuration(selectedTimeAsleep))
                        .font(.system(size: 20, weight: .semibold))
                }
            }
            Text(selectedDate != nil ? formatSelectedDate(selectedDate!) : dateRangeString)
                .font(.subheadline)
                .foregroundColor(.secondary)
        } else {
            // Other metrics - show value (AVG only for 6M/Y)
            if selectedPeriod.showsAverage {
                Text("AVG")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(selectedComparisonValueString)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)
            Text(selectedDate != nil ? formatSelectedDate(selectedDate!) : dateRangeString)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var selectedTimeInBed: Double {
        guard let date = selectedDate else {
            return comparisonData.filter { $0.timeInBed > 0 }.map { $0.timeInBed }.reduce(0, +) / max(1, Double(comparisonData.filter { $0.timeInBed > 0 }.count))
        }
        return comparisonData.first { Calendar.current.isDate($0.date, equalTo: date, toGranularity: selectedPeriod.calendarComponent) }?.timeInBed ?? 0
    }

    private var selectedTimeAsleep: Double {
        guard let date = selectedDate else {
            return comparisonData.filter { $0.value > 0 }.map { $0.value }.reduce(0, +) / max(1, Double(comparisonData.filter { $0.value > 0 }.count))
        }
        return comparisonData.first { Calendar.current.isDate($0.date, equalTo: date, toGranularity: selectedPeriod.calendarComponent) }?.value ?? 0
    }

    private var selectedComparisonValueString: String {
        guard let date = selectedDate else {
            // Average over window
            let values = comparisonData.filter { $0.value > 0 }.map { $0.value }
            guard !values.isEmpty else { return "--" }
            let avg = values.reduce(0, +) / Double(values.count)
            return formatComparisonValue(avg)
        }
        if let point = comparisonData.first(where: { Calendar.current.isDate($0.date, equalTo: date, toGranularity: selectedPeriod.calendarComponent) }) {
            return formatComparisonValue(point.value)
        }
        return "--"
    }

    private func formatComparisonValue(_ value: Double) -> String {
        switch selectedComparisonMetric {
        case .sleep:
            return formatDuration(value)
        case .exerciseMinutes, .outdoorTime:
            return "\(Int(value)) min"
        case .steps:
            return "\(Int(value))"
        }
    }

    private func formatDuration(_ hours: Double) -> String {
        let totalMinutes = Int(hours * 60)
        let hrs = totalMinutes / 60
        let mins = totalMinutes % 60
        return "\(hrs)hr \(mins)min"
    }

    private var selectedStressResult: AssessmentResult? {
        guard let date = selectedDate else { return nil }
        return filteredScoreHistory.first { Calendar.current.isDate($0.date, equalTo: date, toGranularity: .day) }
    }

    private var dateRangeString: String {
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -selectedPeriod.days, to: now) ?? now

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let endFormatter = DateFormatter()
        endFormatter.dateFormat = "MMM d, yyyy"
        return "\(formatter.string(from: startDate))–\(endFormatter.string(from: now))"
    }

    private func formatSelectedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch selectedPeriod {
        case .week, .month:
            formatter.dateFormat = "MMM d, yyyy"
        case .sixMonth:
            // Show week range
            let calendar = Calendar.current
            if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) {
                let startFormatter = DateFormatter()
                startFormatter.dateFormat = "MMM d"
                let endFormatter = DateFormatter()
                endFormatter.dateFormat = "MMM d, yyyy"
                let lastDay = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.end
                return "\(startFormatter.string(from: weekInterval.start))–\(endFormatter.string(from: lastDay))"
            }
            formatter.dateFormat = "MMM d, yyyy"
        case .year:
            formatter.dateFormat = "MMMM yyyy"
        }
        return formatter.string(from: date)
    }

    // MARK: - Stress Chart Section (Scrollable with X-axis)

    private var stressChartSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 0) {
                // Main scrollable chart
                stressChart
                    .frame(height: 180)

                // Y-axis labels on right, outside chart - TOP aligned with gridlines
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(sortedTierNamesForDisplay.enumerated()), id: \.offset) { index, name in
                        Text(name)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxHeight: .infinity, alignment: .top)
                    }
                }
                .frame(width: 60, height: 150)
                .padding(.top, 4)
            }
            .padding(.horizontal)
        }
    }

    /// Tier names sorted for display: Very High at TOP, Very Low at BOTTOM for stress
    private var sortedTierNamesForDisplay: [String] {
        // For stress: higher tier_order = worse = should be at top
        // sortedTiers is sorted ascending by tier_order (1=Very Low, 5=Very High)
        // We need to REVERSE so Very High (tier_order 5) is at top
        return sortedTiers.reversed().map { $0.tierName }
    }

    /// Y-axis domain values matching display order
    private var yAxisDomain: [Double] {
        // Return indices matching sortedTierNamesForDisplay (0=Very High at top, 4=Very Low at bottom)
        return Array(0..<sortedTiers.count).map { Double($0) }
    }

    private var stressChart: some View {
        let chartData = filteredChartData(forQuestion: currentFilterQuestion, selectedOption: currentSelectedOption)

        return Chart {
            ForEach(chartData, id: \.date) { point in
                let tierIndex = tierIndexForDisplay(for: point.score)
                let isSelected = selectedDate != nil && Calendar.current.isDate(point.date, equalTo: selectedDate!, toGranularity: .day)

                PointMark(
                    x: .value("Date", point.date, unit: selectedPeriod.calendarComponent),
                    y: .value("Level", tierIndex)
                )
                .foregroundStyle(point.tierColor ?? color)
                .symbolSize(isSelected ? 120 : 60)
            }
        }
        .chartYScale(domain: 0...Double(sortedTiers.count - 1))
        .chartYAxis {
            AxisMarks(values: yAxisDomain) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.3))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: xAxisStride)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.2))
                AxisValueLabel(format: xAxisFormat)
                    .foregroundStyle(Color.secondary)
            }
        }
        .chartScrollableAxes(.horizontal)
        .chartScrollPosition(x: $scrollPosition)
        .chartXVisibleDomain(length: selectedPeriod.visibleDomainSeconds)
        .chartGesture { proxy in
            SpatialTapGesture()
                .onEnded { value in
                    if let tappedDate: Date = proxy.value(atX: value.location.x) {
                        let closest = chartData.min(by: {
                            abs($0.date.timeIntervalSince(tappedDate)) < abs($1.date.timeIntervalSince(tappedDate))
                        })
                        if let closestDate = closest?.date {
                            if selectedDate != nil && Calendar.current.isDate(selectedDate!, equalTo: closestDate, toGranularity: .day) {
                                selectedDate = nil
                            } else {
                                selectedDate = closestDate
                            }
                        }
                    }
                }
        }
    }

    /// Map score to display index (0 = top = Very High for stress)
    private func tierIndexForDisplay(for score: Int) -> Double {
        guard let tier = assessmentData.tiers.first(where: { score >= $0.scoreMin && score <= $0.scoreMax }) else {
            return Double(sortedTiers.count - 1)
        }
        // sortedTiers: index 0 = Very Low (tier_order 1), index 4 = Very High (tier_order 5)
        // We want: Very High at top (index 0 in display), Very Low at bottom (index 4 in display)
        // So: displayIndex = (sortedTiers.count - 1) - originalIndex
        if let originalIndex = sortedTiers.firstIndex(where: { $0.tierOrder == tier.tierOrder }) {
            return Double(sortedTiers.count - 1 - originalIndex)
        }
        return Double(sortedTiers.count - 1)
    }

    // MARK: - Comparison Chart Section (Linked scroll/selection)

    private var comparisonChartSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(selectedComparisonMetric.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            .padding(.horizontal)

            HStack(alignment: .top, spacing: 0) {
                comparisonChart
                    .frame(height: 150)

                // Y-axis labels on right
                VStack(alignment: .leading, spacing: 0) {
                    Text(yAxisTopLabel)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxHeight: .infinity, alignment: .top)
                    Text(yAxisMidLabel)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxHeight: .infinity, alignment: .center)
                    Text(yAxisBottomLabel)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .frame(width: 50, height: 120)
                .padding(.top, 4)
            }
            .padding(.horizontal)
        }
    }

    private var yAxisTopLabel: String {
        switch selectedComparisonMetric {
        case .sleep: return "12 hr"
        case .exerciseMinutes: return "120 min"
        case .outdoorTime: return "4 hr"
        case .steps: return "20k"
        }
    }

    private var yAxisMidLabel: String {
        switch selectedComparisonMetric {
        case .sleep: return "6 hr"
        case .exerciseMinutes: return "60 min"
        case .outdoorTime: return "2 hr"
        case .steps: return "10k"
        }
    }

    private var yAxisBottomLabel: String {
        switch selectedComparisonMetric {
        case .sleep: return "0"
        case .exerciseMinutes, .outdoorTime: return "0"
        case .steps: return "0"
        }
    }

    private var comparisonChart: some View {
        Chart {
            ForEach(comparisonData, id: \.date) { point in
                let isSelected = selectedDate != nil && Calendar.current.isDate(point.date, equalTo: selectedDate!, toGranularity: selectedPeriod.calendarComponent)

                if selectedComparisonMetric == .sleep {
                    // Time In Bed = darker/behind (lower opacity)
                    // Time Asleep = brighter/in front (higher opacity)
                    // Draw Time In Bed FIRST (behind), then Time Asleep on top
                    if point.timeInBed > 0 {
                        BarMark(
                            x: .value("Date", point.date, unit: selectedPeriod.calendarComponent),
                            y: .value("Time In Bed", point.timeInBed)
                        )
                        .foregroundStyle(Color.indigo.opacity(isSelected ? 0.5 : 0.35))
                        .cornerRadius(2)
                    }

                    if point.value > 0 {
                        BarMark(
                            x: .value("Date", point.date, unit: selectedPeriod.calendarComponent),
                            y: .value("Time Asleep", point.value)
                        )
                        .foregroundStyle(Color.indigo.opacity(isSelected ? 1.0 : 0.8))
                        .cornerRadius(2)
                    }
                } else {
                    if point.value > 0 {
                        BarMark(
                            x: .value("Date", point.date, unit: selectedPeriod.calendarComponent),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(selectedComparisonMetric.color.opacity(isSelected ? 1.0 : 0.7))
                        .cornerRadius(2)
                    }
                }
            }
        }
        .chartYScale(domain: 0...comparisonYAxisMax)
        .chartYAxis {
            AxisMarks(values: [0, comparisonYAxisMax / 2, comparisonYAxisMax]) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.3))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: xAxisStride)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.2))
                AxisValueLabel(format: xAxisFormat)
                    .foregroundStyle(Color.secondary)
            }
        }
        .chartScrollableAxes(.horizontal)
        .chartScrollPosition(x: $scrollPosition)  // LINKED scroll with stress chart
        .chartXVisibleDomain(length: selectedPeriod.visibleDomainSeconds)
        .chartGesture { proxy in
            SpatialTapGesture()
                .onEnded { value in
                    if let tappedDate: Date = proxy.value(atX: value.location.x) {
                        let closest = comparisonData
                            .filter { $0.value > 0 || $0.timeInBed > 0 }
                            .min(by: {
                                abs($0.date.timeIntervalSince(tappedDate)) < abs($1.date.timeIntervalSince(tappedDate))
                            })
                        if let closestDate = closest?.date {
                            if selectedDate != nil && Calendar.current.isDate(selectedDate!, equalTo: closestDate, toGranularity: selectedPeriod.calendarComponent) {
                                selectedDate = nil
                            } else {
                                selectedDate = closestDate
                            }
                        }
                    }
                }
        }
    }

    private var comparisonYAxisMax: Double {
        switch selectedComparisonMetric {
        case .sleep: return 12
        case .exerciseMinutes: return 120
        case .outdoorTime: return 4
        case .steps: return 20000
        }
    }

    private var xAxisStride: Calendar.Component {
        switch selectedPeriod {
        case .week: return .day
        case .month: return .weekOfYear
        case .sixMonth: return .month
        case .year: return .month
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch selectedPeriod {
        case .week: return .dateTime.weekday(.abbreviated)
        case .month: return .dateTime.day()
        case .sixMonth: return .dateTime.month(.abbreviated)
        case .year: return .dateTime.month(.narrow)
        }
    }

    // MARK: - Cards Section

    private var currentFilterQuestion: String? {
        switch selectedTab {
        case .stressors: return "STRESS_SOURCES"
        case .symptoms: return "STRESS_SYMPTOMS"
        case .compare: return nil
        }
    }

    private var currentSelectedOption: Int? {
        switch selectedTab {
        case .stressors: return selectedStressor
        case .symptoms: return selectedSymptom
        case .compare: return nil
        }
    }

    @ViewBuilder
    private var cardsSection: some View {
        VStack(spacing: 12) {
            switch selectedTab {
            case .stressors:
                ForEach(stressorOptions, id: \.displayOrder) { option in
                    InsightCard(
                        title: option.optionText,
                        value: countString(for: "STRESS_SOURCES", displayOrder: option.displayOrder),
                        isSelected: selectedStressor == option.displayOrder,
                        color: color
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedStressor = selectedStressor == option.displayOrder ? nil : option.displayOrder
                        }
                    }
                }

            case .symptoms:
                ForEach(symptomOptions, id: \.displayOrder) { option in
                    InsightCard(
                        title: option.optionText,
                        value: countString(for: "STRESS_SYMPTOMS", displayOrder: option.displayOrder),
                        isSelected: selectedSymptom == option.displayOrder,
                        color: color
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSymptom = selectedSymptom == option.displayOrder ? nil : option.displayOrder
                        }
                    }
                }

            case .compare:
                ForEach(ComparisonMetric.allCases, id: \.self) { metric in
                    InsightCard(
                        title: metric.displayName,
                        value: comparisonValueString(for: metric),
                        isSelected: selectedComparisonMetric == metric,
                        color: metric.color,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedComparisonMetric = metric
                            }
                        },
                        showInfoButton: true,
                        onInfoTap: {
                            infoMetric = metric
                            showingMetricInfo = true
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showingMetricInfo) {
            if let metric = infoMetric {
                MetricInfoSheet(metric: metric)
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Data Helpers

    private var sortedTiers: [ViewAssessmentTier] {
        assessmentData.tiers.sorted { $0.tierOrder < $1.tierOrder }
    }

    private var filteredScoreHistory: [AssessmentResult] {
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -selectedPeriod.days, to: now) ?? now
        return scoreHistory.filter { $0.date >= startDate }
    }

    private var stressorOptions: [ViewAssessmentResponseOption] {
        assessmentData.options(for: "STRESS_SOURCES")
    }

    private var symptomOptions: [ViewAssessmentResponseOption] {
        assessmentData.options(for: "STRESS_SYMPTOMS")
    }

    private func countForOption(questionId: String, displayOrder: Int) -> Int {
        filteredScoreHistory.filter { result in
            guard let responses = result.responses,
                  let bitmask = responses[questionId] else { return false }
            let bitPosition = displayOrder - 1
            return bitPosition >= 0 && (bitmask & (1 << bitPosition)) != 0
        }.count
    }

    private func countString(for questionId: String, displayOrder: Int) -> String {
        let count = countForOption(questionId: questionId, displayOrder: displayOrder)
        return count > 0 ? "\(count)" : "--"
    }

    private func comparisonValueString(for metric: ComparisonMetric) -> String {
        guard !comparisonData.isEmpty else { return "--" }

        if metric == .sleep {
            let sleepValues = comparisonData.filter { $0.value > 0 }.map { $0.value }
            guard !sleepValues.isEmpty else { return "--" }

            let minSleep = sleepValues.min() ?? 0
            let maxSleep = sleepValues.max() ?? 0

            if minSleep == maxSleep {
                return formatDurationShort(maxSleep)
            }
            return "\(formatDurationShort(minSleep))–\(formatDurationShort(maxSleep))"
        }

        let values = comparisonData.map { $0.value }.filter { $0 > 0 }
        guard !values.isEmpty else { return "--" }

        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 0

        switch metric {
        case .sleep:
            return "--" // handled above
        case .exerciseMinutes, .outdoorTime:
            if Int(minVal) == Int(maxVal) {
                return "\(Int(maxVal)) min"
            }
            return "\(Int(minVal))–\(Int(maxVal)) min"
        case .steps:
            if Int(minVal) == Int(maxVal) {
                return "\(Int(maxVal))"
            }
            return "\(Int(minVal))–\(Int(maxVal))"
        }
    }

    private func formatDurationShort(_ hours: Double) -> String {
        let totalMinutes = Int(hours * 60)
        let hrs = totalMinutes / 60
        let mins = totalMinutes % 60
        return "\(hrs)h \(mins)m"
    }

    private func filteredChartData(forQuestion questionId: String?, selectedOption: Int?) -> [StressChartPoint] {
        let results = filteredScoreHistory.filter { result in
            guard let questionId = questionId, let selectedOption = selectedOption else {
                return true
            }
            guard let responses = result.responses,
                  let bitmask = responses[questionId] else { return false }
            let bitPosition = selectedOption - 1
            return bitPosition >= 0 && (bitmask & (1 << bitPosition)) != 0
        }

        return results.map { result in
            StressChartPoint(
                date: result.date,
                score: result.score,
                tierColor: result.tierColor
            )
        }
    }

    // MARK: - Load Comparison Data (REAL DATA from database)

    private func loadComparisonData() async {
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -selectedPeriod.days, to: now) ?? now

        switch selectedComparisonMetric {
        case .sleep:
            await loadSleepData(startDate: startDate, endDate: now)
        case .steps:
            await loadStepsData(startDate: startDate, endDate: now)
        case .exerciseMinutes:
            await loadExerciseData(startDate: startDate, endDate: now)
        case .outdoorTime:
            await loadOutdoorTimeData(startDate: startDate, endDate: now)
        }
    }

    private func loadSleepData(startDate: Date, endDate: Date) async {
        let supabase = SupabaseManager.shared.client
        guard let userId = try? await supabase.auth.session.user.id.uuidString else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        do {
            // Query sleep sessions summary
            let sleepData: [SleepComparisonRow] = try await supabase
                .from("patient_sleep_sessions_summary")
                .select("sleep_date, total_sleep_minutes, time_in_bed_minutes")
                .eq("patient_id", value: userId)
                .gte("sleep_date", value: dateFormatter.string(from: startDate))
                .lte("sleep_date", value: dateFormatter.string(from: endDate))
                .order("sleep_date", ascending: true)
                .execute()
                .value

            // Aggregate based on period
            if selectedPeriod == .sixMonth || selectedPeriod == .year {
                // Aggregate to weekly or monthly averages
                comparisonData = aggregateSleepData(sleepData, by: selectedPeriod.calendarComponent, using: dateFormatter)
            } else {
                // Daily data
                comparisonData = sleepData.compactMap { row in
                    guard let date = dateFormatter.date(from: row.sleepDate) else { return nil }
                    let timeAsleepHours = (row.totalSleepMinutes ?? 0) / 60.0
                    let timeInBedHours = (row.timeInBedMinutes ?? 0) / 60.0
                    return ComparisonDataPoint(date: date, value: timeAsleepHours, timeInBed: timeInBedHours)
                }
            }
        } catch {
            print("[StressInsights] Error loading sleep data: \(error)")
            comparisonData = []
        }
    }

    private func aggregateSleepData(_ data: [SleepComparisonRow], by component: Calendar.Component, using formatter: DateFormatter) -> [ComparisonDataPoint] {
        let calendar = Calendar.current
        var grouped: [Date: (sleepSum: Double, bedSum: Double, count: Int)] = [:]

        for row in data {
            guard let date = formatter.date(from: row.sleepDate) else { continue }
            let periodStart = calendar.dateInterval(of: component, for: date)?.start ?? date

            let existing = grouped[periodStart] ?? (0, 0, 0)
            grouped[periodStart] = (
                existing.sleepSum + (row.totalSleepMinutes ?? 0),
                existing.bedSum + (row.timeInBedMinutes ?? 0),
                existing.count + 1
            )
        }

        return grouped.map { date, values in
            ComparisonDataPoint(
                date: date,
                value: (values.sleepSum / Double(values.count)) / 60.0,  // Average hours
                timeInBed: (values.bedSum / Double(values.count)) / 60.0
            )
        }.sorted { $0.date < $1.date }
    }

    private func loadStepsData(startDate: Date, endDate: Date) async {
        let supabase = SupabaseManager.shared.client
        guard let userId = try? await supabase.auth.session.user.id.uuidString else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        do {
            // Query steps from patient_quantity_samples
            let stepsData: [QuantitySampleRow] = try await supabase
                .from("patient_quantity_samples")
                .select("sample_date, value")
                .eq("patient_id", value: userId)
                .eq("quantity_type", value: "steps")
                .gte("sample_date", value: dateFormatter.string(from: startDate))
                .lte("sample_date", value: dateFormatter.string(from: endDate))
                .order("sample_date", ascending: true)
                .execute()
                .value

            // Aggregate by date (sum steps per day)
            var stepsByDate: [String: Double] = [:]
            for row in stepsData {
                stepsByDate[row.sampleDate, default: 0] += row.value ?? 0
            }

            let dailyData = stepsByDate.compactMap { dateString, steps -> ComparisonDataPoint? in
                guard let date = dateFormatter.date(from: dateString) else { return nil }
                return ComparisonDataPoint(date: date, value: steps, timeInBed: 0)
            }.sorted { $0.date < $1.date }

            // Aggregate if needed
            if selectedPeriod == .sixMonth || selectedPeriod == .year {
                comparisonData = aggregateSimpleData(dailyData, by: selectedPeriod.calendarComponent)
            } else {
                comparisonData = dailyData
            }
        } catch {
            print("[StressInsights] Error loading steps data: \(error)")
            comparisonData = []
        }
    }

    private func loadExerciseData(startDate: Date, endDate: Date) async {
        let supabase = SupabaseManager.shared.client
        guard let userId = try? await supabase.auth.session.user.id.uuidString else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        do {
            // Query exercise minutes from patient_quantity_samples
            let exerciseData: [QuantitySampleRow] = try await supabase
                .from("patient_quantity_samples")
                .select("sample_date, value")
                .eq("patient_id", value: userId)
                .eq("quantity_type", value: "exercise_time")
                .gte("sample_date", value: dateFormatter.string(from: startDate))
                .lte("sample_date", value: dateFormatter.string(from: endDate))
                .order("sample_date", ascending: true)
                .execute()
                .value

            // Aggregate by date (sum minutes per day)
            var exerciseByDate: [String: Double] = [:]
            for row in exerciseData {
                exerciseByDate[row.sampleDate, default: 0] += row.value ?? 0
            }

            let dailyData = exerciseByDate.compactMap { dateString, minutes -> ComparisonDataPoint? in
                guard let date = dateFormatter.date(from: dateString) else { return nil }
                return ComparisonDataPoint(date: date, value: minutes, timeInBed: 0)
            }.sorted { $0.date < $1.date }

            if selectedPeriod == .sixMonth || selectedPeriod == .year {
                comparisonData = aggregateSimpleData(dailyData, by: selectedPeriod.calendarComponent)
            } else {
                comparisonData = dailyData
            }
        } catch {
            print("[StressInsights] Error loading exercise data: \(error)")
            comparisonData = []
        }
    }

    private func loadOutdoorTimeData(startDate: Date, endDate: Date) async {
        let supabase = SupabaseManager.shared.client
        guard let userId = try? await supabase.auth.session.user.id.uuidString else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        do {
            // Query time in daylight from patient_quantity_samples
            let outdoorData: [QuantitySampleRow] = try await supabase
                .from("patient_quantity_samples")
                .select("sample_date, value")
                .eq("patient_id", value: userId)
                .eq("quantity_type", value: "time_in_daylight")
                .gte("sample_date", value: dateFormatter.string(from: startDate))
                .lte("sample_date", value: dateFormatter.string(from: endDate))
                .order("sample_date", ascending: true)
                .execute()
                .value

            // Aggregate by date (sum hours per day)
            var outdoorByDate: [String: Double] = [:]
            for row in outdoorData {
                outdoorByDate[row.sampleDate, default: 0] += row.value ?? 0
            }

            let dailyData = outdoorByDate.compactMap { dateString, hours -> ComparisonDataPoint? in
                guard let date = dateFormatter.date(from: dateString) else { return nil }
                return ComparisonDataPoint(date: date, value: hours, timeInBed: 0)
            }.sorted { $0.date < $1.date }

            if selectedPeriod == .sixMonth || selectedPeriod == .year {
                comparisonData = aggregateSimpleData(dailyData, by: selectedPeriod.calendarComponent)
            } else {
                comparisonData = dailyData
            }
        } catch {
            print("[StressInsights] Error loading outdoor time data: \(error)")
            comparisonData = []
        }
    }

    private func aggregateSimpleData(_ data: [ComparisonDataPoint], by component: Calendar.Component) -> [ComparisonDataPoint] {
        let calendar = Calendar.current
        var grouped: [Date: (sum: Double, count: Int)] = [:]

        for point in data {
            let periodStart = calendar.dateInterval(of: component, for: point.date)?.start ?? point.date
            let existing = grouped[periodStart] ?? (0, 0)
            grouped[periodStart] = (existing.sum + point.value, existing.count + 1)
        }

        return grouped.map { date, values in
            ComparisonDataPoint(
                date: date,
                value: values.sum / Double(values.count),  // Average
                timeInBed: 0
            )
        }.sorted { $0.date < $1.date }
    }
}

// MARK: - Database Row Types

private struct SleepComparisonRow: Codable {
    let sleepDate: String
    let totalSleepMinutes: Double?
    let timeInBedMinutes: Double?

    enum CodingKeys: String, CodingKey {
        case sleepDate = "sleep_date"
        case totalSleepMinutes = "total_sleep_minutes"
        case timeInBedMinutes = "time_in_bed_minutes"
    }
}

private struct QuantitySampleRow: Codable {
    let sampleDate: String
    let value: Double?

    enum CodingKeys: String, CodingKey {
        case sampleDate = "sample_date"
        case value
    }
}

// MARK: - Insight Card (Apple Health style - compact)

struct InsightCard: View {
    let title: String
    let value: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    var showInfoButton: Bool = false
    var onInfoTap: (() -> Void)? = nil

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .white : .primary)

                Spacer()

                Text(value)
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)

                if showInfoButton {
                    Button {
                        onInfoTap?()
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.subheadline)
                            .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? color : Color(uiColor: .secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Supporting Types

struct StressChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let score: Int
    let tierColor: Color?
}

struct ComparisonDataPoint {
    let date: Date
    let value: Double
    let timeInBed: Double // For sleep only
}

enum ComparisonMetric: String, CaseIterable {
    case sleep = "sleep"
    case exerciseMinutes = "exercise_minutes"
    case outdoorTime = "outdoor_time"
    case steps = "steps"

    var displayName: String {
        switch self {
        case .sleep: return "Sleep"
        case .exerciseMinutes: return "Exercise Minutes"
        case .outdoorTime: return "Time In Daylight"
        case .steps: return "Steps"
        }
    }

    var color: Color {
        switch self {
        case .sleep: return .indigo
        case .exerciseMinutes: return .green
        case .outdoorTime: return .orange
        case .steps: return .blue
        }
    }

    var icon: String {
        switch self {
        case .sleep: return "bed.double.fill"
        case .exerciseMinutes: return "figure.run"
        case .outdoorTime: return "sun.max.fill"
        case .steps: return "figure.walk"
        }
    }

    var stressImpactDescription: String {
        switch self {
        case .sleep:
            return "Quality sleep is essential for stress management. Poor sleep can increase cortisol levels, impair emotional regulation, and make it harder to cope with daily stressors. Aim for 7-9 hours of quality sleep each night."
        case .exerciseMinutes:
            return "Physical activity is one of the most effective ways to reduce stress. Exercise releases endorphins, improves mood, and helps regulate the body's stress response. Even short bouts of activity can make a difference."
        case .outdoorTime:
            return "Spending time outdoors, especially in natural settings, has been shown to lower cortisol levels and improve mood. Natural light exposure also helps regulate your circadian rhythm, which supports better sleep."
        case .steps:
            return "Daily movement throughout the day helps manage stress by preventing prolonged sedentary periods. Regular walking promotes circulation, clears the mind, and provides natural breaks from stressful activities."
        }
    }

    var quickTips: [String] {
        switch self {
        case .sleep:
            return [
                "Keep a consistent sleep schedule",
                "Avoid screens 1 hour before bed",
                "Keep your bedroom cool and dark",
                "Limit caffeine after 2 PM"
            ]
        case .exerciseMinutes:
            return [
                "Start with just 10 minutes a day",
                "Find activities you enjoy",
                "Schedule exercise like an appointment",
                "Mix cardio with strength training"
            ]
        case .outdoorTime:
            return [
                "Take a short walk during lunch",
                "Have morning coffee outside",
                "Walk meetings when possible",
                "Weekend hikes or park visits"
            ]
        case .steps:
            return [
                "Take the stairs when possible",
                "Park further from entrances",
                "Set hourly movement reminders",
                "Walk while taking phone calls"
            ]
        }
    }
}

// MARK: - Metric Info Sheet

struct MetricInfoSheet: View {
    let metric: ComparisonMetric
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Icon and title
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(metric.color.opacity(0.15))
                                .frame(width: 50, height: 50)
                            Image(systemName: metric.icon)
                                .font(.title2)
                                .foregroundColor(metric.color)
                        }
                        Text(metric.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }

                    // Impact on stress section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Impact on Stress")
                            .font(.headline)

                        Text(metric.stressImpactDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Quick tips
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Tips")
                            .font(.headline)

                        ForEach(metric.quickTips, id: \.self) { tip in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(metric.color)
                                Text(tip)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer(minLength: 20)

                    // Log button
                    Button {
                        // TODO: Navigate to log entry for this metric
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Log \(metric.displayName)")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(metric.color)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("About \(metric.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

#Preview {
    Text("Preview requires AssessmentData")
}
