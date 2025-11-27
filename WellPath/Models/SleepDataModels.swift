//
//  SleepDataModels.swift
//  WellPath
//
//  Created on 2025-11-15
//

import Foundation
import Supabase

// MARK: - Patient Sleep Data Entry
/// Raw sleep period data from HealthKit or manual entry
struct PatientSleepDataEntry: Codable {
    let id: UUID?
    let patientId: UUID
    let eventInstanceId: UUID
    let periodStart: Date
    let periodEnd: Date
    let periodTypeId: String?
    let source: String
    let userTimezone: String?
    let metadata: [String: AnyJSON]?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case eventInstanceId = "event_instance_id"
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case periodTypeId = "period_type_id"
        case source
        case userTimezone = "user_timezone"
        case metadata
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        patientId: UUID,
        eventInstanceId: UUID,
        periodStart: Date,
        periodEnd: Date,
        periodTypeId: String?,
        source: String,
        userTimezone: String? = nil,
        metadata: [String: AnyJSON]? = nil
    ) {
        self.id = nil  // Let database generate
        self.patientId = patientId
        self.eventInstanceId = eventInstanceId
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.periodTypeId = periodTypeId
        self.source = source
        self.userTimezone = userTimezone
        self.metadata = metadata
        self.createdAt = nil
        self.updatedAt = nil
    }

    // Custom encoding to ensure nil values are omitted
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Only encode non-nil values
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(patientId, forKey: .patientId)
        try container.encode(eventInstanceId, forKey: .eventInstanceId)
        try container.encode(periodStart, forKey: .periodStart)
        try container.encode(periodEnd, forKey: .periodEnd)
        try container.encodeIfPresent(periodTypeId, forKey: .periodTypeId)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(userTimezone, forKey: .userTimezone)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - Patient Sleep Event
/// Calculated sleep event with duration
struct PatientSleepEvent: Codable, Identifiable {
    let id: UUID
    let patientId: UUID
    let sleepDataEntryId: UUID
    let durationMinutes: Double
    let periodType: String
    let sleepSessionId: UUID?
    let periodStart: Date
    let periodEnd: Date
    let entryDate: Date
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case sleepDataEntryId = "sleep_data_entry_id"
        case durationMinutes = "duration_minutes"
        case periodType = "period_type"
        case sleepSessionId = "sleep_session_id"
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case entryDate = "entry_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Patient Sleep Session
/// Aggregated sleep session with totals
struct PatientSleepSession: Codable, Identifiable {
    let id: UUID
    let patientId: UUID
    let sleepSessionId: UUID
    let totalDurationMinutes: Double
    let timeInBedMinutes: Double
    let sessionBedtime: Date
    let sessionWaketime: Date
    let primaryDate: Date
    let periodCount: Int
    let metadata: [String: AnyJSON]?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case sleepSessionId = "sleep_session_id"
        case totalDurationMinutes = "total_duration_minutes"
        case timeInBedMinutes = "time_in_bed_minutes"
        case sessionBedtime = "session_bedtime"
        case sessionWaketime = "session_waketime"
        case primaryDate = "primary_date"
        case periodCount = "period_count"
        case metadata
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Sleep Hypnogram Data (from view)
/// Data from patient_sleep_hypnogram_data view for drawing hypnograms
struct SleepHypnogramData: Codable {
    let patientId: UUID
    let sleepSessionId: UUID?
    let aggregationDate: Date?
    let startTime: Date
    let endTime: Date
    let sleepStage: Int          // 0=Awake, 1=REM, 2=Core, 3=Deep
    let stageName: String        // 'Awake', 'REM', 'Core', 'Deep'
    let durationMinutes: Double
    let source: String
    let sessionStart: Date?      // Window function: earliest start in session
    let sessionEnd: Date?        // Window function: latest end in session
    let sessionTotalMinutes: Double?  // Window function: total duration in session

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case sleepSessionId = "sleep_session_id"
        case aggregationDate = "aggregation_date"
        case startTime = "start_time"
        case endTime = "end_time"
        case sleepStage = "sleep_stage"
        case stageName = "stage_name"
        case durationMinutes = "duration_minutes"
        case source
        case sessionStart = "session_start"
        case sessionEnd = "session_end"
        case sessionTotalMinutes = "session_total_minutes"
    }

    /// Convert sleep_stage integer to SleepStage enum
    var stage: SleepStage {
        switch sleepStage {
        case 0: return .awake
        case 1: return .rem
        case 2: return .core
        case 3: return .deep
        default: return .asleep
        }
    }
}

// MARK: - Patient Event
/// Calculated event for non-sleep data (workouts, meals, etc.)
struct PatientEvent: Codable, Identifiable {
    let id: UUID
    let patientId: UUID
    let eventInstanceId: UUID
    let eventCalculationId: String
    let valueNumeric: Double?
    let valueText: String?
    let valueTimestamp: Date?
    let valueJson: [String: AnyJSON]?
    let entryDate: Date
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case eventInstanceId = "event_instance_id"
        case eventCalculationId = "event_calculation_id"
        case valueNumeric = "value_numeric"
        case valueText = "value_text"
        case valueTimestamp = "value_timestamp"
        case valueJson = "value_json"
        case entryDate = "entry_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
