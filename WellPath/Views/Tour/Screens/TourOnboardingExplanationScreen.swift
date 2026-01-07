//
//  TourOnboardingExplanationScreen.swift
//  WellPath
//
//  Explains how WellPath onboarding works (clinician setup, baselines, etc.)
//

import SwiftUI

struct TourOnboardingExplanationScreen: View {
    let highlightMode: TourScreen
    @ObservedObject private var tourManager = InteractiveTourManager.shared

    // All onboarding highlight screens
    private let onboardingScreens: [TourScreen] = [
        .onboardingClinician, .onboardingBaselines, .onboardingRecommendations,
        .onboardingTracking, .onboardingLabs
    ]

    // Check if we're highlighting a specific step
    private var hasSpecificHighlight: Bool {
        onboardingScreens.contains(highlightMode)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Title
                VStack(spacing: 8) {
                    Text("How WellPath Works")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Your personalized health journey")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)

                // Steps - each with dim and tap gesture
                VStack(spacing: 16) {
                    OnboardingStepCard(
                        number: 1,
                        icon: "person.badge.shield.checkmark.fill",
                        title: "Clinician Setup",
                        description: "Your clinician configures your personalized WellPath journey based on your health profile.",
                        isHighlighted: highlightMode == .onboardingClinician
                    )
                    .opacity(dimOpacity(for: .onboardingClinician))
                    .onTapGesture {
                        if highlightMode == .onboardingClinician {
                            tourManager.nextStep()
                        }
                    }

                    OnboardingStepCard(
                        number: 2,
                        icon: "list.clipboard.fill",
                        title: "Baseline Questions",
                        description: "Answer questions about your current habits to establish your starting point.",
                        isHighlighted: highlightMode == .onboardingBaselines
                    )
                    .opacity(dimOpacity(for: .onboardingBaselines))
                    .onTapGesture {
                        if highlightMode == .onboardingBaselines {
                            tourManager.nextStep()
                        }
                    }

                    OnboardingStepCard(
                        number: 3,
                        icon: "target",
                        title: "Personalized Goals",
                        description: "Your answers help calculate targets and generate goals tailored to you.",
                        isHighlighted: highlightMode == .onboardingRecommendations
                    )
                    .opacity(dimOpacity(for: .onboardingRecommendations))
                    .onTapGesture {
                        if highlightMode == .onboardingRecommendations {
                            tourManager.nextStep()
                        }
                    }

                    OnboardingStepCard(
                        number: 4,
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Real Tracking",
                        description: "As you track real data, it supersedes baselines for accurate insights.",
                        isHighlighted: highlightMode == .onboardingTracking
                    )
                    .opacity(dimOpacity(for: .onboardingTracking))
                    .onTapGesture {
                        if highlightMode == .onboardingTracking {
                            tourManager.nextStep()
                        }
                    }

                    OnboardingStepCard(
                        number: 5,
                        icon: "cross.vial.fill",
                        title: "Labs & Biometrics",
                        description: "Your clinician adds lab results and measurements for a complete picture.",
                        isHighlighted: highlightMode == .onboardingLabs
                    )
                    .opacity(dimOpacity(for: .onboardingLabs))
                    .onTapGesture {
                        if highlightMode == .onboardingLabs {
                            tourManager.nextStep()
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    // Calculate opacity - highlighted step is full, others are slightly dimmed
    private func dimOpacity(for screen: TourScreen) -> Double {
        if !hasSpecificHighlight {
            return 1.0 // No specific highlight
        }
        if highlightMode == screen {
            return 1.0 // This is highlighted
        }
        return 0.6 // Subtly dimmed (not too dark)
    }
}

struct OnboardingStepCard: View {
    let number: Int
    let icon: String
    let title: String
    let description: String
    let isHighlighted: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Number badge
            ZStack {
                Circle()
                    .fill(isHighlighted ? Color.green : Color.gray.opacity(0.2))
                    .frame(width: 32, height: 32)

                Text("\(number)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(isHighlighted ? .white : .secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundColor(isHighlighted ? .green : .secondary)

                    Text(title)
                        .font(.headline)
                }

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHighlighted ? Color.green : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    TourOnboardingExplanationScreen(highlightMode: .onboardingClinician)
}
