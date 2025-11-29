//
//  ReassessmentInfoSheet.swift
//  WellPath
//
//  Help sheet explaining how the smart reassessment process works.
//  Shows users what data-driven updates are and how to review them.
//

import SwiftUI

struct ReassessmentInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerSection

                    // How it works
                    howItWorksSection

                    // Data-driven updates
                    dataDrivenSection

                    // Manual review areas
                    manualReviewSection

                    // Tips
                    tipsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("How Reassessment Works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(.blue)

            Text("Your health profile stays accurate by combining your tracked data with periodic check-ins.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    private var howItWorksSection: some View {
        InfoSection(
            title: "How It Works",
            icon: "gearshape.2",
            color: .blue
        ) {
            VStack(alignment: .leading, spacing: 16) {
                InfoBullet(
                    number: "1",
                    title: "Track Your Health",
                    description: "Throughout your plan, you log meals, sleep, exercise, and other metrics."
                )

                InfoBullet(
                    number: "2",
                    title: "We Analyze Patterns",
                    description: "After 90 days, we compare your tracked data against your survey responses."
                )

                InfoBullet(
                    number: "3",
                    title: "Review Suggestions",
                    description: "We show you proposed updates based on what you actually did vs. what you originally reported."
                )

                InfoBullet(
                    number: "4",
                    title: "Quick Check-ins",
                    description: "For areas we can't track (like substance use), we just ask if anything changed."
                )
            }
        }
    }

    private var dataDrivenSection: some View {
        InfoSection(
            title: "Data-Driven Updates",
            icon: "chart.line.uptrend.xyaxis",
            color: .green
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("These survey questions can be updated automatically based on your tracked data:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(dataTrackedAreas, id: \.self) { area in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text(area)
                            .font(.subheadline)
                    }
                }

                Text("You can accept these suggestions or keep your original responses.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
    }

    private var manualReviewSection: some View {
        InfoSection(
            title: "Manual Review Areas",
            icon: "person.fill.questionmark",
            color: .orange
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Some areas can't be tracked automatically and need your input:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(manualReviewAreas, id: \.self) { area in
                    HStack(spacing: 8) {
                        Image(systemName: "circle")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text(area)
                            .font(.subheadline)
                    }
                }

                Text("For these, we simply ask 'Any changes since last time?' - quick and easy!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
    }

    private var tipsSection: some View {
        InfoSection(
            title: "Tips",
            icon: "lightbulb.fill",
            color: .yellow
        ) {
            VStack(alignment: .leading, spacing: 12) {
                TipRow(
                    icon: "clock.fill",
                    text: "Reassessment takes about 5-10 minutes"
                )

                TipRow(
                    icon: "checkmark.seal.fill",
                    text: "Your tracked data is already factored in - just review and confirm"
                )

                TipRow(
                    icon: "cross.case.fill",
                    text: "Medical history is now in the Data tab, editable anytime"
                )

                TipRow(
                    icon: "arrow.clockwise",
                    text: "A new personalized plan is generated after you complete reassessment"
                )
            }
        }
    }

    // MARK: - Data

    private let dataTrackedAreas = [
        "Daily protein intake",
        "Sleep duration & patterns",
        "Exercise frequency",
        "Step counts",
        "Meal timing",
        "Vegetable/fruit servings"
    ]

    private let manualReviewAreas = [
        "Substance use habits",
        "Supplementation routine",
        "Mental wellbeing & stress",
        "Social connections",
        "Environmental factors"
    ]
}

// MARK: - Helper Views

struct InfoSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
            }

            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct InfoBullet: View {
    let number: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .font(.caption)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    ReassessmentInfoSheet()
}
