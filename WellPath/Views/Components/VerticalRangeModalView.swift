//
//  VerticalRangeModalView.swift
//  WellPath
//
//  Compact range indicator sheet with horizontal bar
//

import SwiftUI

struct RangeSegmentDetail: Identifiable {
    let id = UUID()
    let rangeName: String
    let rangeBucket: String
    let rangeLow: Double
    let rangeHigh: Double
    let displayLow: Double
    let displayHigh: Double
    let frontendDisplay: String?
    let containsValue: Bool
    let isFirstTier: Bool
    let isLastTier: Bool

    init(rangeName: String, rangeBucket: String, rangeLow: Double, rangeHigh: Double,
         frontendDisplay: String?, containsValue: Bool,
         displayLow: Double? = nil, displayHigh: Double? = nil,
         isFirstTier: Bool = false, isLastTier: Bool = false) {
        self.rangeName = rangeName
        self.rangeBucket = rangeBucket
        self.rangeLow = rangeLow
        self.rangeHigh = rangeHigh
        self.displayLow = displayLow ?? rangeLow
        self.displayHigh = displayHigh ?? rangeHigh
        self.frontendDisplay = frontendDisplay
        self.containsValue = containsValue
        self.isFirstTier = isFirstTier
        self.isLastTier = isLastTier
    }

    /// Returns the appropriate color for this segment based on bucket type
    func color(isActive: Bool) -> Color {
        guard isActive else {
            return Color(UIColor.systemGray4)  // Neutral gray for inactive
        }
        switch rangeBucket.uppercased() {
        case "OPTIMAL":
            return .green
        case "IN RANGE", "IN-RANGE":
            return .blue
        default:  // "OUT OF RANGE", "OUT-OF-RANGE"
            return .red
        }
    }

    /// Legacy color property for backward compatibility (assumes active)
    var color: Color {
        color(isActive: containsValue)
    }
}

// MARK: - Range Display Calculator

/// Helper for calculating which bands to show and their widths
struct RangeDisplayCalculator {

    /// Selects 3 visible bands for mini charts based on patient position and directionality
    /// - For optimal_range (5 tiers): shows patient's band + adjacent bands
    /// - For lower_better/higher_better (3 tiers): shows all 3
    static func selectVisibleBands(
        allSegments: [RangeSegmentDetail],
        patientValue: Double,
        directionality: String
    ) -> [RangeSegmentDetail] {
        let sorted = allSegments.sorted { $0.rangeLow < $1.rangeLow }

        // For 3-tier directionality, show all
        if directionality == "lower_better" || directionality == "higher_better" || sorted.count <= 3 {
            return sorted
        }

        // Find which segment contains the patient value
        guard let patientIndex = sorted.firstIndex(where: { $0.containsValue }) else {
            // Fallback: find by value
            if let idx = sorted.firstIndex(where: { patientValue >= $0.rangeLow && patientValue <= $0.rangeHigh }) {
                return selectThreeBandsAround(sorted: sorted, centerIndex: idx)
            }
            // Last resort: return first 3
            return Array(sorted.prefix(3))
        }

        return selectThreeBandsAround(sorted: sorted, centerIndex: patientIndex)
    }

    /// Selects 3 bands centered around the given index
    private static func selectThreeBandsAround(sorted: [RangeSegmentDetail], centerIndex: Int) -> [RangeSegmentDetail] {
        let count = sorted.count

        // Determine the range of indices to show
        var startIndex: Int
        var endIndex: Int

        if centerIndex == 0 {
            // At the low end - show first 3
            startIndex = 0
            endIndex = min(2, count - 1)
        } else if centerIndex == count - 1 {
            // At the high end - show last 3
            startIndex = max(0, count - 3)
            endIndex = count - 1
        } else {
            // In the middle - show one on each side
            startIndex = centerIndex - 1
            endIndex = centerIndex + 1
        }

        return Array(sorted[startIndex...endIndex])
    }

