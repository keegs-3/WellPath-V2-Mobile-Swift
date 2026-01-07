//
//  WaterTimingView.swift
//  WellPath
//
//  Full view for Water Timing metric (DISP_WATER_TIMING).
//  Shows hydration distribution throughout the day with 24-hour clock visualization.
//

import SwiftUI
import Supabase
import Charts

/// Time window for water intake categorization
enum WaterTimeWindow: String, CaseIterable, Identifiable {
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"
    case night = "night"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
        }
    }

    var description: String {
        switch self {
        case .morning: return "6 AM - 12 PM"
        case .afternoon: return "12 PM - 6 PM"
        case .evening: return "6 PM - 10 PM"
        case .night: return "10 PM - 6 AM"
        }
    }

    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .night: return "moon.fill"
        }
    }

    var targetPercentage: Double {
        switch self {
        case .morning: return 40
        case .afternoon: return 40
        case .evening: return 15
        case .night: return 5
        }
    }

    /// Start hour for this window (24-hour)
    var startHour: Int {
        switch self {
        case .morning: return 6
        case .afternoon: return 12
        case .evening: return 18
        case .night: return 22
        }
    }

    /// End hour for this window (24-hour, exclusive)
    var endHour: Int {
        switch self {
        case .morning: return 12
        case .afternoon: return 18
        case .evening: return 22
        case .night: return 6  // wraps around
        }
    }

    /// Determines time window from hour of day
    static func from(hour: Int) -> WaterTimeWindow {
        switch hour {
        case 6..<12: return .morning
        case 12..<18: return .afternoon
        case 18..<22: return .evening
        default: return .night  // 22-24 and 0-6
        }
    }
}

/// Individual water entry for display in expanded cards
struct WaterEntry: Identifiable {
    let id: UUID
    let time: Date
    let amount: Double  // in mL
}

/// ViewModel for water timing analysis
@MainActor
class WaterTimingViewModel: ObservableObject {
    @Published var timingData: [WaterTimeWindow: Double] = [:]
    @Published var hourlyData: [Int: Double] = [:]
    @Published var entriesByWindow: [WaterTimeWindow: [WaterEntry]] = [:]
    @Published var totalIntake: Double = 0
    @Published var daysWithData: Int = 1  // Number of unique days with water data
    @Published var isLoading = false
    @Published var hasData = false
    @Published var timingScore: Int?  // From behavioral_scores - authoritative score

    /// Daily average for week/month/etc. periods
    var dailyAverage: Double {
        guard daysWithData > 0 else { return totalIntake }
        return totalIntake / Double(daysWithData)
    }

    /// Get the timing score - use database value if available, fall back to calculated
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

            // Calculate date range based on period
            let calendar = Calendar.current
            let (startDate, endDate) = getDateRange(for: period, date: date)

            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let startStr = dateFormatter.string(from: startDate)
            let endStr = dateFormatter.string(from: endDate)

            struct WaterSample: Codable {
                let id: String
                let startTime: String
                let canonicalValue: Double?

                enum CodingKeys: String, CodingKey {
                    case id
                    case startTime = "start_time"
                    case canonicalValue = "canonical_value"
                }
            }

            let patientId = userId.uuidString.lowercased()
            print("[WaterTiming] Loading data for period \(period.rawValue), patient: \(patientId), dates: \(startStr) to \(endStr)")

            let samples: [WaterSample] = try await supabase
                .from("patient_quantity_samples")
                .select("id, start_time, canonical_value")
                .eq("patient_id", value: patientId)
                .eq("quantity_type", value: "water_ml")
                .gte("start_time", value: startStr)
                .lte("start_time", value: endStr)
                .order("start_time", ascending: false)
                .execute()
                .value

            print("[WaterTiming] Loaded \(samples.count) samples")

            // Group by time window, by hour, and collect individual entries
            var windowTotals: [WaterTimeWindow: Double] = [:]
            var windowEntries: [WaterTimeWindow: [WaterEntry]] = [:]
            var hourTotals: [Int: Double] = [:]
            var uniqueDays: Set<String> = []  // Track unique days for daily average calculation

            // Initialize all windows
            for window in WaterTimeWindow.allCases {
                windowTotals[window] = 0
                windowEntries[window] = []
            }

