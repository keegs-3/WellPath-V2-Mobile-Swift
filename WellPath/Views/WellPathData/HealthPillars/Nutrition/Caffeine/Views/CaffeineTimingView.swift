//
//  CaffeineTimingView.swift
//  WellPath
//
//  Full view for Caffeine Timing metric (DISP_CAFFEINE_TIMING).
//  Shows caffeine distribution throughout the day with 24-hour clock visualization.
//  Caffeine timing focuses on consuming caffeine earlier in the day to protect sleep.
//

import SwiftUI
import Supabase

/// Time window for caffeine intake categorization
/// Designed to encourage morning caffeine and discourage afternoon/evening consumption
enum CaffeineTimeWindow: String, CaseIterable, Identifiable {
    case morning = "morning"
    case earlyAfternoon = "early_afternoon"
    case lateAfternoon = "late_afternoon"
    case evening = "evening"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .earlyAfternoon: return "Early Afternoon"
        case .lateAfternoon: return "Late Afternoon"
        case .evening: return "Evening"
        }
    }

    var description: String {
        switch self {
        case .morning: return "4 AM - 12 PM"
        case .earlyAfternoon: return "12 PM - 2 PM"
        case .lateAfternoon: return "2 PM - 6 PM"
        case .evening: return "6 PM - 4 AM"
        }
    }

    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .earlyAfternoon: return "sun.max.fill"
        case .lateAfternoon: return "sun.haze.fill"
        case .evening: return "moon.fill"
        }
    }

    /// Target percentage for optimal caffeine timing
    /// 90% in morning encourages early consumption, 0% in late afternoon/evening protects sleep
    var targetPercentage: Double {
        switch self {
        case .morning: return 90
        case .earlyAfternoon: return 10
        case .lateAfternoon: return 0
        case .evening: return 0
        }
    }

    /// Start hour for this window (24-hour)
    var startHour: Int {
        switch self {
        case .morning: return 4
        case .earlyAfternoon: return 12
        case .lateAfternoon: return 14
        case .evening: return 18
        }
    }

    /// End hour for this window (24-hour, exclusive)
    var endHour: Int {
        switch self {
        case .morning: return 12
        case .earlyAfternoon: return 14
        case .lateAfternoon: return 18
        case .evening: return 4  // wraps around
        }
    }

    /// Determines time window from hour of day
    static func from(hour: Int) -> CaffeineTimeWindow {
        switch hour {
        case 4..<12: return .morning
        case 12..<14: return .earlyAfternoon
        case 14..<18: return .lateAfternoon
        default: return .evening  // 18-24 and 0-4
        }
    }
}

/// Individual caffeine entry for display in expanded cards
struct CaffeineEntry: Identifiable {
    let id: UUID
    let time: Date
    let amount: Double  // in mg
    let source: String?
}

/// ViewModel for caffeine timing analysis
@MainActor
class CaffeineTimingViewModel: ObservableObject {
    @Published var timingData: [CaffeineTimeWindow: Double] = [:]
    @Published var hourlyData: [Int: Double] = [:]
    @Published var entriesByWindow: [CaffeineTimeWindow: [CaffeineEntry]] = [:]
    @Published var totalIntake: Double = 0
    @Published var daysWithData: Int = 1
    @Published var isLoading = false
    @Published var hasData = false
    @Published var timingScore: Int?

    var dailyAverage: Double {
        guard daysWithData > 0 else { return totalIntake }
        return totalIntake / Double(daysWithData)
    }

    var displayTimingScore: Int {
        timingScore ?? calculateTimingScore()
    }

    private let supabase = SupabaseManager.shared.client
    let baseColor: Color

    init(color: Color) {
        self.baseColor = color
    }