    /// Calculates value-centered widths using a view window approach
    /// Shows meaningful context around patient value, not artificial bounds
    static func calculateValueCenteredWidths(
        segments: [RangeSegmentDetail],
        patientValue: Double,
        totalWidth: CGFloat,
        zoomFactor: CGFloat = 1.2
    ) -> [(segment: RangeSegmentDetail, width: CGFloat)] {
        guard !segments.isEmpty else { return [] }

        let sorted = segments.sorted { $0.rangeLow < $1.rangeLow }
        let spacing: CGFloat = 1.0
        let availableWidth = totalWidth - (CGFloat(sorted.count - 1) * spacing)

        // Find which segment contains the patient value
        let patientIndex = sorted.firstIndex { $0.containsValue } ??
            sorted.firstIndex { patientValue >= $0.rangeLow && patientValue <= $0.rangeHigh } ?? 0

        // Calculate context buffer based on non-artificial segment widths
        var contextBuffer: Double = 0
        for segment in sorted {
            if !segment.isFirstTier && !segment.isLastTier {
                // Middle segments are not artificial
                let segmentWidth = segment.rangeHigh - segment.rangeLow
                contextBuffer = max(contextBuffer, segmentWidth)
            } else {
                // First/last tiers might be artificial - use display bounds
                let segmentWidth = segment.displayHigh - segment.displayLow
                if segmentWidth < 1000 { // Only use if reasonable
                    contextBuffer = max(contextBuffer, segmentWidth)
                }
            }
        }
        // If no good context buffer found, use a reasonable default
        if contextBuffer == 0 {
            contextBuffer = 50
        }

        // View window centered on patient value
        let viewMin = patientValue - contextBuffer
        let viewMax = patientValue + contextBuffer

        // Calculate visible portion of each segment within the view window
        var visibleWidths: [Double] = []
        for segment in sorted {
            let clippedLow = max(segment.rangeLow, viewMin)
            let clippedHigh = min(segment.rangeHigh, viewMax)
            let visibleWidth = max(0, clippedHigh - clippedLow)
            visibleWidths.append(visibleWidth)
        }

        // Ensure each segment gets at least minimum visibility
        let minVisibleWidth = contextBuffer * 0.15
        for i in 0..<visibleWidths.count {
            if visibleWidths[i] < minVisibleWidth && visibleWidths[i] > 0 {
                visibleWidths[i] = minVisibleWidth
            } else if visibleWidths[i] == 0 {
                visibleWidths[i] = minVisibleWidth * 0.5
            }
        }

        // Convert to proportional widths
        let totalVisibleWidth = visibleWidths.reduce(0, +)
        guard totalVisibleWidth > 0 else {
            let equalWidth = availableWidth / CGFloat(sorted.count)
            return sorted.map { ($0, equalWidth) }
        }

        var results: [(segment: RangeSegmentDetail, width: CGFloat)] = []
        for (index, segment) in sorted.enumerated() {
            let proportion = visibleWidths[index] / totalVisibleWidth
            let width = availableWidth * CGFloat(proportion)
            results.append((segment: segment, width: max(width, 4)))
        }

        return results
    }

    /// Calculates hybrid proportional widths for big charts
    /// Patient's segment gets at least minPatientWidthRatio of the width
    static func calculateHybridWidths(
        segments: [RangeSegmentDetail],
        patientValue: Double,
        totalWidth: CGFloat,
        minPatientWidthRatio: CGFloat = 0.35
    ) -> [(segment: RangeSegmentDetail, width: CGFloat)] {
        guard !segments.isEmpty else { return [] }

        let sorted = segments.sorted { $0.rangeLow < $1.rangeLow }
        let spacing: CGFloat = 2.0
        let availableWidth = totalWidth - (CGFloat(sorted.count - 1) * spacing)

        // Find patient segment
        let patientIndex = sorted.firstIndex { $0.containsValue } ??
            sorted.firstIndex { patientValue >= $0.rangeLow && patientValue <= $0.rangeHigh } ?? 0

        // Calculate weights: patient segment gets boosted weight to achieve minPatientWidthRatio
        // With 3 segments and 35% for patient, others share 65% (32.5% each)
        // So patient weight = 0.35, other weight = 0.325 each
        // Normalized: patient = 0.35/(0.35+0.325+0.325) = 0.35/1.0 = 35%
        let otherCount = sorted.count - 1
        let otherTotalRatio = 1.0 - minPatientWidthRatio
        let otherEachRatio = otherCount > 0 ? otherTotalRatio / CGFloat(otherCount) : 0

        var results: [(segment: RangeSegmentDetail, width: CGFloat)] = []
        for (index, segment) in sorted.enumerated() {
            let ratio = (index == patientIndex) ? minPatientWidthRatio : otherEachRatio
            let width = availableWidth * ratio
            results.append((segment: segment, width: max(width, 4)))
        }

        return results
    }
}

struct VerticalRangeModalView: View {
    let metricName: String
    let currentValue: Double?
    let unit: String
    let segments: [RangeSegmentDetail]
    let metricColor: Color
    let directionality: String
    @Environment(\.dismiss) var dismiss

    @State private var selectedSegment: RangeSegmentDetail?
    @State private var barWidth: CGFloat = 0

    // Convenience initializer for backward compatibility
    init(metricName: String, currentValue: Double?, unit: String, segments: [RangeSegmentDetail], metricColor: Color, directionality: String = "optimal_range") {
        self.metricName = metricName
        self.currentValue = currentValue
        self.unit = unit
        self.segments = segments
        self.metricColor = metricColor
        self.directionality = directionality
    }

