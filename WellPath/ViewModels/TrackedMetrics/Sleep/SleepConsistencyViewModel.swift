import Foundation
import Supabase

// Daily sleep time model for W/M views
struct DailySleepTime: Identifiable {
    let id = UUID()
    let date: Date // UTC date
    let bedtime: Date // UTC timestamp for chart positioning
    let waketime: Date // UTC timestamp for chart positioning
}

// Weekly average model for 6M view
struct WeeklySleepAverage: Identifiable {
    let id = UUID()
    let weekStartDate: Date // UTC start-of-day Monday
    let weekEndDate: Date // UTC start-of-day Sunday
    let avgBedtime: Date // UTC timestamp
    let avgWaketime: Date // UTC timestamp
}

// Monthly average model for Y view
struct MonthlySleepAverage: Identifiable {
    let id = UUID()
    let monthStartDate: Date // UTC start-of-month
    let monthEndDate: Date // UTC end-of-month
    let avgBedtime: Date // UTC timestamp
    let avgWaketime: Date // UTC timestamp
}

@MainActor
class SleepConsistencyViewModel: ObservableObject {
    @Published var dailySleepTimes: [DailySleepTime] = []
    @Published var weeklySleepAverages: [WeeklySleepAverage] = []
    @Published var monthlySleepAverages: [MonthlySleepAverage] = []
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    // MARK: - Cache Entry Models

    struct AggCacheEntry: Codable {
        let aggMetricId: String
        let periodStart: Date
        let periodEnd: Date?
        let value: Double?
        let valueTime: String?

        enum CodingKeys: String, CodingKey {
            case aggMetricId = "agg_metric_id"
            case periodStart = "period_start"
            case periodEnd = "period_end"
            case value
            case valueTime = "value_time"
        }
    }

    // MARK: - Daily Sleep Times (for W and M views)

    func loadDailySleepTimes(daysBack: Int, daysAhead: Int) async {
        isLoading = true
        error = nil

        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        // Calculate date range
        let today = utcCalendar.startOfDay(for: Date())
        guard let startDate = utcCalendar.date(byAdding: .day, value: -daysBack, to: today),
              let endDate = utcCalendar.date(byAdding: .day, value: daysAhead, to: today) else {
            error = "Failed to calculate date range"
            isLoading = false
            return
        }

        let startUTCString = startDate.ISO8601Format()
        let endUTCString = endDate.ISO8601Format()

        NSLog("[CONSISTENCY] 📊 loadDailySleepTimes: Range \(startUTCString) to \(endUTCString)")

        do {
            guard let userId = getUserId() else {
                error = "User ID not found"
                isLoading = false
                return
            }

            // Query daily bedtime and waketime from aggregation_results_cache
            let cacheResults: [AggCacheEntry] = try await supabase
                .from("aggregation_results_cache")
                .select("agg_metric_id, period_start, period_end, value_time")
                .eq("patient_id", value: userId)
                .in("agg_metric_id", values: ["AGG_SLEEP_BEDTIME", "AGG_SLEEP_WAKETIME"])
                .eq("period_type", value: "daily")
                .eq("calculation_type_id", value: "AVG")
                .gte("period_start", value: startUTCString)
                .lte("period_start", value: endUTCString)
                .order("period_start", ascending: true)
                .execute()
                .value

            NSLog("[CONSISTENCY] 📊 Found \(cacheResults.count) daily cache entries")

            // Group by date
            let groupedByDate = Dictionary(grouping: cacheResults) { entry -> Date in
                utcCalendar.startOfDay(for: entry.periodStart)
            }

            var sleepTimes: [DailySleepTime] = []

            for date in groupedByDate.keys.sorted() {
                guard let entries = groupedByDate[date] else { continue }

                let bedtimeEntries = entries.filter { $0.aggMetricId == "AGG_SLEEP_BEDTIME" }
                let waketimeEntries = entries.filter { $0.aggMetricId == "AGG_SLEEP_WAKETIME" }

                guard let bedtimeEntry = bedtimeEntries.first,
                      let waketimeEntry = waketimeEntries.first,
                      let bedtimeTime = bedtimeEntry.valueTime,
                      let waketimeTime = waketimeEntry.valueTime else {
                    NSLog("[CONSISTENCY] ⚠️ Date \(date) missing valid sleep times")
                    continue
                }

                // Parse time strings and create Date objects
                let bedtime = parseTimeString(bedtimeTime)
                let waketime = parseTimeString(waketimeTime)

                sleepTimes.append(DailySleepTime(
                    date: date,
                    bedtime: bedtime,
                    waketime: waketime
                ))
            }

            self.dailySleepTimes = sleepTimes
            NSLog("[CONSISTENCY] ✅ Loaded \(sleepTimes.count) daily sleep times")

        } catch {
            NSLog("[CONSISTENCY] ❌ Error loading daily sleep times: \(error)")
            self.error = "Failed to load daily sleep data"
        }

        isLoading = false
    }

