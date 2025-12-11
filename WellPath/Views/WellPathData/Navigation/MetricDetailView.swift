//
//  MetricDetailView.swift
//  WellPath
//
//  Complete implementation with TRUE INFINITE SCROLLING
//

import SwiftUI
import Charts

struct MetricDetailView: View {
    let screen: DisplayScreen
    let pillar: String
    @StateObject private var viewModel = MetricDetailViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                ProgressView("Loading metrics...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
            } else if let error = viewModel.error {
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer()
                            .frame(height: 60)

                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 72))
                            .foregroundColor(.orange.opacity(0.7))

                        VStack(spacing: 12) {
                            Text("Unable to Load Metrics")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("There was a problem loading the metrics for this screen.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }

                        Button {
                            Task {
                                await viewModel.loadMetrics(forScreen: screen.screenId)
                            }
                        } label: {
                            Label("Retry", systemImage: "arrow.clockwise")
                                .font(.headline)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Error Details:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("Screen ID: \(screen.screenId)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.top, 16)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            } else if let parentMetric = viewModel.parentMetric {
                ScrollView {
                    ParentMetricDetailView(
                        metric: parentMetric,
                        sections: viewModel.sections,
                        sectionChildren: viewModel.sectionChildren,
                        pillar: pillar,
                        color: MetricsUIConfig.getPillarColor(for: pillar)
                    )
                }
            } else {
                // Fallback state - show empty state with navigation intact
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer()
                            .frame(height: 60)

                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 72))
                            .foregroundColor(.secondary.opacity(0.5))

                        VStack(spacing: 12) {
                            Text("No Metrics Configured")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("This screen hasn't been set up with metrics yet. Check back soon!")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Debug Info:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            Text("Screen ID: \(screen.screenId)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("Pillar: \(pillar)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.top, 24)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(screen.name)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadMetrics(forScreen: screen.screenId)
        }
    }
}

// MARK: - Data Models

struct ChartDataPoint: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let value: Double
    let label: String

    static func == (lhs: ChartDataPoint, rhs: ChartDataPoint) -> Bool {
        lhs.id == rhs.id
    }
}

// Note: AggregationResult and DisplayMetricAggregation models are defined in SleepViewModel.swift

enum TimePeriod: String, CaseIterable {
    case hour = "H"
    case day = "D"
    case week = "W"
    case month = "M"
    case sixMonth = "6M"
    case year = "Y"

    var numberOfBars: Int {
        switch self {
        case .hour: return 60     // 60 minutes (each bar = that minute)
        case .day: return 24      // 24 hours (each bar = that hour)
        case .week: return 7      // 7 days (each bar = that day)
        case .month: return 33    // 33 days (each bar = that day)
        case .sixMonth: return 26 // 26 weeks (each bar = weekly average)
        case .year: return 12     // 12 months (each bar = monthly average)
        }
    }

    // How many periods to load at once
    var loadChunkSize: Int {
        switch self {
        case .hour: return 120     // Load 2 hours at a time
        case .day: return 48       // Load 2 days at a time
        case .week: return 28      // Load 4 weeks at a time
        case .month: return 66     // Load 2 months at a time
        case .sixMonth: return 52  // Load 1 year at a time
        case .year: return 24      // Load 2 years at a time
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .hour: return .minute
        case .day: return .hour
        case .week, .month: return .day
        case .sixMonth: return .weekOfYear
        case .year: return .month
        }
    }

    // Map UI period to database period_type
    // All views query hourly or daily aggregations; 6M/Y aggregate client-side
    var databasePeriodType: String {
        switch self {
        case .hour: return "minute"  // Raw series data
        case .day: return "hourly"
        case .week: return "daily"
        case .month: return "daily"
        case .sixMonth: return "daily"   // Query daily, aggregate to weekly client-side
        case .year: return "daily"       // Query daily, aggregate to monthly client-side
        }
    }

    // Whether this period requires client-side aggregation of daily data
    var requiresClientSideAggregation: Bool {
        switch self {
        case .sixMonth, .year: return true
        default: return false
        }
    }

    // Target grouping granularity for client-side aggregation
    var aggregationGranularity: Calendar.Component? {
        switch self {
        case .sixMonth: return .weekOfYear
        case .year: return .month
        default: return nil
        }
    }

    // Calculation type to use for aggregations
    var calculationType: String {
        // All periods query SUM aggregations (daily/hourly totals)
        // 6M/Y views aggregate daily SUMs into weekly/monthly averages client-side
        switch self {
        case .day:
            return "SUM"  // SUM of hourly entries for the day
        case .week, .month:
            return "SUM"  // SUM for daily aggregations (daily totals)
        case .sixMonth, .year:
            return "SUM"  // SUM for daily data, averaged client-side into weekly/monthly
        }
    }

    // Label when NO bar is selected (showing aggregate)
    var aggregateLabel: String {
        switch self {
        case .day:
            return "DAILY TOTAL"
        case .week, .month, .sixMonth, .year:
            return "DAILY AVERAGE"
        }
    }

    // Label when a bar IS selected (showing that bar's value)
    var barLabel: String {
        switch self {
        case .day:
            return "HOURLY TOTAL"
        case .week, .month:
            return "DAILY TOTAL"
        case .sixMonth:
            return "DAILY AVERAGE (WEEK)"
        case .year:
            return "DAILY AVERAGE (MONTH)"
        }
    }
}

// MARK: - Infinite Scroll Chart Manager

@MainActor
class InfiniteScrollChartManager: ObservableObject {
    @Published var chartData: [ChartDataPoint] = []
    @Published var isLoadingOlder = false
    @Published var isLoadingNewer = false
    @Published var actualUnit: String?  // Unit from database
    @Published var decimalPlaces: Int = 0  // Decimal places for formatting

    private var oldestDate: Date
    private var newestDate: Date
    private var selectedPeriod: TimePeriod
    private var selectedUnit: String  // Changed to var so it can be updated
    private let valueRange: ClosedRange<Double>
    private let metricId: String
    private let supabase = SupabaseManager.shared.client

    init(period: TimePeriod, unit: String, valueRange: ClosedRange<Double>, metricId: String) {
        self.selectedPeriod = period
        self.selectedUnit = unit
        self.valueRange = valueRange
        self.metricId = metricId

        // Initialize with reasonable range based on period
        let now = Date()

        // Extend into future by 1 month so user can scroll ahead
        self.newestDate = Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now

        // Initial load: Start with a small range for performance
        switch period {
        case .day:
            self.oldestDate = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        case .week:
            self.oldestDate = Calendar.current.date(byAdding: .weekOfYear, value: -8, to: now) ?? now
        case .month:
            self.oldestDate = Calendar.current.date(byAdding: .month, value: -6, to: now) ?? now
        case .sixMonth:
            self.oldestDate = Calendar.current.date(byAdding: .month, value: -18, to: now) ?? now
        case .year:
            self.oldestDate = Calendar.current.date(byAdding: .year, value: -3, to: now) ?? now
        }

        Task {
            await generateInitialData()
        }
    }

    func updatePeriod(_ period: TimePeriod, unit: String, valueRange: ClosedRange<Double>) {
        self.selectedPeriod = period

        // Reset range based on new period
        let now = Date()

        // Extend into future
        self.newestDate = Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now

        // Initial load: Start with a small range for performance
        switch period {
        case .day:
            self.oldestDate = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        case .week:
            self.oldestDate = Calendar.current.date(byAdding: .weekOfYear, value: -8, to: now) ?? now
        case .month:
            self.oldestDate = Calendar.current.date(byAdding: .month, value: -6, to: now) ?? now
        case .sixMonth:
            self.oldestDate = Calendar.current.date(byAdding: .month, value: -18, to: now) ?? now
        case .year:
            self.oldestDate = Calendar.current.date(byAdding: .year, value: -3, to: now) ?? now
        }

        chartData.removeAll()
        Task {
            await generateDataRange(from: oldestDate, to: newestDate)
        }
    }

    private func generateInitialData() async {
        await generateDataRange(from: oldestDate, to: newestDate)
    }
    
