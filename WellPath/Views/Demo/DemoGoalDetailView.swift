//
//  DemoGoalDetailView.swift
//  WellPath
//
//  Hardcoded demo version of GoalDetailView for the onboarding tour.
//  Matches the real GoalDetailView UI but with static sample data.
//  Completely self-contained - no network calls or database dependencies.
//

import SwiftUI

// MARK: - Demo Goal Types

enum DemoGoalType: String, CaseIterable {
    case protein
    case steps
    case sleep
    case strength

    var title: String {
        switch self {
        case .protein: return "Daily Protein Target"
        case .steps: return "Daily Steps"
        case .sleep: return "Sleep Duration"
        case .strength: return "Strength Training"
        }
    }

    var shortTitle: String {
        switch self {
        case .protein: return "Protein"
        case .steps: return "Steps"
        case .sleep: return "Sleep"
        case .strength: return "Strength"
        }
    }

    var icon: String {
        switch self {
        case .protein: return "fork.knife"
        case .steps: return "figure.walk"
        case .sleep: return "bed.double.fill"
        case .strength: return "dumbbell.fill"
        }
    }

    var pillarName: String {
        switch self {
        case .protein: return "Healthful Nutrition"
        case .steps: return "Movement & Exercise"
        case .sleep: return "Restorative Sleep"
        case .strength: return "Movement & Exercise"
        }
    }

    var color: Color {
        switch self {
        case .protein: return Color(red: 0.58, green: 0.91, blue: 0.47) // Nutrition green
        case .steps: return Color(red: 0.31, green: 0.80, blue: 0.77) // Movement teal
        case .sleep: return Color(red: 0.48, green: 0.41, blue: 0.93) // Sleep purple
        case .strength: return Color(red: 0.31, green: 0.80, blue: 0.77) // Movement teal
        }
    }

    var targetValue: Int {
        switch self {
        case .protein: return 120
        case .steps: return 10000
        case .sleep: return 7
        case .strength: return 3
        }
    }

    var targetUnit: String {
        switch self {
        case .protein: return "g"
        case .steps: return "steps"
        case .sleep: return "hours"
        case .strength: return "sessions"
        }
    }

    var periodLabel: String {
        switch self {
        case .protein: return "per day"
        case .steps: return "per day"
        case .sleep: return "per night"
        case .strength: return "per week"
        }
    }

    var isWeekly: Bool {
        self == .strength
    }

    var currentValue: Int {
        switch self {
        case .protein: return 90
        case .steps: return 7500
        case .sleep: return 6
        case .strength: return 2
        }
    }

    var progressPercent: Double {
        switch self {
        case .protein: return 75
        case .steps: return 75
        case .sleep: return 86
        case .strength: return 67
        }
    }

    var description: String {
        switch self {
        case .protein: return "Hit your personalized daily protein goal for muscle maintenance and metabolic health."
        case .steps: return "Achieve your daily step target to improve cardiovascular health and energy levels."
        case .sleep: return "Get adequate sleep each night to support recovery, cognitive function, and overall wellbeing."
        case .strength: return "Complete resistance training sessions to build muscle, improve bone density, and boost metabolism."
        }
    }

    var rationale: String {
        switch self {
        case .protein: return "Based on your body composition goals and activity level, adequate protein supports muscle maintenance, satiety, and metabolic health. Research shows that distributing protein intake across meals optimizes muscle protein synthesis."
        case .steps: return "Regular walking is one of the most effective ways to improve cardiovascular health, manage weight, and boost mood. Your step target is personalized based on your baseline activity and health goals."
        case .sleep: return "Quality sleep is foundational to health - it affects hormone regulation, immune function, cognitive performance, and emotional wellbeing. Your target is based on research-backed recommendations for your age group."
        case .strength: return "Resistance training preserves muscle mass as you age, improves bone density, enhances metabolic rate, and supports functional independence. Even 2-3 sessions per week provides significant benefits."
        }
    }

    var tips: [String] {
        switch self {
        case .protein:
            return [
                "Add a protein source to every meal (eggs, chicken, fish, legumes)",
                "Keep protein-rich snacks on hand (Greek yogurt, nuts, cheese)",
                "Front-load protein at breakfast to reduce cravings later"
            ]
        case .steps:
            return [
                "Take walking meetings or phone calls",
                "Park farther away or get off transit one stop early",
                "Set hourly reminders to take a 5-minute walk break"
            ]
        case .sleep:
            return [
                "Maintain a consistent bedtime, even on weekends",
                "Create a wind-down routine 30 minutes before bed",
                "Keep your bedroom cool, dark, and screen-free"
            ]
        case .strength:
            return [
                "Start with bodyweight exercises if you're new to training",
                "Focus on compound movements (squats, pushups, rows)",
                "Allow 48 hours between sessions for the same muscle groups"
            ]
        }
    }

    var weeklyData: [Double] {
        switch self {
        case .protein: return [95, 110, 85, 120, 90, 105, 0]  // Last day is today
        case .steps: return [8500, 10200, 6500, 11000, 7500, 9000, 0]
        case .sleep: return [7.5, 6.5, 7.0, 8.0, 6.0, 7.5, 0]
        case .strength: return [1, 0, 1, 0, 0, 0, 0]  // 2 sessions done
        }
    }

