//
//  ProteinTypeDonutViewModel+PeriodQuery.swift
//  WellPath
//
//  Extension to query protein type data for specific periods
//  Queries patient_quantity_samples directly and groups by protein_type metadata
//

import Foundation
import SwiftUI
import Supabase

extension ProteinTypeDonutViewModel {
    func loadDataForPeriod(period: TimePeriod, date: Date) async {
        isLoading = true
        typeData.removeAll()

        do {
            let userId = try await supabase.auth.session.user.id

            // Calculate date range for the period
            let (startDate, endDate) = getDateRange(for: period, date: date)

            print("🥩 Querying protein types for period: \(period)")
            print("🥩   Date range: \(startDate) to \(endDate)")

            // Query patient_quantity_samples for protein_grams with protein_type metadata
            struct ProteinSample: Codable {
                let canonicalValue: Double?
                let metadata: [String: AnyJSON]?
                let aggregationDateString: String?

                enum CodingKeys: String, CodingKey {
                    case canonicalValue = "canonical_value"
                    case metadata
                    case aggregationDateString = "aggregation_date"
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

            let samples: [ProteinSample] = try await supabase
                .from("patient_quantity_samples")
                .select("canonical_value, metadata, aggregation_date")
                .eq("patient_id", value: userId.uuidString)
                .eq("quantity_type", value: "protein_grams")
                .eq("is_primary", value: true)  // Only use primary samples for analysis
                .gte("aggregation_date", value: ISO8601DateFormatter().string(from: startDate))
                .lte("aggregation_date", value: ISO8601DateFormatter().string(from: endDate))
                .execute()
                .value

            print("🥩 Got \(samples.count) protein samples")

            // Group by protein_type from metadata, tracking unique dates with data
            var typeTotals: [String: Double] = [:]
            var datesWithData: Set<String> = []

            for sample in samples {
                guard let value = sample.canonicalValue else { continue }

                // Track which dates have data
                if let dateStr = sample.aggregationDateString {
                    datesWithData.insert(dateStr)
                }

                // Get protein_type from metadata, default to "unassigned"
                var proteinType = "unassigned"
                if let metadata = sample.metadata,
                   case .string(let type) = metadata["protein_type"] {
                    proteinType = type
                }

                typeTotals[proteinType, default: 0] += value
            }

            // For periods > day, calculate daily average using only days with data
            if period != .day && !datesWithData.isEmpty {
                let dayCount = max(1, datesWithData.count)
                print("🥩 Averaging over \(dayCount) days with data (not full period)")
                for (type, total) in typeTotals {
                    typeTotals[type] = total / Double(dayCount)
                }
            }

            typeData = typeTotals
            print("🥩 Loaded \(typeData.count) protein type values")

            // Calculate total to verify percentages
            let total = typeData.values.reduce(0, +)
            print("🥩 Total protein: \(String(format: "%.1f", total))g")

            // Debug percentage calculation
            for (typeId, grams) in typeData where grams > 0 {
                let percentage = total > 0 ? (grams / total) * 100 : 0
                print("   \(typeId): \(String(format: "%.1f", grams))g (\(String(format: "%.1f", percentage))%)")
            }

        } catch {
            print("❌ Error loading type data: \(error)")
        }

        isLoading = false
    }

    /// Returns the date range for querying based on the period
    private func getDateRange(for period: TimePeriod, date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        // Get local date components
        let localComponents = calendar.dateComponents([.year, .month, .day, .weekday], from: date)

        switch period {
        case .hour:
            // Single hour
            let hourComponents = calendar.dateComponents([.year, .month, .day, .hour], from: date)
            var utcComponents = DateComponents()
            utcComponents.year = hourComponents.year
            utcComponents.month = hourComponents.month
            utcComponents.day = hourComponents.day
            utcComponents.hour = hourComponents.hour
            utcComponents.minute = 0
            utcComponents.second = 0
            utcComponents.timeZone = TimeZone(identifier: "UTC")
            let hourStart = utcCalendar.date(from: utcComponents)!
            return (hourStart, hourStart)

        case .day:
            // Single day
            var utcComponents = DateComponents()
            utcComponents.year = localComponents.year
            utcComponents.month = localComponents.month
            utcComponents.day = localComponents.day
            utcComponents.hour = 0
            utcComponents.minute = 0
            utcComponents.second = 0
            utcComponents.timeZone = TimeZone(identifier: "UTC")
            let dayStart = utcCalendar.date(from: utcComponents)!
            return (dayStart, dayStart)

        case .week:
            // Monday to Sunday of the week containing date
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
            // First to last day of the month
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
            // 6 months back from date
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
            // 12 months back from date
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
}