    private var sortedSegments: [RangeSegmentDetail] {
        segments.sorted { $0.rangeLow < $1.rangeLow }
    }

    private var patientSegment: RangeSegmentDetail? {
        guard currentValue != nil else { return nil }
        return segments.first(where: { $0.containsValue })
    }

    private var hasData: Bool {
        currentValue != nil && patientSegment != nil
    }

    private var chartMin: Double {
        sortedSegments.first?.displayLow ?? 0
    }

    private var chartMax: Double {
        sortedSegments.last?.displayHigh ?? 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header row with metric name and close button
            HStack {
                Text(metricName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }

            // Value display
            if let value = currentValue, hasData {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatValue(value))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(metricColor)

                    Text(unit)
                        .font(.subheadline)
                        .foregroundColor(metricColor.opacity(0.7))
                }
            } else {
                Text("No Data")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            // Range bar with label
            VStack(spacing: 6) {
                // Label positioned over the patient's segment
                GeometryReader { geometry in
                    if hasData, let segment = patientSegment {
                        let segmentWidths = RangeDisplayCalculator.calculateHybridWidths(
                            segments: sortedSegments,
                            patientValue: currentValue ?? 0,
                            totalWidth: geometry.size.width,
                            minPatientWidthRatio: 0.35
                        )
                        let labelPosition = calculateLabelPosition(for: segment, in: geometry.size.width, segmentWidths: segmentWidths)

                        Text(segment.rangeName.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                            .fixedSize()
                            .position(x: labelPosition, y: 6)
                    }
                }
                .frame(height: 14)

                // The horizontal bar
                GeometryReader { geometry in
                    let segmentWidths = RangeDisplayCalculator.calculateHybridWidths(
                        segments: sortedSegments,
                        patientValue: currentValue ?? 0,
                        totalWidth: geometry.size.width,
                        minPatientWidthRatio: 0.35
                    )

                    ZStack(alignment: .leading) {
                        // Segments using hybrid widths
                        HStack(spacing: 2) {
                            ForEach(segmentWidths, id: \.segment.id) { item in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(item.segment.color(isActive: item.segment.containsValue))
                                    .frame(width: item.width)
                                    .frame(height: 6)
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            if selectedSegment?.id == item.segment.id {
                                                selectedSegment = nil
                                            } else {
                                                selectedSegment = item.segment
                                            }
                                        }
                                    }
                            }
                        }

                        // Patient value indicator dot
                        if let value = currentValue, hasData {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color(uiColor: .systemGray3), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                                .offset(x: calculateDotXPosition(for: value, in: geometry.size.width, segmentWidths: segmentWidths) - 5)
                        }
                    }
                    .onAppear {
                        barWidth = geometry.size.width
                    }
                }
                .frame(height: 10)

                // Range numbers
                HStack {
                    Text(formatValue(chartMin))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatValue(chartMax))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Selected segment detail (tap to reveal)
            if let selected = selectedSegment {
                HStack(spacing: 6) {
                    Circle()
                        .fill(selected.color)
                        .frame(width: 6, height: 6)

                    Text(selected.rangeName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(selected.color)

                    Text("·")
                        .foregroundColor(.secondary)

                    Text("\(formatValue(selected.rangeLow)) - \(formatValue(selected.rangeHigh)) \(unit)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(action: {
                        withAnimation { selectedSegment = nil }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(6)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }

            // Legend
            HStack(spacing: 12) {
                LegendItem(color: .green, label: "Optimal")
                if segments.contains(where: { $0.rangeBucket == "In-Range" }) {
                    LegendItem(color: .blue, label: "In-Range")
                }
                LegendItem(color: .red, label: "Out-of-Range")
            }
            .padding(.top, 4)
        }
        .padding(20)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }

    // MARK: - Calculations

    private func calculateLabelPosition(for segment: RangeSegmentDetail, in totalWidth: CGFloat, segmentWidths: [(segment: RangeSegmentDetail, width: CGFloat)]) -> CGFloat {
        // Calculate segment start position using hybrid widths
        var segmentStart: CGFloat = 0
        let spacing: CGFloat = 2
        var targetSegmentWidth: CGFloat = 0

        for item in segmentWidths {
            if item.segment.id == segment.id {
                targetSegmentWidth = item.width
                break
            }
            segmentStart += item.width + spacing
        }

        let segmentCenter = segmentStart + targetSegmentWidth / 2

        // Estimate label width (rough approximation)
        let labelWidth = CGFloat(segment.rangeName.count) * 6.5

        // Clamp to keep label within bounds
        let minX = labelWidth / 2 + 4
        let maxX = totalWidth - labelWidth / 2 - 4

        return min(max(segmentCenter, minX), maxX)
    }

    private func calculateDotXPosition(for value: Double, in totalWidth: CGFloat, segmentWidths: [(segment: RangeSegmentDetail, width: CGFloat)]) -> CGFloat {
        guard !segmentWidths.isEmpty else { return totalWidth / 2 }

        guard let minValue = sortedSegments.first?.displayLow,
              let maxValue = sortedSegments.last?.displayHigh else {
            return totalWidth / 2
        }

        let clampedValue = max(minValue, min(maxValue, value))

        var xPosition: CGFloat = 0
        let spacing: CGFloat = 2

        for (index, item) in segmentWidths.enumerated() {
            let segment = item.segment
            let segmentWidth = item.width

            if clampedValue >= segment.displayLow && clampedValue <= segment.displayHigh {
                let segmentRange = segment.displayHigh - segment.displayLow
                if segmentRange > 0 {
                    let positionInSegment = (clampedValue - segment.displayLow) / segmentRange
                    xPosition += segmentWidth * CGFloat(positionInSegment)
                } else {
                    xPosition += segmentWidth / 2
                }
                break
            } else if clampedValue > segment.displayHigh {
                xPosition += segmentWidth
                if index < segmentWidths.count - 1 {
                    xPosition += spacing
                }
            }
        }

        return xPosition
    }

    private func formatValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else if value < 10 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}

// MARK: - Legend Item

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 6)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

#Preview("With Data - 5 Tier optimal_range") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            VerticalRangeModalView(
                metricName: "Magnesium (RBC)",
                currentValue: 6.8,
                unit: "mg/dL",
                segments: [
                    RangeSegmentDetail(rangeName: "OUT OF RANGE", rangeBucket: "OUT OF RANGE", rangeLow: 4.0, rangeHigh: 5.0, frontendDisplay: nil, containsValue: false, isFirstTier: true),
                    RangeSegmentDetail(rangeName: "IN RANGE", rangeBucket: "IN RANGE", rangeLow: 5.0, rangeHigh: 6.0, frontendDisplay: nil, containsValue: false),
                    RangeSegmentDetail(rangeName: "OPTIMAL", rangeBucket: "OPTIMAL", rangeLow: 6.0, rangeHigh: 7.0, frontendDisplay: nil, containsValue: true),
                    RangeSegmentDetail(rangeName: "IN RANGE", rangeBucket: "IN RANGE", rangeLow: 7.0, rangeHigh: 8.0, frontendDisplay: nil, containsValue: false),
                    RangeSegmentDetail(rangeName: "OUT OF RANGE", rangeBucket: "OUT OF RANGE", rangeLow: 8.0, rangeHigh: 9.0, frontendDisplay: nil, containsValue: false, isLastTier: true)
                ],
                metricColor: Color(red: 0.74, green: 0.56, blue: 0.94),
                directionality: "optimal_range"
            )
        }
}

