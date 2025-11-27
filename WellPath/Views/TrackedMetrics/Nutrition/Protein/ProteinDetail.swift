//
//  ProteinDetailView.swift
//  WellPath
//
//  Detail screen for Protein with Timing, Type, and Per Body Weight views
//

import SwiftUI
import Charts

enum ProteinDetailTab: String, CaseIterable {
    case timing = "Timing"
    case type = "Type"
    case gPerKg = "Ratio"
}

struct ProteinDetail: View {
    @State private var selectedTab: ProteinDetailTab = .timing

    // Get color and icon dynamically from database via display_screens
    // For now, hardcoded for protein - TODO: make this generic
    let color = MetricsUIConfig.getPillarColor(for: "Healthful Nutrition")
    let screenIcon = MetricsUIConfig.getIcon(for: "Protein Intake")

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("View", selection: $selectedTab) {
                ForEach(ProteinDetailTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 4)
            .padding(.bottom, 8)

            // Content based on selected tab (each tab handles its own scrolling)
            Group {
                switch selectedTab {
                case .timing:
                    ProteinTimingView(color: color)
                case .type:
                    ProteinTypeView(color: color)
                case .gPerKg:
                    ProteinPerBodyWeightView(color: color)
                }
            }
        }
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
        .navigationTitle("Protein Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Timing View (Chart/About split)

struct ProteinTimingView: View {
    let color: Color
    @StateObject private var educationViewModel = TabEducationViewModel(metricId: "DISP_PROTEIN_MEAL_TIMING")
    @State private var showAbout = false

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Protein Intake")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content
            if showAbout {
                aboutContentView
            } else {
                ProteinTimingTimelineView(color: color, showAbout: $showAbout)
            }
        }
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
        .task {
            await educationViewModel.loadEducation()
        }
    }

    private var aboutContentView: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                if let education = educationViewModel.education {
                    VStack(alignment: .leading, spacing: 24) {
                        if let about = education.aboutContent {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 10) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(color)
                                    Text("About")
                                        .font(.headline)
                                }
                                Text(about)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if let impact = education.longevityImpact {
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

                        if let tips = education.quickTips {
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
                    .padding(.top, 40) // Space for close button
                }
            }
            .background(Color.clear)

            // Close button (floating, top-right)
            Button(action: {
                withAnimation {
                    showAbout = false
                }
            }) {
                Image(systemName: "chart.bar")
                    .font(.title3)
                    .foregroundColor(color)
            }
            .padding(.top, 8)
            .padding(.trailing, 16)
        }
        .background(Color.clear)
    }
}

// MARK: - Type View (Tier-based with expandable types)

struct ProteinTypeView: View {
    let color: Color

    var body: some View {
        ProteinTiersView(color: color)
    }
}

// MARK: - Ratio View (Line Chart with period toggles)

enum ProteinRatioUnit: String, CaseIterable {
    case gPerKg = "g/kg"
    case gPerLb = "g/lb"
}

struct ProteinPerBodyWeightView: View {
    let color: Color
    @StateObject private var viewModel = ProteinPerBodyWeightViewModel()
    @StateObject private var educationViewModel = TabEducationViewModel(metricId: "DISP_PROTEIN_PER_KG")
    @State private var showAbout = false
    @State private var selectedPeriod: TimePeriod = .week
    @State private var scrollPosition: Date
    @State private var selectedDate: Date?
    @State private var chartID = UUID()
    @State private var selectedUnit: ProteinRatioUnit = .gPerKg

