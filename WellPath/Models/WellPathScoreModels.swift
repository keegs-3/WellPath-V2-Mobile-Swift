//
//  WellPathScoreModels.swift
//  WellPath
//
//  Created on 2025-10-22
//

import Foundation
import SwiftUI

// MARK: - History Models (for charts)

struct WellPathScoreHistory: Codable {
    let patientId: UUID
    let overallPercentage: Double
    let calculatedAt: String

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case overallPercentage = "overall_percentage"
        case calculatedAt = "calculated_at"
    }
}

struct PillarScoreHistory: Codable {
    let patientId: UUID
    let pillarName: String
    let pillarPercentage: Double
    let calculatedAt: String

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case pillarName = "pillar_name"
        case pillarPercentage = "pillar_percentage"
        case calculatedAt = "calculated_at"
    }
}

struct PillarScoreCurrent: Codable {
    let patientId: UUID
    let pillarName: String
    let pillarPercentage: Double
    let calculatedAt: String

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case pillarName = "pillar_name"
        case pillarPercentage = "pillar_percentage"
        case calculatedAt = "calculated_at"
    }
}

struct ComponentScoreHistory: Codable {
    let patientId: UUID
    let pillarName: String
    let componentType: String // 'markers', 'behaviors', 'education'
    let componentPercentage: Double
    let calculatedAt: String

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case pillarName = "pillar_name"
        case componentType = "component_type"
        case componentPercentage = "component_percentage"
        case calculatedAt = "calculated_at"
    }
}

struct ComponentScoreCurrent: Codable {
    let patientId: UUID
    let pillarName: String
    let componentType: String // 'markers', 'behaviors', 'education'
    let componentPercentage: Double
    let calculatedAt: String

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case pillarName = "pillar_name"
        case componentType = "component_type"
        case componentPercentage = "component_percentage"
        case calculatedAt = "calculated_at"
    }
}

// MARK: - Current/Latest Models

struct WellPathScoreOverall: Codable {
    let patientId: UUID
    let overallPercentage: Double
    let calculatedAt: String

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case overallPercentage = "overall_percentage"
        case calculatedAt = "calculated_at"
    }

    // Use overall_percentage directly from database (already 0-100)
    var scorePercentageInt: Int {
        Int(overallPercentage.rounded())
    }
}

struct PillarScore: Codable, Identifiable {
    var id: String { pillarName }
    let patientId: UUID
    let pillarName: String
    let pillarPercentage: Double
    let calculatedAt: String

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case pillarName = "pillar_name"
        case pillarPercentage = "pillar_percentage"
        case calculatedAt = "calculated_at"
    }

    var percentageInt: Int {
        Int(pillarPercentage.rounded())
    }
}

// MARK: - Component Score Lists (for component detail views)

struct BiomarkerScore: Codable, Identifiable {
    var id: String { biomarkerName }
    let biomarkerName: String
    let currentValue: Double?
    let referenceUnit: String?
    let pointsEarned: Double
    let maxPoints: Double
    let weightInPillar: Double
    let scorePercentage: Double
    let rangeClassification: String?
    let lastReadingDate: String?

    enum CodingKeys: String, CodingKey {
        case biomarkerName = "biomarker_name"
        case currentValue = "current_value"
        case referenceUnit = "reference_unit"
        case pointsEarned = "points_earned"
        case maxPoints = "max_points"
        case weightInPillar = "weight_in_pillar"
        case scorePercentage = "score_percentage"
        case rangeClassification = "range_classification"
        case lastReadingDate = "last_reading_date"
    }
}

struct BiometricScore: Codable, Identifiable {
    var id: String { biometricName }
    let biometricName: String
    let currentValue: Double?
    let unit: String?
    let pointsEarned: Double
    let maxPoints: Double
    let weightInPillar: Double
    let scorePercentage: Double
    let rangeClassification: String?
    let lastReadingDate: String?

    enum CodingKeys: String, CodingKey {
        case biometricName = "biometric_name"
        case currentValue = "current_value"
        case unit
        case pointsEarned = "points_earned"
        case maxPoints = "max_points"
        case weightInPillar = "weight_in_pillar"
        case scorePercentage = "score_percentage"
        case rangeClassification = "range_classification"
        case lastReadingDate = "last_reading_date"
    }
}

