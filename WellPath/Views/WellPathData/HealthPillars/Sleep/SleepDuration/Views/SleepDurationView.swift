//
//  SleepDurationView.swift
//  WellPath
//
//  Main view for Sleep Duration metric (DISP_SLEEP_DURATION).
//  Shows W/M/6M/Y bar chart (no D - sleep has no hourly tracking).
//

import SwiftUI
import Charts

struct SleepDurationView: View {
    let pillar: String
    let color: Color
    let sectionId: String

    @StateObject private var viewModel = SleepDurationChartViewModel()
    @State private var showingDataManagement = false
    @State private var showingEntryView = false
    @State private var showAboutModal = false
    @State private var selectedPeriod: TimePeriod = .week
    @State private var selectedBarDate: Date?
    @State private var scrollPosition: Date
    @State private var hasInitializedScroll = false  // Track if we've set initial scroll position

    private let metricId = "DISP_SLEEP_DURATION"
    private let metricName = "Sleep Duration"

    init(pillar: String, color: Color, sectionId: String) {
        self.pillar = pillar
        self.color = color
        self.sectionId = sectionId

        // Initialize scroll position correctly for default period (week)
        // Position so today is ~90% across the visible window
        // Align to bar centering (noon for daily bars in week view)
        let calendar = Calendar.current
        let now = Date()
        let defaultPeriod = TimePeriod.week

        // Week view: daily bars at noon
        let startOfDay = calendar.startOfDay(for: now)
        let todayBarDate = calendar.date(byAdding: .hour, value: 12, to: startOfDay) ?? now

        let visibleDuration = defaultPeriod.numberOfBars
        let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
        let initialScroll = calendar.date(
            byAdding: defaultPeriod.calendarComponent,
            value: -offsetFromEnd,
            to: todayBarDate
        ) ?? todayBarDate
        _scrollPosition = State(initialValue: initialScroll)
    }

