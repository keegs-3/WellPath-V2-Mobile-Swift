//
//  AssessmentScreenTemplate.swift
//  WellPath
//
//  Template for assessment detail screens (questionnaire-based views).
//  Follows standard metric view pattern with charts, education modal, and data management.
//

import SwiftUI
import Charts

// MARK: - Assessment Screen Template

struct AssessmentScreenTemplate: View {
    let assessmentId: String
    let color: Color
    let viewId: String
    let sectionId: String

    @StateObject private var viewModel: AssessmentScreenViewModel
    @StateObject private var scrollManager: AssessmentChartScrollManager
    @State private var showingAssessment = false
    @State private var showAboutModal = false
    @State private var showDataManagement = false
    @State private var showStressInsights = false
    @State private var selectedPeriod: AssessmentPeriod = .month
    @State private var scrollPosition: Date
    @State private var selectedPointDate: Date?

    enum AssessmentPeriod: String, CaseIterable {
        case week = "W"
        case month = "M"
        case sixMonth = "6M"
        case year = "Y"

        var calendarComponent: Calendar.Component {
            switch self {
            case .week: return .day
            case .month: return .day
            case .sixMonth: return .weekOfYear
            case .year: return .month
            }
        }

        var numberOfBars: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .sixMonth: return 26
            case .year: return 12
            }
        }

        var loadChunkSize: Int {
            switch self {
            case .week: return 30
            case .month: return 90
            case .sixMonth: return 180
            case .year: return 365
            }
        }
    }

    /// Derive sectionId from assessmentId for favorites categorization
    private static func deriveSectionId(from assessmentId: String) -> String {
        switch assessmentId {
        case "ASSESS_SLEEP_ROUTINE", "ASSESS_SLEEP_ENVIRONMENT":
            return "NAV_SLEEP"
        case "ASSESS_PSS10":
            return "NAV_STRESS"
        case "ASSESS_SWLS", "ASSESS_GAD2", "ASSESS_PHQ2":
            return "NAV_MENTAL_HEALTH"
        default:
            return "NAV_MENTAL_HEALTH"
        }
    }

    init(assessmentId: String, color: Color, viewId: String? = nil, sectionId: String? = nil) {
        self.assessmentId = assessmentId
        self.color = color
        self.viewId = viewId ?? "DISP_\(assessmentId.replacingOccurrences(of: "ASSESS_", with: "").uppercased())"
        self.sectionId = sectionId ?? AssessmentScreenTemplate.deriveSectionId(from: assessmentId)
        _viewModel = StateObject(wrappedValue: AssessmentScreenViewModel(assessmentId: assessmentId))
        _scrollManager = StateObject(wrappedValue: AssessmentChartScrollManager(assessmentId: assessmentId, period: .month))

        // Initialize scroll position
        let now = Date()
        let initialPeriod = AssessmentPeriod.month
        let visibleDuration = initialPeriod.numberOfBars
        let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
        let scrollStart = Calendar.current.date(
            byAdding: initialPeriod.calendarComponent,
            value: -offsetFromEnd,
            to: now
        ) ?? now
        _scrollPosition = State(initialValue: scrollStart)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Chart section with background
                VStack(spacing: 0) {
                    // Period selector
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(AssessmentPeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, MetricScreenLayout.pickerTopPadding)
                    .onChange(of: selectedPeriod) { oldValue, newPeriod in
                        scrollManager.updatePeriod(newPeriod)
                        selectedPointDate = nil
                        scrollPosition = calculateScrollPosition(for: newPeriod)
                    }
                    .onChange(of: scrollManager.chartData.count) { oldCount, newCount in
                        if oldCount == 0 && newCount > 0 {
                            scrollPosition = calculateScrollPosition(for: selectedPeriod)
                        }
                    }

                    // Score header
                    scoreHeader
                        .padding(.top, MetricScreenLayout.headerTopPadding)

                    // Chart
                    chartSection
                        .padding(.top, MetricScreenLayout.chartTopPadding)
                        .padding(.bottom, MetricScreenLayout.chartBottomPadding)
                }
                .padding(.vertical)
                .background(Color(uiColor: .systemGroupedBackground))

                // View More Detail button (for stress assessment only)
                if assessmentId == "ASSESS_PSS10" {
                    Button {
                        showStressInsights = true
                    } label: {
                        HStack {
                            Text("View More Detail")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .foregroundColor(color)
                        .padding()
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }

                // Questionnaire card (below chart section)
                questionnaireCard
                    .padding(.horizontal)
                    .padding(.top, assessmentId == "ASSESS_PSS10" ? 12 : 16)
                    .padding(.bottom, 24)
            }
        }
        .metricScreenBackground(color: color)
        .navigationTitle(viewModel.assessmentData?.assessment.assessmentName ?? "Assessment")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(
                viewId: viewId,
                metricName: viewModel.assessmentData?.assessment.assessmentName ?? "Assessment",
                color: color,
                isPresented: $showAboutModal
            )
        }
        .sheet(isPresented: $showingAssessment) {
            if let data = viewModel.assessmentData {
                DatabaseAssessmentFlowView(assessmentData: data) { score, responses in
                    Task {
                        await viewModel.saveResult(score: score, responses: responses)
                    }
                }
            }
        }
        .sheet(isPresented: $showDataManagement) {
            AssessmentDataManagementView(
                assessmentId: assessmentId,
                assessmentName: viewModel.assessmentData?.assessment.assessmentName ?? "Assessment",
                color: color
            )
        }
        .sheet(isPresented: $showStressInsights) {
            if let data = viewModel.assessmentData {
                StressInsightsModal(
                    assessmentData: data,
                    scoreHistory: viewModel.scoreHistory,
                    color: color
                )
            }
        }
        .task {
            await viewModel.load()
        }
    }

    // MARK: - Score Header (Apple Health style - tier name, not score)

    /// Selected point for display
    private var selectedPoint: AssessmentChartPoint? {
        guard let selectedDate = selectedPointDate else { return nil }
        return dataPointsWithValues.first(where: {
            Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: selectedPeriod.calendarComponent)
        })
    }

    private var scoreHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                if let selected = selectedPoint {
                    // Show selected point info
                    if selected.hasRange {
                        // Multiple entries - show tier range
                        let minTier = tierName(for: Double(selected.minScore))
                        let maxTier = tierName(for: Double(selected.maxScore))
                        if minTier == maxTier {
                            Text(minTier)
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(.primary)
                        } else {
                            Text("\(minTier)–\(maxTier)")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        Text("\(selected.entryCount) entries • \(formatSelectedDate(selected.date))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        // Single entry - show tier name
                        Text(tierName(for: Double(selected.score)))
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.primary)
                        Text(formatSelectedDate(selected.date))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Show overall entry count and tier range
                    let totalEntries = dataPointsWithValues.reduce(0) { $0 + $1.entryCount }
                    let tierRange = getVisibleTierRange()

                    if totalEntries > 0 {
                        // Show tier range for 6M/Y, or entry count for W/M
                        if selectedPeriod == .sixMonth || selectedPeriod == .year, let range = tierRange {
                            Text(range)
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(.primary)
                        } else {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(totalEntries)")
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundColor(.primary)
                                Text(totalEntries == 1 ? "entry" : "entries")
                                    .font(.title3)
                                    .foregroundColor(.primary)
                            }
                        }
                        Text(visibleDateRangeString())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No Data")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("Complete an assessment to see results")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Info button
            Button {
                showAboutModal = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundColor(color)
            }
        }
        .padding(.horizontal)
    }

    /// Format selected date based on period
    private func formatSelectedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()

        switch selectedPeriod {
        case .week, .month:
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        case .sixMonth:
            // Show week range
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
                formatter.dateFormat = "MMM d, yyyy"
                return formatter.string(from: date)
            }
            let startFormatter = DateFormatter()
            startFormatter.dateFormat = "MMM d"
            let endFormatter = DateFormatter()
            endFormatter.dateFormat = "MMM d, yyyy"
            let lastDay = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.end
            return "\(startFormatter.string(from: weekInterval.start)) – \(endFormatter.string(from: lastDay))"
        case .year:
            formatter.dateFormat = "MMM yyyy"
            return formatter.string(from: date)
        }
    }

    /// Get the tier range string for visible data (e.g., "Low–High")
    private func getVisibleTierRange() -> String? {
        let visibleData = dataPointsWithValues
        guard !visibleData.isEmpty else { return nil }

        // Get the absolute min and max across all data points
        let allMinScores = visibleData.map { $0.minScore }
        let allMaxScores = visibleData.map { $0.maxScore }
        guard let minScore = allMinScores.min(), let maxScore = allMaxScores.max() else { return nil }

        let minTier = tierName(for: Double(minScore))
        let maxTier = tierName(for: Double(maxScore))

        if minTier == maxTier {
            return minTier
        }
        return "\(minTier)–\(maxTier)"
    }

    private func visibleDateRangeString() -> String {
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date = {
            switch selectedPeriod {
            case .week: return calendar.date(byAdding: .day, value: -7, to: now) ?? now
            case .month: return calendar.date(byAdding: .month, value: -1, to: now) ?? now
            case .sixMonth: return calendar.date(byAdding: .month, value: -6, to: now) ?? now
            case .year: return calendar.date(byAdding: .year, value: -1, to: now) ?? now
            }
        }()

        let startFormatter = DateFormatter()
        startFormatter.dateFormat = "MMM d"
        let endFormatter = DateFormatter()
        endFormatter.dateFormat = "MMM d, yyyy"
        return "\(startFormatter.string(from: startDate)) – \(endFormatter.string(from: now))"
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if viewModel.isLoading || scrollManager.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
            } else {
                assessmentChart
                    .padding(.horizontal)

                // Loading indicators
                HStack {
                    if scrollManager.isLoadingOlder {
                        ProgressView().scaleEffect(0.7)
                        Text("Loading...").font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer()
                    if scrollManager.isLoadingNewer {
                        Text("Loading...").font(.caption2).foregroundColor(.secondary)
                        ProgressView().scaleEffect(0.7)
                    }
                }
                .frame(height: 14)
                .padding(.horizontal)
            }
        }
    }

    /// Data points with actual values
    private var dataPointsWithValues: [AssessmentChartPoint] {
        scrollManager.chartData.filter { $0.entryCount > 0 }
    }

    /// Tiers sorted by tier_order (determines Y-axis display order)
    /// For "positive" assessments (Sleep Routine/Environment): tier_order 1 = worst (bottom), highest = best (top)
    /// For "negative" assessments (Stress/Anxiety): tier_order 1 = best (bottom), highest = worst (top)
    private var sortedTiers: [ViewAssessmentTier] {
        (viewModel.assessmentData?.tiers ?? []).sorted { $0.tierOrder < $1.tierOrder }
    }

    /// Tier names for categorical Y-axis - order determines position (first = TOP in categorical Charts)
    /// For stress/anxiety: Very High (worst) at top, Very Low (best) at bottom
    /// For sleep: Excellent (best) at top, Poor (worst) at bottom
    private var tierNames: [String] {
        // sortedTiers is sorted by tier_order ascending (1=best/lowest for sleep, 1=best/lowest stress for stress)
        // For Sleep: tier_order 1 = Poor, higher = Excellent → want Excellent at top → REVERSE
        // For Stress/Anxiety: tier_order 1 = Very Low (good), higher = Very High (bad) → want Very High at top → REVERSE
        // Both cases: reverse so highest tier_order is at top (index 0)
        return sortedTiers.reversed().map { $0.tierName }
    }

    /// Get tier name for a score value
    private func tierName(for score: Double) -> String {
        let tiers = viewModel.assessmentData?.tiers ?? []
        let intScore = Int(score)
        return tiers.first { intScore >= $0.scoreMin && intScore <= $0.scoreMax }?.tierName ?? ""
    }

    /// Map score to tier name for chart plotting
    private func tierForScore(_ score: Int) -> String {
        let tiers = viewModel.assessmentData?.tiers ?? []
        return tiers.first { score >= $0.scoreMin && score <= $0.scoreMax }?.tierName ?? ""
    }

    /// Get tier position (order) for a score - used for numeric Y-axis
    /// Returns the tier_order value, which is used for vertical positioning
    private func tierPositionForScore(_ score: Int) -> Double {
        let tiers = viewModel.assessmentData?.tiers ?? []
        guard let tier = tiers.first(where: { score >= $0.scoreMin && score <= $0.scoreMax }) else {
            return 0
        }
        return Double(tier.tierOrder)
    }

    /// Get Y-axis domain based on tier orders
    private var tierYAxisDomain: ClosedRange<Double> {
        guard !sortedTiers.isEmpty else { return 0...5 }
        let minOrder = Double(sortedTiers.first?.tierOrder ?? 1)
        let maxOrder = Double(sortedTiers.last?.tierOrder ?? 5)
        // Add padding for visual clarity
        return (minOrder - 0.5)...(maxOrder + 0.5)
    }

    /// Bar width varies by time period for visual density
    private var barWidth: CGFloat {
        switch selectedPeriod {
        case .week: return 6
        case .month: return 4
        case .sixMonth: return 5
        case .year: return 6
        }
    }

    private var assessmentChart: some View {
        HStack(alignment: .top, spacing: 0) {
            // Main chart area - uses numeric Y axis for range bar support
            Chart {
                // Invisible placeholder to establish timeline
                ForEach(scrollManager.chartData) { point in
                    PointMark(
                        x: .value("Date", point.date, unit: selectedPeriod.calendarComponent),
                        y: .value("Position", tierYAxisDomain.lowerBound)
                    )
                    .opacity(0)
                }

                // Score visualization - range bars for multi-entry periods, points for single entries
                ForEach(dataPointsWithValues) { point in
                    let isSelected = selectedPointDate != nil &&
                        Calendar.current.isDate(point.date, equalTo: selectedPointDate!, toGranularity: selectedPeriod.calendarComponent)

                    if point.hasRange {
                        // Range bar showing min to max tier
                        let minPosition = tierPositionForScore(point.minScore)
                        let maxPosition = tierPositionForScore(point.maxScore)

                        BarMark(
                            x: .value("Date", point.date, unit: selectedPeriod.calendarComponent),
                            yStart: .value("Min", minPosition),
                            yEnd: .value("Max", maxPosition),
                            width: .fixed(barWidth)
                        )
                        .foregroundStyle(isSelected ? color : color.opacity(0.7))
                        .clipShape(Capsule())
                    } else {
                        // Single point for single-entry periods
                        let position = tierPositionForScore(point.score)

                        PointMark(
                            x: .value("Date", point.date, unit: selectedPeriod.calendarComponent),
                            y: .value("Position", position)
                        )
                        .foregroundStyle(point.tierColor ?? color)
                        .symbolSize(isSelected ? 120 : 60)
                    }
                }
            }
            .chartYScale(domain: tierYAxisDomain)
            .frame(height: 220)
            .chartScrollableAxes(.horizontal)
            .chartScrollPosition(x: $scrollPosition)
            .chartXVisibleDomain(length: getVisibleDomainTimeInterval())
            .chartGesture { proxy in
                SpatialTapGesture()
                    .onEnded { value in
                        if let tappedDate: Date = proxy.value(atX: value.location.x) {
                            let closest = dataPointsWithValues
                                .min(by: {
                                    abs($0.date.timeIntervalSince(tappedDate)) < abs($1.date.timeIntervalSince(tappedDate))
                                })
                            if let closestDate = closest?.date,
                               Calendar.current.isDate(selectedPointDate ?? Date.distantPast, equalTo: closestDate, toGranularity: selectedPeriod.calendarComponent) {
                                selectedPointDate = nil
                            } else {
                                selectedPointDate = closest?.date
                            }
                        }
                    }
            }
            .onChange(of: scrollPosition) { oldValue, newValue in
                handleChartScrolling(position: newValue)
            }
            .chartYAxis {
                // Gridlines at each tier position
                AxisMarks(values: sortedTiers.map { Double($0.tierOrder) }) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.secondary.opacity(0.4))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: xAxisStride, count: xAxisLabelMultiplier)) { _ in
                    AxisValueLabel(format: xAxisFormat)
                        .foregroundStyle(Color.secondary)
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.secondary.opacity(0.2))
                }
            }

            // Y-axis tier labels on right side - positioned to align with gridlines
            VStack(alignment: .leading, spacing: 0) {
                // Reversed to match chart orientation (highest tier_order at top)
                ForEach(sortedTiers.reversed(), id: \.tierOrder) { tier in
                    Text(tier.tierName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
            .frame(width: 60, height: 220)
            .padding(.bottom, 24) // Account for x-axis labels
        }
    }

    // MARK: - Scroll Handling

    private func calculateScrollPosition(for period: AssessmentPeriod) -> Date {
        let mostRecentDataDate = dataPointsWithValues.first?.date ?? Date()
        let visibleDuration = period.numberOfBars
        let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
        return Calendar.current.date(
            byAdding: period.calendarComponent,
            value: -offsetFromEnd,
            to: mostRecentDataDate
        ) ?? mostRecentDataDate
    }

    private func handleChartScrolling(position: Date) {
        guard !scrollManager.chartData.isEmpty else { return }

        let calendar = Calendar.current
        let component = selectedPeriod.calendarComponent

        if let oldestDate = scrollManager.chartData.last?.date {
            let diff = calendar.dateComponents([component], from: oldestDate, to: position)
            let units = abs(diff.value(for: component) ?? 0)
            if units < 5 && !scrollManager.isLoadingOlder {
                scrollManager.loadOlderData()
            }
        }

        if let newestDate = scrollManager.chartData.first?.date {
            let diff = calendar.dateComponents([component], from: position, to: newestDate)
            let units = abs(diff.value(for: component) ?? 0)
            if units < 5 && !scrollManager.isLoadingNewer {
                scrollManager.loadNewerData()
            }
        }
    }

    private func getVisibleDomainTimeInterval() -> TimeInterval {
        switch selectedPeriod {
        case .week: return 7 * 24 * 3600
        case .month: return 30 * 24 * 3600
        case .sixMonth: return 26 * 7 * 24 * 3600
        case .year: return 365 * 24 * 3600
        }
    }

    private var xAxisStride: Calendar.Component {
        switch selectedPeriod {
        case .week: return .day
        case .month: return .weekOfYear
        case .sixMonth: return .month
        case .year: return .month
        }
    }

    private var xAxisLabelMultiplier: Int {
        switch selectedPeriod {
        case .week: return 1
        case .month: return 1
        case .sixMonth: return 1
        case .year: return 1
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch selectedPeriod {
        case .week: return .dateTime.weekday(.narrow)
        case .month: return .dateTime.day()
        case .sixMonth: return .dateTime.month(.abbreviated)
        case .year: return .dateTime.month(.narrow)
        }
    }

    // MARK: - Questionnaire Card (Apple Health style)

    /// Custom questionnaire content per assessment type
    private var questionnaireContent: (title: String, body: String) {
        switch assessmentId {
        case "ASSESS_SLEEP_ROUTINE":
            return ("Sleep Routine Questionnaire",
                    "Understanding your sleep habits can help identify opportunities to improve your rest and overall health.")
        case "ASSESS_SLEEP_ENVIRONMENT":
            return ("Sleep Environment Questionnaire",
                    "Your sleep environment plays a crucial role in the quality of your rest and recovery.")
        case "ASSESS_PSS10":
            return ("Stress Level Questionnaire",
                    "Regular assessment of your stress levels can help you recognize patterns and take steps to manage them effectively.")
        case "ASSESS_SWLS":
            return ("Well-Being Questionnaire",
                    "Checking in on your overall well-being helps you stay connected to what matters most for your health.")
        case "ASSESS_GAD2":
            return ("Anxiety Questionnaire",
                    "Along with regular reflection, assessing your current risk for anxiety can be an important part of caring for your mental health.")
        case "ASSESS_PHQ2":
            return ("Depression Questionnaire",
                    "Understanding your current risk for depression can help you take proactive steps to support your mental health.")
        default:
            return ("\(viewModel.assessmentData?.assessment.assessmentName ?? "Assessment") Questionnaire",
                    "Complete this assessment to track your progress over time.")
        }
    }

    private var questionnaireCard: some View {
        HStack(alignment: .top, spacing: 16) {
            // Clipboard icon with assessment icon inside
            ZStack {
                // Clipboard background
                Image(systemName: "clipboard.fill")
                    .font(.system(size: 56))
                    .foregroundColor(color.opacity(0.2))

                // Assessment-specific icon inside clipboard
                Image(systemName: viewModel.assessmentData?.assessment.icon ?? "questionmark")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(color)
                    .offset(y: 6)
            }
            .frame(width: 64, height: 72)

            VStack(alignment: .leading, spacing: 12) {
                // Title
                Text(questionnaireContent.title)
                    .font(.headline)
                    .foregroundColor(.primary)

                // Body text
                Text(questionnaireContent.body)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Take Questionnaire button - left-aligned with text
                Button {
                    showingAssessment = true
                } label: {
                    Text("Take Questionnaire")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(color, lineWidth: 1.5)
                        )
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button { showDataManagement = true } label: {
                Image(systemName: "list.bullet")
            }
        }

        ToolbarItemGroup(placement: .navigationBarTrailing) {
            FavoriteButton(
                itemType: .metric,
                itemId: viewId,
                displayName: viewModel.assessmentData?.assessment.assessmentName ?? "Assessment",
                pillar: viewModel.assessmentData?.assessment.pillar ?? "Mental Health",
                cardId: nil,
                sectionId: sectionId
            )

            Button { showingAssessment = true } label: {
                Image(systemName: "plus")
            }
        }
    }
}

// MARK: - Assessment Screen ViewModel

@MainActor
class AssessmentScreenViewModel: ObservableObject {
    @Published var assessmentData: AssessmentData?
    @Published var scoreHistory: [AssessmentResult] = []
    @Published var latestScore: Int?
    @Published var latestDate: Date?
    @Published var isLoading = false
    @Published var error: Error?

    private let assessmentId: String
    private let service = AssessmentService.shared

    init(assessmentId: String) {
        self.assessmentId = assessmentId
    }

    var scoreProgress: Double {
        guard let data = assessmentData, let score = latestScore else { return 0 }
        return data.scoreProgress(for: score)
    }

    var interpretation: String {
        guard let data = assessmentData, let score = latestScore else { return "" }
        return data.interpretation(for: score)
    }

    var tierColor: Color? {
        guard let data = assessmentData, let score = latestScore else { return nil }
        return data.tier(for: score)?.color
    }

    var interpretationDescription: String? {
        guard let data = assessmentData, let score = latestScore else { return nil }
        return data.interpretationDescription(for: score)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            assessmentData = try await service.fetchAssessmentData(assessmentId: assessmentId)
            scoreHistory = try await service.fetchScoreHistory(assessmentId: assessmentId)

            if let latest = scoreHistory.last {
                latestScore = latest.score
                latestDate = latest.date
            }
        } catch {
            self.error = error
            print("[AssessmentScreen] Error loading: \(error)")
        }
    }

    func saveResult(score: Int, responses: [String: Int]) async {
        do {
            try await service.saveAssessmentResult(
                assessmentId: assessmentId,
                score: score,
                responses: responses
            )

            // Update local state
            latestScore = score
            latestDate = Date()

            let tier = assessmentData?.tier(for: score)
            scoreHistory.append(AssessmentResult(
                id: UUID(),  // Temporary ID for local display
                date: Date(),
                score: score,
                tierName: tier?.tierName,
                tierColor: tier?.color,
                responses: responses
            ))
        } catch {
            print("[AssessmentScreen] Error saving result: \(error)")
        }
    }
}

// MARK: - Assessment Data Management View

struct AssessmentDataManagementView: View {
    let assessmentId: String
    let assessmentName: String
    let color: Color

    @Environment(\.dismiss) private var dismiss
    @State private var results: [AssessmentResult] = []
    @State private var assessmentData: AssessmentData?
    @State private var isLoading = true
    @State private var showDeleteAlert = false
    @State private var resultToDelete: AssessmentResult?
    @State private var selectedResult: AssessmentResult?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if results.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clipboard")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No assessment history")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Complete an assessment to see your history here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(results.reversed()) { result in
                            Button {
                                selectedResult = result
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.date.formatted(date: .long, time: .shortened))
                                            .font(.subheadline)
                                        if let tierName = result.tierName {
                                            Text(tierName)
                                                .font(.caption)
                                                .foregroundColor(result.tierColor ?? .secondary)
                                        }
                                    }

                                    Spacer()

                                    Text("\(result.score)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(result.tierColor ?? color)

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 4)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    resultToDelete = result
                                    showDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("\(assessmentName) History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Entry", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    resultToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let result = resultToDelete {
                        deleteResult(result)
                    }
                }
            } message: {
                if let result = resultToDelete {
                    Text("Delete the assessment from \(result.date.formatted(date: .abbreviated, time: .shortened))? This cannot be undone.")
                }
            }
            .sheet(item: $selectedResult) { result in
                AssessmentResultDetailView(
                    result: result,
                    assessmentData: assessmentData,
                    color: color
                )
            }
            .task {
                await loadResults()
            }
        }
    }

    private func loadResults() async {
        do {
            assessmentData = try await AssessmentService.shared.fetchAssessmentData(assessmentId: assessmentId)
            results = try await AssessmentService.shared.fetchScoreHistory(assessmentId: assessmentId, limit: 100)
        } catch {
            print("Error loading history: \(error)")
        }
        isLoading = false
    }

    private func deleteResult(_ result: AssessmentResult) {
        Task {
            do {
                try await AssessmentService.shared.deleteAssessmentResult(resultId: result.id)
                // Remove from local array
                results.removeAll { $0.id == result.id }
            } catch {
                print("Error deleting result: \(error)")
            }
            resultToDelete = nil
        }
    }
}

