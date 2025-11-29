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
        // 7 Scoring Pillars
        "Healthful Nutrition": Color(hex: "#8DD8FF") ?? .blue,
        "Movement + Exercise": Color(hex: "#EB875D") ?? .orange,
        "Restorative Sleep": Color(hex: "#80CBC4") ?? .teal,
        "Stress Management": Color(hex: "#ED8D8D") ?? .pink,
        "Cognitive Health": Color(hex: "#C6B5FF") ?? .purple,
        "Connection + Purpose": Color(hex: "#ADD399") ?? .green,
        "Core Care": Color(hex: "#F4D284") ?? .yellow,
        // Bio3 (Non-scoring)
        "Biometrics": Color(hex: "#66CCFF") ?? .cyan,
        "Biomarkers": Color(hex: "#BD8FF0") ?? .purple,
        "Biological Age": Color(hex: "#E066FF") ?? .pink
    ]

    static let pillarIcons: [String: String] = [
        // 7 Scoring Pillars
        "Healthful Nutrition": "fork.knife",
        "Movement + Exercise": "figure.walk",
        "Restorative Sleep": "bed.double.fill",
        "Cognitive Health": "brain.head.profile",
        "Stress Management": "heart.fill",
        "Connection + Purpose": "person.2.fill",
        "Core Care": "cross.fill",
        // Bio3 (Non-scoring)
        "Biometrics": "waveform.path.ecg",
        "Biomarkers": "testtube.2",
        "Biological Age": "hourglass"
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

        // Core Care - Biometrics
        if lowercased.contains("body weight") || lowercased.contains("bodyweight") || lowercased.contains("weight") {
            return "scalemass"
        }
        if lowercased.contains("bmi") {
            return "figure.stand"
        }
        if lowercased.contains("body fat") || lowercased.contains("bodyfat") {
            return "percent"
        }
        if lowercased.contains("visceral") {
            return "circle.inset.filled"
        }
        if lowercased.contains("waist") || lowercased.contains("hip ratio") {
            return "ruler"
        }
        if lowercased.contains("smm") || lowercased.contains("ffm") || lowercased.contains("muscle mass") {
            return "figure.strengthtraining.traditional"
        }
        if lowercased.contains("resting heart") || lowercased.contains("resting hr") {
            return "heart"
        }
        if lowercased.contains("hrv") || lowercased.contains("heart rate variability") {
            return "waveform.path.ecg"
        }
        if lowercased.contains("vo2") {
            return "lungs"
        }
        if lowercased.contains("grip") {
            return "hand.raised"
        }
        if lowercased.contains("biometric") {
            return "waveform.path.ecg"
        }
        if lowercased.contains("biomarker") {
            return "testtube.2"
        }
        if lowercased.contains("biological age") {
            return "hourglass"
        }

        // Bio3 Category icons
        if lowercased.contains("body composition") {
            return "figure.stand"
        }
        if lowercased.contains("cardiovascular") {
            return "heart.fill"
        }
        if lowercased.contains("strength") && !lowercased.contains("training") {
            return "dumbbell.fill"
        }
        if lowercased.contains("metabolism") {
            return "flame.fill"
        }
        if lowercased.contains("inflammation") {
            return "waveform.path.ecg"
        }
        if lowercased.contains("hormone") {
            return "pills.fill"
        }
        if lowercased.contains("immune") || lowercased.contains("renal") {
            return "shield.fill"
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

    // MARK: - Quality Tier Colors (Good → Medium → Poor)

    static let tierGood = Color(hex: "#80CBC4") ?? .teal // Restorative Sleep
    static let tierMedium = Color(hex: "#8DD8FF") ?? .blue // Healthful Nutrition
    static let tierPoor = Color(hex: "#EB875D") ?? .orange // Movement (orange-red)

    /// Generate gradient colors within a tier
    /// - Parameters:
    ///   - baseColor: The base color for the tier
    ///   - count: Number of gradient steps needed
    /// - Returns: Array of colors from light to dark
    static func generateGradient(from baseColor: Color, count: Int) -> [Color] {
        guard count > 0 else { return [] }
        guard count > 1 else { return [baseColor] }

        var colors: [Color] = []
        for i in 0..<count {
            let ratio = Double(i) / Double(count - 1)
            // Interpolate from lighter (0.7 opacity) to darker (1.0 opacity)
            let opacity = 0.7 + (ratio * 0.3)
            colors.append(baseColor.opacity(opacity))
        }
        return colors
    }

    /// Get color for a protein type based on its tier and position
    static func getProteinTypeColor(tier: Int, positionInTier: Int, totalInTier: Int) -> Color {
        let baseColor: Color
        switch tier {
        case 1:
            baseColor = tierGood
        case 2:
            baseColor = tierMedium
        case 3:
            baseColor = tierPoor
        default:
            return .gray
        }

        if totalInTier == 1 {
            return baseColor
        }

        let gradient = generateGradient(from: baseColor, count: totalInTier)
        return gradient[min(positionInTier, gradient.count - 1)]
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