    // MARK: - Weekly Sleep Averages (for 6M view)

    func loadWeeklySleepAverages(weeksBack: Int, weeksAhead: Int) async {
        isLoading = true
        error = nil

        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        utcCalendar.firstWeekday = 2 // Monday

        // Calculate date range
        let today = utcCalendar.startOfDay(for: Date())
        guard let startDate = utcCalendar.date(byAdding: .weekOfYear, value: -weeksBack, to: today),
              let endDate = utcCalendar.date(byAdding: .weekOfYear, value: weeksAhead, to: today) else {
            error = "Failed to calculate date range"
            isLoading = false
            return
        }

        let startUTCString = startDate.ISO8601Format()
        let endUTCString = endDate.ISO8601Format()

        NSLog("[CONSISTENCY] 📊 loadWeeklySleepAverages: Range \(startUTCString) to \(endUTCString)")

        do {
            guard let userId = getUserId() else {
                error = "User ID not found"
                isLoading = false
                return
            }

            // Query weekly averages from aggregation_results_cache
            let cacheResults: [AggCacheEntry] = try await supabase
                .from("aggregation_results_cache")
                .select("agg_metric_id, period_start, period_end, value_time")
                .eq("patient_id", value: userId)
                .in("agg_metric_id", values: ["AGG_SLEEP_BEDTIME", "AGG_SLEEP_WAKETIME"])
                .eq("period_type", value: "weekly")
                .eq("calculation_type_id", value: "AVG")
                .gte("period_start", value: startUTCString)
                .lte("period_start", value: endUTCString)
                .order("period_start", ascending: true)
                .execute()
                .value

            NSLog("[CONSISTENCY] 📊 Found \(cacheResults.count) weekly cache entries")

            // Group by week start date
            let groupedByWeek = Dictionary(grouping: cacheResults) { entry -> Date in
                utcCalendar.startOfDay(for: entry.periodStart)
            }

            var averages: [WeeklySleepAverage] = []

            for weekStart in groupedByWeek.keys.sorted() {
                guard let entries = groupedByWeek[weekStart] else { continue }

                let bedtimeEntries = entries.filter { $0.aggMetricId == "AGG_SLEEP_BEDTIME" }
                let waketimeEntries = entries.filter { $0.aggMetricId == "AGG_SLEEP_WAKETIME" }

                guard let bedtimeEntry = bedtimeEntries.first,
                      let waketimeEntry = waketimeEntries.first,
                      let bedtimeTime = bedtimeEntry.valueTime,
                      let waketimeTime = waketimeEntry.valueTime else {
                    NSLog("[CONSISTENCY] ⚠️ Week \(weekStart) missing valid average times")
                    continue
                }

                // Use period_end if available, otherwise calculate
                let weekEnd = bedtimeEntry.periodEnd ?? utcCalendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart

                // Parse time strings
                let bedtime = parseTimeString(bedtimeTime)
                let waketime = parseTimeString(waketimeTime)

                averages.append(WeeklySleepAverage(
                    weekStartDate: weekStart,
                    weekEndDate: weekEnd,
                    avgBedtime: bedtime,
                    avgWaketime: waketime
                ))
            }

            self.weeklySleepAverages = averages
            NSLog("[CONSISTENCY] ✅ Loaded \(averages.count) weekly sleep averages")

        } catch {
            NSLog("[CONSISTENCY] ❌ Error loading weekly averages: \(error)")
            self.error = "Failed to load weekly sleep data"
        }

        isLoading = false
    }

    // MARK: - Monthly Sleep Averages (for Y view)

