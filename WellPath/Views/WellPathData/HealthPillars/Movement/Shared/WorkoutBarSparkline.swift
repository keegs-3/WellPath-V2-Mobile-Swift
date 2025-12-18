//
//  WorkoutBarSparkline.swift
//  WellPath
//
//  Mini BarMark sparkline for workout duration cards
//  Shows recent daily duration with the most recent highlighted
//

import SwiftUI
import Charts

/// Mini bar sparkline for workout duration
struct WorkoutBarSparkline: View {
    let dataPoints: [WorkoutSparklinePoint]
    let color: Color

    /// Fixed number of slots for consistent spacing
    private let slotCount = 6

    /// Points positioned in fixed slots (right-aligned)
    private var slottedPoints: [SlottedWorkoutPoint] {
        let points = Array(dataPoints.suffix(slotCount))
        guard !points.isEmpty else { return [] }

        let startSlot = slotCount - points.count
        return points.enumerated().map { index, point in
            SlottedWorkoutPoint(
                slot: startSlot + index,
                value: point.durationMinutes,
                isLatest: point.isLatest
            )
        }
    }

    private var hasData: Bool {
        !dataPoints.isEmpty
    }

    var body: some View {
        if hasData {
            Chart(slottedPoints) { point in
                BarMark(
                    x: .value("Slot", point.slot),
                    y: .value("Duration", point.value)
                )
                .foregroundStyle(
                    point.isLatest ? color : color.opacity(0.4)
                )
                .cornerRadius(2)
            }
            .chartXScale(domain: 0...slotCount - 1)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(width: 60, height: 30)
        } else {
            EmptyView()
        }
    }
}

/// Point positioned in a fixed slot for bar chart
private struct SlottedWorkoutPoint: Identifiable {
    let id = UUID()
    let slot: Int
    let value: Double
    let isLatest: Bool
}

#Preview {
    VStack(spacing: 20) {
        HStack {
            Text("6 pts:")
            WorkoutBarSparkline(
                dataPoints: [
                    WorkoutSparklinePoint(date: Date().addingTimeInterval(-5*24*3600), durationMinutes: 45),
                    WorkoutSparklinePoint(date: Date().addingTimeInterval(-4*24*3600), durationMinutes: 30),
                    WorkoutSparklinePoint(date: Date().addingTimeInterval(-3*24*3600), durationMinutes: 60),
                    WorkoutSparklinePoint(date: Date().addingTimeInterval(-2*24*3600), durationMinutes: 25),
                    WorkoutSparklinePoint(date: Date().addingTimeInterval(-1*24*3600), durationMinutes: 50),
                    WorkoutSparklinePoint(date: Date(), durationMinutes: 35, isLatest: true)
                ],
                color: .red
            )
        }

        HStack {
            Text("2 pts:")
            WorkoutBarSparkline(
                dataPoints: [
                    WorkoutSparklinePoint(date: Date().addingTimeInterval(-1*24*3600), durationMinutes: 45),
                    WorkoutSparklinePoint(date: Date(), durationMinutes: 30, isLatest: true)
                ],
                color: .red
            )
        }

        HStack {
            Text("Empty:")
            WorkoutBarSparkline(dataPoints: [], color: .red)
        }
    }
    .padding()
}