    func loadOlderData() {
        guard !isLoadingOlder else { return }
        isLoadingOlder = true

        Task {
            let calendar = Calendar.current
            let component = selectedPeriod.calendarComponent

            // Calculate how much data to load based on period (use loadChunkSize)
            let loadAmount = -selectedPeriod.loadChunkSize

            // Don't go beyond 10 years total
            let tenYearsAgo = calendar.date(byAdding: .year, value: -10, to: Date()) ?? Date()
            guard oldestDate > tenYearsAgo else {
                print("📊 Reached 10 year limit, not loading older data")
                isLoadingOlder = false
                return
            }

            let newOldestDate = calendar.date(byAdding: component, value: loadAmount, to: oldestDate) ?? oldestDate

            // Don't go beyond 10 years
            let cappedOldestDate = max(newOldestDate, tenYearsAgo)

            print("📊 Loading older data from \(cappedOldestDate) to \(oldestDate)")

            // Generate and prepend new data
            await generateDataRange(from: cappedOldestDate, to: oldestDate)

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

            // Calculate how much data to load based on period (use loadChunkSize)
            let loadAmount = selectedPeriod.loadChunkSize

            let newNewestDate = calendar.date(byAdding: component, value: loadAmount, to: newestDate) ?? newestDate

            print("📊 Loading newer data from \(newestDate) to \(newNewestDate)")

            // Generate and prepend new data
            await generateDataRange(from: newestDate, to: newNewestDate)

            newestDate = newNewestDate
            isLoadingNewer = false
        }
    }
    
    private func generateDataRange(from startDate: Date, to endDate: Date) async {
        // Generate complete timeline then overlay data
        var timeline = generateEmptyTimeline(from: startDate, to: endDate)
        let dataPoints = await fetchAllDataPoints()

        // Overlay actual data on timeline
        for dataPoint in dataPoints {
            if let index = timeline.firstIndex(where: {
                Calendar.current.isDate($0.date, equalTo: dataPoint.date, toGranularity: getDateGranularity())
            }) {
                timeline[index] = dataPoint
            }
        }

        // Determine if we're loading older or newer data based on date comparison
        if chartData.isEmpty {
            // Initial load
            chartData = timeline
        } else if let firstExisting = chartData.first, let lastNew = timeline.last,
                  lastNew.date < firstExisting.date {
            // Loading older data - prepend
            chartData = timeline + chartData
        } else if let lastExisting = chartData.last, let firstNew = timeline.first,
                  firstNew.date > lastExisting.date {
            // Loading newer data - append
            chartData = chartData + timeline
        } else {
            // Overlapping or initial load - replace
            chartData = timeline
        }

        print("📈 Generated \(timeline.count) timeline points (\(dataPoints.count) with data). Total: \(chartData.count)")
    }

    private func getDateGranularity() -> Calendar.Component {
        switch selectedPeriod {
        case .day: return .hour
        case .week, .month: return .day
        case .sixMonth: return .weekOfYear
        case .year: return .month
        }
    }

