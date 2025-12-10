//
//  MealTimingStackedChart.swift
//  WellPath
//
//  Recreated using ParentMetricBarChart as foundation
//  Dynamic stacked bar chart for meal-based protein distribution
//

import SwiftUI
import Charts

struct MealTimingStackedChart: View {
    let color: Color

    @State private var selectedPeriod: TimePeriod = .week
    @State private var selectedBarDate: Date?
    @State private var selectedMeal: String?
    @State private var scrollPosition: Date
    @State private var showPercentage: Bool = false
    @StateObject private var viewModel: MealTimingViewModel

    init(color: Color) {
        self.color = color

        // Initialize scroll position so TODAY is ~90% across the visible window (leaving 10% for future)
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
        _viewModel = StateObject(wrappedValue: MealTimingViewModel(baseColor: color))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.mealAggregations.isEmpty && !viewModel.isLoading {
                Text("No meal timing data available")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(height: 300)
            } else if !viewModel.isLoading {
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
                    selectedBarDate = nil
                    selectedMeal = nil

                    // Reset scroll position so TODAY is ~90% across the visible window (leaving 10% for future)
                    let now = Date()
                    let visibleDuration = newPeriod.numberOfBars
                    let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
                    scrollPosition = Calendar.current.date(
                        byAdding: newPeriod.calendarComponent,
                        value: -offsetFromEnd,
                        to: now
                    ) ?? now

                    print("📊 MEAL TIMING: Set scrollPosition=\(scrollPosition) for period=\(newPeriod)")

                    Task {
                        await viewModel.loadData(for: newPeriod)
                    }
                }

                // Stacked bar chart
                Chart {
                    ForEach(viewModel.chartData) { dateData in
                        ForEach(dateData.mealValues) { mealValue in
                            let opacity: Double = {
                                if selectedMeal == nil {
                                    return 1.0
                                } else if selectedMeal == mealValue.mealName {
                                    return 1.0
                                } else {
                                    return 0.25
                                }
                            }()

                            BarMark(
                                x: .value("Time", dateData.date),
                                y: .value("Grams", getDisplayValue(for: mealValue.value)),
                                width: .fixed(getBarWidth())
                            )
                            .foregroundStyle(mealValue.color.opacity(opacity))
                        }
                    }
                }
                .frame(height: 280)
                .chartScrollableAxes(.horizontal)
                .chartScrollPosition(x: $scrollPosition)
                .chartXVisibleDomain(length: getVisibleDomainTimeInterval())
                .chartGesture { proxy in
                    SpatialTapGesture()
                        .onEnded { value in
                            if let tappedDate: Date = proxy.value(atX: value.location.x) {
                                let closest = viewModel.chartData.min(by: {
                                    abs($0.date.timeIntervalSince(tappedDate)) < abs($1.date.timeIntervalSince(tappedDate))
                                })

                                if selectedBarDate == closest?.date {
                                    selectedBarDate = nil
                                } else {
                                    selectedBarDate = closest?.date
                                }
                            }
                        }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: getAxisLabelStride(), count: getAxisLabelMultiplier())) { value in
                        if value.as(Date.self) != nil {
                            AxisValueLabel(format: getAxisLabelFormat())
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
                .padding(.top, 16)
                .padding(.bottom, 24)

                // Scrollable meal averages list
                ScrollView {
                    // Grams/% toggle
                    HStack {
                        Spacer()
                        Picker("Unit", selection: $showPercentage) {
                            Text("Grams").tag(false)
                            Text("%").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                    VStack(spacing: 8) {
                        ForEach(viewModel.mealAggregations) { meal in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if selectedMeal == meal.displayName {
                                        selectedMeal = nil
                                    } else {
                                        selectedMeal = meal.displayName
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(meal.color)
                                        .frame(width: 12, height: 12)

                                    Text(meal.displayName)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    if showPercentage {
                                        let percentage = viewModel.getPercentageFor(
                                            meal.aggId,
                                            period: selectedPeriod,
                                            scrollPosition: scrollPosition
                                        )
                                        Text(String(format: "%.0f%%", percentage))
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                    } else {
                                        let average = viewModel.getAverageFor(
                                            meal.aggId,
                                            period: selectedPeriod,
                                            scrollPosition: scrollPosition
                                        )
                                        Text(formatValue(average))
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)

                                        Text("g")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedMeal == meal.displayName ? meal.color.opacity(0.15) : Color(uiColor: .secondarySystemGroupedBackground))
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(uiColor: .systemGroupedBackground))
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .task {
            await viewModel.discoverMealAggregations()
            await viewModel.loadData(for: selectedPeriod)

            // Set scroll position after initial load
            let now = Date()
            let visibleDuration = selectedPeriod.numberOfBars
            let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
            scrollPosition = Calendar.current.date(
                byAdding: selectedPeriod.calendarComponent,
                value: -offsetFromEnd,
                to: now
            ) ?? now
            print("📊 MEAL TIMING: Initial scrollPosition=\(scrollPosition)")
        }
    }

    // MARK: - Helpers (EXACT ParentMetricBarChart pattern)

    private func getDisplayValue(for rawValue: Double) -> Double {
        switch selectedPeriod {
        case .day, .week, .month:
            return rawValue
        case .sixMonth:
            return rawValue / 7.0
        case .year:
            return rawValue / 30.0
        }
    }

    private func getBarWidth() -> CGFloat {
        switch selectedPeriod {
        case .day: return 10
        case .week: return 35
        case .month: return 8
        case .sixMonth: return 10
        case .year: return 22
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
        case .sixMonth: return .month
        case .year: return .month
        }
    }

    private func getAxisLabelMultiplier() -> Int {
        switch selectedPeriod {
        case .day: return 6
        case .week: return 1
        case .month: return 1
        case .sixMonth: return 1
        case .year: return 1
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

    private func formatValue(_ value: Double) -> String {
        if value == 0 {
            return "0"
        } else if value >= 100 {
            return String(format: "%.0f", value)
        } else if value >= 10 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

// MARK: - ViewModel

/// Raw protein sample from patient_quantity_samples
private struct MealProteinSampleRow: Codable {
    let quantityValue: Double?
    let startTime: Date
    let aggregationDateString: String?
    let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case quantityValue = "quantity_value"
        case startTime = "start_time"
        case aggregationDateString = "aggregation_date"
        case metadata
    }

    /// Parse aggregation_date as a local date (noon to avoid DST issues)
    /// The database DATE represents a calendar day, not a UTC timestamp
    var aggregationDate: Date? {
        guard let dateString = aggregationDateString else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone.current  // Parse as local time, not UTC
        return formatter.date(from: dateString + " 12:00")  // Noon local to avoid DST edge cases
    }
}

@MainActor
class MealTimingViewModel: ObservableObject {
    @Published var mealAggregations: [MealAggregation] = []
    @Published var chartData: [MealStackedData] = []
    @Published var isLoading = false
    @Published var periodData: [String: Double] = [:] // For period-specific queries

    private var mealDataCache: [String: [ChartDataPoint]] = [:]
    let supabase = SupabaseManager.shared.client // Internal access for extensions
    private let baseColor: Color

    // Fixed list of meal types from metadata
    private let mealTypeKeys = [
        "breakfast",
        "morning_snack",
        "lunch",
        "afternoon_snack",
        "dinner",
        "evening_snack",
        "other",
        "unassigned"
    ]

    private let mealDisplayNames: [String: String] = [
        "breakfast": "Breakfast",
        "morning_snack": "Morning Snack",
        "lunch": "Lunch",
        "afternoon_snack": "Afternoon Snack",
        "dinner": "Dinner",
        "evening_snack": "Evening Snack",
        "other": "Other",
        "unassigned": "Unassigned"
    ]

    init(baseColor: Color) {
        self.baseColor = baseColor
    }

    func discoverMealAggregations() async {
        // Build meal aggregations from fixed list instead of querying database
        let colorCount = Double(mealTypeKeys.count)

        mealAggregations = mealTypeKeys.enumerated().map { index, mealKey in
            let isOther = mealKey == "other"
            let isUnassigned = mealKey == "unassigned"

            let progress = colorCount > 1 ? Double(index) / (colorCount - 1) : 0
            let opacity = 0.55 + (progress * 0.45)

            let displayName = mealDisplayNames[mealKey] ?? mealKey.capitalized.replacingOccurrences(of: "_", with: " ")
            let color: Color

            if isOther {
                color = Color(red: 0.9, green: 0.9, blue: 0.9)
            } else if isUnassigned {
                color = Color(red: 0.85, green: 0.85, blue: 0.85)
            } else {
                color = baseColor.opacity(opacity)
            }

            return MealAggregation(
                aggId: mealKey,  // Use meal_type key as ID
                displayName: displayName,
                color: color
            )
        }

        print("🍽️ Configured \(mealAggregations.count) meal types")
    }

    /// Load chart data from patient_quantity_samples with meal_type metadata
    func loadData(for period: TimePeriod) async {
        isLoading = true
        mealDataCache.removeAll()

        do {
            let userId = try await supabase.auth.session.user.id
            let calendar = Calendar.current

            // Calculate date range for query
            let now = Date()
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

            // Fetch all protein samples with metadata
            let results: [MealProteinSampleRow] = try await supabase
                .from("patient_quantity_samples")
                .select("quantity_value, start_time, aggregation_date, metadata")
                .eq("patient_id", value: userId)
                .eq("quantity_type", value: "protein_grams")
                .eq("is_primary", value: true)  // Only use primary samples for analysis
                .gte("start_time", value: oldestDate.ISO8601Format())
                .lte("start_time", value: newestDate.ISO8601Format())
                .order("start_time", ascending: true)
                .execute()
                .value

            print("🍽️ Fetched \(results.count) protein samples for range \(oldestDate) to \(newestDate)")

            // Group by meal_type from metadata
            for sample in results {
                guard let value = sample.quantityValue, value > 0 else { continue }

                // Get meal_type from metadata (default to "unassigned")
                let mealType = sample.metadata?["meal_type"] ?? "unassigned"

                // For day view, use hour granularity; otherwise use aggregation_date or start of day
                let groupDate: Date
                if period == .day {
                    let components = calendar.dateComponents([.year, .month, .day, .hour], from: sample.startTime)
                    groupDate = calendar.date(from: components) ?? sample.startTime
                } else {
                    groupDate = sample.aggregationDate ?? calendar.startOfDay(for: sample.startTime)
                }

                if mealDataCache[mealType] == nil {
                    mealDataCache[mealType] = []
                }

                // Find existing point for this date or create new one
                if let existingIndex = mealDataCache[mealType]?.firstIndex(where: {
                    calendar.isDate($0.date, equalTo: groupDate, toGranularity: period == .day ? .hour : .day)
                }) {
                    let existing = mealDataCache[mealType]![existingIndex]
                    let newPoint = ChartDataPoint(date: existing.date, value: existing.value + value, label: existing.label)
                    mealDataCache[mealType]?[existingIndex] = newPoint
                } else {
                    mealDataCache[mealType]?.append(ChartDataPoint(date: groupDate, value: value, label: ""))
                }
            }

            // Build stacked chart data
            buildChartData(for: period)

        } catch {
            print("❌ Error loading meal data: \(error)")
        }

        isLoading = false
    }

    private func buildChartData(for period: TimePeriod) {
        let now = Date()
        let calendar = Calendar.current

        // Extend into future by 1 month
        let newestDate = calendar.date(byAdding: .month, value: 1, to: now) ?? now

        // Calculate oldest date based on period
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

        // Generate complete timeline
        var timeline: [MealStackedData] = []
        var currentDate = oldestDate
        let granularity = getDateGranularity(for: period)

        while currentDate <= newestDate {
            let barDate: Date
            if period == .year {
                var components = calendar.dateComponents([.year, .month], from: currentDate)
                components.day = 15
                barDate = calendar.date(from: components) ?? currentDate
            } else {
                barDate = currentDate
            }

            // Build meal values for this date
            let mealValues = mealAggregations.map { meal in
                let value = mealDataCache[meal.aggId]?.first(where: {
                    calendar.isDate($0.date, equalTo: barDate, toGranularity: granularity)
                })?.value ?? 0

                return MealValue(
                    mealName: meal.displayName,
                    value: value,
                    color: meal.color
                )
            }

            timeline.append(MealStackedData(date: barDate, mealValues: mealValues))

            guard let nextDate = calendar.date(byAdding: period.calendarComponent, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        chartData = timeline
        let dataCount = timeline.filter { $0.mealValues.contains(where: { $0.value > 0 }) }.count
        print("🍽️ Generated \(timeline.count) timeline points (\(dataCount) with data)")
    }

    private func getDateGranularity(for period: TimePeriod) -> Calendar.Component {
        switch period {
        case .day: return .hour
        case .week, .month: return .day
        case .sixMonth: return .weekOfYear
        case .year: return .month
        }
    }

    func getAverageFor(_ mealKey: String, period: TimePeriod, scrollPosition: Date) -> Double {
        guard let points = mealDataCache[mealKey] else { return 0 }

        let visibleDuration = getVisibleDomainTimeInterval(for: period)
        guard let endDate = Calendar.current.date(byAdding: .second, value: Int(visibleDuration), to: scrollPosition) else {
            return 0
        }

        let visiblePoints = points.filter { point in
            point.date >= scrollPosition && point.date <= endDate
        }

        // Calculate sum including zeros (missing data points count as 0)
        let sum = visiblePoints.map { convertToDisplayValue($0.value, for: period) }.reduce(0, +)

        switch period {
        case .day:
            // Day view: Sum all hourly values to get daily TOTAL
            return sum
        case .week, .month, .sixMonth, .year:
            // Other views: Calculate daily AVERAGE including nulls
            let expectedCount = period.numberOfBars
            return sum / Double(expectedCount)
        }
    }

    func getPercentageFor(_ mealKey: String, period: TimePeriod, scrollPosition: Date) -> Double {
        let mealAverage = getAverageFor(mealKey, period: period, scrollPosition: scrollPosition)

        // Calculate total across all meals
        let totalAverage = mealAggregations.reduce(0.0) { sum, meal in
            sum + getAverageFor(meal.aggId, period: period, scrollPosition: scrollPosition)
        }

        guard totalAverage > 0 else { return 0 }
        return (mealAverage / totalAverage) * 100
    }

    private func convertToDisplayValue(_ rawValue: Double, for period: TimePeriod) -> Double {
        switch period {
        case .day, .week, .month:
            return rawValue
        case .sixMonth:
            return rawValue / 7.0
        case .year:
            return rawValue / 30.0
        }
    }

    private func getVisibleDomainTimeInterval(for period: TimePeriod) -> TimeInterval {
        switch period {
        case .day: return 24 * 3600
        case .week: return 7 * 24 * 3600
        case .month: return 30 * 24 * 3600
        case .sixMonth: return 26 * 7 * 24 * 3600
        case .year: return 365 * 24 * 3600
        }
    }
}

// MARK: - Data Models

struct MealAggregation: Identifiable {
    let id = UUID()
    let aggId: String
    let displayName: String
    let color: Color
}

struct MealStackedData: Identifiable {
    let id = UUID()
    let date: Date
    let mealValues: [MealValue]
}

struct MealValue: Identifiable {
    let id = UUID()
    let mealName: String
    let value: Double
    let color: Color
}

#Preview {
    MealTimingStackedChart(color: MetricsUIConfig.getPillarColor(for: "Healthful Nutrition"))
}
