//
//  OnboardingTourView.swift
//  WellPath
//
//  Main orchestrator for the onboarding tour experience.
//  Shows section hubs where users can navigate to actual screens and answer baseline questions.
//

import SwiftUI

struct OnboardingTourView: View {
    @StateObject private var tourManager = OnboardingTourManager()
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSection: TourSection? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                if tourManager.isLoading {
                    loadingView
                } else if let error = tourManager.error {
                    errorView(error)
                } else {
                    sectionSelectionView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        tourManager.endTour()
                        dismiss()
                    }
                }
            }
        }
        .task {
            await tourManager.startTour()
        }
        .fullScreenCover(item: $selectedSection) { section in
            sectionHubView(for: section)
        }
    }

    // MARK: - Section Selection View

    private var sectionSelectionView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Welcome header
                welcomeHeader

                // Section cards
                VStack(spacing: 12) {
                    ForEach(tourManager.sections, id: \.self) { section in
                        TourSectionCard(section: section) {
                            selectedSection = section
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("WellPath Tour")
    }

    private var welcomeHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(.blue)

            Text("Set Your Baselines")
                .font(.title2)
                .fontWeight(.bold)

            Text("Answer a few questions in each category to establish your starting point. This helps us calculate your WellPath Score.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Section Hub Views

    @ViewBuilder
    private func sectionHubView(for section: TourSection) -> some View {
        switch section {
        case .nutrition:
            NutritionTourHubView()
        default:
            // For other sections, use the generic hub (to be implemented)
            GenericSectionHubView(section: section)
        }
    }


    // MARK: - Loading & Error

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading your tour...")
                .foregroundColor(.secondary)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Something went wrong")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await tourManager.startTour() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

}

// MARK: - Tour Section Card

struct TourSectionCard: View {
    let section: TourSection
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Section icon
                Image(systemName: section.icon)
                    .font(.title2)
                    .foregroundColor(section.color)
                    .frame(width: 50, height: 50)
                    .background(section.color.opacity(0.15))
                    .cornerRadius(12)

                // Section info
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(sectionSubtitle(section))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func sectionSubtitle(_ section: TourSection) -> String {
        switch section {
        case .nutrition: return "Diet, hydration, meal patterns"
        case .movement: return "Exercise, activity, fitness"
        case .sleep: return "Sleep quality, duration, patterns"
        case .substances: return "Alcohol, tobacco, supplements"
        case .stress: return "Stress levels, mental health"
        case .cognitive: return "Brain health, cognitive activities"
        case .connection: return "Social bonds, nature time"
        case .healthHistory: return "Medical history, conditions"
        }
    }
}

// MARK: - Generic Section Hub (Placeholder)

struct GenericSectionHubView: View {
    let section: TourSection
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: section.icon)
                    .font(.system(size: 60))
                    .foregroundColor(section.color)

                Text(section.displayName)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Coming soon! This section will let you set baselines for \(section.displayName.lowercased()) metrics.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                Button("Go Back") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(section.displayName)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Tour Launch Button

/// A button component that can be placed anywhere to launch the onboarding tour
struct LaunchTourButton: View {
    @State private var showTour = false
    var style: LaunchTourButtonStyle = .prominent

    enum LaunchTourButtonStyle {
        case prominent
        case subtle
        case iconOnly
    }

    var body: some View {
        Button {
            showTour = true
        } label: {
            switch style {
            case .prominent:
                HStack {
                    Image(systemName: "sparkles")
                    Text("Start WellPath Tour")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)

            case .subtle:
                HStack {
                    Image(systemName: "sparkles")
                    Text("Take the Tour")
                }
                .font(.subheadline)
                .foregroundColor(.blue)

            case .iconOnly:
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .fullScreenCover(isPresented: $showTour) {
            OnboardingTourView()
        }
    }
}

// MARK: - Preview

#Preview("Tour View") {
    OnboardingTourView()
}

#Preview("Launch Button - Prominent") {
    LaunchTourButton(style: .prominent)
        .padding()
}

#Preview("Launch Button - Subtle") {
    LaunchTourButton(style: .subtle)
}
