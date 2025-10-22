//
//  SleepDetailView.swift
//  WellPath
//
//  Created on 2025-10-22
//

import SwiftUI
import Charts

enum PeriodType: String, CaseIterable {
    case daily = "D"
    case weekly = "W"
    case monthly = "M"
    case sixMonth = "6M"
    case yearly = "Y"

    var fullName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .sixMonth: return "6 Month"
        case .yearly: return "Yearly"
        }
    }

    var periodId: String {
        switch self {
        case .daily: return "daily"
        case .weekly: return "weekly"
        case .monthly: return "monthly"
        case .sixMonth: return "6month"
        case .yearly: return "yearly"
        }
    }
}

struct SleepDetailView: View {
    @StateObject private var viewModel = SleepViewModel()
    @State private var selectedPeriod: PeriodType = .weekly

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Summary Card
                SleepSummaryCard(
                    average: viewModel.averageSleep,
                    period: selectedPeriod,
                    dateRange: viewModel.dateRange
                )

                // Period Selector
                PeriodSelector(selectedPeriod: $selectedPeriod)
                    .onChange(of: selectedPeriod) { newPeriod in
                        Task {
                            await viewModel.loadSleepData(for: newPeriod)
                        }
                    }

                // Chart
                SleepChart(data: viewModel.sleepData, period: selectedPeriod)
                    .frame(height: 300)
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Sleep Duration")
        .task {
            await viewModel.loadSleepData(for: selectedPeriod)
        }
    }
}

struct SleepSummaryCard: View {
    let average: Double
    let period: PeriodType
    let dateRange: String

    var body: some View {
        VStack(spacing: 8) {
            Text(period == .daily ? "TOTAL" : "AVERAGE")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", average))
                    .font(.system(size: 48, weight: .semibold))
                Text("hours")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            Text(dateRange)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct PeriodSelector: View {
    @Binding var selectedPeriod: PeriodType

    var body: some View {
        HStack(spacing: 8) {
            ForEach(PeriodType.allCases, id: \.self) { period in
                Button(action: {
                    selectedPeriod = period
                }) {
                    Text(period.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(selectedPeriod == period ? .white : .primary)
                        .frame(minWidth: 44, minHeight: 32)
                        .background(selectedPeriod == period ? Color.blue : Color.clear)
                        .cornerRadius(8)
                }
            }
        }
        .padding(6)
        .background(Color(uiColor: .tertiarySystemBackground))
        .cornerRadius(10)
    }
}

struct SleepChart: View {
    let data: [SleepDataPoint]
    let period: PeriodType

    var body: some View {
        if data.isEmpty {
            VStack {
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No sleep data available")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart(data) { dataPoint in
                BarMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Hours", dataPoint.hours)
                )
                .foregroundStyle(Color.purple.gradient)
                .cornerRadius(4)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(formatXAxisLabel(date: date, period: period))
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }

    func formatXAxisLabel(date: Date, period: PeriodType) -> String {
        let formatter = DateFormatter()
        switch period {
        case .daily:
            formatter.dateFormat = "HH:mm"
        case .weekly:
            formatter.dateFormat = "EEE"
        case .monthly:
            formatter.dateFormat = "d"
        case .sixMonth:
            formatter.dateFormat = "MMM"
        case .yearly:
            formatter.dateFormat = "MMM"
        }
        return formatter.string(from: date)
    }
}

struct SleepDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let hours: Double
}

#Preview {
    NavigationView {
        SleepDetailView()
    }
}
