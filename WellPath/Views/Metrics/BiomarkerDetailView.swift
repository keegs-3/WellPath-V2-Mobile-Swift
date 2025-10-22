//
//  BiomarkerDetailView.swift
//  WellPath
//
//  Created on 2025-10-22
//

import SwiftUI
import Charts

enum TimePeriod: String, CaseIterable {
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1Y"
    case all = "All"

    var months: Int? {
        switch self {
        case .threeMonths: return 3
        case .sixMonths: return 6
        case .oneYear: return 12
        case .all: return nil
        }
    }
}

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

    // Always show ALL data - time period filter only controls visible X-axis window
    var chartData: [BiomarkerDataPoint] {
        viewModel.historicalData.sorted { $0.date < $1.date }
    }

    var historicalData: [BiomarkerDataPoint] {
        viewModel.historicalData
    }

    var statusColor: Color {
        switch status {
        case "Out-of-Range": return .red
        case "In-Range": return .blue
        case "Optimal": return .green
        default: return .gray
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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(name)
                                .font(.title)
                                .foregroundColor(.white)

                            HStack(spacing: 8) {
                                Text(value)
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)

                                Text(status)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(statusColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                        }

                        Spacer()
                    }

                    Divider()
                        .background(Color.white.opacity(0.3))

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Optimal Range:")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Text(optimalRange)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }

                        HStack {
                            Text("Trend:")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Text(trend)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }

                        HStack {
                            Text("Last Measured:")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Text(viewModel.historicalData.first?.date ?? Date(), style: .date)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)

                // Time Period Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(TimePeriod.allCases, id: \.self) { period in
                            Button(action: {
                                selectedPeriod = period
                            }) {
                                Text(period.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(selectedPeriod == period ? .semibold : .regular)
                                    .foregroundColor(selectedPeriod == period ? .black : .white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedPeriod == period ? Color.white : Color.white.opacity(0.2))
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // History Chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("History")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal)

                    if !chartData.isEmpty {
                        // Use SwiftUI Charts scrollable feature - Y-axis stays fixed, chart scrolls
                        Chart {
                            // Optimal range band
                            let optMin = getOptimalMin()
                            let optMax = getOptimalMax()

                            if optMin > 0 && optMax > optMin {
                                // Both min and max defined
                                RectangleMark(
                                    xStart: .value("Start", chartData.first?.date ?? Date()),
                                    xEnd: .value("End", chartData.last?.date ?? Date()),
                                    yStart: .value("Min", optMin),
                                    yEnd: .value("Max", optMax)
                                )
                                .foregroundStyle(Color.green.opacity(0.25))
                            } else if optMax > 0 && optMin == 0 {
                                // Only max defined (< X case)
                                RectangleMark(
                                    xStart: .value("Start", chartData.first?.date ?? Date()),
                                    xEnd: .value("End", chartData.last?.date ?? Date()),
                                    yStart: .value("Min", 0),
                                    yEnd: .value("Max", optMax)
                                )
                                .foregroundStyle(Color.green.opacity(0.25))
                            } else if optMin > 0 && optMax == 0 {
                                // Only min defined (> X case) - draw line
                                RuleMark(y: .value("Optimal", optMin))
                                    .foregroundStyle(Color.green.opacity(0.8))
                                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                            }

                            // Simple grey line connecting all data points
                            ForEach(chartData) { dataPoint in
                                LineMark(
                                    x: .value("Date", dataPoint.date),
                                    y: .value("Value", dataPoint.value)
                                )
                                .foregroundStyle(Color.white.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 3))
                            }

                            // Data points with color coding
                            ForEach(chartData) { dataPoint in
                                PointMark(
                                    x: .value("Date", dataPoint.date),
                                    y: .value("Value", dataPoint.value)
                                )
                                .foregroundStyle(selectedDataPoint?.id == dataPoint.id ? Color.white : getColorForValue(dataPoint.value))
                                .symbol {
                                    Circle()
                                        .fill(selectedDataPoint?.id == dataPoint.id ? Color.white : getColorForValue(dataPoint.value))
                                        .frame(width: selectedDataPoint?.id == dataPoint.id ? 12 : 8, height: selectedDataPoint?.id == dataPoint.id ? 12 : 8)
                                }

                                // Show vertical line and value label for selected point
                                if selectedDataPoint?.id == dataPoint.id {
                                    RuleMark(x: .value("Date", dataPoint.date))
                                        .foregroundStyle(Color.white.opacity(0.3))
                                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

                                    // Value label next to the point
                                    PointMark(
                                        x: .value("Date", dataPoint.date),
                                        y: .value("Value", dataPoint.value)
                                    )
                                    .annotation(position: .top, spacing: 8) {
                                        Text(formatValueForDisplay(dataPoint.value))
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(6)
                                            .background(Color.black.opacity(0.8))
                                            .cornerRadius(6)
                                    }
                                }
                            }
                        }
                        .chartYScale(domain: getChartYDomain())
                        .chartScrollableAxes(.horizontal)  // Y-axis fixed, X-axis scrolls
                        .chartXVisibleDomain(length: getVisibleDomainLength())  // Sets visible window based on filter
                        .chartXAxis {
                            AxisMarks(values: .automatic) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                                    .foregroundStyle(Color.white.opacity(0.2))
                                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                    .foregroundStyle(Color.white.opacity(0.7))
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                                    .foregroundStyle(Color.white.opacity(0.2))
                                AxisValueLabel {
                                    if let doubleValue = value.as(Double.self) {
                                        Text(formatValueForDisplay(doubleValue))
                                            .foregroundStyle(Color.white.opacity(0.7))
                                    }
                                }
                            }
                        }
                        .frame(height: 250)
                        .padding(.vertical, 20)
                        .padding(.horizontal, 16)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(12)
                    } else {
                        Text("Loading historical data...")
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(12)
                    }
                }

                // Recent Records
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Records")
                        .font(.headline)
                        .foregroundColor(.white)
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
                                            .foregroundColor(.white)

                                        // Range name pill on its own line to prevent wrapping
                                        let rangeInfo = getRangeNameFor(value: dataPoint.value)
                                        Text(rangeInfo.name)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(getColorForBucket(rangeInfo.bucket))
                                            .foregroundColor(.white)
                                            .cornerRadius(4)
                                            .lineLimit(1)

                                        Text(dataPoint.date, style: .time)
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.6))
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
                                        .foregroundColor(.white)
                                        .frame(minWidth: 60, alignment: .trailing)
                                }
                                .padding()
                                .background(
                                    selectedDataPoint?.id == dataPoint.id ?
                                    Color.white.opacity(0.2) :
                                    Color.black.opacity(0.3)
                                )
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            selectedDataPoint?.id == dataPoint.id ?
                                            Color.white.opacity(0.5) :
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
                    }
                }

                // Information Sections
                if let biomarkerBase = baseInfo as? BiomarkerBase {
                    // About Why
                    if let aboutWhy = biomarkerBase.aboutWhy, !aboutWhy.isEmpty {
                        InfoCard(title: "About \(name)", content: aboutWhy)
                    }

                    // Optimal Target
                    if let aboutOptimalTarget = biomarkerBase.aboutOptimalTarget, !aboutOptimalTarget.isEmpty {
                        InfoCard(title: "Optimal Range", content: aboutOptimalTarget)
                    }

                    // Quick Tips
                    if let aboutQuickTips = biomarkerBase.aboutQuickTips, !aboutQuickTips.isEmpty {
                        InfoCard(title: "Quick Tips", content: aboutQuickTips)
                    }
                } else if let biometricsBase = baseInfo as? BiometricsBase {
                    // About Why
                    if let aboutWhy = biometricsBase.aboutWhy, !aboutWhy.isEmpty {
                        InfoCard(title: "About \(name)", content: aboutWhy)
                    }

                    // Optimal Range
                    if let aboutOptimalRange = biometricsBase.aboutOptimalRange, !aboutOptimalRange.isEmpty {
                        InfoCard(title: "Optimal Range", content: aboutOptimalRange)
                    }

                    // Quick Tips
                    if let aboutQuickTips = biometricsBase.aboutQuickTips, !aboutQuickTips.isEmpty {
                        InfoCard(title: "Quick Tips", content: aboutQuickTips)
                    }
                }
            }
            .padding()
        }
        .background(
            Image("MetricsDetailBg")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // Clear selection when tapping outside
            withAnimation {
                selectedDataPoint = nil
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(name)
        .task {
            print("🔍 BiomarkerDetailView loading for: '\(name)' (isBiometric: \(isBiometric))")
            await viewModel.loadHistory(for: name, isBiometric: isBiometric)
            // Load range details and base information
            do {
                if isBiometric {
                    print("🔍 Fetching biometric details for: '\(name)'")
                    rangeDetails = try await service.fetchBiometricDetails(for: name)
                    baseInfo = try await service.fetchBiometricsBase(for: name)
                } else {
                    print("🔍 Fetching biomarker details for: '\(name)'")
                    rangeDetails = try await service.fetchBiomarkerDetails(for: name)
                    let fetchedBase = try await service.fetchBiomarkerBase(for: name)
                    print("🔍 Fetched biomarker base: \(fetchedBase?.biomarkerName ?? "nil")")
                    baseInfo = fetchedBase
                }
            } catch {
                print("❌ Error loading range details: \(error)")
            }
        }
    }

    // Helper functions
    func getVisibleDomainLength() -> TimeInterval {
        guard let months = selectedPeriod.months else {
            // For "All", return total seconds in the data range
            guard let earliest = historicalData.map({ $0.date }).min(),
                  let latest = historicalData.map({ $0.date }).max() else {
                return 90 * 24 * 60 * 60 // Default to 90 days in seconds if no data
            }
            return latest.timeIntervalSince(earliest)
        }

        // Return the number of seconds for the selected period
        let days = Double(months) * 30.4
        return days * 24 * 60 * 60 // Convert days to seconds
    }

    func getOptimalMin() -> Double {
        // Parse optimal range string (e.g., "< 90 mg/dL" or "1 - 12" or "> 50")
        if optimalRange.contains("-") {
            let components = optimalRange.components(separatedBy: "-")
            if let min = Double(components[0].trimmingCharacters(in: .whitespaces)) {
                return min
            }
        } else if optimalRange.contains("<") {
            // "< X" means 0 to X is optimal
            return 0
        } else if optimalRange.contains(">") {
            // "> X" means X to infinity is optimal
            let minString = optimalRange
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
        // Parse optimal range string
        if optimalRange.contains("-") {
            let components = optimalRange.components(separatedBy: "-")
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
        } else if optimalRange.contains("<") {
            // "< X" means max is X
            let maxString = optimalRange
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
        } else if optimalRange.contains(">") {
            // "> X" means no upper bound
            return 0
        }
        return 0
    }

    func getChartYDomain() -> ClosedRange<Double> {
        let allValues = chartData.map { $0.value }
        let dataMin = allValues.min() ?? 0
        let dataMax = allValues.max() ?? 100
        let optMin = getOptimalMin()
        let optMax = getOptimalMax()

        // Calculate range based on optimal or data values
        var domainMin: Double
        var domainMax: Double

        if optMin > 0 && optMax > optMin {
            // Both optimal min and max defined - use ±20% of optimal range
            let optimalRange = optMax - optMin
            let padding = optimalRange * 0.2
            domainMin = optMin - padding
            domainMax = optMax + padding
            // Also include data values
            domainMin = min(domainMin, dataMin - padding)
            domainMax = max(domainMax, dataMax + padding)
        } else if optMax > 0 && optMin == 0 {
            // Only max defined (< X case) - use ±20% of max value
            let padding = optMax * 0.2
            domainMin = 0
            domainMax = optMax + padding
            domainMax = max(domainMax, dataMax + padding)
        } else if optMin > 0 && optMax == 0 {
            // Only min defined (> X case) - use ±20% of min value
            let padding = optMin * 0.2
            domainMin = optMin - padding
            domainMax = max(dataMax, optMin * 1.5)
        } else {
            // No optimal range - use ±20% of data values
            let dataRange = dataMax - dataMin
            let padding = dataRange * 0.2
            domainMin = dataMin - padding
            domainMax = dataMax + padding
        }

        // Ensure we have a reasonable range
        if domainMax - domainMin < 1 {
            domainMin -= 0.5
            domainMax += 0.5
        }

        return domainMin...domainMax
    }

    func formatValueForDisplay(_ value: Double) -> String {
        return String(format: "%.\(decimalPlaces)f", value)
    }

    // X-axis shows rolling window from today going back based on selected period
    func getChartXMin() -> Date {
        // If a specific time period is selected, show that period from today
        if let months = selectedPeriod.months {
            return Calendar.current.date(byAdding: .month, value: -months, to: Date()) ?? Date()
        }

        // For "All", use the actual data range with padding
        guard let earliestDate = historicalData.map({ $0.date }).min(),
              let latestDate = historicalData.map({ $0.date }).max() else {
            return Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        }
        let calendar = Calendar.current
        let daysBetween = calendar.dateComponents([.day], from: earliestDate, to: latestDate).day ?? 0
        let padding = max(7, Int(Double(daysBetween) * 0.1))
        return calendar.date(byAdding: .day, value: -padding, to: earliestDate) ?? earliestDate
    }

    func getChartXMax() -> Date {
        // If a specific time period is selected, always end at today
        if selectedPeriod.months != nil {
            return Date()
        }

        // For "All", use the actual data range with padding
        guard let earliestDate = historicalData.map({ $0.date }).min(),
              let latestDate = historicalData.map({ $0.date }).max() else {
            return Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        }
        let calendar = Calendar.current
        let daysBetween = calendar.dateComponents([.day], from: earliestDate, to: latestDate).day ?? 0
        let padding = max(7, Int(Double(daysBetween) * 0.1))
        return calendar.date(byAdding: .day, value: padding, to: latestDate) ?? latestDate
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
                    .foregroundColor(change > 0 ? .red : change < 0 ? .green : .white.opacity(0.6))

                Text(String(format: "%.1f", abs(change)))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
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