// MARK: - Assessment Result Detail View

struct AssessmentResultDetailView: View {
    let result: AssessmentResult
    let assessmentData: AssessmentData?
    let color: Color

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Score header
                    scoreHeader

                    // Response breakdown
                    if let responses = result.responses, !responses.isEmpty {
                        responseSection(responses)
                    } else {
                        Text("No response details available")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Response Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var scoreHeader: some View {
        VStack(spacing: 12) {
            // Score circle
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 80, height: 80)

                VStack(spacing: 2) {
                    Text("\(result.score)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(color)

                    if let max = assessmentData?.assessment.scoreMax {
                        Text("/ \(max)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Tier name
            if let tierName = result.tierName {
                Text(tierName)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(result.tierColor ?? color)
            }

            // Date
            Text(result.date.formatted(date: .long, time: .shortened))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func responseSection(_ responses: [String: Int]) -> some View {
        let questions = assessmentData?.questions ?? []
        let isMultiSelect = questions.first?.responseType == "multi_select_weighted"

        VStack(alignment: .leading, spacing: 16) {
            Text(isMultiSelect ? "Selected Items" : "Responses")
                .font(.headline)
                .padding(.horizontal, 4)

            if isMultiSelect {
                // Multi-select: show checked items grouped by weight
                multiSelectResponseView(responses)
            } else {
                // Standard: show question -> answer pairs
                standardResponseView(responses, questions: questions)
            }
        }
    }

    /// Decode bitmask to find selected options for multi-select responses
    private func decodeSelectedOptions(from responses: [String: Int], using data: AssessmentData) -> [ViewAssessmentResponseOption] {
        var selectedOptions: [ViewAssessmentResponseOption] = []

        for question in data.questions {
            guard let bitmask = responses[question.questionId] else { continue }
            let options = data.options(for: question.questionId)

            for option in options {
                // Check if this option's bit is set in the bitmask
                // displayOrder 1 → bit 0, displayOrder 2 → bit 1, etc.
                let bitPosition = option.displayOrder - 1
                if bitPosition >= 0 && (bitmask & (1 << bitPosition)) != 0 {
                    selectedOptions.append(option)
                }
            }
        }

        return selectedOptions
    }

    @ViewBuilder
    private func multiSelectResponseView(_ responses: [String: Int]) -> some View {
        if let data = assessmentData {
            let selectedOptions = decodeSelectedOptions(from: responses, using: data)
            let highImpact = selectedOptions.filter { $0.optionValue == 3 }
            let mediumImpact = selectedOptions.filter { $0.optionValue == 2 }
            let lowerImpact = selectedOptions.filter { $0.optionValue == 1 }

            VStack(spacing: 16) {
                if !highImpact.isEmpty {
                    impactSection(title: "High Impact", options: highImpact, pointsEach: 3)
                }
                if !mediumImpact.isEmpty {
                    impactSection(title: "Medium Impact", options: mediumImpact, pointsEach: 2)
                }
                if !lowerImpact.isEmpty {
                    impactSection(title: "Lower Impact", options: lowerImpact, pointsEach: 1)
                }

                if selectedOptions.isEmpty {
                    Text("No items were selected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
            }
        } else {
            EmptyView()
        }
    }

    private func impactSection(title: String, options: [ViewAssessmentResponseOption], pointsEach: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(options.count * pointsEach) pts")
                    .font(.caption)
                    .foregroundColor(color)
            }

            VStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(color)
                            .font(.system(size: 16))

                        Text(option.optionText)
                            .font(.subheadline)

                        Spacer()

                        Text("+\(pointsEach)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                    if index < options.count - 1 {
                        Divider()
                            .padding(.leading, 40)
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(10)
        }
    }

    @ViewBuilder
    private func standardResponseView(_ responses: [String: Int], questions: [ViewAssessmentQuestion]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(questions.enumerated()), id: \.element.id) { index, question in
                if let selectedValue = responses[question.questionId] {
                    let options = assessmentData?.options(for: question.questionId) ?? []
                    let selectedOption = options.first { $0.optionValue == selectedValue }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(question.questionText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(selectedOption?.optionText ?? "Value: \(selectedValue)")
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)

                    if index < questions.count - 1 {
                        Divider()
                            .padding(.horizontal, 12)
                    }
                }
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(10)
    }
}

// MARK: - Assessment Card Component

struct AssessmentCard: View {
    let assessmentId: String
    let color: Color
    let pillar: String
    let sectionId: String
    let viewId: String

    @StateObject private var viewModel = AssessmentCardViewModel()

    init(assessmentId: String, color: Color, pillar: String, sectionId: String, viewId: String? = nil) {
        self.assessmentId = assessmentId
        self.color = color
        self.pillar = pillar
        self.sectionId = sectionId
        self.viewId = viewId ?? "DISP_\(assessmentId.replacingOccurrences(of: "ASSESS_", with: "").uppercased())"
    }

    var body: some View {
        MetricCardView(
            title: viewModel.assessment?.assessmentName ?? "Assessment",
            color: color,
            metricId: viewId,
            pillar: pillar,
            cardId: assessmentId,
            sectionId: sectionId
        ) {
            // Mini card content
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: viewModel.assessment?.icon ?? "clipboard")
                        .font(.title3)
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if viewModel.isLoading {
                        ProgressView().scaleEffect(0.8)
                    } else if let score = viewModel.latestScore {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(score)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(viewModel.interpretation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if let date = viewModel.latestDate {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Not yet taken")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
        } fullScreen: {
            AssessmentScreenTemplate(assessmentId: assessmentId, color: color, viewId: viewId, sectionId: sectionId)
        }
        .task {
            await viewModel.load(assessmentId: assessmentId)
        }
    }
}

// MARK: - Assessment Card ViewModel

@MainActor
class AssessmentCardViewModel: ObservableObject {
    @Published var assessment: ViewAssessment?
    @Published var latestScore: Int?
    @Published var latestDate: Date?
    @Published var isLoading = false

    private let service = AssessmentService.shared

    var interpretation: String {
        guard let score = latestScore, let assessment = assessment else { return "" }
        let range = assessment.scoreMax - assessment.scoreMin
        guard range > 0 else { return "" }
        let position = Double(score - assessment.scoreMin) / Double(range)
        if position < 0.33 { return "Low" }
        if position < 0.66 { return "Moderate" }
        return "High"
    }

    func load(assessmentId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let assessments = try await service.fetchAssessmentsAll()
            assessment = assessments.first { $0.assessmentId == assessmentId }

            if let result = try? await service.fetchLatestScore(assessmentId: assessmentId) {
                latestScore = result.score
                latestDate = result.date
            }
        } catch {
            print("Error loading assessment card: \(error)")
        }
    }
}

// MARK: - Specific Assessment Cards

struct WellBeingCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        AssessmentCard(
            assessmentId: "ASSESS_SWLS",
            color: color,
            pillar: pillar,
            sectionId: "NAV_MENTAL_HEALTH",
            viewId: "DISP_WELLBEING"
        )
    }
}

struct AnxietyCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        AssessmentCard(
            assessmentId: "ASSESS_GAD2",
            color: color,
            pillar: pillar,
            sectionId: "NAV_MENTAL_HEALTH",
            viewId: "DISP_ANXIETY"
        )
    }
}

struct DepressionCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        AssessmentCard(
            assessmentId: "ASSESS_PHQ2",
            color: color,
            pillar: pillar,
            sectionId: "NAV_MENTAL_HEALTH",
            viewId: "DISP_DEPRESSION"
        )
    }
}

struct StressCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        AssessmentCard(
            assessmentId: "ASSESS_PSS10",
            color: color,
            pillar: pillar,
            sectionId: "NAV_STRESS",
            viewId: "DISP_STRESS"
        )
    }
}

