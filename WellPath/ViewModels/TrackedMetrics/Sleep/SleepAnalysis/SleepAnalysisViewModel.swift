//
//  SleepViewModel.swift
//  WellPath
//
//  Created on 2025-10-22
//

import Foundation
import Supabase

// Manual sleep entry model (no stage breakdown, just duration)
struct ManualSleepEntry: Identifiable {
    let id = UUID()
    let bedtime: Date
    let waketime: Date
    let sleepDuration: TimeInterval
    let source: String // "wellpath_input" or "auto_calculated"
    let eventInstanceId: String

    var date: Date {
        Calendar.current.startOfDay(for: waketime)
    }
}

// Sleep session model for paging
struct SleepSession: Identifiable {
    var id: Date { date } // Use date as stable identifier
    let segments: [SleepStageSegment]
    let sessionStart: Date
    let sessionEnd: Date
    let date: Date // The date this session represents (for empty sessions)
    let manualEntry: ManualSleepEntry? // If this is a manual entry instead of HealthKit

    init(segments: [SleepStageSegment], sessionStart: Date, sessionEnd: Date, date: Date? = nil, manualEntry: ManualSleepEntry? = nil) {
        self.segments = segments
        self.sessionStart = sessionStart
        self.sessionEnd = sessionEnd
        // Use provided date or derive from sessionEnd
        self.date = date ?? Calendar.current.startOfDay(for: sessionEnd)
        self.manualEntry = manualEntry
    }

    var isManual: Bool {
        manualEntry != nil
    }
}

// Sleep bar model for week/month views
struct SleepBar: Identifiable {
    let id = UUID()
    let sleepDate: Date // Sleep date (wake date - 1)
    let sessionStart: Date // Actual bedtime
    let sessionEnd: Date // Actual wake time
    let isNap: Bool
    let deepDuration: TimeInterval
    let coreDuration: TimeInterval
    let remDuration: TimeInterval
    let awakeDuration: TimeInterval

    var totalDuration: TimeInterval {
        deepDuration + coreDuration + remDuration + awakeDuration
    }
}

// Weekly average model for 6M view
struct WeeklyAverage: Identifiable {
    let id = UUID()
    let weekStartDate: Date // Start of the week
    let weekEndDate: Date // End of the week
    let avgTimeInBed: TimeInterval // Average time in bed for the week
    let avgTimeAsleep: TimeInterval // Average time asleep for the week
    let avgBedtime: Date // Average bedtime as UTC timestamp
    let avgWaketime: Date // Average waketime as UTC timestamp
}

// Monthly average model for Y view
struct MonthlyAverage: Identifiable {
    let id = UUID()
    let monthStartDate: Date // Start of the month
    let monthEndDate: Date // End of the month
    let avgTimeInBed: TimeInterval // Average time in bed for the month
    let avgTimeAsleep: TimeInterval // Average time asleep for the month
    let avgBedtime: Date // Average bedtime as UTC timestamp
    let avgWaketime: Date // Average waketime as UTC timestamp
}

@MainActor
class SleepAnalysisViewModel: ObservableObject {
    @Published var sleepStageSegments: [SleepStageSegment] = []
    @Published var sleepSessions: [SleepSession] = []
    @Published var isLoading = false
    @Published var isLoadingOlder = false
    @Published var isLoadingNewer = false

    // Properties for infinite scrolling day view
    @Published var totalTimeInBed: String = "0h 0m"
    @Published var totalTimeAsleep: String = "0h 0m"
    @Published var currentDateText: String = ""
    
    // Properties for Week/Month view selection
    @Published var selectedBar: SleepBar?
    @Published var selectedBarTimeInBed: String = "0h 0m"
    @Published var selectedBarTimeAsleep: String = "0h 0m"
    @Published var selectedBarDate: String = ""

    // Properties for 6M view (weekly averages)
    @Published var weeklyAverages: [WeeklyAverage] = []
    @Published var selectedWeeklyAverage: WeeklyAverage?
    private var weeklyDataStartDate: Date?
    private var weeklyDataEndDate: Date?

    // Properties for Y view (monthly averages)
    @Published var monthlyAverages: [MonthlyAverage] = []
    @Published var selectedMonthlyAverage: MonthlyAverage?
    private var monthlyDataStartDate: Date?
    private var monthlyDataEndDate: Date?

    // Track the data range for infinite scrolling
    private var dataStartDate: Date?
    private var dataEndDate: Date?

    // Callback when sessions are prepended (so day view can adjust index)
    var onSessionsPrepended: ((Int) -> Void)?

    private let supabase = SupabaseManager.shared.client
    
    // Aggregation metric IDs for cache queries (as you scroll, queries different date ranges)
    private var timeInBedMetricId: String? = "AGG_TIME_IN_BED"
    private var timeAsleepMetricId: String? = "AGG_SLEEP_DURATION"

    // MARK: - Infinite Scrolling Methods

    /// Loads all sleep sessions for multiple days (for scrolling)
    /// - Parameter daysBack: Days to load before today
    /// - Parameter daysAhead: Days to load after today (for views that show future dates)
    func loadInitialSleepStages(daysBack: Int = 7, daysAhead: Int = 0) async {
        isLoading = true

        do {
            let calendar = Calendar.current
            let now = Date()

            // Load specified range centered around today
            let startDate = calendar.date(byAdding: .day, value: -daysBack, to: now) ?? now
            let endDate = calendar.date(byAdding: .day, value: daysAhead, to: now) ?? now

            NSLog("[SLEEP] 📥 Loading initial data: \(daysBack) days back, \(daysAhead) days ahead")

            // Fetch all sleep stages from specified range
            // This includes both HealthKit multi-stage data AND manual entries (as period types)
            let allSegments = try await fetchSleepStages(from: startDate, to: endDate)

            NSLog("[SLEEP] 📊 Found \(allSegments.count) total segments (HealthKit + manual)")

            // Store all segments
            sleepStageSegments = allSegments.sorted { $0.startTime < $1.startTime }

            // Group into individual sleep sessions (including empty days)
            sleepSessions = createSessionsIncludingEmptyDays(
                segments: sleepStageSegments,
                startDate: startDate,
                endDate: endDate,
                manualEntries: [] // Manual entries now come through as segments
            )

            dataStartDate = startDate
            dataEndDate = endDate

            // Calculate summary metrics for most recent session with data
            if let firstSessionWithData = sleepSessions.first(where: { !$0.segments.isEmpty }) {
                calculateSummaryMetrics(for: firstSessionWithData.segments)
            } else {
                // No data at all
                totalTimeInBed = "0h 0m"
                totalTimeAsleep = "0h 0m"
                currentDateText = ""
            }

            NSLog("[SLEEP] ✅ Loaded \(sleepStageSegments.count) sleep stage segments across \(sleepSessions.count) days (including empty)")

        } catch {
            NSLog("[SLEEP] ❌ Error loading initial sleep stages: \(error.localizedDescription)")
        }

        isLoading = false
    }
    
    // MARK: - Aggregation Cache Methods
    
