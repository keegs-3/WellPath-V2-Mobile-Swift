import Foundation
import Supabase

// Daily sleep time model for W/M views
struct DailySleepTime: Identifiable {
    let id = UUID()
    let date: Date
    let bedtime: Date  // Absolute time (e.g., 11 PM)
    let waketime: Date // Absolute time (e.g., 7 AM)
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

    private let supabase = SupabaseManager.shared.client
    private let calendar = Calendar.current

    // MARK: - Cache Entry Models

    struct AggCacheEntry: Codable {
        let aggMetricId: String
        let periodStart: Date
        let periodEnd: Date?
        let valueTime: String?

        enum CodingKeys: String, CodingKey {
            case aggMetricId = "agg_metric_id"
            case periodStart = "period_start"
            case periodEnd = "period_end"
            case valueTime = "value_time"
        }
    }

    // MARK: - Parse Time String (exactly like SleepAnalysisPrimary)

    private func parseTimeString(_ timeString: String) -> Date {
        let components = timeString.split(separator: ":")

        guard components.count >= 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            // Default to 8 PM
            return calendar.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
        }

        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    // MARK: - Daily Sleep Times (for W and M views)

    func loadDailySleepTimes() async {
        isLoading = true
        error = nil

        do {
            guard let userId = try? await supabase.auth.session.user.id else {
                NSLog("[CONSISTENCY] ⚠️ No user session available")
                self.dailySleepTimes = []
                isLoading = false
                return
            }

            // Fetch ALL daily data (no date filters for infinite scroll)
            let cacheResults: [AggCacheEntry] = try await supabase
                .from("aggregation_results_cache")
                .select("agg_metric_id, period_start, period_end, value_time")
                .eq("patient_id", value: userId)
                .in("agg_metric_id", values: ["AGG_SLEEP_BEDTIME", "AGG_SLEEP_WAKETIME"])
                .eq("period_type", value: "daily")
                .eq("calculation_type_id", value: "AVG")
                .order("period_start", ascending: true)
                .execute()
                .value

            NSLog("[CONSISTENCY] 📊 Found \(cacheResults.count) daily cache entries")

            // Group by date
            let groupedByDate = Dictionary(grouping: cacheResults) { entry -> Date in
                calendar.startOfDay(for: entry.periodStart)
            }

            var sleepTimes: [DailySleepTime] = []

            for date in groupedByDate.keys.sorted() {
                guard let entries = groupedByDate[date] else { continue }

                let bedtimeEntries = entries.filter { $0.aggMetricId == "AGG_SLEEP_BEDTIME" }
                let waketimeEntries = entries.filter { $0.aggMetricId == "AGG_SLEEP_WAKETIME" }

                guard let bedtimeEntry = bedtimeEntries.first,
                      let waketimeEntry = waketimeEntries.first,
                      let bedtimeStr = bedtimeEntry.valueTime, !bedtimeStr.isEmpty,
                      let waketimeStr = waketimeEntry.valueTime, !waketimeStr.isEmpty else {
                    continue
                }

                let bedtime = parseTimeString(bedtimeStr)
                let waketime = parseTimeString(waketimeStr)

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

    func loadWeeklySleepAverages() async {
        isLoading = true
        error = nil

        do {
            guard let userId = try? await supabase.auth.session.user.id else {
                NSLog("[CONSISTENCY] ⚠️ No user session available")
                self.weeklySleepAverages = []
                isLoading = false
                return
            }

            // Fetch ALL weekly data (no date filters)
            let cacheResults: [AggCacheEntry] = try await supabase
                .from("aggregation_results_cache")
                .select("agg_metric_id, period_start, period_end, value_time")
                .eq("patient_id", value: userId)
                .in("agg_metric_id", values: ["AGG_SLEEP_BEDTIME", "AGG_SLEEP_WAKETIME"])
                .eq("period_type", value: "weekly")
                .eq("calculation_type_id", value: "AVG")
                .order("period_start", ascending: true)
                .execute()
                .value

            NSLog("[CONSISTENCY] 📊 Found \(cacheResults.count) weekly cache entries")

            // Group by week start date
            let groupedByWeek = Dictionary(grouping: cacheResults) { entry -> Date in
                entry.periodStart
            }

            var averages: [WeeklySleepAverage] = []

            for weekStart in groupedByWeek.keys.sorted() {
                guard let entries = groupedByWeek[weekStart] else { continue }

                let bedtimeEntries = entries.filter { $0.aggMetricId == "AGG_SLEEP_BEDTIME" }
                let waketimeEntries = entries.filter { $0.aggMetricId == "AGG_SLEEP_WAKETIME" }

                guard let bedtimeEntry = bedtimeEntries.first,
                      let waketimeEntry = waketimeEntries.first,
                      let bedtimeStr = bedtimeEntry.valueTime, !bedtimeStr.isEmpty,
                      let waketimeStr = waketimeEntry.valueTime, !waketimeStr.isEmpty else {
                    continue
                }

                let weekEnd = bedtimeEntry.periodEnd ?? calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart

                let bedtime = parseTimeString(bedtimeStr)
                let waketime = parseTimeString(waketimeStr)

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

    func loadMonthlySleepAverages() async {
        isLoading = true
        error = nil

        do {
            guard let userId = try? await supabase.auth.session.user.id else {
                NSLog("[CONSISTENCY] ⚠️ No user session available")
                self.monthlySleepAverages = []
                isLoading = false
                return
            }

            // Fetch ALL monthly data (no date filters)
            let cacheResults: [AggCacheEntry] = try await supabase
                .from("aggregation_results_cache")
                .select("agg_metric_id, period_start, period_end, value_time")
                .eq("patient_id", value: userId)
                .in("agg_metric_id", values: ["AGG_SLEEP_BEDTIME", "AGG_SLEEP_WAKETIME"])
                .eq("period_type", value: "monthly")
                .eq("calculation_type_id", value: "AVG")
                .order("period_start", ascending: true)
                .execute()
                .value

            NSLog("[CONSISTENCY] 📊 Found \(cacheResults.count) monthly cache entries")

            // Group by month start date - use UTC to extract month, then convert to local
            var utcCalendar = Calendar.current
            utcCalendar.timeZone = TimeZone(identifier: "UTC")!

            let groupedByMonth = Dictionary(grouping: cacheResults) { entry -> Date in
                // Extract year/month from UTC periodStart
                var utcComponents = utcCalendar.dateComponents([.year, .month], from: entry.periodStart)
                utcComponents.day = 1

                // Create month start date in LOCAL timezone
                var localComponents = DateComponents()
                localComponents.year = utcComponents.year
                localComponents.month = utcComponents.month
                localComponents.day = 1

                let monthDate = calendar.date(from: localComponents) ?? entry.periodStart
                NSLog("[CONSISTENCY] 📅 Grouping: UTC periodStart=\(entry.periodStart) -> local month=\(monthDate)")
                return monthDate
            }

            var averages: [MonthlySleepAverage] = []

            for monthStart in groupedByMonth.keys.sorted() {
                NSLog("[CONSISTENCY] 📅 Processing month: \(monthStart)")
                guard let entries = groupedByMonth[monthStart] else { continue }

                let bedtimeEntries = entries.filter { $0.aggMetricId == "AGG_SLEEP_BEDTIME" }
                let waketimeEntries = entries.filter { $0.aggMetricId == "AGG_SLEEP_WAKETIME" }

                guard let bedtimeEntry = bedtimeEntries.first,
                      let waketimeEntry = waketimeEntries.first,
                      let bedtimeStr = bedtimeEntry.valueTime, !bedtimeStr.isEmpty,
                      let waketimeStr = waketimeEntry.valueTime, !waketimeStr.isEmpty else {
                    continue
                }

                let monthEnd = bedtimeEntry.periodEnd ?? calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? monthStart

                let bedtime = parseTimeString(bedtimeStr)
                let waketime = parseTimeString(waketimeStr)

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

}