    func loadDataForPeriod(period: TimePeriod, date: Date) async {
        isLoading = true

        do {
            let userId = try await supabase.auth.session.user.id

            let calendar = Calendar.current
            let (startDate, endDate) = getDateRange(for: period, date: date)

            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let startStr = dateFormatter.string(from: startDate)
            let endStr = dateFormatter.string(from: endDate)

            struct CaffeineSample: Codable {
                let id: String
                let startTime: String
                let canonicalValue: Double?
                let metadata: [String: String]?

                enum CodingKeys: String, CodingKey {
                    case id
                    case startTime = "start_time"
                    case canonicalValue = "canonical_value"
                    case metadata
                }
            }

            let patientId = userId.uuidString.lowercased()

            let samples: [CaffeineSample] = try await supabase
                .from("patient_quantity_samples")
                .select("id, start_time, canonical_value, metadata")
                .eq("patient_id", value: patientId)
                .eq("quantity_type", value: "caffeine_mg")
                .gte("start_time", value: startStr)
                .lte("start_time", value: endStr)
                .order("start_time", ascending: false)
                .execute()
                .value

            var windowTotals: [CaffeineTimeWindow: Double] = [:]
            var windowEntries: [CaffeineTimeWindow: [CaffeineEntry]] = [:]
            var hourTotals: [Int: Double] = [:]
            var uniqueDays: Set<String> = []

            for window in CaffeineTimeWindow.allCases {
                windowTotals[window] = 0
                windowEntries[window] = []
            }

            for sample in samples {
                guard let value = sample.canonicalValue, value > 0 else { continue }

                let sampleDate = parseTimestamp(sample.startTime)

                if let sampleDate = sampleDate {
                    let hour = calendar.component(.hour, from: sampleDate)
                    let window = CaffeineTimeWindow.from(hour: hour)
                    windowTotals[window, default: 0] += value
                    hourTotals[hour, default: 0] += value

                    let dayKey = calendar.startOfDay(for: sampleDate)
                    let dayFormatter = DateFormatter()
                    dayFormatter.dateFormat = "yyyy-MM-dd"
                    uniqueDays.insert(dayFormatter.string(from: dayKey))

                    let source = sample.metadata?["source"] ?? sample.metadata?["caffeine_source"]
                    let entry = CaffeineEntry(
                        id: UUID(uuidString: sample.id) ?? UUID(),
                        time: sampleDate,
                        amount: value,
                        source: source
                    )
                    windowEntries[window, default: []].append(entry)
                }
            }

            let total = windowTotals.values.reduce(0, +)
            let days = max(1, uniqueDays.count)

            // Load timing score for daily view
            var dbScore: Int? = nil
            if period == .day {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let dateStr = dateFormatter.string(from: date)

                struct ScoreResult: Codable {
                    let scoreValue: Double
                    enum CodingKeys: String, CodingKey {
                        case scoreValue = "score_value"
                    }
                }

                do {
                    let scoreResults: [ScoreResult] = try await supabase
                        .from("behavioral_scores")
                        .select("score_value")
                        .eq("patient_id", value: userId.uuidString)
                        .eq("score_type", value: "caffeine_timing_score")
                        .eq("score_date", value: dateStr)
                        .eq("score_context", value: "daily")
                        .limit(1)
                        .execute()
                        .value

                    if let result = scoreResults.first {
                        dbScore = Int(result.scoreValue.rounded())
                    }
                } catch {
                    print("[CaffeineTiming] Could not load timing score: \(error)")
                }
            }

            await MainActor.run {
                self.timingData = windowTotals
                self.hourlyData = hourTotals
                self.entriesByWindow = windowEntries
                self.totalIntake = total
                self.daysWithData = days
                self.hasData = total > 0
                self.timingScore = dbScore
                self.isLoading = false
            }

        } catch {
            print("Error loading caffeine timing: \(error)")
            await MainActor.run {
                self.isLoading = false
                self.hasData = false
            }
        }
    }

