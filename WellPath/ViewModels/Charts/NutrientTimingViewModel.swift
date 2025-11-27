//
//  NutrientTimingViewModel.swift
//  WellPath
//
//  Generic ViewModel for meal timing across all nutrients
//  Supports protein (grams) and other nutrients (servings)
//

import SwiftUI

/// Defines a nutrient type for timing analysis
enum NutrientTimingType: String, CaseIterable {
    case protein = "PROTEIN"
    case legumes = "LEGUMES"
    case vegetables = "VEGETABLES"
    case wholeGrains = "WHOLE_GRAINS"
    case fruits = "FRUITS"

    /// The unit suffix used in aggregation IDs
    var unitSuffix: String {
        switch self {
        case .protein:
            return "GRAMS"
        default:
            return "SERVINGS"
        }
    }

    /// Display label for the unit
    var unitLabel: String {
        switch self {
        case .protein:
            return "g"
        default:
            return "servings"
        }
    }

    /// Full unit name for display
    var unitName: String {
        switch self {
        case .protein:
            return "grams"
        default:
            return "servings"
        }
    }

    /// Display name for the nutrient (used in UI)
    var displayName: String {
        switch self {
        case .protein:
            return "Protein"
        case .legumes:
            return "Legumes"
        case .vegetables:
            return "Vegetables"
        case .wholeGrains:
            return "Whole Grains"
        case .fruits:
            return "Fruits"
        }
    }

    /// Builds the aggregation ID prefix for timing queries
    var aggIdPrefix: String {
        return "AGG_\(rawValue)_"
    }
}

@MainActor
class NutrientTimingViewModel: ObservableObject {
    @Published var mealAggregations: [MealAggregation] = []
    @Published var chartData: [MealStackedData] = []
    @Published var isLoading = false
    @Published var periodData: [String: Double] = [:]

    private var mealDataCache: [String: [ChartDataPoint]] = [:]
    let supabase = SupabaseManager.shared.client
    private let baseColor: Color
    private let nutrientType: NutrientTimingType

    init(nutrientType: NutrientTimingType, baseColor: Color) {
        self.nutrientType = nutrientType
        self.baseColor = baseColor
    }

    /// Discovers meal timing aggregations for this nutrient type
    func discoverMealAggregations() async {
        do {
            struct AggMetric: Codable {
                let aggId: String
                let metricName: String
                let displayName: String

                enum CodingKeys: String, CodingKey {
                    case aggId = "agg_id"
                    case metricName = "metric_name"
                    case displayName = "display_name"
                }
            }

            // Build query based on nutrient type
            let mealTypes = ["BREAKFAST", "LUNCH", "DINNER", "MORNING_SNACK", "AFTERNOON_SNACK", "EVENING_SNACK", "OTHER"]
            let aggIds = mealTypes.map { "AGG_\(nutrientType.rawValue)_\($0)_\(nutrientType.unitSuffix)" }

            let results: [AggMetric] = try await supabase
                .from("aggregation_metrics")
                .select("agg_id, metric_name, display_name")
                .in("agg_id", values: aggIds)
                .execute()
                .value

            print("🍽️ Discovered \(results.count) meal aggregations for \(nutrientType.displayName)")

            // Sort meals chronologically
            let mealOrder: [String: Int] = [
                "Breakfast": 1,
                "Morning Snack": 2,
                "Lunch": 3,
                "Afternoon Snack": 4,
                "Dinner": 5,
                "Evening Snack": 6,
                "Other": 98,
                "Other Timing": 98
            ]

            let colorCount = Double(results.count)
            mealAggregations = results.enumerated().sorted(by: {
                // Extract meal name by removing nutrient suffix
                let name1 = cleanMealName($0.element.displayName)
                let name2 = cleanMealName($1.element.displayName)
                let order1 = mealOrder[name1] ?? 99
                let order2 = mealOrder[name2] ?? 99
                return order1 < order2
            }).map { index, agg in
                let isOther = agg.aggId.contains("_OTHER_")

                let progress = colorCount > 1 ? Double(index) / (colorCount - 1) : 0
                let opacity = 0.55 + (progress * 0.45)

                let cleanName = cleanMealName(agg.displayName)
                let color: Color

                if isOther {
                    color = Color(red: 0.9, green: 0.9, blue: 0.9)
                } else {
                    color = baseColor.opacity(opacity)
                }

                return MealAggregation(
                    aggId: agg.aggId,
                    displayName: cleanName,
                    color: color
                )
            }

        } catch {
            print("❌ Error discovering meal aggregations: \(error)")
        }
    }

