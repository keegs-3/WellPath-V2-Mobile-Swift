//
//  TourComponents.swift
//  WellPath
//
//  Shared UI components used across tour screens
//

import SwiftUI

// MARK: - Tour Goal Pill

struct TourGoalPill: View {
    let icon: String
    let label: String
    let score: Int

    var body: some View {
        HStack(spacing: 8) {
            Text("\(score)")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.green)

            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial.opacity(0.6))
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Tour Adherence Arc (uses real AdherenceArcGauge)

struct TourAdherenceArc: View {
    let progress: Int
    let maxPotential: Int

    private let wellPathGreen = Color(red: 0.56, green: 0.82, blue: 0.31)

    var body: some View {
        VStack(spacing: 4) {
            // Use the REAL AdherenceArcGauge component
            AdherenceArcGauge(
                progress: Double(progress),
                maxPotential: Double(maxPotential)
            )
            .frame(height: 85)
            .padding(.top, 20)

            // Score
            Text("\(progress)")
                .font(.system(size: 64, weight: .light, design: .rounded))
                .foregroundColor(.white)

            Text("WEEKLY ADHERENCE")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.7))
                .tracking(2)

            Text("\(maxPotential)% still achievable")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(wellPathGreen)
                .padding(.top, 4)
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Tour Tab Item

struct TourTabItem: View {
    let icon: String
    let label: String
    let isHighlighted: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .fontWeight(isHighlighted ? .semibold : .regular)

            Text(label)
                .font(.caption2)
                .fontWeight(isHighlighted ? .semibold : .regular)
        }
        .foregroundStyle(isHighlighted ? Color.green : Color.secondary)
        .frame(width: 70, height: 50)
        .background(isHighlighted ? Color.green.opacity(0.1) : Color.clear)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHighlighted ? Color.green : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Tour Menu Row (for hamburger menu preview)

struct TourMenuRow: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.secondary)
                .frame(width: 28)

            Text(label)
                .font(.body)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

// MARK: - Tour Goal Detail Screen (for deep navigation)

struct TourGoalDetailScreen: View {
    let goalColor = Color(red: 0.58, green: 0.91, blue: 0.47) // Nutrition green

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero section
                VStack(spacing: 16) {
                    // Pillar badge
                    HStack {
                        Image(systemName: "fork.knife")
                            .foregroundColor(goalColor)
                        Text("Healthful Nutrition")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(goalColor.opacity(0.1))
                    .cornerRadius(16)

                    // Progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                            .frame(width: 120, height: 120)

                        Circle()
                            .trim(from: 0, to: 0.75)
                            .stroke(goalColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 2) {
                            Text("75%")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(goalColor)

                            Text("Today")
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
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(16)

                // Target section
                VStack(alignment: .leading, spacing: 12) {
                    Label("My Goal", systemImage: "target")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("120")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(goalColor)

                            Text("g protein")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            Text("per day")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Text("Hit your personalized daily protein goal for muscle maintenance and metabolic health.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }

                // Weekly chart placeholder
                VStack(alignment: .leading, spacing: 12) {
                    Label("This Week", systemImage: "calendar")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(["S", "S", "M", "T", "W", "T", "F"], id: \.self) { day in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(goalColor.opacity(Double.random(in: 0.4...1.0)))
                                    .frame(width: 28, height: CGFloat.random(in: 40...80))

                                Text(day)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

// MARK: - Previews

#Preview("Goal Pill") {
    ZStack {
        Color.black
        TourGoalPill(icon: "fork.knife", label: "Protein", score: 75)
    }
}

#Preview("Adherence Arc") {
    ZStack {
        Color.black
        TourAdherenceArc(progress: 68, maxPotential: 92)
    }
}

#Preview("Tab Item") {
    HStack {
        TourTabItem(icon: "sun.max", label: "Goals", isHighlighted: true)
        TourTabItem(icon: "gauge.with.needle", label: "Score", isHighlighted: false)
    }
    .padding()
    .background(.ultraThinMaterial)
}

#Preview("Goal Detail") {
    TourGoalDetailScreen()
}
