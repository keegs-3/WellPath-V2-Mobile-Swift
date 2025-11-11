//
//  SleepAnalysisChart.swift
//  WellPath
//
//  Sleep analysis visualization with infinite scroll, time period toggles,
//  and lazy loading for performance
//

import SwiftUI
import Charts

// MARK: - Models

struct SleepPeriod: Identifiable {
    let id = UUID()
    let startDate: Date
    let endDate: Date
    let stage: SleepStage
    let quality: Double // 0-100
    
    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
}

enum SleepStage: String, CaseIterable {
    case deep = "Deep"
    case rem = "REM"
    case light = "Light"
    case awake = "Awake"
    
    var color: Color {
        switch self {
        case .deep: return Color(red: 0.2, green: 0.3, blue: 0.7)
        case .rem: return Color(red: 0.6, green: 0.4, blue: 0.9)
        case .light: return Color(red: 0.7, green: 0.8, blue: 1.0)
        case .awake: return Color.red.opacity(0.3)
        }
    }
    
    var displayOrder: Int {
        switch self {
        case .deep: return 3
        case .rem: return 2
        case .light: return 1
        case .awake: return 0
        }
    }
}

struct DailySleepSummary: Identifiable {
    let id = UUID()
    let date: Date
    let totalSleepMinutes: Int
    let deepSleepMinutes: Int
    let remSleepMinutes: Int
    let lightSleepMinutes: Int
    let awakeMinutes: Int
    let qualityScore: Double // 0-100
    let efficiency: Double // 0-100
    
    var sleepPeriods: [SleepPeriod]
    
    var totalHours: Double {
        Double(totalSleepMinutes) / 60.0
    }
}

enum TimePeriod: String, CaseIterable, Identifiable {
    case day = "D"
    case week = "W"
    case month = "M"
    case sixMonths = "6M"
    case year = "Y"
    
    var id: String { rawValue }
    
    var dateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .day:
            return calendar.startOfDay(for: now)...now
        case .week:
            let start = calendar.date(byAdding: .day, value: -7, to: now)!
            return start...now
        case .month:
            let start = calendar.date(byAdding: .month, value: -1, to: now)!
            return start...now
        case .sixMonths:
            let start = calendar.date(byAdding: .month, value: -6, to: now)!
            return start...now
        case .year:
            let start = calendar.date(byAdding: .year, value: -1, to: now)!
            return start...now
        }
    }
    
    var visibleDomain: TimeInterval {
        switch self {
        case .day: return 24 * 3600 // 24 hours
        case .week: return 7 * 24 * 3600 // 7 days
        case .month: return 30 * 24 * 3600 // 30 days
        case .sixMonths: return 180 * 24 * 3600 // 180 days
        case .year: return 365 * 24 * 3600 // 365 days
        }
    }
    
    var xAxisStride: Calendar.Component {
        switch self {
        case .day: return .hour
        case .week: return .day
        case .month: return .day
        case .sixMonths: return .weekOfYear
        case .year: return .month
        }
    }
    
    var xAxisFormat: Date.FormatStyle {
        switch self {
        case .day: return .dateTime.hour()
        case .week: return .dateTime.weekday(.abbreviated)
        case .month: return .dateTime.day()
        case .sixMonths: return .dateTime.month(.abbreviated).day()
        case .year: return .dateTime.month(.abbreviated)
        }
    }
    
    // How much data to load ahead/behind for infinite scroll
    var loadBufferDays: Int {
        switch self {
        case .day: return 3
        case .week: return 14
        case .month: return 60
        case .sixMonths: return 90
        case .year: return 180
        }
    }
}

// MARK: - Main Chart View

struct SleepAnalysisChart: View {
    @StateObject private var viewModel = SleepChartViewModel()
    @State private var selectedPeriod: TimePeriod = .week
    @State private var scrollPosition: Date?
    @State private var selectedDate: Date?
    
    var body: some View {
        VStack(spacing: 16) {
            // Period Selector
            periodSelector
            
            // Chart Container
            chartContainer
            
            // Summary Stats
            if let summary = viewModel.summaryForDate(selectedDate ?? Date()) {
                sleepSummaryCard(summary)
            }
            
            // Legend
            sleepStageLegend
        }
        .padding()
        .onAppear {
            viewModel.loadInitialData(for: selectedPeriod)
        }
        .onChange(of: selectedPeriod) { _, newPeriod in
            viewModel.changePeriod(to: newPeriod)
        }
        .onChange(of: scrollPosition) { _, newPosition in
            viewModel.handleScroll(to: newPosition, period: selectedPeriod)
        }
    }
    
