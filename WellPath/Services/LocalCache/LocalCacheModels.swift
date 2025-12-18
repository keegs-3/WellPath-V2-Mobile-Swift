//
//  LocalCacheModels.swift
//  WellPath
//
//  SwiftData models for local caching of chart data and display configuration
//  Enables offline functionality and faster chart loading
//

import Foundation
import SwiftData

// MARK: - Cached Quantity Samples (Steps, Protein, etc.)

@Model
final class CachedQuantitySample {
    @Attribute(.unique) var id: UUID
    var patientId: UUID
    var quantityType: String
    var aggregationDate: Date
    var value: Double
    var unit: String?
    var cachedAt: Date

    init(
        id: UUID,
        patientId: UUID,
        quantityType: String,
        aggregationDate: Date,
        value: Double,
        unit: String?,
        cachedAt: Date = Date()
    ) {
        self.id = id
        self.patientId = patientId
        self.quantityType = quantityType
        self.aggregationDate = aggregationDate
        self.value = value
        self.unit = unit
        self.cachedAt = cachedAt
    }
}

// MARK: - Cached Sleep Session Summaries

@Model
final class CachedSleepSummary {
    @Attribute(.unique) var compositeKey: String  // patientId_sleepDate
    var patientId: UUID
    var sleepDate: Date
    var sessionCount: Int
    var sessionStart: Date?
    var sessionEnd: Date?
    var bedtime: Date?        // Can be NULL for some legacy data
    var waketime: Date?       // Can be NULL for some legacy data
    var deepMinutes: Double
    var remMinutes: Double
    var lightMinutes: Double
    var awakeMinutes: Double
    var totalSleepMinutes: Double
    var timeInBedMinutes: Double
    var sleepEfficiency: Double
    // Rolling 7-day averages
    var avgBedtimeOffset7d: Double?
    var avgWaketimeOffset7d: Double?
    var avgSleepMinutes7d: Double?
    var avgDeepMinutes7d: Double?
    var avgRemMinutes7d: Double?
    var avgLightMinutes7d: Double?
    var daysInRolling7d: Int?
    // Consistency flags
    var bedtimeInRange: Bool?
    var waketimeInRange: Bool?
    var cachedAt: Date

    init(from row: SleepSessionSummaryRow, patientId: UUID, cachedAt: Date = Date()) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let sleepDateParsed = dateFormatter.date(from: row.sleepDate) ?? Date()

        self.compositeKey = "\(patientId.uuidString)_\(row.sleepDate)"
        self.patientId = patientId
        self.sleepDate = sleepDateParsed
        self.sessionCount = row.sessionCount
        self.sessionStart = row.sessionStart
        self.sessionEnd = row.sessionEnd
        self.bedtime = row.bedtime
        self.waketime = row.waketime
        self.deepMinutes = row.deepMinutes
        self.remMinutes = row.remMinutes
        self.lightMinutes = row.lightMinutes
        self.awakeMinutes = row.awakeMinutes
        self.totalSleepMinutes = row.totalSleepMinutes
        self.timeInBedMinutes = row.timeInBedMinutes
        self.sleepEfficiency = row.sleepEfficiency
        self.avgBedtimeOffset7d = row.avgBedtimeOffset7d
        self.avgWaketimeOffset7d = row.avgWaketimeOffset7d
        self.avgSleepMinutes7d = row.avgSleepMinutes7d
        self.avgDeepMinutes7d = row.avgDeepMinutes7d
        self.avgRemMinutes7d = row.avgRemMinutes7d
        self.avgLightMinutes7d = row.avgLightMinutes7d
        self.daysInRolling7d = row.daysInRolling7d
        self.bedtimeInRange = row.bedtimeInRange
        self.waketimeInRange = row.waketimeInRange
        self.cachedAt = cachedAt
    }

    /// Convert back to SleepSessionSummaryRowLocal for use with existing code
    func toSummaryRow() -> SleepSessionSummaryRowLocal? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let sleepDateString = dateFormatter.string(from: sleepDate)

        return SleepSessionSummaryRowLocal(
            sleepDate: sleepDateString,
            sessionCount: sessionCount,
            sessionStart: sessionStart,
            sessionEnd: sessionEnd,
            bedtime: bedtime,
            waketime: waketime,
            deepMinutes: deepMinutes,
            remMinutes: remMinutes,
            lightMinutes: lightMinutes,
            awakeMinutes: awakeMinutes,
            totalSleepMinutes: totalSleepMinutes,
            timeInBedMinutes: timeInBedMinutes,
            totalSleepHours: totalSleepMinutes / 60.0,
            sleepEfficiency: sleepEfficiency,
            avgBedtimeOffset7d: avgBedtimeOffset7d,
            avgWaketimeOffset7d: avgWaketimeOffset7d,
            avgSleepMinutes7d: avgSleepMinutes7d,
            avgDeepMinutes7d: avgDeepMinutes7d,
            avgRemMinutes7d: avgRemMinutes7d,
            avgLightMinutes7d: avgLightMinutes7d,
            daysInRolling7d: daysInRolling7d,
            bedtimeInRange: bedtimeInRange,
            waketimeInRange: waketimeInRange
        )
    }
}

