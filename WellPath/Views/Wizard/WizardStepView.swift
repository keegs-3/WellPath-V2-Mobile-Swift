//
//  WizardStepView.swift
//  WellPath
//
//  Reusable template for wizard steps.
//  Shows progress indicator, title, content, and navigation buttons.
//

import SwiftUI

struct WizardStepView<Content: View>: View {
    let stepNumber: Int
    let totalSteps: Int
    let title: String
    let subtitle: String?
    let color: Color
    @ViewBuilder let content: () -> Content

    var onNext: (() -> Void)?
    var onBack: (() -> Void)?
    var nextButtonText: String = "Next"
    var showSkip: Bool = false
    var onSkip: (() -> Void)?
    var isNextEnabled: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            progressBar

            // Scrollable content
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Main content
                    content()
                        .padding(.horizontal)
                }
                .padding(.vertical, 20)
            }

            // Navigation buttons
            navigationButtons
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 8) {
            // Step indicator
            HStack {
                Text("Step \(stepNumber) of \(totalSteps)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(Double(stepNumber) / Double(totalSteps) * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
            .padding(.horizontal)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)

                    // Progress
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(stepNumber) / CGFloat(totalSteps), height: 4)
                        .animation(.easeInOut(duration: 0.3), value: stepNumber)
                }
            }
            .frame(height: 4)
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        VStack(spacing: 12) {
            Divider()

            HStack(spacing: 12) {
                // Back button (if not first step)
                if let onBack = onBack, stepNumber > 1 {
                    Button(action: onBack) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.headline)
                        .foregroundColor(color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(color.opacity(0.1))
                        .cornerRadius(12)
                    }
                }

                // Skip button (optional)
                if showSkip, let onSkip = onSkip {
                    Button(action: onSkip) {
                        Text("Skip")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(12)
                    }
                }

                // Next button
                if let onNext = onNext {
                    Button(action: onNext) {
                        HStack {
                            Text(nextButtonText)
                            if stepNumber < totalSteps {
                                Image(systemName: "chevron.right")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isNextEnabled ? color : Color.secondary)
                        .cornerRadius(12)
                    }
                    .disabled(!isNextEnabled)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }
}

// MARK: - Card Preview Component

/// Shows a card with an explanation overlay for wizard tours
struct WizardCardPreview<CardContent: View>: View {
    let explanation: String
    let highlightPoints: [String]
    let color: Color
    @ViewBuilder let card: () -> CardContent

    var body: some View {
        VStack(spacing: 16) {
            // The actual card (non-interactive preview)
            card()
                .allowsHitTesting(false)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color, lineWidth: 2)
                )

            // Explanation
            VStack(alignment: .leading, spacing: 12) {
                Text(explanation)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Highlight points
                if !highlightPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(highlightPoints, id: \.self) { point in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(color)
                                Text(point)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Preview

#Preview("Step 1 of 6") {
    WizardStepView(
        stepNumber: 1,
        totalSteps: 6,
        title: "Welcome to Protein Tracking",
        subtitle: "Let's walk through how WellPath helps you track protein",
        color: .blue
    ) {
        VStack(spacing: 20) {
            Image(systemName: "fish.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Protein is essential for muscle growth, repair, and overall health.")
                .font(.body)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    .onNext { print("Next tapped") }
}

#Preview("Step 3 of 6 with Back") {
    WizardStepView(
        stepNumber: 3,
        totalSteps: 6,
        title: "Protein Type",
        subtitle: "Track protein quality by source",
        color: .blue
    ) {
        Text("Card preview would go here")
            .frame(maxWidth: .infinity)
            .padding(40)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
    }
    .onNext { print("Next") }
    .onBack { print("Back") }
}

// Extension for convenient modifier-style setup
extension WizardStepView {
    func onNext(_ action: @escaping () -> Void) -> WizardStepView {
        var view = self
        view.onNext = action
        return view
    }

    func onBack(_ action: @escaping () -> Void) -> WizardStepView {
        var view = self
        view.onBack = action
        return view
    }

    func nextButton(_ text: String) -> WizardStepView {
        var view = self
        view.nextButtonText = text
        return view
    }

    func skipButton(action: @escaping () -> Void) -> WizardStepView {
        var view = self
        view.showSkip = true
        view.onSkip = action
        return view
    }

    func nextEnabled(_ enabled: Bool) -> WizardStepView {
        var view = self
        view.isNextEnabled = enabled
        return view
    }
}
