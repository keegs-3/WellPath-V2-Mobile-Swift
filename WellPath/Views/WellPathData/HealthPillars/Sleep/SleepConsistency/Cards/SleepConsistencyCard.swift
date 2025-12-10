//
//  SleepConsistencyCard.swift
//  WellPath
//
//  Card component for Sleep Consistency metric.
//

import SwiftUI
import Charts

struct SleepConsistencyCard: View {
    let color: Color
    let pillar: String
    let sectionId: String

    @StateObject private var viewModel = SleepConsistencyViewModel()

    init(color: Color, pillar: String, sectionId: String = "NAV_SLEEP") {
        self.color = color
        self.pillar = pillar
        self.sectionId = sectionId
    }

    var body: some View {
        MetricCardView(
            title: "Sleep Consistency",
            color: color,
            metricId: "SCREEN_SLEEP_CONSISTENCY",  // Use SCREEN_* for favorites lookup (screen type)
            pillar: pillar,
            cardId: "CARD_SLEEP_CONSISTENCY",
            sectionId: sectionId,
            itemType: .screen  // This is a direct-to-view metric
        ) {
            SleepConsistencyMiniCardContent(viewModel: viewModel, color: color)
        } fullScreen: {
            SleepConsistencyView(pillar: pillar, color: color, sectionId: sectionId)
        }
        .task {
            await viewModel.loadDailySleepTimes()
        }
    }
}

struct SleepConsistencyMiniCardContent: View {
    @ObservedObject var viewModel: SleepConsistencyViewModel
    let color: Color

    private let calendar = Calendar.current
    private let bandMinutes = 30  // ±30 min band

    // Reference date for chart Y-axis (6PM baseline)
    private var referenceDate: Date {
        calendar.startOfDay(for: Date())
    }

    // Build 7 calendar days (today and 6 days back) with data where available
    private var last7CalendarDays: [(date: Date, sleep: DailySleepTime?)] {
        let today = calendar.startOfDay(for: Date())
        var days: [(date: Date, sleep: DailySleepTime?)] = []

        // Create lookup dictionary from sleep data (keyed by date components)
        var dataByDate: [DateComponents: DailySleepTime] = [:]
        for sleep in viewModel.dailySleepTimes {
            let components = calendar.dateComponents([.year, .month, .day], from: sleep.date)
            dataByDate[components] = sleep
        }

        // Build 7 days: 6 days ago through today
        for daysBack in (0...6).reversed() {
            if let date = calendar.date(byAdding: .day, value: -daysBack, to: today) {
                let components = calendar.dateComponents([.year, .month, .day], from: date)
                let sleep = dataByDate[components]
                days.append((date: date, sleep: sleep))
            }
        }

        return days
    }

    // Calculate weekly average for band calculation
    private var weeklyStats: (avgBedtimeMinutes: Int, avgWaketimeMinutes: Int, nightsInBand: Int, totalNights: Int) {
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let thisWeekSleepTimes = viewModel.dailySleepTimes.filter { $0.date >= weekAgo }

        guard !thisWeekSleepTimes.isEmpty else {
            return (0, 0, 0, 0)
        }

        let avgBedtimeMinutes = thisWeekSleepTimes.map { calculateOffsetFromSixPM($0.bedtime) }.reduce(0, +) / thisWeekSleepTimes.count
        let avgWaketimeMinutes = thisWeekSleepTimes.map { calculateOffsetFromSixPM($0.waketime) }.reduce(0, +) / thisWeekSleepTimes.count

        var nightsInBand = 0
        for sleep in thisWeekSleepTimes {
            let bedtimeOffset = calculateOffsetFromSixPM(sleep.bedtime)
            let waketimeOffset = calculateOffsetFromSixPM(sleep.waketime)
            let bedtimeInBand = abs(bedtimeOffset - avgBedtimeMinutes) <= bandMinutes
            let waketimeInBand = abs(waketimeOffset - avgWaketimeMinutes) <= bandMinutes
            if bedtimeInBand && waketimeInBand {
                nightsInBand += 1
            }
        }

        return (avgBedtimeMinutes, avgWaketimeMinutes, nightsInBand, thisWeekSleepTimes.count)
    }

