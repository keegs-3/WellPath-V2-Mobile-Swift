//
//  WellPathOverviewView.swift
//  WellPath
//
//  Level 1: Overall WellPath Score with 7 Pillar Breakdown
//

import SwiftUI

struct WellPathOverviewView: View {
    @StateObject private var viewModel = WellPathScoreViewModel()
    @State private var selectedView: ScoreView = .scoreHistory
    @State private var sortOption: PillarSortOption = .order

    enum ScoreView: String, CaseIterable {
        case scoreHistory = "Score History"
        case breakdown = "Breakdown"
        case about = "About"
    }

    enum PillarSortOption: String, CaseIterable {
        case score = "Score"
        case order = "Order"
        case recentChange = "Recent Change"
    }

    private let wellPathGreen = Color(red: 0.56, green: 0.82, blue: 0.31)

    var body: some View {
        contentView
            .background(
                ZStack {
                    // Background gradient
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [
                                wellPathGreen.opacity(0.65),
                                wellPathGreen.opacity(0.45),
                                wellPathGreen.opacity(0.25),
                                wellPathGreen.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 900)

                        Spacer()
                    }

                    // Large background logo
                    VStack {
                        HStack {
                            Spacer()
                            Image("white_grey")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 180, height: 180)
                                .opacity(0.35)
                                .rotationEffect(.degrees(-15))
                                .offset(x: 40, y: 20)
                        }
                        Spacer()
                    }
                }
                .ignoresSafeArea()
            )
            .navigationTitle("WellPath Score")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.loadWellPathScore()
                await viewModel.loadPillarScores()
                await viewModel.loadScoreAboutContent()
                await viewModel.loadPillarAboutContent()
            }
    }

    private var contentView: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await viewModel.loadWellPathScore()
                            await viewModel.loadPillarScores()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // View picker
                        Picker("View", selection: $selectedView) {
                            ForEach(ScoreView.allCases, id: \.self) { view in
                                Text(view.rawValue).tag(view)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                        // Content based on selected view
                        switch selectedView {
                        case .scoreHistory:
                            scoreHistoryContent
                        case .breakdown:
                            breakdownContent
                        case .about:
                            aboutContent
                        }
                    }
                }
            }
        }
    }

    // MARK: - Score History Content

    private var scoreHistoryContent: some View {
        VStack(spacing: 16) {
            // Trend chart at top
            WellPathScoreTrendChart()
                .padding(.top, 8)

            // Sort options
            HStack {
                Text("Sort by:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("Sort", selection: $sortOption) {
                    ForEach(PillarSortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Pillar list
            VStack(spacing: 12) {
                ForEach(sortedPillars) { pillarScore in
                    NavigationLink(destination: PillarDetailView(pillarScore: pillarScore)) {
                        PillarScoreRowWithTrend(pillarScore: pillarScore)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Breakdown Content

    private var breakdownContent: some View {
        VStack(spacing: 24) {
            // Donut chart
            PillarDonutChart()
                .padding(.top, 16)
                .padding(.bottom, 32)
        }
    }

    private var sortedPillars: [PillarScore] {
        switch sortOption {
        case .score:
            return viewModel.pillarScores.sorted { $0.pillarPercentage > $1.pillarPercentage }
        case .order:
            let pillarOrder = [
                "Healthful Nutrition",
                "Movement + Exercise",
                "Restorative Sleep",
                "Cognitive Health",
                "Stress Management",
                "Connection + Purpose",
                "Core Care"
            ]
            return viewModel.pillarScores.sorted { pillar1, pillar2 in
                let index1 = pillarOrder.firstIndex(of: pillar1.pillarName) ?? Int.max
                let index2 = pillarOrder.firstIndex(of: pillar2.pillarName) ?? Int.max
                return index1 < index2
            }
        case .recentChange:
            // TODO: Sort by recent change when we have historical data
            return viewModel.pillarScores
        }
    }

    // MARK: - About Content

    private var aboutContent: some View {
        VStack(spacing: 24) {
            // Content sections from database
            if viewModel.scoreAboutSections.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("About content loading...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 32)
            } else {
                VStack(alignment: .leading, spacing: 32) {
                    ForEach(Array(viewModel.scoreAboutSections.enumerated()), id: \.element.id) { index, section in
                        ContentSection(
                            icon: section.sectionIcon,
                            title: section.sectionTitle,
                            color: wellPathGreen,
                            content: section.sectionContent
                        )

                        if index < viewModel.scoreAboutSections.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
    }
}

// MARK: - Content Section Component

struct ContentSection: View {
    let icon: String
    let title: String
    let color: Color
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            Text(.init(content))
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Pillar Score Row with Trend

struct PillarScoreRowWithTrend: View {
    let pillarScore: PillarScore

    private var pillarColor: Color {
        MetricsUIConfig.getPillarColor(for: pillarScore.pillarName)
    }

    private var pillarIcon: String {
        MetricsUIConfig.getPillarIcon(for: pillarScore.pillarName)
    }

    // TODO: Calculate actual trend from historical data
    private var trendIndicator: TrendDirection {
        .stable // Placeholder
    }

    enum TrendDirection {
        case up, down, stable

        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .stable: return "arrow.right"
            }
        }

        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .stable: return .gray
            }
        }

        var label: String {
            switch self {
            case .up: return "Trending up"
            case .down: return "Trending down"
            case .stable: return "Stable"
            }
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Left side - Score ring with icon
            ScoreRingView(
                score: pillarScore.pillarPercentage,
                maxScore: 100,
                size: 70,
                lineWidth: 7,
                color: pillarColor
            ) {
                AnyView(
                    VStack(spacing: 2) {
                        Image(systemName: pillarIcon)
                            .font(.system(size: 16))
                            .foregroundColor(pillarColor)

                        Text("\(pillarScore.percentageInt)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                    }
                )
            }

            // Middle - Pillar name, score, and trend
            VStack(alignment: .leading, spacing: 4) {
                Text(pillarScore.pillarName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("\(pillarScore.percentageInt)% score")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Trend indicator on third line
                HStack(spacing: 4) {
                    Image(systemName: trendIndicator.icon)
                        .foregroundColor(trendIndicator.color)
                        .font(.system(size: 12, weight: .semibold))
                    Text(trendIndicator.label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }

            Spacer()

            // Right side - Chevron
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Pillar Detail View (Level 2)

struct PillarDetailView: View {
    let pillarScore: PillarScore
    @StateObject private var viewModel = WellPathScoreViewModel()
    @State private var selectedView: PillarView = .scoreHistory

    enum PillarView: String, CaseIterable {
        case scoreHistory = "Score History"
        case breakdown = "Breakdown"
        case about = "About"
    }

    private var pillarColor: Color {
        MetricsUIConfig.getPillarColor(for: pillarScore.pillarName)
    }

    private var pillarIcon: String {
        MetricsUIConfig.getPillarIcon(for: pillarScore.pillarName)
    }

    private var componentScores: PillarComponentScore? {
        viewModel.getComponentScores(for: pillarScore.pillarName)
    }

    var body: some View {
        contentView
            .background(
                ZStack {
                    // Background gradient - vertical from pillar color to white
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [
                                pillarColor.opacity(0.65),
                                pillarColor.opacity(0.45),
                                pillarColor.opacity(0.25),
                                pillarColor.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 900)

                        Spacer()
                    }

                    // Large background icon
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: pillarIcon)
                                .font(.system(size: 200))
                                .foregroundStyle(Color.white.opacity(0.2))
                                .rotationEffect(.degrees(-15))
                                .offset(x: 50, y: -50)
                        }
                        Spacer()
                    }
                }
                .ignoresSafeArea()
            )
            .navigationTitle(pillarScore.pillarName)
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.loadPillarScores()
                await viewModel.loadComponentScores(for: pillarScore.pillarName)
                await viewModel.loadPillarAboutContent()
            }
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // View picker
                Picker("View", selection: $selectedView) {
                    ForEach(PillarView.allCases, id: \.self) { view in
                        Text(view.rawValue).tag(view)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // Content based on selected view
                switch selectedView {
                case .scoreHistory:
                    scoreHistoryContent
                case .breakdown:
                    breakdownContent
                case .about:
                    pillarAboutContent
                }
            }
        }
    }

    // MARK: - Score History Content

    private var scoreHistoryContent: some View {
        VStack(spacing: 16) {
            // Pillar score trend chart
            PillarScoreTrendChart(pillarName: pillarScore.pillarName)
                .padding(.top, 8)

            // Component Score Cards Section
            VStack(alignment: .leading, spacing: 16) {
                Text("Score Components")
                    .font(.system(size: 20, weight: .semibold))
                    .padding(.horizontal)

                VStack(spacing: 12) {
                    NavigationLink(destination: MarkersDetailView(pillarName: pillarScore.pillarName)) {
                        ComponentScoreCard(
                            title: "Markers",
                            icon: "chart.xyaxis.line",
                            color: Color(red: 0.40, green: 0.80, blue: 0.40),
                            description: "Biomarkers & Biometrics",
                            score: viewModel.componentScores.first(where: { $0.componentType == "markers" })?.componentPercentage,
                            pillarColor: pillarColor
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    NavigationLink(destination: BehaviorsDetailView(pillarName: pillarScore.pillarName)) {
                        ComponentScoreCard(
                            title: "Behaviors",
                            icon: "figure.walk",
                            color: Color(red: 0.20, green: 0.60, blue: 0.86),
                            description: "Lifestyle & Habits",
                            score: viewModel.componentScores.first(where: { $0.componentType == "behaviors" })?.componentPercentage,
                            pillarColor: pillarColor
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    NavigationLink(destination: EducationDetailView(pillarName: pillarScore.pillarName)) {
                        ComponentScoreCard(
                            title: "Education",
                            icon: "book.fill",
                            color: Color(red: 0.74, green: 0.56, blue: 0.94),
                            description: "Learning & Content",
                            score: viewModel.componentScores.first(where: { $0.componentType == "education" })?.componentPercentage,
                            pillarColor: pillarColor
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Breakdown Content

    private var breakdownContent: some View {
        VStack(spacing: 24) {
            // Component contribution pie chart
            ComponentContributionChart(
                pillarName: pillarScore.pillarName,
                pillarColor: pillarColor
            )
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - About Content

    private var pillarAboutContent: some View {
        VStack(spacing: 24) {
            // Content sections from database
            if let sections = viewModel.pillarAboutSections[pillarScore.pillarName], !sections.isEmpty {
                VStack(alignment: .leading, spacing: 32) {
                    ForEach(Array(sections.sorted(by: { $0.displayOrder < $1.displayOrder }).enumerated()), id: \.element.id) { index, section in
                        ContentSection(
                            icon: "info.circle.fill",
                            title: section.sectionTitle,
                            color: pillarColor,
                            content: section.sectionContent
                        )

                        if index < sections.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 32)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("About content loading...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 32)
            }
        }
    }

}

// MARK: - Component Score Card

struct ComponentScoreCard: View {
    let title: String
    let icon: String
    let color: Color
    let description: String
    let score: Double?
    let pillarColor: Color

    private var scoreInt: Int {
        Int((score ?? 0).rounded())
    }

    var body: some View {
        HStack(spacing: 16) {
            // Left side - Score ring with icon
            if let scoreValue = score {
                ScoreRingView(
                    score: scoreValue,
                    maxScore: 100,
                    size: 70,
                    lineWidth: 7,
                    color: color
                ) {
                    AnyView(
                        VStack(spacing: 2) {
                            Image(systemName: icon)
                                .font(.system(size: 16))
                                .foregroundColor(color)

                            Text("\(scoreInt)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                        }
                    )
                }
            } else {
                // Fallback: empty ring
                ScoreRingView(
                    score: 0,
                    maxScore: 100,
                    size: 70,
                    lineWidth: 7,
                    color: color.opacity(0.3)
                ) {
                    AnyView(
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .foregroundColor(color.opacity(0.5))
                    )
                }
            }

            // Middle - Component name, description, score
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let scoreValue = score {
                    Text("\(scoreInt)% score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
            }

            Spacer()

            // Right side - Chevron
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        WellPathOverviewView()
    }
}
