//
//  TourGoalsScreen.swift
//  WellPath
//
//  Goals tab tour section: Shows goals UI with highlights
//  Supports drilling into goal components on tap
//

import SwiftUI

struct TourGoalsScreen: View {
    let highlightMode: TourScreen
    @ObservedObject private var tourManager = InteractiveTourManager.shared

    // Determine which element is highlighted (if any specific one)
    private var hasSpecificHighlight: Bool {
        [.goalPills, .adherenceArc, .arcMechanics, .goalsList, .coachNudges, .challenges].contains(highlightMode)
    }

    // Check if a specific element should be blurred
    private func shouldBlur(for screen: TourScreen) -> Bool {
        guard hasSpecificHighlight else { return false }
        if highlightMode == screen { return false }
        // Special case: arcMechanics also keeps arc focused
        if highlightMode == .arcMechanics && screen == .adherenceArc { return false }
        return true
    }

    var body: some View {
        ZStack {
            // Background (same as real Goals tab)
            GoalsHeroBackground()

            ScrollView {
                VStack(spacing: 16) {
                    // Goal pills with highlight and blur
                    goalPillsSection
                        .padding(.horizontal)
                        .overlay(highlightOverlay(for: .goalPills))
                        .blur(radius: shouldBlur(for: .goalPills) ? 4 : 0)
                        .opacity(shouldBlur(for: .goalPills) ? 0.5 : 1.0)
                        .onTapGesture {
                            if highlightMode == .goalPills {
                                tourManager.nextStep()
                            }
                        }

                    // Adherence arc with highlight - INTERACTIVE, tapping navigates to goals list
                    adherenceArcSection
                        .overlay(highlightOverlay(for: .adherenceArc))
                        .overlay(highlightOverlay(for: .arcMechanics))
                        .blur(radius: shouldBlur(for: .adherenceArc) ? 4 : 0)
                        .opacity(shouldBlur(for: .adherenceArc) ? 0.5 : 1.0)
                        .onTapGesture {
                            if highlightMode == .adherenceArc || highlightMode == .arcMechanics {
                                // Jump to goals list screen (like tapping arc in real app)
                                tourManager.goToScreen(.goalsList)
                            }
                        }

                    // Nudge section with highlight
                    nudgeSection
                        .padding(.horizontal)
                        .overlay(highlightOverlay(for: .coachNudges))
                        .blur(radius: shouldBlur(for: .coachNudges) ? 4 : 0)
                        .opacity(shouldBlur(for: .coachNudges) ? 0.5 : 1.0)
                        .onTapGesture {
                            if highlightMode == .coachNudges {
                                tourManager.nextStep()
                            }
                        }

                    // Challenge section with highlight
                    challengeSection
                        .padding(.horizontal)
                        .overlay(highlightOverlay(for: .challenges))
                        .blur(radius: shouldBlur(for: .challenges) ? 4 : 0)
                        .opacity(shouldBlur(for: .challenges) ? 0.5 : 1.0)
                        .onTapGesture {
                            if highlightMode == .challenges {
                                tourManager.nextStep()
                            }
                        }

                    Spacer(minLength: 100)
                }
                .padding(.top, 8)
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

    private var goalPillsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                TourGoalPill(icon: "fork.knife", label: "Protein", score: 75)
                TourGoalPill(icon: "figure.walk", label: "Steps", score: 62)
                TourGoalPill(icon: "bed.double.fill", label: "Sleep", score: 88)
                TourGoalPill(icon: "dumbbell.fill", label: "Strength", score: 33)
            }
        }
    }

    private var adherenceArcSection: some View {
        VStack(spacing: 4) {
            TourAdherenceArc(progress: 68, maxPotential: 92)

            // "View goals" link hint when arc is highlighted
            if highlightMode == .adherenceArc || highlightMode == .arcMechanics {
                HStack(spacing: 4) {
                    Text("Tap to view goals")
                        .font(.caption)
                    Image(systemName: "hand.tap.fill")
                        .font(.caption)
                }
                .foregroundColor(.green)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal)
    }

    private var nudgeSection: some View {
        HStack(spacing: 12) {
            ChironAvatar(size: .medium, style: .filled)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Chiron")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Text("Just now")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text("Great protein intake today! Try adding an extra 10g at dinner to hit your target.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var challengeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)

                Text("Active Challenge")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text("Day 2/3")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("Morning Movement")
                .font(.headline)

            HStack(spacing: 4) {
                Circle().fill(Color.orange).frame(width: 10, height: 10)
                Circle().fill(Color.orange).frame(width: 10, height: 10)
                Circle().fill(Color.gray.opacity(0.3)).frame(width: 10, height: 10)
            }

            Text("Take a 10-minute walk within an hour of waking up")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    TourGoalsScreen(highlightMode: .goalPills)
}
