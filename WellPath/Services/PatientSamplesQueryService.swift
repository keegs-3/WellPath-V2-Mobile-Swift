//
//  PatientSamplesQueryService.swift
//  WellPath
//
//  Direct sample query service - replaces aggregation_results_cache approach
//  Queries the specialized sample tables (patient_quantity_samples, patient_category_samples)
//  and aggregates in Swift for simpler data management
//

import Foundation
import Supabase

// MARK: - Query Result Models

struct CorrelationSampleResult: Codable {
    let id: UUID
    let patientId: UUID
    let correlationType: String
    let components: [String: Double]
    let sampleTime: Date
    let source: String
    let deviceInfo: [String: AnyJSON]?
    let metadata: [String: AnyJSON]?
    let userTimezone: String
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case correlationType = "correlation_type"
        case components
        case sampleTime = "sample_time"
        case source
        case deviceInfo = "device_info"
        case metadata
        case userTimezone = "user_timezone"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct QuantitySampleResult: Codable {
    let id: UUID
    let aggregationDateString: String?
    let startTime: Date
    let endTime: Date?
    let quantityValue: Double?
    let quantityUnit: String?
    let quantityType: String?
    let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id
        case aggregationDateString = "aggregation_date"
        case startTime = "start_time"
        case endTime = "end_time"
        case quantityValue = "quantity_value"
        case quantityUnit = "quantity_unit"
        case quantityType = "quantity_type"
        case metadata
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

struct SleepStageSampleResult: Codable {
    let id: UUID
    let sleepSessionId: UUID?
    let aggregationDateString: String?
    let categoryValue: String?  // String key (awake, rem, core, deep)
    let startTime: Date
    let endTime: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case sleepSessionId = "sleep_session_id"
        case aggregationDateString = "aggregation_date"
        case categoryValue = "category_value"
        case startTime = "start_time"
        case endTime = "end_time"
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

    var sleepStage: SleepStageType {
        // categoryValue is now a string key matching sample_category_types_reference
        guard let value = categoryValue else { return .awake }
        return SleepStageType(rawValue: value) ?? .awake
    }

    var durationSeconds: Double {
        guard let end = endTime else { return 0 }
        return end.timeIntervalSince(startTime)
    }
}

enum SleepStageType: String {
    // String keys matching sample_category_types_reference
    case awake = "awake"
    case rem = "rem"
    case core = "core"
    case deep = "deep"
}

struct DailyAggregatedValue {
    let date: Date
    let value: Double
    let count: Int
}

// Database row model for patient_sleep_sessions_summary view
// Note: PostgreSQL numeric/bigint types are serialized as strings in JSON
struct SleepSessionSummaryRow: Codable {
    let sleepDate: String
    let sessionCount: Int  // Number of sleep sessions (main + naps)
    let sessionStart: Date
    let sessionEnd: Date
    let bedtime: Date
    let waketime: Date
    let deepMinutes: Double
    let remMinutes: Double
    let lightMinutes: Double
    let awakeMinutes: Double
    let totalSleepMinutes: Double
    let timeInBedMinutes: Double
    let totalSleepHours: Double
    let sleepEfficiency: Double
    // Rolling 7-day averages
    let avgBedtimeOffset7d: Double?
    let avgWaketimeOffset7d: Double?
    let avgSleepMinutes7d: Double?
    let avgDeepMinutes7d: Double?
    let avgRemMinutes7d: Double?
    let avgLightMinutes7d: Double?
    let daysInRolling7d: Int?
    // Consistency flags
    let bedtimeInRange: Bool?
    let waketimeInRange: Bool?

    enum CodingKeys: String, CodingKey {
        case sleepDate = "sleep_date"
        case sessionCount = "session_count"
        case sessionStart = "session_start"
        case sessionEnd = "session_end"
        case bedtime
        case waketime
        case deepMinutes = "deep_minutes"
        case remMinutes = "rem_minutes"
        case lightMinutes = "light_minutes"
        case awakeMinutes = "awake_minutes"
        case totalSleepMinutes = "total_sleep_minutes"
        case timeInBedMinutes = "time_in_bed_minutes"
        case totalSleepHours = "total_sleep_hours"
        case sleepEfficiency = "sleep_efficiency"
        case avgBedtimeOffset7d = "avg_bedtime_offset_7d"
        case avgWaketimeOffset7d = "avg_waketime_offset_7d"
        case avgSleepMinutes7d = "avg_sleep_minutes_7d"
        case avgDeepMinutes7d = "avg_deep_minutes_7d"
        case avgRemMinutes7d = "avg_rem_minutes_7d"
        case avgLightMinutes7d = "avg_light_minutes_7d"
        case daysInRolling7d = "days_in_rolling_7d"
        case bedtimeInRange = "bedtime_in_range"
        case waketimeInRange = "waketime_in_range"
    }

    // Custom decoder to handle PostgreSQL numeric types (returned as strings in JSON)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        sleepDate = try container.decode(String.self, forKey: .sleepDate)
        sessionStart = try container.decode(Date.self, forKey: .sessionStart)
        sessionEnd = try container.decode(Date.self, forKey: .sessionEnd)
        bedtime = try container.decode(Date.self, forKey: .bedtime)
        waketime = try container.decode(Date.self, forKey: .waketime)
        bedtimeInRange = try container.decodeIfPresent(Bool.self, forKey: .bedtimeInRange)
        waketimeInRange = try container.decodeIfPresent(Bool.self, forKey: .waketimeInRange)

        // Handle bigint/numeric that may come as string or number
        sessionCount = try Self.decodeInt(from: container, forKey: .sessionCount) ?? 0
        daysInRolling7d = try Self.decodeIntIfPresent(from: container, forKey: .daysInRolling7d)

        // Handle numeric fields that may come as string or number
        deepMinutes = try Self.decodeDouble(from: container, forKey: .deepMinutes) ?? 0
        remMinutes = try Self.decodeDouble(from: container, forKey: .remMinutes) ?? 0
        lightMinutes = try Self.decodeDouble(from: container, forKey: .lightMinutes) ?? 0
        awakeMinutes = try Self.decodeDouble(from: container, forKey: .awakeMinutes) ?? 0
        totalSleepMinutes = try Self.decodeDouble(from: container, forKey: .totalSleepMinutes) ?? 0
        timeInBedMinutes = try Self.decodeDouble(from: container, forKey: .timeInBedMinutes) ?? 0
        totalSleepHours = try Self.decodeDouble(from: container, forKey: .totalSleepHours) ?? 0
        sleepEfficiency = try Self.decodeDouble(from: container, forKey: .sleepEfficiency) ?? 0

        avgBedtimeOffset7d = try Self.decodeDoubleIfPresent(from: container, forKey: .avgBedtimeOffset7d)
        avgWaketimeOffset7d = try Self.decodeDoubleIfPresent(from: container, forKey: .avgWaketimeOffset7d)
        avgSleepMinutes7d = try Self.decodeDoubleIfPresent(from: container, forKey: .avgSleepMinutes7d)
        avgDeepMinutes7d = try Self.decodeDoubleIfPresent(from: container, forKey: .avgDeepMinutes7d)
        avgRemMinutes7d = try Self.decodeDoubleIfPresent(from: container, forKey: .avgRemMinutes7d)
        avgLightMinutes7d = try Self.decodeDoubleIfPresent(from: container, forKey: .avgLightMinutes7d)
    }

    // Helper to decode Double from either string or number
    private static func decodeDouble(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Double? {
        if let doubleVal = try? container.decode(Double.self, forKey: key) {
            return doubleVal
        }
        if let stringVal = try? container.decode(String.self, forKey: key) {
            return Double(stringVal)
        }
        return nil
    }

    private static func decodeDoubleIfPresent(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Double? {
        if let doubleVal = try? container.decodeIfPresent(Double.self, forKey: key) {
            return doubleVal
        }
        if let stringVal = try? container.decodeIfPresent(String.self, forKey: key) {
            return Double(stringVal ?? "")
        }
        return nil
    }

    // Helper to decode Int from either string or number
    private static func decodeInt(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Int? {
        if let intVal = try? container.decode(Int.self, forKey: key) {
            return intVal
        }
        if let stringVal = try? container.decode(String.self, forKey: key) {
            return Int(stringVal)
        }
        return nil
    }

    private static func decodeIntIfPresent(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Int? {
        if let intVal = try? container.decodeIfPresent(Int.self, forKey: key) {
            return intVal
        }
        if let stringVal = try? container.decodeIfPresent(String.self, forKey: key) {
            return Int(stringVal ?? "")
        }
        return nil
    }
}

/// Per-day sleep stage data for charts
struct DailySleepStageData {
    let date: Date
    let deepMinutes: Double
    let remMinutes: Double
    let coreMinutes: Double
    let awakeMinutes: Double
    let sleepDurationMinutes: Double  // Deep + REM + Core
    let timeInBedMinutes: Double      // Sleep + Awake
}

@MainActor
class PatientSamplesQueryService {
    static let shared = PatientSamplesQueryService()
    private let supabase = SupabaseManager.shared.client
    private init() {}

    // MARK: - Correlation Samples
    func fetchCorrelationSamples(
        correlationType: String,
        startDate: Date,
        endDate: Date
    ) async throws -> [CorrelationSampleResult] {
        let userId = try await supabase.auth.session.user.id
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let startStr = formatter.string(from: startDate)
        let endStr = formatter.string(from: endDate)
        return try await supabase
            .from("patient_correlation_samples")
            .select("id, patient_id, correlation_type, components, sample_time, source, device_info, metadata, user_timezone, created_at, updated_at")
            .eq("patient_id", value: userId)
            .eq("correlation_type", value: correlationType)
            .eq("is_primary", value: true)  // Only use primary samples for analysis
            .gte("sample_time", value: startStr)
            .lte("sample_time", value: endStr)
            .order("sample_time", ascending: true)
            .execute()
            .value
    }

    // MARK: - Quantity Samples
    func fetchQuantityDaily(
        quantityType: String,
        startDate: Date,
        endDate: Date
    ) async throws -> [DailyAggregatedValue] {
        let userId = try await supabase.auth.session.user.id
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let startStr = formatter.string(from: startDate)
        let endStr = formatter.string(from: endDate)
        let results: [QuantitySampleResult] = try await supabase
            .from("patient_quantity_samples")
            .select("id, aggregation_date, start_time, end_time, quantity_value, quantity_unit, quantity_type, metadata")
            .eq("patient_id", value: userId)
            .eq("quantity_type", value: quantityType)
            .eq("is_primary", value: true)  // Only use primary samples for analysis
            .gte("aggregation_date", value: startStr)
            .lte("aggregation_date", value: endStr)
            .order("aggregation_date", ascending: true)
            .execute()
            .value
        var dailyTotals: [Date: (value: Double, count: Int)] = [:]
        for sample in results {
            guard let date = sample.aggregationDate, let value = sample.quantityValue else { continue }
            let current = dailyTotals[date] ?? (0, 0)
            dailyTotals[date] = (current.value + value, current.count + 1)
        }
        return dailyTotals.map { DailyAggregatedValue(date: $0.key, value: $0.value.value, count: $0.value.count) }.sorted { $0.date < $1.date }
    }

    func fetchQuantityTimeSeries(
        quantityType: String,
        period: TimePeriod,
        date: Date
    ) async throws -> [(date: Date, value: Double)] {
        let (startDate, endDate) = getDateRange(for: period, date: date)
        let dailyValues = try await fetchQuantityDaily(
            quantityType: quantityType,
            startDate: startDate,
            endDate: endDate
        )
        return dailyValues.map { ($0.date, $0.value) }
    }

    func fetchQuantityValue(
        quantityType: String,
        period: TimePeriod,
        date: Date
    ) async throws -> Double? {
        let (startDate, endDate) = getDateRange(for: period, date: date)
        let dailyValues = try await fetchQuantityDaily(
            quantityType: quantityType,
            startDate: startDate,
            endDate: endDate
        )
        guard !dailyValues.isEmpty else { return nil }
        let values = dailyValues.map { $0.value }
        return values.reduce(0, +)
    }

    // MARK: - Sleep Data

    /// Fetch pre-computed sleep session summaries from database view
    /// Use this for charts, bars, and consistency metrics - NOT for hypnograms
    func fetchSleepSessionSummaries(
        startDate: Date,
        endDate: Date
    ) async throws -> [SleepSessionSummaryRow] {
        let userId = try await supabase.auth.session.user.id
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let startStr = formatter.string(from: startDate)
        let endStr = formatter.string(from: endDate)

        return try await supabase
            .from("patient_sleep_sessions_summary")
            .select("*")
            .eq("patient_id", value: userId)
            .gte("sleep_date", value: startStr)
            .lte("sleep_date", value: endStr)
            .order("sleep_date", ascending: false)
            .execute()
            .value
    }

    /// Fetch raw sleep stage samples with actual start/end times for each stage transition
    /// Use this for hypnogram display that shows real stage cycling
    func fetchRawSleepStages(
        startDate: Date,
        endDate: Date
    ) async throws -> [SleepStageSampleResult] {
        let userId = try await supabase.auth.session.user.id
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let startStr = formatter.string(from: startDate)
        let endStr = formatter.string(from: endDate)
        return try await supabase
            .from("patient_category_samples")
            .select("id, sleep_session_id, aggregation_date, category_value, start_time, end_time")
            .eq("patient_id", value: userId)
            .eq("category_type", value: "sleep_period_types")
            .eq("is_primary", value: true)
            .gte("aggregation_date", value: startStr)
            .lte("aggregation_date", value: endStr)
            .order("start_time", ascending: true)
            .execute()
            .value
    }

    /// Fetch daily sleep duration using pre-computed database view
    func fetchSleepDurationDaily(
        startDate: Date,
        endDate: Date
    ) async throws -> [DailyAggregatedValue] {
        let summaries = try await fetchSleepSessionSummaries(startDate: startDate, endDate: endDate)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return summaries.compactMap { row -> DailyAggregatedValue? in
            guard let date = dateFormatter.date(from: row.sleepDate) else { return nil }
            return DailyAggregatedValue(
                date: date,
                value: row.totalSleepMinutes,
                count: row.sessionCount
            )
        }.sorted { $0.date < $1.date }
    }

    func fetchSleepTimeSeries(
        period: TimePeriod,
        date: Date
    ) async throws -> [(date: Date, value: Double)] {
        let (startDate, endDate) = getDateRange(for: period, date: date)
        let dailyValues = try await fetchSleepDurationDaily(
            startDate: startDate,
            endDate: endDate
        )
        return dailyValues.map { ($0.date, $0.value) }
    }

    /// Fetch sleep stage breakdown using pre-computed database view
    func fetchSleepStageBreakdown(
        period: TimePeriod,
        date: Date
    ) async throws -> (deep: Double, rem: Double, core: Double, awake: Double) {
        let (startDate, endDate) = getDateRange(for: period, date: date)
        let summaries = try await fetchSleepSessionSummaries(startDate: startDate, endDate: endDate)

        var totalDeep = 0.0
        var totalRem = 0.0
        var totalCore = 0.0
        var totalAwake = 0.0

        for row in summaries {
            totalDeep += row.deepMinutes
            totalRem += row.remMinutes
            totalCore += row.lightMinutes  // "light" in view = "core" stage
            totalAwake += row.awakeMinutes
        }

        let dayCount = Double(max(1, summaries.count))
        if period != .day {
            return (
                deep: totalDeep / dayCount,
                rem: totalRem / dayCount,
                core: totalCore / dayCount,
                awake: totalAwake / dayCount
            )
        }
        return (deep: totalDeep, rem: totalRem, core: totalCore, awake: totalAwake)
    }

    /// Fetch per-day sleep stage breakdown for charts
    /// Uses patient_sleep_sessions_summary view for efficient pre-computed aggregations
    /// Returns daily totals with stage breakdown (already handles multiple sessions per day)
    func fetchSleepStageBreakdownDaily(
        startDate: Date,
        endDate: Date
    ) async throws -> [DailySleepStageData] {
        // Use the pre-computed database view instead of calculating in Swift
        let summaries = try await fetchSleepSessionSummaries(startDate: startDate, endDate: endDate)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var results: [DailySleepStageData] = []
        for row in summaries {
            guard let date = dateFormatter.date(from: row.sleepDate) else { continue }

            results.append(DailySleepStageData(
                date: date,
                deepMinutes: row.deepMinutes,
                remMinutes: row.remMinutes,
                coreMinutes: row.lightMinutes,  // "light" in view = "core" stage
                awakeMinutes: row.awakeMinutes,
                sleepDurationMinutes: row.totalSleepMinutes,
                timeInBedMinutes: row.timeInBedMinutes
            ))
        }

        return results.sorted { $0.date < $1.date }
    }

    /// Fetch sleep timing (bedtime/waketime) using pre-computed database view
    func fetchSleepTiming(
        startDate: Date,
        endDate: Date
    ) async throws -> [(date: Date, bedtime: Date, waketime: Date)] {
        let summaries = try await fetchSleepSessionSummaries(startDate: startDate, endDate: endDate)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return summaries.compactMap { row -> (date: Date, bedtime: Date, waketime: Date)? in
            guard let date = dateFormatter.date(from: row.sleepDate) else { return nil }
            return (date: date, bedtime: row.bedtime, waketime: row.waketime)
        }.sorted { $0.date < $1.date }
    }

    /// Fetch weekly averages from the pre-computed database view
    /// Groups daily summaries by week and calculates averages
    func fetchWeeklyAveragesFromView(
        startDate: Date,
        endDate: Date
    ) async throws -> [WeeklyAverage] {
        let summaries = try await fetchSleepSessionSummaries(startDate: startDate, endDate: endDate)
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Group summaries by week
        var weeklyData: [Date: [SleepSessionSummaryRow]] = [:]
        for row in summaries {
            guard let date = dateFormatter.date(from: row.sleepDate) else { continue }
            // Get start of week (Monday)
            let weekday = calendar.component(.weekday, from: date)
            let daysToMonday = (weekday == 1) ? -6 : (2 - weekday)
            let weekStart = calendar.date(byAdding: .day, value: daysToMonday, to: calendar.startOfDay(for: date))!
            weeklyData[weekStart, default: []].append(row)
        }

        var results: [WeeklyAverage] = []
        for (weekStart, weekSessions) in weeklyData {
            guard !weekSessions.isEmpty else { continue }
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
            let count = Double(weekSessions.count)

            // Average time in bed and asleep (convert minutes to seconds for TimeInterval)
            let avgTimeInBed = weekSessions.reduce(0.0) { $0 + $1.timeInBedMinutes } / count * 60
            let avgTimeAsleep = weekSessions.reduce(0.0) { $0 + $1.totalSleepMinutes } / count * 60

            // Average bedtime/waketime using offset from 6PM for proper overnight averaging
            let avgBedtimeOffsetMins = weekSessions.map { calculateOffsetFromSixPM($0.bedtime) }.reduce(0, +) / weekSessions.count
            let avgWaketimeOffsetMins = weekSessions.map { calculateOffsetFromSixPM($0.waketime) }.reduce(0, +) / weekSessions.count

            let avgBedtime = offsetToTime(avgBedtimeOffsetMins, calendar: calendar)
            let avgWaketime = offsetToTime(avgWaketimeOffsetMins, calendar: calendar)

            results.append(WeeklyAverage(
                weekStartDate: weekStart,
                weekEndDate: weekEnd,
                avgTimeInBed: avgTimeInBed,
                avgTimeAsleep: avgTimeAsleep,
                avgBedtime: avgBedtime,
                avgWaketime: avgWaketime
            ))
        }

        return results.sorted { $0.weekStartDate < $1.weekStartDate }
    }

    /// Fetch monthly averages from the pre-computed database view
    /// Groups daily summaries by month and calculates averages
    func fetchMonthlyAveragesFromView(
        startDate: Date,
        endDate: Date
    ) async throws -> [MonthlyAverage] {
        let summaries = try await fetchSleepSessionSummaries(startDate: startDate, endDate: endDate)
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Group summaries by month
        var monthlyData: [Date: [SleepSessionSummaryRow]] = [:]
        for row in summaries {
            guard let date = dateFormatter.date(from: row.sleepDate) else { continue }
            // Get start of month
            let monthComponents = calendar.dateComponents([.year, .month], from: date)
            let monthStart = calendar.date(from: monthComponents)!
            monthlyData[monthStart, default: []].append(row)
        }

        var results: [MonthlyAverage] = []
        for (monthStart, monthSessions) in monthlyData {
            guard !monthSessions.isEmpty else { continue }
            let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!
            let count = Double(monthSessions.count)

            // Average time in bed and asleep (convert minutes to seconds for TimeInterval)
            let avgTimeInBed = monthSessions.reduce(0.0) { $0 + $1.timeInBedMinutes } / count * 60
            let avgTimeAsleep = monthSessions.reduce(0.0) { $0 + $1.totalSleepMinutes } / count * 60

            // Average bedtime/waketime using offset from 6PM for proper overnight averaging
            let avgBedtimeOffsetMins = monthSessions.map { calculateOffsetFromSixPM($0.bedtime) }.reduce(0, +) / monthSessions.count
            let avgWaketimeOffsetMins = monthSessions.map { calculateOffsetFromSixPM($0.waketime) }.reduce(0, +) / monthSessions.count

            let avgBedtime = offsetToTime(avgBedtimeOffsetMins, calendar: calendar)
            let avgWaketime = offsetToTime(avgWaketimeOffsetMins, calendar: calendar)

            results.append(MonthlyAverage(
                monthStartDate: monthStart,
                monthEndDate: monthEnd,
                avgTimeInBed: avgTimeInBed,
                avgTimeAsleep: avgTimeAsleep,
                avgBedtime: avgBedtime,
                avgWaketime: avgWaketime
            ))
        }

        return results.sorted { $0.monthStartDate < $1.monthStartDate }
    }

    /// Calculate offset from 6PM for averaging sleep times across midnight
    private func calculateOffsetFromSixPM(_ time: Date) -> Int {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)
        // If time is 6PM or later (18:00+), offset is hours since 6PM
        // If time is before 6PM, it's next day - add 24 hours worth
        if hour >= 18 {
            return (hour - 18) * 60 + minute
        } else {
            return (24 - 18 + hour) * 60 + minute
        }
    }

    /// Convert offset from 6PM back to a time Date
    private func offsetToTime(_ offsetMinutes: Int, calendar: Calendar) -> Date {
        let sixPMMinutes = 18 * 60
        var totalMinutes = sixPMMinutes + offsetMinutes
        if totalMinutes >= 24 * 60 {
            totalMinutes -= 24 * 60
        }
        let hour = totalMinutes / 60
        let minute = totalMinutes % 60
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    // MARK: - Helpers
    func getDateRange(for period: TimePeriod, date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        switch period {
        case .hour:
            let startOfHour = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: date))!
            let endOfHour = calendar.date(byAdding: .hour, value: 1, to: startOfHour)!
            return (startOfHour, endOfHour)
        case .day:
            return (startOfDay, startOfDay)
        case .week:
            let weekday = calendar.component(.weekday, from: date)
            let daysToSubtract = weekday - calendar.firstWeekday
            let weekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: startOfDay)!
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
            return (weekStart, weekEnd)
        case .month:
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart)!
            let monthEnd = calendar.date(byAdding: .day, value: -1, to: nextMonth)!
            return (monthStart, monthEnd)
        case .sixMonth:
            let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: startOfDay)!
            return (sixMonthsAgo, startOfDay)
        case .year:
            let yearStart = calendar.date(from: calendar.dateComponents([.year], from: date))!
            let nextYear = calendar.date(byAdding: .year, value: 1, to: yearStart)!
            let yearEnd = calendar.date(byAdding: .day, value: -1, to: nextYear)!
            return (yearStart, yearEnd)
        }
    }
}

// MARK: - Quantity Type Constants

extension PatientSamplesQueryService {
    struct QuantityTypes {
        static let steps = "steps"
        static let proteinGrams = "protein_grams"
        static let vegetablesServings = "vegetables_servings"
        static let fruitsServings = "fruits_servings"
        static let legumesServings = "legumes_servings"
        static let wholeGrainsServings = "whole_grains_servings"
        static let alcoholDrinks = "alcohol_drinks"
    }
    struct CategoryTypes {
        static let sleepPeriodTypes = "sleep_period_types"
    }
}