#Preview("With Data - 3 Tier lower_better") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            VerticalRangeModalView(
                metricName: "Blood Pressure",
                currentValue: 125,
                unit: "mmHg",
                segments: [
                    RangeSegmentDetail(rangeName: "OPTIMAL", rangeBucket: "OPTIMAL", rangeLow: 90, rangeHigh: 120, frontendDisplay: nil, containsValue: false, isFirstTier: true),
                    RangeSegmentDetail(rangeName: "IN RANGE", rangeBucket: "IN RANGE", rangeLow: 120, rangeHigh: 140, frontendDisplay: nil, containsValue: true),
                    RangeSegmentDetail(rangeName: "OUT OF RANGE", rangeBucket: "OUT OF RANGE", rangeLow: 140, rangeHigh: 180, frontendDisplay: nil, containsValue: false, isLastTier: true)
                ],
                metricColor: .red,
                directionality: "lower_better"
            )
        }
}

#Preview("No Data") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            VerticalRangeModalView(
                metricName: "Magnesium (RBC)",
                currentValue: nil,
                unit: "mg/dL",
                segments: [
                    RangeSegmentDetail(rangeName: "OUT OF RANGE", rangeBucket: "OUT OF RANGE", rangeLow: 4.0, rangeHigh: 5.0, frontendDisplay: nil, containsValue: false, isFirstTier: true),
                    RangeSegmentDetail(rangeName: "IN RANGE", rangeBucket: "IN RANGE", rangeLow: 5.0, rangeHigh: 6.5, frontendDisplay: nil, containsValue: false),
                    RangeSegmentDetail(rangeName: "OPTIMAL", rangeBucket: "OPTIMAL", rangeLow: 6.5, rangeHigh: 7.5, frontendDisplay: nil, containsValue: false, isLastTier: true)
                ],
                metricColor: Color(red: 0.74, green: 0.56, blue: 0.94),
                directionality: "higher_better"
            )
        }
}
