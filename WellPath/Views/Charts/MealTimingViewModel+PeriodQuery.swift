//
//  MealTimingViewModel+PeriodQuery.swift
//  WellPath
//
//  Extension to query specific periods directly from database
//

import Foundation
import SwiftUI

extension MealTimingViewModel {
    /// Loads data for a specific period using direct patient_quantity_samples queries
    /// Day view uses hourly data summed, Week/Month/Year use daily data averaged
    func loadDataForPeriod(period: TimePeriod, date: Date) async {
        isLoading = true
        periodData.removeAll()

        do {
            let userId = try await supabase.auth.session.user.id
            let calendar = Calendar.current

            // Calculate period start and end
            let (periodStart, periodEnd): (Date, Date) = {
                switch period {
                case .hour:
                    let start = calendar.dateInterval(of: .hour, for: date)?.start ?? date
                    let end = calendar.date(byAdding: .hour, value: 1, to: start) ?? start
                    return (start, end)
                case .day:
                    let start = calendar.startOfDay(for: date)
                    let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
                    return (start, end)
                case .week:
                    let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
                    let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
                    return (start, end)
                case .month:
                    let start = calendar.dateInterval(of: .month, for: date)?.start ?? date
                    let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
                    return (start, end)
                case .sixMonth:
                    let start = calendar.date(byAdding: .month, value: -6, to: date) ?? date
                    return (start, date)
                case .year:
                    let start = calendar.dateInterval(of: .year, for: date)?.start ?? date
                    let end = calendar.date(byAdding: .year, value: 1, to: start) ?? start
                    return (start, end)
                }
            }()

            struct SampleEntry: Codable {
                let eventInstanceId: UUID?
                let startTime: Date
                let mealType: String?
                let quantityValue: Double?
                let metadata: [String: String]?

                enum CodingKeys: String, CodingKey {
                    case eventInstanceId = "event_instance_id"
                    case startTime = "start_time"
                    case mealType = "meal_type"
                    case quantityValue = "quantity_value"
                    case metadata
                }
            }

            // Fetch all protein samples for the period
            let entries: [SampleEntry] = try await supabase
                .from("patient_quantity_samples")
                .select("event_instance_id, start_time, quantity_value, metadata")
                .eq("patient_id", value: userId)
                .eq("quantity_type", value: QuantityTypes.proteinGrams)
                .eq("is_primary", value: true)  // Only use primary samples for analysis
                .gte("start_time", value: periodStart.ISO8601Format())
                .lt("start_time", value: periodEnd.ISO8601Format())
                .execute()
                .value

            // Aggregate by meal type
            var mealTotals: [String: Double] = [:]
            var uniqueEvents = Set<String>()
            for entry in entries {
                let mealType = entry.metadata?["meal_type"] ?? "unassigned"
                let value = entry.quantityValue ?? 0
                mealTotals[mealType, default: 0] += value
                if let id = entry.eventInstanceId?.uuidString {
                    uniqueEvents.insert(id)
                }
            }

            // Store the aggregated values
            for (meal, value) in mealTotals {
                periodData[meal] = value
            }
            periodData["entries_count"] = Double(uniqueEvents.count)
            print("🍽️ Found \(uniqueEvents.count) protein entries in period")

            // Calculate average per meal using the entry count
            let totalProtein = mealTotals.values.reduce(0, +)
            if uniqueEvents.count > 0 {
                let avgPerMeal = totalProtein / Double(uniqueEvents.count)
                periodData["avg_per_meal"] = avgPerMeal
                print("🍽️ Average per meal: \(avgPerMeal)g")
            } else {
                periodData["avg_per_meal"] = 0
            }

        } catch {
            print("❌ Error loading period data: \(error)")
        }

        isLoading = false
    }
}
