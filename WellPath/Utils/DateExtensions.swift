//
//  DateExtensions.swift
//  WellPath
//
//  Date utility extensions for timeline matching
//

import Foundation

extension Date {
    /// Returns the date for timeline matching
    ///
    /// Since aggregation_results_cache now stores period_start representing local calendar boundaries
    /// (daily = local date at midnight, hourly = local hour), no timezone conversion is needed.
    /// The database stores the "wall clock" time/date directly.
    ///
    /// - Parameter preserveTime: If true, preserves the time component for hourly data. If false (default), uses start of day.
    /// - Returns: The date, optionally at start of day for daily data
    func toLocalDateForTimeline(preserveTime: Bool = false) -> Date {
        if preserveTime {
            // For hourly data: return as-is (already represents local hour)
            return self
        } else {
            // For daily data: use start of day for matching
            return Calendar.current.startOfDay(for: self)
        }
    }
}