            // Parse timestamps - database returns formats like:
            // "2026-01-05 17:18:10.513+00" (with milliseconds)
            // "2026-01-06 06:03:00+00" (without milliseconds)
            func parseTimestamp(_ timeString: String) -> Date? {
                // Normalize timezone format: "+00" -> "+0000"
                var normalized = timeString.replacingOccurrences(of: "+00", with: "+0000")

                // Try multiple formats
                let formatters: [(DateFormatter, String)] = [
                    // With milliseconds
                    {
                        let f = DateFormatter()
                        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSZ"
                        f.locale = Locale(identifier: "en_US_POSIX")
                        return (f, "with ms")
                    }(),
                    // Without milliseconds
                    {
                        let f = DateFormatter()
                        f.dateFormat = "yyyy-MM-dd HH:mm:ssZ"
                        f.locale = Locale(identifier: "en_US_POSIX")
                        return (f, "no ms")
                    }(),
                    // ISO8601 with fractional seconds
                    {
                        let f = DateFormatter()
                        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                        f.locale = Locale(identifier: "en_US_POSIX")
                        return (f, "ISO with ms")
                    }(),
                    // ISO8601 without fractional seconds
                    {
                        let f = DateFormatter()
                        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                        f.locale = Locale(identifier: "en_US_POSIX")
                        return (f, "ISO no ms")
                    }()
                ]

                for (formatter, name) in formatters {
                    if let date = formatter.date(from: normalized) {
                        return date
                    }
                }

                // Try ISO8601DateFormatter as last resort
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let isoTime = timeString.replacingOccurrences(of: " ", with: "T")
                if let date = isoFormatter.date(from: isoTime) {
                    return date
                }

                // Try without fractional seconds
                isoFormatter.formatOptions = [.withInternetDateTime]
                if let date = isoFormatter.date(from: isoTime) {
                    return date
                }

                print("[WaterTiming] Failed to parse: '\(timeString)'")
                return nil
            }

            for sample in samples {
                guard let value = sample.canonicalValue, value > 0 else { continue }

                let sampleDate = parseTimestamp(sample.startTime)

                if let sampleDate = sampleDate {
                    let hour = calendar.component(.hour, from: sampleDate)
                    let window = WaterTimeWindow.from(hour: hour)
                    windowTotals[window, default: 0] += value
                    hourTotals[hour, default: 0] += value

                    // Track unique days for daily average
                    let dayKey = calendar.startOfDay(for: sampleDate)
                    let dayFormatter = DateFormatter()
                    dayFormatter.dateFormat = "yyyy-MM-dd"
                    uniqueDays.insert(dayFormatter.string(from: dayKey))

                    print("[WaterTiming] Parsed sample: hour=\(hour), window=\(window.rawValue), value=\(value)")

                    // Create entry for display
                    let entry = WaterEntry(
                        id: UUID(uuidString: sample.id) ?? UUID(),
                        time: sampleDate,
                        amount: value
                    )
                    windowEntries[window, default: []].append(entry)
                } else {
                    print("[WaterTiming] Failed to parse timestamp: '\(sample.startTime)'")
                }
            }

            let total = windowTotals.values.reduce(0, +)
            let days = max(1, uniqueDays.count)  // At least 1 day to avoid division by zero
            print("[WaterTiming] Total intake: \(total) mL, days: \(days), hasData: \(total > 0)")

            // Also load the timing score from behavioral_scores (for daily view)
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
                        .eq("score_type", value: "hydration_timing_score")
                        .eq("score_date", value: dateStr)
                        .eq("score_context", value: "daily")
                        .limit(1)
                        .execute()
                        .value

