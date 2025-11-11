//
//  MetricsUIConfig.swift
//  WellPath
//
//  Created on 2025-10-22
//

import SwiftUI

struct MetricsUIConfig {

    // MARK: - Pillar Configuration (from database)

    static let pillarColors: [String: Color] = [
        "Healthful Nutrition": Color(hex: "#8DD8FF") ?? .blue,
        "Movement + Exercise": Color(hex: "#EB875D") ?? .orange,
        "Restorative Sleep": Color(hex: "#80CBC4") ?? .teal,
        "Stress Management": Color(hex: "#ED8D8D") ?? .pink,
        "Cognitive Health": Color(hex: "#C6B5FF") ?? .purple,
        "Connection + Purpose": Color(hex: "#ADD399") ?? .green,
        "Core Care": Color(hex: "#F4D284") ?? .yellow
    ]

    static let pillarIcons: [String: String] = [
        "Healthful Nutrition": "fork.knife",
        "Movement + Exercise": "figure.walk",
        "Restorative Sleep": "bed.double.fill",
        "Cognitive Health": "brain.head.profile",
        "Stress Management": "heart.fill",
        "Connection + Purpose": "person.2.fill",
        "Core Care": "cross.fill"
    ]

    // MARK: - Screen/Metric Icons

    static func getIcon(for screenName: String) -> String {
        let lowercased = screenName.lowercased()

        // Nutrition
        if lowercased.contains("vegetable") {
            return "carrot.fill"
        }
        if lowercased.contains("fruit") {
            return "apple.logo"
        }
        if lowercased.contains("protein") {
            return "fish.fill"
        }
        if lowercased.contains("legume") {
            return "leaf.fill"
        }
        if lowercased.contains("grain") {
            return "basket.fill"
        }
        if lowercased.contains("fiber") {
            return "laurel.leading"
        }
        if lowercased.contains("fat") {
            return "heart.fill"
        }
        if lowercased.contains("sugar") {
            return "takeoutbag.and.cup.and.straw.fill"
        }
        if lowercased.contains("hydration") || lowercased.contains("water") {
            return "drop.fill"
        }
        if lowercased.contains("meal timing") {
            return "clock.fill"
        }
        if lowercased.contains("meal quality") {
            return "hand.thumbsup.fill"
        }
        if lowercased.contains("nutrition quality") {
            return "apple.meditate.square.stack.fill"
        }

        // Movement & Exercise
        if lowercased.contains("steps") {
            return "figure.walk"
        }
        if lowercased.contains("cardio") {
            return "figure.run"
        }
        if lowercased.contains("strength") {
            return "dumbbell.fill"
        }
        if lowercased.contains("hiit") {
            return "bolt.fill"
        }
        if lowercased.contains("mobility") {
            return "figure.flexibility"
        }
        if lowercased.contains("daily activity") || lowercased.contains("activity") {
            return "figure.walk.motion"
        }

        // Sleep
        if lowercased.contains("sleep") {
            return "bed.double.fill"
        }

        // Stress Management
        if lowercased.contains("meditation") || lowercased.contains("mindfulness") {
            return "figure.mind.and.body"
        }
        if lowercased.contains("stress") {
            return "heart.fill"
        }
        if lowercased.contains("breathing") {
            return "wind"
        }

        // Cognitive Health
        if lowercased.contains("cognitive") {
            return "brain.head.profile"
        }
        if lowercased.contains("light") || lowercased.contains("circadian") {
            return "sun.max.fill"
        }
        if lowercased.contains("brain") {
            return "brain"
        }

        // Connection & Purpose
        if lowercased.contains("wellness") || lowercased.contains("connection") {
            return "heart.circle.fill"
        }
        if lowercased.contains("social") {
            return "person.2.fill"
        }
        if lowercased.contains("purpose") {
            return "star.fill"
        }

        // Core Care
        if lowercased.contains("biometric") {
            return "chart.line.uptrend.xyaxis"
        }
        if lowercased.contains("screening") {
            return "cross.case.fill"
        }
        if lowercased.contains("skincare") || lowercased.contains("sun protection") {
            return "sun.max.fill"
        }
        if lowercased.contains("substance") {
            return "circle.slash"
        }
        if lowercased.contains("medication") {
            return "pills.fill"
        }

        // Default
        return "circle.fill"
    }

    static func getPillarColor(for pillarName: String) -> Color {
        return pillarColors[pillarName] ?? .gray
    }

    static func getPillarIcon(for pillarName: String) -> String {
        return pillarIcons[pillarName] ?? "circle.fill"
    }

    // MARK: - Category Configuration (from data_entry_fields)

    static let categoryColors: [String: Color] = [
        "Nutrition": .green,
        "Exercise": .orange,
        "Sleep": .purple,
        "Biometrics": .blue,
        "Mental Health": .indigo,
        "Substances": .pink,
        "Screenings": .red
    ]

    static func getCategoryColor(for category: String) -> Color {
        return categoryColors[category] ?? .gray
    }
}
