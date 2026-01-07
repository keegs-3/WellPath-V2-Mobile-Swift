//
//  TourContainerView.swift
//  WellPath
//
//  Main container for the interactive tour experience.
//  Wraps tour screens with chrome (header, progress, navigation, coach bubble).
//

import SwiftUI

struct TourContainerView: View {
    @ObservedObject private var tourManager = InteractiveTourManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showSetupWizard = false

    // More precise coach bubble positioning based on what's highlighted
    private var coachBubblePosition: CoachBubblePosition {
        switch tourManager.currentStep.screen {
        // Welcome/intro screens - bubble near top (content is centered)
        case .welcome, .chironFeatures:
            return .top

        // Tab bar highlights at BOTTOM - bubble ABOVE the tabs (bottom-aligned)
        case .navigationOverview, .goalsTabIntro, .scoreTabIntro, .dataTabIntro:
            return .aboveHighlight

        // Plus button and hamburger at bottom - bubble above them
        case .plusButton, .hamburgerMenu:
            return .aboveHighlight

        // Goals content - position near highlighted element
        case .goalsOverview:
            return .top
        case .goalPills:
            return .belowHighlight  // Below the pills
        case .adherenceArc, .arcMechanics:
            return .belowHighlight  // Below the arc
        case .goalsList, .goalManagement:
            return .top
        case .coachNudges, .challenges:
            return .aboveHighlight  // Above nudges/challenges at bottom

        // Score tab
        case .scoreOverview:
            return .top
        case .scoreBreakdown:
            return .belowHighlight
        case .scorePillars, .pillarDetail, .componentDetail:
            return .top

        // Data tab
        case .dataOverview, .dataSections, .dataFavorites, .dataCardNavigation, .dataDeepNavigation:
            return .top

        // Onboarding explanation
        case .onboardingClinician, .onboardingBaselines, .onboardingRecommendations, .onboardingTracking, .onboardingLabs:
            return .top

        // Wrap up
        case .wrapUpSummary, .wrapUpNextSteps:
            return .top
        }
    }

    // Vertical offset from top of content area based on position
    private var bubbleTopOffset: CGFloat {
        switch coachBubblePosition {
        case .top:
            return 60  // Just below header
        case .upperMiddle:
            return 100  // Upper area but not cramped
        case .belowHighlight:
            return 180  // Below typical highlight area (arc, pills)
        case .middle:
            return 240  // Center-ish
        case .aboveHighlight:
            return 0  // Special: uses bottom alignment
        case .lowerMiddle:
            return 300  // Lower middle
        case .bottom:
            return 0  // Special: uses bottom alignment
        }
    }

    private var usesBottomAlignment: Bool {
        switch coachBubblePosition {
        case .aboveHighlight, .bottom:
            return true
        default:
            return false
        }
    }

    private var bubbleBottomOffset: CGFloat {
        switch coachBubblePosition {
        case .aboveHighlight:
            return 280  // Above tab bar (needs clearance for tabs + nav footer)
        case .bottom:
            return 80  // Just above nav
        default:
            return 0
        }
    }

