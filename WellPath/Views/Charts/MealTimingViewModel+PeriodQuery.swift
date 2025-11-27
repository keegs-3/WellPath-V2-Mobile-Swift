//
//  MealTimingViewModel+PeriodQuery.swift
//  WellPath
//
//  Extension to query specific periods directly from database
//

import Foundation
import SwiftUI

extension MealTimingViewModel {
    func loadDataForPeriod(period: TimePeriod, date: Date) async {
        isLoading = true
        periodData.removeAll()

        do {
            let userId = try await supabase.auth.session.user.id
            // Map to actual database period_type (not databasePeriodType which is for scrolling charts)
            let periodType: String
            switch period {
            case .day:
                periodType = "daily"
            case .week:
                periodType = "weekly"
            case .month:
                periodType = "monthly"
            case .sixMonth:
                periodType = "six_month"  // or whatever the database uses
            case .year:
                periodType = "yearly"
            }
            let aggIds = mealAggregations.map { $0.aggId }

            guard !aggIds.isEmpty else {
                print("⚠️ No meal aggregations discovered yet")
                isLoading = false
                return
            }

            // Calculate the period start and end based on period type and date
            let periodStart = getPeriodStart(for: period, date: date)
            let periodEnd = getPeriodEnd(for: period, date: date)
            let iso8601String = periodStart.ISO8601Format()

            print("🍽️ Querying for period: \(periodType)")
            print("🍽️   Input date: \(date)")
            print("🍽️   Period start (UTC): \(periodStart)")
            print("🍽️   Period end (UTC): \(periodEnd)")
            print("🍽️   ISO8601 query: \(iso8601String)")

            // Query aggregation_results_cache for SUM values (for breakdown)
            let results: [AggregationResult] = try await supabase
                .from("aggregation_results_cache")
                .select()
                .eq("patient_id", value: userId)
                .in("agg_metric_id", values: aggIds)
                .eq("period_type", value: periodType)
                .eq("calculation_type_id", value: "SUM")
                .eq("period_start", value: iso8601String)
                .execute()
                .value

            print("🍽️ Found \(results.count) SUM results for period")
            if results.isEmpty {
                print("⚠️ No data found - check if period_start matches database")
            } else {
                print("✅ Sample result: \(results[0].aggMetricId) = \(results[0].value)")
            }

            // Store the SUM results for breakdown
            for result in results {
                periodData[result.aggMetricId] = result.value
            }

            // Count distinct protein entries from patient_samples
            // Query all protein samples in the period using start_time
            struct SampleEntry: Codable {
                let eventInstanceId: UUID?
                let startTime: Date

                enum CodingKeys: String, CodingKey {
                    case eventInstanceId = "event_instance_id"
                    case startTime = "start_time"
                }
            }

            let entries: [SampleEntry] = try await supabase
                .from("patient_samples")
                .select("event_instance_id, start_time")
                .eq("patient_id", value: userId)
                .eq("quantity_type", value: QuantityTypes.proteinGrams)
                .gte("start_time", value: periodStart.ISO8601Format())
                .lt("start_time", value: periodEnd.ISO8601Format())
                .execute()
                .value

            // Count unique event_instance_id values
            let uniqueEvents = Set(entries.compactMap { $0.eventInstanceId?.uuidString })
            periodData["entries_count"] = Double(uniqueEvents.count)
            print("🍽️ Found \(uniqueEvents.count) protein entries in period (queried from patient_samples)")

            // Calculate average per meal using the entry count
            let totalProtein = periodData.values.reduce(0, +)
            if uniqueEvents.count > 0 {
                let avgPerMeal = totalProtein / Double(uniqueEvents.count)
                periodData["avg_per_meal"] = avgPerMeal
                print("🍽️ Average per meal: \(avgPerMeal)g (total: \(totalProtein)g / \(uniqueEvents.count) entries)")
            } else {
                periodData["avg_per_meal"] = 0
            }

        } catch {
            print("❌ Error loading period data: \(error)")
        }

        isLoading = false
    }

    private func getPeriodStart(for period: TimePeriod, date: Date) -> Date {
        let calendar = Calendar.current
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        switch period {
        case .day:
            // Get the local date components (year, month, day)
            let localComponents = calendar.dateComponents([.year, .month, .day], from: date)

            // Create a UTC date with the same calendar date
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
            // Get the local date components for the week
            let localComponents = calendar.dateComponents([.year, .month, .day, .weekday], from: date)

            // Calculate Monday of this week in local calendar
            let weekday = localComponents.weekday!
            let daysFromMonday = (weekday == 1) ? -6 : (2 - weekday)
            let localMonday = calendar.date(byAdding: .day, value: daysFromMonday, to: date)!
            let mondayComponents = calendar.dateComponents([.year, .month, .day], from: localMonday)

            // Create a UTC date with the same calendar date as Monday
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
            // Get the local year and month
            let localComponents = calendar.dateComponents([.year, .month], from: date)

            // Create a UTC date for the 1st of that month
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
            // Get the local year and month
            let localComponents = calendar.dateComponents([.year, .month], from: date)
            let year = localComponents.year!
            let month = localComponents.month!

            // Determine if we're in Jan-Jun (H1) or Jul-Dec (H2)
            let startMonth = month <= 6 ? 1 : 7

            // Create a UTC date for the start of the 6-month period
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
            // Get the local year
            let localComponents = calendar.dateComponents([.year], from: date)

            // Create a UTC date for January 1 of that year
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

    private func getPeriodEnd(for period: TimePeriod, date: Date) -> Date {
        let calendar = Calendar.current
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        let periodStart = getPeriodStart(for: period, date: date)

        switch period {
        case .day:
            return utcCalendar.date(byAdding: .day, value: 1, to: periodStart)!
        case .week:
            return utcCalendar.date(byAdding: .weekOfYear, value: 1, to: periodStart)!
        case .month:
            return utcCalendar.date(byAdding: .month, value: 1, to: periodStart)!
        case .sixMonth:
            return utcCalendar.date(byAdding: .month, value: 6, to: periodStart)!
        case .year:
            return utcCalendar.date(byAdding: .year, value: 1, to: periodStart)!
        }
    }
}
