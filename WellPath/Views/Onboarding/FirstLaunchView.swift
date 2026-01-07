//
//  FirstLaunchView.swift
//  WellPath
//
//  Modal presented on first app launch.
//  Offers three paths: Start Setup, Take Tour, or Explore.
//
//  Architecture:
//  - Shown via fullScreenCover from ContentView
//  - Checks UserDefaults "wellpath_first_launch_completed"
//  - Each option dismisses modal and triggers appropriate action
//

import SwiftUI

struct FirstLaunchView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var showWizard: Bool
    @Binding var startTour: Bool

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.15, blue: 0.2),
                    Color(red: 0.05, green: 0.1, blue: 0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo and welcome text
                welcomeHeader

                Spacer()

                // Three option cards
                VStack(spacing: 16) {
                    FirstLaunchOptionCard(
                        icon: "checklist",
                        iconColor: .green,
                        title: "Set Your Baselines",
                        subtitle: "Tell us about your lifestyle and habits",
                        isRecommended: true
                    ) {
                        markCompleted()
                        showWizard = true
                        dismiss()
                    }

                    FirstLaunchOptionCard(
                        icon: "sparkles",
                        iconColor: .blue,
                        title: "Take a Tour",
                        subtitle: "See what WellPath offers with sample data",
                        isRecommended: false
                    ) {
                        markCompleted()
                        startTour = true
                        // TourManager.startTour() will reset tips
                        dismiss()
                    }

                    FirstLaunchOptionCard(
                        icon: "magnifyingglass",
                        iconColor: .secondary,
                        title: "Explore on My Own",
                        subtitle: "Jump right in and look around",
                        isRecommended: false
                    ) {
                        markCompleted()
                        dismiss()
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Footer text
                Text("You can always access setup from the menu")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Welcome Header

    private var welcomeHeader: some View {
        VStack(spacing: 16) {
            // App icon / logo placeholder
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.8), Color.green.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.white)
            }
            .shadow(color: .green.opacity(0.3), radius: 20, x: 0, y: 10)

            VStack(spacing: 8) {
                Text("Welcome to WellPath")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Your personalized path to optimal health")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Helpers

    private func markCompleted() {
        UserDefaults.standard.set(true, forKey: "wellpath_first_launch_completed")
    }

    /// Check if first launch has been completed
    static var hasCompletedFirstLaunch: Bool {
        UserDefaults.standard.bool(forKey: "wellpath_first_launch_completed")
    }

    /// Reset first launch state (for testing)
    static func resetFirstLaunch() {
        UserDefaults.standard.set(false, forKey: "wellpath_first_launch_completed")
    }
}

// MARK: - Option Card

struct FirstLaunchOptionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let isRecommended: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(iconColor)
                }

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.white)

                        if isRecommended {
                            Text("Recommended")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.green.opacity(0.2)))
                        }
                    }

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isRecommended ? Color.green.opacity(0.5) : Color.white.opacity(0.1),
                                lineWidth: isRecommended ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    FirstLaunchView(
        showWizard: .constant(false),
        startTour: .constant(false)
    )
}