    private func generateEmptyTimeline(from startDate: Date, to endDate: Date) -> [ChartDataPoint] {
        var points: [ChartDataPoint] = []
        let calendar = Calendar.current
        var currentDate = startDate

        while currentDate <= endDate {
            let barDate: Date
            if selectedPeriod == .year {
                var components = calendar.dateComponents([.year, .month], from: currentDate)
                components.day = 15
                barDate = calendar.date(from: components) ?? currentDate
            } else {
                barDate = currentDate
            }

            points.append(ChartDataPoint(date: barDate, value: 0, label: ""))

            guard let nextDate = calendar.date(byAdding: selectedPeriod.calendarComponent, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return points
    }

    private func fetchAllDataPoints() async -> [ChartDataPoint] {
        do {
            // Get current user ID
            let userId = try await supabase.auth.session.user.id

            let periodType = selectedPeriod.databasePeriodType
            let calculationType = selectedPeriod.calculationType

            NSLog("[CHART] 👤 User ID: %@", userId.uuidString)
            NSLog("[CHART] Fetching ALL data for metric=%@, period=%@, calc=%@", metricId, periodType, calculationType)

            // First, get the sample_quantity_type from the junction table
            struct JunctionResult: Codable {
                let sampleQuantityType: String?
                let sampleCategoryType: String?
                let sampleClinicalType: String?
                let sampleCorrelationType: String?
                enum CodingKeys: String, CodingKey {
                    case sampleQuantityType = "sample_quantity_type"
                    case sampleCategoryType = "sample_category_type"
                    case sampleClinicalType = "sample_clinical_type"
                    case sampleCorrelationType = "sample_correlation_type"
                }
            }

            let junctionResults: [JunctionResult] = try await supabase
                .from("display_views_dependencies")
                .select("sample_quantity_type, sample_category_type, sample_clinical_type, sample_correlation_type")
                .eq("view_id", value: metricId)
                .eq("is_primary", value: true)
                .execute()
                .value

            // Use first result with a sample type
            guard let junction = junctionResults.first else {
                NSLog("[CHART] ❌ No dependency found for metric=%@ period=%@. Showing empty bars.", metricId, periodType)
                return []
            }

            // Determine which sample type to use
            let sampleType: String
            let sampleTable: String
            if let quantityType = junction.sampleQuantityType {
                sampleType = quantityType
                sampleTable = "patient_quantity_samples"
            } else if let categoryType = junction.sampleCategoryType {
                sampleType = categoryType
                sampleTable = "patient_category_samples"
            } else if let clinicalType = junction.sampleClinicalType {
                sampleType = clinicalType
                sampleTable = "patient_clinical_samples"
            } else if let correlationType = junction.sampleCorrelationType {
                sampleType = correlationType
                sampleTable = "patient_correlation_samples"
            } else {
                NSLog("[CHART] ❌ No sample type found for metric=%@. Showing empty bars.", metricId)
                return []
            }

            NSLog("[CHART] ✅ Found sample_type: %@ (table: %@)", sampleType, sampleTable)

            // Fetch the canonical_unit from sample_quantity_types
            struct SampleTypeInfo: Codable {
                let canonicalUnit: String?
                enum CodingKeys: String, CodingKey {
                    case canonicalUnit = "canonical_unit"
                }
            }

            let typeInfo: [SampleTypeInfo] = try await supabase
                .from("sample_quantity_types")
                .select("canonical_unit")
                .eq("quantity_type", value: sampleType)
                .execute()
                .value

            let unitId = typeInfo.first?.canonicalUnit ?? "unit"

            // Now fetch the unit display info from units_base
            struct UnitsBaseInfo: Codable {
                let uiDisplay: String
                let decimalPlaces: Int?

                enum CodingKeys: String, CodingKey {
                    case uiDisplay = "ui_display"
                    case decimalPlaces = "decimal_places"
                }
            }

            let unitsInfo: [UnitsBaseInfo] = try await supabase
                .from("units_base")
                .select("ui_display, decimal_places")
                .eq("unit_id", value: unitId)
                .execute()
                .value

            let fetchedUnit = unitsInfo.first?.uiDisplay ?? "unit"
            let fetchedDecimalPlaces = unitsInfo.first?.decimalPlaces ?? 0
            NSLog("[CHART] 📏 Fetched unit from database: '%@' with %d decimal places (metricId: %@, sampleType: %@)", fetchedUnit, fetchedDecimalPlaces, metricId, sampleType)

            // Store actual unit and decimal places from database and update selectedUnit
            self.actualUnit = fetchedUnit
            self.decimalPlaces = fetchedDecimalPlaces
            NSLog("[CHART] 📏 Set manager.actualUnit = '%@', manager.decimalPlaces = %d", fetchedUnit, fetchedDecimalPlaces)
            if self.selectedUnit.isEmpty {
                self.selectedUnit = fetchedUnit
                NSLog("[CHART] 📏 Set manager.selectedUnit = '%@' (was empty)", fetchedUnit)
            } else {
                NSLog("[CHART] 📏 manager.selectedUnit already set to '%@', not updating", self.selectedUnit)
            }

            // Query patient_quantity_samples - for Day view, need hourly granularity
            // For other views, aggregate by aggregation_date
            let calendar = Calendar.current
            var points: [ChartDataPoint] = []

            if selectedPeriod == .day {
                // Day view: query by start_time and group by hour
                struct HourlySample: Codable {
                    let startTime: Date
                    let quantityValue: Double?
                    let canonicalValue: Double?

                    enum CodingKeys: String, CodingKey {
                        case startTime = "start_time"
                        case quantityValue = "quantity_value"
                        case canonicalValue = "canonical_value"
                    }
                }

                let samples: [HourlySample] = try await supabase
                    .from("patient_quantity_samples")
                    .select("start_time, quantity_value, canonical_value")
                    .eq("patient_id", value: userId)
                    .eq("quantity_type", value: sampleType)
                    .eq("is_primary", value: true)
                    .order("start_time", ascending: false)
                    .execute()
                    .value

                NSLog("[CHART] 📊 Fetched %d samples from patient_quantity_samples for %@ (hourly mode)", samples.count, sampleType)

                // Group by hour (year, month, day, hour)
                var hourlyTotals: [DateComponents: Double] = [:]
                for sample in samples {
                    let value = sample.canonicalValue ?? sample.quantityValue ?? 0.0
                    let components = calendar.dateComponents([.year, .month, .day, .hour], from: sample.startTime)
                    hourlyTotals[components, default: 0.0] += value
                }

                NSLog("[CHART] 📊 Grouped into %d hourly buckets", hourlyTotals.count)

                for (components, total) in hourlyTotals {
                    guard let date = calendar.date(from: components) else { continue }
                    points.append(ChartDataPoint(
                        date: date,
                        value: total,
                        label: ""
                    ))
                }
            } else {
                // Other views: aggregate by aggregation_date (daily)
                struct QuantitySample: Codable {
                    let aggregationDate: String
                    let quantityValue: Double?
                    let canonicalValue: Double?

                    enum CodingKeys: String, CodingKey {
                        case aggregationDate = "aggregation_date"
                        case quantityValue = "quantity_value"
                        case canonicalValue = "canonical_value"
                    }
                }

                let samples: [QuantitySample] = try await supabase
                    .from("patient_quantity_samples")
                    .select("aggregation_date, quantity_value, canonical_value")
                    .eq("patient_id", value: userId)
                    .eq("quantity_type", value: sampleType)
                    .eq("is_primary", value: true)  // Only use primary samples for analysis
                    .order("aggregation_date", ascending: false)
                    .execute()
                    .value

                NSLog("[CHART] 📊 Fetched %d samples from patient_quantity_samples for %@ (daily mode)", samples.count, sampleType)

                // Aggregate samples by date (sum values for each day)
                // Parse aggregation_date as local noon to avoid DST/timezone edge cases
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
                dateFormatter.timeZone = TimeZone.current

                var dailyTotals: [String: Double] = [:]
                for sample in samples {
                    let value = sample.canonicalValue ?? sample.quantityValue ?? 0.0
                    dailyTotals[sample.aggregationDate, default: 0.0] += value
                }

                for (dateString, total) in dailyTotals {
                    guard let date = dateFormatter.date(from: dateString + " 12:00") else { continue }

                    let barDate: Date
                    if selectedPeriod == .year {
                        var components = calendar.dateComponents([.year, .month], from: date)
                        components.day = 15
                        barDate = calendar.date(from: components) ?? date
                    } else {
                        barDate = date
                    }

                    points.append(ChartDataPoint(
                        date: barDate,
                        value: total,
                        label: ""
                    ))
                }
            }

            // Sort by date descending to match previous behavior
            points.sort { $0.date > $1.date }

            // For 6M/Y views, aggregate daily data into weekly/monthly averages
            if selectedPeriod.requiresClientSideAggregation,
               let granularity = selectedPeriod.aggregationGranularity {
                let aggregatedPoints = aggregateDailyData(points, by: granularity)
                NSLog("[CHART] 📊 Aggregated %d daily points into %d %@ points",
                      points.count, aggregatedPoints.count,
                      granularity == .weekOfYear ? "weekly" : "monthly")
                return aggregatedPoints
            }

            return points

        } catch {
            NSLog("[CHART] ⚠️ Error fetching data: %@, returning empty", error.localizedDescription)
            NSLog("[CHART] Error details: %@", String(describing: error))
            return []
        }
    }

    /// Aggregates daily data points into weekly or monthly averages
    /// - Parameters:
    ///   - dailyPoints: Array of daily ChartDataPoints
    ///   - component: Calendar component to group by (.weekOfYear or .month)
    /// - Returns: Aggregated ChartDataPoints with averaged values
    private func aggregateDailyData(_ dailyPoints: [ChartDataPoint], by component: Calendar.Component) -> [ChartDataPoint] {
        guard !dailyPoints.isEmpty else { return [] }

        let calendar = Calendar.current

        // Group points by their week/month
        var grouped: [DateComponents: [ChartDataPoint]] = [:]

        for point in dailyPoints {
            var components: DateComponents
            if component == .weekOfYear {
                // Group by year + week of year
                components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: point.date)
            } else {
                // Group by year + month
                components = calendar.dateComponents([.year, .month], from: point.date)
            }
            grouped[components, default: []].append(point)
        }

        // Calculate average for each group and create representative date
        var aggregatedPoints: [ChartDataPoint] = []

        for (components, points) in grouped {
            // Calculate average of non-zero values (exclude empty days)
            let nonZeroValues = points.filter { $0.value > 0 }.map { $0.value }
            let averageValue: Double
            if nonZeroValues.isEmpty {
                averageValue = 0
            } else {
                averageValue = nonZeroValues.reduce(0, +) / Double(nonZeroValues.count)
            }

            // Create representative date for the bucket
            let representativeDate: Date
            if component == .weekOfYear {
                // Use Monday of the week as the representative date
                var weekComponents = components
                weekComponents.weekday = 2 // Monday
                representativeDate = calendar.date(from: weekComponents) ?? points.first!.date
            } else {
                // Use 15th of the month as the representative date
                var monthComponents = components
                monthComponents.day = 15
                representativeDate = calendar.date(from: monthComponents) ?? points.first!.date
            }

            aggregatedPoints.append(ChartDataPoint(
                date: representativeDate,
                value: averageValue,
                label: ""
            ))
        }

        // Sort by date descending (most recent first)
        return aggregatedPoints.sorted { $0.date > $1.date }
    }

    private func generateEmptyDataPoints(from startDate: Date, to endDate: Date) -> [ChartDataPoint] {
        var points: [ChartDataPoint] = []
        let calendar = Calendar.current
        var currentDate = startDate

        while currentDate <= endDate {
            let barDate: Date
            if selectedPeriod == .year {
                var components = calendar.dateComponents([.year, .month], from: currentDate)
                components.day = 15
                barDate = calendar.date(from: components) ?? currentDate
            } else {
                barDate = currentDate
            }

            // Empty data point (value = 0)
            points.append(ChartDataPoint(date: barDate, value: 0, label: ""))

            if let nextDate = calendar.date(byAdding: selectedPeriod.calendarComponent, value: 1, to: currentDate) {
                currentDate = nextDate
            } else {
                break
            }
        }

        return points.reversed()
    }
}

// MARK: - Parent Metric Bar Chart (TRUE Infinite Scrolling)

struct ParentMetricBarChart: View {
    let metric: DisplayMetric
    let color: Color
    var showAbout: Binding<Bool>? = nil

    @State private var selectedPeriod: TimePeriod = .week
    @State private var selectedBarDate: Date?
    @State private var selectedUnit: String
    @State private var actualUnit: String?  // Unit from database
    @State private var decimalPlaces: Int = 0  // Decimal places for formatting
    @State private var dailySums: [Double] = []  // Daily SUM aggregations for 6M/Y unselected views
    @StateObject private var scrollManager: InfiniteScrollChartManager
    @State private var scrollViewID = UUID()
    @State private var scrollPosition: Date

    private var selectedBar: ChartDataPoint? {
        guard let selectedDate = selectedBarDate else { return nil }
        return scrollManager.chartData.first(where: { $0.date == selectedDate })
    }

