//
//  NutrientTimingViewModel.swift
//  WellPath
//
//  Generic ViewModel for meal timing across all nutrients
//  Supports protein (grams) and other nutrients (servings)
//

import SwiftUI
import Supabase

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

    /// The quantity_type in patient_quantity_samples
    var quantityType: String {
        switch self {
        case .protein:
            return "protein_grams"
        case .legumes:
            return "legumes_servings"
        case .vegetables:
            return "vegetables_servings"
        case .wholeGrains:
            return "whole_grains_servings"
        case .fruits:
            return "fruits_servings"
        }
    }

    /// The metadata key for type breakdown (e.g., "protein_type")
    var typeMetadataKey: String {
        switch self {
        case .protein:
            return "protein_type"
        case .legumes:
            return "legumes_type"
        case .vegetables:
            return "vegetables_type"
        case .wholeGrains:
            return "whole_grains_type"
        case .fruits:
            return "fruits_type"
        }
    }

    /// The metadata key for food timing 
    var mealMetadataKey: String {
        return "food_timing"
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

    /// Defines meal timing types (no longer queries aggregation_metrics)
    func discoverMealAggregations() async {
        // Define standard meal types with display names and metadata values
        let mealTypes: [(id: String, displayName: String, order: Int)] = [
            ("breakfast", "Breakfast", 1),
            ("morning_snack", "Morning Snack", 2),
            ("lunch", "Lunch", 3),
            ("afternoon_snack", "Afternoon Snack", 4),
            ("dinner", "Dinner", 5),
            ("evening_snack", "Evening Snack", 6),
            ("other", "Other", 98)
        ]

        print("🍽️ Setting up \(mealTypes.count) meal types for \(nutrientType.displayName)")

        let colorCount = Double(mealTypes.count)
        mealAggregations = mealTypes.enumerated().map { index, meal in
            let isOther = meal.id == "other"
            let progress = colorCount > 1 ? Double(index) / (colorCount - 1) : 0
            let opacity = 0.55 + (progress * 0.45)

            let color: Color
            if isOther {
                color = Color(red: 0.9, green: 0.9, blue: 0.9)
            } else {
                color = baseColor.opacity(opacity)
            }

            return MealAggregation(
                aggId: meal.id,  // Now using food_timing metadata value as ID
                displayName: meal.displayName,
                color: color
            )
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
    /// Queries patient_quantity_samples and groups by meal_type metadata
    func loadDataForPeriod(period: TimePeriod, date: Date) async {
        isLoading = true
        periodData.removeAll()

        do {
            let userId = try await supabase.auth.session.user.id
            let mealIds = mealAggregations.map { $0.aggId }

            // Calculate date range for the period
            let (startDate, endDate) = getDateRange(for: period, date: date)

            print("🍽️ Querying \(nutrientType.displayName) timing for period: \(period)")
            print("🍽️   Date range: \(startDate) to \(endDate)")

            // Query patient_quantity_samples for this nutrient type
            struct TimingSample: Codable {
                let aggregationDate: String
                let quantityValue: Double?
                let metadata: [String: AnyJSON]?

                enum CodingKeys: String, CodingKey {
                    case aggregationDate = "aggregation_date"
                    case quantityValue = "quantity_value"
                    case metadata
                }
            }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let startStr = dateFormatter.string(from: startDate)
            let endStr = dateFormatter.string(from: endDate)

            let samples: [TimingSample] = try await supabase
                .from("patient_quantity_samples")
                .select("aggregation_date, quantity_value, metadata")
                .eq("patient_id", value: userId)
                .eq("quantity_type", value: nutrientType.quantityType)
                .eq("is_primary", value: true)  // Only use primary samples for analysis
                .gte("aggregation_date", value: startStr)
                .lte("aggregation_date", value: endStr)
                .execute()
                .value

            print("🍽️ Fetched \(samples.count) samples for \(nutrientType.displayName) timing")

            // Group samples by food_timing from metadata
            var mealTotals: [String: [Double]] = [:]
            for mealId in mealIds {
                mealTotals[mealId] = []
            }

            for sample in samples {
                let value = sample.quantityValue ?? 0.0
                if value > 0 {
                    // Get meal_type from metadata
                    let mealType: String
                    if let metadata = sample.metadata,
                       let mealJson = metadata[nutrientType.mealMetadataKey],
                       let mealStr = mealJson.stringValue {
                        mealType = mealStr.lowercased()
                    } else {
                        mealType = "other"  // Default to "other" if no food_timing
                    }
                    mealTotals[mealType, default: []].append(value)
                }
            }

            // For Day view: sum values directly
            // For Week/Month/Year: calculate average per day from samples
            if period == .day {
                // Single day - sum values for each meal type
                var totalValue: Double = 0
                var mealsWithData = 0
                for (mealId, values) in mealTotals {
                    if !values.isEmpty {
                        let sum = values.reduce(0, +)
                        periodData[mealId] = sum
                        totalValue += sum
                        mealsWithData += 1
                    }
                }
                periodData["avg_per_meal"] = mealsWithData > 0 ? totalValue / Double(mealsWithData) : 0
                periodData["entries_count"] = Double(samples.count)
            } else {
                // Multiple days - calculate average per meal type
                var totalValue: Double = 0
                var mealsWithData = 0
                for (mealId, values) in mealTotals {
                    if !values.isEmpty {
                        let average = values.reduce(0, +) / Double(values.count)
                        periodData[mealId] = average
                        totalValue += average
                        mealsWithData += 1
                    }
                }
                periodData["avg_per_meal"] = mealsWithData > 0 ? totalValue / Double(mealsWithData) : 0
                periodData["entries_count"] = Double(mealsWithData)
            }

        } catch {
            print("❌ Error loading period data: \(error)")
        }

        isLoading = false
    }

    /// Returns the date range for querying based on the period
    private func getDateRange(for period: TimePeriod, date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        let localComponents = calendar.dateComponents([.year, .month, .day, .weekday], from: date)

        switch period {
        case .day:
            var utcComponents = DateComponents()
            utcComponents.year = localComponents.year
            utcComponents.month = localComponents.month
            utcComponents.day = localComponents.day
            utcComponents.hour = 0
            utcComponents.timeZone = TimeZone(identifier: "UTC")
            let dayStart = utcCalendar.date(from: utcComponents)!
            return (dayStart, dayStart)

        case .week:
            let weekday = localComponents.weekday!
            let daysFromMonday = (weekday == 1) ? -6 : (2 - weekday)
            let localMonday = calendar.date(byAdding: .day, value: daysFromMonday, to: date)!
            let localSunday = calendar.date(byAdding: .day, value: 6, to: localMonday)!

            let mondayComponents = calendar.dateComponents([.year, .month, .day], from: localMonday)
            let sundayComponents = calendar.dateComponents([.year, .month, .day], from: localSunday)

            var startUtc = DateComponents()
            startUtc.year = mondayComponents.year
            startUtc.month = mondayComponents.month
            startUtc.day = mondayComponents.day
            startUtc.hour = 0
            startUtc.timeZone = TimeZone(identifier: "UTC")

            var endUtc = DateComponents()
            endUtc.year = sundayComponents.year
            endUtc.month = sundayComponents.month
            endUtc.day = sundayComponents.day
            endUtc.hour = 0
            endUtc.timeZone = TimeZone(identifier: "UTC")

            return (utcCalendar.date(from: startUtc)!, utcCalendar.date(from: endUtc)!)

        case .month:
            var startUtc = DateComponents()
            startUtc.year = localComponents.year
            startUtc.month = localComponents.month
            startUtc.day = 1
            startUtc.hour = 0
            startUtc.timeZone = TimeZone(identifier: "UTC")

            let lastDay = calendar.range(of: .day, in: .month, for: date)!.count
            var endUtc = DateComponents()
            endUtc.year = localComponents.year
            endUtc.month = localComponents.month
            endUtc.day = lastDay
            endUtc.hour = 0
            endUtc.timeZone = TimeZone(identifier: "UTC")

            return (utcCalendar.date(from: startUtc)!, utcCalendar.date(from: endUtc)!)

        case .sixMonth:
            let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: date)!
            let startComponents = calendar.dateComponents([.year, .month, .day], from: sixMonthsAgo)

            var startUtc = DateComponents()
            startUtc.year = startComponents.year
            startUtc.month = startComponents.month
            startUtc.day = startComponents.day
            startUtc.hour = 0
            startUtc.timeZone = TimeZone(identifier: "UTC")

            var endUtc = DateComponents()
            endUtc.year = localComponents.year
            endUtc.month = localComponents.month
            endUtc.day = localComponents.day
            endUtc.hour = 0
            endUtc.timeZone = TimeZone(identifier: "UTC")

            return (utcCalendar.date(from: startUtc)!, utcCalendar.date(from: endUtc)!)

        case .year:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: date)!
            let startComponents = calendar.dateComponents([.year, .month, .day], from: yearAgo)

            var startUtc = DateComponents()
            startUtc.year = startComponents.year
            startUtc.month = startComponents.month
            startUtc.day = startComponents.day
            startUtc.hour = 0
            startUtc.timeZone = TimeZone(identifier: "UTC")

            var endUtc = DateComponents()
            endUtc.year = localComponents.year
            endUtc.month = localComponents.month
            endUtc.day = localComponents.day
            endUtc.hour = 0
            endUtc.timeZone = TimeZone(identifier: "UTC")

            return (utcCalendar.date(from: startUtc)!, utcCalendar.date(from: endUtc)!)
        }
    }

    /// Loads chart data for stacked bar visualization
    /// Queries patient_quantity_samples and groups by food_timing metadata
    func loadData(for period: TimePeriod) async {
        isLoading = true
        mealDataCache.removeAll()

        do {
            let mealIds = mealAggregations.map { $0.aggId }

            // Calculate date range for scrolling chart
            let now = Date()
            let calendar = Calendar.current
            let newestDate = calendar.date(byAdding: .month, value: 1, to: now) ?? now

            let oldestDate: Date
            switch period {
            case .hour:
                oldestDate = calendar.date(byAdding: .hour, value: -3, to: now) ?? now
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

            // Query patient_quantity_samples
            struct ChartSample: Codable {
                let aggregationDate: String
                let quantityValue: Double?
                let metadata: [String: AnyJSON]?

                enum CodingKeys: String, CodingKey {
                    case aggregationDate = "aggregation_date"
                    case quantityValue = "quantity_value"
                    case metadata
                }
            }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let startStr = dateFormatter.string(from: oldestDate)
            let endStr = dateFormatter.string(from: newestDate)

            let userId = try await supabase.auth.session.user.id
            let samples: [ChartSample] = try await supabase
                .from("patient_quantity_samples")
                .select("aggregation_date, quantity_value, metadata")
                .eq("patient_id", value: userId)
                .eq("quantity_type", value: nutrientType.quantityType)
                .eq("is_primary", value: true)  // Only use primary samples for analysis
                .gte("aggregation_date", value: startStr)
                .lte("aggregation_date", value: endStr)
                .order("aggregation_date", ascending: true)
                .execute()
                .value

            print("🍽️ Fetched \(samples.count) chart samples for \(nutrientType.displayName)")

            // Initialize cache for each meal type
            for mealId in mealIds {
                mealDataCache[mealId] = []
            }

            // Group by meal_type from metadata
            for sample in samples {
                let value = sample.quantityValue ?? 0.0
                if value > 0 {
                    // Get meal_type from metadata
                    let mealType: String
                    if let metadata = sample.metadata,
                       let mealJson = metadata[nutrientType.mealMetadataKey],
                       let mealStr = mealJson.stringValue {
                        mealType = mealStr.lowercased()
                    } else {
                        mealType = "other"
                    }

                    // Parse aggregation_date as local noon to avoid DST/timezone edge cases
                    let noonFormatter = DateFormatter()
                    noonFormatter.dateFormat = "yyyy-MM-dd HH:mm"
                    noonFormatter.timeZone = TimeZone.current
                    if let date = noonFormatter.date(from: sample.aggregationDate + " 12:00") {
                        mealDataCache[mealType, default: []].append(ChartDataPoint(
                            date: date,
                            value: value,
                            label: ""
                        ))
                    }
                }
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