    // MARK: - Period Selector
    
    private var periodSelector: some View {
        HStack(spacing: 8) {
            ForEach(TimePeriod.allCases) { period in
                Button(action: {
                    withAnimation {
                        selectedPeriod = period
                    }
                }) {
                    Text(period.rawValue)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundColor(selectedPeriod == period ? .white : .primary)
                        .frame(width: 44, height: 32)
                        .background(
                            selectedPeriod == period ?
                                Color.blue : Color.gray.opacity(0.1)
                        )
                        .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Chart Container
    
    private var chartContainer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sleep Quality & Duration")
                .font(.headline)
            
            if viewModel.isLoading && viewModel.sleepData.isEmpty {
                ProgressView()
                    .frame(height: 300)
            } else {
                sleepChart
                    .frame(height: 300)
            }
        }
    }
    
    private var sleepChart: some View {
        Chart {
            // Sleep quality line with area
            ForEach(viewModel.sleepData) { summary in
                LineMark(
                    x: .value("Date", summary.date),
                    y: .value("Quality", summary.qualityScore)
                )
                .foregroundStyle(Color.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Date", summary.date),
                    y: .value("Quality", summary.qualityScore)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
                
                // Sleep duration bars
                BarMark(
                    x: .value("Date", summary.date),
                    y: .value("Hours", summary.totalHours)
                )
                .foregroundStyle(Color.purple.opacity(0.3))
                .position(by: .value("Metric", "Duration"))
            }
            
            // Target line
            RuleMark(y: .value("Target", 8.0))
                .foregroundStyle(Color.green.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("8h target")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            
            // Average quality line
            if let avgQuality = viewModel.averageQuality {
                RuleMark(y: .value("Average", avgQuality))
                    .foregroundStyle(Color.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            
            // Selection indicator
            if let selectedDate = selectedDate {
                RuleMark(x: .value("Selected", selectedDate))
                    .foregroundStyle(Color.gray.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: selectedPeriod.xAxisStride)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: selectedPeriod.xAxisFormat)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartYScale(domain: 0...100)
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: selectedPeriod.visibleDomain)
        .chartScrollPosition(x: $scrollPosition)
        .chartXSelection(value: $selectedDate)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let x = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                                if let date: Date = proxy.value(atX: x) {
                                    selectedDate = date
                                }
                            }
                    )
            }
        }
    }
    
    // MARK: - Summary Card
    
    private func sleepSummaryCard(_ summary: DailySleepSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(summary.date, format: .dateTime.month().day().year())
                        .font(.headline)
                    Text("Quality Score: \(Int(summary.qualityScore))")
                        .font(.subheadline)
                        .foregroundColor(qualityColor(summary.qualityScore))
                }
                Spacer()
                Text("\(summary.totalHours, format: .number.precision(.fractionLength(1)))h")
                    .font(.system(.title2, design: .rounded, weight: .bold))
            }
            
            // Stage breakdown
            HStack(spacing: 16) {
                sleepStageInfo("Deep", minutes: summary.deepSleepMinutes, color: SleepStage.deep.color)
                sleepStageInfo("REM", minutes: summary.remSleepMinutes, color: SleepStage.rem.color)
                sleepStageInfo("Light", minutes: summary.lightSleepMinutes, color: SleepStage.light.color)
            }
            
            // Efficiency
            HStack {
                Text("Sleep Efficiency")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(summary.efficiency))%")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func sleepStageInfo(_ title: String, minutes: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text("\(minutes)m")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
    }
    
    // MARK: - Legend
    
