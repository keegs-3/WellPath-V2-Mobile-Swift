//
//  TourScoreScreen.swift
//  WellPath
//
//  Score tab tour section: Shows WellPath Score and pillar breakdown
//

import SwiftUI

struct TourScoreScreen: View {
    let highlightMode: TourScreen
    @ObservedObject private var tourManager = InteractiveTourManager.shared

    private let wellPathGreen = Color(red: 0.56, green: 0.82, blue: 0.31)

    // Check if we're highlighting a specific element
    private var hasSpecificHighlight: Bool {
        [.scoreOverview, .scoreBreakdown, .scorePillars, .pillarDetail, .componentDetail].contains(highlightMode)
    }

    // Check if element should be blurred
    private func shouldBlur(for screens: [TourScreen]) -> Bool {
        guard hasSpecificHighlight else { return false }
        return !screens.contains(highlightMode)
    }

    var body: some View {
        ZStack {
            // Subtle gradient background matching real app aesthetic
            LinearGradient(
                colors: [
                    wellPathGreen.opacity(0.05),
                    Color(uiColor: .systemBackground).opacity(0.95),
                    Color(uiColor: .systemGroupedBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // WellPath Score Card (matching real LargeScoreCard)
                    scoreCard
                        .overlay(highlightOverlay(for: .scoreOverview))
                        .overlay(highlightOverlay(for: .scoreBreakdown))
                        .blur(radius: shouldBlur(for: [.scoreOverview, .scoreBreakdown]) ? 4 : 0)
                        .opacity(shouldBlur(for: [.scoreOverview, .scoreBreakdown]) ? 0.5 : 1.0)
                        .onTapGesture {
                            if highlightMode == .scoreOverview || highlightMode == .scoreBreakdown {
                                tourManager.nextStep()
                            }
                        }

                    // Pillar Breakdown (matching real PillarBreakdownSection style)
                    pillarsSection
                        .overlay(highlightOverlay(for: .scorePillars))
                        .overlay(highlightOverlay(for: .pillarDetail))
                        .blur(radius: shouldBlur(for: [.scorePillars, .pillarDetail]) ? 4 : 0)
                        .opacity(shouldBlur(for: [.scorePillars, .pillarDetail]) ? 0.5 : 1.0)
                        .onTapGesture {
                            if highlightMode == .scorePillars {
                                // Jump to pillar detail screen
                                tourManager.goToScreen(.pillarDetail)
                            } else if highlightMode == .pillarDetail {
                                // Jump to component detail screen
                                tourManager.goToScreen(.componentDetail)
                            }
                        }
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private func highlightOverlay(for screen: TourScreen) -> some View {
        if highlightMode == screen {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green, lineWidth: 3)
                .shadow(color: .green.opacity(0.5), radius: 8)
                .padding(-4)
        }
    }

    private var scoreCard: some View {
        VStack(spacing: 20) {
            // Large Ring (matching real LargeScoreCard)
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: 0.72)
                    .stroke(wellPathGreen, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("72")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(wellPathGreen)
                    Text("/ 100")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 4) {
                Text("WellPath Score")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Updated today")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Text("Tap to view details")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private var pillarsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Health Pillars")
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                // Matching real ScorePillarRow style
                TourScorePillarRow(name: "Movement & Exercise", icon: "figure.run", score: 78, color: Color(hex: "#4ECDC4") ?? .teal)
                TourScorePillarRow(name: "Healthful Nutrition", icon: "fork.knife", score: 71, color: Color(hex: "#95E879") ?? .green)
                TourScorePillarRow(name: "Restorative Sleep", icon: "moon.zzz.fill", score: 82, color: Color(hex: "#7B68EE") ?? .purple)
                TourScorePillarRow(name: "Stress & Resilience", icon: "brain.head.profile", score: 65, color: Color(hex: "#FFB347") ?? .orange)
                TourScorePillarRow(name: "Social Connection", icon: "person.2.fill", score: 70, color: Color(hex: "#FF6B9D") ?? .pink)
                TourScorePillarRow(name: "Cognitive Health", icon: "lightbulb.fill", score: 74, color: Color(hex: "#64B5F6") ?? .blue)
                TourScorePillarRow(name: "Core Longevity", icon: "heart.fill", score: 68, color: Color(hex: "#A0A0A0") ?? .gray)
            }
        }
    }
}

// Matching real ScorePillarRow style from ScoreTabView
struct TourScorePillarRow: View {
    let name: String
    let icon: String
    let score: Int
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .foregroundColor(color)
            }

            Text(name)
                .font(.subheadline)

            Spacer()

            Text("\(score)%")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

#Preview {
    TourScoreScreen(highlightMode: .scoreOverview)
}