    var body: some View {
        contentView
            .metricScreenBackground(color: color)
            .navigationTitle("Sleep Duration")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingDataManagement = true
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    FavoriteButton(
                        itemType: .screen,
                        itemId: "SCREEN_SLEEP_DURATION",
                        displayName: "Sleep Duration",
                        pillar: pillar,
                        cardId: "CARD_SLEEP_DURATION",
                        sectionId: sectionId
                    )

                    Button(action: {
                        showingEntryView = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEntryView) {
                SleepEntryView()
            }
            .sheet(isPresented: $showingDataManagement) {
                SleepDataManagementView(color: color)
            }
            .sheet(isPresented: $showAboutModal) {
                MetricEducationModal(
                    viewId: metricId,
                    metricName: metricName,
                    color: color,
                    isPresented: $showAboutModal
                )
            }
            .task {
                await viewModel.loadData(for: selectedPeriod)
                // Scroll position is set via .onAppear on the Chart with delay
            }
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 0) {
                chartContent
            }
            .padding(.vertical)
        }
    }

    private var chartContent: some View {
        VStack(spacing: 0) {
            // Period selector (no D - sleep has no hourly tracking)
            Picker("Period", selection: $selectedPeriod) {
                ForEach(TimePeriod.allCases.filter { $0 != .day }, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 16)
            .onChange(of: selectedPeriod) { _, newPeriod in
                selectedBarDate = nil
                // Reset scroll flag and set position with delay after chart re-renders
                hasInitializedScroll = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    initializeScrollPosition()
                    hasInitializedScroll = true
                }
                Task {
                    await viewModel.loadData(for: newPeriod)
                }
            }

            // Header with value display
            HStack(alignment: .top, spacing: 40) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedBarDate != nil ? selectedPeriod.barLabel : selectedPeriod.aggregateLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(formatDuration(getDisplayValue()))
                            .font(.system(size: 48, weight: .semibold))
                    }
                    Text(getDateLabel())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    withAnimation {
                        showAboutModal = true
                    }
                }) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(color)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 12)

            // Chart
            if viewModel.isLoading {
                ProgressView()
                    .frame(height: 280)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(viewModel.chartData) { dataPoint in
                    BarMark(
                        x: .value("Date", dataPoint.date, unit: selectedPeriod.calendarComponent),
                        y: .value("Hours", dataPoint.value / 60.0)  // Convert minutes to hours
                    )
                    .foregroundStyle(selectedBarDate == dataPoint.date ? color.opacity(0.6) : color)
                }
                .frame(height: 280)
                .chartScrollableAxes(.horizontal)
                .chartScrollPosition(x: $scrollPosition)
                .chartXVisibleDomain(length: getVisibleDomainTimeInterval())
                .chartGesture { proxy in
                    SpatialTapGesture()
                        .onEnded { value in
                            if let tappedDate: Date = proxy.value(atX: value.location.x) {
                                let closest = viewModel.chartData.min(by: {
                                    abs($0.date.timeIntervalSince(tappedDate)) < abs($1.date.timeIntervalSince(tappedDate))
                                })
                                if selectedBarDate == closest?.date {
                                    selectedBarDate = nil
                                } else {
                                    selectedBarDate = closest?.date
                                }
                            }
                        }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: getAxisStride(), count: 1)) { value in
                        if value.as(Date.self) != nil {
                            AxisValueLabel(format: getAxisFormat())
                            AxisGridLine()
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let hours = value.as(Double.self) {
                                Text("\(Int(hours))h")
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .onAppear {
                    // Only initialize scroll position if we haven't already
                    guard !hasInitializedScroll else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        initializeScrollPosition()
                        hasInitializedScroll = true
                    }
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: - Helpers

    private func initializeScrollPosition() {
        // Use simple pattern from ParentMetricBarChart:
        // Position scroll so today is ~90% across the visible window
        // IMPORTANT: Align scroll position to match bar centering for proper positioning
        let calendar = Calendar.current
        let now = Date()

        // First, find the bar date that represents "today" based on period
        let todayBarDate: Date
        switch selectedPeriod {
        case .year:
            // Year: bars at noon on 15th of month
            var components = calendar.dateComponents([.year, .month], from: now)
            components.day = 15
            components.hour = 12
            todayBarDate = calendar.date(from: components) ?? now
        case .sixMonth:
            // 6M: weekly bars at Wednesday noon
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            components.weekday = 2  // Monday
            let monday = calendar.date(from: components) ?? now
            todayBarDate = calendar.date(byAdding: .init(day: 2, hour: 12), to: monday) ?? monday
        default:
            // W/M: daily bars at noon
            let startOfDay = calendar.startOfDay(for: now)
            todayBarDate = calendar.date(byAdding: .hour, value: 12, to: startOfDay) ?? now
        }

        // Position scroll so today's bar is ~90% across the visible window
        let visibleDuration = selectedPeriod.numberOfBars
        let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
        scrollPosition = calendar.date(
            byAdding: selectedPeriod.calendarComponent,
            value: -offsetFromEnd,
            to: todayBarDate
        ) ?? todayBarDate
    }

    private func getDisplayValue() -> Double {
        if let selectedDate = selectedBarDate {
            return viewModel.chartData.first(where: {
                Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: .day)
            })?.value ?? 0
        } else {
            // Average
            let validData = viewModel.chartData.filter { $0.value > 0 }
            guard !validData.isEmpty else { return 0 }
            return validData.reduce(0) { $0 + $1.value } / Double(validData.count)
        }
    }

    private func formatDuration(_ minutes: Double) -> String {
        let totalMinutes = Int(minutes)
        if totalMinutes < 60 {
            return "\(totalMinutes)m"
        }
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        return "\(hours)h \(mins)m"
    }

    private func getDateLabel() -> String {
        let formatter = DateFormatter()
        if let selectedDate = selectedBarDate {
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: selectedDate)
        } else {
            formatter.dateFormat = "MMM d"
            guard let firstDate = viewModel.chartData.first?.date,
                  let lastDate = viewModel.chartData.last?.date else { return "" }
            let sortedDates = [firstDate, lastDate].sorted()
            return "\(formatter.string(from: sortedDates[0])) - \(formatter.string(from: sortedDates[1]))"
        }
    }

    private func getVisibleDomainTimeInterval() -> TimeInterval {
        Self.getVisibleDomainTimeInterval(for: selectedPeriod)
    }

    private static func getVisibleDomainTimeInterval(for period: TimePeriod) -> TimeInterval {
        let duration = period.numberOfBars
        switch period {
        case .day: return TimeInterval(duration * 3600)
        case .week, .month: return TimeInterval(duration * 24 * 3600)
        case .sixMonth: return TimeInterval(duration * 7 * 24 * 3600)
        case .year: return TimeInterval(duration * 30 * 24 * 3600)
        }
    }

    private func getAxisStride() -> Calendar.Component {
        switch selectedPeriod {
        case .day: return .hour
        case .week: return .day
        case .month: return .weekOfYear
        case .sixMonth: return .month
        case .year: return .month
        }
    }

    private func getAxisFormat() -> Date.FormatStyle {
        switch selectedPeriod {
        case .day: return .dateTime.hour(.defaultDigits(amPM: .abbreviated))
        case .week: return .dateTime.weekday(.narrow)
        case .month: return .dateTime.day(.defaultDigits)
        case .sixMonth: return .dateTime.month(.abbreviated)
        case .year: return .dateTime.month(.narrow)
        }
    }
}

// MARK: - ViewModel

@MainActor
class SleepDurationChartViewModel: ObservableObject {
    @Published var chartData: [SleepDurationDataPoint] = []
    @Published var isLoading = false

