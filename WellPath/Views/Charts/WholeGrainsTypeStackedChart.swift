//
//  WholeGrainsTypeStackedChart.swift
//  WellPath
//
//  Recreated using ProteinTypeStackedChart as foundation
//  Stacked bar chart for whole grains type distribution
//

import SwiftUI
import Charts

struct WholeGrainsTypeStackedChart: View {
    let color: Color

    @State private var selectedPeriod: TimePeriod = .week
    @State private var selectedBarDate: Date?
    @State private var selectedType: String?
    @State private var scrollPosition: Date
    @State private var showPercentage: Bool = false
    @StateObject private var viewModel = WholeGrainsTypeChartViewModel()

    // Ordered from best (top of stack) to worst (bottom of stack)
    private let wholeGrainsTypeAggIds = [
        "AGG_WHOLE_GRAINS_TYPE_BROWN_RICE",
        "AGG_WHOLE_GRAINS_TYPE_QUINOA",
        "AGG_WHOLE_GRAINS_TYPE_OATS",
        "AGG_WHOLE_GRAINS_TYPE_WHOLE_WHEAT",
        "AGG_WHOLE_GRAINS_TYPE_BARLEY",
        "AGG_WHOLE_GRAINS_TYPE_FARRO",
        "AGG_WHOLE_GRAINS_TYPE_BULGUR",
        "AGG_WHOLE_GRAINS_TYPE_OTHER"
    ]

    private let typeDisplayNames: [String: String] = [
        "AGG_WHOLE_GRAINS_TYPE_BROWN_RICE": "Brown Rice",
        "AGG_WHOLE_GRAINS_TYPE_QUINOA": "Quinoa",
        "AGG_WHOLE_GRAINS_TYPE_OATS": "Oats",
        "AGG_WHOLE_GRAINS_TYPE_WHOLE_WHEAT": "Whole Wheat",
        "AGG_WHOLE_GRAINS_TYPE_BARLEY": "Barley",
        "AGG_WHOLE_GRAINS_TYPE_FARRO": "Farro",
        "AGG_WHOLE_GRAINS_TYPE_BULGUR": "Bulgur",
        "AGG_WHOLE_GRAINS_TYPE_OTHER": "Other"
    ]

    // Apple Health style vibrant colors
    private let typeColors: [String: Color] = [
        "AGG_WHOLE_GRAINS_TYPE_BROWN_RICE": Color(red: 0.6, green: 0.4, blue: 0.2),
        "AGG_WHOLE_GRAINS_TYPE_QUINOA": Color(red: 0.7, green: 0.5, blue: 0.3),
        "AGG_WHOLE_GRAINS_TYPE_OATS": Color(red: 0.8, green: 0.6, blue: 0.4),
        "AGG_WHOLE_GRAINS_TYPE_WHOLE_WHEAT": Color(red: 0.75, green: 0.55, blue: 0.35),
        "AGG_WHOLE_GRAINS_TYPE_BARLEY": Color(red: 0.65, green: 0.45, blue: 0.25),
        "AGG_WHOLE_GRAINS_TYPE_FARRO": Color(red: 0.7, green: 0.6, blue: 0.4),
        "AGG_WHOLE_GRAINS_TYPE_BULGUR": Color(red: 0.8, green: 0.65, blue: 0.45),
        "AGG_WHOLE_GRAINS_TYPE_OTHER": Color(red: 0.9, green: 0.9, blue: 0.9)
    ]

