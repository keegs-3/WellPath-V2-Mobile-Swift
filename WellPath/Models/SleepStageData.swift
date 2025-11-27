//
//  SleepStageData.swift
//  WellPath
//
//  Created on 2025-10-23
//

import Foundation
import SwiftUI
import Charts

enum SleepStage: String, CaseIterable, Codable, Plottable {
    case inBed = "In Bed"
    case asleep = "Asleep"
    case awake = "Awake"
    case rem = "REM"
    case core = "Core"
    case deep = "Deep"
    case asleepSummary = "Asleep Summary" // Horizontal bar for unified visualization

    var fieldIdPrefix: String {
        // NOTE: Not currently used, but kept for reference
        switch self {
        case .inBed: return "DEF_SLEEP_PERIOD"
        case .asleep: return "DEF_SLEEP_PERIOD"
        case .awake: return "DEF_SLEEP_PERIOD"
        case .rem: return "DEF_SLEEP_PERIOD"
        case .core: return "DEF_SLEEP_PERIOD"
        case .deep: return "DEF_SLEEP_PERIOD"
        case .asleepSummary: return "" // Not a data field, used for rendering only
        }
    }

    var displayOrder: Int {
        switch self {
        case .asleepSummary: return -1 // Render first (top of chart)
        case .awake: return 0
        case .rem: return 1
        case .core: return 2
        case .deep: return 3
        case .asleep: return 4
        case .inBed: return 5
        }
    }

    var color: Color {
        switch self {
        case .awake: return Color.red // Red (no transparency)
        case .rem: return Color(red: 0.6, green: 0.8, blue: 1.0) // Light blue
        case .core: return Color(red: 0.3, green: 0.6, blue: 1.0) // Medium blue
        case .deep: return Color(red: 0.0, green: 0.4, blue: 0.8) // Dark blue
        case .asleep: return Color(hex: "80CBC4") ?? .teal // Teal for basic sleep
        case .inBed: return Color(hex: "C8E6C9") ?? Color.green.opacity(0.3) // Light green
        case .asleepSummary: return Color(hex: "80CBC4") ?? .teal // Sleep pillar color (teal)
        }
    }
}

struct SleepStageSegment: Identifiable, Equatable {
    let id = UUID()
    let stage: SleepStage
    let startTime: Date
    let endTime: Date
    let userTimezone: String // Timezone where this sleep data was recorded (e.g., "America/Los_Angeles")

    var durationMinutes: Double {
        endTime.timeIntervalSince(startTime) / 60.0
    }

    /// Returns the start time converted to the user's original timezone
    var localStartTime: Date {
        guard let timezone = TimeZone(identifier: userTimezone) else {
            return startTime
        }
        // Date is already UTC, convert to display in original timezone
        return startTime
    }

    /// Returns the end time converted to the user's original timezone
    var localEndTime: Date {
        guard let timezone = TimeZone(identifier: userTimezone) else {
            return endTime
        }
        return endTime
    }

    static func == (lhs: SleepStageSegment, rhs: SleepStageSegment) -> Bool {
        lhs.id == rhs.id
    }
}
