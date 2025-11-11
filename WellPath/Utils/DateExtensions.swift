//
//  DateExtensions.swift
//  WellPath
//
//  Date utility extensions for timezone conversions
//

import Foundation

extension Date {
    /// Converts a UTC period_start date to the corresponding local date for timeline matching
    ///
    /// This handles the date matching where period_start is stored in UTC,
    /// but needs to match against local dates in the timeline.
    ///
    /// For daily aggregations:
    /// - period_start: 2025-10-29 00:00:00 UTC (entry made on Oct 29 local time)
    /// - Extract UTC date: 2025-10-29
    /// - Returns: 2025-10-29 00:00:00 PDT (same calendar date in local timezone)
    ///
    /// For hourly/other aggregations:
    /// - period_start: 2025-10-29 15:00:00 UTC (3 PM UTC)
    /// - Converts to local: 2025-10-29 08:00:00 PDT (8 AM Pacific, same instant in time)
    ///
    /// - Parameter preserveTime: If true, preserves the time component for hourly data. If false (default), sets to midnight for daily data.
    /// - Returns: The date in local timezone, optionally preserving the time component
    func toLocalDateForTimeline(preserveTime: Bool = false) -> Date {
        let calendar = Calendar.current

        if preserveTime {
            // For hourly data: just return the date as-is
            // SwiftUI Charts will handle timezone conversion for display
            return self
        } else {
            // For daily data: extract the UTC calendar date and get start of day in local timezone
            let utcComponents = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: self)

            // Create a date with the UTC calendar date components in local timezone
            var localComponents = DateComponents()
            localComponents.year = utcComponents.year
            localComponents.month = utcComponents.month
            localComponents.day = utcComponents.day

            guard let localDate = calendar.date(from: localComponents) else {
                return self
            }

            // Use startOfDay to ensure proper day boundary handling
            return calendar.startOfDay(for: localDate)
        }
    }
}
