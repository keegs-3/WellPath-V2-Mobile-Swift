//
//  ProteinAmountCard.swift
//  WellPath
//
//  Reusable card for Protein Amount metric.
//  Can be used in ProteinScreen and Favorites.
//

import SwiftUI

struct ProteinAmountCard: View {
    let color: Color
    let pillar: String

    @StateObject private var viewModel = StandardMetricViewModel(metricId: "DISP_PROTEIN_GRAMS")

    var body: some View {
        MetricCardView(
            title: "Protein Amount",
            color: color,
            metricId: "DISP_PROTEIN_GRAMS",
            pillar: pillar
        ) {
            ProteinAmountMiniCard(viewModel: viewModel, color: color)
        } fullScreen: {
            ProteinAmountView(color: color)
        }
        .task {
            await viewModel.loadPrimaryScreen()
        }
    }
}

// MARK: - Mini Card

struct ProteinAmountMiniCard: View {
    @ObservedObject var viewModel: StandardMetricViewModel
    let color: Color

    private let calendar = Calendar.current

    // Build 7 calendar days (today and 6 days back) with data where available
    private var last7CalendarDays: [(date: Date, value: Double?)] {
        let today = calendar.startOfDay(for: Date())
        var days: [(date: Date, value: Double?)] = []

        // Create lookup dictionary from chart data (keyed by date components)
        var dataByDate: [DateComponents: Double] = [:]
        for point in viewModel.chartData {
            let components = calendar.dateComponents([.year, .month, .day], from: point.date)
            dataByDate[components] = point.value
        }

        // Build 7 days: 6 days ago through today
        for daysBack in (0...6).reversed() {
            if let date = calendar.date(byAdding: .day, value: -daysBack, to: today) {
                let components = calendar.dateComponents([.year, .month, .day], from: date)
                let value = dataByDate[components]
                days.append((date: date, value: value))
            }
        }

        return days
    }

    // Max value for bar height normalization
    private var maxValue: Double {
        let values = last7CalendarDays.compactMap { $0.value }
        return values.max() ?? 100
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
                    // Today's total on left
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(formatValue(viewModel.todayValue))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(color)
                            Text("g")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Mini bar chart on right - 7 calendar days
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(Array(last7CalendarDays.enumerated()), id: \.offset) { _, day in
                            VStack(spacing: 2) {
                                if let value = day.value {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(isToday(day.date) ? color : color.opacity(0.4))
                                        .frame(width: 8, height: barHeight(for: value))
                                } else {
                                    // Gap indicator for missing data
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
                    Image(systemName: "fork.knife")
                        .font(.system(size: 24))
                        .foregroundColor(color.opacity(0.6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Protein")
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
        return 15 + normalized * 25  // 15-40pt range
    }

    private func dayInitial(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }

    private func formatValue(_ value: Double?) -> String {
        guard let value = value else { return "--" }
        if value >= 100 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}

#Preview {
    ProteinAmountCard(color: .blue, pillar: "Healthful Nutrition")
        .padding()
}