// MARK: - Assessment Chart Data Point

struct AssessmentChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let score: Int  // For single entry or average
    let minScore: Int  // Min score in period (for range bars)
    let maxScore: Int  // Max score in period (for range bars)
    let entryCount: Int  // Number of entries in this period
    let tierColor: Color?

    /// Whether this point has a range (multiple entries with different scores)
    var hasRange: Bool { minScore != maxScore && entryCount > 1 }

    /// For backward compatibility - single score point
    init(date: Date, score: Int, tierColor: Color?) {
        self.date = date
        self.score = score
        self.minScore = score
        self.maxScore = score
        self.entryCount = score > 0 ? 1 : 0
        self.tierColor = tierColor
    }

    /// Full initializer with range support
    init(date: Date, score: Int, minScore: Int, maxScore: Int, entryCount: Int, tierColor: Color?) {
        self.date = date
        self.score = score
        self.minScore = minScore
        self.maxScore = maxScore
        self.entryCount = entryCount
        self.tierColor = tierColor
    }
}

// MARK: - Assessment Chart Scroll Manager

@MainActor
class AssessmentChartScrollManager: ObservableObject {
    @Published var chartData: [AssessmentChartPoint] = []
    @Published var isLoading = false
    @Published var isLoadingOlder = false
    @Published var isLoadingNewer = false

