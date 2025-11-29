//
//  SurveyLockBanner.swift
//  WellPath
//
//  Banner that displays when survey is locked during active_plan phase.
//  Shows lock status and countdown to unlock date.
//

import SwiftUI

struct SurveyLockBanner: View {
    let planEndsAt: Date?
    let daysUntilUnlock: Int?
    var onLogException: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // Lock icon
            Image(systemName: "lock.fill")
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 40, height: 40)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(10)

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text("Survey Locked")
                    .font(.headline)
                    .foregroundColor(.primary)

                if let days = daysUntilUnlock, days > 0 {
                    Text("Unlocks in \(days) day\(days == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if let endDate = planEndsAt {
                    Text("Unlocks \(endDate, style: .relative)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text("Your health plan is active. Responses can't be edited.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Life happened button
            if let onLogException = onLogException {
                Button {
                    onLogException()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption)
                        Text("Life\nHappened?")
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Compact Version (for inline use)

struct SurveyLockBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.caption2)
            Text("Locked")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(.orange)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(8)
    }
}

// MARK: - View Modifier for conditional lock banner

struct SurveyLockBannerModifier: ViewModifier {
    let surveyState: PatientSurveyState?
    var onLogException: (() -> Void)?

    func body(content: Content) -> some View {
        VStack(spacing: 16) {
            if let state = surveyState, !state.isEditable {
                SurveyLockBanner(
                    planEndsAt: state.planEndsAt,
                    daysUntilUnlock: state.daysUntilUnlock,
                    onLogException: onLogException
                )
            }
            content
        }
    }
}

extension View {
    func surveyLockBanner(state: PatientSurveyState?, onLogException: (() -> Void)? = nil) -> some View {
        modifier(SurveyLockBannerModifier(surveyState: state, onLogException: onLogException))
    }
}

#Preview("Locked - 45 days") {
    VStack {
        SurveyLockBanner(
            planEndsAt: Calendar.current.date(byAdding: .day, value: 45, to: Date()),
            daysUntilUnlock: 45
        ) {
            print("Log exception tapped")
        }
        Spacer()
    }
    .padding()
}

#Preview("Locked - 1 day") {
    VStack {
        SurveyLockBanner(
            planEndsAt: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
            daysUntilUnlock: 1
        )
        Spacer()
    }
    .padding()
}

#Preview("Badge") {
    SurveyLockBadge()
        .padding()
}