    var weeklyAverage: Int {
        let data = weeklyData.filter { $0 > 0 }
        guard !data.isEmpty else { return 0 }
        return Int(data.reduce(0, +) / Double(data.count))
    }

    var daysCompleted: Int {
        weeklyData.filter { $0 >= Double(targetValue) }.count
    }
}

// MARK: - Demo Goal Detail View

struct DemoGoalDetailView: View {
    let goalType: DemoGoalType

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero Section
                heroSection

                // My Goal
                myGoalSection

                // This Week Progress
                weekProgressSection

                // Why This Recommendation
                rationaleSection

                // Tips to Get Started
                tipsSection

                // Actions
                actionsSection
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(goalType.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        // Demo - no action
                    } label: {
                        Label("Pause Goal", systemImage: "pause.circle")
                    }

                    Button(role: .destructive) {
                        // Demo - no action
                    } label: {
                        Label("Request to Remove", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            // Pillar badge
            HStack {
                Image(systemName: goalType.icon)
                    .foregroundColor(goalType.color)
                Text(goalType.pillarName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(goalType.color.opacity(0.1))
            .cornerRadius(16)

            // Large progress ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: goalType.progressPercent / 100)
                    .stroke(goalType.color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(Int(goalType.progressPercent))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(goalType.color)

                    Text(goalType.isWeekly ? "This Week" : "Today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Status badge
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("On Track")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)

            // Max potential hint
            Text("You can still reach 100% this week!")
                .font(.caption)
                .foregroundColor(.green)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - My Goal Section

    private var myGoalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "My Goal", icon: "target")

            VStack(alignment: .leading, spacing: 8) {
                // Target display
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(goalType.targetValue)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(goalType.color)

                    Text(goalType.targetUnit)
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text(goalType.periodLabel)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Description
                Text(goalType.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Current progress
                HStack {
                    Text("Current:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(goalType.currentValue)\(goalType.targetUnit)")
                        .font(.caption)
                        .fontWeight(.semibold)

                    Spacer()

                    Text("Remaining:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    let remaining = max(0, goalType.targetValue - goalType.currentValue)
                    Text("\(remaining)\(goalType.targetUnit)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(remaining > 0 ? .orange : .green)
                }
                .padding(.top, 4)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Week Progress Section

    private var weekProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "This Week", icon: "calendar")

            VStack(spacing: 12) {
                // Day bars
                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { index in
                        DemoDayBar(
                            dayLabel: dayLabel(for: index),
                            value: goalType.weeklyData[index],
                            target: Double(goalType.targetValue),
                            isToday: index == 6,
                            accentColor: goalType.color
                        )
                    }
                }
                .frame(height: 100)

                // Week summary
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Week Average")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(goalType.weeklyAverage)\(goalType.targetUnit)")
                            .font(.headline)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Days Completed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(goalType.daysCompleted) / 7")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    private func dayLabel(for index: Int) -> String {
        let labels = ["S", "S", "M", "T", "W", "T", "F"]
        return labels[index]
    }

    // MARK: - Rationale Section

    private var rationaleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Why This Recommendation", icon: "lightbulb.fill")

            Text(goalType.rationale)
                .font(.subheadline)
                .foregroundColor(.primary)
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
        }
    }

    // MARK: - Tips Section

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Tips to Get Started", icon: "checkmark.circle.fill")

            VStack(alignment: .leading, spacing: 8) {
                ForEach(goalType.tips.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(goalType.color)
                            .clipShape(Circle())

                        Text(goalType.tips[index])
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Primary log button
            Button {
                // Demo - no action
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Log Progress")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(goalType.color)
                .cornerRadius(12)
            }

            // Secondary actions
            HStack(spacing: 12) {
                Button {
                    // Demo - no action
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("History")
                    }
                    .font(.subheadline)
                    .foregroundColor(goalType.color)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(goalType.color.opacity(0.1))
                    .cornerRadius(12)
                }

                Button {
                    // Demo - no action
                } label: {
                    HStack {
                        Image(systemName: "book.fill")
                        Text("Learn More")
                    }
                    .font(.subheadline)
                    .foregroundColor(goalType.color)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(goalType.color.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }
}

// MARK: - Demo Day Bar

struct DemoDayBar: View {
    let dayLabel: String
    let value: Double
    let target: Double
    let isToday: Bool
    let accentColor: Color

    private var fillPercent: Double {
        guard target > 0 else { return 0 }
        return min(value / target, 1.0)
    }

    var body: some View {
        VStack(spacing: 4) {
            // Bar
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    // Fill
                    if value > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(fillPercent >= 1.0 ? Color.green : accentColor)
                            .frame(height: geometry.size.height * fillPercent)
                    }
                }
            }

            // Day label
            Text(dayLabel)
                .font(.caption2)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundColor(isToday ? accentColor : .secondary)
        }
    }
}

// MARK: - Preview

#Preview("Protein Goal") {
    NavigationStack {
        DemoGoalDetailView(goalType: .protein)
    }
}

#Preview("Steps Goal") {
    NavigationStack {
        DemoGoalDetailView(goalType: .steps)
    }
}

#Preview("Sleep Goal") {
    NavigationStack {
        DemoGoalDetailView(goalType: .sleep)
    }
}

#Preview("Strength Goal") {
    NavigationStack {
        DemoGoalDetailView(goalType: .strength)
    }
}