    private var oldestDate: Date
    private var newestDate: Date
    private var selectedPeriod: AssessmentScreenTemplate.AssessmentPeriod
    private let assessmentId: String
    private let supabase = SupabaseManager.shared.client

    init(assessmentId: String, period: AssessmentScreenTemplate.AssessmentPeriod) {
        self.assessmentId = assessmentId
        self.selectedPeriod = period

        let now = Date()
        self.newestDate = Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now

        switch period {
        case .week:
            self.oldestDate = Calendar.current.date(byAdding: .weekOfYear, value: -12, to: now) ?? now
        case .month:
            self.oldestDate = Calendar.current.date(byAdding: .month, value: -12, to: now) ?? now
        case .sixMonth:
            self.oldestDate = Calendar.current.date(byAdding: .month, value: -24, to: now) ?? now
        case .year:
            self.oldestDate = Calendar.current.date(byAdding: .year, value: -5, to: now) ?? now
        }

        Task {
            await loadInitialData()
        }
    }

    func updatePeriod(_ period: AssessmentScreenTemplate.AssessmentPeriod) {
        self.selectedPeriod = period

        let now = Date()
        self.newestDate = Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now

        switch period {
        case .week:
            self.oldestDate = Calendar.current.date(byAdding: .weekOfYear, value: -12, to: now) ?? now
        case .month:
            self.oldestDate = Calendar.current.date(byAdding: .month, value: -12, to: now) ?? now
        case .sixMonth:
            self.oldestDate = Calendar.current.date(byAdding: .month, value: -24, to: now) ?? now
        case .year:
            self.oldestDate = Calendar.current.date(byAdding: .year, value: -5, to: now) ?? now
        }

        chartData.removeAll()
        Task {
            await loadInitialData()
        }
    }

