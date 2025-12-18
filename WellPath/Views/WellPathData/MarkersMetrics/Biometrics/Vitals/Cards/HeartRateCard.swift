//
//  HeartRateCard.swift
//  WellPath
//
//  Individual card for Heart Rate (quantity samples from HealthKit)
//

import SwiftUI

struct HeartRateCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Heart Rate",
            color: color,
            metricId: "DISP_HEART_RATE",
            pillar: pillar,
            cardId: "DISP_HEART_RATE",
            sectionId: "NAV_BIOMETRICS",
            itemType: .biometric
        ) {
            HeartRateMiniCard(color: color)
        } fullScreen: {
            HeartRateFullView(color: color)
        }
    }
}

struct HeartRateMiniCard: View {
    let color: Color
    @StateObject private var loader = HRCardLoader()

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                if loader.isLoading {
                    ProgressView().scaleEffect(0.8)
                } else if loader.hasData {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(loader.latestDisplay)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("BPM")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(loader.smartDateDisplay)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Sparkline showing 7-day range history
            HeartRateRangeSparkline(dataPoints: loader.sparklinePoints, color: color)
        }
        .task {
            await loader.loadWeekData()
        }
    }
}

/// Loads heart rate data from patient_quantity_samples (heart_rate)
/// Computes daily ranges for sparkline and latest value for display
@MainActor
class HRCardLoader: ObservableObject {
    @Published var todayMin: Double?
    @Published var todayMax: Double?
    @Published var latestValue: Double?
    @Published var latestDate: Date?
    @Published var sparklinePoints: [HRRangePoint] = []
    @Published var isLoading = false

    private let supabase = SupabaseManager.shared.client

    var hasData: Bool {
        latestValue != nil && latestValue! > 0
    }

    /// Display the latest value (not range)
    var latestDisplay: String {
        guard let latest = latestValue else { return "--" }
        return "\(Int(latest))"
    }

    /// Smart date display: Today, Yesterday, day name (if this week), or date
    var smartDateDisplay: String {
        guard let date = latestDate else { return "" }

        let calendar = Calendar.current
        let now = Date()

        // Check if today
        if calendar.isDateInToday(date) {
            return "Today"
        }

        // Check if yesterday
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        // Check if within the current week (Monday to Sunday)
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        if date >= startOfWeek {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"  // Full day name
            return formatter.string(from: date)
        }

        // Otherwise show the date
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    var rangeDisplay: String {
        guard let max = todayMax else { return "--" }
        guard let min = todayMin, min > 0, min != max else {
            return "\(Int(max))"
        }
        return "\(Int(min))-\(Int(max))"
    }

    // Legacy properties for compatibility
    var minValue: Double? { todayMin }
    var maxValue: Double? { todayMax }

    func loadWeekData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let patientId = try await supabase.auth.session.user.id

            // Get start of 7 days ago
            let calendar = Calendar.current
            let startOf7DaysAgo = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -6, to: Date())!)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            struct QuantityResult: Codable {
                let quantityValue: Double
                let startTime: Date

                enum CodingKeys: String, CodingKey {
                    case quantityValue = "quantity_value"
                    case startTime = "start_time"
                }
            }

            // Custom decoder for Supabase timestamps
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)

                let iso8601 = ISO8601DateFormatter()
                iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = iso8601.date(from: dateString) {
                    return date
                }

                iso8601.formatOptions = [.withInternetDateTime]
                if let date = iso8601.date(from: dateString) {
                    return date
                }

                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
            }

            let data = try await supabase
                .from("patient_quantity_samples")
                .select("quantity_value, start_time")
                .eq("patient_id", value: patientId)
                .eq("quantity_type", value: "heart_rate")
                .gte("start_time", value: formatter.string(from: startOf7DaysAgo))
                .order("start_time", ascending: false)
                .execute()
                .data

            let results = try decoder.decode([QuantityResult].self, from: data)

            // Set latestDate from the most recent reading (results are ordered DESC)
            latestDate = results.first?.startTime

            // Group by day and compute ranges
            var dailyReadings: [Date: [Double]] = [:]
            var dailyLatest: [Date: Double] = [:]

            for result in results {
                let dayStart = calendar.startOfDay(for: result.startTime)
                if dailyReadings[dayStart] == nil {
                    dailyReadings[dayStart] = []
                    dailyLatest[dayStart] = result.quantityValue  // First (most recent) reading for day
                }
                dailyReadings[dayStart]?.append(result.quantityValue)
            }

            // Build sparkline points sorted by date (oldest first)
            let sortedDays = dailyReadings.keys.sorted()
            let today = calendar.startOfDay(for: Date())

            sparklinePoints = sortedDays.map { day in
                let values = dailyReadings[day] ?? []
                let minVal = values.min() ?? 0
                let maxVal = values.max() ?? 0
                let latest = dailyLatest[day]
                let isLatest = day == sortedDays.last

                return HRRangePoint(
                    date: day,
                    minValue: minVal,
                    maxValue: maxVal,
                    latestValue: isLatest ? latest : nil,
                    isLatest: isLatest
                )
            }

            // Set today's data for the main display
            if let todayValues = dailyReadings[today] {
                todayMin = todayValues.min()
                todayMax = todayValues.max()
                latestValue = dailyLatest[today]
            } else if let latestDay = sortedDays.last, let latestValues = dailyReadings[latestDay] {
                // If no data today, show the most recent day's data
                todayMin = latestValues.min()
                todayMax = latestValues.max()
                latestValue = dailyLatest[latestDay]
            }

        } catch {
            print("HRCardLoader error: \(error)")
        }
    }

    // Legacy method for compatibility
    func loadTodayRange() async {
        await loadWeekData()
    }
}

/// Wrapper to route to HeartRateView
struct HeartRateFullView: View {
    let color: Color

    var body: some View {
        HeartRateView(color: color)
    }
}

#Preview {
    HeartRateCard(color: .red, pillar: "Core Care")
        .padding()
}
