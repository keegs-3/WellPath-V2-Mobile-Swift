//
//  BodyMeasurementsRangeChart.swift
//  WellPath
//
//  Dual line chart showing waist and hip circumference over time
//  Synchronized with WaistHipRatioChart via shared scroll position
//

import SwiftUI
import Charts
import Supabase

struct BodyMeasurementsRangeChart: View {
    let color: Color
    @Binding var selectedUnit: HeightDisplayUnit2
    @Binding var scrollPosition: Date
    @Binding var selectedPeriod: TimePeriod
    @Binding var selectedPointDate: Date?  // Shared with ratio chart
    @ObservedObject var scrollManager: MeasurementsChartScrollManager

    private var selectedPoint: MeasurementDataPoint? {
        guard let selectedDate = selectedPointDate else { return nil }
        return scrollManager.chartData.first(where: {
            Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: getDateGranularity())
        })
    }

    private func convertValue(_ cm: Double) -> Double {
        switch selectedUnit {
        case .cm: return cm
        case .ftIn: return cm / 2.54
        }
    }

    private var displayUnitString: String {
        selectedUnit == .cm ? "cm" : "in"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Measurements")
                    .font(.headline)
                Spacer()
                // Unit toggle - aligned right
                Picker("Unit", selection: $selectedUnit) {
                    Text("in").tag(HeightDisplayUnit2.ftIn)
                    Text("cm").tag(HeightDisplayUnit2.cm)
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
            }
            .padding(.horizontal)
            .padding(.top, 12)

            // Value display - shows all 3 values (waist, hip, ratio)
            HStack(alignment: .top, spacing: 16) {
                if let selected = selectedPoint, selected.waist > 0 && selected.hip > 0 {
                    let ratio = selected.waist / selected.hip

                    VStack(alignment: .leading, spacing: 4) {
                        Text("WAIST")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.1f", convertValue(selected.waist)))
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(displayUnitString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("HIP")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.1f", convertValue(selected.hip)))
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(displayUnitString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("RATIO")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.2f", ratio))
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text(formatSelectedDate(selected.date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if let latest = getLatestReading(), latest.waist > 0 && latest.hip > 0 {
                    let ratio = latest.waist / latest.hip

                    VStack(alignment: .leading, spacing: 4) {
                        Text("LATEST")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 12) {
                            VStack(alignment: .leading) {
                                Text("Waist")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                HStack(alignment: .firstTextBaseline, spacing: 1) {
                                    Text(String(format: "%.1f", convertValue(latest.waist)))
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Text(displayUnitString)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            VStack(alignment: .leading) {
                                Text("Hip")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                HStack(alignment: .firstTextBaseline, spacing: 1) {
                                    Text(String(format: "%.1f", convertValue(latest.hip)))
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Text(displayUnitString)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            VStack(alignment: .leading) {
                                Text("Ratio")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f", ratio))
                                    .font(.title3)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    Spacer()
                } else {
                    Text("No data")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 8)

            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text("Waist")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(color.opacity(0.5))
                        .frame(width: 8, height: 8)
                    Text("Hip")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Chart
            Chart(scrollManager.chartData) { dataPoint in
                // Invisible placeholder
                PointMark(
                    x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
                    y: .value("Value", 0)
                )
                .opacity(0)

                if dataPoint.waist > 0 && dataPoint.hip > 0 {
                    let waistDisplay = convertValue(dataPoint.waist)
                    let hipDisplay = convertValue(dataPoint.hip)

                    // Waist line
                    LineMark(
                        x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
                        y: .value("Waist", waistDisplay)
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    // Hip line
                    LineMark(
                        x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
                        y: .value("Hip", hipDisplay)
                    )
                    .foregroundStyle(color.opacity(0.5))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    // Points
                    if let selectedDate = selectedPointDate,
                       Calendar.current.isDate(dataPoint.date, equalTo: selectedDate, toGranularity: getDateGranularity()) {
                        PointMark(
                            x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
                            y: .value("Waist", waistDisplay)
                        )
                        .foregroundStyle(color)
                        .symbolSize(100)

                        PointMark(
                            x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
                            y: .value("Hip", hipDisplay)
                        )
                        .foregroundStyle(color.opacity(0.5))
                        .symbolSize(100)
                    } else {
                        PointMark(
                            x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
                            y: .value("Waist", waistDisplay)
                        )
                        .foregroundStyle(color)
                        .symbolSize(40)

                        PointMark(
                            x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
                            y: .value("Hip", hipDisplay)
                        )
                        .foregroundStyle(color.opacity(0.5))
                        .symbolSize(40)
                    }
                }
            }
            .chartYScale(domain: yAxisDomain)
            .frame(height: 200)
            .chartScrollableAxes(.horizontal)
            .chartScrollPosition(x: $scrollPosition)
            .chartXVisibleDomain(length: getVisibleDomainTimeInterval())
            .chartGesture { proxy in
                SpatialTapGesture()
                    .onEnded { value in
                        if let tappedDate: Date = proxy.value(atX: value.location.x) {
                            let closest = scrollManager.chartData
                                .filter { $0.waist > 0 && $0.hip > 0 }
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
                            Text(String(format: "%.0f", numValue))
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(Color.secondary.opacity(0.2))
                }
            }
            .chartPlotStyle { plotArea in
                plotArea.frame(height: 200)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)

            // Loading indicators
            HStack {
                if scrollManager.isLoadingOlder {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .frame(height: 16)
            .padding(.horizontal)
        }
    }

    // MARK: - Computed Properties

    private var yAxisDomain: ClosedRange<Double> {
        let values = scrollManager.chartData
            .flatMap { [convertValue($0.waist), convertValue($0.hip)] }
            .filter { $0 > 0 }

        guard !values.isEmpty else {
            return selectedUnit == .cm ? 50...120 : 20...50
        }

        let minVal = values.min() ?? 50
        let maxVal = values.max() ?? 120
        let padding = (maxVal - minVal) * 0.15

        return max(0, minVal - padding)...(maxVal + padding)
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
    }

    private func getLatestReading() -> MeasurementDataPoint? {
        scrollManager.chartData
            .filter { $0.waist > 0 && $0.hip > 0 }
            .sorted { $0.date > $1.date }
            .first
    }

    private func formatSelectedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch selectedPeriod {
        case .day:
            formatter.dateFormat = "MMM d, h:mm a"
        case .week:
            formatter.dateFormat = "E, MMM d"
        case .month, .sixMonth, .year:
            formatter.dateFormat = "MMM d, yyyy"
        }
        return formatter.string(from: date)
    }

    private func getDateGranularity() -> Calendar.Component {
        switch selectedPeriod {
        case .day: return .hour
        case .week, .month: return .day
        case .sixMonth: return .weekOfYear
        case .year: return .month
        }
    }

    private func getVisibleDomainTimeInterval() -> TimeInterval {
        switch selectedPeriod {
        case .day: return 24 * 3600
        case .week: return 7 * 24 * 3600
        case .month: return 30 * 24 * 3600
        case .sixMonth: return 26 * 7 * 24 * 3600
        case .year: return 365 * 24 * 3600
        }
    }

    private func getAxisLabelStride() -> Calendar.Component {
        switch selectedPeriod {
        case .day: return .hour
        case .week: return .day
        case .month: return .weekOfYear
        case .sixMonth, .year: return .month
        }
    }

    private func getAxisLabelMultiplier() -> Int {
        switch selectedPeriod {
        case .day: return 6
        default: return 1
        }
    }

    private func getAxisLabelFormat() -> Date.FormatStyle {
        switch selectedPeriod {
        case .day: return .dateTime.hour(.defaultDigits(amPM: .abbreviated))
        case .week: return .dateTime.weekday(.narrow)
        case .month: return .dateTime.day(.defaultDigits)
        case .sixMonth: return .dateTime.month(.abbreviated)
        case .year: return .dateTime.month(.narrow)
        }
    }
}

// MARK: - Measurement Data Point

struct MeasurementDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let waist: Double
    let hip: Double
    let waistIsDerived: Bool  // True if waist value was carried forward from previous reading
    let hipIsDerived: Bool    // True if hip value was carried forward from previous reading

    /// True if the ratio uses at least one derived (carried forward) value
    var isDerivedRatio: Bool {
        waistIsDerived || hipIsDerived
    }

    /// True if this point has at least one actual measurement (not just carried forward values)
    var hasActualMeasurement: Bool {
        !waistIsDerived || !hipIsDerived
    }

    init(date: Date, waist: Double, hip: Double, waistIsDerived: Bool = false, hipIsDerived: Bool = false) {
        self.date = date
        self.waist = waist
        self.hip = hip
        self.waistIsDerived = waistIsDerived
        self.hipIsDerived = hipIsDerived
    }
}

// MARK: - Measurements Chart Scroll Manager

@MainActor
class MeasurementsChartScrollManager: ObservableObject {
    @Published var chartData: [MeasurementDataPoint] = []
    @Published var isLoading = true  // Initial load state
    @Published var isLoadingOlder = false
    @Published var isLoadingNewer = false
    @Published var optimalScrollPosition: Date?  // Calculated based on actual data

    // Chart display range (stable, doesn't change during scroll)
    private var chartOldestDate: Date
    private var chartNewestDate: Date
    // Data loading boundary (tracks how far back we've loaded)
    private var loadedOldestDate: Date
    private var selectedPeriod: TimePeriod

    /// The date range for the chart's X axis - remains stable to prevent jumping
    var chartDateRange: ClosedRange<Date> {
        chartOldestDate...chartNewestDate
    }
    private let supabase = SupabaseManager.shared.client

    init(period: TimePeriod) {
        self.selectedPeriod = period

        let now = Date()
        // Set chart display range (stable) and initial load boundary
        switch period {
        case .day:
            self.chartNewestDate = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
            self.chartOldestDate = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        case .week:
            self.chartNewestDate = Calendar.current.date(byAdding: .weekOfYear, value: 2, to: now) ?? now
            self.chartOldestDate = Calendar.current.date(byAdding: .weekOfYear, value: -12, to: now) ?? now
        case .month:
            self.chartNewestDate = Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now
            self.chartOldestDate = Calendar.current.date(byAdding: .month, value: -12, to: now) ?? now
        case .sixMonth:
            self.chartNewestDate = Calendar.current.date(byAdding: .month, value: 2, to: now) ?? now
            self.chartOldestDate = Calendar.current.date(byAdding: .month, value: -24, to: now) ?? now
        case .year:
            self.chartNewestDate = Calendar.current.date(byAdding: .month, value: 3, to: now) ?? now
            self.chartOldestDate = Calendar.current.date(byAdding: .year, value: -5, to: now) ?? now
        }
        // Data loading boundary starts at chart oldest - can extend further back on scroll
        self.loadedOldestDate = chartOldestDate

        Task { await loadInitialData() }
    }

    func updatePeriod(_ period: TimePeriod) {
        self.selectedPeriod = period

        let now = Date()
        // Reset chart display range (stable) for new period
        switch period {
        case .day:
            self.chartNewestDate = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
            self.chartOldestDate = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        case .week:
            self.chartNewestDate = Calendar.current.date(byAdding: .weekOfYear, value: 2, to: now) ?? now
            self.chartOldestDate = Calendar.current.date(byAdding: .weekOfYear, value: -12, to: now) ?? now
        case .month:
            self.chartNewestDate = Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now
            self.chartOldestDate = Calendar.current.date(byAdding: .month, value: -12, to: now) ?? now
        case .sixMonth:
            self.chartNewestDate = Calendar.current.date(byAdding: .month, value: 2, to: now) ?? now
            self.chartOldestDate = Calendar.current.date(byAdding: .month, value: -24, to: now) ?? now
        case .year:
            self.chartNewestDate = Calendar.current.date(byAdding: .month, value: 3, to: now) ?? now
            self.chartOldestDate = Calendar.current.date(byAdding: .year, value: -5, to: now) ?? now
        }
        // Reset data loading boundary to match chart range
        self.loadedOldestDate = chartOldestDate

        isLoading = true
        chartData.removeAll()
        optimalScrollPosition = nil
        Task { await loadInitialData() }
    }

    /// Refreshes all chart data - call when data may have changed (e.g., after deletion)
    func refresh() {
        Task {
            chartData.removeAll()
            optimalScrollPosition = nil
            await loadInitialData()
        }
    }

    /// Calculate optimal scroll position so the most recent data is visible at ~70% from left
    private func calculateOptimalScrollPosition() {
        // Find the most recent data point with actual values
        let dataWithValues = chartData.filter { $0.waist > 0 && $0.hip > 0 }
        guard let mostRecentDataPoint = dataWithValues.sorted(by: { $0.date > $1.date }).first else {
            // No data with values - use default position relative to now
            let now = Date()
            let visibleDuration = selectedPeriod.numberOfBars
            let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
            optimalScrollPosition = Calendar.current.date(
                byAdding: selectedPeriod.calendarComponent,
                value: -offsetFromEnd,
                to: now
            ) ?? now
            return
        }

        let calendar = Calendar.current
        let visibleDuration = selectedPeriod.numberOfBars

        // Position so most recent data is at ~70% from left edge (30% from right)
        // This shows the data clearly while leaving room for potential future entries
        let offsetFromData = Int(Double(visibleDuration) * 0.7)
        optimalScrollPosition = calendar.date(
            byAdding: selectedPeriod.calendarComponent,
            value: -offsetFromData,
            to: mostRecentDataPoint.date
        ) ?? mostRecentDataPoint.date

        print("📊 Calculated optimal scroll: mostRecentData=\(mostRecentDataPoint.date), scrollPosition=\(optimalScrollPosition!)")
    }

    func loadOlderData() {
        guard !isLoadingOlder else { return }
        isLoadingOlder = true

        Task {
            let calendar = Calendar.current
            let loadAmount = -selectedPeriod.loadChunkSize

            let tenYearsAgo = calendar.date(byAdding: .year, value: -10, to: Date()) ?? Date()
            guard loadedOldestDate > tenYearsAgo else {
                isLoadingOlder = false
                return
            }

            let newOldestDate = calendar.date(byAdding: selectedPeriod.calendarComponent, value: loadAmount, to: loadedOldestDate) ?? loadedOldestDate
            let cappedOldestDate = max(newOldestDate, tenYearsAgo)

            await loadDataRange(from: cappedOldestDate, to: loadedOldestDate)
            // Only update the data loading boundary, NOT the chart display range
            // This is the key fix - chartDateRange stays stable during scroll
            loadedOldestDate = cappedOldestDate
            isLoadingOlder = false
        }
    }

    private func loadInitialData() async {
        await loadDataRange(from: chartOldestDate, to: chartNewestDate)
        calculateOptimalScrollPosition()
        isLoading = false
    }

    private func loadDataRange(from startDate: Date, to endDate: Date) async {
        let dataPoints = await fetchDataPoints(from: startDate, to: endDate)

        await MainActor.run {
            // Use exact timestamp matching to avoid duplicates
            let existingTimestamps = Set(chartData.map { $0.date })
            let newPoints = dataPoints.filter { !existingTimestamps.contains($0.date) }
            chartData.append(contentsOf: newPoints)
            chartData.sort { $0.date > $1.date }
        }
    }

    private func fetchDataPoints(from startDate: Date, to endDate: Date) async -> [MeasurementDataPoint] {
        do {
            let patientId = try await supabase.auth.session.user.id

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            struct SampleResult: Codable {
                let quantityType: String
                let quantityValue: Double
                let quantityUnit: String?
                let startTime: Date

                enum CodingKeys: String, CodingKey {
                    case quantityType = "quantity_type"
                    case quantityValue = "quantity_value"
                    case quantityUnit = "quantity_unit"
                    case startTime = "start_time"
                }
            }

            // Query patient_quantity_samples directly for waist and hip circumference
            let results: [SampleResult] = try await supabase
                .from("patient_quantity_samples")
                .select("quantity_type, quantity_value, quantity_unit, start_time")
                .eq("patient_id", value: patientId)
                .in("quantity_type", values: ["waist_circumference", "hip_circumference"])
                .gte("start_time", value: formatter.string(from: startDate))
                .lte("start_time", value: formatter.string(from: endDate))
                .order("start_time", ascending: false)
                .execute()
                .value

            let calendar = Calendar.current

            // Determine aggregation granularity based on period
            // D: hourly, W/M: daily, 6M: weekly, Y: monthly
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
            struct BucketData {
                var waistValues: [Double] = []
                var hipValues: [Double] = []
            }
            var bucketData: [Date: BucketData] = [:]

            for result in results {
                // Convert to cm if stored in inches
                let valueInCm: Double
                if let unit = result.quantityUnit?.lowercased(), unit == "inch" || unit == "in" {
                    valueInCm = result.quantityValue * 2.54
                } else {
                    valueInCm = result.quantityValue
                }

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

                if bucketData[bucketStart] == nil {
                    bucketData[bucketStart] = BucketData()
                }

                if result.quantityType == "waist_circumference" {
                    bucketData[bucketStart]?.waistValues.append(valueInCm)
                } else if result.quantityType == "hip_circumference" {
                    bucketData[bucketStart]?.hipValues.append(valueInCm)
                }
            }

            // Calculate averages for buckets with data
            var bucketAverages: [Date: (waist: Double?, hip: Double?)] = [:]
            for (bucketStart, data) in bucketData {
                let waistAvg = data.waistValues.isEmpty ? nil : data.waistValues.reduce(0, +) / Double(data.waistValues.count)
                let hipAvg = data.hipValues.isEmpty ? nil : data.hipValues.reduce(0, +) / Double(data.hipValues.count)
                bucketAverages[bucketStart] = (waist: waistAvg, hip: hipAvg)
            }

            // Create data points only for buckets with actual measurements
            // Carry forward values for derived calculations, but only when at least one measurement exists
            var aggregatedPoints: [MeasurementDataPoint] = []
            var lastKnownWaist: Double?
            var lastKnownHip: Double?

            for (bucketDate, averages) in bucketAverages.sorted(by: { $0.key < $1.key }) {
                let hasActualWaist = averages.waist != nil
                let hasActualHip = averages.hip != nil

                // Skip buckets with no measurements at all
                guard hasActualWaist || hasActualHip else { continue }

                // Update last known values
                if let waist = averages.waist {
                    lastKnownWaist = waist
                }
                if let hip = averages.hip {
                    lastKnownHip = hip
                }

                // Create data point with actual or derived values
                let waistValue = averages.waist ?? lastKnownWaist ?? 0
                let hipValue = averages.hip ?? lastKnownHip ?? 0

                aggregatedPoints.append(MeasurementDataPoint(
                    date: bucketDate,
                    waist: waistValue,
                    hip: hipValue,
                    waistIsDerived: !hasActualWaist,
                    hipIsDerived: !hasActualHip
                ))
            }

            print("📊 Measurements: Fetched \(results.count) raw samples → \(aggregatedPoints.count) data points (\(selectedPeriod.rawValue) view)")

            return aggregatedPoints

        } catch {
            print("❌ Error fetching measurements: \(error)")
            return []
        }
    }
}