    /// Fetches averages from aggregation cache for a visible date range
    /// - Parameters:
    ///   - startDate: Start of visible window (normalized to start of day)
    ///   - endDate: End of visible window (normalized to start of day)
    ///   - periodType: "daily", "weekly", or "monthly"
    ///   - calculationType: "SUM" for daily, "AVG" for weekly/monthly
    func fetchAveragesFromCache(startDate: Date, endDate: Date, periodType: String, calculationType: String) async -> (timeInBed: Double, timeAsleep: Double)? {
        do {
            let userId = try await supabase.auth.session.user.id
            
            guard let timeInBedMetricId = timeInBedMetricId,
                  let timeAsleepMetricId = timeAsleepMetricId else {
                NSLog("[SLEEP] ⚠️ Metric IDs not set")
                return nil
            }
            
            // Query aggregation cache for both metrics in the date range
            // Note: aggregation cache dates are already normalized to 6PM-6PM day boundaries
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            struct AggCacheEntry: Codable {
                let aggMetricId: String
                let periodStart: Date
                let value: Double
                
                enum CodingKeys: String, CodingKey {
                    case aggMetricId = "agg_metric_id"
                    case periodStart = "period_start"
                    case value
                }
            }
            
            // Query aggregation cache for the date range
            // Cache stores dates at UTC midnight (00:00:00+00), so normalize to UTC
            var utcCalendar = Calendar(identifier: .gregorian)
            utcCalendar.timeZone = TimeZone(identifier: "UTC")!
            
            let localCalendar = Calendar.current
            
            // Normalize startDate and endDate to UTC midnight for comparison
            let startComponents = localCalendar.dateComponents([.year, .month, .day], from: startDate)
            let endComponents = localCalendar.dateComponents([.year, .month, .day], from: endDate)
            
            guard let startUTC = utcCalendar.date(from: startComponents),
                  let endUTC = utcCalendar.date(from: endComponents) else {
                NSLog("[SLEEP] ⚠️ Failed to normalize dates to UTC")
                return nil
            }
            
            // Query with buffer days to account for timezone differences
            let queryStartUTC = utcCalendar.date(byAdding: .day, value: -1, to: startUTC) ?? startUTC
            let queryEndUTC = utcCalendar.date(byAdding: .day, value: 1, to: endUTC) ?? endUTC
            
            NSLog("[SLEEP] 🔍 Querying aggregation cache: periodType=\(periodType), calcType=\(calculationType), range=\(queryStartUTC) to \(queryEndUTC)")
            
            let cacheResults: [AggCacheEntry] = try await supabase
                .from("aggregation_results_cache")
                .select("agg_metric_id, period_start, value")
                .eq("patient_id", value: userId)
                .in("agg_metric_id", values: [timeInBedMetricId, timeAsleepMetricId])
                .eq("period_type", value: periodType)
                .eq("calculation_type_id", value: calculationType)
                .gte("period_start", value: queryStartUTC.ISO8601Format())
                .lte("period_start", value: queryEndUTC.ISO8601Format())
                .order("period_start", ascending: true)
                .execute()
                .value
            
            NSLog("[SLEEP] 📊 Found \(cacheResults.count) total cache entries")
            
            // Log all cache entry dates for debugging
            for entry in cacheResults.prefix(5) {
                let entryUTC = utcCalendar.startOfDay(for: entry.periodStart)
                NSLog("[SLEEP] 📊 Cache entry: date=\(entryUTC), metricId=\(entry.aggMetricId), value=\(entry.value)")
            }
            
            // Filter to visible range using UTC midnight comparison
            let filteredResults = cacheResults.filter { entry in
                let entryUTC = utcCalendar.startOfDay(for: entry.periodStart)
                return entryUTC >= startUTC && entryUTC <= endUTC
            }
            NSLog("[SLEEP] 📊 Filtered to \(filteredResults.count) entries within visible range (startDate=\(startDate), endDate=\(endDate))")

            guard !filteredResults.isEmpty else {
                NSLog("[SLEEP] ⚠️ No aggregation cache results for range \(startDate) to \(endDate)")
                return nil
            }
            
            let groupedByDate = Dictionary(grouping: filteredResults) { entry -> Date in
                utcCalendar.startOfDay(for: entry.periodStart)
            }

            let datesWithData = groupedByDate.keys.sorted()
            NSLog("[SLEEP] 📅 Dates with cache data: \(datesWithData.map { utcCalendar.dateComponents([.month, .day], from: $0) })")

            var validDays: [(timeInBed: Double, timeAsleep: Double)] = []
            
            for date in datesWithData {
                guard let entries = groupedByDate[date] else { continue }
                guard let timeInBed = entries.first(where: { $0.aggMetricId == timeInBedMetricId })?.value,
                      let timeAsleep = entries.first(where: { $0.aggMetricId == timeAsleepMetricId })?.value else {
                    let dateStr = utcCalendar.dateComponents([.month, .day], from: date)
                    NSLog("[SLEEP] ⚠️ Skipping date \(dateStr) - missing one or both metrics")
                    continue
                }
                let dateStr = utcCalendar.dateComponents([.month, .day], from: date)
                NSLog("[SLEEP] 📊 Date \(dateStr): timeInBed=\(timeInBed)min, timeAsleep=\(timeAsleep)min")
                validDays.append((timeInBed: timeInBed, timeAsleep: timeAsleep))
            }

            guard !validDays.isEmpty else {
                NSLog("[SLEEP] ⚠️ No valid days with both metrics")
                return nil
            }
            
            let avgTimeInBed = validDays.reduce(0.0) { $0 + $1.timeInBed } / Double(validDays.count)
            let avgTimeAsleep = validDays.reduce(0.0) { $0 + $1.timeAsleep } / Double(validDays.count)
            
            NSLog("[SLEEP] ✅ Fetched from cache: \(validDays.count) days, avg \(String(format: "%.1f", avgTimeInBed))min in bed, \(String(format: "%.1f", avgTimeAsleep))min asleep")
            
            return (avgTimeInBed, avgTimeAsleep)
            
        } catch {
            NSLog("[SLEEP] ❌ Error fetching from aggregation cache: \(error.localizedDescription)")
            return nil
        }
    }

    /// Fetches bedtime and waketime averages from aggregation cache
    /// Returns minutes since 6PM (e.g., 300 = 11 PM, 780 = 7 AM)
    func fetchBedtimeWaketimeFromCache(startDate: Date, endDate: Date, periodType: String, calculationType: String) async -> (bedtime: Double, waketime: Double)? {
        do {
            let userId = try await supabase.auth.session.user.id

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            struct AggCacheEntry: Codable {
                let aggMetricId: String
                let periodStart: Date
                let value: Double

                enum CodingKeys: String, CodingKey {
                    case aggMetricId = "agg_metric_id"
                    case periodStart = "period_start"
                    case value
                }
            }

            var utcCalendar = Calendar(identifier: .gregorian)
            utcCalendar.timeZone = TimeZone(identifier: "UTC")!

            let localCalendar = Calendar.current

            // Normalize dates to UTC midnight
            let startComponents = localCalendar.dateComponents([.year, .month, .day], from: startDate)
            let endComponents = localCalendar.dateComponents([.year, .month, .day], from: endDate)

            guard let startUTC = utcCalendar.date(from: startComponents),
                  let endUTC = utcCalendar.date(from: endComponents) else {
                NSLog("[SLEEP] ⚠️ Failed to normalize dates to UTC")
                return nil
            }

            let queryStartUTC = utcCalendar.date(byAdding: .day, value: -1, to: startUTC) ?? startUTC
            let queryEndUTC = utcCalendar.date(byAdding: .day, value: 1, to: endUTC) ?? endUTC

            NSLog("[SLEEP] 🔍 Querying bedtime/waketime cache: periodType=\(periodType), calcType=\(calculationType), range=\(queryStartUTC) to \(queryEndUTC)")

            let cacheResults: [AggCacheEntry] = try await supabase
                .from("aggregation_results_cache")
                .select("agg_metric_id, period_start, value")
                .eq("patient_id", value: userId)
                .in("agg_metric_id", values: ["AGG_SLEEP_BEDTIME", "AGG_SLEEP_WAKETIME"])
                .eq("period_type", value: periodType)
                .eq("calculation_type_id", value: calculationType)
                .gte("period_start", value: queryStartUTC.ISO8601Format())
                .lte("period_start", value: queryEndUTC.ISO8601Format())
                .order("period_start", ascending: true)
                .execute()
                .value

            NSLog("[SLEEP] 📊 Found \(cacheResults.count) bedtime/waketime cache entries")

            let filteredResults = cacheResults.filter { entry in
                let entryUTC = utcCalendar.startOfDay(for: entry.periodStart)
                return entryUTC >= startUTC && entryUTC <= endUTC
            }

            guard !filteredResults.isEmpty else {
                NSLog("[SLEEP] ⚠️ No bedtime/waketime cache results for range")
                return nil
            }

            let groupedByDate = Dictionary(grouping: filteredResults) { entry -> Date in
                utcCalendar.startOfDay(for: entry.periodStart)
            }

            var validDays: [(bedtime: Double, waketime: Double)] = []

            for date in groupedByDate.keys.sorted() {
                guard let entries = groupedByDate[date] else { continue }
                guard let bedtime = entries.first(where: { $0.aggMetricId == "AGG_SLEEP_BEDTIME" })?.value,
                      let waketime = entries.first(where: { $0.aggMetricId == "AGG_SLEEP_WAKETIME" })?.value else {
                    continue
                }
                validDays.append((bedtime: bedtime, waketime: waketime))
            }

            guard !validDays.isEmpty else {
                NSLog("[SLEEP] ⚠️ No valid days with both bedtime and waketime")
                return nil
            }

            let avgBedtime = validDays.reduce(0.0) { $0 + $1.bedtime } / Double(validDays.count)
            let avgWaketime = validDays.reduce(0.0) { $0 + $1.waketime } / Double(validDays.count)

            NSLog("[SLEEP] ✅ Fetched bedtime/waketime from cache: \(validDays.count) periods, avg bedtime=\(avgBedtime)min, waketime=\(avgWaketime)min")

            return (avgBedtime, avgWaketime)

        } catch {
            NSLog("[SLEEP] ❌ Error fetching bedtime/waketime from cache: \(error.localizedDescription)")
            return nil
        }
    }

