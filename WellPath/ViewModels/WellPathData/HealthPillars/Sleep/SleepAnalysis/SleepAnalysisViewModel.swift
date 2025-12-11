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
    let asleepDuration: TimeInterval  // Basic asleep (no detailed stages)
    let inBedDuration: TimeInterval   // Time in bed (before sleep/after wake)

    var totalDuration: TimeInterval {
        deepDuration + coreDuration + remDuration + awakeDuration + asleepDuration
    }

    var totalTimeInBed: TimeInterval {
        sessionEnd.timeIntervalSince(sessionStart)
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

// MARK: - Sleep Session Data Type Classification
/// Classifies the type of sleep data available in a session
enum SleepSessionDataType {
    case fullStages          // Has REM, Core, or Deep stages
    case basicSleep(hasInBed: Bool)  // Only asleep ± in_bed (HealthKit limited)
    case manual(hasInBed: Bool)      // Manual entry from wellpath_input
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

    // Primary session bedtime/waketime from database view (for mini cards)
    // These are calculated from the PRIMARY session only (longest session starting before 4AM)
    @Published var primaryBedtime: Date?
    @Published var primaryWaketime: Date?
    @Published var latestSleepDate: Date?
    
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
    
    // No longer using aggregation cache - queries patient_category_samples directly via PatientSamplesQueryService

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

            // Fetch primary bedtime/waketime from database view (for mini cards)
            await loadPrimaryBedtimeWaketime()

            NSLog("[SLEEP] ✅ Loaded \(sleepStageSegments.count) sleep stage segments across \(sleepSessions.count) days (including empty)")

        } catch {
            NSLog("[SLEEP] ❌ Error loading initial sleep stages: \(error.localizedDescription)")
        }

        isLoading = false
    }
    
    // MARK: - Sleep Data Queries (Using PatientSamplesQueryService)

    /// No longer using aggregation cache - all queries go through PatientSamplesQueryService
    /// which queries patient_category_samples directly for sleep stage data
    
    /// Creates a session for each day, even if no data exists
    private func createSessionsIncludingEmptyDays(segments: [SleepStageSegment], startDate: Date, endDate: Date, manualEntries: [ManualSleepEntry] = []) -> [SleepSession] {
        let calendar = Calendar.current
        var sessions: [SleepSession] = []

        // Group segments by sleep session (gaps > 2 hours)
        let dataSessionGroups = groupIntoSleepSessions(segments)

        // Create a dictionary mapping dates to ALL segments (combining multiple sessions per day)
        // Use aggregationDate from database (6PM rule) instead of calculating from endTime
        var dateToSegments: [Date: [SleepStageSegment]] = [:]
        for sessionGroup in dataSessionGroups {
            guard let lastSegment = sessionGroup.last else { continue }

            // Use the database-calculated aggregationDate (6PM rule) from any segment in the group
            // Sleep ending between 6PM Mon and 6PM Tue → assigned to Tuesday
            // Fall back to startOfDay(for: endTime) only if aggregationDate is missing
            let sessionEndDate: Date
            if let aggDate = lastSegment.aggregationDate {
                sessionEndDate = calendar.startOfDay(for: aggDate)
            } else {
                // Fallback for legacy data without aggregationDate
                sessionEndDate = calendar.startOfDay(for: lastSegment.endTime)
            }

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

    /// Fetch sleep stages using PatientSamplesQueryService which queries patient_category_samples
    /// Returns actual sleep stage segments with real start/end times for proper hypnogram display
    private func fetchSleepStages(from startDate: Date, to endDate: Date) async throws -> [SleepStageSegment] {
        // Use PatientSamplesQueryService to fetch raw sleep stage samples with actual timestamps
        let rawStages = try await PatientSamplesQueryService.shared.fetchRawSleepStages(
            startDate: startDate,
            endDate: endDate
        )

        NSLog("[SLEEP] 📊 PatientSamplesQueryService returned \(rawStages.count) raw sleep stage samples")

        // Convert raw samples to SleepStageSegment with actual timestamps
        var segments: [SleepStageSegment] = []

        for sample in rawStages {
            guard let endTime = sample.endTime else { continue }

            // Map the categoryValue string to SleepStage enum
            let stage: SleepStage
            switch sample.categoryValue {
            case "deep":
                stage = .deep
            case "core":
                stage = .core
            case "rem":
                stage = .rem
            case "awake":
                stage = .awake
            default:
                // Skip unknown stage types
                continue
            }

            segments.append(SleepStageSegment(
                stage: stage,
                startTime: sample.startTime,
                endTime: endTime,
                userTimezone: "UTC",
                aggregationDate: sample.aggregationDate  // 6PM rule already applied in database
            ))
        }

        NSLog("[SLEEP] ✅ Converted to \(segments.count) SleepStageSegments with real timestamps")
        return segments
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
            // TIME IN BED = sum of all sleep stages in view window (excludes only In Bed to avoid double-counting)
            // Includes asleepUnspecified for basic sessions
            let timeInBedSeconds = visibleSegments
                .filter { $0.stage != .inBed }
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
            case .asleep:
                // Map basic sleep to core for rendering
                core += duration
            case .inBed, .asleepSummary:
                // Don't count In Bed or Asleep Summary in duration calculations
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
    
    /// Calculates weekly averages using pre-computed database view
    private func calculateWeeklyAverages(from startDate: Date, to endDate: Date) async throws -> [WeeklyAverage] {
        // Use the view-based method for efficient pre-computed aggregations
        return try await PatientSamplesQueryService.shared.fetchWeeklyAveragesFromView(
            startDate: startDate,
            endDate: endDate
        )
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
    
    /// Calculates monthly averages using pre-computed database view
    private func calculateMonthlyAverages(from startDate: Date, to endDate: Date) async throws -> [MonthlyAverage] {
        // Use the view-based method for efficient pre-computed aggregations
        return try await PatientSamplesQueryService.shared.fetchMonthlyAveragesFromView(
            startDate: startDate,
            endDate: endDate
        )
    }
    
    // MARK: - Helper: Session Type Detection

    /// Detects the type of sleep data available in a session
    /// - Parameter session: The sleep session to analyze
    /// - Returns: Classification of the session data type
    private func detectSessionType(_ session: SleepSession) -> SleepSessionDataType {
        let stages = Set(session.segments.map { $0.stage })

        // Check if manual entry (from wellpath_input source)
        if session.isManual {
            return .manual(hasInBed: stages.contains(.inBed))
        }

        // Check for detailed HealthKit stages (REM, Core, or Deep)
        if stages.intersection([.deep, .core, .rem]).isEmpty == false {
            return .fullStages
        }

        // Basic sleep only (asleep ± in_bed from limited HealthKit)
        return .basicSleep(hasInBed: stages.contains(.inBed))
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

    // MARK: - Helper: Calculate offset from 6PM for time averaging

    /// Calculates minutes offset from 6PM for averaging sleep times across midnight
    /// - Parameters:
    ///   - time: The time to calculate offset for
    ///   - calendar: Calendar to use for date components
    /// - Returns: Minutes since 6PM (e.g., 11 PM = 300, 7 AM = 780)
    private func calculateOffsetFromSixPM(_ time: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: time)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let totalMinutes = hour * 60 + minute

        // If time is before 6PM (18:00), it's the next day - add 24 hours
        // e.g., 7 AM = 7*60 = 420 minutes -> 420 + 1080 (18 hours) = 1500 minutes from 6PM yesterday
        // e.g., 11 PM = 23*60 = 1380 minutes -> 1380 - 1080 = 300 minutes from 6PM
        if totalMinutes < 1080 { // 18:00 = 1080 minutes
            return totalMinutes + 1440 - 1080 // Add to next day then subtract 6PM offset
        } else {
            return totalMinutes - 1080 // Subtract 6PM offset
        }
    }

    /// Converts minutes offset from 6PM back to a Date
    /// - Parameters:
    ///   - offset: Minutes since 6PM
    ///   - calendar: Calendar to use
    /// - Returns: A Date representing the time
    private func offsetToTime(_ offset: Int, calendar: Calendar) -> Date {
        // Add offset to 6PM reference
        let sixPMMinutes = 1080 // 18:00
        var totalMinutes = sixPMMinutes + offset

        // Wrap around if past midnight (1440 minutes)
        if totalMinutes >= 1440 {
            totalMinutes -= 1440
        }

        let hour = totalMinutes / 60
        let minute = totalMinutes % 60

        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    // MARK: - Primary Bedtime/Waketime from Database View

    /// Fetches primary bedtime/waketime from the database view for the most recent day with data.
    /// The database view calculates these from the PRIMARY session only (longest session starting before 4AM).
    /// This ensures all mini cards show consistent bedtime/waketime from the same source.
    func loadPrimaryBedtimeWaketime() async {
        do {
            let calendar = Calendar.current
            let endDate = Date()
            let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate

            let summaries = try await PatientSamplesQueryService.shared.fetchSleepSessionSummaries(
                startDate: startDate,
                endDate: endDate
            )

            // Find the most recent day with bedtime/waketime data
            // summaries are already sorted descending by sleep_date
            if let mostRecent = summaries.first {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"

                self.primaryBedtime = mostRecent.bedtime
                self.primaryWaketime = mostRecent.waketime
                self.latestSleepDate = dateFormatter.date(from: mostRecent.sleepDate)

                NSLog("[SLEEP] ✅ Loaded primary bedtime/waketime from database view: bedtime=\(mostRecent.bedtime), waketime=\(mostRecent.waketime)")
            } else {
                self.primaryBedtime = nil
                self.primaryWaketime = nil
                self.latestSleepDate = nil
                NSLog("[SLEEP] ⚠️ No sleep summaries found in database view")
            }
        } catch {
            NSLog("[SLEEP] ❌ Error loading primary bedtime/waketime: \(error)")
            self.primaryBedtime = nil
            self.primaryWaketime = nil
            self.latestSleepDate = nil
        }
    }
}

// MARK: - Shared Data Models
// Note: AggregationResult struct removed - no longer using aggregation_results_cache
