//
//  DateExtensions.swift
//  WellPath
//
//  Date utility extensions for timeline matching
//

import Foundation

// MARK: - Calendar Extension

extension Calendar {
    /// Returns the first day of the month for the given date
    func startOfMonth(for date: Date) -> Date {
        self.date(from: self.dateComponents([.year, .month], from: date)) ?? date
    }
}

// MARK: - Date Identifiable Conformance

extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSince1970 }
}

extension Date {
    /// Returns the date for timeline matching
    ///
    /// The database stores period_start as UTC timestamps with different semantics:
    ///
    /// **Daily/Weekly/Monthly/Yearly aggregations:**
    /// - Stored as UTC midnight (e.g., 2025-11-28 00:00:00+00)
    /// - The date component (Nov 28) represents the LOCAL calendar date
    /// - We extract UTC date components and treat them as local date
    ///
    /// **Hourly aggregations:**
    /// - Stored as actual UTC time (e.g., 2025-11-29 00:00:00+00 = UTC hour 0)
    /// - Need standard UTC→local conversion to display correct local hour
    /// - 00:00 UTC = 16:00 Pacific (4 PM)
    ///
    /// - Parameter preserveTime: If true, does standard UTC→local conversion for hourly data. If false (default), extracts UTC date as local date.
    /// - Returns: The date in local timezone for display
    func toLocalDateForTimeline(preserveTime: Bool = false) -> Date {
        if preserveTime {
            // For hourly data: standard UTC to local conversion
            // The timestamp IS the actual UTC time, convert to local
            // Swift Date already stores in UTC, Calendar operations use local by default
            // Just return the start of the local hour
            let calendar = Calendar.current
            return calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: self)) ?? self
        } else {
            // For daily/weekly/monthly/yearly data: extract UTC date and create local midnight
            // The UTC date components represent the LOCAL calendar date
            var utcCalendar = Calendar.current
            utcCalendar.timeZone = TimeZone(identifier: "UTC")!

            let utcComponents = utcCalendar.dateComponents([.year, .month, .day], from: self)
            // Create midnight local time with the same date components
            var localComponents = utcComponents
            localComponents.hour = 0
            localComponents.minute = 0
            localComponents.second = 0
            localComponents.timeZone = Calendar.current.timeZone
            return Calendar.current.date(from: localComponents) ?? self
        }
    }
}
