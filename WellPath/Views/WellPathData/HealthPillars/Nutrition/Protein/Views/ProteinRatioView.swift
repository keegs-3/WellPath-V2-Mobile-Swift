//
//  ProteinRatioView.swift
//  WellPath
//
//  Full view for Protein Ratio metric (DISP_PROTEIN_RATIO).
//  Shows protein per body weight (g/kg or g/lb).
//

import SwiftUI
import Charts

enum ProteinRatioUnit: String, CaseIterable {
    case gPerKg = "g/kg"
    case gPerLb = "g/lb"
}

struct ProteinRatioView: View {
    let color: Color
    @StateObject private var viewModel = ProteinPerBodyWeightViewModel()
    @State private var showAboutModal = false
    @State private var selectedPeriod: TimePeriod = .week
    @State private var scrollPosition: Date
    @State private var selectedDate: Date?
    @State private var chartID = UUID()
    @State private var selectedUnit: ProteinRatioUnit = .gPerKg
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private let metricId = "DISP_PROTEIN_RATIO"
    private let metricName = "Protein Ratio"
    private let unitService = UnitConversionService.shared

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Protein Intake")
    }

    // Optimal range in g/kg (backend standard)
    private let optimalRangeGPerKg: ClosedRange<Double> = 1.2...1.6

    // Convert optimal range based on selected unit
    private var optimalRangeLow: Double {
        selectedUnit == .gPerKg ? optimalRangeGPerKg.lowerBound : unitService.gPerKgToGPerLb(optimalRangeGPerKg.lowerBound)
    }

    private var optimalRangeHigh: Double {
        selectedUnit == .gPerKg ? optimalRangeGPerKg.upperBound : unitService.gPerKgToGPerLb(optimalRangeGPerKg.upperBound)
    }

    private var unitLabel: String {
        selectedUnit.rawValue
    }

    private func displayValue(for dataPoint: ProteinPerBodyWeightData) -> Double {
        selectedUnit == .gPerKg ? dataPoint.perKg : dataPoint.perLb
    }

    private func displayAverage(for period: TimePeriod, scrollPosition: Date) -> Double {
        selectedUnit == .gPerKg
            ? viewModel.calculateAveragePerKg(for: period, scrollPosition: scrollPosition)
            : viewModel.calculateAveragePerLb(for: period, scrollPosition: scrollPosition)
    }

    init(color: Color) {
        self.color = color

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
        ScrollView {
            chartView
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Protein Ratio")
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
                    itemType: .metric,
                    itemId: "DISP_PROTEIN_RATIO",
                    displayName: "Protein Ratio",
                    pillar: "Healthful Nutrition",
                    cardId: "CARD_PROTEIN_RATIO",
                    sectionId: "NAV_NUTRITION"
                )

                Button {
                    showingEntryForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEntryForm) {
            FoodEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            NutritionDataManagementView(color: color, initialCategory: .protein)
        }
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(viewId: metricId, metricName: metricName, color: color, isPresented: $showAboutModal)
        }
        .task {
            await viewModel.loadData(for: selectedPeriod)

            let now = Date()
            let visibleDuration = selectedPeriod.numberOfBars
            let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
            scrollPosition = Calendar.current.date(
                byAdding: selectedPeriod.calendarComponent,
                value: -offsetFromEnd,
                to: now
            ) ?? now

            chartID = UUID()
        }
    }

    private var chartView: some View {
        VStack(spacing: 0) {
            if !viewModel.isLoading {
                VStack(spacing: 0) {
                    // Period picker (excluding Day)
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(TimePeriod.allCases.filter { $0 != .day }, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 16)

                    // Unit toggle
                    HStack {
                        Spacer()
                        Picker("Unit", selection: $selectedUnit) {
                            ForEach(ProteinRatioUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    .onChange(of: selectedPeriod) { oldValue, newPeriod in
                        selectedDate = nil

                        let now = Date()
                        let visibleDuration = newPeriod.numberOfBars
                        let offsetFromEnd = Int(Double(visibleDuration) * 0.9)
                        scrollPosition = Calendar.current.date(
                            byAdding: newPeriod.calendarComponent,
                            value: -offsetFromEnd,
                            to: now
                        ) ?? now

                        chartID = UUID()

                        Task {
                            await viewModel.loadData(for: newPeriod)
                        }
                    }

                    // Value display
                        HStack(alignment: .top, spacing: 24) {
                            VStack(alignment: .leading, spacing: 4) {
                                if let date = selectedDate,
                                   let selected = viewModel.chartData.first(where: { Calendar.current.isDate($0.date, equalTo: date, toGranularity: .day) }) {

                                    Text(formatSelectedDateLabel(date))
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text(String(format: "%.2f", displayValue(for: selected)))
                                            .font(.system(size: 48, weight: .semibold))
                                            .foregroundColor(color)
                                        Text(unitLabel)
                                            .font(.title2)
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    Text(getAggregateLabel())
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text(String(format: "%.2f", displayAverage(for: selectedPeriod, scrollPosition: scrollPosition)))
                                            .font(.system(size: 48, weight: .semibold))
                                            .foregroundColor(color)
                                        Text(unitLabel)
                                            .font(.title2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }

                            Spacer()

                            Button(action: {
                                showAboutModal = true
                            }) {
                                Image(systemName: "info.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(color)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 16)

                    // Line chart
                    Chart {
                        // Optimal range shading (light blue area between lines)
                        RectangleMark(
                            yStart: .value("OptimalLow", optimalRangeLow),
                            yEnd: .value("OptimalHigh", optimalRangeHigh)
                        )
                        .foregroundStyle(Color.blue.opacity(0.08))

                        RuleMark(y: .value("OptimalLow", optimalRangeLow))
                            .foregroundStyle(Color.blue.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))

                        RuleMark(y: .value("OptimalHigh", optimalRangeHigh))
                            .foregroundStyle(Color.blue.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))

                        ForEach(viewModel.chartData) { dataPoint in
                            PointMark(
                                x: .value("Date", dataPoint.date),
                                y: .value("Ratio", 0)
                            )
                            .opacity(0)

                            let value = displayValue(for: dataPoint)
                            if value > 0 {
                                // Line connecting points - lighter secondary color
                                LineMark(
                                    x: .value("Date", dataPoint.date),
                                    y: .value("Ratio", value)
                                )
                                .foregroundStyle(Color.secondary.opacity(0.3))
                                .interpolationMethod(.catmullRom)
                                .lineStyle(StrokeStyle(lineWidth: 2))

                                // Stroked circle points
                                let isSelected = selectedDate != nil && Calendar.current.isDate(dataPoint.date, equalTo: selectedDate!, toGranularity: .day)
                                PointMark(
                                    x: .value("Date", dataPoint.date),
                                    y: .value("Ratio", value)
                                )
                                .symbol {
                                    Circle()
                                        .strokeBorder(
                                            isSelected ? color : color.opacity(0.7),
                                            lineWidth: isSelected ? 3 : 2
                                        )
                                        .background(Circle().fill(Color(uiColor: .systemBackground)))
                                        .frame(width: isSelected ? 12 : 8, height: isSelected ? 12 : 8)
                                }
                            }
                        }
                    }
                    .chartYScale(domain: 0...(max(viewModel.chartData.map { displayValue(for: $0) }.max() ?? (selectedUnit == .gPerKg ? 2.5 : 1.2), selectedUnit == .gPerKg ? 2.5 : 1.2)))
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            if let selectedDate = selectedDate,
                               let selectedData = viewModel.chartData.first(where: { Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: .day) }),
                               displayValue(for: selectedData) > 0 {

                                let yValue = displayValue(for: selectedData)
                                if let xPos = proxy.position(forX: selectedData.date),
                                   let yPos = proxy.position(forY: yValue) {

                                    VStack(spacing: 4) {
                                        if let grams = selectedData.grams, let kg = selectedData.kg {
                                            let weightLabel = selectedUnit == .gPerKg
                                                ? "kg: \(String(format: "%.1f", kg))"
                                                : "lb: \(String(format: "%.1f", kg * 2.2046))"
                                            Text("g: \(String(format: "%.0f", grams)) / \(weightLabel)")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.primary)
                                        } else {
                                            Text("Calculation data unavailable")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(uiColor: .systemBackground))
                                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                                    )
                                    .position(x: xPos, y: max(30, yPos - 40))
                                }
                            }
                        }
                    }
                    .frame(height: 220)
                    .chartScrollableAxes(.horizontal)
                    .chartScrollPosition(x: $scrollPosition)
                    .chartXVisibleDomain(length: getVisibleDomainTimeInterval())
                    .id(chartID)
                    .chartGesture { proxy in
                        SpatialTapGesture()
                            .onEnded { value in
                                if let tappedDate: Date = proxy.value(atX: value.location.x) {
                                    let closest = viewModel.chartData.min(by: {
                                        abs($0.date.timeIntervalSince(tappedDate)) < abs($1.date.timeIntervalSince(tappedDate))
                                    })

                                    if selectedDate == closest?.date {
                                        selectedDate = nil
                                    } else {
                                        selectedDate = closest?.date
                                    }
                                }
                            }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: getAxisStride(), count: getAxisMultiplier())) { value in
                            if value.as(Date.self) != nil {
                                AxisValueLabel(format: getAxisFormat())
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
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                        // Optimal range info
                        HStack {
                            Spacer()
                            HStack(spacing: 6) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.caption)
                                    .foregroundColor(Color.blue.opacity(0.7))
                                Text("Optimal: \(String(format: "%.2f", optimalRangeLow))-\(String(format: "%.2f", optimalRangeHigh)) \(unitLabel)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.08))
                            .cornerRadius(8)
                            Spacer()
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                }
                .background(Color(uiColor: .systemGroupedBackground))
            }
        }
    }

    // MARK: - Helpers

    private func getVisibleDomainTimeInterval() -> TimeInterval {
        switch selectedPeriod {
        case .day: return 24 * 3600
        case .week: return 7 * 24 * 3600
        case .month: return 30 * 24 * 3600
        case .sixMonth: return 26 * 7 * 24 * 3600
        case .year: return 365 * 24 * 3600
        }
    }

    private func getAxisStride() -> Calendar.Component {
        switch selectedPeriod {
        case .day: return .hour
        case .week: return .day
        case .month: return .weekOfYear
        case .sixMonth: return .weekOfYear
        case .year: return .month
        }
    }

    private func getAxisMultiplier() -> Int {
        switch selectedPeriod {
        case .day: return 6
        case .week: return 1
        case .month: return 1
        case .sixMonth: return 4
        case .year: return 1
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

    private func getAggregateLabel() -> String {
        switch selectedPeriod {
        case .day: return "DAY"
        case .week: return "WEEK"
        case .month: return "MONTH"
        case .sixMonth: return "6 MONTHS"
        case .year: return "YEAR"
        }
    }

    private func formatSelectedDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        switch selectedPeriod {
        case .day:
            formatter.dateFormat = "h:00 a"
            return formatter.string(from: date)
        case .week, .month:
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        case .sixMonth:
            guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: date) else {
                formatter.dateFormat = "MMM d"
                return formatter.string(from: date)
            }
            let startFormatter = DateFormatter()
            startFormatter.dateFormat = "MMM d"
            let endFormatter = DateFormatter()
            endFormatter.dateFormat = "d"
            return "\(startFormatter.string(from: date))-\(endFormatter.string(from: weekEnd))"
        case .year:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }
    }
}

// MARK: - View Model

// Weight sample from patient_quantity_samples table
private struct WeightSample: Codable {
    let canonicalValue: Double?
    let startTime: Date

    enum CodingKeys: String, CodingKey {
        case canonicalValue = "canonical_value"
        case startTime = "start_time"
    }
}

// Protein sample from patient_quantity_samples table
private struct ProteinSample: Codable {
    let quantityValue: Double?
    let startTime: Date
    let aggregationDateString: String?

    enum CodingKeys: String, CodingKey {
        case quantityValue = "quantity_value"
        case startTime = "start_time"
        case aggregationDateString = "aggregation_date"
    }

    /// Parse aggregation_date as a local date (noon to avoid DST issues)
    var aggregationDate: Date? {
        guard let dateString = aggregationDateString else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: dateString + " 12:00")
    }
}

@MainActor
class ProteinPerBodyWeightViewModel: ObservableObject {
    @Published var chartData: [ProteinPerBodyWeightData] = []
    @Published var averagePerKg: Double = 0
    @Published var averagePerLb: Double = 0
    @Published var isLoading = true

    private let supabase = SupabaseManager.shared.client
    private let unitService = UnitConversionService.shared

    func loadData(for period: TimePeriod) async {
        isLoading = true

        await unitService.loadConversions()

        do {
            let userId = try await supabase.auth.session.user.id

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

            // Get protein from patient_quantity_samples
            let proteinSamples: [ProteinSample] = try await supabase
                .from("patient_quantity_samples")
                .select("quantity_value, start_time, aggregation_date")
                .eq("patient_id", value: userId)
                .eq("quantity_type", value: "protein_grams")
                .eq("is_primary", value: true)  // Only use primary samples for analysis
                .gte("start_time", value: oldestDate.ISO8601Format())
                .lte("start_time", value: newestDate.ISO8601Format())
                .order("start_time", ascending: true)
                .execute()
                .value

            // Get bodyweight from patient_quantity_samples (canonical source)
            let weightSamples: [WeightSample] = try await supabase
                .from("patient_quantity_samples")
                .select("canonical_value, start_time")
                .eq("patient_id", value: userId)
                .eq("quantity_type", value: "bodyweight")
                .eq("is_primary", value: true)  // Only use primary samples for analysis
                .lte("start_time", value: newestDate.ISO8601Format())
                .order("start_time", ascending: true)
                .execute()
                .value

            let granularity: Calendar.Component
            switch period {
            case .day:
                granularity = .hour
            case .week, .month:
                granularity = .day
            case .sixMonth:
                granularity = .weekOfYear
            case .year:
                granularity = .month
            }

            // Group protein samples by date and sum
            var proteinByDate: [Date: Double] = [:]
            for sample in proteinSamples {
                guard let value = sample.quantityValue, value > 0 else { continue }

                let groupDate: Date
                if period == .day {
                    let components = calendar.dateComponents([.year, .month, .day, .hour], from: sample.startTime)
                    groupDate = calendar.date(from: components) ?? sample.startTime
                } else {
                    groupDate = sample.aggregationDate ?? calendar.startOfDay(for: sample.startTime)
                }

                proteinByDate[groupDate, default: 0] += value
            }

            var timeline: [ProteinPerBodyWeightData] = []
            var currentDate = oldestDate

            while currentDate <= newestDate {
                let barDate: Date
                if period == .year {
                    var components = calendar.dateComponents([.year, .month], from: currentDate)
                    components.day = 15
                    barDate = calendar.date(from: components) ?? currentDate
                } else {
                    barDate = currentDate
                }

                // Find matching protein data
                let matchingProtein = proteinByDate.first(where: { dateKey, _ in
                    calendar.isDate(dateKey, equalTo: barDate, toGranularity: granularity)
                })

                let proteinGrams = matchingProtein?.value ?? 0.0
                let weightKg = findWeightForDate(barDate, from: weightSamples)

                let perKg: Double
                if let weight = weightKg, weight > 0, proteinGrams > 0 {
                    perKg = proteinGrams / weight
                } else {
                    perKg = 0
                }

                timeline.append(ProteinPerBodyWeightData(
                    date: barDate,
                    perKg: perKg,
                    perLb: unitService.gPerKgToGPerLb(perKg),
                    grams: proteinGrams > 0 ? proteinGrams : nil,
                    kg: weightKg
                ))

                guard let nextDate = calendar.date(byAdding: period.calendarComponent, value: 1, to: currentDate) else {
                    break
                }
                currentDate = nextDate
            }

            chartData = timeline

        } catch {
            print("❌ Error loading protein per body weight: \(error)")
        }

        isLoading = false
    }

    private func findWeightForDate(_ date: Date, from samples: [WeightSample]) -> Double? {
        var lastWeight: Double? = nil

        for sample in samples {
            if sample.startTime <= date {
                // canonical_value is always in kg (canonical unit)
                lastWeight = sample.canonicalValue
            } else {
                break
            }
        }

        return lastWeight
    }

    func calculateAveragePerKg(for period: TimePeriod, scrollPosition: Date) -> Double {
        guard !chartData.isEmpty else { return 0 }

        let visibleDuration: TimeInterval
        switch period {
        case .day: visibleDuration = 24 * 3600
        case .week: visibleDuration = 7 * 24 * 3600
        case .month: visibleDuration = 30 * 24 * 3600
        case .sixMonth: visibleDuration = 26 * 7 * 24 * 3600
        case .year: visibleDuration = 365 * 24 * 3600
        }

        let calendar = Calendar.current
        guard let endDate = calendar.date(byAdding: .second, value: Int(visibleDuration), to: scrollPosition) else {
            return 0
        }

        let visibleData = chartData.filter { $0.date >= scrollPosition && $0.date <= endDate }
        let actualData = visibleData.filter { $0.perKg > 0 }

        guard !actualData.isEmpty else { return 0 }

        return actualData.reduce(0, { $0 + $1.perKg }) / Double(actualData.count)
    }

    func calculateAveragePerLb(for period: TimePeriod, scrollPosition: Date) -> Double {
        return unitService.gPerKgToGPerLb(calculateAveragePerKg(for: period, scrollPosition: scrollPosition))
    }
}

// MARK: - Data Model

struct ProteinPerBodyWeightData: Identifiable {
    let id = UUID()
    let date: Date
    let perKg: Double
    let perLb: Double
    let grams: Double?
    let kg: Double?
}

#Preview {
    NavigationStack {
        ProteinRatioView(color: .green)
    }
}
