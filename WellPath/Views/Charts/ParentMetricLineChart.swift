//
//  ParentMetricLineChart.swift
//  WellPath
//
//  Reusable line chart component for biometric metrics like bodyweight, body fat, HRV, etc.
//  X-axis behavior matches ParentMetricBarChart: D=24h, W=7d, M=30d, 6M=26w, Y=12m
//

import SwiftUI
import Charts

struct ParentMetricLineChart: View {
    let metric: DisplayMetric
    let color: Color
    var showAbout: Binding<Bool>? = nil

    @State private var selectedPeriod: TimePeriod = .week
    @State private var selectedPointDate: Date?
    @State private var selectedUnit: String
    @State private var actualUnit: String?
    @State private var decimalPlaces: Int = 1
    @StateObject private var scrollManager: LineChartScrollManager
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

        _selectedUnit = State(initialValue: "")

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

        _scrollManager = StateObject(wrappedValue: LineChartScrollManager(
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
                        Text("VALUE")
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
                        // Show LATEST value when nothing selected (biometrics are point-in-time)
                        Text("LATEST")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatValue(convertValueForDisplay(getLatestValue())))
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

                    // Line connecting points (smooth interpolation)
                    LineMark(
                        x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
                        y: .value("Value", displayValue)
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    // Point marks
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
                        // Regular point
                        PointMark(
                            x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
                            y: .value("Value", displayValue)
                        )
                        .foregroundStyle(color)
                        .symbolSize(60)
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
    private func convertValueForDisplay(_ value: Double) -> Double {
        // Handle weight conversion (data stored in canonical kg)
        if supportsWeightToggle {
            switch selectedWeightUnit {
            case .kg:
                return value  // Already in kg
            case .lb:
                return value * 2.2046  // Convert kg to lb
            }
        }

        // Handle length conversion
        guard supportsLengthToggle else { return value }

        // Data is stored in cm, convert if needed
        let rawUnit = (actualUnit ?? "cm").lowercased()
        let isSourceCm = rawUnit.contains("cm") || rawUnit.contains("centimeter")

        switch selectedLengthUnit {
        case .cm:
            // If source is cm, return as-is; if source is inches, convert to cm
            return isSourceCm ? value : value * 2.54
        case .ftIn:
            // If source is cm, convert to inches; if source is inches, return as-is
            return isSourceCm ? value / 2.54 : value
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
        let padding = (maxVal - minVal) * 0.1

        // Add some padding to make the chart look better
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

    /// Get the latest (most recent) value in the visible range
    private func getLatestValue() -> Double {
        let visibleData = getVisibleDataPoints()
        // Sort by date descending and get the first non-zero value
        let latestPoint = visibleData
            .filter { $0.value > 0 }
            .sorted { $0.date > $1.date }
            .first
        return latestPoint?.value ?? 0
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

    /// Format date for selected point display (includes time for D view)
    private func formatSelectedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch selectedPeriod {
        case .day:
            formatter.dateFormat = "MMM d, h:mm a"  // Include time for day view
        case .week:
            formatter.dateFormat = "E, MMM d"  // Day of week + date
        case .month:
            formatter.dateFormat = "MMM d, yyyy"
        case .sixMonth, .year:
            formatter.dateFormat = "MMM d, yyyy"
        }
        return formatter.string(from: date)
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

// MARK: - Line Chart Scroll Manager

@MainActor
class LineChartScrollManager: ObservableObject {
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

        // Fetch data from patient_quantity_samples
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
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            // Check if this is a biometric metric that should query patient_samples directly
            if let quantityType = await BiometricQuantityTypeService.shared.quantityType(for: metricId) {
                return await fetchBiometricDataPoints(
                    patientId: patientId,
                    quantityType: quantityType,
                    from: startDate,
                    to: endDate,
                    formatter: formatter
                )
            }

            // Query patient_quantity_samples via the sample_quantity_type from display_views_dependencies
            let sampleType = await lookupSampleType()
            guard let quantityType = sampleType else {
                print("⚠️ No sample_quantity_type found for \(metricId)")
                return []
            }

            struct SampleReading: Codable {
                let quantityValue: Double
                let quantityUnit: String?
                let startTime: Date

                enum CodingKeys: String, CodingKey {
                    case quantityValue = "quantity_value"
                    case quantityUnit = "quantity_unit"
                    case startTime = "start_time"
                }
            }

            let results: [SampleReading] = try await supabase
                .from("patient_quantity_samples")
                .select("quantity_value, quantity_unit, start_time")
                .eq("patient_id", value: patientId)
                .eq("quantity_type", value: quantityType)
                .eq("is_primary", value: true)  // Only use primary samples for analysis
                .gte("start_time", value: formatter.string(from: startDate))
                .lte("start_time", value: formatter.string(from: endDate))
                .order("start_time", ascending: false)
                .execute()
                .value

            // Set the unit from the first result
            if let first = results.first, let unit = first.quantityUnit {
                await MainActor.run {
                    self.actualUnit = unit
                }
            }

            return results.map { ChartDataPoint(date: $0.startTime, value: $0.quantityValue, label: "") }

        } catch {
            print("❌ Error fetching line chart data: \(error)")
            return []
        }
    }

    /// Fetch biometric data directly from patient_samples table
    private func fetchBiometricDataPoints(
        patientId: UUID,
        quantityType: String,
        from startDate: Date,
        to endDate: Date,
        formatter: ISO8601DateFormatter
    ) async -> [ChartDataPoint] {
        do {
            struct SampleReading: Codable {
                let quantityValue: Double
                let quantityUnit: String?
                let startTime: Date

                enum CodingKeys: String, CodingKey {
                    case quantityValue = "quantity_value"
                    case quantityUnit = "quantity_unit"
                    case startTime = "start_time"
                }
            }

            let results: [SampleReading] = try await supabase
                .from("patient_quantity_samples")
                .select("quantity_value, quantity_unit, start_time")
                .eq("patient_id", value: patientId)
                .eq("quantity_type", value: quantityType)
                .eq("is_primary", value: true)  // Only use primary samples for analysis
                .gte("start_time", value: formatter.string(from: startDate))
                .lte("start_time", value: formatter.string(from: endDate))
                .order("start_time", ascending: false)
                .execute()
                .value

            // Set the unit from the first result
            if let first = results.first, let unit = first.quantityUnit {
                await MainActor.run {
                    self.actualUnit = BiometricValueLoader.formatUnitForDisplay(unit)
                }
            }

            return results.map { ChartDataPoint(date: $0.startTime, value: $0.quantityValue, label: "") }

        } catch {
            print("❌ Error fetching biometric data from patient_samples: \(error)")
            return []
        }
    }

    private func lookupSampleType() async -> String? {
        do {
            struct SampleTypeLookup: Codable {
                let sampleQuantityType: String?

                enum CodingKeys: String, CodingKey {
                    case sampleQuantityType = "sample_quantity_type"
                }
            }

            let results: [SampleTypeLookup] = try await supabase
                .from("display_views_dependencies")
                .select("sample_quantity_type")
                .eq("view_id", value: metricId)
                .eq("is_primary", value: true)
                .limit(1)
                .execute()
                .value

            return results.first?.sampleQuantityType

        } catch {
            print("❌ Error looking up sample type: \(error)")
            return nil
        }
    }

}

// Note: dateGranularity is implemented as getDateGranularity() within ParentMetricLineChart
// to match ParentMetricBarChart behavior

#Preview {
    let mockMetric = DisplayMetric(
        id: "preview-id",
        metricId: "DISP_WEIGHT",
        metricName: "Weight",
        description: "Body weight tracking",
        pillar: "Core Care",
        chartTypeId: "trend_line",
        isActive: true,
        aboutContent: nil,
        longevityImpact: nil,
        quickTips: nil
    )

    ParentMetricLineChart(metric: mockMetric, color: .cyan)
}
