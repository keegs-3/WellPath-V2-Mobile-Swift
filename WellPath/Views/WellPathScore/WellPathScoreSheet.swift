//
//  WellPathScoreSheet.swift
//  WellPath
//
//  Score Sheet that displays when tapping the WellPath logo.
//  Shows a comprehensive summary of all score components.
//

import SwiftUI

struct WellPathScoreSheet: View {
    @ObservedObject var viewModel: WellPathScoreViewModel
    @Environment(\.dismiss) private var dismiss

    private let wellPathGreen = Color(red: 0.56, green: 0.82, blue: 0.31)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with overall score
                    scoreHeaderSection

                    // Score breakdown pie
                    scoreBreakdownSection

                    // 7 Pillar cards
                    pillarCardsSection

                    // Score composition
                    scoreCompositionSection

                    // Quick improvement tips
                    improvementTipsSection
                }
                .padding(.vertical)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Score Sheet")
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

    // MARK: - Score Header Section

    private var scoreHeaderSection: some View {
        VStack(spacing: 16) {
            // Logo and score
            HStack(spacing: 20) {
                Image("white_grey")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .background(wellPathGreen)
                    .cornerRadius(16)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Your WellPath Score")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(currentPercentageInt)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(wellPathGreen)

                        Text("%")
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundColor(wellPathGreen.opacity(0.8))
                    }

                    Text(scoreInterpretation)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)
            .padding(.horizontal)

            // Last updated
            if let calculatedAt = viewModel.currentScore?.calculatedAt {
                Text("Last calculated: \(calculatedAt)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var currentPercentageInt: Int {
        viewModel.currentScore?.scorePercentageInt ?? 0
    }

    private var scoreInterpretation: String {
        let score = currentPercentageInt
        switch score {
        case 90...100: return "Excellent - You're thriving!"
        case 80..<90: return "Very Good - Keep it up!"
        case 70..<80: return "Good - Room for improvement"
        case 60..<70: return "Fair - Focus on key areas"
        case 50..<60: return "Needs Work - Let's improve"
        default: return "Getting Started - Every step counts"
        }
    }

    // MARK: - Score Breakdown Section

    private var scoreBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Score Composition")
                .font(.headline)
                .padding(.horizontal)

            HStack(spacing: 0) {
                // Biomarkers & Biometrics
                VStack {
                    Text("72%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Bio Data")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 50)

                // Surveys
                VStack {
                    Text("18%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                    Text("Surveys")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 50)

                // Education
                VStack {
                    Text("10%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("Education")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    // MARK: - Pillar Cards Section

    private var pillarCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("7 Pillars of Health")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(viewModel.pillarScores) { pillar in
                    PillarScoreCard(pillar: pillar)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Score Composition Section

    private var scoreCompositionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What's Measured")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 0) {
                CompositionRow(icon: "drop.fill", title: "Biomarkers", subtitle: "Lab results & blood work", color: .red)
                Divider().padding(.leading, 56)
                CompositionRow(icon: "heart.fill", title: "Biometrics", subtitle: "Vitals & body measurements", color: .pink)
                Divider().padding(.leading, 56)
                CompositionRow(icon: "list.clipboard.fill", title: "Health Surveys", subtitle: "Lifestyle & habits assessment", color: .purple)
                Divider().padding(.leading, 56)
                CompositionRow(icon: "brain.head.profile", title: "Mental Health", subtitle: "Wellness assessments", color: .indigo)
                Divider().padding(.leading, 56)
                CompositionRow(icon: "book.fill", title: "Education", subtitle: "Health literacy progress", color: .orange)
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    // MARK: - Improvement Tips Section

    private var improvementTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Wins")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 12) {
                // Find lowest pillar and suggest improvement
                if let lowestPillar = viewModel.pillarScores.min(by: { $0.pillarPercentage < $1.pillarPercentage }) {
                    ImprovementTipCard(
                        pillarName: lowestPillar.pillarName,
                        currentScore: lowestPillar.percentageInt,
                        color: MetricsUIConfig.getPillarColor(for: lowestPillar.pillarName)
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Supporting Views

struct PillarScoreCard: View {
    let pillar: PillarScore

    private var pillarColor: Color {
        MetricsUIConfig.getPillarColor(for: pillar.pillarName)
    }

    private var pillarIcon: String {
        MetricsUIConfig.getPillarIcon(for: pillar.pillarName)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: pillarIcon)
                    .font(.title3)
                    .foregroundColor(pillarColor)

                Spacer()

                Text("\(pillar.percentageInt)%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(pillarColor)
            }

            Text(pillar.pillarName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(pillarColor)
                        .frame(width: geometry.size.width * CGFloat(pillar.pillarPercentage) / 100, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct CompositionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
        .padding()
    }
}

struct ImprovementTipCard: View {
    let pillarName: String
    let currentScore: Int
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: "lightbulb.fill")
                    .font(.title3)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Focus on \(pillarName)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("Currently at \(currentScore)% - small improvements here will boost your overall score the most!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

#Preview {
    WellPathScoreSheet(viewModel: WellPathScoreViewModel())
}
