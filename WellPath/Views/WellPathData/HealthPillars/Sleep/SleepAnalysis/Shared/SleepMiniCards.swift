//
//  SleepMiniCards.swift
//  WellPath
//
//  Mini card preview components for Sleep Analysis metrics.
//  Used inside MetricCardView for compact sleep data display.
//

import SwiftUI

// MARK: - Sleep Stages Mini Card

struct SleepStagesMiniCard: View {
    let color: Color
    @ObservedObject var chartViewModel: SleepAnalysisViewModel

    private let calendar = Calendar.current

    /// Find the most recent session with actual sleep data (non-empty segments)
    private var latestSessionWithData: SleepSession? {
        chartViewModel.sleepSessions.first { !$0.segments.isEmpty }
    }

    /// Check if the latest session is from today
    private var isSessionFromToday: Bool {
        guard let session = latestSessionWithData else { return false }
        return calendar.isDateInToday(session.date)
    }

    /// Get bedtime and waketime from database view (PRIMARY session only)
    /// Falls back to local calculation if database view data not available
    private var sleepTimes: (bedtime: Date, waketime: Date)? {
        // Prefer database view values (from PRIMARY session only)
        if let bedtime = chartViewModel.primaryBedtime,
           let waketime = chartViewModel.primaryWaketime {
            return (bedtime, waketime)
        }

        // Fallback: calculate from segments (legacy behavior)
        guard let session = latestSessionWithData else { return nil }

        let sleepSegments = session.segments.filter { segment in
            segment.stage != .awake && segment.stage != .inBed
        }

        guard !sleepSegments.isEmpty else {
            return (session.sessionStart, session.sessionEnd)
        }

        let sortedSegments = sleepSegments.sorted { $0.startTime < $1.startTime }
        return (sortedSegments.first!.startTime, sortedSegments.last!.endTime)
    }

