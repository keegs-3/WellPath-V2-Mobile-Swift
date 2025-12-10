//
//  MetricsUIConfig.swift
//  WellPath
//
//  Created on 2025-10-22
//  Updated 2025-11-30: Now delegates to DisplayConfigurationService for database-driven config
//

import SwiftUI

@MainActor
struct MetricsUIConfig {

    // MARK: - Database-Driven Accessors (Preferred)

    /// Access the shared configuration service
    /// Call DisplayConfigurationService.shared.loadConfiguration() at app startup
    private static var configService: DisplayConfigurationService {
        DisplayConfigurationService.shared
    }

    // MARK: - Pillar Color & Icon (Database-driven with fallback)

    static func getPillarColor(for pillarName: String) -> Color {
        if configService.isLoaded {
            return configService.pillarColor(for: pillarName)
        }
        return fallbackPillarColors[pillarName] ?? .gray
    }

    static func getPillarIcon(for pillarName: String) -> String {
        if configService.isLoaded {
            return configService.pillarIcon(for: pillarName)
        }
        return fallbackPillarIcons[pillarName] ?? "circle.fill"
    }

    // MARK: - View Icon (Database-driven with fallback)

    static func getIcon(for screenName: String, viewId: String? = nil) -> String {
        // First try database lookup by view_id
        if let viewId = viewId, configService.isLoaded {
            return configService.viewIcon(for: viewId)
        }
        // Fallback to string matching for backward compatibility
        return getIconByStringMatch(for: screenName)
    }

    // MARK: - Card Category Accessors (Database-driven)

    static func getCategoryColor(for categoryId: String) -> Color {
        if configService.isLoaded {
            return configService.cardCategoryColor(for: categoryId)
        }
        // Fallback
        if let pillarName = fallbackCategoryToPillarMapping[categoryId] {
            return fallbackPillarColors[pillarName] ?? .gray
        }
        return .gray
    }

    static func getCategoryIcon(for categoryId: String) -> String {
        if configService.isLoaded {
            return configService.cardCategoryIcon(for: categoryId)
        }
        return "circle.fill"
    }

    // MARK: - Tier Colors (Database-driven with fallback)

    static var tierGood: Color {
        configService.isLoaded ? configService.tierGood : (Color(hex: "#80CBC4") ?? .teal)
    }

    static var tierMedium: Color {
        configService.isLoaded ? configService.tierMedium : (Color(hex: "#8DD8FF") ?? .blue)
    }

    static var tierPoor: Color {
        configService.isLoaded ? configService.tierPoor : (Color(hex: "#EB875D") ?? .orange)
    }

    static func getTierColor(for tier: Int) -> Color {
        if configService.isLoaded {
            return configService.tierColor(for: tier)
        }
        switch tier {
        case 1: return tierGood
        case 2: return tierMedium
        case 3: return tierPoor
        default: return .gray
        }
    }

    static func getTierColor(tierId: String, viewId: String) -> Color {
        if configService.isLoaded {
            return configService.tierColor(tierId: tierId, viewId: viewId)
        }
        return .gray
    }

    // MARK: - Gradient Generation

    static func generateGradient(from baseColor: Color, count: Int) -> [Color] {
        guard count > 0 else { return [] }
        guard count > 1 else { return [baseColor] }

        var colors: [Color] = []
        for i in 0..<count {
            let ratio = Double(i) / Double(count - 1)
            let opacity = 0.7 + (ratio * 0.3)
            colors.append(baseColor.opacity(opacity))
        }
        return colors
    }

    static func getProteinTypeColor(tier: Int, positionInTier: Int, totalInTier: Int) -> Color {
        let baseColor = getTierColor(for: tier)
        if totalInTier == 1 { return baseColor }
        let gradient = generateGradient(from: baseColor, count: totalInTier)
        return gradient[min(positionInTier, gradient.count - 1)]
    }

    // MARK: - Legacy Accessors (Deprecated - use above methods)

    @available(*, deprecated, message: "Use getPillarColor(for:) instead")
    static let pillarColors: [String: Color] = fallbackPillarColors

    @available(*, deprecated, message: "Use getPillarIcon(for:) instead")
    static let pillarIcons: [String: String] = fallbackPillarIcons

    // MARK: - Fallback Data (used when DB not loaded)