    /// Looks up sleep metric IDs from display_metrics_aggregations
    private func lookupSleepMetricIds() async {
        do {
            // Try to find metric IDs for "Time in Bed" and "Time Asleep"
            // First, search display_metrics for sleep-related metrics
            struct DisplayMetric: Codable {
                let metricId: String
                let metricName: String
                
                enum CodingKeys: String, CodingKey {
                    case metricId = "metric_id"
                    case metricName = "metric_name"
                }
            }
            
            // Search for sleep metrics - try multiple approaches
            var allMetrics: [DisplayMetric] = []
            
            // Try sleep-related metrics first
            do {
                let sleepMetrics: [DisplayMetric] = try await supabase
                    .from("display_metrics")
                    .select("metric_id, metric_name")
                    .ilike("metric_name", pattern: "%sleep%")
                    .eq("is_active", value: true)
                    .execute()
                    .value
                allMetrics.append(contentsOf: sleepMetrics)
            } catch {
                NSLog("[SLEEP] Could not query sleep metrics: \(error.localizedDescription)")
            }
            
            // Also try time in bed / time asleep
            do {
                let timeMetrics: [DisplayMetric] = try await supabase
                    .from("display_metrics")
                    .select("metric_id, metric_name")
                    .or("metric_name.ilike.%time%in%bed%,metric_name.ilike.%time%asleep%")
                    .eq("is_active", value: true)
                    .execute()
                    .value
                allMetrics.append(contentsOf: timeMetrics)
            } catch {
                NSLog("[SLEEP] Could not query time metrics: \(error.localizedDescription)")
            }
            
            // Remove duplicates
            let metrics = Array(Set(allMetrics.map { $0.metricId }))
                .compactMap { metricId in
                    allMetrics.first(where: { $0.metricId == metricId })
                }
            
            // Find time in bed and time asleep metrics
            if let timeInBed = metrics.first(where: { $0.metricName.localizedCaseInsensitiveContains("time") && $0.metricName.localizedCaseInsensitiveContains("bed") }),
               let timeAsleep = metrics.first(where: { $0.metricName.localizedCaseInsensitiveContains("time") && $0.metricName.localizedCaseInsensitiveContains("asleep") }) {
                
                // Now get agg_metric_id from junction table for "daily" period
                struct JunctionResult: Codable {
                    let aggMetricId: String
                    let metricId: String
                    
                    enum CodingKeys: String, CodingKey {
                        case aggMetricId = "agg_metric_id"
                        case metricId = "metric_id"
                    }
                }
                
                let junctionResults: [JunctionResult] = try await supabase
                    .from("display_metrics_aggregations")
                    .select("agg_metric_id, metric_id")
                    .in("metric_id", values: [timeInBed.metricId, timeAsleep.metricId])
                    .eq("period_type", value: "daily")
                    .execute()
                    .value
                
                timeInBedMetricId = junctionResults.first(where: { $0.metricId == timeInBed.metricId })?.aggMetricId
                timeAsleepMetricId = junctionResults.first(where: { $0.metricId == timeAsleep.metricId })?.aggMetricId
                
                NSLog("[SLEEP] ✅ Looked up metric IDs: timeInBed=\(timeInBedMetricId ?? "nil"), timeAsleep=\(timeAsleepMetricId ?? "nil")")
            }
        } catch {
            NSLog("[SLEEP] ❌ Error looking up sleep metric IDs: \(error.localizedDescription)")
        }
    }
    
