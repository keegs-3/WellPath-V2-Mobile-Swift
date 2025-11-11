//
//  BiomarkerComparisonChart.swift
//  WellPath
//
//  Comparison charts for biomarkers with reference ranges, trends, and multi-metric views
//

import SwiftUI
import Charts

// MARK: - Models

struct BiomarkerReading: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let biomarker: Biomarker
    let source: String? // "Lab Test", "Wearable", etc.
}

struct Biomarker: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let unit: String
    let referenceRange: ClosedRange<Double>
    let optimalRange: ClosedRange<Double>?
    let color: Color
    
    func status(for value: Double) -> BiomarkerStatus {
        if let optimal = optimalRange, optimal.contains(value) {
            return .optimal
        } else if referenceRange.contains(value) {
            return .normal
        } else if value < referenceRange.lowerBound {
            return .low
        } else {
            return .high
        }
    }
}

enum BiomarkerStatus {
    case optimal, normal, low, high
    
    var color: Color {
        switch self {
        case .optimal: return .green
        case .normal: return .blue
        case .low: return .orange
        case .high: return .red
        }
    }
    
    var label: String {
        switch self {
        case .optimal: return "Optimal"
        case .normal: return "Normal"
        case .low: return "Low"
        case .high: return "High"
        }
    }
}

// MARK: - Biomarker Comparison Chart

struct BiomarkerComparisonChart: View {
    let readings: [BiomarkerReading]
    let selectedBiomarkers: [Biomarker]
    
    @State private var selectedPeriod: TimePeriod = .month
    @State private var scrollPosition: Date?
    @State private var selectedReading: BiomarkerReading?
    @State private var showReferenceRanges = true
    @State private var chartType: ComparisonChartType = .line
    
    enum ComparisonChartType: String, CaseIterable {
        case line = "Trend"
        case bar = "Compare"
        case scatter = "Distribution"
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Controls
            controlsSection
            
            // Chart
            chartSection
            
            // Latest values summary
            latestValuesSummary
            