                    if let result = scoreResults.first {
                        dbScore = Int(result.scoreValue.rounded())
                        print("[WaterTiming] Loaded timing score from DB: \(dbScore ?? 0)")
                    }
                } catch {
                    print("[WaterTiming] Could not load timing score: \(error)")
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
            print("Error loading water timing: \(error)")
            await MainActor.run {
                self.isLoading = false
                self.hasData = false
            }
        }
    }

    func percentage(for window: WaterTimeWindow) -> Double {
        guard totalIntake > 0 else { return 0 }
        return ((timingData[window] ?? 0) / totalIntake) * 100
    }

    func entries(for window: WaterTimeWindow) -> [WaterEntry] {
        entriesByWindow[window] ?? []
    }

    func windowColor(for window: WaterTimeWindow) -> Color {
        switch window {
        case .morning: return .cyan
        case .afternoon: return .cyan
        case .evening: return MetricsUIConfig.tierMedium  // yellow
        case .night: return MetricsUIConfig.tierPoor      // red/orange
        }
    }

    /// Calculate timing score based on distribution vs targets
    func calculateTimingScore() -> Int {
        guard totalIntake > 0 else { return 0 }

        var totalDeviation: Double = 0
        for window in WaterTimeWindow.allCases {
            let actual = percentage(for: window)
            let target = window.targetPercentage
            totalDeviation += abs(actual - target)
        }

        // Perfect distribution = 0 deviation = 100 score
        // Max deviation (all in one window) = ~190 = 0 score
        let maxDeviation: Double = 190.0
        let score = max(0, 100 - (totalDeviation / maxDeviation * 100))
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

// MARK: - Two-Ring Clock (Sections + Data)

struct TwoRingClock: View {
    let hourlyData: [Int: Double]
    let color: Color
    let size: CGFloat
    let selectedWindow: WaterTimeWindow?
    let viewModel: WaterTimingViewModel
    @StateObject private var unitPrefs = UnitPreferencesViewModel()

    // Sleek thin pill-bar style rings
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
            // Outer ring: Time window sections
            outerSectionsRing

            // Inner ring: Actual hourly data
            innerDataRing

            // Hour labels
            hourLabels

            // Center content
            centerContent
        }
        .frame(width: size, height: size)
        .task {
            await unitPrefs.loadPreferences()
        }
    }

    // MARK: - Outer Sections Ring

    @ViewBuilder
    private var outerSectionsRing: some View {
        ForEach(WaterTimeWindow.allCases) { window in
            SectionArcView(
                window: window,
                isSelected: selectedWindow == window,
                size: size,
                ringWidth: outerRingWidth,
                viewModel: viewModel
            )
        }
    }

    // MARK: - Inner Data Ring

    @ViewBuilder
    private var innerDataRing: some View {
        let innerRadius = (size - outerRingWidth * 2 - ringGap * 2 - innerRingWidth) / 2

        // Background ring
        Circle()
            .stroke(Color.secondary.opacity(0.08), lineWidth: innerRingWidth)
            .frame(width: innerRadius * 2, height: innerRadius * 2)

        // Data segments
        ForEach(0..<24, id: \.self) { hour in
            if (hourlyData[hour] ?? 0) > 0 {
                HourDataArc(
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

    // MARK: - Hour Labels

    private var labelRadius: CGFloat {
        // Position labels well inside the data ring to avoid overlap
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

    // MARK: - Center Content

    @ViewBuilder
    private var centerContent: some View {
        VStack(spacing: 2) {
            Image(systemName: "drop.fill")
                .font(.system(size: size * 0.1))
                .foregroundColor(hourlyData.isEmpty ? color.opacity(0.3) : color)

            if totalIntake > 0 {
                Text(formatTotal())
                    .font(.system(size: size * 0.07, weight: .bold))
                    .foregroundColor(.primary)
                Text("total")
                    .font(.system(size: size * 0.04))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func formatTotal() -> String {
        let ml = totalIntake
        let unit = unitPrefs.liquidUnit
        let value = ml / unit.mlPerUnit
        if value >= 100 {
            return String(format: "%.0f %@", value, unit.shortLabel)
        } else if value >= 10 {
            return String(format: "%.1f %@", value, unit.shortLabel)
        } else {
            return String(format: "%.1f %@", value, unit.shortLabel)
        }
    }
}

// MARK: - Section Arc View (Outer Ring)

struct SectionArcView: View {
    let window: WaterTimeWindow
    let isSelected: Bool
    let size: CGFloat
    let ringWidth: CGFloat
    let viewModel: WaterTimingViewModel

    private var degreesPerHour: Double { 360.0 / 24.0 }

    private let gapDegrees: Double = 2.0  // Gap between segments

    private var startAngle: Double {
        Double(window.startHour) * degreesPerHour - 90 + gapDegrees / 2
    }

    private var endAngle: Double {
        let end = window.endHour
        if window == .night {
            // Night wraps: 22 -> 6 (through midnight)
            return Double(6 + 24) * degreesPerHour - 90 - gapDegrees / 2
        }
        return Double(end) * degreesPerHour - 90 - gapDegrees / 2
    }

    private var sectionColor: Color {
        viewModel.windowColor(for: window)
    }

    private var hasData: Bool {
        (viewModel.timingData[window] ?? 0) > 0
    }

    var body: some View {
        let center = size / 2
        let radius = (size - ringWidth) / 2

        // Sleek thin arc - brighter when selected, subtle when not
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

// MARK: - Hour Data Arc (Inner Ring)

struct HourDataArc: View {
    let hour: Int
    let amount: Double
    let maxAmount: Double
    let selectedWindow: WaterTimeWindow?
    let size: CGFloat
    let outerRingWidth: CGFloat
    let innerRingWidth: CGFloat
    let ringGap: CGFloat
    let viewModel: WaterTimingViewModel

    private var intensity: Double { min(amount / max(maxAmount, 1), 1.0) }
    private var window: WaterTimeWindow { WaterTimeWindow.from(hour: hour) }
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

struct WaterTimingView: View {
    let color: Color

    @State private var selectedPeriod: TimePeriod = .week
    @State private var currentDate: Date = Date()
    @State private var showAboutModal = false
    @State private var showScoringExplanation = false
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false
    @State private var selectedWindow: WaterTimeWindow?
    @State private var expandedWindow: WaterTimeWindow?
    @StateObject private var viewModel: WaterTimingViewModel
    @StateObject private var unitPrefs = UnitPreferencesViewModel()

    private let metricId = "DISP_WATER_TIMING"
    private let metricName = "Hydration Timing"

    init(color: Color) {
        self.color = color
        _viewModel = StateObject(wrappedValue: WaterTimingViewModel(color: color))
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
        .navigationTitle("Hydration Timing")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingEntryForm) {
            WaterEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            NutritionDataManagementView(color: color, initialCategory: .water)
        }
        .sheet(isPresented: $showScoringExplanation) {
            scoringExplanationModal
        }
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(viewId: metricId, metricName: metricName, color: color, isPresented: $showAboutModal)
        }
        .task {
            await unitPrefs.loadPreferences()
            await viewModel.loadDataForPeriod(period: selectedPeriod, date: currentDate)
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            periodSelectorSection
            periodNavigationSection
            clockCardSection
            timeWindowsSection
        }
        .background(Color(uiColor: .systemGroupedBackground))
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
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
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
        .background(Color(uiColor: .tertiarySystemGroupedBackground).opacity(0.3))

        Rectangle()
            .fill(Color(uiColor: .separator))
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
            TwoRingClock(
                hourlyData: viewModel.hourlyData,
                color: color,
                size: 240,
                selectedWindow: selectedWindow,
                viewModel: viewModel
            )
            .padding(.vertical, 8)
            .onTapGesture {
                // Tap clock to deselect
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
            TwoRingClock(
                hourlyData: [:],
                color: color,
                size: 200,
                selectedWindow: nil,
                viewModel: viewModel
            )
            .opacity(0.5)

            Text("No water logged yet")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var timeWindowsSection: some View {
        // Always show expandable cards - they handle 0 data gracefully
        VStack(spacing: 8) {
            ForEach(WaterTimeWindow.allCases) { window in
                ExpandableTimeWindowCard(
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

    // MARK: - Toolbar

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
                itemId: "DISP_WATER_TIMING",
                displayName: "Hydration Timing",
                pillar: "Healthful Nutrition",
                cardId: "CARD_WATER_TIMING",
                sectionId: "NAV_NUTRITION"
            )

            Button { showingEntryForm = true } label: {
                Image(systemName: "plus")
            }
        }
    }

    // MARK: - Scoring Explanation Modal

    private var scoringExplanationModal: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // How it's calculated
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "function")
                                .foregroundColor(color)
                                .font(.title3)
                            Text("How It's Calculated")
                                .font(.headline)
                        }

                        Text("Your timing score measures how evenly you distribute water intake throughout the day. Consistent hydration is better than drinking large amounts at once.")
                            .font(.body)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            scoreRangeRow(range: "Near-ideal distribution", score: "80-100", color: MetricsUIConfig.tierGood)
                            scoreRangeRow(range: "Good distribution", score: "60-80", color: .yellow)
                            scoreRangeRow(range: "Uneven distribution", score: "40-60", color: .orange)
                            scoreRangeRow(range: "Very uneven", score: "0-40", color: MetricsUIConfig.tierPoor)
                        }
                        .padding(.top, 8)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    )

                    // Time window targets
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
                            description: "Front-load hydration to rehydrate after sleep and support morning metabolism.",
                            color: color
                        )

                        windowExplanationRow(
                            window: .afternoon,
                            description: "Maintain steady intake through the productive hours of your day.",
                            color: color
                        )

                        windowExplanationRow(
                            window: .evening,
                            description: "Reduce intake before bed to minimize sleep disruption.",
                            color: color
                        )
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    )
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
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
    private func windowExplanationRow(window: WaterTimeWindow, description: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: window.icon)
                .font(.title3)
                .foregroundColor(color)
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
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
    }

    // MARK: - Helper Functions

    private func formatTotalIntake() -> String {
        // For day period, show total. For week/month/etc., show daily average
        let displayValue: Double
        if selectedPeriod == .day {
            displayValue = viewModel.totalIntake
        } else {
            displayValue = viewModel.dailyAverage
        }

        if displayValue == 0 {
            return "—"
        }
        let value = displayValue / unitPrefs.liquidUnit.mlPerUnit
        if value >= 10 {
            return String(format: "%.1f %@", value, unitPrefs.liquidUnit.shortLabel)
        } else {
            return String(format: "%.2f %@", value, unitPrefs.liquidUnit.shortLabel)
        }
    }
}

// MARK: - Expandable Time Window Card

struct ExpandableTimeWindowCard: View {
    let window: WaterTimeWindow
    @ObservedObject var viewModel: WaterTimingViewModel
    let color: Color
    @Binding var selectedWindow: WaterTimeWindow?
    @Binding var expandedWindow: WaterTimeWindow?
    @StateObject private var unitPrefs = UnitPreferencesViewModel()

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

    private var entries: [WaterEntry] {
        viewModel.entries(for: window)
    }

    private var windowColor: Color {
        viewModel.windowColor(for: window)
    }

    private var progressColor: Color {
        let diff = abs(actual - target)
        if diff <= 10 {
            return MetricsUIConfig.tierGood
        } else if diff <= 20 {
            return .yellow
        } else {
            return MetricsUIConfig.tierPoor
        }
    }

    private var statusText: String {
        let diff = actual - target
        if abs(diff) <= 5 {
            return "On target"
        } else if diff > 0 {
            return "Above target"
        } else {
            return "Below target"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerButton
            if isExpanded {
                expandedContent
            }
        }
        .task {
            await unitPrefs.loadPreferences()
        }
    }

    // MARK: - Header Button

    @ViewBuilder
    private var headerButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                // Toggle expansion
                if expandedWindow == window {
                    expandedWindow = nil
                } else {
                    expandedWindow = window
                }

                // Toggle selection (sync with clock)
                if selectedWindow == window {
                    selectedWindow = nil
                } else {
                    selectedWindow = window
                }
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    // Window color indicator
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
                        Text(formatAmount(amount))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Progress bar with target
                progressBar
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? windowColor.opacity(0.5) : Color.clear, lineWidth: 2)
                )
        )
    }

    // MARK: - Progress Bar

    @ViewBuilder
    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(
                            width: geometry.size.width * min(actual / 100, 1.0),
                            height: 8
                        )

                    // Target marker
                    Rectangle()
                        .fill(windowColor)
                        .frame(width: 2, height: 14)
                        .position(
                            x: geometry.size.width * (target / 100),
                            y: 7
                        )
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

    // MARK: - Expanded Content

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
                Text("No water logged in this time window")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .padding(.top, 2)
    }

    // MARK: - Entry Row

    @ViewBuilder
    private func entryRow(_ entry: WaterEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "drop.fill")
                .font(.caption)
                .foregroundColor(windowColor)

            Text(formatTime(entry.time))
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()

            Text(formatEntryAmount(entry.amount))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
    }

    // MARK: - Formatters

    private func formatAmount(_ ml: Double) -> String {
        let value = ml / unitPrefs.liquidUnit.mlPerUnit
        if value >= 100 {
            return String(format: "%.0f %@", value, unitPrefs.liquidUnit.shortLabel)
        } else if value >= 10 {
            return String(format: "%.1f %@", value, unitPrefs.liquidUnit.shortLabel)
        } else {
            return String(format: "%.1f %@", value, unitPrefs.liquidUnit.shortLabel)
        }
    }

    private func formatEntryAmount(_ ml: Double) -> String {
        let value = ml / unitPrefs.liquidUnit.mlPerUnit
        if value >= 10 {
            return String(format: "%.0f %@", value, unitPrefs.liquidUnit.shortLabel)
        } else {
            return String(format: "%.1f %@", value, unitPrefs.liquidUnit.shortLabel)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        WaterTimingView(color: .cyan)
    }
}