/// Local version that can be directly constructed (vs. SleepSessionSummaryRow which requires Codable)
struct SleepSessionSummaryRowLocal {
    let sleepDate: String
    let sessionCount: Int
    let sessionStart: Date?
    let sessionEnd: Date?
    let bedtime: Date?
    let waketime: Date?
    let deepMinutes: Double
    let remMinutes: Double
    let lightMinutes: Double
    let awakeMinutes: Double
    let totalSleepMinutes: Double
    let timeInBedMinutes: Double
    let totalSleepHours: Double
    let sleepEfficiency: Double
    let avgBedtimeOffset7d: Double?
    let avgWaketimeOffset7d: Double?
    let avgSleepMinutes7d: Double?
    let avgDeepMinutes7d: Double?
    let avgRemMinutes7d: Double?
    let avgLightMinutes7d: Double?
    let daysInRolling7d: Int?
    let bedtimeInRange: Bool?
    let waketimeInRange: Bool?
}

// MARK: - Cached Correlation Samples (Blood Pressure, etc.)

@Model
final class CachedCorrelationSample {
    @Attribute(.unique) var id: UUID
    var patientId: UUID
    var correlationType: String
    var components: Data  // JSON-encoded [String: Double]
    var sampleTime: Date
    var source: String
    var cachedAt: Date

    init(
        id: UUID,
        patientId: UUID,
        correlationType: String,
        components: [String: Double],
        sampleTime: Date,
        source: String,
        cachedAt: Date = Date()
    ) {
        self.id = id
        self.patientId = patientId
        self.correlationType = correlationType
        self.components = (try? JSONEncoder().encode(components)) ?? Data()
        self.sampleTime = sampleTime
        self.source = source
        self.cachedAt = cachedAt
    }

    var decodedComponents: [String: Double] {
        (try? JSONDecoder().decode([String: Double].self, from: components)) ?? [:]
    }
}

// MARK: - Cached Display Configuration

@Model
final class CachedDisplayMetric {
    @Attribute(.unique) var metricId: String
    var metricName: String
    var aboutContent: String?
    var longevityImpact: String?
    var quickTipsData: Data?  // JSON-encoded [String]
    var chartTypeId: String?
    var pillarName: String?
    var unitLabel: String?
    var cachedAt: Date

    init(
        metricId: String,
        metricName: String,
        aboutContent: String?,
        longevityImpact: String?,
        quickTips: [String]?,
        chartTypeId: String?,
        pillarName: String?,
        unitLabel: String?,
        cachedAt: Date = Date()
    ) {
        self.metricId = metricId
        self.metricName = metricName
        self.aboutContent = aboutContent
        self.longevityImpact = longevityImpact
        self.quickTipsData = quickTips.flatMap { try? JSONEncoder().encode($0) }
        self.chartTypeId = chartTypeId
        self.pillarName = pillarName
        self.unitLabel = unitLabel
        self.cachedAt = cachedAt
    }

    var quickTips: [String]? {
        quickTipsData.flatMap { try? JSONDecoder().decode([String].self, from: $0) }
    }
}

// MARK: - Cache Sync Status

@Model
final class CacheSyncStatus {
    @Attribute(.unique) var key: String  // e.g., "sleep_summaries", "quantity_steps"
    var patientId: UUID
    var lastSyncDate: Date
    var oldestDataDate: Date?
    var newestDataDate: Date?
    var recordCount: Int

    init(
        key: String,
        patientId: UUID,
        lastSyncDate: Date = Date(),
        oldestDataDate: Date? = nil,
        newestDataDate: Date? = nil,
        recordCount: Int = 0
    ) {
        self.key = key
        self.patientId = patientId
        self.lastSyncDate = lastSyncDate
        self.oldestDataDate = oldestDataDate
        self.newestDataDate = newestDataDate
        self.recordCount = recordCount
    }
}
