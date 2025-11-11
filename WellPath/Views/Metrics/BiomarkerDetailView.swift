//
//  BiomarkerDetailView.swift
//  WellPath
//
//  Created on 2025-10-22
//

import SwiftUI
import Charts

struct BiomarkerDetailView: View {
    let name: String
    let value: String
    let status: String
    let optimalRange: String
    let trend: String
    let isBiometric: Bool

    @StateObject private var viewModel = BiomarkerDetailViewModel()
    @State private var selectedDataPoint: BiomarkerDataPoint?
    @State private var rangeDetails: [Any] = [] // Will be [BiomarkerDetail] or [BiometricDetail]
    @State private var baseInfo: Any? = nil // Will be BiomarkerBase or BiometricsBase
    @State private var service = BiometricsService()
    @State private var selectedPeriod: TimePeriod = .all
    @State private var selectedView: DetailView = .chart
    @State private var availableUnits: [UnitConversion] = []
    @State private var selectedUnit: String = ""
    @State private var originalUnit: String = ""
    @State private var unitDisplayNames: [String: String] = [:]
    @State private var educationSections: [Any] = [] // Will be [BiomarkerEducationSection] or [BiometricEducationSection]
    @State private var isLoadingEducation = false

    // State for current values fetched from database
    @State private var currentValue: String = ""
    @State private var currentStatus: String = ""
    @State private var currentOptimalRange: String = ""
    @State private var currentTrend: String = ""

    enum DetailView: String, CaseIterable {
        case chart = "Chart"
        case about = "About"
    }

    var chartData: [BiomarkerDataPoint] {
        let sortedData = viewModel.historicalData.sorted { $0.date < $1.date }

        // Filter by period
        let filteredData: [BiomarkerDataPoint]
        if selectedPeriod == .all {
            filteredData = sortedData
        } else {
            let calendar = Calendar.current
            let now = Date()
            let cutoffDate: Date

            switch selectedPeriod {
            case .threeMonths:
                cutoffDate = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            case .sixMonths:
                cutoffDate = calendar.date(byAdding: .month, value: -6, to: now) ?? now
            case .oneYear:
                cutoffDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            case .fiveYears:
                cutoffDate = calendar.date(byAdding: .year, value: -5, to: now) ?? now
            case .all:
                cutoffDate = Date.distantPast
            }

            filteredData = sortedData.filter { $0.date >= cutoffDate }
        }

        // Apply unit conversion if needed
        if selectedUnit != originalUnit {
            return filteredData.map { dataPoint in
                BiomarkerDataPoint(
                    date: dataPoint.date,
                    value: convertValue(dataPoint.value)
                )
            }
        }

        return filteredData
    }

    var historicalData: [BiomarkerDataPoint] {
        viewModel.historicalData
    }

    enum TimePeriod: Equatable {
        case threeMonths, sixMonths, oneYear, fiveYears, all

        var label: String {
            switch self {
            case .threeMonths: return "3M"
            case .sixMonths: return "6M"
            case .oneYear: return "1Y"
            case .fiveYears: return "5Y"
            case .all: return "All"
            }
        }
    }

    var statusColor: Color {
        switch status {
        case "Out-of-Range": return .red
        case "In-Range": return .blue
        case "Optimal": return .green
        default: return .gray
        }
    }

    var metricColor: Color {
        if isBiometric {
            return Color(red: 1.0, green: 0.0, blue: 1.0) // Magenta for biometrics
        } else {
            return Color(red: 0.74, green: 0.56, blue: 0.94) // Purple for biomarkers
        }
    }

    var metricIcon: String {
        if isBiometric {
            return "ruler.fill" // Physical measurements
        } else {
            return "drop.fill" // Lab/blood tests
        }
    }

    var decimalPlaces: Int {
        // Parse format from value string or default to 1
        if let dotIndex = value.firstIndex(of: ".") {
            let afterDot = value[value.index(after: dotIndex)...]
            let decimals = afterDot.prefix(while: { $0.isNumber })
            return decimals.count
        }
        return 1
    }

