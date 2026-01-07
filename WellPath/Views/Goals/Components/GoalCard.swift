//
//  GoalCard.swift
//  WellPath
//
//  Reusable card for displaying goal progress in GoalsListView
//  Shows progress ring, goal name, current/target, pillar badge
//

import SwiftUI

struct GoalCard: View {
    let goal: PatientGoal
    let progress: GoalProgress?
    let isAvailable: Bool  // true = in Available tab (not yet activated)

    var onTryAsChallenge: (() -> Void)?
    var onRequestAsGoal: (() -> Void)?

    private var pillar: HealthPillar {
        HealthPillar(rawValue: goal.pillarId) ?? .core
    }

    private var pillarColor: Color {
        Color(hex: pillar.color) ?? .green
    }

    private var progressPercent: Double {
        progress?.displayProgress ?? 0
    }

    private var actualValue: Double {
        progress?.displayActual ?? 0
    }

    private var statusColor: Color {
        guard let status = progress?.status else { return .gray }
        switch status {
        case .ahead, .completed: return .green
        case .onTrack: return pillarColor
        case .atRisk: return .orange
        case .behind: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row: pillar badge + goal name
            HStack(spacing: 10) {
                // Pillar icon
                ZStack {
                    Circle()
                        .fill(pillarColor.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: pillar.icon)
                        .font(.system(size: 16))
                        .foregroundColor(pillarColor)
                }

                // Goal title
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Text(pillar.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Progress ring (for active goals)
                if !isAvailable {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                            .frame(width: 44, height: 44)

                        Circle()
                            .trim(from: 0, to: min(progressPercent / 100, 1.0))
                            .stroke(statusColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 44, height: 44)
                            .rotationEffect(.degrees(-90))

                        Text("\(Int(progressPercent))%")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(statusColor)
                    }
                }
            }

            // Progress details (for active goals)
            if !isAvailable {
                HStack {
                    // Current / Target
                    if goal.isWeekly {
                        Text("\(Int(actualValue)) / \(Int(goal.targetValue)) \(goal.targetUnit) this week")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(Int(actualValue)) / \(Int(goal.targetValue))\(goal.targetUnit) today")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Status badge
                    if let status = progress?.status {
                        StatusBadge(status: status)
                    }
                }
            }

            // Available goal actions
            if isAvailable {
                // Description if available
                if let description = goal.template?.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        onTryAsChallenge?()
                    } label: {
                        Label("Try as Challenge", systemImage: "flame")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                    }

                    Button {
                        onRequestAsGoal?()
                    } label: {
                        Label("Request", systemImage: "plus.circle")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(pillarColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(pillarColor.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(pillarColor.opacity(isAvailable ? 0.3 : 0), lineWidth: 1)
        )
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: ProgressStatus

    private var text: String {
        switch status {
        case .ahead: return "Ahead"
        case .onTrack: return "On Track"
        case .atRisk: return "At Risk"
        case .behind: return "Behind"
        case .completed: return "Complete"
        }
    }

    private var color: Color {
        switch status {
        case .ahead, .completed: return .green
        case .onTrack: return .blue
        case .atRisk: return .orange
        case .behind: return .red
        }
    }

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .cornerRadius(4)
    }
}

// MARK: - Compact Goal Row (for lists)

struct GoalRow: View {
    let goal: PatientGoal
    let progress: GoalProgress?

    private var pillar: HealthPillar {
        HealthPillar(rawValue: goal.pillarId) ?? .core
    }

    private var pillarColor: Color {
        Color(hex: pillar.color) ?? .green
    }

    private var progressPercent: Double {
        progress?.displayProgress ?? 0
    }

    var body: some View {
        HStack(spacing: 12) {
            // Pillar icon
            ZStack {
                Circle()
                    .fill(pillarColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: pillar.icon)
                    .foregroundColor(pillarColor)
            }

            // Goal info
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(Int(goal.targetValue))\(goal.targetUnit) \(goal.isWeekly ? "weekly" : "daily")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Progress
            Text("\(Int(progressPercent))%")
                .font(.headline)
                .foregroundColor(pillarColor)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            // Mock active goal
            GoalCard(
                goal: PatientGoal.mockProteinGoal(),
                progress: GoalProgress.mockProgress(),
                isAvailable: false
            )

            // Mock available goal
            GoalCard(
                goal: PatientGoal.mockStepsGoal(),
                progress: nil,
                isAvailable: true,
                onTryAsChallenge: { print("Try challenge") },
                onRequestAsGoal: { print("Request goal") }
            )

            // Row style
            GoalRow(
                goal: PatientGoal.mockProteinGoal(),
                progress: GoalProgress.mockProgress()
            )
        }
        .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}

// MARK: - Mock Data for Previews

#if DEBUG
extension PatientGoal {
    static func mockProteinGoal() -> PatientGoal {
        // Create mock JSON and decode to match Codable struct
        let json = """
        {
            "goal_id": "goal-1",
            "patient_id": "patient-1",
            "template_id": "GOAL_PROTEIN_TOTAL",
            "target_value": 120,
            "target_unit": "g",
            "target_frequency": "daily",
            "tracking_mode": "detailed",
            "status": "active",
            "cycle_start": "2025-01-01",
            "assigned_at": "2025-01-01T00:00:00Z",
            "goal_templates": {
                "template_id": "GOAL_PROTEIN_TOTAL",
                "title": "Daily Protein",
                "description": "Hit your daily protein target",
                "pillar_id": "nutrition",
                "target_type": "increase",
                "frequency": "daily",
                "is_active": true
            }
        }
        """
        return try! JSONDecoder().decode(PatientGoal.self, from: json.data(using: .utf8)!)
    }

    static func mockStepsGoal() -> PatientGoal {
        let json = """
        {
            "goal_id": "goal-2",
            "patient_id": "patient-1",
            "template_id": "GOAL_STEPS_DAILY",
            "target_value": 10000,
            "target_unit": " steps",
            "target_frequency": "daily",
            "tracking_mode": "quick",
            "status": "active",
            "cycle_start": "2025-01-01",
            "assigned_at": "2025-01-01T00:00:00Z",
            "goal_templates": {
                "template_id": "GOAL_STEPS_DAILY",
                "title": "Daily Steps",
                "description": "Walk 10,000 steps each day for cardiovascular health",
                "pillar_id": "movement",
                "target_type": "increase",
                "frequency": "daily",
                "is_active": true
            }
        }
        """
        return try! JSONDecoder().decode(PatientGoal.self, from: json.data(using: .utf8)!)
    }
}

extension GoalProgress {
    static func mockProgress() -> GoalProgress {
        let json = """
        {
            "id": "progress-1",
            "patient_id": "patient-1",
            "goal_id": "goal-1",
            "progress_date": "2025-01-15",
            "actual_value": 85,
            "target_value": 120,
            "progress_percentage": 71,
            "status": "on_track"
        }
        """
        return try! JSONDecoder().decode(GoalProgress.self, from: json.data(using: .utf8)!)
    }
}
#endif