    private static let fallbackPillarColors: [String: Color] = [
        "Healthful Nutrition": Color(hex: "#8DD8FF") ?? .blue,
        "Movement + Exercise": Color(hex: "#EB875D") ?? .orange,
        "Restorative Sleep": Color(hex: "#80CBC4") ?? .teal,
        "Stress Management": Color(hex: "#ED8D8D") ?? .pink,
        "Cognitive Health": Color(hex: "#C6B5FF") ?? .purple,
        "Connection + Purpose": Color(hex: "#ADD399") ?? .green,
        "Core Care": Color(hex: "#F4D284") ?? .yellow,
        "Biometrics": Color(hex: "#00CED1") ?? .cyan,
        "Biomarkers": Color(hex: "#FF8C00") ?? .orange,
        "Biological Age": Color(hex: "#9370DB") ?? .purple
    ]

    private static let fallbackPillarIcons: [String: String] = [
        "Healthful Nutrition": "fork.knife",
        "Movement + Exercise": "figure.walk",
        "Restorative Sleep": "bed.double.fill",
        "Cognitive Health": "brain.head.profile",
        "Stress Management": "heart.fill",
        "Connection + Purpose": "person.2.fill",
        "Core Care": "cross.fill",
        "Biometrics": "waveform.path.ecg",
        "Biomarkers": "testtube.2",
        "Biological Age": "hourglass"
    ]

    private static let fallbackCategoryToPillarMapping: [String: String] = [
        "Nutrition": "Healthful Nutrition",
        "Exercise": "Movement + Exercise",
        "Sleep": "Restorative Sleep",
        "Biometrics": "Biometrics"
    ]

    // MARK: - String-based Icon Matching (Fallback)

    private static func getIconByStringMatch(for screenName: String) -> String {
        let lowercased = screenName.lowercased()

        // Nutrition
        if lowercased.contains("vegetable") { return "carrot.fill" }
        if lowercased.contains("fruit") { return "apple.logo" }
        if lowercased.contains("protein") { return "fish.fill" }
        if lowercased.contains("legume") { return "leaf.fill" }
        if lowercased.contains("grain") { return "basket.fill" }
        if lowercased.contains("fiber") { return "laurel.leading" }
        if lowercased.contains("fat") { return "heart.fill" }
        if lowercased.contains("sugar") { return "cube.fill" }
        if lowercased.contains("hydration") || lowercased.contains("water") { return "drop.fill" }
        if lowercased.contains("meal timing") { return "clock.fill" }
        if lowercased.contains("meal quality") { return "hand.thumbsup.fill" }

        // Movement & Exercise
        if lowercased.contains("steps") { return "figure.walk" }
        if lowercased.contains("cardio") { return "figure.run" }
        if lowercased.contains("strength") { return "dumbbell.fill" }
        if lowercased.contains("hiit") { return "bolt.fill" }
        if lowercased.contains("mobility") { return "figure.flexibility" }
        if lowercased.contains("activity") { return "figure.walk.motion" }

        // Sleep
        if lowercased.contains("sleep") { return "bed.double.fill" }

        // Stress Management
        if lowercased.contains("meditation") || lowercased.contains("mindfulness") { return "figure.mind.and.body" }
        if lowercased.contains("stress") { return "heart.fill" }
        if lowercased.contains("breath") { return "wind" }

        // Cognitive Health
        if lowercased.contains("cognitive") || lowercased.contains("brain") { return "brain.head.profile" }
        if lowercased.contains("light") || lowercased.contains("circadian") { return "sun.max.fill" }

        // Connection & Purpose
        if lowercased.contains("social") { return "person.2.fill" }
        if lowercased.contains("outdoor") { return "tree.fill" }
        if lowercased.contains("gratitude") { return "heart.circle.fill" }

        // Biometrics
        if lowercased.contains("weight") { return "scalemass" }
        if lowercased.contains("bmi") { return "figure.stand" }
        if lowercased.contains("body fat") { return "percent" }
        if lowercased.contains("hrv") { return "waveform.path.ecg" }
        if lowercased.contains("vo2") { return "lungs" }

        // Substances
        if lowercased.contains("alcohol") { return "wineglass.fill" }
        if lowercased.contains("caffeine") { return "cup.and.saucer.fill" }
        if lowercased.contains("cigarette") || lowercased.contains("tobacco") { return "smoke.fill" }

        return "circle.fill"
    }
}