    private func calculateOffsetFromSixPM(_ time: Date) -> Int {
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)
        if hour >= 18 {
            return (hour - 18) * 60 + minute
        } else {
            return (24 - 18 + hour) * 60 + minute
        }
    }

    // Convert offset from 6PM to a chart date (relative to referenceDate at 6PM)
    private func offsetToChartDate(_ offsetMinutes: Int) -> Date {
        let sixPM = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: referenceDate) ?? referenceDate
        return calendar.date(byAdding: .minute, value: offsetMinutes, to: sixPM) ?? sixPM
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    // Check if a sleep time is within the band
    private func isInBand(_ sleep: DailySleepTime) -> Bool {
        let bedtimeOffset = calculateOffsetFromSixPM(sleep.bedtime)
        let waketimeOffset = calculateOffsetFromSixPM(sleep.waketime)
        let bedtimeInBand = abs(bedtimeOffset - weeklyStats.avgBedtimeMinutes) <= bandMinutes
        let waketimeInBand = abs(waketimeOffset - weeklyStats.avgWaketimeMinutes) <= bandMinutes
        return bedtimeInBand && waketimeInBand
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
            } else if !viewModel.dailySleepTimes.isEmpty {
                HStack(spacing: 8) {
                    // In Range stat and average bands on left
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(weeklyStats.nightsInBand)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(color)
                            Text("/ \(weeklyStats.totalNights)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("in range")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        // Show average bedtime and waketime bands
                        HStack(spacing: 8) {
                            HStack(spacing: 2) {
                                Image(systemName: "moon.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                                Text(formatOffsetToTime(weeklyStats.avgBedtimeMinutes))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            HStack(spacing: 2) {
                                Image(systemName: "sun.max.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                                Text(formatOffsetToTime(weeklyStats.avgWaketimeMinutes))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer()

                    // Mini floating bar chart with bands (matches full chart style)
                    miniFloatingChart
                        .frame(width: 100, height: 55)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 24))
                        .foregroundColor(color.opacity(0.6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sleep Schedule")
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

    // Mini floating bar chart matching the full view style
    private var miniFloatingChart: some View {
        let stats = weeklyStats
        let avgBedtimeDate = offsetToChartDate(stats.avgBedtimeMinutes)
        let avgWaketimeDate = offsetToChartDate(stats.avgWaketimeMinutes)

        // Band boundaries (±30 min from average)
        let bedtimeBandLower = offsetToChartDate(stats.avgBedtimeMinutes - bandMinutes)
        let bedtimeBandUpper = offsetToChartDate(stats.avgBedtimeMinutes + bandMinutes)
        let waketimeBandLower = offsetToChartDate(stats.avgWaketimeMinutes - bandMinutes)
        let waketimeBandUpper = offsetToChartDate(stats.avgWaketimeMinutes + bandMinutes)

        // Y-axis range: from earliest bedtime band to latest waketime band with padding
        let yMin = offsetToChartDate(max(stats.avgBedtimeMinutes - 90, 0))  // 1.5h before avg bedtime
        let yMax = offsetToChartDate(stats.avgWaketimeMinutes + 90)  // 1.5h after avg waketime

        return Chart {
            // Bedtime band (shaded area)
            RectangleMark(
                yStart: .value("BedLower", bedtimeBandLower),
                yEnd: .value("BedUpper", bedtimeBandUpper)
            )
            .foregroundStyle(color.opacity(0.1))

            // Waketime band (shaded area)
            RectangleMark(
                yStart: .value("WakeLower", waketimeBandLower),
                yEnd: .value("WakeUpper", waketimeBandUpper)
            )
            .foregroundStyle(color.opacity(0.1))

            // Band boundary lines (dotted)
            RuleMark(y: .value("BedLower", bedtimeBandLower))
                .foregroundStyle(color.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [2, 2]))

            RuleMark(y: .value("BedUpper", bedtimeBandUpper))
                .foregroundStyle(color.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [2, 2]))

            RuleMark(y: .value("WakeLower", waketimeBandLower))
                .foregroundStyle(color.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [2, 2]))

            RuleMark(y: .value("WakeUpper", waketimeBandUpper))
                .foregroundStyle(color.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [2, 2]))

            // Floating bars for each day
            ForEach(Array(last7CalendarDays.enumerated()), id: \.offset) { index, day in
                if let sleep = day.sleep {
                    let bedtimeOffset = calculateOffsetFromSixPM(sleep.bedtime)
                    let waketimeOffset = calculateOffsetFromSixPM(sleep.waketime)
                    let chartBedtime = offsetToChartDate(bedtimeOffset)
                    let chartWaketime = offsetToChartDate(waketimeOffset)

                    BarMark(
                        x: .value("Day", index),
                        yStart: .value("Bedtime", chartBedtime),
                        yEnd: .value("Waketime", chartWaketime),
                        width: .fixed(8)
                    )
                    .foregroundStyle(
                        isToday(day.date)
                            ? (isInBand(sleep) ? color : color.opacity(0.5))
                            : (isInBand(sleep) ? color.opacity(0.6) : color.opacity(0.25))
                    )
                    .cornerRadius(2)
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: yMin...yMax)
        .chartXScale(domain: -0.5...6.5)
    }

    private func dayInitial(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    // Convert offset minutes from 6PM back to time string
    private func formatOffsetToTime(_ offsetMinutes: Int) -> String {
        // Offset is minutes from 6PM
        let totalMinutes = (18 * 60) + offsetMinutes  // Convert back to minutes from midnight
        var hours = (totalMinutes / 60) % 24
        let minutes = totalMinutes % 60
        let isPM = hours >= 12
        if hours > 12 { hours -= 12 }
        if hours == 0 { hours = 12 }
        return String(format: "%d:%02d%@", hours, minutes, isPM ? "p" : "a")
    }
}

#Preview {
    SleepConsistencyCard(color: .indigo, pillar: "Sleep")
        .padding()
}