            // Stats
            if let selected = selectedReading {
                readingDetailCard(selected)
            }
        }
        .padding()
    }
    
    // MARK: - Controls
    
    private var controlsSection: some View {
        VStack(spacing: 12) {
            // Period selector
            HStack(spacing: 8) {
                ForEach(TimePeriod.allCases) { period in
                    Button(action: {
                        withAnimation {
                            selectedPeriod = period
                        }
                    }) {
                        Text(period.rawValue)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundColor(selectedPeriod == period ? .white : .primary)
                            .frame(width: 36, height: 28)
                            .background(
                                selectedPeriod == period ?
                                    Color.blue : Color.gray.opacity(0.1)
                            )
                            .cornerRadius(6)
                    }
                }
            }
            
            // Chart type picker
            Picker("Chart Type", selection: $chartType) {
                ForEach(ComparisonChartType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            
            // Toggle reference ranges
            Toggle("Show Reference Ranges", isOn: $showReferenceRanges)
                .font(.caption)
        }
    }
    
    // MARK: - Chart Section
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Biomarker Trends")
                .font(.headline)
            
            Group {
                switch chartType {
                case .line:
                    trendChart
                case .bar:
                    comparisonBarChart
                case .scatter:
                    distributionChart
                }
            }
            .frame(height: 300)
        }
    }
    
    // MARK: - Trend Chart (Line)
    
    private var trendChart: some View {
        Chart {
            ForEach(selectedBiomarkers) { biomarker in
                let biomarkerReadings = readings.filter { $0.biomarker.id == biomarker.id }
                
                // Reference ranges
                if showReferenceRanges {
                    RectangleMark(
                        xStart: .value("Start", selectedPeriod.dateRange.lowerBound),
                        xEnd: .value("End", selectedPeriod.dateRange.upperBound),
                        yStart: .value("Lower", biomarker.referenceRange.lowerBound),
                        yEnd: .value("Upper", biomarker.referenceRange.upperBound)
                    )
                    .foregroundStyle(biomarker.color.opacity(0.1))
                    
                    // Optimal range
                    if let optimal = biomarker.optimalRange {
                        RectangleMark(
                            xStart: .value("Start", selectedPeriod.dateRange.lowerBound),
                            xEnd: .value("End", selectedPeriod.dateRange.upperBound),
                            yStart: .value("Lower", optimal.lowerBound),
                            yEnd: .value("Upper", optimal.upperBound)
                        )
                        .foregroundStyle(Color.green.opacity(0.08))
                    }
                }
                
                // Data line
                ForEach(biomarkerReadings) { reading in
                    LineMark(
                        x: .value("Date", reading.date),
                        y: .value("Value", reading.value)
                    )
                    .foregroundStyle(by: .value("Biomarker", biomarker.name))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                    
                    PointMark(
                        x: .value("Date", reading.date),
                        y: .value("Value", reading.value)
                    )
                    .foregroundStyle(by: .value("Biomarker", biomarker.name))
                    .symbolSize(50)
                }
            }
            
            // Selection indicator
            if let selected = selectedReading {
                RuleMark(x: .value("Selected", selected.date))
                    .foregroundStyle(Color.gray.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
        .chartForegroundStyleScale(
            Dictionary(uniqueKeysWithValues: selectedBiomarkers.map { ($0.name, $0.color) })
        )
        .chartXAxis {
            AxisMarks(values: .stride(by: selectedPeriod.xAxisStride)) { value in
                AxisGridLine()
                AxisValueLabel(format: selectedPeriod.xAxisFormat)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartLegend(position: .bottom, alignment: .leading)
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: selectedPeriod.visibleDomain)
        .chartScrollPosition(x: $scrollPosition)
        .chartXSelection(value: $selectedReading, by: \.date)
    }
    
    // MARK: - Comparison Bar Chart
    
    private var comparisonBarChart: some View {
        Chart {
            ForEach(selectedBiomarkers) { biomarker in
                if let latest = readings.filter({ $0.biomarker.id == biomarker.id }).sorted(by: { $0.date > $1.date }).first {
                    BarMark(
                        x: .value("Biomarker", biomarker.name),
                        y: .value("Value", normalizedValue(latest.value, for: biomarker))
                    )
                    .foregroundStyle(biomarker.status(for: latest.value).color)
                    .annotation(position: .top) {
                        VStack(spacing: 2) {
                            Text("\(latest.value, format: .number.precision(.fractionLength(1)))")
                                .font(.caption2)
                                .fontWeight(.semibold)
                            Text(biomarker.unit)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Reference line at 100% (optimal)
                    RuleMark(y: .value("Optimal", 100))
                        .foregroundStyle(Color.green.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
            }
        }
        .chartYScale(domain: 0...150)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let intValue = value.as(Int.self) {
                        Text("\(intValue)%")
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let name = value.as(String.self) {
                        Text(name)
                            .font(.caption)
                            .rotationEffect(.degrees(-45))
                    }
                }
            }
        }
    }
    
    // MARK: - Distribution Chart (Scatter)
    
    private var distributionChart: some View {
        Chart {
            ForEach(selectedBiomarkers) { biomarker in
                let biomarkerReadings = readings.filter { $0.biomarker.id == biomarker.id }
                
                // Reference range box
                if showReferenceRanges {
                    RectangleMark(
                        x: .value("Biomarker", biomarker.name),
                        yStart: .value("Lower", biomarker.referenceRange.lowerBound),
                        yEnd: .value("Upper", biomarker.referenceRange.upperBound),
                        width: .ratio(0.8)
                    )
                    .foregroundStyle(Color.gray.opacity(0.1))
                }
                
                // Data points
                ForEach(biomarkerReadings) { reading in
                    PointMark(
                        x: .value("Biomarker", biomarker.name),
                        y: .value("Value", reading.value)
                    )
                    .foregroundStyle(biomarker.status(for: reading.value).color)
                    .symbolSize(40)
                    .opacity(0.7)
                }
                
                // Mean line
                if let mean = calculateMean(for: biomarkerReadings) {
                    RuleMark(
                        xStart: .value("Start", biomarker.name),
                        xEnd: .value("End", biomarker.name),
                        y: .value("Mean", mean)
                    )
                    .foregroundStyle(biomarker.color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let name = value.as(String.self) {
                        Text(name)
                            .font(.caption)
                    }
                }
            }
        }
    }
    
    // MARK: - Latest Values Summary
    
    private var latestValuesSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Latest Values")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            ForEach(selectedBiomarkers) { biomarker in
                if let latest = readings.filter({ $0.biomarker.id == biomarker.id }).sorted(by: { $0.date > $1.date }).first {
                    biomarkerSummaryRow(biomarker: biomarker, reading: latest)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func biomarkerSummaryRow(biomarker: Biomarker, reading: BiomarkerReading) -> some View {
        HStack {
            Circle()
                .fill(biomarker.color)
                .frame(width: 8, height: 8)
            
            Text(biomarker.name)
                .font(.caption)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(reading.value, format: .number.precision(.fractionLength(1))) \(biomarker.unit)")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text(biomarker.status(for: reading.value).label)
                    .font(.caption2)
                    .foregroundColor(biomarker.status(for: reading.value).color)
            }
        }
    }
    
    // MARK: - Reading Detail Card
    
    private func readingDetailCard(_ reading: BiomarkerReading) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reading.biomarker.name)
                        .font(.headline)
                    Text(reading.date, format: .dateTime.month().day().year())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(reading.value, format: .number.precision(.fractionLength(1)))")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(reading.biomarker.unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Status indicator
            HStack {
                Text("Status:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(reading.biomarker.status(for: reading.value).label)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(reading.biomarker.status(for: reading.value).color)
                
                Spacer()
                
                if let source = reading.source {
                    Text(source)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Reference range
            VStack(alignment: .leading, spacing: 4) {
                Text("Reference Range")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("\(reading.biomarker.referenceRange.lowerBound, format: .number) - \(reading.biomarker.referenceRange.upperBound, format: .number) \(reading.biomarker.unit)")
                        .font(.caption)
                    
                    if let optimal = reading.biomarker.optimalRange {
                        Text("(Optimal: \(optimal.lowerBound, format: .number) - \(optimal.upperBound, format: .number))")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Helpers
    
    private func normalizedValue(_ value: Double, for biomarker: Biomarker) -> Double {
        // Normalize to percentage of optimal range
        if let optimal = biomarker.optimalRange {
            let midpoint = (optimal.lowerBound + optimal.upperBound) / 2
            return (value / midpoint) * 100
        } else {
            let midpoint = (biomarker.referenceRange.lowerBound + biomarker.referenceRange.upperBound) / 2
            return (value / midpoint) * 100
        }
    }
    
    private func calculateMean(for readings: [BiomarkerReading]) -> Double? {
        guard !readings.isEmpty else { return nil }
        return readings.map(\.value).reduce(0, +) / Double(readings.count)
    }
}

// MARK: - Preview

#Preview {
    BiomarkerComparisonChart(
        readings: generateMockBiomarkerReadings(),
        selectedBiomarkers: mockBiomarkers
    )
}

// MARK: - Mock Data

let mockBiomarkers: [Biomarker] = [
    Biomarker(
        name: "Vitamin D",
        unit: "ng/mL",
        referenceRange: 20...50,
        optimalRange: 40...60,
        color: .orange
    ),
    Biomarker(
        name: "HbA1c",
        unit: "%",
        referenceRange: 4...5.7,
        optimalRange: 4...5.4,
        color: .red
    ),
    Biomarker(
        name: "HDL",
        unit: "mg/dL",
        referenceRange: 40...60,
        optimalRange: 60...80,
        color: .green
    )
]

func generateMockBiomarkerReadings() -> [BiomarkerReading] {
    var readings: [BiomarkerReading] = []
    let calendar = Calendar.current
    
    for biomarker in mockBiomarkers {
        for i in 0..<12 {
            let date = calendar.date(byAdding: .month, value: -i, to: Date())!
            let baseValue = (biomarker.referenceRange.lowerBound + biomarker.referenceRange.upperBound) / 2
            let variation = Double.random(in: -10...10)
            
            readings.append(BiomarkerReading(
                date: date,
                value: baseValue + variation,
                biomarker: biomarker,
                source: i % 3 == 0 ? "Lab Test" : "Estimated"
            ))
        }
    }
    
    return readings
}
