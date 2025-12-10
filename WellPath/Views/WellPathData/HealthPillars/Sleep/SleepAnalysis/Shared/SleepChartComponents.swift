//
//  SleepChartComponents.swift
//  WellPath
//
//  Reusable chart components for Sleep Analysis metrics.
//  Shared visualization elements used across sleep cards and views.
//

import SwiftUI

// MARK: - Mini Hypnogram

/// A compact horizontal hypnogram visualization for sleep stage cards
struct MiniHypnogram: View {
    let session: SleepSession

    // Y-axis order for mini chart: Awake at top, Deep at bottom
    private let stageOrder: [SleepStage] = [.awake, .rem, .core, .deep]

    // Filter to only show actual sleep stages (exclude In Bed, asleepSummary)
    private var displaySegments: [SleepStageSegment] {
        session.segments.filter { segment in
            segment.stage == .awake ||
            segment.stage == .rem ||
            segment.stage == .core ||
            segment.stage == .deep ||
            segment.stage == .asleep
        }.sorted { $0.startTime < $1.startTime }
    }

    private var timeRange: (start: Date, end: Date)? {
        guard let first = displaySegments.first,
              let last = displaySegments.last else { return nil }
        return (first.startTime, last.endTime)
    }

    var body: some View {
        GeometryReader { geometry in
            if displaySegments.isEmpty {
                // No detailed stage data - show simple asleep bar
                if session.isManual, let manual = session.manualEntry {
                    manualEntryBar(geometry: geometry, entry: manual)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: geometry.size.height)
                }
            } else {
                Canvas { context, size in
                    drawMiniHypnogram(context: context, size: size)
                }
            }
        }
    }

    @ViewBuilder
    private func manualEntryBar(geometry: GeometryProxy, entry: ManualSleepEntry) -> some View {
        // Simple gradient bar for manual entries
        RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: "80CBC4") ?? .teal,
                        Color(hex: "60ABA4") ?? .teal
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: geometry.size.height * 0.6)
            .frame(maxHeight: .infinity, alignment: .center)
    }

    private func drawMiniHypnogram(context: GraphicsContext, size: CGSize) {
        guard let range = timeRange else { return }

        let totalDuration = range.end.timeIntervalSince(range.start)
        guard totalDuration > 0 else { return }

        let stageHeight = size.height / CGFloat(stageOrder.count)

        // Draw horizontal grid lines for each stage row
        for i in 0..<stageOrder.count {
            let y = CGFloat(i) * stageHeight + stageHeight / 2
            let linePath = Path { path in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(linePath, with: .color(Color.gray.opacity(0.3)), lineWidth: 0.5)
        }

        // Draw sleep stage segments
        for segment in displaySegments {
            // Calculate x position based on time
            let startOffset = segment.startTime.timeIntervalSince(range.start)
            let endOffset = segment.endTime.timeIntervalSince(range.start)

            let xStart = CGFloat(startOffset / totalDuration) * size.width
            let xEnd = CGFloat(endOffset / totalDuration) * size.width
            let width = max(xEnd - xStart, 1) // Minimum 1pt width

            // Calculate y position based on stage
            let stage = mapToDisplayStage(segment.stage)
            guard let stageIndex = stageOrder.firstIndex(of: stage) else { continue }

            let yCenter = CGFloat(stageIndex) * stageHeight + stageHeight / 2
            let barHeight = stageHeight * 0.7

            // Draw the segment bar
            let rect = CGRect(
                x: xStart,
                y: yCenter - barHeight / 2,
                width: width,
                height: barHeight
            )

            let path = Path(roundedRect: rect, cornerRadius: 2)
            context.fill(path, with: .color(stage.color))
        }
    }

    private func mapToDisplayStage(_ stage: SleepStage) -> SleepStage {
        switch stage {
        case .asleep:
            return .core // Map basic "asleep" to core for display
        default:
            return stage
        }
    }
}