    private func parseTimestamp(_ timeString: String) -> Date? {
        var normalized = timeString.replacingOccurrences(of: "+00", with: "+0000")

        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSZ"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd HH:mm:ssZ"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }()
        ]

        for formatter in formatters {
            if let date = formatter.date(from: normalized) {
                return date
            }
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoTime = timeString.replacingOccurrences(of: " ", with: "T")
        if let date = isoFormatter.date(from: isoTime) {
            return date
        }

        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: isoTime) {
            return date
        }

        return nil
    }

    func percentage(for window: CaffeineTimeWindow) -> Double {
        guard totalIntake > 0 else { return 0 }
        return ((timingData[window] ?? 0) / totalIntake) * 100
    }

    func entries(for window: CaffeineTimeWindow) -> [CaffeineEntry] {
        entriesByWindow[window] ?? []
    }

    func windowColor(for window: CaffeineTimeWindow) -> Color {
        switch window {
        case .morning: return MetricsUIConfig.tierGood  // green - ideal time
        case .earlyAfternoon: return .yellow            // caution
        case .lateAfternoon: return .orange             // not recommended
        case .evening: return MetricsUIConfig.tierPoor  // red - avoid
        }
    }

    /// Calculate timing score based on distribution vs targets
    /// Caffeine after noon is penalized more heavily than water timing
    func calculateTimingScore() -> Int {
        guard totalIntake > 0 else { return 0 }

        var weightedDeviation: Double = 0
        let weights: [CaffeineTimeWindow: Double] = [
            .morning: 1.0,
            .earlyAfternoon: 1.5,
            .lateAfternoon: 2.0,
            .evening: 3.0
        ]

        for window in CaffeineTimeWindow.allCases {
            let actual = percentage(for: window)
            let target = window.targetPercentage
            let weight = weights[window] ?? 1.0

            // Only penalize for exceeding target in bad windows
            if target == 0 && actual > 0 {
                weightedDeviation += actual * weight
            } else {
                weightedDeviation += abs(actual - target)
            }
        }

        // Perfect distribution = 0 deviation = 100 score
        let maxDeviation: Double = 300.0  // Higher due to weights
        let score = max(0, 100 - (weightedDeviation / maxDeviation * 100))
        return Int(score.rounded())
    }

    private func getDateRange(for period: TimePeriod, date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        switch period {
        case .day:
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return (startOfDay, endOfDay)
        case .week:
            let weekday = calendar.component(.weekday, from: date)
            let daysToSubtract = weekday - calendar.firstWeekday
            let weekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: startOfDay)!
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
            return (weekStart, weekEnd)
        case .month:
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart)!
            return (monthStart, nextMonth)
        case .sixMonth:
            let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: startOfDay)!
            return (sixMonthsAgo, startOfDay)
        case .year:
            let yearStart = calendar.date(from: calendar.dateComponents([.year], from: date))!
            let nextYear = calendar.date(byAdding: .year, value: 1, to: yearStart)!
            return (yearStart, nextYear)
        }
    }
}

// MARK: - Caffeine Two-Ring Clock

struct CaffeineTwoRingClock: View {
    let hourlyData: [Int: Double]
    let color: Color
    let size: CGFloat
    let selectedWindow: CaffeineTimeWindow?
    let viewModel: CaffeineTimingViewModel

    private let outerRingWidth: CGFloat = 6
    private let innerRingWidth: CGFloat = 5
    private let ringGap: CGFloat = 6

    private var totalIntake: Double {
        hourlyData.values.reduce(0, +)
    }

    private var maxHourlyAmount: Double {
        hourlyData.values.max() ?? 1
    }