    func loadOlderData() {
        guard !isLoadingOlder else { return }
        isLoadingOlder = true

        Task {
            let calendar = Calendar.current
            let component = selectedPeriod.calendarComponent
            let loadAmount = -selectedPeriod.loadChunkSize

            let tenYearsAgo = calendar.date(byAdding: .year, value: -10, to: Date()) ?? Date()
            guard oldestDate > tenYearsAgo else {
                isLoadingOlder = false
                return
            }

            let newOldestDate = calendar.date(byAdding: component, value: loadAmount, to: oldestDate) ?? oldestDate
            let cappedOldestDate = max(newOldestDate, tenYearsAgo)

            await loadDataRange(from: cappedOldestDate, to: oldestDate)
            oldestDate = cappedOldestDate
            isLoadingOlder = false
        }
    }

    func loadNewerData() {
        guard !isLoadingNewer else { return }
        isLoadingNewer = true

        Task {
            let calendar = Calendar.current
            let component = selectedPeriod.calendarComponent
            let loadAmount = selectedPeriod.loadChunkSize

            let newNewestDate = calendar.date(byAdding: component, value: loadAmount, to: newestDate) ?? newestDate

            await loadDataRange(from: newestDate, to: newNewestDate)
            newestDate = newNewestDate
            isLoadingNewer = false
        }
    }

