//
//  BiometricLineChart.swift
//  WellPath
//
//  Line chart for biometric metrics (bodyweight, body fat, etc.)
//  Queries patient_quantity_samples directly instead of aggregation_results_cache
//  Uses sample_quantity_type from display_views to map DISP_* metric IDs
//

import SwiftUI
import Charts

struct BiometricLineChart: View {
    let metric: DisplayMetric
    let color: Color
    var showAbout: Binding<Bool>? = nil

    @State private var selectedPeriod: TimePeriod = .week
    @State private var selectedPointDate: Date?
    @State private var selectedUnit: String = ""
    @State private var actualUnit: String?
    @State private var decimalPlaces: Int = 1
    @StateObject private var scrollManager: BiometricLineChartScrollManager
    @State private var scrollPosition: Date
    @State private var selectedLengthUnit: HeightDisplayUnit2 = .ftIn
    @State private var selectedWeightUnit: WeightDisplayUnit = .lb

    /// Metrics that support length unit toggle (in/cm)
    private var supportsLengthToggle: Bool {
        ["DISP_WAIST_CIRCUMFERENCE", "DISP_HIP_CIRCUMFERENCE"].contains(metric.metricId)
    }

    /// Metrics that support weight unit toggle (lb/kg)
    private var supportsWeightToggle: Bool {
        metric.metricId == "DISP_BODYWEIGHT"
    }