    var body: some View {
        ZStack {
            outerSectionsRing
            innerDataRing
            hourLabels
            centerContent
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var outerSectionsRing: some View {
        ForEach(CaffeineTimeWindow.allCases) { window in
            CaffeineSectionArcView(
                window: window,
                isSelected: selectedWindow == window,
                size: size,
                ringWidth: outerRingWidth,
                viewModel: viewModel
            )
        }
    }

    @ViewBuilder
    private var innerDataRing: some View {
        let innerRadius = (size - outerRingWidth * 2 - ringGap * 2 - innerRingWidth) / 2

        Circle()
            .stroke(Color.secondary.opacity(0.08), lineWidth: innerRingWidth)
            .frame(width: innerRadius * 2, height: innerRadius * 2)

        ForEach(0..<24, id: \.self) { hour in
            if (hourlyData[hour] ?? 0) > 0 {
                CaffeineHourDataArc(
                    hour: hour,
                    amount: hourlyData[hour] ?? 0,
                    maxAmount: maxHourlyAmount,
                    selectedWindow: selectedWindow,
                    size: size,
                    outerRingWidth: outerRingWidth,
                    innerRingWidth: innerRingWidth,
                    ringGap: ringGap,
                    viewModel: viewModel
                )
            }
        }
    }

    private var labelRadius: CGFloat {
        (size - outerRingWidth * 2 - ringGap * 2 - innerRingWidth * 2) / 2 - 32
    }

    private var clockCenter: CGFloat {
        size / 2
    }

    @ViewBuilder
    private var hourLabels: some View {
        let radius: CGFloat = labelRadius
        let center: CGFloat = clockCenter

        ZStack {
            hourLabel("12a", opacity: 0.4, x: center, y: center - radius)
            hourLabel("6a", opacity: 0.5, x: center + radius, y: center)
            hourLabel("12p", opacity: 0.5, x: center, y: center + radius)
            hourLabel("6p", opacity: 0.5, x: center - radius, y: center)
        }
    }

    @ViewBuilder
    private func hourLabel(_ text: String, opacity: Double, x: CGFloat, y: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.secondary.opacity(opacity))
            .position(x: x, y: y)
    }

    @ViewBuilder
    private var centerContent: some View {
        VStack(spacing: 2) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: size * 0.1))
                .foregroundColor(hourlyData.isEmpty ? color.opacity(0.3) : color)

