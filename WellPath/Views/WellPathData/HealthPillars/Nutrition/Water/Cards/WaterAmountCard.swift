//
//  WaterAmountCard.swift
//  WellPath
//
//  Reusable card for Water Amount metric.
//

import SwiftUI

struct WaterAmountCard: View {
    let color: Color
    let pillar: String

    @StateObject private var viewModel = StandardMetricViewModel(metricId: "DISP_HYDRATION_AMOUNT")
    @StateObject private var unitPrefs = UnitPreferencesViewModel()

    var body: some View {
        MetricCardView(
            title: "Water Intake",
            color: color,
            metricId: "DISP_HYDRATION_AMOUNT",
            pillar: pillar
        ) {
            WaterAmountMiniCard(viewModel: viewModel, color: color, liquidUnit: unitPrefs.liquidUnit)
        } fullScreen: {
            WaterAmountView(color: color)
        }
        .task {
            await viewModel.loadPrimaryScreen()
            await unitPrefs.loadPreferences()
        }
    }
}

// MARK: - Mini Card

struct WaterAmountMiniCard: View {
    @ObservedObject var viewModel: StandardMetricViewModel
    let color: Color
    let liquidUnit: LiquidDisplayUnit

    private let calendar = Calendar.current

    private var last7CalendarDays: [(date: Date, value: Double?)] {
        let today = calendar.startOfDay(for: Date())
        var days: [(date: Date, value: Double?)] = []

        var dataByDate: [DateComponents: Double] = [:]
        for point in viewModel.chartData {
            let components = calendar.dateComponents([.year, .month, .day], from: point.date)
            dataByDate[components] = point.value
        }

        for daysBack in (0...6).reversed() {
            if let date = calendar.date(byAdding: .day, value: -daysBack, to: today) {
                let components = calendar.dateComponents([.year, .month, .day], from: date)
                let value = dataByDate[components]
                days.append((date: date, value: value))
            }
        }

        return days
    }

    private var maxValue: Double {
        let values = last7CalendarDays.compactMap { $0.value }
        return values.max() ?? 2000
    }

    /// Convert mL to the user's preferred unit
    private func convertFromMl(_ ml: Double) -> Double {
        ml / liquidUnit.mlPerUnit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(height: 60)
            } else if viewModel.todayValue != nil || viewModel.weeklyAverageValue != nil {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(formatValue(viewModel.todayValue))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(color)
                            Text(liquidUnit.shortLabel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(Array(last7CalendarDays.enumerated()), id: \.offset) { _, day in
                            VStack(spacing: 2) {
                                if let value = day.value {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(isToday(day.date) ? color : color.opacity(0.4))
                                        .frame(width: 8, height: barHeight(for: value))
                                } else {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 8, height: 4)
                                }
                                Text(dayInitial(for: day.date))
                                    .font(.system(size: 7))
                                    .foregroundColor(isToday(day.date) ? color : .secondary)
                            }
                        }
                    }
                    .frame(height: 45)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 24))
                        .foregroundColor(color.opacity(0.6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hydration")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("No data yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(height: 60)
            }
        }
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    private func barHeight(for value: Double) -> CGFloat {
        let normalized = min(value / max(maxValue, 1), 1)
        return 15 + normalized * 25
    }

    private func dayInitial(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }

    private func formatValue(_ mlValue: Double?) -> String {
        guard let ml = mlValue else { return "--" }
        let converted = convertFromMl(ml)
        if converted >= 10 {
            return String(format: "%.0f", converted)
        } else {
            return String(format: "%.1f", converted)
        }
    }
}

#Preview {
    WaterAmountCard(color: .cyan, pillar: "Healthful Nutrition")
        .padding()
}