    /// Cleans the display name by removing nutrient suffix
    private func cleanMealName(_ displayName: String) -> String {
        // Remove nutrient name from display (e.g., "Breakfast Legumes" -> "Breakfast")
        var name = displayName
        for nutrient in NutrientTimingType.allCases {
            name = name.replacingOccurrences(of: " \(nutrient.displayName)", with: "")
        }
        // Handle "Other Timing" -> "Other"
        name = name.replacingOccurrences(of: "Other Timing", with: "Other")
        return name.trimmingCharacters(in: .whitespaces)
    }

    /// Loads data for a specific period and date
    func loadDataForPeriod(period: TimePeriod, date: Date) async {
        isLoading = true
        periodData.removeAll()

        do {
            let userId = try await supabase.auth.session.user.id

            // Map to aggregated period type (not bar chart granularity)
            // Calendar views can query aggregated periods directly
            let periodType: String
            switch period {
            case .day: periodType = "daily"
            case .week: periodType = "weekly"
            case .month: periodType = "monthly"
            case .sixMonth: periodType = "six_month"
            case .year: periodType = "yearly"
            }

            let aggIds = mealAggregations.map { $0.aggId }

            // Calculate period start for calendar period
            let periodStart = getPeriodStart(for: period, date: date)
            let iso8601String = periodStart.ISO8601Format()

            print("🍽️ Querying \(nutrientType.displayName) timing for period: \(periodType)")
            print("🍽️   Period start (UTC): \(periodStart)")
            print("🍽️   ISO8601 string: \(iso8601String)")

            // For Day: use SUM (daily total)
            // For Week/Month/Year: use AVG (average per day) - backend already calculates this
            let calculationType = period == .day ? "SUM" : "AVG"

            // Fetch data for the specific calendar period
            let results: [AggregationResult] = try await supabase
                .from("aggregation_results_cache")
                .select()
                .eq("patient_id", value: userId)
                .in("agg_metric_id", values: aggIds)
                .eq("period_type", value: periodType)
                .eq("calculation_type_id", value: calculationType)
                .eq("period_start", value: iso8601String)
                .execute()
                .value

            print("🍽️ Fetched \(results.count) data points for \(nutrientType.displayName) timing")

            // Store results directly - backend already computed averages for non-day periods
            var totalValue: Double = 0
            for result in results {
                periodData[result.aggMetricId] = result.value
                totalValue += result.value
            }

            // Calculate avg per meal
            let mealCount = results.filter { $0.value > 0 }.count
            periodData["avg_per_meal"] = mealCount > 0 ? totalValue / Double(mealCount) : 0
            periodData["entries_count"] = Double(results.count)

        } catch {
            print("❌ Error loading period data: \(error)")
        }

        isLoading = false
    }

    // MARK: - Period Calculation Helpers