            if totalIntake > 0 {
                Text(String(format: "%.0f mg", totalIntake))
                    .font(.system(size: size * 0.07, weight: .bold))
                    .foregroundColor(.primary)
                Text("total")
                    .font(.system(size: size * 0.04))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Caffeine Section Arc View

struct CaffeineSectionArcView: View {
    let window: CaffeineTimeWindow
    let isSelected: Bool
    let size: CGFloat
    let ringWidth: CGFloat
    let viewModel: CaffeineTimingViewModel

    private var degreesPerHour: Double { 360.0 / 24.0 }
    private let gapDegrees: Double = 2.0

    private var startAngle: Double {
        Double(window.startHour) * degreesPerHour - 90 + gapDegrees / 2
    }

    private var endAngle: Double {
        let end = window.endHour
        if window == .evening {
            return Double(4 + 24) * degreesPerHour - 90 - gapDegrees / 2
        }
        return Double(end) * degreesPerHour - 90 - gapDegrees / 2
    }

    private var sectionColor: Color {
        viewModel.windowColor(for: window)
    }

    var body: some View {
        let center = size / 2
        let radius = (size - ringWidth) / 2

        Path { path in
            path.addArc(
                center: CGPoint(x: center, y: center),
                radius: radius,
                startAngle: .degrees(startAngle),
                endAngle: .degrees(endAngle),
                clockwise: false
            )
        }
        .stroke(
            sectionColor.opacity(isSelected ? 0.9 : 0.25),
            style: StrokeStyle(lineWidth: ringWidth, lineCap: .butt)
        )
    }
}

// MARK: - Caffeine Hour Data Arc

struct CaffeineHourDataArc: View {
    let hour: Int
    let amount: Double
    let maxAmount: Double
    let selectedWindow: CaffeineTimeWindow?
    let size: CGFloat
    let outerRingWidth: CGFloat
    let innerRingWidth: CGFloat
    let ringGap: CGFloat
    let viewModel: CaffeineTimingViewModel

    private var intensity: Double { min(amount / max(maxAmount, 1), 1.0) }
    private var window: CaffeineTimeWindow { CaffeineTimeWindow.from(hour: hour) }
    private var isInSelectedWindow: Bool { selectedWindow == nil || selectedWindow == window }
    private var degreesPerHour: Double { 360.0 / 24.0 }
    private var startAngle: Double { Double(hour) * degreesPerHour - 90 }
    private var endAngle: Double { startAngle + degreesPerHour - 1.5 }

    private var arcColor: Color {
        let baseColor = viewModel.windowColor(for: window)
        let opacity = isInSelectedWindow ? (0.5 + intensity * 0.5) : 0.2
        return baseColor.opacity(opacity)
    }

    var body: some View {
        let center = size / 2
        let radius = (size - outerRingWidth * 2 - ringGap * 2 - innerRingWidth) / 2

        Path { path in
            path.addArc(
                center: CGPoint(x: center, y: center),
                radius: radius,
                startAngle: .degrees(startAngle),
                endAngle: .degrees(endAngle),
                clockwise: false
            )
        }
        .stroke(arcColor, style: StrokeStyle(lineWidth: innerRingWidth, lineCap: .round))
    }
}

// MARK: - Main View

struct CaffeineTimingView: View {
    let color: Color

    @State private var selectedPeriod: TimePeriod = .week
    @State private var currentDate: Date = Date()
    @State private var showAboutModal = false
    @State private var showScoringExplanation = false
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false
    @State private var selectedWindow: CaffeineTimeWindow?
    @State private var expandedWindow: CaffeineTimeWindow?
    @StateObject private var viewModel: CaffeineTimingViewModel

    private let metricId = "DISP_CAFFEINE_TIMING"
    private let metricName = "Caffeine Timing"

    init(color: Color) {
        self.color = color
        _viewModel = StateObject(wrappedValue: CaffeineTimingViewModel(color: color))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                } else {
                    mainContent
                }
            }
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Caffeine Timing")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingEntryForm) {
            CaffeineEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            NutritionDataManagementView(color: color, initialCategory: .caffeine)
        }
        .sheet(isPresented: $showScoringExplanation) {
            scoringExplanationModal
        }
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(viewId: metricId, metricName: metricName, color: color, isPresented: $showAboutModal)
        }
        .task {
            await viewModel.loadDataForPeriod(period: selectedPeriod, date: currentDate)
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            periodSelectorSection
            periodNavigationSection
            clockCardSection
            timeWindowsSection
        }
    }

    @ViewBuilder
    private var periodSelectorSection: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach([TimePeriod.day, .week, .month, .year], id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.top, 16)
        .onChange(of: selectedPeriod) { _, newPeriod in
            Task {
                await viewModel.loadDataForPeriod(period: newPeriod, date: currentDate)
            }
        }
    }

    @ViewBuilder
    private var periodNavigationSection: some View {
        HStack {
            PeriodNavigationView(
                selectedPeriod: selectedPeriod,
                currentDate: $currentDate
            )
            .onChange(of: currentDate) { _, newDate in
                Task {
                    await viewModel.loadDataForPeriod(period: selectedPeriod, date: newDate)
                }
            }

            Spacer()

            Button(action: { showAboutModal = true }) {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundColor(color)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var clockCardSection: some View {
        VStack(spacing: 0) {
            clockCardHeader
            clockCardContent
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(WellPathColors.cardBackground)
        )
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var clockCardHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 6) {
                Text("Timing Score")
                    .font(.headline)
                    .foregroundColor(.primary)

                Button(action: { showScoringExplanation = true }) {
                    Image(systemName: "info.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(color)
                }
            }

            Spacer()

            CompactScoreRing(
                score: Double(viewModel.displayTimingScore),
                hasData: viewModel.hasData
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(WellPathColors.cardBackground.opacity(0.5))

        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(height: 1)
            .padding(.horizontal, 16)

        HStack(alignment: .top, spacing: 12) {
            Text("Hourly Distribution")
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(selectedPeriod == .day ? "Total" : "Daily Avg")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(formatTotalIntake())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var clockCardContent: some View {
        if viewModel.hasData {
            CaffeineTwoRingClock(
                hourlyData: viewModel.hourlyData,
                color: color,
                size: 240,
                selectedWindow: selectedWindow,
                viewModel: viewModel
            )
            .padding(.vertical, 8)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedWindow = nil
                    expandedWindow = nil
                }
            }

            Text("Tap a time window below to highlight")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 12)
        } else {
            clockEmptyState
        }
    }

    @ViewBuilder
    private var clockEmptyState: some View {
        VStack(spacing: 8) {
            CaffeineTwoRingClock(
                hourlyData: [:],
                color: color,
                size: 200,
                selectedWindow: nil,
                viewModel: viewModel
            )
            .opacity(0.5)

            Text("No caffeine logged yet")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var timeWindowsSection: some View {
        VStack(spacing: 8) {
            ForEach(CaffeineTimeWindow.allCases) { window in
                CaffeineExpandableTimeWindowCard(
                    window: window,
                    viewModel: viewModel,
                    color: color,
                    selectedWindow: $selectedWindow,
                    expandedWindow: $expandedWindow
                )
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button { showingDataManagement = true } label: {
                Image(systemName: "list.bullet")
            }
        }

        ToolbarItemGroup(placement: .navigationBarTrailing) {
            FavoriteButton(
                itemType: .metric,
                itemId: "DISP_CAFFEINE_TIMING",
                displayName: "Caffeine Timing",
                pillar: "Healthful Nutrition",
                cardId: "CARD_CAFFEINE_TIMING",
                sectionId: "NAV_NUTRITION"
            )

            Button { showingEntryForm = true } label: {
                Image(systemName: "plus")
            }
        }
    }

    private var scoringExplanationModal: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "function")
                                .foregroundColor(color)
                                .font(.title3)
                            Text("How It's Calculated")
                                .font(.headline)
                        }

                        Text("Your caffeine timing score measures how early in the day you consume caffeine. Caffeine has a half-life of 5-6 hours, so consuming it earlier protects your sleep quality.")
                            .font(.body)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            scoreRangeRow(range: "All before noon", score: "90-100", color: MetricsUIConfig.tierGood)
                            scoreRangeRow(range: "Mostly before 2pm", score: "70-90", color: .yellow)
                            scoreRangeRow(range: "Some after 2pm", score: "40-70", color: .orange)
                            scoreRangeRow(range: "Caffeine after 6pm", score: "0-40", color: MetricsUIConfig.tierPoor)
                        }
                        .padding(.top, 8)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(WellPathColors.cardBackground)
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "clock.fill")
                                .foregroundColor(color)
                                .font(.title3)
                            Text("Ideal Distribution")
                                .font(.headline)
                        }

                        windowExplanationRow(
                            window: .morning,
                            description: "The ideal time for caffeine. Your body is naturally waking up and caffeine will clear before bedtime.",
                            color: color
                        )

                        windowExplanationRow(
                            window: .earlyAfternoon,
                            description: "Still acceptable, but getting close to the cutoff. Limit caffeine after noon when possible.",
                            color: color
                        )

                        windowExplanationRow(
                            window: .lateAfternoon,
                            description: "Not recommended. Caffeine consumed now will still be in your system at bedtime.",
                            color: color
                        )

                        windowExplanationRow(
                            window: .evening,
                            description: "Avoid caffeine entirely. Even 6 hours before bed can reduce sleep quality by 15-20%.",
                            color: color
                        )
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(WellPathColors.cardBackground)
                    )
                }
                .padding()
            }
            .background(WellPathColors.backgroundBase)
            .navigationTitle("Timing Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showScoringExplanation = false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func scoreRangeRow(range: String, score: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(range)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            Text("Score: \(score)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func windowExplanationRow(window: CaffeineTimeWindow, description: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: window.icon)
                .font(.title3)
                .foregroundColor(viewModel.windowColor(for: window))
                .frame(width: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(window.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("Target: \(Int(window.targetPercentage))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(WellPathColors.cardBackground.opacity(0.5))
        )
    }

    private func formatTotalIntake() -> String {
        let displayValue: Double
        if selectedPeriod == .day {
            displayValue = viewModel.totalIntake
        } else {
            displayValue = viewModel.dailyAverage
        }

        if displayValue == 0 {
            return "—"
        }
        return String(format: "%.0f mg", displayValue)
    }
}

// MARK: - Caffeine Expandable Time Window Card

struct CaffeineExpandableTimeWindowCard: View {
    let window: CaffeineTimeWindow
    @ObservedObject var viewModel: CaffeineTimingViewModel
    let color: Color
    @Binding var selectedWindow: CaffeineTimeWindow?
    @Binding var expandedWindow: CaffeineTimeWindow?

    private var isExpanded: Bool {
        expandedWindow == window
    }

    private var isSelected: Bool {
        selectedWindow == window
    }

    private var actual: Double {
        viewModel.percentage(for: window)
    }

    private var target: Double {
        window.targetPercentage
    }

    private var amount: Double {
        viewModel.timingData[window] ?? 0
    }

    private var entries: [CaffeineEntry] {
        viewModel.entries(for: window)
    }

    private var windowColor: Color {
        viewModel.windowColor(for: window)
    }

    private var progressColor: Color {
        // For morning, green if meeting target
        // For other windows, green if staying at/below target
        if window == .morning {
            let diff = target - actual
            if diff <= 10 { return MetricsUIConfig.tierGood }
            else if diff <= 30 { return .yellow }
            else { return .orange }
        } else {
            // For afternoon/evening windows, lower is better
            if actual <= 5 { return MetricsUIConfig.tierGood }
            else if actual <= 15 { return .yellow }
            else if actual <= 30 { return .orange }
            else { return MetricsUIConfig.tierPoor }
        }
    }

    private var statusText: String {
        if window == .morning {
            let diff = actual - target
            if abs(diff) <= 5 { return "On target" }
            else if diff > 0 { return "Above target" }
            else { return "Below target" }
        } else {
            // For afternoon/evening, we want 0%
            if actual == 0 { return "Perfect" }
            else if actual <= target + 5 { return "Acceptable" }
            else { return "Reduce intake" }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerButton
            if isExpanded {
                expandedContent
            }
        }
    }

    @ViewBuilder
    private var headerButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                if expandedWindow == window {
                    expandedWindow = nil
                } else {
                    expandedWindow = window
                }

                if selectedWindow == window {
                    selectedWindow = nil
                } else {
                    selectedWindow = window
                }
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(windowColor)
                        .frame(width: 12, height: 12)

                    Image(systemName: window.icon)
                        .font(.system(size: 18))
                        .foregroundColor(windowColor)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(window.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(window.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.0f%%", actual))
                            .font(.headline)
                            .foregroundColor(progressColor)
                        Text(String(format: "%.0f mg", amount))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                progressBar
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(WellPathColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? windowColor.opacity(0.5) : Color.clear, lineWidth: 2)
                )
        )
    }

    @ViewBuilder
    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(
                            width: geometry.size.width * min(actual / 100, 1.0),
                            height: 8
                        )

                    if target > 0 {
                        Rectangle()
                            .fill(windowColor)
                            .frame(width: 2, height: 14)
                            .position(
                                x: geometry.size.width * (target / 100),
                                y: 7
                            )
                    }
                }
            }
            .frame(height: 14)

            HStack {
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(progressColor)
                Spacer()
                Text("Target: \(Int(target))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(spacing: 8) {
            if !entries.isEmpty {
                Text("\(entries.count) logged entr\(entries.count == 1 ? "y" : "ies")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(entries) { entry in
                    entryRow(entry)
                }
            } else {
                Text("No caffeine logged in this time window")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(WellPathColors.cardBackground)
        )
        .padding(.top, 2)
    }

    @ViewBuilder
    private func entryRow(_ entry: CaffeineEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.caption)
                .foregroundColor(windowColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(formatTime(entry.time))
                    .font(.subheadline)
                    .foregroundColor(.primary)
                if let source = entry.source {
                    Text(source)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(String(format: "%.0f mg", entry.amount))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(WellPathColors.cardBackground.opacity(0.5))
        )
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        CaffeineTimingView(color: .brown)
    }
}