    private func loadInitialData() async {
        isLoading = true
        await loadDataRange(from: oldestDate, to: newestDate)
        isLoading = false
    }

    private func loadDataRange(from startDate: Date, to endDate: Date) async {
        // Generate empty timeline
        var timeline = generateEmptyTimeline(from: startDate, to: endDate)

        // Fetch data from database
        let dataPoints = await fetchDataPoints(from: startDate, to: endDate)

        // Overlay actual data on timeline
        for dataPoint in dataPoints {
            if let index = timeline.firstIndex(where: {
                Calendar.current.isDate($0.date, equalTo: dataPoint.date, toGranularity: selectedPeriod.calendarComponent)
            }) {
                timeline[index] = dataPoint
            }
        }

        // Merge with existing data
        await MainActor.run {
            let existingDates = Set(chartData.map { $0.date })
            let newPoints = timeline.filter { !existingDates.contains($0.date) }
            chartData.append(contentsOf: newPoints)
            chartData.sort { $0.date > $1.date }
        }
    }

    private func generateEmptyTimeline(from startDate: Date, to endDate: Date) -> [AssessmentChartPoint] {
        var timeline: [AssessmentChartPoint] = []
        var currentDate = startDate
        let calendar = Calendar.current
        let component = selectedPeriod.calendarComponent

        while currentDate <= endDate {
            timeline.append(AssessmentChartPoint(
                date: currentDate,
                score: 0,
                minScore: 0,
                maxScore: 0,
                entryCount: 0,
                tierColor: nil
            ))
            currentDate = calendar.date(byAdding: component, value: 1, to: currentDate) ?? endDate
        }

        return timeline
    }

