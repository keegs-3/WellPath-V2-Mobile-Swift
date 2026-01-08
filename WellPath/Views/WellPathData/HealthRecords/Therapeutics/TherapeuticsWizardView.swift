//
//  TherapeuticsWizardView.swift
//  WellPath
//
//  Tour wizard introducing the Therapeutics hub.
//  Uses WizardStepView for consistent UI patterns.
//

import SwiftUI

struct TherapeuticsWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var baselineChecker = TherapeuticsBaselineChecker()
    @State private var currentStep = 1

    private let totalSteps = 4
    private let therapeuticsColor = Color.blue

    var body: some View {
        NavigationStack {
            Group {
                switch currentStep {
                case 1:
                    introStep
                case 2:
                    myTherapeuticsStep
                case 3:
                    exploreStep
                case 4:
                    readyStep
                default:
                    EmptyView()
                }
            }
            .modifier(MetricScreenBackground(color: therapeuticsColor))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Exit") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }

    // MARK: - Step 1: Intro

    private var introStep: some View {
        WizardStepView(
            stepNumber: 1,
            totalSteps: totalSteps,
            title: "Your Therapeutics Hub",
            subtitle: "Track medications, supplements, peptides, and hormones in one place",
            color: therapeuticsColor
        ) {
            VStack(spacing: 24) {
                Image(systemName: "pills.fill")
                    .font(.system(size: 72))
                    .foregroundColor(therapeuticsColor)

                VStack(alignment: .leading, spacing: 16) {
                    featureRow(icon: "checkmark.circle.fill", title: "Track Daily Doses", description: "Log when you take each therapeutic")
                    featureRow(icon: "chart.line.uptrend.xyaxis", title: "Monitor Adherence", description: "See your consistency over time")
                    featureRow(icon: "exclamationmark.triangle.fill", title: "Drug Interactions", description: "Get alerts about potential interactions")
                    featureRow(icon: "book.fill", title: "Learn & Explore", description: "Browse our curated therapeutic database")
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
        .onNext { withAnimation { currentStep = 2 } }
        .nextButton("Continue")
    }

    // MARK: - Step 2: My Therapeutics

    private var myTherapeuticsStep: some View {
        WizardStepView(
            stepNumber: 2,
            totalSteps: totalSteps,
            title: "My Therapeutics",
            subtitle: "Your personal therapeutic tracker",
            color: therapeuticsColor
        ) {
            VStack(spacing: 20) {
                // Preview of the My Therapeutics card
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(therapeuticsColor.opacity(0.15))
                            .frame(width: 56, height: 56)

                        Image(systemName: "pills.fill")
                            .font(.title2)
                            .foregroundColor(therapeuticsColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("My Therapeutics")
                            .font(.headline)

                        Text("Track & log your daily doses")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(therapeuticsColor, lineWidth: 2)
                )

                // Explanation
                VStack(alignment: .leading, spacing: 12) {
                    Text("This is your central hub for all therapeutics you take.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        highlightRow(text: "View all your active therapeutics")
                        highlightRow(text: "Log doses with one tap")
                        highlightRow(text: "Track morning, afternoon, and evening doses")
                    }
                }
                .padding()
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
        .onNext { withAnimation { currentStep = 3 } }
        .onBack { withAnimation { currentStep = 1 } }
        .nextButton("Continue")
    }

    // MARK: - Step 3: Explore

    private var exploreStep: some View {
        WizardStepView(
            stepNumber: 3,
            totalSteps: totalSteps,
            title: "Explore & Learn",
            subtitle: "Browse our curated database",
            color: therapeuticsColor
        ) {
            VStack(spacing: 20) {
                // Preview of explore cards
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    exploreTypePreview(icon: "cross.case.fill", name: "Medications", count: "152", color: .red)
                    exploreTypePreview(icon: "leaf.fill", name: "Supplements", count: "166", color: .green)
                    exploreTypePreview(icon: "syringe.fill", name: "Peptides", count: "52", color: .purple)
                    exploreTypePreview(icon: "waveform.path.ecg", name: "Hormones", count: "26", color: .orange)
                }

                // Explanation
                VStack(alignment: .leading, spacing: 12) {
                    Text("Discover therapeutics relevant to your health journey.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        highlightRow(text: "Search by name or category")
                        highlightRow(text: "Read about longevity impacts")
                        highlightRow(text: "Add therapeutics to your tracker")
                    }
                }
                .padding()
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
        .onNext { withAnimation { currentStep = 4 } }
        .onBack { withAnimation { currentStep = 2 } }
        .nextButton("Continue")
    }

    // MARK: - Step 4: Ready

    private var readyStep: some View {
        WizardStepView(
            stepNumber: 4,
            totalSteps: totalSteps,
            title: "Ready to Start",
            subtitle: "You're all set to track your therapeutics",
            color: therapeuticsColor
        ) {
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 16) {
                    Text("How to Get Started")
                        .font(.headline)

                    nextStepRow(number: 1, text: "Tap \"My Therapeutics\" to see your tracker")
                    nextStepRow(number: 2, text: "Use \"Explore\" to browse available therapeutics")
                    nextStepRow(number: 3, text: "Add each medication, supplement, or peptide you take")
                    nextStepRow(number: 4, text: "Log your daily doses to track adherence")
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)

                Text("You can access this guide anytime from the book icon in the toolbar.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .onNext {
            Task {
                await baselineChecker.markBaselineComplete()
            }
            dismiss()
        }
        .onBack { withAnimation { currentStep = 3 } }
        .nextButton("Get Started")
    }

    // MARK: - Helper Views

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(therapeuticsColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func highlightRow(text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(therapeuticsColor)
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }

    private func exploreTypePreview(icon: String, name: String, count: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(color)
            }

            Text(name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Text("\(count) available")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(10)
    }

    private func nextStepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(therapeuticsColor.opacity(0.15))
                    .frame(width: 24, height: 24)

                Text("\(number)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(therapeuticsColor)
            }

            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    TherapeuticsWizardView()
}