    /// Creates a session for each day, even if no data exists
    private func createSessionsIncludingEmptyDays(segments: [SleepStageSegment], startDate: Date, endDate: Date, manualEntries: [ManualSleepEntry] = []) -> [SleepSession] {
        let calendar = Calendar.current
        var sessions: [SleepSession] = []

        // Group segments by sleep session (gaps > 2 hours)
        let dataSessionGroups = groupIntoSleepSessions(segments)

        // Create a dictionary mapping dates to ALL segments (combining multiple sessions per day)
        var dateToSegments: [Date: [SleepStageSegment]] = [:]
        for sessionGroup in dataSessionGroups {
            guard let lastSegment = sessionGroup.last else { continue }

            // Assign sessions to the calendar day of their ending (wake-up) time.
            // This matches the backend aggregation which now uses standard midnight boundaries.
            let sessionEndDate = calendar.startOfDay(for: lastSegment.endTime)

            if dateToSegments[sessionEndDate] == nil {
                dateToSegments[sessionEndDate] = []
            }
            dateToSegments[sessionEndDate]?.append(contentsOf: sessionGroup)
        }

        // Group manual entries by date (wake-up date)
        var dateToManualEntry: [Date: ManualSleepEntry] = [:]
        for entry in manualEntries {
            let entryDate = calendar.startOfDay(for: entry.waketime)
            dateToManualEntry[entryDate] = entry
        }

        // Iterate through each day in range
        var currentDate = calendar.startOfDay(for: endDate)
        let startOfRange = calendar.startOfDay(for: startDate)

        while currentDate >= startOfRange {
            if let sessionSegments = dateToSegments[currentDate] {
                // Day has HealthKit data - sort segments by start time to ensure chronological order
                let sortedSegments = sessionSegments.sorted { $0.startTime < $1.startTime }

                // Check for manual entry on same day
                if let manualEntry = dateToManualEntry[currentDate] {
                    // Overlap detection: Check if manual entry overlaps with HealthKit data
                    let healthKitStart = sortedSegments.first?.startTime ?? currentDate
                    let healthKitEnd = sortedSegments.last?.endTime ?? currentDate

                    let overlaps = timeRangesOverlap(
                        start1: manualEntry.bedtime, end1: manualEntry.waketime,
                        start2: healthKitStart, end2: healthKitEnd
                    )

                    if overlaps {
                        NSLog("[SLEEP] ⚠️ Manual entry overlaps with HealthKit data on \(currentDate), using HealthKit data")
                        // Use HealthKit data only (ignore manual entry due to overlap)
                        sessions.append(SleepSession(
                            segments: sortedSegments,
                            sessionStart: sortedSegments.first?.startTime ?? currentDate,
                            sessionEnd: sortedSegments.last?.endTime ?? currentDate,
                            date: currentDate
                        ))
                    } else {
                        // No overlap - show BOTH HealthKit segments AND manual entry
                        NSLog("[SLEEP] ✅ Combining HealthKit and manual entry for \(currentDate)")
                        sessions.append(SleepSession(
                            segments: sortedSegments,
                            sessionStart: sortedSegments.first?.startTime ?? currentDate,
                            sessionEnd: sortedSegments.last?.endTime ?? currentDate,
                            date: currentDate,
                            manualEntry: manualEntry
                        ))
                    }
                } else {
                    // Only HealthKit data, no manual entry
                    sessions.append(SleepSession(
                        segments: sortedSegments,
                        sessionStart: sortedSegments.first?.startTime ?? currentDate,
                        sessionEnd: sortedSegments.last?.endTime ?? currentDate,
                        date: currentDate
                    ))
                }
            } else if let manualEntry = dateToManualEntry[currentDate] {
                // Day has only manual entry (no HealthKit data)
                sessions.append(SleepSession(
                    segments: [],
                    sessionStart: manualEntry.bedtime,
                    sessionEnd: manualEntry.waketime,
                    date: currentDate,
                    manualEntry: manualEntry
                ))
            } else {
                // Empty day - create empty session with default time window
                let defaultStart = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: currentDate.addingTimeInterval(-86400)) ?? currentDate
                let defaultEnd = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: currentDate) ?? currentDate

                sessions.append(SleepSession(
                    segments: [],
                    sessionStart: defaultStart,
                    sessionEnd: defaultEnd,
                    date: currentDate
                ))
            }

            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }

        return sessions
    }

    /// Checks if two time ranges overlap
    private func timeRangesOverlap(start1: Date, end1: Date, start2: Date, end2: Date) -> Bool {
        // Two ranges overlap if either:
        // - start1 is between start2 and end2
        // - start2 is between start1 and end1
        // - ranges are identical
        return (start1 >= start2 && start1 < end2) ||
               (start2 >= start1 && start2 < end1) ||
               (start1 <= start2 && end1 >= end2) ||
               (start2 <= start1 && end2 >= end1)
    }

    /// Groups sleep segments into individual sleep sessions
    private func groupIntoSleepSessions(_ segments: [SleepStageSegment]) -> [[SleepStageSegment]] {
        guard !segments.isEmpty else { return [] }

        let sorted = segments.sorted { $0.startTime < $1.startTime }
        var sessions: [[SleepStageSegment]] = []
        var currentSession: [SleepStageSegment] = [sorted[0]]

        for i in 1..<sorted.count {
            let previousEnd = sorted[i-1].endTime
            let currentStart = sorted[i].startTime
            let gap = currentStart.timeIntervalSince(previousEnd)

            // If gap > 2 hours, start a new session
            if gap > 7200 {
                sessions.append(currentSession)
                currentSession = [sorted[i]]
            } else {
                currentSession.append(sorted[i])
            }
        }

        // Add the last session
        if !currentSession.isEmpty {
            sessions.append(currentSession)
        }

        return sessions
    }

    /// Loads earlier sleep stage data (scroll backward)
    func loadEarlierSleepStages() async {
        // Guard against concurrent loads
        guard !isLoadingOlder else {
            NSLog("[SLEEP] Already loading earlier data, skipping")
            return
        }

        guard let currentStart = dataStartDate else { return }

        isLoadingOlder = true

        do {
            let calendar = Calendar.current

            // Load 7 more days going backwards
            let olderEnd = currentStart
            let olderStart = calendar.date(byAdding: .day, value: -7, to: currentStart) ?? currentStart

            NSLog("[SLEEP] â¬…ï¸ Loading earlier sleep data from \(olderStart) to \(olderEnd)")

            let olderSegments = try await fetchSleepStages(from: olderStart, to: olderEnd)

            // Prepend older data
            sleepStageSegments = (olderSegments + sleepStageSegments).sorted { $0.startTime < $1.startTime }

            // Re-create all sessions including empty days
            guard let newEnd = dataEndDate else { return }
            
            sleepSessions = createSessionsIncludingEmptyDays(
                segments: sleepStageSegments,
                startDate: olderStart,
                endDate: newEnd
            )

            // Update data range
            dataStartDate = olderStart

            NSLog("[SLEEP] ✅ Loaded \(olderSegments.count) earlier segments. Total sessions: \(sleepSessions.count)")

            isLoadingOlder = false

        } catch {
            NSLog("[SLEEP] ❌ Error loading earlier data: \(error)")
            isLoadingOlder = false
        }
    }

    /// Loads later sleep stage data (scroll forward)
    func loadLaterSleepStages() async {
        // Guard against concurrent loads
        guard !isLoadingNewer else {
            NSLog("[SLEEP] Already loading later data, skipping")
            return
        }

        guard let currentEnd = dataEndDate else { return }

        let calendar = Calendar.current
        let now = Date()

        // Use day-level comparison to avoid timestamp precision issues
        let currentEndDay = calendar.startOfDay(for: currentEnd)
        let todayDay = calendar.startOfDay(for: now)

        // Check if we're already at current date
        guard currentEndDay < todayDay else {
            NSLog("[SLEEP] ⚠️ Already at current date")
            return
        }

        isLoadingNewer = true

        do {

            // Load from next day after current end, up to today
            let newerStart = calendar.date(byAdding: .day, value: 1, to: currentEndDay) ?? currentEndDay
            let newerEnd = todayDay

            NSLog("[SLEEP] âž¡ï¸ Loading later sleep data from \(newerStart) to \(newerEnd)")

            let newerSegments = try await fetchSleepStages(from: newerStart, to: newerEnd)

            // Append newer data
            sleepStageSegments = (sleepStageSegments + newerSegments).sorted { $0.startTime < $1.startTime }

            // Re-create all sessions including empty days
            guard let newStart = dataStartDate else { return }
            
            sleepSessions = createSessionsIncludingEmptyDays(
                segments: sleepStageSegments,
                startDate: newStart,
                endDate: newerEnd
            )

            // Update data range
            dataEndDate = newerEnd

            NSLog("[SLEEP] ✅ Loaded \(newerSegments.count) later segments. Total sessions: \(sleepSessions.count)")

            isLoadingNewer = false

        } catch {
            NSLog("[SLEEP] ❌ Error loading later data: \(error)")
            isLoadingNewer = false
        }
    }

    /// Helper to fetch sleep stages for a date range
    private func fetchManualSleepEntries(from startDate: Date, to endDate: Date) async throws -> [ManualSleepEntry] {
        let userId = try await supabase.auth.session.user.id

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        struct SleepOutputEntry: Codable {
            let fieldId: String
            let valueTimestamp: Date?
            let valueQuantity: Double?
            let eventInstanceId: String
            let source: String

            enum CodingKeys: String, CodingKey {
                case fieldId = "field_id"
                case valueTimestamp = "value_timestamp"
                case valueQuantity = "value_quantity"
                case eventInstanceId = "event_instance_id"
                case source
            }
        }

        // Fetch OUTPUT_SLEEP_WAKETIME first to get sessions in this date range
        // Like HealthKit, we assign sessions to their wake-up date
        let waketimeResponse = try await supabase
            .from("patient_data_entries")
            .select("field_id, value_timestamp, value_quantity, event_instance_id, source")
            .eq("patient_id", value: userId)
            .gte("value_timestamp", value: startDate.ISO8601Format())
            .lte("value_timestamp", value: endDate.ISO8601Format())
            .eq("field_id", value: "OUTPUT_SLEEP_WAKETIME")
            .eq("source", value: "auto_calculated") // Only get entries from manual entry trigger
            .order("value_timestamp", ascending: true)
            .execute()

        let waketimeEntries = try decoder.decode([SleepOutputEntry].self, from: waketimeResponse.data)

        // Extract unique event_instance_ids from waketimes
        let eventInstanceIds = Array(Set(waketimeEntries.map { $0.eventInstanceId }))

        guard !eventInstanceIds.isEmpty else {
            return []
        }

        // Now fetch BEDTIME entries for those specific event instances
        let bedtimeResponse = try await supabase
            .from("patient_data_entries")
            .select("field_id, value_timestamp, value_quantity, event_instance_id, source")
            .eq("patient_id", value: userId)
            .eq("field_id", value: "OUTPUT_SLEEP_BEDTIME")
            .in("event_instance_id", values: eventInstanceIds)
            .execute()

        let bedtimeEntries = try decoder.decode([SleepOutputEntry].self, from: bedtimeResponse.data)

        // Fetch DURATION entries for those specific event instances
        let durationResponse = try await supabase
            .from("patient_data_entries")
            .select("field_id, value_timestamp, value_quantity, event_instance_id, source")
            .eq("patient_id", value: userId)
            .eq("field_id", value: "OUTPUT_SLEEP_DURATION")
            .in("event_instance_id", values: eventInstanceIds)
            .execute()

        let durationEntries = try decoder.decode([SleepOutputEntry].self, from: durationResponse.data)

        // Combine all entries
        let entries = waketimeEntries + bedtimeEntries + durationEntries

        // Group by event_instance_id
        var instanceMap: [String: [SleepOutputEntry]] = [:]
        for entry in entries {
            instanceMap[entry.eventInstanceId, default: []].append(entry)
        }

        var manualEntries: [ManualSleepEntry] = []

        for (instanceId, instanceEntries) in instanceMap {
            guard let bedtimeEntry = instanceEntries.first(where: { $0.fieldId == "OUTPUT_SLEEP_BEDTIME" }),
                  let waketimeEntry = instanceEntries.first(where: { $0.fieldId == "OUTPUT_SLEEP_WAKETIME" }),
                  let durationEntry = instanceEntries.first(where: { $0.fieldId == "OUTPUT_SLEEP_DURATION" }),
                  let bedtime = bedtimeEntry.valueTimestamp,
                  let waketime = waketimeEntry.valueTimestamp,
                  let durationMinutes = durationEntry.valueQuantity else {
                continue
            }

            manualEntries.append(ManualSleepEntry(
                bedtime: bedtime,
                waketime: waketime,
                sleepDuration: durationMinutes * 60, // Convert minutes to seconds
                source: bedtimeEntry.source,
                eventInstanceId: instanceId
            ))
        }

        return manualEntries.sorted { $0.bedtime < $1.bedtime }
    }

    private func fetchSleepStages(from startDate: Date, to endDate: Date) async throws -> [SleepStageSegment] {
        let userId = try await supabase.auth.session.user.id

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        struct Entry: Codable {
            let fieldId: String
            let valueTimestamp: Date?
            let valueReference: String?
            let eventInstanceId: String

            enum CodingKeys: String, CodingKey {
                case fieldId = "field_id"
                case valueTimestamp = "value_timestamp"
                case valueReference = "value_reference"
                case eventInstanceId = "event_instance_id"
            }
        }

        // First, get START and END entries in date range (they have timestamps)
        let startEndResponse = try await supabase
            .from("patient_data_entries")
            .select("field_id, value_timestamp, value_reference, event_instance_id")
            .eq("patient_id", value: userId)
            .gte("value_timestamp", value: startDate.ISO8601Format())
            .lte("value_timestamp", value: endDate.ISO8601Format())
            .in("field_id", values: [
                "DEF_SLEEP_PERIOD_START",
                "DEF_SLEEP_PERIOD_END"
            ])
            .order("value_timestamp", ascending: true)
            .execute()

        let startEndEntries = try decoder.decode([Entry].self, from: startEndResponse.data)

        // Extract unique event_instance_ids from the START/END entries
        let eventInstanceIds = Array(Set(startEndEntries.map { $0.eventInstanceId }))

        guard !eventInstanceIds.isEmpty else {
            return []
        }

        // Now fetch TYPE entries for those specific event instances
        let typeResponse = try await supabase
            .from("patient_data_entries")
            .select("field_id, value_timestamp, value_reference, event_instance_id")
            .eq("patient_id", value: userId)
            .eq("field_id", value: "DEF_SLEEP_PERIOD_TYPE")
            .in("event_instance_id", values: eventInstanceIds)
            .execute()

        let typeEntries = try decoder.decode([Entry].self, from: typeResponse.data)

        // Combine all entries
        let entries = startEndEntries + typeEntries

        // Group entries by event_instance_id
        var instanceMap: [String: [Entry]] = [:]
        for entry in entries {
            instanceMap[entry.eventInstanceId, default: []].append(entry)
        }

        // Fetch sleep period types from universal reference table
        let typesResponse = try await supabase
            .from("data_entry_fields_reference")
            .select("id, reference_key, display_name")
            .eq("reference_category", value: "sleep_period_types")
            .execute()

        struct PeriodType: Codable {
            let id: String
            let referenceKey: String
            let displayName: String

            enum CodingKeys: String, CodingKey {
                case id
                case referenceKey = "reference_key"
                case displayName = "display_name"
            }
        }

        let periodTypes = try decoder.decode([PeriodType].self, from: typesResponse.data)
        let typeMap = Dictionary(uniqueKeysWithValues: periodTypes.map { ($0.id, $0.referenceKey) })

        var segments: [SleepStageSegment] = []

        for (_, instanceEntries) in instanceMap {
            guard instanceEntries.count == 3 else {
                continue
            }

            guard let startEntry = instanceEntries.first(where: { $0.fieldId == "DEF_SLEEP_PERIOD_START" }),
                  let endEntry = instanceEntries.first(where: { $0.fieldId == "DEF_SLEEP_PERIOD_END" }),
                  let typeEntry = instanceEntries.first(where: { $0.fieldId == "DEF_SLEEP_PERIOD_TYPE" }),
                  let startTime = startEntry.valueTimestamp,
                  let endTime = endEntry.valueTimestamp,
                  let typeId = typeEntry.valueReference,
                  let periodName = typeMap[typeId] else {
                continue
            }

            // Map period name to SleepStage enum
            let stage: SleepStage
            switch periodName.lowercased() {
            case "in_bed":
                stage = .inBed
            case "unspecified", "asleep":
                stage = .asleepUnspecified
            case "core":
                stage = .core
            case "deep":
                stage = .deep
            case "rem":
                stage = .rem
            case "awake":
                stage = .awake
            default:
                NSLog("[SLEEP] ⚠️ Unknown sleep period type: \(periodName)")
                continue
            }

            segments.append(SleepStageSegment(
                stage: stage,
                startTime: startTime,
                endTime: endTime
            ))
        }

        return segments.sorted { $0.startTime < $1.startTime }
    }

    /// Calculates summary metrics for a manual sleep entry
    func calculateMetricsForManualEntry(_ entry: ManualSleepEntry) {
        let calendar = Calendar.current

        // For manual entries, time in bed = time asleep = the duration between bedtime and waketime
        let durationMinutes = entry.sleepDuration / 60.0

        let hours = Int(durationMinutes / 60)
        let minutes = Int(durationMinutes.truncatingRemainder(dividingBy: 60))

        totalTimeInBed = "\(hours)h \(minutes)m"
        totalTimeAsleep = "\(hours)h \(minutes)m"

        // Format date
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        currentDateText = formatter.string(from: entry.date)
    }

    /// Calculates summary metrics from segments in the view window
    func calculateSummaryMetrics(for visibleSegments: [SleepStageSegment]) {
        // If there are segments, calculate normally
        if !visibleSegments.isEmpty {
            // TIME IN BED = sum of Deep + Core + REM + Awake in view window (excludes In Bed and Asleep Unspecified)
            let timeInBedSeconds = visibleSegments
                .filter { $0.stage == .deep || $0.stage == .core || $0.stage == .rem || $0.stage == .awake }
                .reduce(0.0) { total, segment in
                    total + segment.endTime.timeIntervalSince(segment.startTime)
                }

            // TIME ASLEEP = TIME IN BED - Awake time
            let awakeSeconds = visibleSegments
                .filter { $0.stage == .awake }
                .reduce(0.0) { total, segment in
                    total + segment.endTime.timeIntervalSince(segment.startTime)
                }

            let timeAsleepSeconds = timeInBedSeconds - awakeSeconds

            totalTimeInBed = formatDuration(timeInBedSeconds)
            totalTimeAsleep = formatDuration(timeAsleepSeconds)

            // Set date range based on visible window
            if let first = visibleSegments.first, let last = visibleSegments.last {
                currentDateText = formatDateRange(start: first.startTime, end: last.endTime)
            }

            NSLog("[SLEEP] ðŸ“Š Calculated metrics from visible segments: %@ in bed, %@ asleep", totalTimeInBed, totalTimeAsleep)
        }
    }
    
    /// Updates summary metrics for a date with no data
    func updateMetricsForNoData(date: Date) {
        totalTimeInBed = "No Data"
        totalTimeAsleep = "No Data"
        
        // Format the date to show which day has no data
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        currentDateText = formatter.string(from: date)
        
        NSLog("[SLEEP] ✅ No data available for date: %@", currentDateText)
    }
    
    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: end)
        
        return "\(startStr) - \(endStr)"
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    // MARK: - Week/Month View Methods

    /// Calculates total duration for each sleep stage
    private func calculateStageDurations(for segments: [SleepStageSegment]) -> (deep: TimeInterval, core: TimeInterval, rem: TimeInterval, awake: TimeInterval) {
        var deep: TimeInterval = 0
        var core: TimeInterval = 0
        var rem: TimeInterval = 0
        var awake: TimeInterval = 0

        for segment in segments {
            let duration = segment.endTime.timeIntervalSince(segment.startTime)
            switch segment.stage {
            case .deep:
                deep += duration
            case .core:
                core += duration
            case .rem:
                rem += duration
            case .awake:
                awake += duration
            case .inBed, .asleepUnspecified:
                // Don't count In Bed or Asleep Unspecified in duration calculations
                break
            }
        }

        return (deep, core, rem, awake)
    }

    /// Selects a bar and calculates its individual metrics
    func selectBar(_ bar: SleepBar) {
        selectedBar = bar
        selectedBarTimeInBed = formatDuration(bar.totalDuration)
        let timeAsleep = bar.totalDuration - bar.awakeDuration
        selectedBarTimeAsleep = formatDuration(timeAsleep)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d" // Match day view format
        selectedBarDate = formatter.string(from: bar.sleepDate)
        
        // Also update currentDateText to show selected date
        currentDateText = selectedBarDate
    }
    
    /// Clears bar selection
    func deselectBar() {
        selectedBar = nil
        selectedBarTimeInBed = "0h 0m"
        selectedBarTimeAsleep = "0h 0m"
        selectedBarDate = ""
    }
    
    // MARK: - Weekly Aggregation (6M View)
    
    /// Loads initial weekly averages for 6M view (need ~30 weeks = 26 visible + buffer)
    func loadInitialWeeklyAverages() async {
        guard !isLoading, weeklyAverages.isEmpty else {
            NSLog("[SLEEP] ⏭️ Skipping loadInitialWeeklyAverages - already loading or has data")
            return
        }
        
        isLoading = true

        let calendar = Calendar.current
        let now = Date()

        // Load more than view window (26 weeks) for infinite scroll buffer
        // View window = 26 weeks visible, but we load 30 weeks to have scroll buffer
        let rawStartDate = calendar.date(byAdding: .weekOfYear, value: -30, to: now) ?? now

        // Round start date to Monday (beginning of week) to align with cache period_start
        var startComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: rawStartDate)
        startComponents.weekday = 2 // Monday
        let startDate = calendar.date(from: startComponents) ?? rawStartDate

        // Round end date to NEXT Monday (start of next week) to include current week's period_start
        // Database stores weeks as Monday 00:00:00+00 to next Monday 00:00:00+00
        // Current week (Nov 3-9) has period_start = Nov 3, so we need to query up to Nov 10
        var endComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        endComponents.weekday = 2 // Monday (start of week)
        guard let currentWeekMonday = calendar.date(from: endComponents) else {
            let endDate = now
            NSLog("[SLEEP] 📅 loadInitialWeeklyAverages: from \(startDate) to \(endDate) (30 weeks = 26 view window + buffer)")
            let averages = (try? await calculateWeeklyAverages(from: startDate, to: endDate)) ?? []
            await MainActor.run {
                guard isLoading else { return }
                weeklyAverages = averages.sorted { $0.weekStartDate > $1.weekStartDate }
                weeklyDataStartDate = startDate
                weeklyDataEndDate = endDate
                isLoading = false
            }
            NSLog("[SLEEP] ✅ Loaded \(averages.count) weekly averages")
            return
        }
        // Add 7 days to get next Monday (to include current week)
        let endDate = calendar.date(byAdding: .day, value: 7, to: currentWeekMonday) ?? now

        NSLog("[SLEEP] 📅 loadInitialWeeklyAverages: from \(startDate) to \(endDate) (30 weeks = 26 view window + buffer)")

        let averages = (try? await calculateWeeklyAverages(from: startDate, to: endDate)) ?? []

        await MainActor.run {
            // Double-check we're still in a valid state
            guard isLoading else { return }
            weeklyAverages = averages.sorted { $0.weekStartDate > $1.weekStartDate }
            weeklyDataStartDate = startDate
            weeklyDataEndDate = endDate
            isLoading = false
        }

        NSLog("[SLEEP] ✅ Loaded \(averages.count) weekly averages")
    }
    
    /// Loads earlier weekly averages
    func loadEarlierWeeklyAverages() async {
        guard let currentStart = weeklyDataStartDate else { return }
        
        do {
            let calendar = Calendar.current
            
            // Load 15 more weeks going backwards
            let olderEnd = currentStart
            let olderStart = calendar.date(byAdding: .weekOfYear, value: -15, to: currentStart) ?? currentStart
            
            let olderAverages = try await calculateWeeklyAverages(from: olderStart, to: olderEnd)
            
            // Prepend older data (avoid duplicates)
            let existingWeekStarts = Set(weeklyAverages.map { Calendar.current.startOfDay(for: $0.weekStartDate) })
            let newAverages = olderAverages.filter { avg in
                !existingWeekStarts.contains(Calendar.current.startOfDay(for: avg.weekStartDate))
            }
            
            weeklyAverages = (newAverages + weeklyAverages).sorted { $0.weekStartDate > $1.weekStartDate }
            weeklyDataStartDate = olderStart
            
            NSLog("[SLEEP] ✅ Loaded \(olderAverages.count) earlier weekly averages. Total: \(weeklyAverages.count)")
            
        } catch {
            NSLog("[SLEEP] ❌ Error loading earlier weekly averages: \(error)")
        }
    }
    
    /// Loads later weekly averages
    func loadLaterWeeklyAverages() async {
        guard let currentEnd = weeklyDataEndDate else { return }
        
        do {
            let calendar = Calendar.current
            let now = Date()
            
            // Load up to 15 more weeks going forwards (or up to now)
            let newerStart = currentEnd
            let newerEnd = min(calendar.date(byAdding: .weekOfYear, value: 15, to: currentEnd) ?? now, now)
            
            guard newerStart < newerEnd else {
                NSLog("[SLEEP] ⚠️ Already at current date")
                return
            }
            
            let newerAverages = try await calculateWeeklyAverages(from: newerStart, to: newerEnd)
            
            // Append newer data (avoid duplicates)
            let existingWeekStarts = Set(weeklyAverages.map { Calendar.current.startOfDay(for: $0.weekStartDate) })
            let newAverages = newerAverages.filter { avg in
                !existingWeekStarts.contains(Calendar.current.startOfDay(for: avg.weekStartDate))
            }
            
            weeklyAverages = (weeklyAverages + newAverages).sorted { $0.weekStartDate > $1.weekStartDate }
            weeklyDataEndDate = newerEnd
            
            NSLog("[SLEEP] ✅ Loaded \(newerAverages.count) later weekly averages. Total: \(weeklyAverages.count)")
            
        } catch {
            NSLog("[SLEEP] ❌ Error loading later weekly averages: \(error)")
        }
    }
    
    /// Calculates weekly averages from sleep sessions
    private func calculateWeeklyAverages(from startDate: Date, to endDate: Date) async throws -> [WeeklyAverage] {
        // Fetch weekly aggregations from cache instead of calculating from raw sessions
        guard let userId = try? await supabase.auth.session.user.id else {
            NSLog("[SLEEP] ⚠️ No user session available for weekly averages")
            return []
        }

        do {
            struct WeeklyCacheEntry: Codable {
                let aggMetricId: String
                let periodStart: Date
                let periodEnd: Date
                let value: Double?
                let valueTime: String? // TIME field for bedtime/waketime (format: "HH:mm:ss" or "HH:mm")

                enum CodingKeys: String, CodingKey {
                    case aggMetricId = "agg_metric_id"
                    case periodStart = "period_start"
                    case periodEnd = "period_end"
                    case value
                    case valueTime = "value_time"
                }
            }

            // Convert dates to UTC ISO8601 strings for query
            // Use ISO8601DateFormatter to ensure proper UTC conversion
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            isoFormatter.timeZone = TimeZone(identifier: "UTC")!
            
            let startUTCString = isoFormatter.string(from: startDate)
            let endUTCString = isoFormatter.string(from: endDate)
            
            // For logging, create Date objects in UTC for display
            var utcCalendar = Calendar(identifier: .gregorian)
            utcCalendar.timeZone = TimeZone(identifier: "UTC")!
            let startComponents = utcCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: startDate)
            let endComponents = utcCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: endDate)
            let startUTC = utcCalendar.date(from: startComponents) ?? startDate
            let endUTC = utcCalendar.date(from: endComponents) ?? endDate

            NSLog("[SLEEP] 🔍 Fetching weekly averages from \(startUTC) to \(endUTC)")

            // Query pre-aggregated weekly averages from cache
            // For 6M view, we only need bedtime and waketime (value_time)
            let cacheResults: [WeeklyCacheEntry] = try await supabase
                .from("aggregation_results_cache")
                .select("agg_metric_id, period_start, period_end, value, value_time")
                .eq("patient_id", value: userId)
                .in("agg_metric_id", values: ["AGG_SLEEP_BEDTIME", "AGG_SLEEP_WAKETIME"])
                .eq("period_type", value: "weekly")
                .eq("calculation_type_id", value: "AVG")
                .gte("period_start", value: startUTCString)
                .lte("period_start", value: endUTCString)
                .order("period_start", ascending: true)
                .execute()
                .value

            NSLog("[SLEEP] 📊 Found \(cacheResults.count) weekly cache entries in query range")
            
            // Log all unique weeks found
            let uniqueWeeks = Set(cacheResults.map { utcCalendar.startOfDay(for: $0.periodStart) }).sorted()
            NSLog("[SLEEP] 📅 Unique weeks in cache: \(uniqueWeeks.map { utcCalendar.dateComponents([.year, .month, .day], from: $0) })")

            // Group by week start date
            let groupedByWeek = Dictionary(grouping: cacheResults) { entry -> Date in
                utcCalendar.startOfDay(for: entry.periodStart)
            }

            var averages: [WeeklyAverage] = []

            for weekStart in groupedByWeek.keys.sorted() {
                guard let entries = groupedByWeek[weekStart] else { continue }
                
                let weekLabel = utcCalendar.dateComponents([.year, .month, .day], from: weekStart)
                
                // STRICT VALIDATION: Must have exactly 2 entries (bedtime and waketime) in cache
                let bedtimeEntries = entries.filter { $0.aggMetricId == "AGG_SLEEP_BEDTIME" }
                let waketimeEntries = entries.filter { $0.aggMetricId == "AGG_SLEEP_WAKETIME" }
                
                // Must have exactly one entry for each metric
                guard bedtimeEntries.count == 1,
                      waketimeEntries.count == 1 else {
                    NSLog("[SLEEP] ⚠️ Week \(weekLabel) does NOT have exactly 2 cache entries (bedtime and waketime). Skipping.")
                    continue
                }
                
                // Extract values - now we know we have exactly one of each
                guard let bedtimeEntry = bedtimeEntries.first,
                      let waketimeEntry = waketimeEntries.first else {
                    NSLog("[SLEEP] ⚠️ Week \(weekLabel) failed to extract entries. Skipping.")
                    continue
                }
                
                // Validate values are present and valid
                guard let bedtimeTime = bedtimeEntry.valueTime,
                      !bedtimeTime.isEmpty,
                      let waketimeTime = waketimeEntry.valueTime,
                      !waketimeTime.isEmpty else {
                    NSLog("[SLEEP] ⚠️ Week \(weekLabel) has entries but invalid values - bedtime: \(bedtimeEntry.valueTime ?? "nil"), waketime: \(waketimeEntry.valueTime ?? "nil")")
                    continue
                }
                
                // Calculate weekEnd as Monday + 6 days = Sunday (Mon-Sun week)
                // Week runs from Monday 00:00:00+00 to next Monday 00:00:00+00 (exclusive)
                // Display shows Mon-Sun, so weekEnd = Sunday (Mon + 6 days)
                // Always calculate from weekStart to ensure correct 7-day week
                let weekEnd = utcCalendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
                
                // Verify: weekStart should be Monday, weekEnd should be Sunday
                let weekStartWeekday = utcCalendar.component(.weekday, from: weekStart)
                let weekEndWeekday = utcCalendar.component(.weekday, from: weekEnd)
                // weekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
                // So weekStart should be 2 (Monday), weekEnd should be 1 (Sunday)
                if weekStartWeekday != 2 || weekEndWeekday != 1 {
                    NSLog("[SLEEP] ⚠️ Week date calculation error: start weekday=\(weekStartWeekday), end weekday=\(weekEndWeekday)")
                }
                
                // Parse time strings (format: "HH:mm:ss" or "HH:mm") and create Date objects
                let bedtime = parseTimeString(bedtimeTime)
                let waketime = parseTimeString(waketimeTime)

                // For 6M view, we don't need timeInBed/timeAsleep (set to 0)
                averages.append(WeeklyAverage(
                    weekStartDate: weekStart,
                    weekEndDate: weekEnd,
                    avgTimeInBed: 0, // Not used in 6M view
                    avgTimeAsleep: 0, // Not used in 6M view
                    avgBedtime: bedtime,
                    avgWaketime: waketime
                ))
            }

            NSLog("[SLEEP] ✅ Calculated \(averages.count) weekly averages from cache")
            return averages

        } catch {
            // Ignore cancellation errors (expected when views are recreated)
            if let urlError = error as? URLError, urlError.code == .cancelled {
                NSLog("[SLEEP] ⏸️ Weekly averages fetch cancelled (view may have been recreated)")
                return []
            }
            NSLog("[SLEEP] ❌ Error fetching weekly averages from cache: \(error)")
            return []
        }
    }
    
    // MARK: - Monthly Aggregation (Y View)
    
    /// Loads initial monthly averages for Y view (exactly 12 months = full year)
    func loadInitialMonthlyAverages() async {
        guard !isLoading, monthlyAverages.isEmpty else {
            NSLog("[SLEEP] ⏭️ Skipping loadInitialMonthlyAverages - already loading or has data")
            return
        }
        
        isLoading = true

        let calendar = Calendar.current
        let now = Date()

        // Load more than view window (12 months) for infinite scroll buffer
        // View window = 12 months visible, but we load 15 months to have scroll buffer
        let rawStartDate = calendar.date(byAdding: .month, value: -15, to: now) ?? now

        // Round start date to 1st of month to align with cache period_start
        var startComponents = calendar.dateComponents([.year, .month], from: rawStartDate)
        startComponents.day = 1
        let startDate = calendar.date(from: startComponents) ?? rawStartDate

        // Round end date to last day of month containing today to capture full current month
        var endComponents = calendar.dateComponents([.year, .month], from: now)
        endComponents.day = 1
        guard let monthStart = calendar.date(from: endComponents),
              let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            NSLog("[SLEEP] ⚠️ Failed to calculate month end")
            isLoading = false
            return
        }
        let endDate = monthEnd

        NSLog("[SLEEP] 📅 loadInitialMonthlyAverages: from \(startDate) to \(endDate) (15 months = 12 view window + buffer)")

        let averages = (try? await calculateMonthlyAverages(from: startDate, to: endDate)) ?? []

        await MainActor.run {
            // Double-check we're still in a valid state
            guard isLoading else { return }
            monthlyAverages = averages.sorted { $0.monthStartDate > $1.monthStartDate }
            monthlyDataStartDate = startDate
            monthlyDataEndDate = endDate
            isLoading = false
        }

        NSLog("[SLEEP] ✅ Loaded \(averages.count) monthly averages")
    }
    
    /// Loads earlier monthly averages
    func loadEarlierMonthlyAverages() async {
        guard let currentStart = monthlyDataStartDate else { return }
        
        do {
            let calendar = Calendar.current
            
            // Load 6 more months going backwards
            let olderEnd = currentStart
            let olderStart = calendar.date(byAdding: .month, value: -6, to: currentStart) ?? currentStart
            
            let olderAverages = try await calculateMonthlyAverages(from: olderStart, to: olderEnd)
            
            // Prepend older data (avoid duplicates)
            let existingMonthStarts = Set(monthlyAverages.map { Calendar.current.startOfDay(for: $0.monthStartDate) })
            let newAverages = olderAverages.filter { avg in
                !existingMonthStarts.contains(Calendar.current.startOfDay(for: avg.monthStartDate))
            }
            
            monthlyAverages = (newAverages + monthlyAverages).sorted { $0.monthStartDate > $1.monthStartDate }
            monthlyDataStartDate = olderStart
            
            NSLog("[SLEEP] ✅ Loaded \(olderAverages.count) earlier monthly averages. Total: \(monthlyAverages.count)")
            
        } catch {
            NSLog("[SLEEP] ❌ Error loading earlier monthly averages: \(error)")
        }
    }
    
    /// Loads later monthly averages
    func loadLaterMonthlyAverages() async {
        guard let currentEnd = monthlyDataEndDate else { return }
        
        do {
            let calendar = Calendar.current
            let now = Date()
            
            // Load up to 6 more months going forwards (or up to now)
            let newerStart = currentEnd
            let newerEnd = min(calendar.date(byAdding: .month, value: 6, to: currentEnd) ?? now, now)
            
            guard newerStart < newerEnd else {
                NSLog("[SLEEP] ⚠️ Already at current date")
                return
            }
            
            let newerAverages = try await calculateMonthlyAverages(from: newerStart, to: newerEnd)
            
            // Append newer data (avoid duplicates)
            let existingMonthStarts = Set(monthlyAverages.map { Calendar.current.startOfDay(for: $0.monthStartDate) })
            let newAverages = newerAverages.filter { avg in
                !existingMonthStarts.contains(Calendar.current.startOfDay(for: avg.monthStartDate))
            }
            
            monthlyAverages = (monthlyAverages + newAverages).sorted { $0.monthStartDate > $1.monthStartDate }
            monthlyDataEndDate = newerEnd
            
            NSLog("[SLEEP] ✅ Loaded \(newerAverages.count) later monthly averages. Total: \(monthlyAverages.count)")
            
        } catch {
            NSLog("[SLEEP] ❌ Error loading later monthly averages: \(error)")
        }
    }
    
    /// Calculates monthly averages from sleep sessions
    private func calculateMonthlyAverages(from startDate: Date, to endDate: Date) async throws -> [MonthlyAverage] {
        // Fetch monthly aggregations from cache instead of calculating from raw sessions
        guard let userId = try? await supabase.auth.session.user.id else {
            NSLog("[SLEEP] ⚠️ No user session available for monthly averages")
            return []
        }

        do {
            struct MonthlyCacheEntry: Codable {
                let aggMetricId: String
                let periodStart: Date
                let periodEnd: Date
                let value: Double?
                let valueTime: String? // TIME field for bedtime/waketime (format: "HH:mm:ss" or "HH:mm")

                enum CodingKeys: String, CodingKey {
                    case aggMetricId = "agg_metric_id"
                    case periodStart = "period_start"
                    case periodEnd = "period_end"
                    case value
                    case valueTime = "value_time"
                }
            }

            var utcCalendar = Calendar(identifier: .gregorian)
            utcCalendar.timeZone = TimeZone(identifier: "UTC")!

            let localCalendar = Calendar.current
            let startComponents = localCalendar.dateComponents([.year, .month, .day], from: startDate)
            let endComponents = localCalendar.dateComponents([.year, .month, .day], from: endDate)

            guard let startUTC = utcCalendar.date(from: startComponents),
                  let endUTC = utcCalendar.date(from: endComponents) else {
                NSLog("[SLEEP] ⚠️ Failed to convert dates to UTC")
                return []
            }

            NSLog("[SLEEP] 🔍 Fetching monthly averages from \(startUTC) to \(endUTC)")

            // Query pre-aggregated monthly averages from cache
            // For Y view, we only need bedtime and waketime (value_time)
            let cacheResults: [MonthlyCacheEntry] = try await supabase
                .from("aggregation_results_cache")
                .select("agg_metric_id, period_start, period_end, value, value_time")
                .eq("patient_id", value: userId)
                .in("agg_metric_id", values: ["AGG_SLEEP_BEDTIME", "AGG_SLEEP_WAKETIME"])
                .eq("period_type", value: "monthly")
                .eq("calculation_type_id", value: "AVG")
                .gte("period_start", value: startUTC.ISO8601Format())
                .lte("period_start", value: endUTC.ISO8601Format())
                .order("period_start", ascending: true)
                .execute()
                .value

            NSLog("[SLEEP] 📊 Found \(cacheResults.count) monthly cache entries in query range")
            
            // Log all unique months found
            let uniqueMonths = Set(cacheResults.map { utcCalendar.startOfDay(for: $0.periodStart) }).sorted()
            NSLog("[SLEEP] 📅 Unique months in cache: \(uniqueMonths.map { utcCalendar.dateComponents([.year, .month], from: $0) })")

            // Group by month
            let groupedByMonth = Dictionary(grouping: cacheResults) { entry -> Date in
                utcCalendar.startOfDay(for: entry.periodStart)
            }

            var averages: [MonthlyAverage] = []

            for monthStart in groupedByMonth.keys.sorted() {
                guard let entries = groupedByMonth[monthStart] else { continue }
                
                let monthLabel = utcCalendar.dateComponents([.year, .month], from: monthStart)
                
                // STRICT VALIDATION: Must have exactly 2 entries (bedtime and waketime) in cache
                let bedtimeEntries = entries.filter { $0.aggMetricId == "AGG_SLEEP_BEDTIME" }
                let waketimeEntries = entries.filter { $0.aggMetricId == "AGG_SLEEP_WAKETIME" }
                
                // Log what we found for this month
                NSLog("[SLEEP] 🔍 Month \(monthLabel): bedtime entries: \(bedtimeEntries.count), waketime: \(waketimeEntries.count)")
                
                // Must have exactly one entry for each metric
                guard bedtimeEntries.count == 1,
                      waketimeEntries.count == 1 else {
                    NSLog("[SLEEP] ⚠️ Month \(monthLabel) does NOT have exactly 2 cache entries (bedtime and waketime). Skipping.")
                    continue
                }
                
                // Extract values - now we know we have exactly one of each
                guard let bedtimeEntry = bedtimeEntries.first,
                      let waketimeEntry = waketimeEntries.first else {
                    NSLog("[SLEEP] ⚠️ Month \(monthLabel) failed to extract entries. Skipping.")
                    continue
                }
                
                // Validate values are present and valid
                guard let bedtimeTime = bedtimeEntry.valueTime,
                      !bedtimeTime.isEmpty,
                      let waketimeTime = waketimeEntry.valueTime,
                      !waketimeTime.isEmpty else {
                    NSLog("[SLEEP] ⚠️ Month \(monthLabel) has entries but invalid values - bedtime: \(bedtimeEntry.valueTime ?? "nil"), waketime: \(waketimeEntry.valueTime ?? "nil")")
                    continue
                }
                
                NSLog("[SLEEP] ✅ Including month \(monthLabel) - confirmed 2 cache entries with valid values")

                // Calculate monthEnd as start of next month - 1 day (last day of the month)
                let monthEnd: Date
                if let periodEnd = entries.first?.periodEnd, periodEnd != monthStart {
                    monthEnd = utcCalendar.startOfDay(for: periodEnd)
                } else {
                    // Calculate last day of month
                    if let nextMonth = utcCalendar.date(byAdding: .month, value: 1, to: monthStart),
                       let lastDay = utcCalendar.date(byAdding: .day, value: -1, to: nextMonth) {
                        monthEnd = utcCalendar.startOfDay(for: lastDay)
                    } else {
                        monthEnd = monthStart
                    }
                }
                
                // Parse time strings (format: "HH:mm:ss" or "HH:mm") and create Date objects
                let bedtime = parseTimeString(bedtimeTime)
                let waketime = parseTimeString(waketimeTime)

                // For Y view, we don't need timeInBed/timeAsleep (set to 0)
                averages.append(MonthlyAverage(
                    monthStartDate: monthStart,
                    monthEndDate: monthEnd,
                    avgTimeInBed: 0, // Not used in Y view
                    avgTimeAsleep: 0, // Not used in Y view
                    avgBedtime: bedtime,
                    avgWaketime: waketime
                ))
            }

            NSLog("[SLEEP] ✅ Calculated \(averages.count) monthly averages from cache")
            return averages

        } catch {
            // Ignore cancellation errors (expected when views are recreated)
            if let urlError = error as? URLError, urlError.code == .cancelled {
                NSLog("[SLEEP] ⏸️ Monthly averages fetch cancelled (view may have been recreated)")
                return []
            }
            NSLog("[SLEEP] ❌ Error fetching monthly averages from cache: \(error)")
            return []
        }
    }
    
    // MARK: - Helper: Parse time string to Date
    
    /// Parses a time string (e.g., "23:00:00" or "07:00") and returns a Date with today's date and that time
    private func parseTimeString(_ timeString: String) -> Date {
        let components = timeString.split(separator: ":").map { String($0) }
        guard components.count >= 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            // Fallback to 11 PM if parsing fails
            let calendar = Calendar.current
            return calendar.date(bySettingHour: 23, minute: 0, second: 0, of: Date()) ?? Date()
        }

        let calendar = Calendar.current
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
}

// MARK: - Shared Data Models

struct AggregationResult: Codable {
    let aggMetricId: String
    let periodType: String
    let periodStart: Date
    let periodEnd: Date
    let value: Double

    enum CodingKeys: String, CodingKey {
        case aggMetricId = "agg_metric_id"
        case periodType = "period_type"
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case value
    }
}