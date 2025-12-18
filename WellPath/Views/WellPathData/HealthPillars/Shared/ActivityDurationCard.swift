//
//  ActivityDurationCard.swift
//  WellPath
//
//  Reusable duration card with chart for activity tracking
//  Used by: Mindfulness, Outdoor Time, Social Interactions, Cognitive Activities
//

import SwiftUI
import Charts

struct ActivityDurationCard: View {
    let config: ActivityCategoryConfig
    let pillar: String
    let sectionId: String

    @State private var chartData: [ActivityChartDataPoint] = []
    @State private var recentEntries: [ActivityEntry] = []
    @State private var totalMinutes: Double = 0
    @State private var entryCount: Int = 0
    @State private var isLoading = true
    @State private var selectedPeriod: ChartPeriod = .week

    private let supabase = SupabaseManager.shared.client

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: config.icon)
                    .foregroundColor(config.color)
                Text(config.name)
                    .font(.headline)
                Spacer()

                // Period selector
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(ChartPeriod.allCases, id: \.self) { period in
                        Text(period.shortLabel).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                // Summary stats
                HStack(spacing: 24) {
                    VStack(alignment: .leading) {
                        Text(formatDuration(totalMinutes))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(config.color)
                        Text("Total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading) {
                        Text("\(entryCount)")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Sessions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if entryCount > 0 {
                        VStack(alignment: .leading) {
                            Text(formatDuration(totalMinutes / Double(max(1, selectedPeriod.dayCount))))
                                .font(.title)
                                .fontWeight(.bold)
                            Text("Daily Avg")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Chart
                if !chartData.isEmpty {
                    Chart(chartData) { point in
                        BarMark(
                            x: .value("Date", point.date, unit: selectedPeriod.chartUnit),
                            y: .value("Minutes", point.value)
                        )
                        .foregroundStyle(config.color.gradient)
                        .cornerRadius(4)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisGridLine()
                            AxisValueLabel(format: selectedPeriod.dateFormat)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let mins = value.as(Double.self) {
                                    Text("\(Int(mins))m")
                                }
                            }
                        }
                    }
                    .frame(height: 150)
                } else {
                    Text("No data for this period")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 150)
                }

                // Recent entries
                if !recentEntries.isEmpty {
                    Divider()

                    Text("Recent")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ForEach(recentEntries.prefix(3)) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.displayName)
                                    .font(.subheadline)
                                Text(formatEntryDate(entry.startTime))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(formatDuration(entry.durationMinutes))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(config.color)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .task {
            await loadData()
        }
        .onChange(of: selectedPeriod) { _, _ in
            Task {
                await loadData()
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true

        do {
            let userId = try await supabase.auth.session.user.id

            let startDate = selectedPeriod.startDate
            let endDate = Date()

            struct ActivitySampleRow: Codable {
                let id: UUID
                let quantityType: String
                let quantityValue: Double
                let startTime: Date
                let endTime: Date?
                let source: String?
                let metadata: ActivityMetadataRow?

                enum CodingKeys: String, CodingKey {
                    case id
                    case quantityType = "quantity_type"
                    case quantityValue = "quantity_value"
                    case startTime = "start_time"
                    case endTime = "end_time"
                    case source
                    case metadata
                }
            }

            struct ActivityMetadataRow: Codable {
                let activitySubtype: String?
                let notes: String?

                enum CodingKeys: String, CodingKey {
                    case activitySubtype = "activity_subtype"
                    case notes
                }
            }

            let rows: [ActivitySampleRow] = try await supabase
                .from("patient_quantity_samples")
                .select("id, quantity_type, quantity_value, start_time, end_time, source, metadata")
                .eq("patient_id", value: userId.uuidString)
                .eq("quantity_type", value: config.quantityType)
                .gte("start_time", value: ISO8601DateFormatter().string(from: startDate))
                .lte("start_time", value: ISO8601DateFormatter().string(from: endDate))
                .order("start_time", ascending: false)
                .execute()
                .value

            // Process data
            let entries = rows.map { row in
                ActivityEntry(
                    id: row.id,
                    quantityType: row.quantityType,
                    durationMinutes: row.quantityValue,
                    startTime: row.startTime,
                    endTime: row.endTime,
                    activitySubtype: row.metadata?.activitySubtype,
                    notes: row.metadata?.notes,
                    source: row.source
                )
            }

            // Group by date for chart
            let grouped = Dictionary(grouping: entries) { entry in
                Calendar.current.startOfDay(for: entry.startTime)
            }

            let chartPoints = grouped.map { date, entries in
                ActivityChartDataPoint(
                    date: date,
                    value: entries.reduce(0) { $0 + $1.durationMinutes }
                )
            }.sorted { $0.date < $1.date }

            await MainActor.run {
                chartData = chartPoints
                recentEntries = entries
                totalMinutes = entries.reduce(0) { $0 + $1.durationMinutes }
                entryCount = entries.count
                isLoading = false
            }

        } catch {
            await MainActor.run {
                print("Error loading activity data: \(error)")
                isLoading = false
            }
        }
    }

    // MARK: - Formatters

    private func formatDuration(_ minutes: Double) -> String {
        let totalMinutes = Int(minutes)
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }

    private func formatEntryDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Today, \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Chart Data Point

struct ActivityChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - Chart Period

enum ChartPeriod: String, CaseIterable {
    case day = "D"
    case week = "W"
    case month = "M"
    case sixMonths = "6M"
    case year = "Y"

    var shortLabel: String { rawValue }

    var dayCount: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .sixMonths: return 180
        case .year: return 365
        }
    }

    var startDate: Date {
        Calendar.current.date(byAdding: .day, value: -dayCount, to: Date()) ?? Date()
    }

    var chartUnit: Calendar.Component {
        switch self {
        case .day: return .hour
        case .week, .month: return .day
        case .sixMonths, .year: return .weekOfYear
        }
    }

    var dateFormat: Date.FormatStyle {
        switch self {
        case .day: return .dateTime.hour()
        case .week: return .dateTime.weekday(.abbreviated)
        case .month: return .dateTime.day()
        case .sixMonths, .year: return .dateTime.month(.abbreviated)
        }
    }
}

#Preview {
    ScrollView {
        ActivityDurationCard(
            config: .mindfulness,
            pillar: "Stress Management",
            sectionId: "NAV_STRESS"
        )
        .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}