    func loadData(for period: TimePeriod) async {
        isLoading = true

        do {
            let now = Date()
            let calendar = Calendar.current

            // Calculate wide date range based on period (for scrollability)
            var oldestDate: Date
            // Extend into future by 1 month so user can scroll ahead
            let newestDate = calendar.date(byAdding: .month, value: 1, to: now) ?? now

            switch period {
            case .day:
                oldestDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            case .week:
                oldestDate = calendar.date(byAdding: .weekOfYear, value: -8, to: now) ?? now
            case .month:
                oldestDate = calendar.date(byAdding: .month, value: -6, to: now) ?? now
            case .sixMonth:
                oldestDate = calendar.date(byAdding: .month, value: -18, to: now) ?? now
            case .year:
                oldestDate = calendar.date(byAdding: .year, value: -3, to: now) ?? now
            }

            // STEP 1: Generate empty data points for ALL dates in range (enables scrolling)
            var allDataPoints = generateEmptyDataPoints(from: oldestDate, to: newestDate, period: period)

            // STEP 2: Fetch actual sleep data
            let dailyValues = try await PatientSamplesQueryService.shared.fetchSleepDurationDaily(
                startDate: oldestDate,
                endDate: newestDate
            )

            // STEP 3: Populate data points based on period granularity
            let granularity = getDateGranularity(for: period)

            // For 6M/Y, aggregate daily values into weekly/monthly bars
            if period == .sixMonth || period == .year {
                // Group daily data by bar date (using granularity matching)
                for i in 0..<allDataPoints.count {
                    let barDate = allDataPoints[i].date

                    // Find all daily data that falls within this bar's period
                    let matchingDays = dailyValues.filter { dailyValue in
                        calendar.isDate(dailyValue.date, equalTo: barDate, toGranularity: granularity)
                    }

                    guard !matchingDays.isEmpty else { continue }

                    // Calculate average from matching days
                    let avgValue = matchingDays.reduce(0.0) { $0 + $1.value } / Double(matchingDays.count)
                    allDataPoints[i] = SleepDurationDataPoint(date: barDate, value: avgValue)
                }
            } else {
                // D/W/M: Direct 1:1 daily mapping
                var valuesByDate: [Date: Double] = [:]
                for dailyValue in dailyValues {
                    let dateKey = calendar.startOfDay(for: dailyValue.date)
                    valuesByDate[dateKey] = dailyValue.value
                }

                for i in 0..<allDataPoints.count {
                    let dateKey = calendar.startOfDay(for: allDataPoints[i].date)
                    if let actualValue = valuesByDate[dateKey] {
                        allDataPoints[i] = SleepDurationDataPoint(date: allDataPoints[i].date, value: actualValue)
                    }
                }
            }

            chartData = allDataPoints
            print("📊 SleepDuration: Built \(chartData.count) chart data points (\(dailyValues.count) days of data)")

        } catch {
            print("❌ Error loading sleep duration data: \(error)")
        }

        isLoading = false
    }

    /// Generate empty data points (value=0) for all dates in range - enables chart scrolling
    /// Uses period.calendarComponent for stepping (daily for W/M, weekly for 6M, monthly for Y)
    private func generateEmptyDataPoints(from startDate: Date, to endDate: Date, period: TimePeriod) -> [SleepDurationDataPoint] {
        var points: [SleepDurationDataPoint] = []
        let calendar = Calendar.current
        var currentDate = startDate
        let incrementComponent: Calendar.Component = period.calendarComponent

        while currentDate <= endDate {
            // Calculate bar date with proper centering based on period
            let barDate: Date
            if period == .year {
                // Yearly: center bar at noon on 15th of month
                var components = calendar.dateComponents([.year, .month], from: currentDate)
                components.day = 15
                components.hour = 12
                barDate = calendar.date(from: components) ?? currentDate
            } else if period == .sixMonth {
                // 6M: weekly bars, align to Wednesday noon (middle of Mon-Sun week)
                var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: currentDate)
                components.weekday = 2  // Monday
                let monday = calendar.date(from: components) ?? currentDate
                barDate = calendar.date(byAdding: .init(day: 2, hour: 12), to: monday) ?? monday
            } else {
                // D/W/M: daily bars, center at noon
                let startOfDay = calendar.startOfDay(for: currentDate)
                barDate = calendar.date(byAdding: .hour, value: 12, to: startOfDay) ?? currentDate
            }

            points.append(SleepDurationDataPoint(date: barDate, value: 0))

            guard let nextDate = calendar.date(byAdding: incrementComponent, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return points
    }

    private func getDateGranularity(for period: TimePeriod) -> Calendar.Component {
        switch period {
        case .day: return .day
        case .week, .month: return .day
        case .sixMonth: return .weekOfYear
        case .year: return .month
        }
    }
}

struct SleepDurationDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double  // Minutes
}

#Preview {
    NavigationStack {
        SleepDurationView(pillar: "Restful Sleep", color: .purple, sectionId: "NAV_SLEEP")
    }
}