    init(color: Color) {
        self.color = color

        // Initialize scroll position so TODAY is ~90% across the visible window (leaving 10% for future)
        let now = Date()
        let initialPeriod = TimePeriod.week
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
        VStack(spacing: 0) {
            if !viewModel.isLoading {
                // Time period picker
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 16)
                .onChange(of: selectedPeriod) { oldValue, newPeriod in
                    selectedBarDate = nil
                    selectedType = nil

                    // Reset scroll position so TODAY is ~90% across the visible window (leaving 10% for future)
                    let now = Date()
                    let visibleDuration = newPeriod.numberOfBars
                    let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
                    scrollPosition = Calendar.current.date(
                        byAdding: newPeriod.calendarComponent,
                        value: -offsetFromEnd,
                        to: now
                    ) ?? now

                    print("📊 WHOLE GRAINS TYPE: Set scrollPosition=\(scrollPosition) for period=\(newPeriod)")

                    Task {
                        await viewModel.loadData(
                            for: newPeriod,
                            typeIds: wholeGrainsTypeAggIds,
                            typeNames: typeDisplayNames,
                            typeColors: typeColors
                        )
                    }
                }

                // Stacked bar chart
                Chart {
                    ForEach(viewModel.chartData) { dateData in
                        ForEach(dateData.typeValues) { typeValue in
                            let opacity: Double = {
                                if selectedType == nil {
                                    return 1.0
                                } else if selectedType == typeValue.name {
                                    return 1.0
                                } else {
                                    return 0.3
                                }
                            }()

                            BarMark(
                                x: .value("Time", dateData.date),
                                y: .value("Servings", getDisplayValue(for: typeValue.value)),
                                width: .fixed(getBarWidth())
                            )
                            .foregroundStyle(typeValue.color.opacity(opacity))
                        }
                    }
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
                                    selectedType = nil
                                } else {
                                    selectedBarDate = closest?.date
                                }
                            }
                        }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: getAxisLabelStride(), count: getAxisLabelMultiplier())) { value in
                        if value.as(Date.self) != nil {
                            AxisValueLabel(format: getAxisLabelFormat())
                            AxisGridLine()
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 24)

                // Scrollable type averages list
                ScrollView {
                    // Servings/% toggle
                    HStack {
                        Spacer()
                        Picker("Unit", selection: $showPercentage) {
                            Text("Servings").tag(false)
                            Text("%").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                    VStack(spacing: 8) {
                        ForEach(wholeGrainsTypeAggIds, id: \.self) { aggId in
                            if let typeName = typeDisplayNames[aggId],
                               let typeColor = typeColors[aggId] {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if selectedType == typeName {
                                            selectedType = nil
                                        } else {
                                            selectedType = typeName
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(typeColor)
                                            .frame(width: 12, height: 12)

                                        Text(typeName)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        if showPercentage {
                                            let percentage = viewModel.getPercentageFor(
                                                typeName,
                                                period: selectedPeriod,
                                                scrollPosition: scrollPosition
                                            )
                                            Text(String(format: "%.0f%%", percentage))
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)
                                        } else {
                                            let average = viewModel.getAverageFor(
                                                typeName,
                                                period: selectedPeriod,
                                                scrollPosition: scrollPosition
                                            )
                                            Text(formatValue(average))
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)

                                            Text("servings")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedType == typeName ? typeColor.opacity(0.15) : Color(uiColor: .secondarySystemGroupedBackground))
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(uiColor: .systemGroupedBackground))
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .task {
            await viewModel.loadData(
                for: selectedPeriod,
                typeIds: wholeGrainsTypeAggIds,
                typeNames: typeDisplayNames,
                typeColors: typeColors
            )

            // Set scroll position after initial load
            let now = Date()
            let visibleDuration = selectedPeriod.numberOfBars
            let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
            scrollPosition = Calendar.current.date(
                byAdding: selectedPeriod.calendarComponent,
                value: -offsetFromEnd,
                to: now
            ) ?? now
            print("📊 WHOLE GRAINS TYPE: Initial scrollPosition=\(scrollPosition)")
        }
    }

    // MARK: - Helpers (EXACT ParentMetricBarChart pattern)

    private func getDisplayValue(for rawValue: Double) -> Double {
        switch selectedPeriod {
        case .day, .week, .month:
            return rawValue
        case .sixMonth:
            return rawValue / 7.0
        case .year:
            return rawValue / 30.0
        }
    }

    private func getBarWidth() -> CGFloat {
        switch selectedPeriod {
        case .day: return 10
        case .week: return 35
        case .month: return 8
        case .sixMonth: return 10
        case .year: return 22
        }
    }

    private func getVisibleDomainTimeInterval() -> TimeInterval {
        switch selectedPeriod {
        case .day: return 24 * 3600
        case .week: return 7 * 24 * 3600
        case .month: return 30 * 24 * 3600
        case .sixMonth: return 26 * 7 * 24 * 3600
        case .year: return 365 * 24 * 3600
        }
    }

    private func getAxisLabelStride() -> Calendar.Component {
        switch selectedPeriod {
        case .day: return .hour
        case .week: return .day
        case .month: return .weekOfYear
        case .sixMonth: return .month
        case .year: return .month
        }
    }

    private func getAxisLabelMultiplier() -> Int {
        switch selectedPeriod {
        case .day: return 6
        case .week: return 1
        case .month: return 1
        case .sixMonth: return 1
        case .year: return 1
        }
    }

    private func getAxisLabelFormat() -> Date.FormatStyle {
        switch selectedPeriod {
        case .day: return .dateTime.hour(.defaultDigits(amPM: .abbreviated))
        case .week: return .dateTime.weekday(.narrow)
        case .month: return .dateTime.day(.defaultDigits)
        case .sixMonth: return .dateTime.month(.abbreviated)
        case .year: return .dateTime.month(.narrow)
        }
    }

    private func formatValue(_ value: Double) -> String {
        if value == 0 {
            return "0"
        } else if value >= 100 {
            return String(format: "%.0f", value)
        } else if value >= 10 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

// MARK: - ViewModel

@MainActor
class WholeGrainsTypeChartViewModel: ObservableObject {
    @Published var chartData: [WholeGrainsTypeStackedData] = []
    @Published var isLoading = false

    private let supabase = SupabaseManager.shared.client

    func loadData(for period: TimePeriod, typeIds: [String], typeNames: [String: String], typeColors: [String: Color]) async {
        isLoading = true

        do {
            let userId = try await supabase.auth.session.user.id
            let periodType = period.databasePeriodType

            // Calculate date range for query - small initial ranges for performance
            let now = Date()
            let calendar = Calendar.current
            let newestDate = calendar.date(byAdding: .month, value: 1, to: now) ?? now

            let oldestDate: Date
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

            // Fetch whole grains type data with date range filters
            let results: [AggregationResult] = try await supabase
                .from("aggregation_results_cache")
                .select()
                .eq("patient_id", value: userId)
                .in("agg_metric_id", values: typeIds)
                .eq("period_type", value: periodType)
                .eq("calculation_type_id", value: "SUM")
                .gte("period_start", value: oldestDate.ISO8601Format())
                .lte("period_start", value: newestDate.ISO8601Format())
                .order("period_start", ascending: true)
                .execute()
                .value

            print("🌾 Fetched \(results.count) whole grains type data points for range \(oldestDate) to \(newestDate)")

            // Group by date
            var dateMap: [Date: [String: Double]] = [:]
            for result in results {
                // Convert UTC period_start to local date for timeline matching
                let localDate = result.periodStart.toLocalDateForTimeline()
                if dateMap[localDate] == nil {
                    dateMap[localDate] = [:]
                }
                let typeName = typeNames[result.aggMetricId] ?? result.aggMetricId
                dateMap[localDate]?[typeName] = result.value
            }

            // Build timeline with stacked data
            buildTimeline(for: period, typeIds: typeIds, typeNames: typeNames, typeColors: typeColors, dateMap: dateMap)

        } catch {
            print("❌ Error loading whole grains type data: \(error)")
        }

        isLoading = false
    }

    private func buildTimeline(
        for period: TimePeriod,
        typeIds: [String],
        typeNames: [String: String],
        typeColors: [String: Color],
        dateMap: [Date: [String: Double]]
    ) {
        let now = Date()
        let calendar = Calendar.current

        // Extend into future by 1 month
        let newestDate = calendar.date(byAdding: .month, value: 1, to: now) ?? now

        // Calculate oldest date based on period - start with small ranges for performance
        let oldestDate: Date
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

        // Generate timeline
        var timeline: [WholeGrainsTypeStackedData] = []
        var currentDate = oldestDate
        let granularity = getDateGranularity(for: period)

        while currentDate <= newestDate {
            let barDate: Date
            if period == .year {
                var components = calendar.dateComponents([.year, .month], from: currentDate)
                components.day = 15
                barDate = calendar.date(from: components) ?? currentDate
            } else {
                barDate = currentDate
            }

            // Overlay actual data if exists
            let matchingDateData = dateMap.first(where: { dateKey, _ in
                calendar.isDate(dateKey, equalTo: barDate, toGranularity: granularity)
            })

            let values = matchingDateData?.value ?? [:]
            let typeValues = typeIds.compactMap { aggId -> WholeGrainsTypeValue? in
                let name = typeNames[aggId] ?? aggId
                let value = values[name] ?? 0
                let typeColor = typeColors[aggId] ?? Color.gray

                return WholeGrainsTypeValue(name: name, value: value, color: typeColor)
            }

            timeline.append(WholeGrainsTypeStackedData(date: barDate, typeValues: typeValues))

            guard let nextDate = calendar.date(byAdding: period.calendarComponent, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        chartData = timeline
        let dataCount = timeline.filter { $0.typeValues.contains(where: { $0.value > 0 }) }.count
        print("🌾 Generated \(timeline.count) timeline points (\(dataCount) with data)")
    }

    private func getDateGranularity(for period: TimePeriod) -> Calendar.Component {
        switch period {
        case .day: return .hour
        case .week, .month: return .day
        case .sixMonth: return .weekOfYear
        case .year: return .month
        }
    }

    func getAverageFor(_ typeName: String, period: TimePeriod, scrollPosition: Date) -> Double {
        guard !chartData.isEmpty else { return 0 }

        let visibleDuration = getVisibleDomainTimeInterval(for: period)
        guard let endDate = Calendar.current.date(byAdding: .second, value: Int(visibleDuration), to: scrollPosition) else {
            return 0
        }

        let visibleBars = chartData.filter { $0.date >= scrollPosition && $0.date <= endDate }
        let typeValuesInWindow = visibleBars.compactMap { barData -> Double in
            barData.typeValues.first(where: { $0.name == typeName })?.value ?? 0
        }

        // Calculate sum including zeros (missing data points count as 0)
        let displayValues = typeValuesInWindow.map { convertToDisplayValue($0, for: period) }
        let sum = displayValues.reduce(0, +)

        switch period {
        case .day:
            // Day view: Sum all hourly values to get daily TOTAL
            return sum
        case .week, .month, .sixMonth, .year:
            // Other views: Calculate daily AVERAGE including nulls
            // Divide by expected number of data points in visible range
            let expectedCount = period.numberOfBars
            return sum / Double(expectedCount)
        }
    }

    func getPercentageFor(_ typeName: String, period: TimePeriod, scrollPosition: Date) -> Double {
        let typeNames = Set(chartData.flatMap { $0.typeValues.map { $0.name } })
        let totalForAllTypes = typeNames.reduce(0.0) { sum, name in
            sum + getAverageFor(name, period: period, scrollPosition: scrollPosition)
        }

        guard totalForAllTypes > 0 else { return 0 }

        let thisTypeAverage = getAverageFor(typeName, period: period, scrollPosition: scrollPosition)
        return (thisTypeAverage / totalForAllTypes) * 100
    }

    private func convertToDisplayValue(_ rawValue: Double, for period: TimePeriod) -> Double {
        switch period {
        case .day, .week, .month:
            return rawValue
        case .sixMonth:
            return rawValue / 7.0
        case .year:
            return rawValue / 30.0
        }
    }

    private func getVisibleDomainTimeInterval(for period: TimePeriod) -> TimeInterval {
        switch period {
        case .day: return 24 * 3600
        case .week: return 7 * 24 * 3600
        case .month: return 30 * 24 * 3600
        case .sixMonth: return 26 * 7 * 24 * 3600
        case .year: return 365 * 24 * 3600
        }
    }
}

// MARK: - Data Models

struct WholeGrainsTypeStackedData: Identifiable {
    let id = UUID()
    let date: Date
    let typeValues: [WholeGrainsTypeValue]
}

struct WholeGrainsTypeValue: Identifiable {
    let id = UUID()
    let name: String
    let value: Double
    let color: Color
}

#Preview {
    WholeGrainsTypeStackedChart(color: MetricsUIConfig.getPillarColor(for: "Healthful Nutrition"))
}