    private let unitService = UnitConversionService.shared

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Protein Intake")
    }

    // Optimal range in g/kg (backend standard)
    private let optimalRangeGPerKg: ClosedRange<Double> = 1.2...1.6

    // Convert optimal range based on selected unit
    private var optimalRangeLow: Double {
        selectedUnit == .gPerKg ? optimalRangeGPerKg.lowerBound : unitService.gPerKgToGPerLb(optimalRangeGPerKg.lowerBound)
    }

    private var optimalRangeHigh: Double {
        selectedUnit == .gPerKg ? optimalRangeGPerKg.upperBound : unitService.gPerKgToGPerLb(optimalRangeGPerKg.upperBound)
    }

    private var unitLabel: String {
        selectedUnit.rawValue
    }

    // Get value in selected unit from a data point
    private func displayValue(for dataPoint: ProteinPerBodyWeightData) -> Double {
        selectedUnit == .gPerKg ? dataPoint.perKg : dataPoint.perLb
    }

    // Get average in selected unit
    private func displayAverage(for period: TimePeriod, scrollPosition: Date) -> Double {
        selectedUnit == .gPerKg
            ? viewModel.calculateAveragePerKg(for: period, scrollPosition: scrollPosition)
            : viewModel.calculateAveragePerLb(for: period, scrollPosition: scrollPosition)
    }

    init(color: Color) {
        self.color = color

        // Initialize scroll position so TODAY is ~90% across the visible window (leaving 10% for future)
        let now = Date()
        let initialPeriod = TimePeriod.week
        let visibleDuration = initialPeriod.numberOfBars  // 7 for week
        let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
        let scrollStart = Calendar.current.date(
            byAdding: initialPeriod.calendarComponent,  // .day for week
            value: -offsetFromEnd,
            to: now
        ) ?? now
        _scrollPosition = State(initialValue: scrollStart)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content
            if showAbout {
                aboutContentView
            } else {
                chartView
            }
        }
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
        .task {
            await viewModel.loadData(for: selectedPeriod)
            await educationViewModel.loadEducation()

            // Set scroll position after initial load so TODAY is ~90% across the visible window (leaving 10% for future)
            let now = Date()
            let visibleDuration = selectedPeriod.numberOfBars
            let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
            scrollPosition = Calendar.current.date(
                byAdding: selectedPeriod.calendarComponent,
                value: -offsetFromEnd,
                to: now
            ) ?? now

            chartID = UUID()  // Force chart recreation with correct scroll position

            print("📊 G/KG: Initial scrollPosition=\(scrollPosition)")
        }
    }

    private var chartView: some View {
        VStack(spacing: 0) {
            if !viewModel.isLoading {
                VStack(spacing: 0) {
                    // Period picker (excluding Day - doesn't make sense for ratios)
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(TimePeriod.allCases.filter { $0 != .day }, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 16)

                    // Unit toggle (g/kg vs g/lb)
                    HStack {
                        Spacer()
                        Picker("Unit", selection: $selectedUnit) {
                            ForEach(ProteinRatioUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    .onChange(of: selectedPeriod) { oldValue, newPeriod in
                        selectedDate = nil

                        // Reset scroll position so TODAY is ~90% across the visible window (leaving 10% for future)
                        let now = Date()
                        let visibleDuration = newPeriod.numberOfBars
                        let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
                        scrollPosition = Calendar.current.date(
                            byAdding: newPeriod.calendarComponent,
                            value: -offsetFromEnd,
                            to: now
                        ) ?? now

                        chartID = UUID()  // Force chart recreation with new scroll position

                        print("📊 G/KG: Set scrollPosition=\(scrollPosition) for period=\(newPeriod)")

                        Task {
                            await viewModel.loadData(for: newPeriod)
                        }
                    }

                    // Value display with info button
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 4) {
                            if let date = selectedDate,
                               let selected = viewModel.chartData.first(where: { Calendar.current.isDate($0.date, equalTo: date, toGranularity: .day) }) {

                                Text(formatSelectedDateLabel(date))
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text(String(format: "%.2f", displayValue(for: selected)))
                                        .font(.system(size: 48, weight: .semibold))
                                        .foregroundColor(color)
                                    Text(unitLabel)
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text(getAggregateLabel())
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text(String(format: "%.2f", displayAverage(for: selectedPeriod, scrollPosition: scrollPosition)))
                                        .font(.system(size: 48, weight: .semibold))
                                        .foregroundColor(color)
                                    Text(unitLabel)
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        Spacer()

                        // Info button (top-aligned with metrics)
                        Button(action: {
                            withAnimation {
                                showAbout = true
                            }
                        }) {
                            Image(systemName: "info.circle.fill")
                                .font(.title3)
                                .foregroundColor(color)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 24)

                    // Line chart
                Chart {
                    // Optimal range band - horizontal lines marking the target range
                    RuleMark(y: .value("OptimalLow", optimalRangeLow))
                        .foregroundStyle(Color.blue.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))

                    RuleMark(y: .value("OptimalHigh", optimalRangeHigh))
                        .foregroundStyle(Color.blue.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))

                    ForEach(viewModel.chartData) { dataPoint in
                        // Invisible placeholder for ALL points to establish x-axis domain
                        PointMark(
                            x: .value("Date", dataPoint.date),
                            y: .value("Ratio", 0)
                        )
                        .opacity(0)

                        // Only show line/area/points for non-zero values
                        let value = displayValue(for: dataPoint)
                        if value > 0 {
                            // User data line
                            LineMark(
                                x: .value("Date", dataPoint.date),
                                y: .value("Ratio", value)
                            )
                            .foregroundStyle(color)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 3))

                            // Area under line
                            AreaMark(
                                x: .value("Date", dataPoint.date),
                                y: .value("Ratio", value)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [color.opacity(0.2), color.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)

                            // Point marks (no annotation here - will use overlay)
                            if let selectedDate = selectedDate,
                               Calendar.current.isDate(dataPoint.date, equalTo: selectedDate, toGranularity: .day) {
                                // Selected point (larger)
                                PointMark(
                                    x: .value("Date", dataPoint.date),
                                    y: .value("Ratio", value)
                                )
                                .foregroundStyle(color)
                                .symbolSize(150)
                            } else {
                                // Regular point (not selected)
                                PointMark(
                                    x: .value("Date", dataPoint.date),
                                    y: .value("Ratio", value)
                                )
                                .foregroundStyle(color)
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...(max(viewModel.chartData.map { displayValue(for: $0) }.max() ?? (selectedUnit == .gPerKg ? 2.5 : 1.2), selectedUnit == .gPerKg ? 2.5 : 1.2)))
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        // Display annotation for selected point
                        if let selectedDate = selectedDate,
                           let selectedData = viewModel.chartData.first(where: { Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: .day) }),
                           displayValue(for: selectedData) > 0 {

                            // Get the position of the selected point
                            let yValue = displayValue(for: selectedData)
                            if let xPos = proxy.position(forX: selectedData.date),
                               let yPos = proxy.position(forY: yValue) {

                                // Annotation content
                                VStack(spacing: 4) {
                                    if let grams = selectedData.grams, let kg = selectedData.kg {
                                        let weightLabel = selectedUnit == .gPerKg
                                            ? "kg: \(String(format: "%.1f", kg))"
                                            : "lb: \(String(format: "%.1f", kg * 2.2046))"
                                        Text("g: \(String(format: "%.0f", grams)) / \(weightLabel)")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                    } else {
                                        Text("Calculation data unavailable")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(uiColor: .systemBackground))
                                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                                )
                                // Position the annotation above the point, but ensure it doesn't go off screen
                                .position(x: xPos, y: max(30, yPos - 40))
                            }
                        }
                    }
                }
                .frame(height: 220)
                .chartScrollableAxes(.horizontal)
                .chartScrollPosition(x: $scrollPosition)
                .chartXVisibleDomain(length: getVisibleDomainTimeInterval())
                .id(chartID)
                .chartGesture { proxy in
                    SpatialTapGesture()
                        .onEnded { value in
                            if let tappedDate: Date = proxy.value(atX: value.location.x) {
                                let closest = viewModel.chartData.min(by: {
                                    abs($0.date.timeIntervalSince(tappedDate)) < abs($1.date.timeIntervalSince(tappedDate))
                                })
                                
                                if selectedDate == closest?.date {
                                    selectedDate = nil
                                } else {
                                    selectedDate = closest?.date
                                }
                            }
                        }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: getAxisStride(), count: getAxisMultiplier())) { value in
                        if value.as(Date.self) != nil {
                            AxisValueLabel(format: getAxisFormat())
                            AxisGridLine()
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 24)
                .padding(.bottom, 16)
                }

                // Optimal range info - subtle, centered
                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.caption)
                            .foregroundColor(Color.blue.opacity(0.7))
                        Text("Optimal: \(String(format: "%.2f", optimalRangeLow))-\(String(format: "%.2f", optimalRangeHigh)) \(unitLabel)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(8)
                    Spacer()
                }
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
    }

    private var aboutContentView: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                if let education = educationViewModel.education {
                    VStack(alignment: .leading, spacing: 24) {
                        if let about = education.aboutContent {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 10) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(color)
                                    Text("About Protein Efficiency")
                                        .font(.headline)
                                }
                                Text(about)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if let impact = education.longevityImpact {
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

                        if let tips = education.quickTips {
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

                        // Optimal range explanation
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                                    .foregroundColor(color)
                                Text("Optimal Range")
                                    .font(.headline)
                            }
                            Text("The blue band on the chart shows the optimal protein intake range of \(String(format: "%.2f", optimalRangeLow))-\(String(format: "%.2f", optimalRangeHigh)) \(unitLabel) body weight for active adults.")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .padding(.top, 40) // Space for close button
                }
            }
            .background(Color.clear)

            // Close button (floating, top-right)
            Button(action: {
                withAnimation {
                    showAbout = false
                }
            }) {
                Image(systemName: "chart.bar")
                    .font(.title3)
                    .foregroundColor(color)
            }
            .padding(.top, 8)
            .padding(.trailing, 16)
        }
        .background(Color.clear)
    }

    // MARK: - Helpers

    private func getVisibleDomainLength() -> Int {
        switch selectedPeriod {
        case .day: return 24      // 24 hours (each bar = that hour)
        case .week: return 7      // 7 days (each bar = that day)
        case .month: return 33    // 33 days (each bar = that day)
        case .sixMonth: return 26 // 26 weeks (each bar = weekly average)
        case .year: return 12     // 12 months (each bar = monthly average)
        }
    }

    private func getVisibleDomainTimeInterval() -> TimeInterval {
        switch selectedPeriod {
        case .day: return 24 * 3600 // 24 hours in seconds
        case .week: return 7 * 24 * 3600 // 7 days in seconds
        case .month: return 30 * 24 * 3600 // 30 days in seconds
        case .sixMonth: return 26 * 7 * 24 * 3600 // 26 weeks in seconds
        case .year: return 365 * 24 * 3600 // 1 year in seconds
        }
    }
    
    private func getAxisStride() -> Calendar.Component {
        switch selectedPeriod {
        case .day: return .hour
        case .week: return .day
        case .month: return .weekOfYear
        case .sixMonth: return .weekOfYear  // Points are weeks, so stride by week
        case .year: return .month
        }
    }

    private func getAxisMultiplier() -> Int {
        switch selectedPeriod {
        case .day: return 6  // Every 6 hours
        case .week: return 1  // Every day
        case .month: return 1  // Every week
        case .sixMonth: return 4  // Every 4 weeks (~monthly labels)
        case .year: return 1  // Every month
        }
    }
    
    private func getAxisFormat() -> Date.FormatStyle {
        switch selectedPeriod {
        case .day: return .dateTime.hour(.defaultDigits(amPM: .abbreviated))
        case .week: return .dateTime.weekday(.narrow)
        case .month: return .dateTime.day(.defaultDigits)
        case .sixMonth: return .dateTime.month(.abbreviated)
        case .year: return .dateTime.month(.narrow)
        }
    }

    // Custom label for g/kg that doesn't use "Total" or "Average"
    private func getAggregateLabel() -> String {
        switch selectedPeriod {
        case .day: return "DAY"
        case .week: return "WEEK"
        case .month: return "MONTH"
        case .sixMonth: return "6 MONTHS"
        case .year: return "YEAR"
        }
    }

    private func formatSelectedDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        switch selectedPeriod {
        case .day:
            // Point = 1 hour
            formatter.dateFormat = "h:00 a"
            return formatter.string(from: date)
        case .week, .month:
            // Point = 1 day
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        case .sixMonth:
            // Point = 1 week - show week range
            guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: date) else {
                formatter.dateFormat = "MMM d"
                return formatter.string(from: date)
            }
            let startFormatter = DateFormatter()
            startFormatter.dateFormat = "MMM d"
            let endFormatter = DateFormatter()
            endFormatter.dateFormat = "d"
            return "\(startFormatter.string(from: date))-\(endFormatter.string(from: weekEnd))"
        case .year:
            // Point = 1 month - show month name
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }
    }
}

