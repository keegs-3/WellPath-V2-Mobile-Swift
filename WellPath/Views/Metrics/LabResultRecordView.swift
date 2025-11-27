//
//  LabResultRecordView.swift
//  WellPath
//
//  Detail view for individual biomarker/biometric records
//  Matches Apple Health Lab Result Record style
//

import SwiftUI

struct LabResultRecordView: View {
    let record: BiomarkerDataPoint
    let metricName: String
    let unit: String
    let metricColor: Color
    let rangeSegments: [RangeSegmentDetail]
    let isBiometric: Bool

    @State private var showExpandedRange = false

    var metricIcon: String {
        isBiometric ? "waveform.path.ecg" : "testtube.2"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Main result card
                VStack(spacing: 0) {
                    // Blue/Purple header with metric name and date
                    VStack(alignment: .leading, spacing: 4) {
                        Text(metricName)
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text("Collected \(formatDateTime(record.date))")
                            .font(.subheadline)
                            .opacity(0.85)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(metricColor)
                    .foregroundColor(.white)

                    // Value and range section
                    VStack(alignment: .leading, spacing: 16) {
                        // Value display
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatValue(record.value))
                                .font(.system(size: 36, weight: .semibold))

                            if !unit.isEmpty {
                                Text(unit)
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Status label
                        Text(getStatus().uppercased())
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        // Range bar (expandable)
                        if !rangeSegments.isEmpty {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showExpandedRange.toggle()
                                }
                            }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    // Horizontal range bar
                                    InlineRangeBar(
                                        segments: rangeSegments,
                                        currentValue: record.value,
                                        metricColor: metricColor
                                    )

                                    if showExpandedRange {
                                        // Expanded range details
                                        VStack(alignment: .leading, spacing: 8) {
                                            ForEach(rangeSegments) { segment in
                                                HStack {
                                                    Circle()
                                                        .fill(segment.color(isActive: segment.containsValue))
                                                        .frame(width: 8, height: 8)

                                                    Text(segment.rangeName)
                                                        .font(.caption)
                                                        .foregroundColor(.primary)

                                                    Spacer()

                                                    Text(formatRangeText(segment))
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                        .padding(.top, 8)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        Text("Collected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                }
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .padding(.top, 16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Lab Result Record")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helper Functions

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }

    private func formatValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 && value < 10000 {
            return String(format: "%.0f", value)
        } else if value >= 1000 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func getStatus() -> String {
        for segment in rangeSegments {
            if record.value >= segment.rangeLow && record.value <= segment.rangeHigh {
                return segment.rangeName ?? segment.rangeBucket
            }
        }
        return "Unknown"
    }

    private func formatRangeText(_ segment: RangeSegmentDetail) -> String {
        let low = segment.displayLow
        let high = segment.displayHigh

        if segment.isFirstTier {
            return "< \(formatValue(high))"
        } else if segment.isLastTier {
            return "> \(formatValue(low))"
        } else {
            return "\(formatValue(low)) - \(formatValue(high))"
        }
    }
}

// MARK: - Inline Range Bar Component

struct InlineRangeBar: View {
    let segments: [RangeSegmentDetail]
    let currentValue: Double
    let metricColor: Color
    let directionality: String
    let allSegments: [RangeSegmentDetail]

    // Computed visible segments (always 3 for mini charts)
    private var visibleSegments: [RangeSegmentDetail] {
        RangeDisplayCalculator.selectVisibleBands(
            allSegments: allSegments.isEmpty ? segments : allSegments,
            patientValue: currentValue,
            directionality: directionality
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let barHeight: CGFloat = 10
            let segmentWidths = RangeDisplayCalculator.calculateValueCenteredWidths(
                segments: visibleSegments,
                patientValue: currentValue,
                totalWidth: totalWidth,
                zoomFactor: 1.2
            )

            ZStack(alignment: .leading) {
                // Background segments
                HStack(spacing: 1) {
                    ForEach(segmentWidths, id: \.segment.id) { item in
                        Rectangle()
                            .fill(item.segment.color(isActive: item.segment.containsValue))
                            .frame(width: max(item.width, 2), height: barHeight)
                    }
                }
                .cornerRadius(barHeight / 2)

                // Value indicator dot
                if let position = calculateValuePosition(totalWidth: totalWidth, segmentWidths: segmentWidths) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(metricColor, lineWidth: 2)
                        )
                        .offset(x: position - 7)
                }
            }
        }
        .frame(height: 14)
    }

    private func calculateValuePosition(totalWidth: CGFloat, segmentWidths: [(segment: RangeSegmentDetail, width: CGFloat)]) -> CGFloat? {
        guard !segmentWidths.isEmpty else { return nil }

        let spacing: CGFloat = 1.0
        var xPosition: CGFloat = 0

        for (index, item) in segmentWidths.enumerated() {
            let segment = item.segment
            let segmentWidth = item.width

            if currentValue >= segment.rangeLow && currentValue <= segment.rangeHigh {
                // Value is in this segment
                let segmentRange = segment.rangeHigh - segment.rangeLow
                if segmentRange > 0 {
                    let positionInSegment = (currentValue - segment.rangeLow) / segmentRange
                    xPosition += segmentWidth * CGFloat(positionInSegment)
                } else {
                    xPosition += segmentWidth / 2
                }
                return max(7, min(totalWidth - 7, xPosition))
            } else if currentValue > segment.rangeHigh {
                xPosition += segmentWidth
                if index < segmentWidths.count - 1 {
                    xPosition += spacing
                }
            }
        }

        // Value is below first segment or above last
        if currentValue < segmentWidths.first?.segment.rangeLow ?? 0 {
            return 7
        }
        return max(7, min(totalWidth - 7, xPosition))
    }
}

// Convenience initializer for backward compatibility
extension InlineRangeBar {
    init(segments: [RangeSegmentDetail], currentValue: Double, metricColor: Color) {
        self.segments = segments
        self.currentValue = currentValue
        self.metricColor = metricColor
        self.directionality = "optimal_range"  // Default
        self.allSegments = segments
    }
}

#Preview {
    NavigationView {
        LabResultRecordView(
            record: BiomarkerDataPoint(date: Date(), value: 27),
            metricName: "Alkaline Phosphatase",
            unit: "IU/L",
            metricColor: Color(red: 0.74, green: 0.56, blue: 0.94),
            rangeSegments: [
                RangeSegmentDetail(
                    rangeName: "OUT OF RANGE",
                    rangeBucket: "OUT OF RANGE",
                    rangeLow: 0,
                    rangeHigh: 39,
                    frontendDisplay: nil,
                    containsValue: true,
                    displayLow: 0,
                    displayHigh: 39,
                    isFirstTier: true,
                    isLastTier: false
                ),
                RangeSegmentDetail(
                    rangeName: "OPTIMAL",
                    rangeBucket: "OPTIMAL",
                    rangeLow: 39,
                    rangeHigh: 117,
                    frontendDisplay: nil,
                    containsValue: false,
                    displayLow: 39,
                    displayHigh: 117,
                    isFirstTier: false,
                    isLastTier: false
                ),
                RangeSegmentDetail(
                    rangeName: "OUT OF RANGE",
                    rangeBucket: "OUT OF RANGE",
                    rangeLow: 117,
                    rangeHigh: 200,
                    frontendDisplay: nil,
                    containsValue: false,
                    displayLow: 117,
                    displayHigh: 200,
                    isFirstTier: false,
                    isLastTier: true
                )
            ],
            isBiometric: false
        )
    }
}
