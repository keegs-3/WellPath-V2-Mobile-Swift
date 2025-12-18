import Foundation
import Supabase

// Daily sleep time model for W/M views - now includes consistency data from database view
struct DailySleepTime: Identifiable {
    let id = UUID()
    let date: Date
    let bedtime: Date  // Absolute time (e.g., 11 PM)
    let waketime: Date // Absolute time (e.g., 7 AM)
    // Rolling 7-day averages (from database)
    let avgBedtimeOffset7d: Double?
    let avgWaketimeOffset7d: Double?
    let daysInRolling7d: Int?
    // Consistency flags (±30 min of rolling average)
    let bedtimeInRange: Bool
    let waketimeInRange: Bool

    // Convenience initializer for basic data (backwards compatibility)
    init(date: Date, bedtime: Date, waketime: Date) {
        self.date = date
        self.bedtime = bedtime
        self.waketime = waketime
        self.avgBedtimeOffset7d = nil
        self.avgWaketimeOffset7d = nil
        self.daysInRolling7d = nil
        self.bedtimeInRange = false
        self.waketimeInRange = false
    }

    // Full initializer with consistency data
    init(date: Date, bedtime: Date, waketime: Date,
         avgBedtimeOffset7d: Double?, avgWaketimeOffset7d: Double?,
         daysInRolling7d: Int?, bedtimeInRange: Bool, waketimeInRange: Bool) {
        self.date = date
        self.bedtime = bedtime
        self.waketime = waketime
        self.avgBedtimeOffset7d = avgBedtimeOffset7d
        self.avgWaketimeOffset7d = avgWaketimeOffset7d
        self.daysInRolling7d = daysInRolling7d
        self.bedtimeInRange = bedtimeInRange
        self.waketimeInRange = waketimeInRange
    }
}

// Weekly average model for 6M view
struct WeeklySleepAverage: Identifiable {
    let id = UUID()
    let weekStartDate: Date
    let weekEndDate: Date
    let avgBedtime: Date
    let avgWaketime: Date
}

// Monthly average model for Y view
struct MonthlySleepAverage: Identifiable {
    let id = UUID()
    let monthStartDate: Date
    let monthEndDate: Date
    let avgBedtime: Date
    let avgWaketime: Date
}

@MainActor
class SleepConsistencyViewModel: ObservableObject {
    @Published var dailySleepTimes: [DailySleepTime] = []
    @Published var weeklySleepAverages: [WeeklySleepAverage] = []
    @Published var monthlySleepAverages: [MonthlySleepAverage] = []
    @Published var isLoading = false
    @Published var error: String?

    private let calendar = Calendar.current

    // MARK: - Daily Sleep Times (from database view)
    // Queries patient_sleep_sessions_summary - all session grouping and consistency calcs done server-side

    func loadDailySleepTimes() async {
        isLoading = true
        error = nil

        do {
            // Query pre-computed sleep sessions from database view (last 90 days)
            let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: Date()) ?? Date()
            let rows = try await PatientSamplesQueryService.shared.fetchSleepSessionSummaries(
                startDate: ninetyDaysAgo,
                endDate: Date()
            )

            NSLog("[CONSISTENCY] 📊 Loaded \(rows.count) sleep sessions from database view")

            // Convert to DailySleepTime models
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            var sleepTimes: [DailySleepTime] = []

            for row in rows {
                // Parse sleep_date string to Date
                // Skip rows with nil bedtime/waketime (legacy data)
                guard let sleepDate = dateFormatter.date(from: row.sleepDate),
                      let bedtime = row.bedtime,
                      let waketime = row.waketime else {
                    continue
                }

                sleepTimes.append(DailySleepTime(
                    date: sleepDate,
                    bedtime: bedtime,
                    waketime: waketime,
                    avgBedtimeOffset7d: row.avgBedtimeOffset7d,
                    avgWaketimeOffset7d: row.avgWaketimeOffset7d,
                    daysInRolling7d: row.daysInRolling7d,
                    bedtimeInRange: row.bedtimeInRange ?? false,
                    waketimeInRange: row.waketimeInRange ?? false
                ))
            }

            self.dailySleepTimes = sleepTimes  // Already sorted descending from query
            NSLog("[CONSISTENCY] ✅ Processed \(sleepTimes.count) daily sleep times with consistency data")

        } catch {
            NSLog("[CONSISTENCY] ❌ Error loading daily sleep times: \(error)")
            self.error = "Failed to load daily sleep data"
        }