// MARK: - View Models

/// Lightweight struct for decoding weight readings from patient_biometric_readings
private struct WeightReading: Codable {
    let value: Double
    let recordedAt: Date
    let unit: String?

    enum CodingKeys: String, CodingKey {
        case value
        case recordedAt = "recorded_at"
        case unit
    }
}

@MainActor
class ProteinPerBodyWeightViewModel: ObservableObject {
    @Published var chartData: [ProteinPerBodyWeightData] = []
    @Published var averagePerKg: Double = 0
    @Published var averagePerLb: Double = 0
    @Published var isLoading = true

    private let supabase = SupabaseManager.shared.client
    private let unitService = UnitConversionService.shared

    func loadData(for period: TimePeriod) async {
        isLoading = true

        // Ensure unit conversions are loaded
        await unitService.loadConversions()

        do {
            let userId = try await supabase.auth.session.user.id
            let periodType = period.databasePeriodType

            // Calculate date range for query - small initial ranges for performance
            let now = Date()
            let calendar = Calendar.current
            let newestDate = calendar.date(byAdding: .month, value: 1, to: now) ?? now

            let oldestDate: Date
            switch period {
            case .day:
                oldestDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            case .week:
                oldestDate = calendar.date(byAdding: .weekOfYear, value: -8, to: now) ?? now
            case .month:
                oldestDate = calendar.date(byAdding: .month, value: -6, to: now) ?? now
            case .sixMonth:
                oldestDate = calendar.date(byAdding: .month, value: -18, to: now) ?? now
            case .year:
                oldestDate = calendar.date(byAdding: .year, value: -3, to: now) ?? now
            }

            // 1. Fetch protein grams from aggregation cache
            let proteinResults: [AggregationResult] = try await supabase
                .from("aggregation_results_cache")
                .select()
                .eq("patient_id", value: userId)
                .eq("agg_metric_id", value: "AGG_PROTEIN_GRAMS")
                .eq("period_type", value: periodType)
                .eq("calculation_type_id", value: "SUM")
                .gte("period_start", value: oldestDate.ISO8601Format())
                .lte("period_start", value: newestDate.ISO8601Format())
                .order("period_start", ascending: true)
                .execute()
                .value

            print("📊 Fetched \(proteinResults.count) protein grams data points")

            // 2. Fetch weight readings from patient_biometric_readings
            // Get all weight readings up to newest date (need historical for carry-forward)
            let weightReadings: [WeightReading] = try await supabase
                .from("patient_biometric_readings")
                .select("value, recorded_at, unit")
                .eq("patient_id", value: userId)
                .eq("biometric_name", value: "Weight")
                .lte("recorded_at", value: newestDate.ISO8601Format())
                .order("recorded_at", ascending: true)
                .execute()
                .value

            print("⚖️ Fetched \(weightReadings.count) weight readings")

            // Determine granularity for date matching
            let granularity: Calendar.Component
            switch period {
            case .day:
                granularity = .hour
            case .week, .month:
                granularity = .day
            case .sixMonth:
                granularity = .weekOfYear
            case .year:
                granularity = .month
            }

            // Generate empty timeline
            var timeline: [ProteinPerBodyWeightData] = []
            var currentDate = oldestDate

            while currentDate <= newestDate {
                let barDate: Date
                if period == .year {
                    var components = calendar.dateComponents([.year, .month], from: currentDate)
                    components.day = 15
                    barDate = calendar.date(from: components) ?? currentDate
                } else {
                    barDate = currentDate
                }

                timeline.append(ProteinPerBodyWeightData(
                    date: barDate,
                    perKg: 0,
                    perLb: 0,
                    grams: nil,
                    kg: nil
                ))

                guard let nextDate = calendar.date(byAdding: period.calendarComponent, value: 1, to: currentDate) else {
                    break
                }
                currentDate = nextDate
            }

            print("📊 Generated \(timeline.count) timeline points for g/kg")

            // 3. Calculate ratio for each protein data point
            for proteinResult in proteinResults {
                let localDate = proteinResult.periodStart.toLocalDateForTimeline()

                if let index = timeline.firstIndex(where: {
                    calendar.isDate($0.date, equalTo: localDate, toGranularity: granularity)
                }) {
                    let proteinGrams = proteinResult.value

                    // Find the most recent weight reading <= this date (carry forward)
                    let weightKg = findWeightForDate(localDate, from: weightReadings)

                    // Calculate ratio if we have both values
                    let perKg: Double
                    if let weight = weightKg, weight > 0 {
                        perKg = proteinGrams / weight
                    } else {
                        perKg = 0
                    }

                    timeline[index] = ProteinPerBodyWeightData(
                        date: timeline[index].date,
                        perKg: perKg,
                        perLb: unitService.gPerKgToGPerLb(perKg),
                        grams: proteinGrams,
                        kg: weightKg
                    )

                    print("📊 Point \(index): protein=\(proteinGrams)g, weight=\(weightKg?.description ?? "nil")kg, ratio=\(perKg) g/kg")
                }
            }

            let dataCount = timeline.filter { $0.perKg > 0 }.count
            print("📈 Overlaid \(dataCount) ratio data points on timeline")

            chartData = timeline

        } catch {
            print("❌ Error loading protein per body weight: \(error)")
        }

        isLoading = false
    }