struct BehaviorScore: Codable, Identifiable {
    var id: Double { questionNumber }
    let questionNumber: Double
    let questionText: String
    let responseText: String?
    let responseScore: Double
    let pointsEarned: Double
    let maxPoints: Double
    let weightInPillar: Double
    let scorePercentage: Double
    let lastUpdated: String?
    let dataSource: String?  // "questionnaire_initial", "tracked_data_auto_update", "check_in_update"

    enum CodingKeys: String, CodingKey {
        case questionNumber = "question_number"
        case questionText = "question_text"
        case responseText = "response_text"
        case responseScore = "response_score"
        case pointsEarned = "points_earned"
        case maxPoints = "max_points"
        case weightInPillar = "weight_in_pillar"
        case scorePercentage = "score_percentage"
        case lastUpdated = "last_updated"
        case dataSource = "data_source"
    }
}

struct EducationScore: Codable, Identifiable {
    var id: String { educationItemId }
    let educationItemId: String
    let educationItemTitle: String
    let completionStatus: String  // "started", "in_progress", "completed"
    let completionPercentage: Double?
    let pointsEarned: Double
    let maxPoints: Double
    let weightInPillar: Double
    let completedDate: String?

    enum CodingKeys: String, CodingKey {
        case educationItemId = "education_item_id"
        case educationItemTitle = "education_item_title"
        case completionStatus = "completion_status"
        case completionPercentage = "completion_percentage"
        case pointsEarned = "points_earned"
        case maxPoints = "max_points"
        case weightInPillar = "weight_in_pillar"
        case completedDate = "completed_date"
    }
}

// MARK: - Item Cards

struct ItemCard: Codable, Identifiable {
    let id: UUID
    let pillarName: String
    let componentType: String
    let itemType: String

    // Display
    let cardDisplayName: String
    let cardSubtitle: String?
    let componentPercentage: Double
    let itemWeightInComponent: Double

    // Navigation
    let navigationType: String
    let navigationId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case pillarName = "pillar_name"
        case componentType = "component_type"
        case itemType = "item_type"
        case cardDisplayName = "card_display_name"
        case cardSubtitle = "card_subtitle"
        case componentPercentage = "component_percentage"
        case itemWeightInComponent = "item_weight_in_component"
        case navigationType = "navigation_type"
        case navigationId = "navigation_id"
    }

    // Computed properties
    var percentOfComponent: String {
        String(format: "%.1f%%", itemWeightInComponent * 100)
    }

    var scoreText: String {
        String(format: "%.0f%%", componentPercentage)
    }

    var scoreColor: Color {
        switch componentPercentage {
        case 80...100: return .green
        case 60..<80: return .yellow
        default: return .red
        }
    }
}

// MARK: - Pillar Component Breakdown

struct PillarComponentScore {
    let pillarName: String
    let totalScore: Double
    let biomarkersScore: Double
    let behaviorsScore: Double
    let educationScore: Double
    let biomarkersWeight: Double
    let behaviorsWeight: Double
    let educationWeight: Double

    // Computed properties for display
    var biomarkersPoints: Int {
        Int(biomarkersScore.rounded())
    }

    var behaviorsPoints: Int {
        Int(behaviorsScore.rounded())
    }

    var educationPoints: Int {
        Int(educationScore.rounded())
    }

    var totalPoints: Int {
        Int(totalScore.rounded())
    }
}

// MARK: - Component Detail Metric

struct ComponentMetric: Identifiable {
    let id: UUID
    let metricName: String
    let pointsEarned: Double
    let maxPoints: Double
    let weight: Double // 0.0-1.0 of component total
    let currentValue: Double?
    let pillar: String
    let componentType: ComponentType

    enum ComponentType: String {
        case biomarkers = "biomarkers"
        case behaviors = "behaviors"
        case education = "education"

        var displayName: String {
            switch self {
            case .biomarkers: return "Biomarkers"
            case .behaviors: return "Behaviors"
            case .education: return "Education"
            }
        }
    }

    var pointsEarnedInt: Int {
        Int(pointsEarned.rounded())
    }

    var maxPointsInt: Int {
        Int(maxPoints.rounded())
    }

    var weightPercentage: Int {
        Int((weight * 100).rounded())
    }
}

// MARK: - Pillar Weight Configuration