    init(metric: DisplayMetric, color: Color, showAbout: Binding<Bool>? = nil) {
        self.metric = metric
        self.color = color
        self.showAbout = showAbout

        // Unit will be fetched from aggregation_metrics dynamically
        // Default to empty string, will be loaded in task
        _selectedUnit = State(initialValue: "")

        // Default range - will be adjusted based on actual data
        let range: ClosedRange<Double> = 0.0...100.0

        // Initialize scroll position so TODAY is visible with a small buffer of future dates
        let now = Date()
        let initialPeriod = TimePeriod.week
        let visibleDuration = initialPeriod.numberOfBars

        // Position scroll so today is ~90% across the visible window (leaving 10% for future)
        let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
        let scrollStart = Calendar.current.date(
            byAdding: initialPeriod.calendarComponent,
            value: -offsetFromEnd,
            to: now
        ) ?? now

        _scrollPosition = State(initialValue: scrollStart)

        _scrollManager = StateObject(wrappedValue: InfiniteScrollChartManager(
            period: initialPeriod,
            unit: "",  // Will be loaded dynamically from database
            valueRange: range,
            metricId: metric.metricId
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Time period picker (exclude day view for sleep metrics only)
            Picker("Period", selection: $selectedPeriod) {
                ForEach(TimePeriod.allCases.filter { period in
                    // Exclude day view only for sleep metrics
                    if metric.metricName.lowercased().contains("sleep") {
                        return period != .day
                    }
                    return true
                }, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 16)
            .onChange(of: selectedPeriod) { oldValue, newPeriod in
                let range = getValueRange()
                scrollManager.updatePeriod(newPeriod, unit: selectedUnit, valueRange: range)
                selectedBarDate = nil
                
                // Reset daily sums - will be fetched if needed for 6M/Y
                dailySums = []

                // Reset scroll position so TODAY is visible with buffer for future dates
                let now = Date()
                let visibleDuration = newPeriod.numberOfBars
                let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
                scrollPosition = Calendar.current.date(
                    byAdding: newPeriod.calendarComponent,
                    value: -offsetFromEnd,
                    to: now
                ) ?? now

                scrollViewID = UUID() // Force ScrollView recreation
                
                // Fetch daily sums for 6M/Y periods if unselected
                if newPeriod == .sixMonth || newPeriod == .year {
                    Task {
                        dailySums = await fetchDailySumsForVisibleRange()
                    }
                }
            }
            .onChange(of: scrollPosition) { oldValue, newValue in
                // When scroll position changes, refetch daily sums for 6M/Y if unselected
                if selectedBarDate == nil && (selectedPeriod == .sixMonth || selectedPeriod == .year) {
                    Task {
                        dailySums = await fetchDailySumsForVisibleRange()
                    }
                }
            }
            .onChange(of: selectedBarDate) { oldValue, newValue in
                // When bar is deselected for 6M/Y, fetch daily sums if not already loaded
                if newValue == nil && (selectedPeriod == .sixMonth || selectedPeriod == .year) {
                    if dailySums.isEmpty {
                        Task {
                            dailySums = await fetchDailySumsForVisibleRange()
                        }
                    }
                }
            }

            // Unit toggle removed - protein is grams only

            // Value display (selected or average) with optional info button
            HStack(alignment: .top, spacing: 40) {
                VStack(alignment: .leading, spacing: 4) {
                    if let selected = selectedBar {
                        Text(selectedPeriod.barLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatValue(getDisplayValue(for: selected.value)))
                                .font(.system(size: 48, weight: .semibold))
                            // Don't show unit if already in formatted value (hours_minutes or minutes)
                            let unitToCheck = (actualUnit ?? selectedUnit).lowercased().trimmingCharacters(in: .whitespaces)
                            let isMinutesUnit = unitToCheck == "hours_minutes" ||
                                               unitToCheck == "minutes" ||
                                               unitToCheck == "min" ||
                                               unitToCheck == "minute" ||
                                               unitToCheck.hasPrefix("minute")
                            if !isMinutesUnit && !selectedUnit.isEmpty {
                                Text(selectedUnit)
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Text(formatDate(selected.date))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text(selectedPeriod.aggregateLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatValue(calculateAggregate()))
                                .font(.system(size: 48, weight: .semibold))
                            // Don't show unit if already in formatted value (hours_minutes or minutes)
                            let unitToCheck = (actualUnit ?? selectedUnit).lowercased().trimmingCharacters(in: .whitespaces)
                            let isMinutesUnit = unitToCheck == "hours_minutes" ||
                                               unitToCheck == "minutes" ||
                                               unitToCheck == "min" ||
                                               unitToCheck == "minute" ||
                                               unitToCheck.hasPrefix("minute")
                            if !isMinutesUnit && !selectedUnit.isEmpty {
                                Text(selectedUnit)
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

                // Info button (top-aligned with value display)
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
                // Update actualUnit when manager fetches it from database
                NSLog("[CHART] 📏 onChange actualUnit triggered: oldValue='%@', newValue='%@'", oldValue ?? "nil", newValue ?? "nil")
                if let newUnit = newValue {
                    NSLog("[CHART] 📏 Syncing actualUnit: \(oldValue ?? "nil") → \(newUnit)")
                    actualUnit = newUnit
                    // Also update selectedUnit if it's empty
                    if selectedUnit.isEmpty {
                        NSLog("[CHART] 📏 Updating selectedUnit from empty to: \(newUnit)")
                        selectedUnit = newUnit
                    }
                } else {
                    NSLog("[CHART] ⚠️ onChange actualUnit: newValue is nil!")
                }
            }
            .onAppear {
                // Also check on appear in case unit was already set before view appeared
                NSLog("[CHART] 📏 onAppear: actualUnit='%@', selectedUnit='%@', scrollManager.actualUnit='%@'", 
                      actualUnit ?? "nil", selectedUnit, scrollManager.actualUnit ?? "nil")
                if let managerUnit = scrollManager.actualUnit, actualUnit == nil {
                    NSLog("[CHART] 📏 Setting actualUnit from manager on appear: \(managerUnit)")
                    actualUnit = managerUnit
                    if selectedUnit.isEmpty {
                        selectedUnit = managerUnit
                    }
                }
                
                // Fetch daily sums for 6M/Y periods if unselected
                if selectedBarDate == nil && (selectedPeriod == .sixMonth || selectedPeriod == .year) {
                    Task {
                        dailySums = await fetchDailySumsForVisibleRange()
                    }
                }
            }
            .onChange(of: scrollManager.decimalPlaces) { oldValue, newValue in
                NSLog("[CHART] 📏 Syncing decimalPlaces: \(oldValue) → \(newValue)")
                decimalPlaces = newValue
            }

            // Infinite scrollable chart (using native Charts scrolling)
            let _ = print("📊 Chart data count: \(scrollManager.chartData.count)")
            Chart(scrollManager.chartData) { dataPoint in
                BarMark(
                    x: .value("Time", dataPoint.date, unit: selectedPeriod.calendarComponent),
                    y: .value("Value", getYAxisValue(for: dataPoint.value))
                )
                .foregroundStyle(selectedBarDate == dataPoint.date ? color.opacity(0.6) : color)
            }
            .frame(height: 280)
            .chartScrollableAxes(.horizontal)
            .chartScrollPosition(x: $scrollPosition)
            .chartXVisibleDomain(length: getVisibleDomainTimeInterval())
            .chartGesture { proxy in
                SpatialTapGesture()
                    .onEnded { value in
                        // Convert tap location to chart data value
                        if let tappedDate: Date = proxy.value(atX: value.location.x) {
                            // Find closest data point
                            let closest = scrollManager.chartData.min(by: {
                                abs($0.date.timeIntervalSince(tappedDate)) < abs($1.date.timeIntervalSince(tappedDate))
                            })

                            if selectedBarDate == closest?.date {
                                // Deselect if tapping same bar
                                selectedBarDate = nil
                            } else {
                                selectedBarDate = closest?.date
                            }
                            print("✅ Tapped bar: \(selectedBarDate?.description ?? "none")")
                        }
                    }
            }
            .onChange(of: scrollPosition) { oldValue, newValue in
                print("📍 Scroll position: \(newValue)")
                // Check if we need to load more data based on scroll position
                handleChartScrolling(position: newValue)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: getAxisLabelStride(), count: getAxisLabelMultiplier())) { value in
                    if let date = value.as(Date.self) {
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
                            // For hours_minutes or minutes, database stores minutes - convert to hours for display
                            let unitToCheck = (actualUnit ?? selectedUnit).lowercased().trimmingCharacters(in: .whitespaces)
                            if unitToCheck == "hours_minutes" ||
                               unitToCheck == "minutes" ||
                               unitToCheck == "min" ||
                               unitToCheck == "minute" {
                                let hours = Int(numValue / 60.0)
                                Text("\(hours)h")
                            } else {
                                // Standard numeric display
                                Text("\(Int(numValue))")
                            }
                        }
                    }
                    AxisGridLine(
                        stroke: StrokeStyle(
                            lineWidth: 0.5,
                            dash: [2, 3]
                        )
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
    }

    // MARK: - Infinite Scroll Detection

    private func handleScrolling(offset: CGFloat) {
        let chartWidth = getChartWidth()
        let screenWidth = UIScreen.main.bounds.width
        
        // Load older data when scrolled near beginning
        if offset > -200 && !scrollManager.isLoadingOlder {
            print("ðŸ”„ Near beginning, loading older data...")
            scrollManager.loadOlderData()
        }
        
        // Load newer data when scrolled near end
        let distanceFromEnd = chartWidth + offset - screenWidth
        if distanceFromEnd < 200 && !scrollManager.isLoadingNewer {
            print("ðŸ”„ Near end, loading newer data...")
            scrollManager.loadNewerData()
        }
    }
    
    // MARK: - Chart Scroll Handlers

    private func handleChartScrolling(position: Date) {
        guard !scrollManager.chartData.isEmpty else { return }

        let calendar = Calendar.current
        let component = selectedPeriod.calendarComponent

        // Check if scrolling near oldest data
        if let oldestDate = scrollManager.chartData.last?.date {
            let diff = calendar.dateComponents([component], from: oldestDate, to: position)
            let units = abs(diff.value(for: component) ?? 0)

            // Load older data if within 5 units of oldest
            if units < 5 && !scrollManager.isLoadingOlder {
                print("📄 Scrolling near oldest date, loading older data...")
                scrollManager.loadOlderData()
            }
        }

        // Check if scrolling near newest data
        if let newestDate = scrollManager.chartData.first?.date {
            let diff = calendar.dateComponents([component], from: position, to: newestDate)
            let units = abs(diff.value(for: component) ?? 0)

            // Load newer data if within 5 units of newest
            if units < 5 && !scrollManager.isLoadingNewer {
                print("📄 Scrolling near newest date, loading newer data...")
                scrollManager.loadNewerData()
            }
        }
    }

    private func handleChartScroll(position: Date?) {
        guard let position = position else { return }

        // Check if we're near the edges and need to load more data
        if let oldestDate = scrollManager.chartData.last?.date {
            let calendar = Calendar.current
            let component = selectedPeriod.calendarComponent
            let diff = calendar.dateComponents([component], from: oldestDate, to: position)
            let units = diff.value(for: component) ?? 0

            // Load older data if scrolling back and within 5 units of oldest data
            if abs(units) < 5 && !scrollManager.isLoadingOlder {
                print("Near oldest data, loading older...")
                scrollManager.loadOlderData()
            }
        }

        if let newestDate = scrollManager.chartData.first?.date {
            let calendar = Calendar.current
            let component = selectedPeriod.calendarComponent
            let diff = calendar.dateComponents([component], from: position, to: newestDate)
            let units = diff.value(for: component) ?? 0

            // Load newer data if scrolling forward and within 5 units of newest data
            if abs(units) < 5 && !scrollManager.isLoadingNewer {
                print("Near newest data, loading newer...")
                scrollManager.loadNewerData()
            }
        }
    }
    
    private func getVisibleDomainLength() -> Int {
        switch selectedPeriod {
        case .day:
            return 24 // 24 hours
        case .week:
            return 7 // 7 days
        case .month:
            return 30 // 30 days
        case .sixMonth:
            return 26 // 26 weeks
        case .year:
            return 12 // 12 months
        }
    }

    private func getDateUnit() -> Calendar.Component {
        switch selectedPeriod {
        case .day: return .hour
        case .week: return .day
        case .month: return .day
        case .sixMonth: return .weekOfYear
        case .year: return .month
        }
    }

    private func getAxisStride() -> Calendar.Component {
        switch selectedPeriod {
        case .day: return .hour
        case .week: return .day
        case .month: return .day
        case .sixMonth: return .weekOfYear
        case .year: return .month
        }
    }

    // Stride for axis labels (can differ from data stride)
    private func getAxisLabelStride() -> Calendar.Component {
        switch selectedPeriod {
        case .day: return .hour
        case .week: return .day
        case .month: return .weekOfYear  // Weekly labels for month view
        case .sixMonth: return .month  // Monthly labels for 6-month view
        case .year: return .month
        }
    }

    private func getAxisLabelMultiplier() -> Int {
        switch selectedPeriod {
        case .day: return 6  // Every 6 hours (12 AM, 6 AM, 12 PM, 6 PM)
        case .week: return 1  // Every day
        case .month: return 1  // Every week
        case .sixMonth: return 1  // Every month
        case .year: return 1  // Every month
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

    private func getVisibleDomainTimeInterval() -> TimeInterval {
        switch selectedPeriod {
        case .day:
            return 24 * 3600 // 24 hours in seconds
        case .week:
            return 7 * 24 * 3600 // 7 days in seconds
        case .month:
            return 30 * 24 * 3600 // 30 days in seconds
        case .sixMonth:
            return 26 * 7 * 24 * 3600 // 26 weeks in seconds
        case .year:
            return 365 * 24 * 3600 // 1 year in seconds
        }
    }

    private func getBarWidth() -> CGFloat {
        switch selectedPeriod {
        case .day:
            return 10  // Narrow - 24 bars need to fit
        case .week:
            return 35  // 7 bars
        case .month:
            return 8   // Very narrow - 30 bars need to fit
        case .sixMonth:
            return 10  // 26 bars need to fit
        case .year:
            return 22  // 12 bars
        }
    }    

    private func getXAxisMarkValues() -> [Date] {
        switch selectedPeriod {
        case .day:
            // Show 12 AM, 6 AM, 12 PM, 6 PM
            return scrollManager.chartData.compactMap { point in
                let hour = Calendar.current.component(.hour, from: point.date)
                return (hour == 0 || hour == 6 || hour == 12 || hour == 18) ? point.date : nil
            }
            
        case .week:
            // Show every day
            return scrollManager.chartData.map { $0.date }
            
        case .month:
            // Show only Mondays (weekday == 2)
            return scrollManager.chartData.compactMap { point in
                let weekday = Calendar.current.component(.weekday, from: point.date)
                return weekday == 2 ? point.date : nil
            }
            
        case .sixMonth:
            // Show start of each month
            var marks: [Date] = []
            var lastMonth = -1
            for point in scrollManager.chartData {
                let month = Calendar.current.component(.month, from: point.date)
                if month != lastMonth {
                    marks.append(point.date)
                    lastMonth = month
                }
            }
            return marks
            
        case .year:
            // Show each month
            return scrollManager.chartData.map { $0.date }
        }
    }
    
    private func getDateMatchingUnit() -> Calendar.Component {
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

    private func getDateMatchingComponents() -> DateComponents {
        switch selectedPeriod {
        case .day:
            return DateComponents(hour: 1)
        case .week, .month:
            return DateComponents(day: 1)
        case .sixMonth:
            return DateComponents(weekOfYear: 1)
        case .year:
            return DateComponents(month: 1)
        }
    }
    
    private func getInitialScrollPosition() -> Date {
        // Start at the most recent date (first item since data is reversed)
        return scrollManager.chartData.first?.date ?? Date()
    }


    // MARK: - Chart Configuration

    private func getChartWidth() -> CGFloat {
        let barWidth: CGFloat
        
        switch selectedPeriod {
        case .day:
            barWidth = 30
        case .week:
            barWidth = 50
        case .month:
            barWidth = 25
        case .sixMonth:
            barWidth = 40
        case .year:
            barWidth = 60
        }
        
        let width = CGFloat(scrollManager.chartData.count) * barWidth
        print("ðŸ“Š Chart Width: \(width)pt for \(scrollManager.chartData.count) data points (barWidth: \(barWidth)pt)")
        return width
    }

    private func getXAxisMarks() -> [Date] {
        let visibleData = getVisibleData()
        
        switch selectedPeriod {
        case .day:
            return visibleData.filter { dataPoint in
                let hour = Calendar.current.component(.hour, from: dataPoint.date)
                return hour == 0 || hour == 6 || hour == 12 || hour == 18
            }.map { $0.date }
            
        case .week:
            return visibleData.map { $0.date }
            
        case .month:
            return visibleData.filter { dataPoint in
                Calendar.current.component(.weekday, from: dataPoint.date) == 2
            }.map { $0.date }
            
        case .sixMonth:
            var marks: [Date] = []
            var lastMonth = -1
            for dataPoint in visibleData {
                let month = Calendar.current.component(.month, from: dataPoint.date)
                if month != lastMonth {
                    marks.append(dataPoint.date)
                    lastMonth = month
                }
            }
            return marks
            
        case .year:
            return visibleData.map { $0.date }
        }
    }
    
    private func formatXAxisLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        switch selectedPeriod {
        case .day:
            let hour = calendar.component(.hour, from: date)
            if hour == 0 {
                return "12 AM"
            } else if hour < 12 {
                return "\(hour) AM"
            } else if hour == 12 {
                return "12 PM"
            } else {
                return "\(hour - 12) PM"
            }
            
        case .week, .month:
            formatter.dateFormat = "E"
            return formatter.string(from: date)
            
        case .sixMonth:
            formatter.dateFormat = "MMM"
            return formatter.string(from: date)
            
        case .year:
            formatter.dateFormat = "MMM"
            return formatter.string(from: date)
        }
    }

    private func getValueRange() -> ClosedRange<Double> {
        // Default range for protein (grams)
        if selectedUnit.lowercased().contains("gram") || selectedUnit == "g" {
            return 20.0...80.0
        } else {
            return 10.0...100.0
        }
    }

    // MARK: - Helpers

    private func getDisplayValue(for rawValue: Double) -> Double {
        // rawValue comes from patient_*_samples queries (aggregated by PatientSamplesQueryService or direct queries)
        // - D period: Total or average as appropriate
        // - W/M periods: SUM of daily aggregations (daily totals)
        // - 6M/Y periods: AVG of weekly/monthly aggregations (rollup aggregation)
        // All values are already correctly calculated - just pass through
        return rawValue
    }

    private func getYAxisValue(for rawValue: Double) -> Double {
        // First apply period-based conversion
        let periodAdjustedValue = getDisplayValue(for: rawValue)

        // Then convert to hours if using hours_minutes or minutes unit (for Y-axis display)
        let unitToCheck = actualUnit ?? selectedUnit
        if unitToCheck == "hours_minutes" || 
           unitToCheck == "minutes" || 
           unitToCheck == "min" || 
           unitToCheck == "minute" {
            return periodAdjustedValue / 60.0  // Convert minutes to hours for Y-axis
        }

        return periodAdjustedValue
    }

    private func getVisibleData() -> [ChartDataPoint] {
        guard !scrollManager.chartData.isEmpty else { return [] }

        // Calculate the visible window based on scroll position
        // scrollPosition is the LEFT/START edge of the visible domain
        let visibleDuration = getVisibleDomainTimeInterval()

        guard let endDate = Calendar.current.date(byAdding: .second, value: Int(visibleDuration), to: scrollPosition) else {
            // Fallback to most recent data
            let count = min(selectedPeriod.numberOfBars, scrollManager.chartData.count)
            let startIndex = max(0, scrollManager.chartData.count - count)
            return Array(scrollManager.chartData[startIndex..<scrollManager.chartData.count])
        }

        // Filter data points that fall within the visible window (from scrollPosition to endDate)
        let visiblePoints = scrollManager.chartData.filter { point in
            point.date >= scrollPosition && point.date <= endDate
        }

        print("📊 Visible data: \(visiblePoints.count) points between \(scrollPosition) and \(endDate)")
        return visiblePoints.isEmpty ? Array(scrollManager.chartData.prefix(selectedPeriod.numberOfBars)) : visiblePoints
    }

    private func calculateAggregate() -> Double {
        // For 6M/Y periods when unselected, use daily SUM aggregations within visible range
        // This gives correct average: sum(all daily totals) / count(days with data)
        if selectedBarDate == nil {
            if selectedPeriod == .sixMonth || selectedPeriod == .year {
                if !dailySums.isEmpty {
                    let sum = dailySums.reduce(0, +)
                    let average = sum / Double(dailySums.count)
                    NSLog("[CHART] 📊 Calculated aggregate from %d daily SUMs: %.2f", dailySums.count, average)
                    return average
                }
                // If daily sums not yet loaded, return 0 (will show after fetch completes)
                return 0
            }
        }
        
        let visibleData = getVisibleData()
        guard !visibleData.isEmpty else { return 0 }
        let validData = visibleData.filter { $0.value > 0 }
        guard !validData.isEmpty else { return 0 }

        switch selectedPeriod {
        case .day:
            // Show TOTAL for the day (sum of all hourly values)
            return validData.reduce(0) { $0 + $1.value }
        case .week, .month:
            // Show DAILY AVERAGE (averages daily sums - already correct)
            let dailyAverages: [Double] = validData.map { getDisplayValue(for: $0.value) }
            let sum = dailyAverages.reduce(0, +)
            return sum / Double(dailyAverages.count)
        case .sixMonth, .year:
            // If bar is selected, show that bar's value (from weekly/monthly aggregation)
            // This case should not be reached when unselected (handled above)
            let dailyAverages: [Double] = validData.map { getDisplayValue(for: $0.value) }
            let sum = dailyAverages.reduce(0, +)
            return sum / Double(dailyAverages.count)
        }
    }
    
    private func fetchDailySumsForVisibleRange() async -> [Double] {
        // For 6M/Y unselected views, fetch daily SUM aggregations within visible date range
        // This gives correct average: sum(all daily totals) / count(days with data)
        do {
            let supabase = SupabaseManager.shared.client
            let userId = try await supabase.auth.session.user.id
            
            // Get the sample_quantity_type from display_views_dependencies
            struct JunctionResult: Codable {
                let sampleQuantityType: String?
                enum CodingKeys: String, CodingKey {
                    case sampleQuantityType = "sample_quantity_type"
                }
            }

            let junctionResults: [JunctionResult] = try await supabase
                .from("display_views_dependencies")
                .select("sample_quantity_type")
                .eq("view_id", value: metric.metricId)
                .eq("is_primary", value: true)
                .execute()
                .value

            guard let quantityType = junctionResults.first?.sampleQuantityType else {
                NSLog("[CHART] ❌ No sample_quantity_type found for metric=%@", metric.metricId)
                return []
            }
            
            // Calculate visible date range
            let calendar = Calendar.current
            let visibleDuration = getVisibleDomainTimeInterval()
            let startDate = scrollPosition
            guard let endDate = calendar.date(byAdding: .second, value: Int(visibleDuration), to: startDate) else {
                NSLog("[CHART] ⚠️ Could not calculate end date for visible range")
                return []
            }
            
            NSLog("[CHART] 📊 Fetching daily values for visible range: %@ to %@", startDate.description, endDate.description)

            // Fetch patient_quantity_samples within visible date range
            struct QuantitySample: Codable {
                let quantityValue: Double
                let startTime: Date
                enum CodingKeys: String, CodingKey {
                    case quantityValue = "quantity_value"
                    case startTime = "start_time"
                }
            }

            let samples: [QuantitySample] = try await supabase
                .from("patient_quantity_samples")
                .select("quantity_value, start_time")
                .eq("patient_id", value: userId)
                .eq("quantity_type", value: quantityType)
                .eq("is_primary", value: true)  // Only use primary samples for analysis
                .gte("start_time", value: startDate.ISO8601Format())
                .lte("start_time", value: endDate.ISO8601Format())
                .order("start_time", ascending: true)
                .execute()
                .value

            // Group by day and sum values
            var dailySums: [Date: Double] = [:]
            for sample in samples {
                let day = calendar.startOfDay(for: sample.startTime)
                dailySums[day, default: 0] += sample.quantityValue
            }

            // Extract daily sum values
            let values = dailySums.values.filter { $0 > 0 }

            NSLog("[CHART] ✅ Fetched %d daily sums from %d samples for visible range", values.count, samples.count)
            return Array(values)
            
        } catch {
            NSLog("[CHART] ❌ Error fetching daily SUMs: %@", error.localizedDescription)
            return []
        }
    }

    private func formatValue(_ value: Double) -> String {
        // Check if we should use hours_minutes formatting
        // Handle both "hours_minutes" unit and "minutes" unit (for sleep duration)
        // The ui_display from units_base might be "Minutes", "minutes", "Min", etc.
        let unitToCheck = (actualUnit ?? selectedUnit).lowercased().trimmingCharacters(in: .whitespaces)
        
        // Also check if this is a sleep duration metric (fallback if unit doesn't match)
        let isSleepDurationMetric = metric.metricId.contains("SLEEP_DURATION") || 
                                   metric.metricName.lowercased().contains("sleep duration")
        
        let isMinutesUnit = unitToCheck == "hours_minutes" || 
                           unitToCheck == "minutes" || 
                           unitToCheck == "min" || 
                           unitToCheck == "minute" ||
                           unitToCheck.hasPrefix("minute") ||
                           (isSleepDurationMetric && (unitToCheck.isEmpty || unitToCheck == "unit"))
        
        NSLog("[CHART] 📏 formatValue called: value=%f, actualUnit='%@', selectedUnit='%@', unitToCheck='%@', isMinutesUnit=%@, isSleepMetric=%@", 
              value, actualUnit ?? "nil", selectedUnit, unitToCheck, isMinutesUnit ? "YES" : "NO", isSleepDurationMetric ? "YES" : "NO")
        
        if isMinutesUnit {
            let formatted = formatMinutesAsHoursMinutes(value)
            NSLog("[CHART] 📏 formatValue: %f minutes → '%@' (using hours_minutes format)", value, formatted)
            return formatted
        }

        // Use NumberFormatter for proper formatting with thousand separators
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimalPlaces
        formatter.maximumFractionDigits = decimalPlaces
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true

        let formatted = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(decimalPlaces)f", value)
        NSLog("[CHART] 📏 formatValue: %f → '%@' (actualUnit: '%@', selectedUnit: '%@', decimalPlaces: %d)", value, formatted, actualUnit ?? "nil", selectedUnit, decimalPlaces)
        return formatted
    }

    private func formatMinutesAsHoursMinutes(_ minutes: Double) -> String {
        let totalMinutes = Int(minutes)
        
        // If less than 60 minutes, just show minutes
        if totalMinutes < 60 {
            return "\(totalMinutes)m"
        }
        
        // Otherwise show hours and minutes
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        return "\(hours)h \(mins)m"
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()

        switch selectedPeriod {
        case .day:
            // Show hour and minute (e.g., "2:00 PM")
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)

        case .week, .month:
            // Show specific date (e.g., "Jan 15, 2025")
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)

        case .sixMonth:
            // Show week range (e.g., "Dec 1 - Dec 7, 2025")
            formatter.dateFormat = "MMM d"
            let weekStart = formatter.string(from: date)

            if let weekEnd = calendar.date(byAdding: .day, value: 6, to: date) {
                formatter.dateFormat = "MMM d, yyyy"
                let weekEndStr = formatter.string(from: weekEnd)
                return "\(weekStart) - \(weekEndStr)"
            } else {
                formatter.dateFormat = "MMM d, yyyy"
                return formatter.string(from: date)
            }

        case .year:
            // Show month (e.g., "January 2025")
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }
    }

    private func visibleDateRangeString() -> String {
        let visibleData = getVisibleData()
        guard !visibleData.isEmpty else {
            print("📅 No visible data for date range")
            return ""
        }

        // Get the date range from the actual visible data
        let dates = visibleData.map { $0.date }
        guard let firstDate = dates.min(),
              let lastDate = dates.max() else {
            print("📅 Could not extract date range")
            return ""
        }

        let formatter = DateFormatter()
        let result: String

        switch selectedPeriod {
        case .day:
            formatter.dateFormat = "MMM d, h a"
            result = "\(formatter.string(from: firstDate)) - \(formatter.string(from: lastDate))"
        case .week:
            formatter.dateFormat = "MMM d"
            result = "\(formatter.string(from: firstDate)) - \(formatter.string(from: lastDate)), 2025"
        case .month:
            formatter.dateFormat = "MMM d"
            result = "\(formatter.string(from: firstDate)) - \(formatter.string(from: lastDate)), 2025"
        case .sixMonth:
            formatter.dateFormat = "MMM yyyy"
            result = "\(formatter.string(from: firstDate)) - \(formatter.string(from: lastDate))"
        case .year:
            formatter.dateFormat = "MMM yyyy"
            result = "\(formatter.string(from: firstDate)) - \(formatter.string(from: lastDate))"
        }

        print("📅 Date range: \(result) (from \(visibleData.count) visible points)")
        return result
    }
}

// MARK: - Preference Keys for Scroll Detection

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct LeadingEdgePreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct TrailingEdgePreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Parent Metric Detail View

struct ParentMetricDetailView: View {
    let metric: DisplayMetric
    let sections: [ParentDetailSection]
    let sectionChildren: [String: [DisplayMetric]]
    let pillar: String
    let color: Color

    @State private var showingChildMetrics = false

    var body: some View {
        VStack(spacing: 0) {
            // Parent metric chart - use ParentMetricBarChart for bar charts, ChartTypeFactory for others
            let chartType = metric.chartTypeId?.lowercased() ?? "bar_vertical"
            if chartType == "bar_vertical" || chartType == "bar_horizontal" {
                ParentMetricBarChart(metric: metric, color: color)
            } else {
                ChartTypeFactory.createChart(
                    metricName: metric.metricName,
                    chartType: metric.chartTypeId,
                    color: color
                )
            }

            // Show more button
            if !sections.isEmpty {
                Button(action: {
                    showingChildMetrics = true
                }) {
                    HStack {
                        Text("Show More Data")
                            .font(.body)
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .padding()
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 16)
            }

            // About section - removed for new simplified DisplayMetric model
            // Educational content should be added to custom Primary/Detail views
        }
        .sheet(isPresented: $showingChildMetrics) {
            DetailChildMetricsSheet(
                parentMetricName: metric.metricName,
                sections: sections,
                sectionChildren: sectionChildren,
                pillar: pillar,
                color: color
            )
        }
    }
}

// MARK: - About Section Item

struct DetailAboutItem: View {
    let title: String
    let content: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal)
    }
}

// MARK: - Child Metrics Sheet

struct DetailChildMetricsSheet: View {
    let parentMetricName: String
    let sections: [ParentDetailSection]
    let sectionChildren: [String: [DisplayMetric]]
    let pillar: String
    let color: Color

    @Environment(\.dismiss) var dismiss
    @State private var selectedSectionIndex: Int

    init(parentMetricName: String, sections: [ParentDetailSection], sectionChildren: [String: [DisplayMetric]], pillar: String, color: Color) {
        self.parentMetricName = parentMetricName
        self.sections = sections
        self.sectionChildren = sectionChildren
        self.pillar = pillar
        self.color = color

        // Find default tab or use first section
        let defaultIndex = sections.firstIndex(where: { $0.isDefaultTab }) ?? 0
        _selectedSectionIndex = State(initialValue: defaultIndex)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Horizontal tab bar
                HorizontalTabBar(
                    sections: sections,
                    selectedIndex: $selectedSectionIndex,
                    color: color
                )
                .padding(.top, 8)

                // Paginated TabView for sections
                TabView(selection: $selectedSectionIndex) {
                    ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                        SectionChartView(
                            section: section,
                            children: sectionChildren[section.sectionId] ?? [],
                            color: color
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle(parentMetricName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Horizontal Tab Bar

struct HorizontalTabBar: View {
    let sections: [ParentDetailSection]
    @Binding var selectedIndex: Int
    let color: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                    TabButton(
                        title: section.sectionName,
                        icon: section.sectionIcon,
                        isSelected: selectedIndex == index,
                        color: color
                    ) {
                        withAnimation {
                            selectedIndex = index
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 50)
    }
}

struct TabButton: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? color.opacity(0.15) : Color(uiColor: .systemGray6))
            )
            .foregroundColor(isSelected ? color : .secondary)
        }
    }
}

// MARK: - Section Chart View

struct SectionChartView: View {
    let section: ParentDetailSection
    let children: [DisplayMetric]
    let color: Color

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Section description if available
                if let description = section.sectionDescription {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top)
                }

                // Chart placeholder
                VStack(spacing: 16) {
                    Text("Chart Type: \(section.sectionChartTypeId)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Mock chart visualization
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.1))
                        .frame(height: 300)
                        .overlay(
                            VStack {
                                Image(systemName: getChartIcon(for: section.sectionChartTypeId))
                                    .font(.system(size: 48))
                                    .foregroundColor(color.opacity(0.5))
                                Text("ONE chart with \(children.count) data series")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        )
                        .padding(.horizontal)
                }

                // Data series summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Data Series (\(children.count))")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(children) { child in
                        HStack {
                            Circle()
                                .fill(color)
                                .frame(width: 8, height: 8)
                            Text(child.metricName)
                                .font(.subheadline)
                            Spacer()
                            // Unit info removed - not in simplified DisplayMetric model
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func getChartIcon(for chartType: String) -> String {
        switch chartType.lowercased() {
        case "bar_vertical":
            return "chart.bar.fill"
        case "bar_horizontal":
            return "chart.bar.xaxis"
        case "bar_stacked":
            return "chart.bar.fill"
        case "comparison_view":
            return "chart.bar.xaxis"
        case "trend_line":
            return "chart.line.uptrend.xyaxis"
        case "sleep_stages_horizontal":
            return "bed.double.fill"
        default:
            return "chart.bar.fill"
        }
    }
}

struct ChildMetricRow: View {
    let metric: DisplayMetric
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
                    .frame(width: 60, height: 40)

                Image(systemName: getChartIcon(for: metric.chartTypeId))
                    .font(.caption)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(metric.metricName)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                // Unit info removed - not in simplified DisplayMetric model
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private func getChartIcon(for chartType: String?) -> String {
        guard let type = chartType else { return "chart.bar.fill" }

        switch type.lowercased() {
        case "trend_line":
            return "chart.line.uptrend.xyaxis"
        case "bar_vertical":
            return "chart.bar.fill"
        case "progress_bar":
            return "chart.bar.xaxis"
        default:
            return "chart.bar.fill"
        }
    }
}

// MARK: - Database Response Structs

struct ParentDisplayMetricResponse: Codable {
    let id: String
    let parentMetricId: String
    let parentName: String
    let parentDescription: String?
    let pillar: String?
    let supportedUnits: [String]?
    let defaultUnit: String?
    let chartTypeId: String?
    let supportedPeriods: [String]?
    let defaultPeriod: String?
    let displayUnit: String?
    let widgetType: String?
    let displayOrder: Int?
    let aboutWhat: String?
    let aboutWhy: String?
    let aboutOptimalTarget: String?
    let aboutQuickTips: String?

    enum CodingKeys: String, CodingKey {
        case id
        case parentMetricId = "parent_metric_id"
        case parentName = "parent_name"
        case parentDescription = "parent_description"
        case pillar
        case supportedUnits = "supported_units"
        case defaultUnit = "default_unit"
        case chartTypeId = "chart_type_id"
        case supportedPeriods = "supported_periods"
        case defaultPeriod = "default_period"
        case displayUnit = "display_unit"
        case widgetType = "widget_type"
        case displayOrder = "display_order"
        case aboutWhat = "about_what"
        case aboutWhy = "about_why"
        case aboutOptimalTarget = "about_optimal_target"
        case aboutQuickTips = "about_quick_tips"
    }

    func toDisplayMetric() -> DisplayMetric {
        return DisplayMetric(
            id: id,
            metricId: parentMetricId,
            metricName: parentName,
            description: parentDescription,
            pillar: pillar,
            chartTypeId: chartTypeId,
            isActive: true,
            aboutContent: nil,
            longevityImpact: nil,
            quickTips: nil
        )
    }
}

struct ChildDisplayMetricResponse: Codable {
    let id: String
    let childMetricId: String
    let childName: String
    let parentMetricId: String
    let sectionId: String?
    let dataSeriesOrder: Int?
    let chartLabelOrder: Int?
    let supportedUnits: [String]?
    let inheritParentUnit: Bool?
    let displayUnit: String?
    let widgetType: String?

    enum CodingKeys: String, CodingKey {
        case id
        case childMetricId = "child_metric_id"
        case childName = "child_name"
        case parentMetricId = "parent_metric_id"
        case sectionId = "section_id"
        case dataSeriesOrder = "data_series_order"
        case chartLabelOrder = "chart_label_order"
        case supportedUnits = "supported_units"
        case inheritParentUnit = "inherit_parent_unit"
        case displayUnit = "display_unit"
        case widgetType = "widget_type"
    }

    func toDisplayMetric() -> DisplayMetric {
        return DisplayMetric(
            id: id,
            metricId: childMetricId,
            metricName: childName,
            description: nil,
            pillar: nil,
            chartTypeId: nil,
            isActive: true,
            aboutContent: nil,
            longevityImpact: nil,
            quickTips: nil
        )
    }
}

// MARK: - ViewModel

@MainActor
class MetricDetailViewModel: ObservableObject {
    @Published var parentMetric: DisplayMetric?
    @Published var sections: [ParentDetailSection] = []
    @Published var sectionChildren: [String: [DisplayMetric]] = [:]
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    func loadMetrics(forScreen screenId: String) async {
        isLoading = true
        error = nil

        do {
            // Query display_screens_display_metrics directly using screen_id
            let links: [ScreenMetricLink] = try await supabase
                .from("display_screens_display_metrics")
                .select()
                .eq("screen_id", value: screenId)
                .order("display_order", ascending: true)
                .execute()
                .value

            print("📊 Found \(links.count) metric links for screen_id \(screenId)")

            let metricIds = links.map { $0.metricId }

            // Step 2: Query display_views table
            let fetchedMetrics: [DisplayMetric] = try await supabase
                .from("display_views")
                .select()
                .in("view_id", values: metricIds)
                .eq("is_active", value: true)
                .execute()
                .value

            print("📊 Found \(fetchedMetrics.count) display views")

            // Step 3: Sort by the order from junction table
            let sortedMetrics = metricIds.compactMap { metricId in
                fetchedMetrics.first { $0.metricId == metricId }
            }

            // Step 4: Use the first metric
            if let first = sortedMetrics.first {
                parentMetric = first
                print("✅ Using first metric: \(first.metricName)")
                // Note: Detail sections are not used in current schema
                // await loadSections(forParent: first.metricId)
            } else {
                print("⚠️ No display metrics found")
            }

        } catch {
            print("❌ Error loading metrics: \(error)")
            self.error = "Failed to load metrics: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func loadSections(forParent parentMetricId: String) async {
        do {
            // Query parent_detail_sections (tabs in modal)
            let fetchedSections: [ParentDetailSection] = try await supabase
                .from("parent_detail_sections")
                .select()
                .eq("parent_metric_id", value: parentMetricId)
                .eq("is_active", value: true)
                .order("display_order", ascending: true)
                .execute()
                .value

            print("📊 Found \(fetchedSections.count) sections for parent \(parentMetricId)")
            sections = fetchedSections

            // Query child_display_metrics (data series) for each section
            for section in sections {
                let childResponses: [ChildDisplayMetricResponse] = try await supabase
                    .from("child_display_metrics")
                    .select("""
                        id,
                        child_metric_id,
                        child_name,
                        parent_metric_id,
                        section_id,
                        data_series_order,
                        chart_label_order,
                        supported_units,
                        inherit_parent_unit,
                        display_unit,
                        widget_type
                    """)
                    .eq("section_id", value: section.sectionId)
                    .eq("is_active", value: true)
                    .order("data_series_order", ascending: true)
                    .execute()
                    .value

                let children = childResponses.map { $0.toDisplayMetric() }
                print("📊 Found \(children.count) data series for section \(section.sectionName)")
                sectionChildren[section.sectionId] = children
            }
        } catch {
            print("❌ Error loading sections: \(error)")
            self.error = "Failed to load sections: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MetricDetailView(
            screen: DisplayScreen(
                id: "1",
                screenId: "SCREEN_PROTEIN",
                name: "Protein",
                overview: "Track your protein intake",
                pillar: "Healthful Nutrition",
                displayOrder: 1,
                isActive: true
            ),
            pillar: "Healthful Nutrition"
        )
    }
}