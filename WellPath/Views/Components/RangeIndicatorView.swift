//
//  RangeIndicatorView.swift
//  WellPath
//
//  Segmented range indicator matching Apple Health style
//

import SwiftUI

struct RangeIndicatorView: View {
    let segments: [RangeSegment]
    let patientValue: Double
    let totalWidth: CGFloat = 80  // Slightly wider for better visibility
    let height: CGFloat = 6

    // Find which segment contains the patient value
    private var patientSegmentIndex: Int? {
        segments.firstIndex { patientValue >= $0.rangeLow && patientValue <= $0.rangeHigh }
    }

    var body: some View {
        if segments.isEmpty {
            // Fallback to simple indicator if no segments
            Circle()
                .fill(Color.secondary)
                .frame(width: 7, height: 7)
        } else {
            GeometryReader { geometry in
                let segmentWidths = calculateValueCenteredWidths()

                ZStack(alignment: .leading) {
                    // Draw all segments with value-centered widths
                    HStack(spacing: 1) {
                        ForEach(Array(segmentWidths.enumerated()), id: \.element.segment.id) { index, item in
                            let isActive = index == patientSegmentIndex
                            Rectangle()
                                .fill(isActive ? item.segment.color : Color(UIColor.systemGray4))
                                .frame(width: item.width)
                                .frame(height: height)
                        }
                    }
                    .cornerRadius(height / 2)

                    // Draw patient value dot
                    if let dotPosition = calculateDotPosition(segmentWidths: segmentWidths) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color(UIColor.systemGray3), lineWidth: 1)
                            )
                            .offset(x: dotPosition - 5) // Center the dot
                    }
                }
            }
            .frame(width: totalWidth, height: 10)
        }
    }

    /// Value-centered widths using a view window approach
    /// Shows meaningful context around patient value, not artificial bounds
    private func calculateValueCenteredWidths() -> [(segment: RangeSegment, width: CGFloat)] {
        let spacing: CGFloat = 1.0
        let availableWidth = totalWidth - (CGFloat(segments.count - 1) * spacing)

        guard let patientIdx = patientSegmentIndex else {
            // Fallback to equal widths
            let equalWidth = availableWidth / CGFloat(segments.count)
            return segments.map { ($0, equalWidth) }
        }

        // Calculate context buffer based on non-artificial segment widths
        var contextBuffer: Double = 0
        for segment in segments {
            if !segment.isArtificialLow && !segment.isArtificialHigh {
                let segmentWidth = segment.rangeHigh - segment.rangeLow
                contextBuffer = max(contextBuffer, segmentWidth)
            }
        }
        // If all segments are artificial, use a reasonable default
        if contextBuffer == 0 {
            contextBuffer = 50
        }

        // View window centered on patient value with buffer on each side
        let viewMin = patientValue - contextBuffer
        let viewMax = patientValue + contextBuffer

        // Calculate visible portion of each segment within the view window
        var visibleWidths: [Double] = []
        for segment in segments {
            let clippedLow = max(segment.rangeLow, viewMin)
            let clippedHigh = min(segment.rangeHigh, viewMax)
            let visibleWidth = max(0, clippedHigh - clippedLow)
            visibleWidths.append(visibleWidth)
        }

        // Ensure each segment gets at least a minimum visible width (10% of buffer)
        let minVisibleWidth = contextBuffer * 0.15
        for i in 0..<visibleWidths.count {
            if visibleWidths[i] < minVisibleWidth && visibleWidths[i] > 0 {
                visibleWidths[i] = minVisibleWidth
            } else if visibleWidths[i] == 0 {
                // Segment is outside view window - give it minimum width for visibility
                visibleWidths[i] = minVisibleWidth * 0.5
            }
        }

        // Convert to proportional widths
        let totalVisibleWidth = visibleWidths.reduce(0, +)
        guard totalVisibleWidth > 0 else {
            let equalWidth = availableWidth / CGFloat(segments.count)
            return segments.map { ($0, equalWidth) }
        }

        var results: [(segment: RangeSegment, width: CGFloat)] = []
        for (index, segment) in segments.enumerated() {
            let proportion = visibleWidths[index] / totalVisibleWidth
            let width = availableWidth * CGFloat(proportion)
            results.append((segment: segment, width: max(width, 4)))
        }

        return results
    }

    private func calculateDotPosition(segmentWidths: [(segment: RangeSegment, width: CGFloat)]) -> CGFloat? {
        guard let patientIdx = patientSegmentIndex else { return nil }

        // Calculate cumulative width up to patient's segment
        var cumulativeWidth: CGFloat = 0
        for i in 0..<patientIdx {
            cumulativeWidth += segmentWidths[i].width + 1  // width + spacing
        }

        let patientSegment = segmentWidths[patientIdx].segment
        let patientWidth = segmentWidths[patientIdx].width

        // If patient is in a segment with artificial bounds, position at edge
        if patientSegment.isArtificialLow {
            return cumulativeWidth
        } else if patientSegment.isArtificialHigh {
            return cumulativeWidth + patientWidth
        } else {
            // Position proportionally within this segment
            let segmentRange = patientSegment.rangeHigh - patientSegment.rangeLow
            guard segmentRange > 0 else { return cumulativeWidth + patientWidth / 2 }

            let valueOffset = patientValue - patientSegment.rangeLow
            let proportionInSegment = CGFloat(valueOffset / segmentRange)
            return cumulativeWidth + (patientWidth * proportionInSegment)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // Example 1: Albumin with 4 buckets (Out/In/Optimal/Out)
        VStack(alignment: .leading) {
            Text("Albumin (4.5 g/dL)")
                .font(.caption)
            RangeIndicatorView(
                segments: [
                    RangeSegment(rangeName: "Low", rangeBucket: "Out-of-Range", rangeLow: 0, rangeHigh: 3.49),
                    RangeSegment(rangeName: "In-Range", rangeBucket: "In-Range", rangeLow: 3.5, rangeHigh: 3.99),
                    RangeSegment(rangeName: "Optimal", rangeBucket: "Optimal", rangeLow: 4.0, rangeHigh: 4.99),
                    RangeSegment(rangeName: "High", rangeBucket: "Out-of-Range", rangeLow: 5.0, rangeHigh: 16.5)
                ],
                patientValue: 4.5
            )
        }

        // Example 2: Value in Out-of-Range (low)
        VStack(alignment: .leading) {
            Text("Low Value (2.8)")
                .font(.caption)
            RangeIndicatorView(
                segments: [
                    RangeSegment(rangeName: "Low", rangeBucket: "Out-of-Range", rangeLow: 0, rangeHigh: 3.49),
                    RangeSegment(rangeName: "In-Range", rangeBucket: "In-Range", rangeLow: 3.5, rangeHigh: 3.99),
                    RangeSegment(rangeName: "Optimal", rangeBucket: "Optimal", rangeLow: 4.0, rangeHigh: 4.99),
                    RangeSegment(rangeName: "High", rangeBucket: "Out-of-Range", rangeLow: 5.0, rangeHigh: 16.5)
                ],
                patientValue: 2.8
            )
        }

        // Example 3: Value in Out-of-Range (high)
        VStack(alignment: .leading) {
            Text("High Value (5.2)")
                .font(.caption)
            RangeIndicatorView(
                segments: [
                    RangeSegment(rangeName: "Low", rangeBucket: "Out-of-Range", rangeLow: 0, rangeHigh: 3.49),
                    RangeSegment(rangeName: "In-Range", rangeBucket: "In-Range", rangeLow: 3.5, rangeHigh: 3.99),
                    RangeSegment(rangeName: "Optimal", rangeBucket: "Optimal", rangeLow: 4.0, rangeHigh: 4.99),
                    RangeSegment(rangeName: "High", rangeBucket: "Out-of-Range", rangeLow: 5.0, rangeHigh: 16.5)
                ],
                patientValue: 5.2
            )
        }

        // Example 4: Value in In-Range
        VStack(alignment: .leading) {
            Text("In-Range Value (3.7)")
                .font(.caption)
            RangeIndicatorView(
                segments: [
                    RangeSegment(rangeName: "Low", rangeBucket: "Out-of-Range", rangeLow: 0, rangeHigh: 3.49),
                    RangeSegment(rangeName: "In-Range", rangeBucket: "In-Range", rangeLow: 3.5, rangeHigh: 3.99),
                    RangeSegment(rangeName: "Optimal", rangeBucket: "Optimal", rangeLow: 4.0, rangeHigh: 4.99),
                    RangeSegment(rangeName: "High", rangeBucket: "Out-of-Range", rangeLow: 5.0, rangeHigh: 16.5)
                ],
                patientValue: 3.7
            )
        }
    }
    .padding()
}
