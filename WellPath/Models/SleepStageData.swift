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
    case asleepUnspecified = "Asleep"
    case awake = "Awake"
    case rem = "REM"
    case core = "Core"
    case deep = "Deep"

    var fieldIdPrefix: String {
        switch self {
        case .inBed: return "DEF_INBED_SLEEP"
        case .asleepUnspecified: return "DEF_ASLEEP_UNSPECIFIED_SLEEP"
        case .awake: return "DEF_AWAKE_SLEEP"
        case .rem: return "DEF_REM_SLEEP"
        case .core: return "DEF_CORE_SLEEP"
        case .deep: return "DEF_DEEP_SLEEP"
        }
    }

    var displayOrder: Int {
        switch self {
        case .awake: return 0
        case .rem: return 1
        case .core: return 2
        case .deep: return 3
        case .asleepUnspecified: return 4
        case .inBed: return 5
        }
    }

    var color: Color {
        switch self {
        case .awake: return .red
        case .rem: return .cyan
        case .core: return .blue
        case .deep: return .indigo
        case .asleepUnspecified: return .blue.opacity(0.5)
        case .inBed: return .gray.opacity(0.3)
        }
    }
}

struct SleepStageSegment: Identifiable, Equatable {
    let id = UUID()
    let stage: SleepStage
    let startTime: Date
    let endTime: Date

    var durationMinutes: Double {
        endTime.timeIntervalSince(startTime) / 60.0
    }

    static func == (lhs: SleepStageSegment, rhs: SleepStageSegment) -> Bool {
        lhs.id == rhs.id
    }
}
