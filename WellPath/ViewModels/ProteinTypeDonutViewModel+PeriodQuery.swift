//
//  ProteinTypeDonutViewModel+PeriodQuery.swift
//  WellPath
//
//  Extension to query protein type data for specific periods
//

import Foundation
import SwiftUI

extension ProteinTypeDonutViewModel {
    func loadDataForPeriod(period: TimePeriod, date: Date) async {
        isLoading = true
        typeData.removeAll()

        do {
            let userId = try await supabase.auth.session.user.id

            // Map to database period_type
            let periodType: String
            switch period {
            case .day:
                periodType = "daily"
            case .week:
                periodType = "weekly"
            case .month:
                periodType = "monthly"
            case .sixMonth:
                periodType = "six_month"
            case .year:
                periodType = "yearly"
            }

            // All protein type aggregations
            let typeAggIds = [
                "AGG_PROTEIN_TYPE_PLANT_BASED",
                "AGG_PROTEIN_TYPE_FATTY_FISH",
                "AGG_PROTEIN_TYPE_EGGS",
                "AGG_PROTEIN_TYPE_LEAN_PROTEIN",
                "AGG_PROTEIN_TYPE_DAIRY",
                "AGG_PROTEIN_TYPE_SUPPLEMENT",
                "AGG_PROTEIN_TYPE_RED_MEAT",
                "AGG_PROTEIN_TYPE_PROCESSED_MEAT",
                "AGG_PROTEIN_TYPE_OTHER",
                "AGG_PROTEIN_TYPE_UNASSIGNED"
            ]

            // Calculate period start
            let periodStart = getPeriodStart(for: period, date: date)
            let iso8601String = periodStart.ISO8601Format()

            print("🥩 Querying protein types for period: \(periodType)")
            print("🥩   Period start (UTC): \(periodStart)")
            print("🥩   ISO8601 query: \(iso8601String)")

            // Query aggregation_results_cache
            // For Day: use SUM (daily total)
            // For Week/Month/Year: use AVG (average per day with data)
            let calculationType = period == .day ? "SUM" : "AVG"

            let results: [AggregationResult] = try await supabase
                .from("aggregation_results_cache")
                .select()
                .eq("patient_id", value: userId)
                .in("agg_metric_id", values: typeAggIds)
                .eq("period_type", value: periodType)
                .eq("calculation_type_id", value: calculationType)
                .eq("period_start", value: iso8601String)
                .execute()
                .value

            print("🥩 Found \(results.count) type results for period")

            // Store results
            for result in results {
                typeData[result.aggMetricId] = result.value
                print("   \(result.aggMetricId): \(result.value)g")
            }

            // Calculate total to verify percentages sum to 100%
            let total = typeData.values.reduce(0, +)
            print("🥩 Total protein: \(total)g")

            // Debug percentage calculation
            for (typeId, grams) in typeData where grams > 0 {
                let percentage = (grams / total) * 100
                print("   \(typeId): \(grams)g (\(String(format: "%.1f", percentage))%)")
            }

        } catch {
            print("❌ Error loading type data: \(error)")
        }

        isLoading = false
    }

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
}