struct PillarWeightConfig {
    static let weights: [String: [String: Double]] = [
        "Healthful Nutrition": ["biomarkers": 0.72, "behaviors": 0.18, "education": 0.10],
        "Movement + Exercise": ["biomarkers": 0.54, "behaviors": 0.36, "education": 0.10],
        "Restorative Sleep": ["biomarkers": 0.63, "behaviors": 0.27, "education": 0.10],
        "Cognitive Health": ["biomarkers": 0.36, "behaviors": 0.54, "education": 0.10],
        "Stress Management": ["biomarkers": 0.27, "behaviors": 0.63, "education": 0.10],
        "Connection + Purpose": ["biomarkers": 0.18, "behaviors": 0.72, "education": 0.10],
        "Core Care": ["biomarkers": 0.495, "behaviors": 0.405, "education": 0.10]
    ]

    static func weight(for pillar: String, component: String) -> Double {
        return weights[pillar]?[component] ?? 0
    }

    static func calculateComponentScore(pillarScore: Double, weight: Double) -> Double {
        return pillarScore * weight
    }
}

// MARK: - Pillar UI Configuration

struct PillarUIConfig {
    let name: String
    let color: Color
    let icon: String

    static let configs: [String: PillarUIConfig] = [
        "Healthful Nutrition": PillarUIConfig(
            name: "Healthful Nutrition",
            color: Color(red: 0.40, green: 0.80, blue: 0.40),
            icon: "leaf.fill"
        ),
        "Movement + Exercise": PillarUIConfig(
            name: "Movement + Exercise",
            color: Color(red: 0.20, green: 0.60, blue: 0.86),
            icon: "figure.run"
        ),
        "Restorative Sleep": PillarUIConfig(
            name: "Restorative Sleep",
            color: Color(red: 0.35, green: 0.34, blue: 0.84),
            icon: "moon.fill"
        ),
        "Cognitive Health": PillarUIConfig(
            name: "Cognitive Health",
            color: Color(red: 0.98, green: 0.73, blue: 0.18),
            icon: "brain.head.profile"
        ),
        "Stress Management": PillarUIConfig(
            name: "Stress Management",
            color: Color(red: 0.95, green: 0.55, blue: 0.65),
            icon: "heart.fill"
        ),
        "Connection + Purpose": PillarUIConfig(
            name: "Connection + Purpose",
            color: Color(red: 0.74, green: 0.56, blue: 0.94),
            icon: "person.2.fill"
        ),
        "Core Care": PillarUIConfig(
            name: "Core Care",
            color: Color(red: 0.90, green: 0.49, blue: 0.13),
            icon: "cross.case.fill"
        )
    ]

    static func config(for pillar: String) -> PillarUIConfig {
        return configs[pillar] ?? PillarUIConfig(
            name: pillar,
            color: .gray,
            icon: "circle.fill"
        )
    }
}

// MARK: - Marker Items (for Markers component breakdown)

struct MarkerItem: Codable, Identifiable {
    var id: String { biomarkerName ?? biometricName ?? UUID().uuidString }
    let pillarName: String
    let itemType: String // "biomarker" or "biometric"
    let biomarkerName: String?
    let biometricName: String?
    let itemDisplayName: String
    let itemPercentage: Double
    let itemWeightInPillar: Double
    let scoreBand: String // "Optimal", "In-Range", "Out-of-Range"

    enum CodingKeys: String, CodingKey {
        case pillarName = "pillar_name"
        case itemType = "item_type"
        case biomarkerName = "biomarker_name"
        case biometricName = "biometric_name"
        case itemDisplayName = "item_display_name"
        case itemPercentage = "item_percentage"
        case itemWeightInPillar = "item_weight_in_pillar"
        case scoreBand = "score_band"
    }

    var isBiometric: Bool { itemType == "biometric" }
    var name: String { biomarkerName ?? biometricName ?? itemDisplayName }

    var percentageInt: Int {
        Int(itemPercentage.rounded())
    }

    var weightPercentage: String {
        String(format: "%.1f%%", itemWeightInPillar * 100)
    }

    var statusColor: Color {
        switch scoreBand {
        case "Optimal": return .green
        case "In-Range": return .blue
        case "Out-of-Range": return .red
        default: return .gray
        }
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
