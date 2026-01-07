//
//  JourneyStatusCard.swift
//  WellPath
//
//  Status card shown in hamburger menu displaying onboarding progress or cycle status.
//

import SwiftUI

struct JourneyStatusCard: View {
    let state: JourneyState
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon and title
            HStack(spacing: 10) {
                Image(systemName: state.statusIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: 28, height: 28)
                    .background(iconColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(cardTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(state.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }

            // Progress bar (for onboarding states)
            if showProgressBar {
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 6)

                            // Progress
                            RoundedRectangle(cornerRadius: 4)
                                .fill(progressColor)
                                .frame(width: geometry.size.width * progressPercentage, height: 6)
                        }
                    }
                    .frame(height: 6)

                    // Progress label
                    HStack {
                        Text(progressLabel)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(state.progressPercentage))%")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(progressColor)
                    }
                }
            }

            // Continue button (for actionable states)
            if showContinueButton {
                Button(action: onContinue) {
                    HStack {
                        Text(buttonTitle)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(buttonColor)
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Computed Properties

    private var cardTitle: String {
        switch state {
        case .loading:
            return "Loading..."
        case .baselineCollection:
            return "Setting Up Your WellPath"
        case .awaitingLabs:
            return "Awaiting Lab Results"
        case .awaitingBiometrics:
            return "Awaiting Biometrics"
        case .awaitingClinicianReview:
            return "Almost Ready!"
        case .activeGoals:
            return "Active Cycle"
        case .cycleComplete:
            return "Cycle Complete"
        }
    }

    private var iconColor: Color {
        switch state {
        case .loading:
            return .gray
        case .baselineCollection:
            return .green
        case .awaitingLabs, .awaitingBiometrics, .awaitingClinicianReview:
            return .blue
        case .activeGoals:
            return .green
        case .cycleComplete:
            return .orange
        }
    }

    private var showProgressBar: Bool {
        switch state {
        case .baselineCollection, .awaitingLabs, .awaitingBiometrics, .awaitingClinicianReview:
            return true
        default:
            return false
        }
    }

    private var progressPercentage: CGFloat {
        CGFloat(state.progressPercentage) / 100.0
    }

    private var progressColor: Color {
        switch state {
        case .baselineCollection:
            return .green
        case .awaitingLabs, .awaitingBiometrics, .awaitingClinicianReview:
            return .blue
        default:
            return .green
        }
    }

    private var progressLabel: String {
        switch state {
        case .baselineCollection(let completed, let total):
            return "\(completed) of \(total) baselines"
        case .awaitingLabs:
            return "Baselines complete"
        case .awaitingBiometrics:
            return "Labs entered"
        case .awaitingClinicianReview:
            return "All data received"
        default:
            return ""
        }
    }

    private var showContinueButton: Bool {
        switch state {
        case .baselineCollection, .cycleComplete:
            return true
        default:
            return false
        }
    }

    private var buttonTitle: String {
        switch state {
        case .baselineCollection:
            return "Continue Setup"
        case .cycleComplete:
            return "View Results"
        default:
            return "Continue"
        }
    }

    private var buttonColor: Color {
        switch state {
        case .baselineCollection:
            return .green
        case .cycleComplete:
            return .orange
        default:
            return .blue
        }
    }
}

// MARK: - Preview

#Preview("Baseline Collection") {
    VStack(spacing: 16) {
        JourneyStatusCard(
            state: .baselineCollection(completed: 7, total: 17),
            onContinue: {}
        )

        JourneyStatusCard(
            state: .awaitingLabs,
            onContinue: {}
        )

        JourneyStatusCard(
            state: .awaitingClinicianReview,
            onContinue: {}
        )

        JourneyStatusCard(
            state: .cycleComplete,
            onContinue: {}
        )
    }
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}