    var body: some View {
        VStack(spacing: 0) {
            // View picker
            Picker("View", selection: $selectedView) {
                ForEach(DetailView.allCases, id: \.self) { view in
                    Text(view.rawValue).tag(view)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Content based on selected view
            if selectedView == .chart {
                chartContentView
            } else {
                aboutContentView
            }
        }
        .background(
            ZStack {
                // Background gradient
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [metricColor.opacity(0.65), metricColor.opacity(0.45), metricColor.opacity(0.25), metricColor.opacity(0.1), Color.clear],
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
                        Image(systemName: metricIcon)
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
        .navigationBarTitleDisplayMode(.large)
        .navigationTitle(name)
        .task {
            print("🔍 BiomarkerDetailView loading for: '\(name)' (isBiometric: \(isBiometric))")
            await viewModel.loadHistory(for: name, isBiometric: isBiometric)
            // Load range details and base information
            do {
                if isBiometric {
                    print("🔍 Fetching biometric details for: '\(name)'")
                    rangeDetails = try await service.fetchBiometricDetails(for: name)
                    let baseInfoFetched = try await service.fetchBiometricsBase(for: name)
                    baseInfo = baseInfoFetched

                    // Set current values from baseInfo
                    if let base = baseInfoFetched {
                        if let optRange = base.aboutOptimalRange {
                            currentOptimalRange = optRange
                        }
                    }

                    // Load unit conversions if unit exists
                    if let unitId = (baseInfoFetched as? BiometricsBase)?.unit {
                        originalUnit = unitId
                        selectedUnit = unitId
                        await loadUnitConversions(for: unitId)
                    }
                } else {
                    print("🔍 Fetching biomarker details for: '\(name)'")
                    rangeDetails = try await service.fetchBiomarkerDetails(for: name)
                    let fetchedBase = try await service.fetchBiomarkerBase(for: name)
                    print("🔍 Fetched biomarker base: \(fetchedBase?.biomarkerName ?? "nil")")
                    baseInfo = fetchedBase

                    // Set current values from baseInfo
                    if let base = fetchedBase {
                        if let optRange = base.aboutOptimalTarget {
                            currentOptimalRange = optRange
                        }
                    }

                    // Load unit conversions if unit exists
                    if let unitId = fetchedBase?.units {
                        originalUnit = unitId
                        selectedUnit = unitId
                        await loadUnitConversions(for: unitId)
                    }
                }

                // Get the most recent value and status from historical data
                if let latestDataPoint = viewModel.historicalData.first {
                    // Format the value with units
                    let formattedValue = formatValueForDisplay(latestDataPoint.value)
                    if !originalUnit.isEmpty, let unitDisplay = unitDisplayNames[originalUnit] {
                        currentValue = "\(formattedValue) \(unitDisplay)"
                    } else {
                        currentValue = formattedValue
                    }

                    // Determine status from range details
                    let rangeInfo = getRangeNameFor(value: latestDataPoint.value)
                    currentStatus = rangeInfo.bucket

                    // Simple trend calculation - compare to previous value
                    if viewModel.historicalData.count >= 2 {
                        let current = viewModel.historicalData[0].value
                        let previous = viewModel.historicalData[1].value
                        let difference = current - previous
                        let percentChange = abs(difference / previous * 100)

                        if percentChange < 5 {
                            currentTrend = "Stable"
                        } else if difference > 0 {
                            currentTrend = "Increasing"
                        } else {
                            currentTrend = "Decreasing"
                        }
                    }
                }
            } catch {
                print("❌ Error loading range details: \(error)")
            }

            // Load education sections
            await loadEducationSections()
        }
    }

    // MARK: - Chart Content View
    private var chartContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Current Status Card
                VStack(alignment: .leading, spacing: 16) {
                    // Metric icon and name
                    HStack(spacing: 12) {
                        Image(systemName: metricIcon)
                            .font(.system(size: 24))
                            .foregroundColor(metricColor)
                            .frame(width: 40, height: 40)
                            .background(metricColor.opacity(0.15))
                            .cornerRadius(8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(name)
                                .font(.headline)
                            Text(isBiometric ? "Biometric" : "Biomarker")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // Current value and status
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(currentValue.isEmpty ? value : currentValue)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(statusColor)

                        Text(currentStatus.isEmpty ? status : currentStatus)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusColor.opacity(0.15))
                            .foregroundColor(statusColor)
                            .cornerRadius(6)
                    }

                    // Metadata
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Optimal Range")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(currentOptimalRange.isEmpty ? convertedOptimalRange() : currentOptimalRange)
                                .font(.caption)
                                .fontWeight(.medium)
                        }

                        HStack {
                            Text("Trend")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(currentTrend.isEmpty ? trend : currentTrend)
                                .font(.caption)
                                .fontWeight(.medium)
                        }

                        HStack {
                            Text("Last Measured")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(viewModel.historicalData.first?.date ?? Date(), style: .date)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding()
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(12)

                // History Chart
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("History")
                                .font(.headline)

                            if !chartData.isEmpty {
                                Text("\(chartData.count) reading\(chartData.count == 1 ? "" : "s")")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        // Period Selector
                        Picker("Period", selection: $selectedPeriod) {
                            ForEach([TimePeriod.threeMonths, .sixMonths, .oneYear, .fiveYears, .all], id: \.label) { period in
                                Text(period.label).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 240)
                    }
                    .padding(.horizontal)

                    // Unit Selector
                    if !availableUnits.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Unit")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            Picker("Unit", selection: $selectedUnit) {
                                // Original unit
                                Text(unitDisplayNames[originalUnit] ?? originalUnit).tag(originalUnit)

                                // All available conversions
                                ForEach(availableUnits) { conversion in
                                    Text(unitDisplayNames[conversion.toUnit] ?? conversion.toUnit).tag(conversion.toUnit)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                        }
                    }

                    if viewModel.isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                            Text("Loading historical data...")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: 200)
                        .padding()
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    } else if !chartData.isEmpty {
                        Chart {
                            // Optimal range background
                            let optMin = getOptimalMin()
                            let optMax = getOptimalMax()

                            // Calculate x-axis range with padding
                            let xAxisRange = getXAxisDomain()
                            let xStart = xAxisRange.lowerBound
                            let xEnd = xAxisRange.upperBound

                            if optMin > 0 && optMax > optMin {
                                // Optimal range background - more transparent
                                RectangleMark(
                                    xStart: .value("Start", xStart),
                                    xEnd: .value("End", xEnd),
                                    yStart: .value("Min", optMin),
                                    yEnd: .value("Max", optMax)
                                )
                                .foregroundStyle(Color.green.opacity(0.08))

                                // Dotted border lines - thin black
                                RuleMark(y: .value("Optimal Max", optMax))
                                    .foregroundStyle(Color.black.opacity(0.3))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                                RuleMark(y: .value("Optimal Min", optMin))
                                    .foregroundStyle(Color.black.opacity(0.3))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                            } else if optMax > 0 && optMin == 0 {
                                // Optimal range background - more transparent
                                RectangleMark(
                                    xStart: .value("Start", xStart),
                                    xEnd: .value("End", xEnd),
                                    yStart: .value("Min", 0),
                                    yEnd: .value("Max", optMax)
                                )
                                .foregroundStyle(Color.green.opacity(0.08))

                                // Dotted border line at top - thin black
                                RuleMark(y: .value("Optimal Max", optMax))
                                    .foregroundStyle(Color.black.opacity(0.3))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                            } else if optMin > 0 && optMax == 0 {
                                // Only min defined - dotted line - thin black
                                RuleMark(y: .value("Optimal", optMin))
                                    .foregroundStyle(Color.black.opacity(0.3))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            }

                            // Line connecting data points - using metric color
                            ForEach(chartData) { dataPoint in
                                LineMark(
                                    x: .value("Date", dataPoint.date),
                                    y: .value("Value", dataPoint.value)
                                )
                                .foregroundStyle(metricColor)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                            }

                            // Data points - stroke only, no fill
                            ForEach(chartData) { dataPoint in
                                PointMark(
                                    x: .value("Date", dataPoint.date),
                                    y: .value("Value", dataPoint.value)
                                )
                                .foregroundStyle(metricColor)
                                .symbol {
                                    Circle()
                                        .stroke(metricColor, lineWidth: 2)
                                        .frame(width: selectedDataPoint?.id == dataPoint.id ? 12 : 8, height: selectedDataPoint?.id == dataPoint.id ? 12 : 8)
                                }

                                // Selected point annotation
                                if selectedDataPoint?.id == dataPoint.id {
                                    RuleMark(x: .value("Date", dataPoint.date))
                                        .foregroundStyle(metricColor.opacity(0.3))
                                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

                                    PointMark(
                                        x: .value("Date", dataPoint.date),
                                        y: .value("Value", dataPoint.value)
                                    )
                                    .annotation(position: .top, spacing: 8) {
                                        Text(formatValueForDisplay(dataPoint.value))
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                            .padding(6)
                                            .background(Color(uiColor: .systemBackground))
                                            .cornerRadius(6)
                                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                                    }
                                }
                            }
                        }
                        .chartYScale(domain: getChartYDomain())
                        .chartXScale(domain: getXAxisDomain())
                        .chartXAxis {
                            AxisMarks(values: .automatic) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                    .foregroundStyle(Color.secondary.opacity(0.2))
                                AxisValueLabel {
                                    if let date = value.as(Date.self) {
                                        Text(date, format: .dateTime.month(.abbreviated).day())
                                            .foregroundStyle(Color.secondary)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                                    .foregroundStyle(Color.secondary.opacity(0.2))
                                AxisValueLabel {
                                    if let doubleValue = value.as(Double.self) {
                                        Text(formatValueForDisplay(doubleValue))
                                            .foregroundStyle(Color.secondary)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                        .frame(height: 250)
                        .padding()
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    } else {
                        // No data available - show onboarding message
                        VStack(spacing: 16) {
                            Image(systemName: metricIcon)
                                .font(.system(size: 60))
                                .foregroundColor(metricColor.opacity(0.3))

                            VStack(spacing: 8) {
                                Text("No Historical Data")
                                    .font(.headline)

                                Text("Complete your onboarding to see \(isBiometric ? "biometric" : "biomarker") data and track your health over time.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 250)
                        .padding()
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }

                // Recent Records
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Records")
                        .font(.headline)
                        .padding(.horizontal)

                    if !historicalData.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(historicalData) { dataPoint in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        // Date on first line
                                        Text(dataPoint.date, style: .date)
                                            .font(.subheadline)
                                            .fontWeight(.medium)

                                        // Range name pill on its own line to prevent wrapping
                                        let rangeInfo = getRangeNameFor(value: dataPoint.value)
                                        Text(rangeInfo.name)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(getColorForBucket(rangeInfo.bucket).opacity(0.2))
                                            .foregroundColor(getColorForBucket(rangeInfo.bucket))
                                            .cornerRadius(4)
                                            .lineLimit(1)

                                        Text(dataPoint.date, style: .time)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    // Mini trend for this record
                                    MiniTrendIndicator(
                                        current: dataPoint.value,
                                        previous: getPreviousValue(for: dataPoint)
                                    )

                                    Text(formatValueForDisplay(dataPoint.value))
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .frame(minWidth: 60, alignment: .trailing)
                                }
                                .padding()
                                .background(
                                    selectedDataPoint?.id == dataPoint.id ?
                                    metricColor.opacity(0.1) :
                                    Color(uiColor: .tertiarySystemGroupedBackground)
                                )
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            selectedDataPoint?.id == dataPoint.id ?
                                            metricColor :
                                            Color.clear,
                                            lineWidth: 2
                                        )
                                )
                                .onTapGesture {
                                    withAnimation {
                                        selectedDataPoint = dataPoint
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else if !viewModel.isLoading {
                        // No records available - show message
                        Text("No records available yet. Complete your onboarding to start tracking.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .padding(.horizontal, 32)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - About Content View
    private var aboutContentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoadingEducation {
                    ProgressView()
                        .padding()
                } else if educationSections.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 60))
                            .foregroundColor(metricColor.opacity(0.3))

                        VStack(spacing: 8) {
                            Text("No Educational Content")
                                .font(.headline)

                            Text("Educational content for this \(isBiometric ? "biometric" : "biomarker") is not yet available.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    // Display education sections with accordions
                    VStack(spacing: 12) {
                        if isBiometric {
                            ForEach(Array((educationSections as! [BiometricEducationSection]).enumerated()), id: \.element.id) { index, section in
                                EducationAccordionSection(
                                    sectionNumber: index + 1,
                                    title: section.sectionTitle,
                                    content: section.sectionContent,
                                    color: metricColor
                                )
                            }
                        } else {
                            ForEach(Array((educationSections as! [BiomarkerEducationSection]).enumerated()), id: \.element.id) { index, section in
                                EducationAccordionSection(
                                    sectionNumber: index + 1,
                                    title: section.sectionTitle,
                                    content: section.sectionContent,
                                    color: metricColor
                                )
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.vertical)
        }
    }

    // Helper functions
    func getOptimalMin() -> Double {
        // Use converted range for parsing
        let rangeString = convertedOptimalRange()

        // Parse optimal range string (e.g., "< 90 mg/dL" or "1 - 12" or "> 50")
        if rangeString.contains("-") {
            let components = rangeString.components(separatedBy: "-")
            if let min = Double(components[0].trimmingCharacters(in: .whitespaces)) {
                return min
            }
        } else if rangeString.contains("<") {
            // "< X" means 0 to X is optimal
            return 0
        } else if rangeString.contains(">") {
            // "> X" means X to infinity is optimal
            let minString = rangeString
                .replacingOccurrences(of: ">", with: "")
                .components(separatedBy: " ")[0]
                .trimmingCharacters(in: .whitespaces)
            if let min = Double(minString) {
                return min
            }
        }
        return 0
    }

    func getOptimalMax() -> Double {
        // Use converted range for parsing
        let rangeString = convertedOptimalRange()

        // Parse optimal range string
        if rangeString.contains("-") {
            let components = rangeString.components(separatedBy: "-")
            if components.count > 1 {
                // Remove all unit text from the string
                let maxString = components[1]
                    .replacingOccurrences(of: "mg/dL", with: "")
                    .replacingOccurrences(of: "ng/mL", with: "")
                    .replacingOccurrences(of: "pg/mL", with: "")
                    .replacingOccurrences(of: "mIU/L", with: "")
                    .replacingOccurrences(of: "μg/dL", with: "")
                    .replacingOccurrences(of: "%", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if let max = Double(maxString) {
                    return max
                }
            }
        } else if rangeString.contains("<") {
            // "< X" means max is X
            let maxString = rangeString
                .replacingOccurrences(of: "<", with: "")
                .replacingOccurrences(of: "mg/dL", with: "")
                .replacingOccurrences(of: "ng/mL", with: "")
                .replacingOccurrences(of: "pg/mL", with: "")
                .replacingOccurrences(of: "mIU/L", with: "")
                .replacingOccurrences(of: "μg/dL", with: "")
                .replacingOccurrences(of: "%", with: "")
                .trimmingCharacters(in: .whitespaces)
            if let max = Double(maxString) {
                return max
            }
        } else if rangeString.contains(">") {
            // "> X" means no upper bound
            return 0
        }
        return 0
    }

    func getChartYDomain() -> ClosedRange<Double> {
        let allValues = chartData.map { $0.value }
        guard let dataMin = allValues.min(), let dataMax = allValues.max() else {
            return 0...100
        }

        let optMin = getOptimalMin()
        let optMax = getOptimalMax()

        var domainMin: Double
        var domainMax: Double

        if optMin > 0 && optMax > optMin {
            // Both optimal min and max defined
            // Use 20% above max of (dataMax, optMax) and 20% below min of (dataMin, optMin)
            let upperBound = max(dataMax, optMax)
            let lowerBound = min(dataMin, optMin)

            domainMax = upperBound * 1.20
            domainMin = lowerBound * 0.80

        } else if optMax > 0 && optMin == 0 {
            // Only max defined (< X case)
            let upperBound = max(dataMax, optMax)
            domainMax = upperBound * 1.20
            domainMin = min(dataMin, 0) * 0.80

        } else if optMin > 0 && optMax == 0 {
            // Only min defined (> X case) - 50% above, 20% below
            domainMin = min(dataMin, optMin) * 0.80
            domainMax = dataMax * 1.50

        } else {
            // No optimal range - use data values only with 20% buffer
            domainMax = dataMax * 1.20
            domainMin = dataMin * 0.80
        }

        return domainMin...domainMax
    }

    func getXAxisDomain() -> ClosedRange<Date> {
        guard !chartData.isEmpty else {
            return Date()...Date()
        }

        let calendar = Calendar.current
        let firstDate = chartData.first!.date
        let lastDate = chartData.last!.date

        // Handle single data point - add ±7 days padding
        if chartData.count == 1 {
            let startWithBuffer = calendar.date(byAdding: .day, value: -7, to: firstDate) ?? firstDate
            let endWithBuffer = calendar.date(byAdding: .day, value: 7, to: firstDate) ?? firstDate
            return startWithBuffer...endWithBuffer
        }

        // Calculate time span and buffer (10% of the total range, or at least 1 day)
        let timeSpan = lastDate.timeIntervalSince(firstDate)
        let bufferInterval = max(timeSpan * 0.10, 86400) // 10% or 1 day minimum

        let startWithBuffer = firstDate.addingTimeInterval(-bufferInterval)
        let endWithBuffer = lastDate.addingTimeInterval(bufferInterval)

        return startWithBuffer...endWithBuffer
    }

    func formatValueForDisplay(_ value: Double) -> String {
        return String(format: "%.\(decimalPlaces)f", value)
    }

    func getPreviousValue(for dataPoint: BiomarkerDataPoint) -> Double? {
        guard let index = historicalData.firstIndex(where: { $0.id == dataPoint.id }),
              index < historicalData.count - 1 else {
            return nil
        }
        return historicalData[index + 1].value
    }

    func getColorForValue(_ value: Double) -> Color {
        let optMin = getOptimalMin()
        let optMax = getOptimalMax()

        // Determine if value is in optimal, in-range, or out-of-range
        if optMin > 0 && optMax > optMin {
            // Both min and max defined
            if value >= optMin && value <= optMax {
                return .green  // Optimal
            } else {
                // Check if it's within a reasonable "in-range" threshold (e.g., within 20% of optimal)
                let optRange = optMax - optMin
                let lowerInRange = optMin - (optRange * 0.3)
                let upperInRange = optMax + (optRange * 0.3)
                if value >= lowerInRange && value <= upperInRange {
                    return .blue  // In-Range
                }
                return .red  // Out-of-Range
            }
        } else if optMax > 0 && optMin == 0 {
            // Only max defined (< X case)
            if value <= optMax {
                return .green  // Optimal
            } else if value <= optMax * 1.3 {
                return .blue  // In-Range
            }
            return .red  // Out-of-Range
        } else if optMin > 0 && optMax == 0 {
            // Only min defined (> X case)
            if value >= optMin {
                return .green  // Optimal
            } else if value >= optMin * 0.7 {
                return .blue  // In-Range
            }
            return .red  // Out-of-Range
        }

        return .gray
    }

    func getRangeNameFor(value: Double) -> (name: String, bucket: String) {
        if isBiometric {
            if let ranges = rangeDetails as? [BiometricDetail] {
                for range in ranges {
                    var matchesRange = false
                    if let low = range.rangeLow, let high = range.rangeHigh {
                        matchesRange = value >= low && value <= high
                    } else if let low = range.rangeLow, range.rangeHigh == nil {
                        matchesRange = value >= low
                    } else if let high = range.rangeHigh, range.rangeLow == nil {
                        matchesRange = value <= high
                    }
                    if matchesRange {
                        return (name: range.rangeName ?? "Unknown", bucket: range.rangeBucket ?? "Unknown")
                    }
                }
            }
        } else {
            if let ranges = rangeDetails as? [BiomarkerDetail] {
                for range in ranges {
                    var matchesRange = false
                    if let low = range.rangeLow, let high = range.rangeHigh {
                        matchesRange = value >= low && value <= high
                    } else if let low = range.rangeLow, range.rangeHigh == nil {
                        matchesRange = value >= low
                    } else if let high = range.rangeHigh, range.rangeLow == nil {
                        matchesRange = value <= high
                    }
                    if matchesRange {
                        return (name: range.rangeName, bucket: range.rangeBucket ?? "Unknown")
                    }
                }
            }
        }
        return (name: "Unknown", bucket: "Unknown")
    }

    func getColorForBucket(_ bucket: String) -> Color {
        switch bucket {
        case "Out-of-Range": return .red
        case "In-Range": return .blue
        case "Optimal": return .green
        default: return .gray
        }
    }

    // Get threshold values for color transitions
    func getThresholds() -> [Double] {
        let optMin = getOptimalMin()
        let optMax = getOptimalMax()
        var thresholds: [Double] = []

        if optMin > 0 && optMax > optMin {
            let optRange = optMax - optMin
            let lowerInRange = optMin - (optRange * 0.3)
            let upperInRange = optMax + (optRange * 0.3)
            thresholds = [lowerInRange, optMin, optMax, upperInRange]
        } else if optMax > 0 && optMin == 0 {
            let upperInRange = optMax * 1.3
            thresholds = [optMax, upperInRange]
        } else if optMin > 0 && optMax == 0 {
            let lowerInRange = optMin * 0.7
            thresholds = [lowerInRange, optMin]
        }

        return thresholds.filter { $0 > 0 }
    }

    // Interpolate data points at threshold crossings for smooth color transitions
    func getInterpolatedData() -> [BiomarkerDataPoint] {
        guard historicalData.count >= 2 else { return historicalData }

        let thresholds = getThresholds()
        guard !thresholds.isEmpty else { return historicalData }

        var interpolatedData: [BiomarkerDataPoint] = []

        for i in 0..<historicalData.count {
            interpolatedData.append(historicalData[i])

            // Check if there's a next point to interpolate between
            guard i < historicalData.count - 1 else { continue }

            let currentPoint = historicalData[i]
            let nextPoint = historicalData[i + 1]

            // Find thresholds crossed between these two points
            for threshold in thresholds {
                let crossesThreshold = (currentPoint.value < threshold && nextPoint.value >= threshold) ||
                                     (currentPoint.value > threshold && nextPoint.value <= threshold) ||
                                     (currentPoint.value >= threshold && nextPoint.value < threshold) ||
                                     (currentPoint.value <= threshold && nextPoint.value > threshold)

                if crossesThreshold {
                    // Calculate interpolation ratio
                    let valueRange = nextPoint.value - currentPoint.value
                    guard abs(valueRange) > 0.0001 else { continue }

                    let ratio = (threshold - currentPoint.value) / valueRange

                    // Only interpolate if ratio is between 0 and 1 (crossing happens within this segment)
                    if ratio > 0 && ratio < 1 {
                        // Interpolate date
                        let timeInterval = nextPoint.date.timeIntervalSince(currentPoint.date)
                        let interpolatedDate = currentPoint.date.addingTimeInterval(timeInterval * ratio)

                        // Create interpolated point at threshold
                        let interpolatedPoint = BiomarkerDataPoint(
                            date: interpolatedDate,
                            value: threshold
                        )
                        interpolatedData.append(interpolatedPoint)
                    }
                }
            }
        }

        // Sort by date to maintain chronological order
        return interpolatedData.sorted { $0.date < $1.date }
    }

    // MARK: - Education Section Loading

    func loadEducationSections() async {
        isLoadingEducation = true
        defer { isLoadingEducation = false }

        do {
            let supabase = SupabaseManager.shared.client

            if isBiometric {
                let sections: [BiometricEducationSection] = try await supabase
                    .from("biometrics_education_sections")
                    .select()
                    .eq("biometric_name", value: name)
                    .eq("is_active", value: true)
                    .order("display_order", ascending: true)
                    .execute()
                    .value

                educationSections = sections
                print("📚 Loaded \(sections.count) biometric education sections for '\(name)'")
            } else {
                let sections: [BiomarkerEducationSection] = try await supabase
                    .from("biomarkers_education_sections")
                    .select()
                    .eq("biomarker_name", value: name)
                    .eq("is_active", value: true)
                    .order("display_order", ascending: true)
                    .execute()
                    .value

                educationSections = sections
                print("📚 Loaded \(sections.count) biomarker education sections for '\(name)'")
            }
        } catch {
            print("❌ Error loading education sections: \(error)")
        }
    }

    // MARK: - Unit Conversion Helpers

    func loadUnitConversions(for unitId: String) async {
        do {
            // Fetch all conversions for this unit
            availableUnits = try await service.fetchUnitConversions(for: unitId)

            // Build display name dictionary for all units (original + all "to" units)
            unitDisplayNames[unitId] = try await service.getUnitDisplayName(for: unitId)

            for conversion in availableUnits {
                if unitDisplayNames[conversion.toUnit] == nil {
                    unitDisplayNames[conversion.toUnit] = try await service.getUnitDisplayName(for: conversion.toUnit)
                }
            }
        } catch {
            print("❌ Error loading unit conversions: \(error)")
        }
    }

    func convertValue(_ value: Double) -> Double {
        guard selectedUnit != originalUnit else { return value }
        return service.convertValue(value, from: originalUnit, to: selectedUnit, conversions: availableUnits)
    }

    func convertedOptimalRange() -> String {
        guard selectedUnit != originalUnit else { return optimalRange }

        // Parse the optimal range string and convert values
        // Examples: "< 90 mg/dL", "40-60 mg/dL", "> 100 mg/dL"
        let rangeString = optimalRange

        // Extract numbers from the range
        let numberPattern = "\\d+\\.?\\d*"
        guard let regex = try? NSRegularExpression(pattern: numberPattern, options: []) else {
            return optimalRange
        }

        let nsRange = NSRange(rangeString.startIndex..<rangeString.endIndex, in: rangeString)
        let matches = regex.matches(in: rangeString, options: [], range: nsRange)

        var convertedRange = rangeString
        // Convert from last to first to maintain string positions
        for match in matches.reversed() {
            if let range = Range(match.range, in: rangeString),
               let value = Double(rangeString[range]) {
                let converted = convertValue(value)
                let formattedValue = String(format: "%.1f", converted)
                convertedRange = convertedRange.replacingOccurrences(
                    of: String(rangeString[range]),
                    with: formattedValue
                )
            }
        }

        // Replace unit display
        if let oldUnitDisplay = unitDisplayNames[originalUnit],
           let newUnitDisplay = unitDisplayNames[selectedUnit] {
            convertedRange = convertedRange.replacingOccurrences(of: oldUnitDisplay, with: newUnitDisplay)
        }

        return convertedRange
    }
}

struct BiomarkerDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct MiniTrendIndicator: View {
    let current: Double
    let previous: Double?

    var body: some View {
        if let previous = previous {
            let change = current - previous
            HStack(spacing: 2) {
                Image(systemName: change > 0 ? "arrow.up" : change < 0 ? "arrow.down" : "minus")
                    .font(.caption)
                    .foregroundColor(change > 0 ? .red : change < 0 ? .green : .secondary)

                Text(String(format: "%.1f", abs(change)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Info Card Component
struct InfoCard: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)

            Text(content)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

#Preview {
    NavigationView {
        BiomarkerDetailView(
            name: "Apolipoprotein B",
            value: "125 mg/dL",
            status: "High",
            optimalRange: "< 90 mg/dL",
            trend: "Rising past 3 months",
            isBiometric: false
        )
    }
}