    private var sleepStageLegend: some View {
        HStack(spacing: 16) {
            ForEach(SleepStage.allCases, id: \.self) { stage in
                HStack(spacing: 6) {
                    Circle()
                        .fill(stage.color)
                        .frame(width: 10, height: 10)
                    Text(stage.rawValue)
                        .font(.caption)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func qualityColor(_ quality: Double) -> Color {
        switch quality {
        case 80...100: return .green
        case 60..<80: return .yellow
        default: return .red
        }
    }
}

// MARK: - View Model

@MainActor
class SleepChartViewModel: ObservableObject {
    @Published var sleepData: [DailySleepSummary] = []
    @Published var isLoading = false
    @Published var currentPeriod: TimePeriod = .week
    
    private var loadedDateRange: ClosedRange<Date>?
    private let calendar = Calendar.current
    
    var averageQuality: Double? {
        guard !sleepData.isEmpty else { return nil }
        return sleepData.map(\.qualityScore).reduce(0, +) / Double(sleepData.count)
    }
    
    // MARK: - Initial Load
    
    func loadInitialData(for period: TimePeriod) {
        Task {
            isLoading = true
            let range = period.dateRange
            sleepData = await fetchSleepData(for: range)
            loadedDateRange = range
            isLoading = false
        }
    }
    
    // MARK: - Period Change
    
    func changePeriod(to newPeriod: TimePeriod) {
        currentPeriod = newPeriod
        loadInitialData(for: newPeriod)
    }
    
    // MARK: - Infinite Scroll Handler
    
    func handleScroll(to position: Date?, period: TimePeriod) {
        guard let position = position,
              let loadedRange = loadedDateRange else { return }
        
        let bufferDays = period.loadBufferDays
        let bufferInterval = TimeInterval(bufferDays * 24 * 3600)
        
        // Check if we're near the start of loaded data
        if position.timeIntervalSince(loadedRange.lowerBound) < bufferInterval {
            loadMoreData(direction: .past, bufferDays: bufferDays)
        }
        
        // Check if we're near the end of loaded data
        if loadedRange.upperBound.timeIntervalSince(position) < bufferInterval {
            loadMoreData(direction: .future, bufferDays: bufferDays)
        }
    }
    
    enum ScrollDirection {
        case past, future
    }
    
    private func loadMoreData(direction: ScrollDirection, bufferDays: Int) {
        guard !isLoading, let loadedRange = loadedDateRange else { return }
        
        Task {
            isLoading = true
            
            let newRange: ClosedRange<Date>
            switch direction {
            case .past:
                let newStart = calendar.date(byAdding: .day, value: -bufferDays, to: loadedRange.lowerBound)!
                newRange = newStart...loadedRange.lowerBound
            case .future:
                let newEnd = calendar.date(byAdding: .day, value: bufferDays, to: loadedRange.upperBound)!
                newRange = loadedRange.upperBound...min(newEnd, Date())
            }
            
            let newData = await fetchSleepData(for: newRange)
            
            // Merge with existing data
            switch direction {
            case .past:
                sleepData.insert(contentsOf: newData, at: 0)
                loadedDateRange = newRange.lowerBound...loadedRange.upperBound
            case .future:
                sleepData.append(contentsOf: newData)
                loadedDateRange = loadedRange.lowerBound...newRange.upperBound
            }
            
            isLoading = false
        }
    }
    
    // MARK: - Data Fetching
    
    private func fetchSleepData(for range: ClosedRange<Date>) async -> [DailySleepSummary] {
        // TODO: Replace with actual API call
        // Example: return await SleepDataService.shared.fetchSleep(startDate: range.lowerBound, endDate: range.upperBound)
        
        // Mock data for demonstration
        try? await Task.sleep(nanoseconds: 500_000_000) // Simulate network delay
        
        var summaries: [DailySleepSummary] = []
        var currentDate = calendar.startOfDay(for: range.lowerBound)
        let endDate = calendar.startOfDay(for: range.upperBound)
        
        while currentDate <= endDate {
            summaries.append(generateMockSummary(for: currentDate))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return summaries
    }
    
    private func generateMockSummary(for date: Date) -> DailySleepSummary {
        // Mock data generator
        let deepMin = Int.random(in: 60...120)
        let remMin = Int.random(in: 90...150)
        let lightMin = Int.random(in: 180...300)
        let awakeMin = Int.random(in: 10...40)
        let totalMin = deepMin + remMin + lightMin
        
        return DailySleepSummary(
            date: date,
            totalSleepMinutes: totalMin,
            deepSleepMinutes: deepMin,
            remSleepMinutes: remMin,
            lightSleepMinutes: lightMin,
            awakeMinutes: awakeMin,
            qualityScore: Double.random(in: 60...95),
            efficiency: Double(totalMin) / Double(totalMin + awakeMin) * 100,
            sleepPeriods: []
        )
    }
    
    // MARK: - Summary Lookup
    
    func summaryForDate(_ date: Date) -> DailySleepSummary? {
        let targetDay = calendar.startOfDay(for: date)
        return sleepData.first { calendar.isDate($0.date, inSameDayAs: targetDay) }
    }
}

// MARK: - Preview

#Preview {
    SleepAnalysisChart()
}