    func loadMonthlySleepAverages(monthsBack: Int, monthsAhead: Int) async {
        isLoading = true
        error = nil

        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        // Calculate date range
        let today = utcCalendar.startOfDay(for: Date())
        guard let startDate = utcCalendar.date(byAdding: .month, value: -monthsBack, to: today),
              let endDate = utcCalendar.date(byAdding: .month, value: monthsAhead, to: today) else {
            error = "Failed to calculate date range"
            isLoading = false
            return
        }

        let startUTCString = startDate.ISO8601Format()
        let endUTCString = endDate.ISO8601Format()

        NSLog("[CONSISTENCY] 📊 loadMonthlySleepAverages: Range \(startUTCString) to \(endUTCString)")

        do {
            guard let userId = getUserId() else {
                error = "User ID not found"
                isLoading = false
                return
            }

            // Query monthly averages from aggregation_results_cache
            let cacheResults: [AggCacheEntry] = try await supabase
                .from("aggregation_results_cache")
                .select("agg_metric_id, period_start, period_end, value_time")
                .eq("patient_id", value: userId)
                .in("agg_metric_id", values: ["AGG_SLEEP_BEDTIME", "AGG_SLEEP_WAKETIME"])
                .eq("period_type", value: "monthly")
                .eq("calculation_type_id", value: "AVG")
                .gte("period_start", value: startUTCString)
                .lte("period_start", value: endUTCString)
                .order("period_start", ascending: true)
                .execute()
                .value

            NSLog("[CONSISTENCY] 📊 Found \(cacheResults.count) monthly cache entries")

            // Group by month start date
            let groupedByMonth = Dictionary(grouping: cacheResults) { entry -> Date in
                // Get start of month for period_start
                let components = utcCalendar.dateComponents([.year, .month], from: entry.periodStart)
                return utcCalendar.date(from: components) ?? entry.periodStart
            }

            var averages: [MonthlySleepAverage] = []

            for monthStart in groupedByMonth.keys.sorted() {
                guard let entries = groupedByMonth[monthStart] else { continue }

                let bedtimeEntries = entries.filter { $0.aggMetricId == "AGG_SLEEP_BEDTIME" }
                let waketimeEntries = entries.filter { $0.aggMetricId == "AGG_SLEEP_WAKETIME" }

                guard let bedtimeEntry = bedtimeEntries.first,
                      let waketimeEntry = waketimeEntries.first,
                      let bedtimeTime = bedtimeEntry.valueTime,
                      let waketimeTime = waketimeEntry.valueTime else {
                    NSLog("[CONSISTENCY] ⚠️ Month \(monthStart) missing valid average times")
                    continue
                }

                // Use period_end if available, otherwise calculate
                let monthEnd = bedtimeEntry.periodEnd ?? utcCalendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? monthStart

                // Parse time strings
                let bedtime = parseTimeString(bedtimeTime)
                let waketime = parseTimeString(waketimeTime)

                averages.append(MonthlySleepAverage(
                    monthStartDate: monthStart,
                    monthEndDate: monthEnd,
                    avgBedtime: bedtime,
                    avgWaketime: waketime
                ))
            }

            self.monthlySleepAverages = averages
            NSLog("[CONSISTENCY] ✅ Loaded \(averages.count) monthly sleep averages")

        } catch {
            NSLog("[CONSISTENCY] ❌ Error loading monthly averages: \(error)")
            self.error = "Failed to load monthly sleep data"
        }

        isLoading = false
    }

    // MARK: - Helper Functions

    private func getUserId() -> String? {
        return UserDefaults.standard.string(forKey: "userId")
    }

    private func parseTimeString(_ timeString: String) -> Date {
        // Parse "HH:mm:ss" or "HH:mm" format
        // Returns a Date with time component for chart positioning
        let components = timeString.split(separator: ":").map { Int($0) ?? 0 }
        guard components.count >= 2 else {
            return Date() // Fallback
        }

        let hour = components[0]
        let minute = components[1]

        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!

        // Create date with time component
        var dateComponents = DateComponents()
        dateComponents.year = 2000
        dateComponents.month = 1
        dateComponents.day = 1
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = 0

        return calendar.date(from: dateComponents) ?? Date()
    }
}
