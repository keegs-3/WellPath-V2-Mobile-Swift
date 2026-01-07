//
//  DemoDataFixtures.swift
//  WellPath
//
//  Sample data for demo mode - shown when patient hasn't completed onboarding.
//  Uses hardcoded values for offline reliability.
//

import Foundation
import SwiftUI

// MARK: - Demo Data Container

/// Central container for all demo/sample data used in tours and demo views
enum DemoData {

    // MARK: - WellPath Score

    /// Sample WellPath score (0-100)
    static let wellPathScore: Int = 72

    /// Sample pillar scores with colors
    static let pillarScores: [(name: String, score: Int, icon: String, color: Color)] = [
        ("Movement & Exercise", 68, "figure.run", .orange),
        ("Healthful Nutrition", 75, "leaf.fill", .green),
        ("Restorative Sleep", 71, "moon.fill", .indigo),
        ("Stress Management", 65, "brain.head.profile", .yellow),
        ("Connection & Purpose", 78, "heart.fill", .pink),
        ("Substances & Behaviors", 82, "hand.raised.fill", .purple),
        ("Environment & Safety", 70, "house.fill", .cyan)
    ]

    /// Sample score history for trend display
    static let scoreHistory: [(date: Date, score: Int)] = {
        let calendar = Calendar.current
        let today = Date()
        return [
            (calendar.date(byAdding: .day, value: -30, to: today)!, 64),
            (calendar.date(byAdding: .day, value: -23, to: today)!, 66),
            (calendar.date(byAdding: .day, value: -16, to: today)!, 68),
            (calendar.date(byAdding: .day, value: -9, to: today)!, 70),
            (calendar.date(byAdding: .day, value: -2, to: today)!, 72)
        ]
    }()

    // MARK: - Goals

    /// Sample goals for demo
    static let goals: [DemoGoal] = [
        DemoGoal(
            id: "demo-steps",
            title: "Daily Steps",
            pillar: "Movement",
            icon: "figure.walk",
            color: .orange,
            targetValue: 10000,
            currentValue: 7500,
            unit: "steps",
            frequency: "daily"
        ),
        DemoGoal(
            id: "demo-protein",
            title: "Protein Intake",
            pillar: "Nutrition",
            icon: "fork.knife",
            color: .green,
            targetValue: 120,
            currentValue: 95,
            unit: "g",
            frequency: "daily"
        ),
        DemoGoal(
            id: "demo-sleep",
            title: "Sleep Duration",
            pillar: "Sleep",
            icon: "bed.double.fill",
            color: .indigo,
            targetValue: 7.5,
            currentValue: 6.8,
            unit: "hrs",
            frequency: "daily"
        )
    ]

    /// Sample weekly adherence percentage
    static let weeklyAdherence: Double = 68.0

    /// Sample max potential for the week
    static let weeklyMaxPotential: Double = 92.0

    // MARK: - Nudges

    /// Sample coach nudge
    static let sampleNudge = DemoNudge(
        title: "Great Progress!",
        message: "You're on track with your protein goal today. Keep it up!",
        icon: "sparkles",
        color: .green
    )

    /// Sample nudges for nudge list
    static let nudges: [DemoNudge] = [
        DemoNudge(
            title: "Great Progress!",
            message: "You're on track with your protein goal today. Keep it up!",
            icon: "sparkles",
            color: .green
        ),
        DemoNudge(
            title: "Movement Reminder",
            message: "You're 2,500 steps away from your daily goal. A short walk could help!",
            icon: "figure.walk",
            color: .orange
        ),
        DemoNudge(
            title: "Sleep Tip",
            message: "Try dimming lights 30 minutes before bed for better sleep quality.",
            icon: "moon.fill",
            color: .indigo
        )
    ]

    // MARK: - Cycle Info

    /// Sample cycle number
    static let cycleNumber: Int = 1

    /// Sample cycle week
    static let cycleWeek: Int = 4

    /// Sample cycle total weeks
    static let cycleTotalWeeks: Int = 13

    // MARK: - Challenge

    /// Sample active challenge
    static let challenge = DemoChallenge(
        title: "7-Day Step Streak",
        description: "Hit your step goal 7 days in a row",
        currentDay: 4,
        totalDays: 7,
        icon: "flame.fill",
        color: .orange
    )
}

// MARK: - Demo Data Models

/// Sample goal for demo mode
struct DemoGoal: Identifiable {
    let id: String
    let title: String
    let pillar: String
    let icon: String
    let color: Color
    let targetValue: Double
    let currentValue: Double
    let unit: String
    let frequency: String

    var progressPercentage: Double {
        guard targetValue > 0 else { return 0 }
        return min((currentValue / targetValue) * 100, 100)
    }

    var progressStatus: String {
        if progressPercentage >= 100 { return "Completed" }
        if progressPercentage >= 80 { return "Almost There" }
        if progressPercentage >= 50 { return "On Track" }
        if progressPercentage >= 25 { return "Keep Going" }
        return "Just Started"
    }

    var formattedCurrent: String {
        if currentValue == floor(currentValue) {
            return String(format: "%.0f", currentValue)
        }
        return String(format: "%.1f", currentValue)
    }

    var formattedTarget: String {
        if targetValue == floor(targetValue) {
            return String(format: "%.0f", targetValue)
        }
        return String(format: "%.1f", targetValue)
    }
}

/// Sample nudge for demo mode
struct DemoNudge: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let icon: String
    let color: Color
}

/// Sample challenge for demo mode
struct DemoChallenge: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let currentDay: Int
    let totalDays: Int
    let icon: String
    let color: Color

    var progressPercentage: Double {
        guard totalDays > 0 else { return 0 }
        return Double(currentDay) / Double(totalDays) * 100
    }
}

// MARK: - Demo Badge View

/// "DEMO" badge overlay for demo content
struct DemoBadgeView: View {
    var style: BadgeStyle = .pill

    enum BadgeStyle {
        case pill      // Small pill in corner
        case banner    // Full-width banner at top
        case subtle    // Small text indicator
    }

    var body: some View {
        switch style {
        case .pill:
            Text("DEMO")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.8))
                )

        case .banner:
            HStack {
                Image(systemName: "sparkles")
                    .font(.caption)
                Text("Preview Mode")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("- Sample data shown")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.blue)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color.blue.opacity(0.1))

        case .subtle:
            HStack(spacing: 4) {
                Image(systemName: "eye.fill")
                    .font(.caption2)
                Text("Demo")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview("Demo Goals") {
    VStack(spacing: 16) {
        ForEach(DemoData.goals) { goal in
            HStack {
                Image(systemName: goal.icon)
                    .foregroundColor(goal.color)
                VStack(alignment: .leading) {
                    Text(goal.title)
                        .font(.headline)
                    Text("\(goal.formattedCurrent)/\(goal.formattedTarget) \(goal.unit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(Int(goal.progressPercentage))%")
                    .font(.headline)
                    .foregroundColor(goal.color)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    .padding()
}

#Preview("Demo Badge Styles") {
    VStack(spacing: 20) {
        DemoBadgeView(style: .pill)
        DemoBadgeView(style: .banner)
        DemoBadgeView(style: .subtle)
    }
    .padding()
}