    /// Find the most recent weight reading <= the given date (carry forward last known weight)
    /// Returns weight in kg for ratio calculation
    private func findWeightForDate(_ date: Date, from readings: [WeightReading]) -> Double? {
        // Readings are sorted ascending by date
        // Find the last reading that is <= the target date
        var lastWeight: Double? = nil

        for reading in readings {
            if reading.recordedAt <= date {
                // Canonical unit for weight is pounds - convert to kg for g/kg calculation
                // Handle both canonical (pound) and any legacy kg data via unit field
                let unit = reading.unit?.lowercased() ?? "pound"
                if unit == "kilogram" || unit == "kg" {
                    // Already in kg
                    lastWeight = reading.value
                } else {
                    // Canonical unit is pounds - convert to kg
                    lastWeight = reading.value * 0.453592
                }
            } else {
                break // Readings after target date - stop
            }
        }

        return lastWeight
    }

    // Calculate average for VISIBLE WINDOW only (matches ParentMetricBarChart pattern)
    func calculateAveragePerKg(for period: TimePeriod, scrollPosition: Date) -> Double {
        guard !chartData.isEmpty else { return 0 }

        // Calculate visible window based on scroll position
        let visibleDuration: TimeInterval
        switch period {
        case .day: visibleDuration = 24 * 3600
        case .week: visibleDuration = 7 * 24 * 3600
        case .month: visibleDuration = 30 * 24 * 3600
        case .sixMonth: visibleDuration = 26 * 7 * 24 * 3600
        case .year: visibleDuration = 365 * 24 * 3600
        }

        let calendar = Calendar.current
        guard let endDate = calendar.date(byAdding: .second, value: Int(visibleDuration), to: scrollPosition) else {
            return 0
        }

        // Filter to visible window
        let visibleData = chartData.filter { $0.date >= scrollPosition && $0.date <= endDate }

        // Filter out zeros
        let actualData = visibleData.filter { $0.perKg > 0 }

        guard !actualData.isEmpty else { return 0 }

        // Return average
        return actualData.reduce(0, { $0 + $1.perKg }) / Double(actualData.count)
    }

    func calculateAveragePerLb(for period: TimePeriod, scrollPosition: Date) -> Double {
        return unitService.gPerKgToGPerLb(calculateAveragePerKg(for: period, scrollPosition: scrollPosition))
    }
}

// MARK: - Data Models

struct ProteinPerBodyWeightData: Identifiable {
    let id = UUID()
    let date: Date
    let perKg: Double
    let perLb: Double
    let grams: Double?  // Raw protein grams used in calculation
    let kg: Double?     // Body weight in kg used in calculation
}

#Preview {
    NavigationStack {
        ProteinDetail()
    }
}
