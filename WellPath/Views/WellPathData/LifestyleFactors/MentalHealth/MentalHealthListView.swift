//
//  MentalHealthListView.swift
//  WellPath
//
//  Mental health assessments section with Apple Health-inspired UI.
//  Each assessment shows a score chart with "Take Assessment" button.
//

import SwiftUI
import Charts

struct MentalHealthListView: View {
    @StateObject private var viewModel = MentalHealthViewModel()

    var body: some View {
        List {
            Section {
                NavigationLink(destination: AssessmentDetailView(assessmentType: .swls)) {
                    AssessmentRow(
                        name: "Well-Being",
                        subtitle: "Satisfaction with Life Scale (SWLS)",
                        icon: "face.smiling.fill",
                        color: .yellow,
                        lastScore: viewModel.latestSWLSScore,
                        lastDate: viewModel.latestSWLSDate
                    )
                }

                NavigationLink(destination: AssessmentDetailView(assessmentType: .gad2)) {
                    AssessmentRow(
                        name: "Anxiety",
                        subtitle: "Generalized Anxiety Disorder (GAD-2)",
                        icon: "brain.head.profile",
                        color: .mint,
                        lastScore: viewModel.latestGAD2Score,
                        lastDate: viewModel.latestGAD2Date
                    )
                }

                NavigationLink(destination: AssessmentDetailView(assessmentType: .phq2)) {
                    AssessmentRow(
                        name: "Depression",
                        subtitle: "Patient Health Questionnaire (PHQ-2)",
                        icon: "heart.circle.fill",
                        color: .indigo,
                        lastScore: viewModel.latestPHQ2Score,
                        lastDate: viewModel.latestPHQ2Date
                    )
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("About Mental Health Assessments")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("These clinically validated assessments help track your mental well-being over time. Regular check-ins can help identify patterns and support conversations with healthcare providers.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Mental Health")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadLatestScores()
        }
    }
}

// MARK: - Assessment Row

struct AssessmentRow: View {
    let name: String
    let subtitle: String
    let icon: String
    let color: Color
    let lastScore: Int?
    let lastDate: Date?

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 22))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let date = lastDate {
                    Text("Last: \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let score = lastScore {
                Text("\(score)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            } else {
                Text("Start")
                    .font(.subheadline)
                    .foregroundColor(color)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Assessment Detail View (Apple Health Style)

struct AssessmentDetailView: View {
    let assessmentType: MentalHealthAssessmentType
    @StateObject private var viewModel = AssessmentDetailViewModel()
    @State private var showingAssessment = false
    @State private var selectedPeriod: MentalHealthTimePeriod = .monthly

    private var color: Color {
        switch assessmentType {
        case .swls: return .yellow
        case .gad2: return .mint
        case .phq2: return .indigo
        }
    }

    private var description: String {
        switch assessmentType {
        case .swls:
            return "The SWLS is a 5-question assessment measuring your overall satisfaction with life."
        case .gad2:
            return "A quick 2-question screening for generalized anxiety disorder symptoms."
        case .phq2:
            return "A brief 2-question screening for depression symptoms over the past 2 weeks."
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Latest Score Display
                latestScoreSection

                // Period Selector
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(MentalHealthTimePeriod.allCases, id: \.self) { period in
                        Text(period.shortLabel).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Score History Chart
                scoreChartSection

                // Take Assessment Button
                Button {
                    showingAssessment = true
                } label: {
                    HStack {
                        Image(systemName: "clipboard.fill")
                        Text("Take Assessment")
                        Spacer()
                        Text("\(assessmentType.questionCount) questions")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Image(systemName: "chevron.right")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(color)
                    .cornerRadius(12)
                }
                .padding(.horizontal)

                // About Section
                aboutSection

                Spacer()
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(assessmentType.displayName)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingAssessment) {
            AssessmentFlowView(assessmentType: assessmentType) { score, responses in
                Task {
                    await viewModel.saveAssessment(
                        type: assessmentType,
                        score: score,
                        responses: responses
                    )
                    await viewModel.loadHistory(for: assessmentType)
                }
            }
        }
        .task {
            await viewModel.loadHistory(for: assessmentType)
        }
    }

    // MARK: - Latest Score Section

    private var latestScoreSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: viewModel.scoreProgress(for: assessmentType))
                    .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    if let score = viewModel.latestScore {
                        Text("\(score)")
                            .font(.system(size: 36, weight: .bold))
                        Text(viewModel.interpretation(for: assessmentType))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("--")
                            .font(.system(size: 36, weight: .bold))
                        Text("No data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Text("Score range: \(assessmentType.scoreRange.lowerBound)-\(assessmentType.scoreRange.upperBound)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
    }

    // MARK: - Score Chart Section

    private var scoreChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.scoreHistory.isEmpty {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .frame(height: 200)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("Score history will appear here")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
            } else {
                Chart {
                    ForEach(viewModel.scoreHistory) { dataPoint in
                        PointMark(
                            x: .value("Date", dataPoint.date),
                            y: .value("Score", dataPoint.score)
                        )
                        .foregroundStyle(color)
                        .symbolSize(100)

                        LineMark(
                            x: .value("Date", dataPoint.date),
                            y: .value("Score", dataPoint.score)
                        )
                        .foregroundStyle(color.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                .chartYScale(domain: assessmentType.scoreRange)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 200)
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About \(assessmentType.fullName)")
                .font(.headline)

            Text(description)
                .font(.body)
                .foregroundColor(.secondary)

            if let interpretation = viewModel.interpretationDescription(for: assessmentType) {
                Divider()
                Text("What your score means")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(interpretation)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Mental Health Time Period Enum

enum MentalHealthTimePeriod: String, CaseIterable {
    case daily = "D"
    case weekly = "W"
    case monthly = "M"
    case sixMonth = "6M"
    case yearly = "Y"

    var shortLabel: String { rawValue }
}

// MARK: - Mental Health Score Data Point

struct MentalHealthScoreDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let score: Int
}

// MARK: - Previews

#Preview {
    NavigationStack {
        MentalHealthListView()
    }
}

#Preview("Assessment Detail") {
    NavigationStack {
        AssessmentDetailView(assessmentType: .swls)
    }
}