    /// Smart date label: "Last Night", "Yesterday", "Dec 5"
    private func smartDateLabel(for date: Date) -> String {
        if calendar.isDateInToday(date) {
            return "Last Night"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        return formatter.string(from: date).lowercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if chartViewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(height: 60)
            } else if let session = latestSessionWithData, let times = sleepTimes {
                HStack(spacing: 8) {
                    // Left side: Date label and bedtime/waketime (like Sleep Consistency)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(smartDateLabel(for: session.date))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // Bedtime and waketime with icons (unified formatting)
                        HStack(spacing: 8) {
                            HStack(spacing: 2) {
                                Image(systemName: "moon.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(color)
                                Text(formatTime(times.bedtime))
                                    .font(.system(size: 10))
                                    .foregroundColor(.primary)
                            }
                            HStack(spacing: 2) {
                                Image(systemName: "sun.max.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(color)
                                Text(formatTime(times.waketime))
                                    .font(.system(size: 10))
                                    .foregroundColor(.primary)
                            }
                        }
                    }

                    Spacer()

                    // Right side: Mini hypnogram (same width as duration chart bars ~80pt)
                    MiniHypnogram(session: session)
                        .frame(width: 80, height: 45)
                }
            } else {
                // No data state - clean without chart background
                HStack(spacing: 12) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 24))
                        .foregroundColor(color.opacity(0.6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sleep Stages")
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
}

// MARK: - Sleep Amounts Mini Card

/// Mini preview for Stage Amounts - matches Stage Percentages style with progress bars but shows duration
struct SleepAmountsMiniCard: View {
    let color: Color
    @ObservedObject var chartViewModel: SleepAnalysisViewModel

    private let calendar = Calendar.current

    /// Find the most recent session with actual sleep data (non-empty segments)
    private var latestSessionWithData: SleepSession? {
        chartViewModel.sleepSessions.first { !$0.segments.isEmpty }
    }

    /// Get bedtime and waketime from database view (PRIMARY session only)
    /// Falls back to local calculation if database view data not available
    private var sleepTimes: (bedtime: Date, waketime: Date)? {
        // Prefer database view values (from PRIMARY session only)
        if let bedtime = chartViewModel.primaryBedtime,
           let waketime = chartViewModel.primaryWaketime {
            return (bedtime, waketime)
        }

        // Fallback: calculate from segments (legacy behavior)
        guard let session = latestSessionWithData else { return nil }

        let sleepSegments = session.segments.filter { segment in
            segment.stage != .awake && segment.stage != .inBed
        }

        guard !sleepSegments.isEmpty else {
            return (session.sessionStart, session.sessionEnd)
        }

        let sortedSegments = sleepSegments.sorted { $0.startTime < $1.startTime }
        return (sortedSegments.first!.startTime, sortedSegments.last!.endTime)
    }

    /// Smart date label: "Last Night", "Yesterday", "Dec 5"
    private func smartDateLabel(for date: Date) -> String {
        if calendar.isDateInToday(date) {
            return "Last Night"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        return formatter.string(from: date).lowercased()
    }

    private var stageData: [(stage: SleepStage, minutes: Double, percentage: Double)] {
        guard let latestSession = latestSessionWithData else {
            return []
        }

        let stages: [SleepStage] = [.deep, .core, .rem, .awake]
        var totals: [SleepStage: Double] = [:]
        var grandTotal: Double = 0

        for segment in latestSession.segments {
            guard segment.stage != .inBed else { continue }
            let duration = segment.endTime.timeIntervalSince(segment.startTime)
            totals[segment.stage, default: 0] += duration
            grandTotal += duration
        }

        guard grandTotal > 0 else { return [] }

        return stages.compactMap { stage in
            guard let total = totals[stage], total > 0 else { return nil }
            let minutes = total / 60.0
            let percentage = (total / grandTotal) * 100
            return (stage, minutes, percentage)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if chartViewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(height: 60)
            } else if let session = latestSessionWithData, let times = sleepTimes, !stageData.isEmpty {
                HStack(spacing: 8) {
                    // Left side: Date label and bedtime/waketime
                    VStack(alignment: .leading, spacing: 4) {
                        Text(smartDateLabel(for: session.date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            HStack(spacing: 2) {
                                Image(systemName: "moon.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(color)
                                Text(formatTime(times.bedtime))
                                    .font(.system(size: 10))
                                    .foregroundColor(.primary)
                            }
                            HStack(spacing: 2) {
                                Image(systemName: "sun.max.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(color)
                                Text(formatTime(times.waketime))
                                    .font(.system(size: 10))
                                    .foregroundColor(.primary)
                            }
                        }
                    }

                    Spacer()

                    // Right side: Mini bars with duration
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(stageData, id: \.stage) { item in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(item.stage.color)
                                    .frame(width: 5, height: 5)
                                Text(stageName(item.stage))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                    .frame(width: 32, alignment: .leading)
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                                        .frame(width: 40, height: 4)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(item.stage.color)
                                        .frame(width: 40 * min(item.percentage / 100, 1.0), height: 4)
                                }
                                Text(formatDuration(item.minutes))
                                    .font(.system(size: 9))
                                    .foregroundColor(.primary)
                                    .frame(width: 38, alignment: .trailing)
                            }
                        }
                    }
                }
            } else {
                HStack {
                    Text("No sleep data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 60)
            }
        }
    }

    private func stageName(_ stage: SleepStage) -> String {
        switch stage {
        case .deep: return "Deep"
        case .core: return "Core"
        case .rem: return "REM"
        case .awake: return "Awake"
        default: return ""
        }
    }

    private func formatDuration(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}

// MARK: - Sleep Percentages Mini Card

/// Mini preview for Stage Percentages - shows percentage bars with date label and times
struct SleepPercentagesMiniCard: View {
    let color: Color
    @ObservedObject var chartViewModel: SleepAnalysisViewModel

    private let calendar = Calendar.current

    /// Find the most recent session with actual sleep data (non-empty segments)
    private var latestSessionWithData: SleepSession? {
        chartViewModel.sleepSessions.first { !$0.segments.isEmpty }
    }

    /// Get bedtime and waketime from database view (PRIMARY session only)
    /// Falls back to local calculation if database view data not available
    private var sleepTimes: (bedtime: Date, waketime: Date)? {
        // Prefer database view values (from PRIMARY session only)
        if let bedtime = chartViewModel.primaryBedtime,
           let waketime = chartViewModel.primaryWaketime {
            return (bedtime, waketime)
        }

        // Fallback: calculate from segments (legacy behavior)
        guard let session = latestSessionWithData else { return nil }

        let sleepSegments = session.segments.filter { segment in
            segment.stage != .awake && segment.stage != .inBed
        }

        guard !sleepSegments.isEmpty else {
            return (session.sessionStart, session.sessionEnd)
        }

        let sortedSegments = sleepSegments.sorted { $0.startTime < $1.startTime }
        return (sortedSegments.first!.startTime, sortedSegments.last!.endTime)
    }

    /// Smart date label: "Last Night", "Yesterday", "Dec 5"
    private func smartDateLabel(for date: Date) -> String {
        if calendar.isDateInToday(date) {
            return "Last Night"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        return formatter.string(from: date).lowercased()
    }

    private var stagePercentages: [(stage: SleepStage, percentage: Double)] {
        guard let latestSession = latestSessionWithData else {
            return []
        }

        let stages: [SleepStage] = [.deep, .core, .rem, .awake]
        var totals: [SleepStage: Double] = [:]
        var grandTotal: Double = 0

        for segment in latestSession.segments {
            guard segment.stage != .inBed else { continue }
            let duration = segment.endTime.timeIntervalSince(segment.startTime)
            totals[segment.stage, default: 0] += duration
            grandTotal += duration
        }

        guard grandTotal > 0 else { return [] }

        return stages.compactMap { stage in
            guard let total = totals[stage], total > 0 else { return nil }
            return (stage, (total / grandTotal) * 100)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if chartViewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(height: 60)
            } else if let session = latestSessionWithData, let times = sleepTimes, !stagePercentages.isEmpty {
                HStack(spacing: 8) {
                    // Left side: Date label and bedtime/waketime
                    VStack(alignment: .leading, spacing: 4) {
                        Text(smartDateLabel(for: session.date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            HStack(spacing: 2) {
                                Image(systemName: "moon.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(color)
                                Text(formatTime(times.bedtime))
                                    .font(.system(size: 10))
                                    .foregroundColor(.primary)
                            }
                            HStack(spacing: 2) {
                                Image(systemName: "sun.max.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(color)
                                Text(formatTime(times.waketime))
                                    .font(.system(size: 10))
                                    .foregroundColor(.primary)
                            }
                        }
                    }

                    Spacer()

                    // Right side: Mini percentage bars
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(stagePercentages, id: \.stage) { item in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(item.stage.color)
                                    .frame(width: 5, height: 5)
                                Text(stageName(item.stage))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                    .frame(width: 32, alignment: .leading)
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                                        .frame(width: 40, height: 4)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(item.stage.color)
                                        .frame(width: 40 * min(item.percentage / 100, 1.0), height: 4)
                                }
                                Text("\(Int(item.percentage.rounded()))%")
                                    .font(.system(size: 9))
                                    .foregroundColor(.primary)
                                    .frame(width: 26, alignment: .trailing)
                            }
                        }
                    }
                }
            } else {
                HStack {
                    Text("No sleep data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 60)
            }
        }
    }

    private func stageName(_ stage: SleepStage) -> String {
        switch stage {
        case .deep: return "Deep"
        case .core: return "Core"
        case .rem: return "REM"
        case .awake: return "Awake"
        default: return ""
        }
    }
}

// MARK: - Sleep Comparisons Mini Card

/// Mini preview for Comparisons - shows placeholder since comparisons need more data
struct SleepComparisonsMiniCard: View {
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 24))
                    .foregroundColor(color.opacity(0.6))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Compare Over Time")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text("View trends and patterns")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .frame(height: 60)
    }
}