        isLoading = false
    }

    // MARK: - Weekly Sleep Averages (for 6M view)
    // Aggregates daily sleep times into weekly averages

    func loadWeeklySleepAverages() async {
        // First ensure daily data is loaded
        if dailySleepTimes.isEmpty {
            await loadDailySleepTimes()
        }

        isLoading = true
        error = nil

        // Group daily sleep times by week
        var weekToSleepTimes: [Date: [DailySleepTime]] = [:]

        for daily in dailySleepTimes {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: daily.date)?.start ?? daily.date
            weekToSleepTimes[weekStart, default: []].append(daily)
        }

        var averages: [WeeklySleepAverage] = []

        for weekStart in weekToSleepTimes.keys.sorted() {
            guard let weekSleepTimes = weekToSleepTimes[weekStart], !weekSleepTimes.isEmpty else { continue }

            // Calculate average bedtime/waketime as minutes since 6 PM
            let avgBedtimeMinutes = weekSleepTimes.map { calculateOffsetFromSixPM($0.bedtime) }.reduce(0, +) / weekSleepTimes.count
            let avgWaketimeMinutes = weekSleepTimes.map { calculateOffsetFromSixPM($0.waketime) }.reduce(0, +) / weekSleepTimes.count

            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart

            // Convert back to Date for display
            let sixPMRef = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
            let avgBedtime = calendar.date(byAdding: .minute, value: avgBedtimeMinutes, to: sixPMRef) ?? sixPMRef
            let avgWaketime = calendar.date(byAdding: .minute, value: avgWaketimeMinutes, to: sixPMRef) ?? sixPMRef

            averages.append(WeeklySleepAverage(
                weekStartDate: weekStart,
                weekEndDate: weekEnd,
                avgBedtime: avgBedtime,
                avgWaketime: avgWaketime
            ))
        }

        self.weeklySleepAverages = averages.sorted { $0.weekStartDate > $1.weekStartDate }
        NSLog("[CONSISTENCY] ✅ Loaded \(averages.count) weekly sleep averages")

        isLoading = false
    }

    // Calculate minutes since 6 PM (for averaging times across midnight)
    private func calculateOffsetFromSixPM(_ time: Date) -> Int {
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)

        if hour >= 18 {
            return (hour - 18) * 60 + minute
        } else {
            return (24 - 18 + hour) * 60 + minute
        }
    }

    // MARK: - Monthly Sleep Averages (for Y view)
    // Aggregates daily sleep times into monthly averages

    func loadMonthlySleepAverages() async {
        // First ensure daily data is loaded
        if dailySleepTimes.isEmpty {
            await loadDailySleepTimes()
        }

        isLoading = true
        error = nil

        // Group daily sleep times by month
        var monthToSleepTimes: [Date: [DailySleepTime]] = [:]

        for daily in dailySleepTimes {
            let monthComponents = calendar.dateComponents([.year, .month], from: daily.date)
            let monthStart = calendar.date(from: monthComponents) ?? daily.date
            monthToSleepTimes[monthStart, default: []].append(daily)
        }

        var averages: [MonthlySleepAverage] = []

        for monthStart in monthToSleepTimes.keys.sorted() {
            guard let monthSleepTimes = monthToSleepTimes[monthStart], !monthSleepTimes.isEmpty else { continue }

            // Calculate average bedtime/waketime as minutes since 6 PM
            let avgBedtimeMinutes = monthSleepTimes.map { calculateOffsetFromSixPM($0.bedtime) }.reduce(0, +) / monthSleepTimes.count
            let avgWaketimeMinutes = monthSleepTimes.map { calculateOffsetFromSixPM($0.waketime) }.reduce(0, +) / monthSleepTimes.count

            let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? monthStart

            // Convert back to Date for display
            let sixPMRef = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
            let avgBedtime = calendar.date(byAdding: .minute, value: avgBedtimeMinutes, to: sixPMRef) ?? sixPMRef
            let avgWaketime = calendar.date(byAdding: .minute, value: avgWaketimeMinutes, to: sixPMRef) ?? sixPMRef

            averages.append(MonthlySleepAverage(
                monthStartDate: monthStart,
                monthEndDate: monthEnd,
                avgBedtime: avgBedtime,
                avgWaketime: avgWaketime
            ))
        }

        self.monthlySleepAverages = averages.sorted { $0.monthStartDate > $1.monthStartDate }
        NSLog("[CONSISTENCY] ✅ Loaded \(averages.count) monthly sleep averages")

        isLoading = false
    }

}
