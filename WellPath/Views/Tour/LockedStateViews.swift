//
//  LockedStateViews.swift
//  WellPath
//
//  Locked/blurred state views for Goals and Score tabs.
//  Shown when user hasn't completed setup yet.
//  Clear visual indication that content is locked, with CTA to unlock.
//

import SwiftUI

// MARK: - Goals Locked View

struct GoalsLockedView: View {
    let onTakeTour: () -> Void
    let onContinueSetup: () -> Void

    @ObservedObject private var journeyState = JourneyStateService.shared

    // Calculate baseline progress for the progress bar
    private var baselineProgress: Double {
        switch journeyState.state {
        case .baselineCollection(let completed, let total):
            return total > 0 ? Double(completed) / Double(total) : 0
        default:
            return journeyState.hasCompletedBaselines ? 1.0 : 0
        }
    }

    private var baselineProgressText: String {
        switch journeyState.state {
        case .baselineCollection(let completed, let total):
            return "\(completed) of \(total) complete"
        default:
            return journeyState.hasCompletedBaselines ? "Complete" : "Not started"
        }
    }

    private var baselineCompleted: Int {
        switch journeyState.state {
        case .baselineCollection(let completed, _):
            return completed
        default:
            return journeyState.hasCompletedBaselines ? 17 : 0
        }
    }

    private var baselineTotal: Int {
        switch journeyState.state {
        case .baselineCollection(_, let total):
            return total
        default:
            return 17
        }
    }

    var body: some View {
        ZStack {
            // Full-screen Goals background
            GoalsHeroBackground()
                .ignoresSafeArea()

            // Content
            VStack(spacing: 24) {
                Spacer()

                // Chiron avatar
                ChironAvatar(size: .hero, style: .gradient, animate: true)

                // Message
                VStack(spacing: 8) {
                    Text("Complete Your Profile")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Your personalized goals will be generated once your health profile is complete.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Progress card with tappable baseline row
                setupProgressCard

                // Take a Tour link (smaller, secondary)
                Button(action: onTakeTour) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.circle")
                        Text("Take a Tour")
                    }
                    .font(.subheadline)
                    .foregroundColor(.green)
                }
                .padding(.top, 8)

                Spacer()
                Spacer()
            }
        }
        .task {
            // Ensure journey state is loaded
            await journeyState.loadState()
        }
    }

    private var setupProgressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Baseline Questions - TAPPABLE with progress bar
            Button(action: onContinueSetup) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "list.clipboard")
                            .font(.title3)
                            .foregroundColor(.green)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Baseline Questions")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)

                            Text("\(baselineCompleted) of \(baselineTotal) complete")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text("\(Int(baselineProgress * 100))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)

                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }

                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.green)
                                .frame(width: geometry.size.width * baselineProgress, height: 8)
                        }
                    }
                    .frame(height: 8)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Clinician items with progress bars
            VStack(spacing: 12) {
                Text("From your clinician:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                clinicianProgressRow(
                    icon: "testtube.2",
                    label: "Lab Results",
                    isComplete: journeyState.hasLabResults
                )

                clinicianProgressRow(
                    icon: "heart.text.clipboard",
                    label: "Biometrics",
                    isComplete: journeyState.hasBiometrics
                )
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.95))
        .cornerRadius(16)
        .padding(.horizontal, 24)
    }

    private func clinicianProgressRow(icon: String, label: String, isComplete: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(isComplete ? .green : .secondary)

                Text(label)
                    .font(.subheadline)
                    .foregroundColor(isComplete ? .primary : .secondary)

                Spacer()

                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.green)
                } else {
                    Text("Waiting")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(isComplete ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: geometry.size.width * (isComplete ? 1.0 : 0), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Score Locked View

struct ScoreLockedView: View {
    let onTakeTour: () -> Void
    let onContinueSetup: () -> Void

    var body: some View {
        ZStack {
            // Blurred background preview
            blurredScorePreview
                .blur(radius: 8)
                .opacity(0.6)

            // Overlay content
            VStack(spacing: 24) {
                Spacer()

                // Lock icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 100, height: 100)

                    Image(systemName: "heart.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                }

                // Message
                VStack(spacing: 8) {
                    Text("Your WellPath Score")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("A personalized 0-100 health score based on your biomarkers, biometrics, and lifestyle habits.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Components card
                scoreComponentsCard

                // Action buttons
                VStack(spacing: 12) {
                    Button(action: onContinueSetup) {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Continue Setup")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                    }

                    Button(action: onTakeTour) {
                        HStack {
                            Image(systemName: "play.circle")
                            Text("Take a Tour")
                        }
                        .font(.subheadline)
                        .foregroundColor(.green)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
            .background(
                ZStack {
                    WellPathColors.backgroundBase
                    // Soft ambient glow
                    RadialGradient(
                        gradient: Gradient(colors: [
                            WellPathColors.brandGreen.opacity(0.08),
                            Color.clear
                        ]),
                        center: UnitPoint(x: 0.5, y: 0.3),
                        startRadius: 0,
                        endRadius: UIScreen.main.bounds.height * 0.5
                    )
                }
                .ignoresSafeArea()
            )
        }
    }

    private var blurredScorePreview: some View {
        VStack(spacing: 20) {
            // Fake score ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 16)
                    .frame(width: 180, height: 180)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 16)
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 40)
            }
            .padding(.top, 40)

            // Fake pillars
            VStack(spacing: 8) {
                ForEach(0..<7) { _ in
                    HStack {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 12, height: 12)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 120, height: 16)

                        Spacer()

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 30, height: 16)
                    }
                    .padding(.horizontal, 32)
                }
            }
            .padding(.top, 20)

            Spacer()
        }
    }

    private var scoreComponentsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calculated from:")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                componentRow(icon: "testtube.2", label: "Biomarkers", detail: "Lab results")
                componentRow(icon: "heart.text.clipboard", label: "Biometrics", detail: "Body measurements")
                componentRow(icon: "list.clipboard", label: "Lifestyle", detail: "Health habits")
            }
        }
        .padding()
        .background(WellPathColors.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal, 32)
    }

    private func componentRow(icon: String, label: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)

            Spacer()

            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Previews

#Preview("Goals Locked") {
    GoalsLockedView(
        onTakeTour: {},
        onContinueSetup: {}
    )
}

#Preview("Score Locked") {
    ScoreLockedView(
        onTakeTour: {},
        onContinueSetup: {}
    )
}