    var body: some View {
        Group {
            if tourManager.isLoading {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading tour...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemBackground))
            } else {
                ZStack {
                    // Main content layer
                    VStack(spacing: 0) {
                        // Tour header (in safe area)
                        tourHeader

                        // Main content area - bounded and clipped
                        screenContent
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()

                        // Navigation controls always at bottom
                        tourNavigation
                    }

                    // Floating coach bubble overlay - positioned relative to highlighted content
                    VStack {
                        if usesBottomAlignment {
                            // Bottom-aligned positions (for nudges, challenges, etc.)
                            Spacer()

                            TourCoachBubble(
                                message: tourManager.currentStep.coachMessage,
                                subtext: tourManager.currentStep.coachSubtext
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, bubbleBottomOffset)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
                            // Top-aligned positions (most cases)
                            TourCoachBubble(
                                message: tourManager.currentStep.coachMessage,
                                subtext: tourManager.currentStep.coachSubtext
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, bubbleTopOffset)
                            .transition(.move(edge: .top).combined(with: .opacity))

                            Spacer()
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: coachBubblePosition)
                }
                .background(Color(uiColor: .systemBackground))
            }
        }
        .fullScreenCover(isPresented: $showSetupWizard) {
            WizardView()
        }
        .task {
            // Load tour content from database when view appears
            await tourManager.startTour()
        }
    }

    enum CoachBubblePosition {
        case top              // Just below header (60pt)
        case upperMiddle      // Upper area (100pt) - good for content with highlights below
        case belowHighlight   // Below arc/pills area (180pt)
        case middle           // Center-ish (240pt)
        case lowerMiddle      // Lower middle (300pt)
        case aboveHighlight   // Above bottom content (from bottom: 160pt)
        case bottom           // Just above nav (from bottom: 80pt)
    }

    // MARK: - Tour Header

    private var tourHeader: some View {
        HStack {
            Text("TOUR")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .tracking(1)

            Spacer()

            // Progress indicator
            Text("\(tourManager.currentStepIndex + 1) of \(TourFlow.totalSteps)")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button("Skip") {
                tourManager.endTour()
                dismiss()
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: - Screen Content

    @ViewBuilder
    private var screenContent: some View {
        switch tourManager.currentStep.screen {
        // Welcome section
        case .welcome, .chironFeatures:
            TourWelcomeScreen()

        // Navigation section
        case .navigationOverview, .goalsTabIntro, .scoreTabIntro, .dataTabIntro, .plusButton, .hamburgerMenu:
            TourNavigationScreen(highlightMode: tourManager.currentStep.screen)

        // Goals section
        case .goalsOverview, .goalPills, .adherenceArc, .arcMechanics, .goalsList, .goalManagement, .coachNudges, .challenges:
            TourGoalsScreen(highlightMode: tourManager.currentStep.screen)

        // Score section
        case .scoreOverview, .scoreBreakdown, .scorePillars, .pillarDetail, .componentDetail:
            TourScoreScreen(highlightMode: tourManager.currentStep.screen)

        // Data section
        case .dataOverview, .dataSections, .dataFavorites, .dataCardNavigation, .dataDeepNavigation:
            TourMyDataScreen(highlightMode: tourManager.currentStep.screen)

        // Onboarding explanation section
        case .onboardingClinician, .onboardingBaselines, .onboardingRecommendations, .onboardingTracking, .onboardingLabs:
            TourOnboardingExplanationScreen(highlightMode: tourManager.currentStep.screen)

        // Wrap up section
        case .wrapUpSummary, .wrapUpNextSteps:
            TourWrapUpScreen(onStartSetup: {
                showSetupWizard = true
                tourManager.endTour()
            })
        }
    }

    // MARK: - Navigation

    private var tourNavigation: some View {
        HStack(spacing: 16) {
            // Back button
            Button {
                tourManager.previousStep()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.subheadline)
                .foregroundColor(tourManager.isFirstStep ? .secondary.opacity(0.5) : .primary)
            }
            .disabled(tourManager.isFirstStep)

            Spacer()

            // Section-based progress (7 sections instead of 33 dots)
            HStack(spacing: 4) {
                ForEach(tourManager.sections, id: \.self) { section in
                    Circle()
                        .fill(section == tourManager.currentSection ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: section == tourManager.currentSection ? 10 : 8, height: section == tourManager.currentSection ? 10 : 8)
                }
            }

            Spacer()

            // Next / Done button
            Button {
                if tourManager.isLastStep {
                    tourManager.endTour()
                    dismiss()
                } else {
                    tourManager.nextStep()
                }
            } label: {
                HStack(spacing: 4) {
                    Text(tourManager.isLastStep ? "Done" : "Next")
                    if !tourManager.isLastStep {
                        Image(systemName: "chevron.right")
                    }
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(uiColor: .secondarySystemBackground))
    }
}

// MARK: - Coach Bubble

struct TourCoachBubble: View {
    let message: String
    let subtext: String?

    private let chironGreen = Color(red: 0.2, green: 0.7, blue: 0.4)

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Chiron avatar
            ChironAvatar(size: .medium, style: .gradient)

            // Message bubble
            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                if let subtext = subtext {
                    Text(subtext)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: 320) // Narrower max width
        .background(
            // Solid dark background with subtle green tint
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.16, blue: 0.14),
                    Color(red: 0.10, green: 0.14, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(chironGreen.opacity(0.5), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 6)
    }
}

// MARK: - Preview

#Preview {
    TourContainerView()
}
