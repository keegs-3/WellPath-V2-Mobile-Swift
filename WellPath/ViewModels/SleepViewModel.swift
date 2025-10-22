//
//  SleepViewModel.swift
//  WellPath
//
//  Created on 2025-10-22
//

import Foundation
import Supabase

@MainActor
class SleepViewModel: ObservableObject {
    @Published var sleepData: [SleepDataPoint] = []
    @Published var averageSleep: Double = 0.0
    @Published var dateRange: String = ""
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    func loadSleepData(for period: PeriodType) async {
        isLoading = true
        error = nil

        do {
            // Query aggregation_results_cache for sleep duration
            let response = try await supabase
                .from("aggregation_results_cache")
                .select()
                .eq("agg_metric_id", value: "AGG_SLEEP_DURATION")
                .eq("period_type", value: period.periodId)
                .order("period_start", ascending: true)
                .execute()

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let results = try decoder.decode([AggregationResult].self, from: response.data)

            // Convert to chart data points
            sleepData = results.map { result in
                SleepDataPoint(
                    date: result.periodStart,
                    hours: result.value / 60.0  // Convert minutes to hours
                )
            }

            // Calculate average
            if !results.isEmpty {
                let totalMinutes = results.reduce(0.0) { $0 + $1.value }
                averageSleep = (totalMinutes / Double(results.count)) / 60.0
            }

            // Set date range
            if let first = results.first, let last = results.last {
                dateRange = formatDateRange(start: first.periodStart, end: last.periodEnd)
            }

        } catch {
            self.error = error.localizedDescription
            print("Error loading sleep data: \\(error)")
        }

        isLoading = false
    }

    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: end)

        return "\\(startStr) - \\(endStr)"
    }
}

struct AggregationResult: Codable {
    let aggMetricId: String
    let periodType: String
    let periodStart: Date
    let periodEnd: Date
    let value: Double

    enum CodingKeys: String, CodingKey {
        case aggMetricId = "agg_metric_id"
        case periodType = "period_type"
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case value
    }
}