    private func fetchDataPoints(from startDate: Date, to endDate: Date) async -> [AssessmentChartPoint] {
        do {
            let patientId = try await supabase.auth.session.user.id
            let quantityType = "assessment_\(assessmentId.lowercased())_score"

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            struct SampleResult: Codable {
                let quantityValue: Double?
                let startTime: Date

                enum CodingKeys: String, CodingKey {
                    case quantityValue = "quantity_value"
                    case startTime = "start_time"
                }
            }

            let results: [SampleResult] = try await supabase
                .from("patient_quantity_samples")
                .select("quantity_value, start_time")
                .eq("patient_id", value: patientId)
                .eq("quantity_type", value: quantityType)
                .gte("start_time", value: formatter.string(from: startDate))
                .lte("start_time", value: formatter.string(from: endDate))
                .order("start_time", ascending: false)
                .execute()
                .value

            // Get tiers for color mapping
            let assessmentData = try? await AssessmentService.shared.fetchAssessmentData(assessmentId: assessmentId)
            let calendar = Calendar.current

            // Group results by period for aggregation
            struct PeriodAggregate {
                var scores: [Int] = []
                var date: Date
            }

            var groupedByPeriod: [Date: PeriodAggregate] = [:]

            for sample in results {
                guard let value = sample.quantityValue else { continue }
                let score = Int(value)
                let periodKey = getPeriodKey(for: sample.startTime, calendar: calendar)

                if groupedByPeriod[periodKey] == nil {
                    groupedByPeriod[periodKey] = PeriodAggregate(date: periodKey)
                }
                groupedByPeriod[periodKey]?.scores.append(score)
            }

            // Convert to AssessmentChartPoint with min/max ranges
            return groupedByPeriod.compactMap { _, aggregate in
                guard !aggregate.scores.isEmpty else { return nil }

                let minScore = aggregate.scores.min() ?? 0
                let maxScore = aggregate.scores.max() ?? 0
                let avgScore = aggregate.scores.reduce(0, +) / aggregate.scores.count
                let entryCount = aggregate.scores.count

                // Use max score tier color for the point
                let tier = assessmentData?.tier(for: avgScore)

                return AssessmentChartPoint(
                    date: aggregate.date,
                    score: avgScore,
                    minScore: minScore,
                    maxScore: maxScore,
                    entryCount: entryCount,
                    tierColor: tier?.color
                )
            }

        } catch {
            print("❌ Error fetching assessment chart data: \(error)")
            return []
        }
    }

    /// Get the period key (start date of period) for a given reading time
    private func getPeriodKey(for date: Date, calendar: Calendar) -> Date {
        switch selectedPeriod {
        case .week, .month:
            // Group by day
            return calendar.startOfDay(for: date)
        case .sixMonth:
            // Group by week (start of week)
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return calendar.date(from: components) ?? date
        case .year:
            // Group by month
            let components = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: components) ?? date
        }
    }
}

// MARK: - Previews

#Preview("Assessment Screen") {
    NavigationStack {
        AssessmentScreenTemplate(assessmentId: "ASSESS_SWLS", color: .purple, sectionId: "NAV_MENTAL_HEALTH")
    }
}

#Preview("Assessment Card") {
    WellBeingCard(color: .purple, pillar: "Mental Health")
        .padding()
}