    private func getPeriodStart(for period: TimePeriod, date: Date) -> Date {
        let calendar = Calendar.current
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        switch period {
        case .day:
            let localComponents = calendar.dateComponents([.year, .month, .day], from: date)
            var utcComponents = DateComponents()
            utcComponents.year = localComponents.year
            utcComponents.month = localComponents.month
            utcComponents.day = localComponents.day
            utcComponents.hour = 0
            utcComponents.minute = 0
            utcComponents.second = 0
            utcComponents.timeZone = TimeZone(identifier: "UTC")
            return utcCalendar.date(from: utcComponents)!

        case .week:
            let localComponents = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
            let weekday = localComponents.weekday!
            let daysFromMonday = (weekday == 1) ? -6 : (2 - weekday)
            let localMonday = calendar.date(byAdding: .day, value: daysFromMonday, to: date)!
            let mondayComponents = calendar.dateComponents([.year, .month, .day], from: localMonday)

            var utcComponents = DateComponents()
            utcComponents.year = mondayComponents.year
            utcComponents.month = mondayComponents.month
            utcComponents.day = mondayComponents.day
            utcComponents.hour = 0
            utcComponents.minute = 0
            utcComponents.second = 0
            utcComponents.timeZone = TimeZone(identifier: "UTC")
            return utcCalendar.date(from: utcComponents)!

        case .month:
            let localComponents = calendar.dateComponents([.year, .month], from: date)
            var utcComponents = DateComponents()
            utcComponents.year = localComponents.year
            utcComponents.month = localComponents.month
            utcComponents.day = 1
            utcComponents.hour = 0
            utcComponents.minute = 0
            utcComponents.second = 0
            utcComponents.timeZone = TimeZone(identifier: "UTC")
            return utcCalendar.date(from: utcComponents)!

        case .sixMonth:
            let localComponents = calendar.dateComponents([.year, .month], from: date)
            let year = localComponents.year!
            let month = localComponents.month!
            let startMonth = month <= 6 ? 1 : 7

            var utcComponents = DateComponents()
            utcComponents.year = year
            utcComponents.month = startMonth
            utcComponents.day = 1
            utcComponents.hour = 0
            utcComponents.minute = 0
            utcComponents.second = 0
            utcComponents.timeZone = TimeZone(identifier: "UTC")
            return utcCalendar.date(from: utcComponents)!

        case .year:
            let localComponents = calendar.dateComponents([.year], from: date)
            var utcComponents = DateComponents()
            utcComponents.year = localComponents.year
            utcComponents.month = 1
            utcComponents.day = 1
            utcComponents.hour = 0
            utcComponents.minute = 0
            utcComponents.second = 0
            utcComponents.timeZone = TimeZone(identifier: "UTC")
            return utcCalendar.date(from: utcComponents)!
        }
    }

    /// Loads chart data for stacked bar visualization
    func loadData(for period: TimePeriod) async {
        isLoading = true
        mealDataCache.removeAll()

        do {
            let userId = try await supabase.auth.session.user.id
            let periodType = period.databasePeriodType
            let aggIds = mealAggregations.map { $0.aggId }

            // Calculate date range
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

            // Fetch data
            let results: [AggregationResult] = try await supabase
                .from("aggregation_results_cache")
                .select()
                .eq("patient_id", value: userId)
                .in("agg_metric_id", values: aggIds)
                .eq("period_type", value: periodType)
                .eq("calculation_type_id", value: "SUM")
                .gte("period_start", value: oldestDate.ISO8601Format())
                .lte("period_start", value: newestDate.ISO8601Format())
                .order("period_start", ascending: true)
                .execute()
                .value

            print("🍽️ Fetched \(results.count) chart data points for \(nutrientType.displayName)")

            // Group by agg_metric_id
            for result in results {
                if mealDataCache[result.aggMetricId] == nil {
                    mealDataCache[result.aggMetricId] = []
                }
                let localDate = result.periodStart.toLocalDateForTimeline()
                mealDataCache[result.aggMetricId]?.append(ChartDataPoint(
                    date: localDate,
                    value: result.value,
                    label: ""
                ))
            }

            buildChartData(for: period)

        } catch {
            print("❌ Error loading chart data: \(error)")
        }

        isLoading = false
    }

    private func buildChartData(for period: TimePeriod) {
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
    }

    private func getDateGranularity(for period: TimePeriod) -> Calendar.Component {
        switch period {
        case .day: return .hour
        case .week, .month: return .day
        case .sixMonth: return .weekOfYear
        case .year: return .month
        }
    }

    // MARK: - Accessors for chart stats

    func getAverageFor(_ aggId: String, period: TimePeriod, scrollPosition: Date) -> Double {
        guard let points = mealDataCache[aggId] else { return 0 }

        let visibleDuration = getVisibleDomainTimeInterval(for: period)
        guard let endDate = Calendar.current.date(byAdding: .second, value: Int(visibleDuration), to: scrollPosition) else {
            return 0
        }

        let visiblePoints = points.filter { point in
            point.date >= scrollPosition && point.date <= endDate
        }

        let sum = visiblePoints.map { convertToDisplayValue($0.value, for: period) }.reduce(0, +)

        switch period {
        case .day:
            return sum
        case .week, .month, .sixMonth, .year:
            let expectedCount = period.numberOfBars
            return sum / Double(expectedCount)
        }
    }

    func getPercentageFor(_ aggId: String, period: TimePeriod, scrollPosition: Date) -> Double {
        let mealAverage = getAverageFor(aggId, period: period, scrollPosition: scrollPosition)

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