    private var selectedPoint: ChartDataPoint? {
        guard let selectedDate = selectedPointDate else { return nil }
        return scrollManager.chartData.first(where: {
            Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: getDateGranularity())
        })
    }

    /// Get only the data points that have actual values (non-zero)
    private var dataPointsWithValues: [ChartDataPoint] {
        scrollManager.chartData.filter { $0.value > 0 }
    }

    init(metric: DisplayMetric, color: Color, showAbout: Binding<Bool>? = nil) {
        self.metric = metric
        self.color = color
        self.showAbout = showAbout

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

        _scrollManager = StateObject(wrappedValue: BiometricLineChartScrollManager(
            period: initialPeriod,
            metricId: metric.metricId
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Time period picker
            Picker("Period", selection: $selectedPeriod) {
                ForEach(TimePeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 16)
            .onChange(of: selectedPeriod) { oldValue, newPeriod in
                scrollManager.updatePeriod(newPeriod)
                selectedPointDate = nil

                let now = Date()
                let visibleDuration = newPeriod.numberOfBars
                let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
                scrollPosition = Calendar.current.date(
                    byAdding: newPeriod.calendarComponent,
                    value: -offsetFromEnd,
                    to: now
                ) ?? now
            }

            // Unit toggle for length metrics (in/cm) - aligned right
            if supportsLengthToggle {
                HStack {
                    Spacer()
                    Picker("Unit", selection: $selectedLengthUnit) {
                        Text("in").tag(HeightDisplayUnit2.ftIn)
                        Text("cm").tag(HeightDisplayUnit2.cm)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 100)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            // Unit toggle for weight metrics (lb/kg) - aligned right
            if supportsWeightToggle {
                HStack {
                    Spacer()
                    Picker("Unit", selection: $selectedWeightUnit) {
                        Text("lb").tag(WeightDisplayUnit.lb)
                        Text("kg").tag(WeightDisplayUnit.kg)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 100)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            // Value display with optional info button
            HStack(alignment: .top, spacing: 40) {
                VStack(alignment: .leading, spacing: 4) {
                    if let selected = selectedPoint, selected.value > 0 {
                        // Show selected point's value (converted if length metric)
                        // For 6M/Y views, show AVG since points are weekly/monthly averages
                        Text(selectedPeriod == .sixMonth || selectedPeriod == .year ? "AVG" : "VALUE")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatValue(convertValueForDisplay(selected.value)))
                                .font(.system(size: 48, weight: .semibold))
                            if !displayUnit.isEmpty {
                                Text(displayUnit)
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Text(formatSelectedDate(selected.date))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        // Show AVG value when nothing selected
                        Text("AVG")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatValue(convertValueForDisplay(getAverageValue())))
                                .font(.system(size: 48, weight: .semibold))
                            if !displayUnit.isEmpty {
                                Text(displayUnit)
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Text(visibleDateRangeString())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Info button
                if let showAboutBinding = showAbout {
                    Button(action: {
                        withAnimation {
                            showAboutBinding.wrappedValue = true
                        }
                    }) {
                        Image(systemName: "info.circle")
                            .font(.title3)
                            .foregroundColor(color)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 12)
            .onChange(of: scrollManager.actualUnit) { oldValue, newValue in
                if let newUnit = newValue {
                    actualUnit = newUnit
                    if selectedUnit.isEmpty {
                        selectedUnit = newUnit
                    }
                }
            }

            // Line chart - points only where data exists, lines connect adjacent points
            // Only render LineMark when there are 2+ data points to avoid rendering artifacts
            let nonZeroPointCount = dataPointsWithValues.count
            Chart(scrollManager.chartData) { dataPoint in
                // Invisible placeholder for all points to establish x-axis domain
                PointMark(
                    x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
                    y: .value("Value", 0)
                )
                .opacity(0)

                // Only show line/points for non-zero values
                if dataPoint.value > 0 {
                    let displayValue = convertValueForDisplay(dataPoint.value)

                    // Line connecting points (only render when 2+ points exist to avoid vertical bar artifacts)
                    if nonZeroPointCount >= 2 {
                        LineMark(
                            x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
                            y: .value("Value", displayValue)
                        )
                        .foregroundStyle(color)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }

                    // Point marks (always show)
                    if let selectedDate = selectedPointDate,
                       Calendar.current.isDate(dataPoint.date, equalTo: selectedDate, toGranularity: getDateGranularity()) {
                        // Selected point (larger)
                        PointMark(
                            x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
                            y: .value("Value", displayValue)
                        )
                        .foregroundStyle(color)
                        .symbolSize(150)
                    } else {
                        // Regular point (larger when single point for better visibility)
                        PointMark(
                            x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
                            y: .value("Value", displayValue)
                        )
                        .foregroundStyle(color)
                        .symbolSize(nonZeroPointCount == 1 ? 100 : 60)
                    }
                }
            }
            .chartYScale(domain: yAxisDomain)
            .frame(height: 280)
            .chartScrollableAxes(.horizontal)
            .chartScrollPosition(x: $scrollPosition)
            .chartXVisibleDomain(length: getVisibleDomainTimeInterval())
            .chartGesture { proxy in
                SpatialTapGesture()
                    .onEnded { value in
                        if let tappedDate: Date = proxy.value(atX: value.location.x) {
                            let closest = scrollManager.chartData
                                .filter { $0.value > 0 }
                                .min(by: {
                                    abs($0.date.timeIntervalSince(tappedDate)) < abs($1.date.timeIntervalSince(tappedDate))
                                })

                            if let closestDate = closest?.date,
                               Calendar.current.isDate(selectedPointDate ?? Date.distantPast, equalTo: closestDate, toGranularity: getDateGranularity()) {
                                selectedPointDate = nil
                            } else {
                                selectedPointDate = closest?.date
                            }
                        }
                    }
            }
            .onChange(of: scrollPosition) { oldValue, newValue in
                handleChartScrolling(position: newValue)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: getAxisLabelStride(), count: getAxisLabelMultiplier())) { value in
                    if value.as(Date.self) != nil {
                        AxisValueLabel(format: getAxisLabelFormat())
                        AxisGridLine()
                        AxisTick()
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let numValue = value.as(Double.self) {
                            Text(formatAxisValue(numValue))
                        }
                    }
                    AxisGridLine(
                        stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3])
                    )
                    .foregroundStyle(Color.secondary.opacity(0.2))
                }
            }
            .chartPlotStyle { plotArea in
                plotArea.frame(height: 280)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 24)

            // Loading indicators
            HStack {
                if scrollManager.isLoadingOlder {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading older data...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if scrollManager.isLoadingNewer {
                    Text("Loading newer data...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .frame(height: 20)
            .padding(.horizontal)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .task {
            // Load user's preferred units
            await UnitConversionService.shared.loadUserPreferences()
            if supportsLengthToggle {
                selectedLengthUnit = UnitConversionService.shared.preferredHeightUnit
            }
            if supportsWeightToggle {
                selectedWeightUnit = UnitConversionService.shared.preferredWeightUnit
            }
        }
    }

    // MARK: - Computed Properties

    private var displayUnit: String {
        // For length metrics, use the selected toggle unit
        if supportsLengthToggle {
            return selectedLengthUnit == .cm ? "cm" : "in"
        }

        // For weight metrics, use the selected toggle unit
        if supportsWeightToggle {
            return selectedWeightUnit.rawValue
        }

        let unit = (actualUnit ?? selectedUnit).lowercased()
        switch unit {
        case "kilogram", "kg":
            return "kg"
        case "pound", "lb", "lbs":
            return "lb"
        case "percent", "percentage", "%":
            return "%"
        case "centimeter", "cm":
            return "cm"
        case "inch", "in":
            return "in"
        default:
            return selectedUnit
        }
    }

    /// Convert value based on selected unit for length or weight metrics
    /// Checks the actual source unit before converting
    private func convertValueForDisplay(_ value: Double) -> Double {
        let rawUnit = (actualUnit ?? "").lowercased()

        // Handle weight conversion - check source unit first
        if supportsWeightToggle {
            let sourceIsKg = rawUnit.contains("kg") || rawUnit.contains("kilogram")
            let sourceIsLb = rawUnit.contains("lb") || rawUnit.contains("pound")

            switch selectedWeightUnit {
            case .kg:
                if sourceIsKg { return value }
                if sourceIsLb { return value * 0.453592 }  // lb to kg
                return value
            case .lb:
                if sourceIsLb { return value }
                if sourceIsKg { return value * 2.2046 }  // kg to lb
                return value
            }
        }

        // Handle length conversion - check source unit first
        guard supportsLengthToggle else { return value }

        let sourceIsCm = rawUnit.contains("cm") || rawUnit.contains("centimeter")
        let sourceIsIn = rawUnit.contains("in") || rawUnit.contains("inch")

        switch selectedLengthUnit {
        case .cm:
            if sourceIsCm { return value }
            if sourceIsIn { return value * 2.54 }  // in to cm
            return value
        case .ftIn:
            if sourceIsIn { return value }
            if sourceIsCm { return value / 2.54 }  // cm to in
            return value
        }
    }

    private var yAxisDomain: ClosedRange<Double> {
        // Convert values for length metrics when calculating domain
        let values = scrollManager.chartData
            .map { convertValueForDisplay($0.value) }
            .filter { $0 > 0 }
        guard !values.isEmpty else { return 0...100 }

        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 100
        let range = maxVal - minVal
        // Ensure minimum padding to prevent Y-axis from disappearing with single data point
        // Use 10% of range or 5% of value, whichever is larger
        let padding = max(range * 0.1, maxVal * 0.05, 1.0)

        // Add padding to make the chart look better
        let lowerBound = max(0, minVal - padding)
        let upperBound = maxVal + padding

        return lowerBound...upperBound
    }

    // MARK: - Helper Functions

    private func handleChartScrolling(position: Date) {
        guard !scrollManager.chartData.isEmpty else { return }

        let calendar = Calendar.current
        let component = selectedPeriod.calendarComponent

        if let oldestDate = scrollManager.chartData.last?.date {
            let diff = calendar.dateComponents([component], from: oldestDate, to: position)
            let units = abs(diff.value(for: component) ?? 0)

            if units < 5 && !scrollManager.isLoadingOlder {
                scrollManager.loadOlderData()
            }
        }

        if let newestDate = scrollManager.chartData.first?.date {
            let diff = calendar.dateComponents([component], from: position, to: newestDate)
            let units = abs(diff.value(for: component) ?? 0)

            if units < 5 && !scrollManager.isLoadingNewer {
                scrollManager.loadNewerData()
            }
        }
    }

    /// Get the average value across the visible range
    private func getAverageValue() -> Double {
        let visibleData = getVisibleDataPoints()
        let values = visibleData.compactMap { $0.value > 0 ? $0.value : nil }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func getVisibleDataPoints() -> [ChartDataPoint] {
        let calendar = Calendar.current
        let visibleDuration = selectedPeriod.numberOfBars
        let endDate = calendar.date(byAdding: selectedPeriod.calendarComponent, value: visibleDuration, to: scrollPosition) ?? scrollPosition

        return scrollManager.chartData.filter { dataPoint in
            dataPoint.date >= scrollPosition && dataPoint.date <= endDate
        }
    }

    private func visibleDateRangeString() -> String {
        let calendar = Calendar.current
        let visibleDuration = selectedPeriod.numberOfBars
        let endDate = calendar.date(byAdding: selectedPeriod.calendarComponent, value: visibleDuration - 1, to: scrollPosition) ?? scrollPosition

        let formatter = DateFormatter()
        formatter.dateFormat = selectedPeriod == .year ? "MMM yyyy" : "MMM d"

        return "\(formatter.string(from: scrollPosition)) - \(formatter.string(from: endDate))"
    }

    private func formatValue(_ value: Double) -> String {
        if decimalPlaces == 0 || value >= 100 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.\(decimalPlaces)f", value)
        }
    }

    private func formatAxisValue(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    /// Format date for selected point display
    /// - D view: includes time (e.g., "Dec 3, 1:00 PM")
    /// - W/M view: specific date (e.g., "Tue, Dec 3")
    /// - 6M view: week range (e.g., "Dec 1 - Dec 7, 2025")
    /// - Y view: month name (e.g., "December, 2025")
    private func formatSelectedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()

        switch selectedPeriod {
        case .day:
            formatter.dateFormat = "MMM d, h:mm a"  // Include time for day view
            return formatter.string(from: date)
        case .week:
            formatter.dateFormat = "E, MMM d"  // Day of week + date
            return formatter.string(from: date)
        case .month:
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        case .sixMonth:
            // Show week range (Mon-Sun)
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
                formatter.dateFormat = "MMM d, yyyy"
                return formatter.string(from: date)
            }
            let startFormatter = DateFormatter()
            startFormatter.dateFormat = "MMM d"
            let endFormatter = DateFormatter()
            endFormatter.dateFormat = "MMM d, yyyy"
            // End date is exclusive, so subtract one day to get the actual last day of the week
            let lastDay = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.end
            return "\(startFormatter.string(from: weekInterval.start)) - \(endFormatter.string(from: lastDay))"
        case .year:
            // Show month name and year
            formatter.dateFormat = "MMMM, yyyy"
            return formatter.string(from: date)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch selectedPeriod {
        case .day:
            formatter.dateFormat = "MMM d, yyyy"
        case .week:
            formatter.dateFormat = "MMM d"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
        case .sixMonth, .year:
            formatter.dateFormat = "MMM yyyy"
        }
        return formatter.string(from: date)
    }

    /// Get the calendar granularity for date matching based on period
    private func getDateGranularity() -> Calendar.Component {
        switch selectedPeriod {
        case .day:
            return .hour
        case .week, .month:
            return .day
        case .sixMonth:
            return .weekOfYear
        case .year:
            return .month
        }
    }

    private func getVisibleDomainTimeInterval() -> TimeInterval {
        switch selectedPeriod {
        case .day:
            return 24 * 3600  // 24 hours in seconds
        case .week:
            return 7 * 24 * 3600  // 7 days in seconds
        case .month:
            return 30 * 24 * 3600  // 30 days in seconds
        case .sixMonth:
            return 26 * 7 * 24 * 3600  // 26 weeks in seconds
        case .year:
            return 365 * 24 * 3600  // 1 year in seconds
        }
    }

    // MARK: - X-Axis Configuration (matches ParentMetricBarChart)

    private func getAxisLabelStride() -> Calendar.Component {
        switch selectedPeriod {
        case .day:
            return .hour
        case .week:
            return .day
        case .month:
            return .weekOfYear  // Weekly labels for month view
        case .sixMonth:
            return .month  // Monthly labels for 6-month view
        case .year:
            return .month
        }
    }

    private func getAxisLabelMultiplier() -> Int {
        switch selectedPeriod {
        case .day:
            return 6  // Every 6 hours (12 AM, 6 AM, 12 PM, 6 PM)
        case .week:
            return 1  // Every day
        case .month:
            return 1  // Every week
        case .sixMonth:
            return 1  // Every month
        case .year:
            return 1  // Every month
        }
    }

    private func getAxisLabelFormat() -> Date.FormatStyle {
        switch selectedPeriod {
        case .day:
            return .dateTime.hour(.defaultDigits(amPM: .abbreviated))
        case .week:
            return .dateTime.weekday(.narrow)
        case .month:
            return .dateTime.day(.defaultDigits)  // Just day number (12, 19, etc.)
        case .sixMonth:
            return .dateTime.month(.abbreviated)
        case .year:
            return .dateTime.month(.narrow)  // Single letter (J, F, M, A, M, J, J, A, S, O, N, D)
        }
    }
}

// MARK: - Biometric Line Chart Scroll Manager

@MainActor
class BiometricLineChartScrollManager: ObservableObject {
    @Published var chartData: [ChartDataPoint] = []
    @Published var isLoadingOlder = false
    @Published var isLoadingNewer = false
    @Published var actualUnit: String?

    private var oldestDate: Date
    private var newestDate: Date
    private var selectedPeriod: TimePeriod
    private let metricId: String
    private let supabase = SupabaseManager.shared.client

    init(period: TimePeriod, metricId: String) {
        self.selectedPeriod = period
        self.metricId = metricId

        let now = Date()
        self.newestDate = Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now

        switch period {
        case .day:
            self.oldestDate = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        case .week:
            self.oldestDate = Calendar.current.date(byAdding: .weekOfYear, value: -12, to: now) ?? now
        case .month:
            self.oldestDate = Calendar.current.date(byAdding: .month, value: -12, to: now) ?? now
        case .sixMonth:
            self.oldestDate = Calendar.current.date(byAdding: .month, value: -24, to: now) ?? now
        case .year:
            self.oldestDate = Calendar.current.date(byAdding: .year, value: -5, to: now) ?? now
        }

        Task {
            await loadInitialData()
        }
    }

    func updatePeriod(_ period: TimePeriod) {
        self.selectedPeriod = period

        let now = Date()
        self.newestDate = Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now

        switch period {
        case .day:
            self.oldestDate = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        case .week:
            self.oldestDate = Calendar.current.date(byAdding: .weekOfYear, value: -12, to: now) ?? now
        case .month:
            self.oldestDate = Calendar.current.date(byAdding: .month, value: -12, to: now) ?? now
        case .sixMonth:
            self.oldestDate = Calendar.current.date(byAdding: .month, value: -24, to: now) ?? now
        case .year:
            self.oldestDate = Calendar.current.date(byAdding: .year, value: -5, to: now) ?? now
        }

        chartData.removeAll()
        Task {
            await loadInitialData()
        }
    }

    func loadOlderData() {
        guard !isLoadingOlder else { return }
        isLoadingOlder = true

        Task {
            let calendar = Calendar.current
            let component = selectedPeriod.calendarComponent
            let loadAmount = -selectedPeriod.loadChunkSize

            let tenYearsAgo = calendar.date(byAdding: .year, value: -10, to: Date()) ?? Date()
            guard oldestDate > tenYearsAgo else {
                isLoadingOlder = false
                return
            }

            let newOldestDate = calendar.date(byAdding: component, value: loadAmount, to: oldestDate) ?? oldestDate
            let cappedOldestDate = max(newOldestDate, tenYearsAgo)

            await loadDataRange(from: cappedOldestDate, to: oldestDate)
            oldestDate = cappedOldestDate
            isLoadingOlder = false
        }
    }

    func loadNewerData() {
        guard !isLoadingNewer else { return }
        isLoadingNewer = true

        Task {
            let calendar = Calendar.current
            let component = selectedPeriod.calendarComponent
            let loadAmount = selectedPeriod.loadChunkSize

            let newNewestDate = calendar.date(byAdding: component, value: loadAmount, to: newestDate) ?? newestDate

            await loadDataRange(from: newestDate, to: newNewestDate)
            newestDate = newNewestDate
            isLoadingNewer = false
        }
    }

    private func loadInitialData() async {
        await loadDataRange(from: oldestDate, to: newestDate)
    }

    private func loadDataRange(from startDate: Date, to endDate: Date) async {
        // Generate empty timeline
        var timeline = generateEmptyTimeline(from: startDate, to: endDate)

        // Fetch data from patient_samples
        let dataPoints = await fetchDataPoints(from: startDate, to: endDate)

        // Overlay actual data on timeline
        for dataPoint in dataPoints {
            if let index = timeline.firstIndex(where: {
                Calendar.current.isDate($0.date, equalTo: dataPoint.date, toGranularity: selectedPeriod.calendarComponent)
            }) {
                timeline[index] = dataPoint
            }
        }

        // Merge with existing data
        await MainActor.run {
            let existingDates = Set(chartData.map { $0.date })
            let newPoints = timeline.filter { !existingDates.contains($0.date) }
            chartData.append(contentsOf: newPoints)
            chartData.sort { $0.date > $1.date }
        }
    }

    private func generateEmptyTimeline(from startDate: Date, to endDate: Date) -> [ChartDataPoint] {
        var timeline: [ChartDataPoint] = []
        var currentDate = startDate
        let calendar = Calendar.current
        let component = selectedPeriod.calendarComponent

        while currentDate <= endDate {
            timeline.append(ChartDataPoint(date: currentDate, value: 0, label: ""))
            currentDate = calendar.date(byAdding: component, value: 1, to: currentDate) ?? endDate
        }

        return timeline
    }

    private func fetchDataPoints(from startDate: Date, to endDate: Date) async -> [ChartDataPoint] {
        do {
            let patientId = try await supabase.auth.session.user.id

            // Look up quantity_type from display_views.sample_quantity_type
            guard let quantityType = await BiometricQuantityTypeService.shared.quantityType(for: metricId) else {
                print("⚠️ No sample_quantity_type mapping for \(metricId)")
                return []
            }

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            struct SampleResult: Codable {
                let quantityValue: Double
                let quantityUnit: String?
                let startTime: Date

                enum CodingKeys: String, CodingKey {
                    case quantityValue = "quantity_value"
                    case quantityUnit = "quantity_unit"
                    case startTime = "start_time"
                }
            }

            // Query patient_quantity_samples directly
            let results: [SampleResult] = try await supabase
                .from("patient_quantity_samples")
                .select("quantity_value, quantity_unit, start_time")
                .eq("patient_id", value: patientId)
                .eq("quantity_type", value: quantityType)
                .gte("start_time", value: formatter.string(from: startDate))
                .lte("start_time", value: formatter.string(from: endDate))
                .order("start_time", ascending: false)
                .execute()
                .value

            // Update the actual unit from the first result
            if let firstResult = results.first, let unit = firstResult.quantityUnit {
                await MainActor.run {
                    self.actualUnit = unit
                }
            }

            print("📊 BiometricLineChart: Fetched \(results.count) samples for \(quantityType)")

            // Aggregate by period: D=hourly, W/M=daily, 6M=weekly, Y=monthly
            let calendar = Calendar.current
            let aggregationGranularity: Calendar.Component = {
                switch selectedPeriod {
                case .day:
                    return .hour
                case .week, .month:
                    return .day
                case .sixMonth:
                    return .weekOfYear
                case .year:
                    return .month
                }
            }()

            // Group readings by period bucket and collect values for averaging
            var bucketData: [Date: [Double]] = [:]

            for result in results {
                // Get the start of the period bucket for this reading
                let bucketStart: Date
                switch aggregationGranularity {
                case .hour:
                    bucketStart = calendar.dateInterval(of: .hour, for: result.startTime)?.start ?? result.startTime
                case .day:
                    bucketStart = calendar.startOfDay(for: result.startTime)
                case .weekOfYear:
                    bucketStart = calendar.dateInterval(of: .weekOfYear, for: result.startTime)?.start ?? result.startTime
                case .month:
                    bucketStart = calendar.dateInterval(of: .month, for: result.startTime)?.start ?? result.startTime
                default:
                    bucketStart = result.startTime
                }

                bucketData[bucketStart, default: []].append(result.quantityValue)
            }

            // Calculate averages for each bucket
            var aggregatedPoints: [ChartDataPoint] = []
            for (bucketStart, values) in bucketData {
                let avgValue = values.reduce(0, +) / Double(values.count)
                aggregatedPoints.append(ChartDataPoint(date: bucketStart, value: avgValue, label: ""))
            }

            print("📊 BiometricLineChart: Aggregated to \(aggregatedPoints.count) points for period \(selectedPeriod.rawValue)")

            return aggregatedPoints.sorted { $0.date > $1.date }

        } catch {
            print("❌ Error fetching biometric line chart data: \(error)")
            return []
        }
    }
}

#Preview {
    let mockMetric = DisplayMetric(
        id: "preview-id",
        metricId: "DISP_BODYWEIGHT",
        metricName: "Weight",
        description: "Body weight tracking",
        pillar: "Core Care",
        chartTypeId: "trend_line",
        isActive: true,
        aboutContent: nil,
        longevityImpact: nil,
        quickTips: nil
    )

    BiometricLineChart(metric: mockMetric, color: .cyan)
}
