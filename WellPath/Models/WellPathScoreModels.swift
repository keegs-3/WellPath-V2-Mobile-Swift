//
//  WellPathScoreModels.swift
//  WellPath
//
//  Created on 2025-10-22
//

import Foundation

struct WellPathScoreOverall: Codable {
    let userId: UUID
    let patientGender: String?
    let patientAge: Int?
    let wellpathScoreOverall: Double

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case patientGender = "patient_gender"
        case patientAge = "patient_age"
        case wellpathScoreOverall = "wellpath_score_overall"
    }

    var scorePercentage: Int {
        Int((wellpathScoreOverall * 100).rounded())
    }
}

struct PillarScore: Codable, Identifiable {
    var id: String { pillarName }
    let userId: UUID
    let pillarName: String
    let patientScore: Double
    let maxScore: Double
    let scorePercentage: Double
    let itemCount: Int
    let lastUpdated: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case pillarName = "pillar_name"
        case patientScore = "patient_score"
        case maxScore = "max_score"
        case scorePercentage = "score_percentage"
        case itemCount = "item_count"
        case lastUpdated = "last_updated"
    }

    var percentageInt: Int {
        Int(scorePercentage.rounded())
    }
}

// Helper for decoding dynamic JSON structures
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
