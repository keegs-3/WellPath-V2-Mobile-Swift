//
//  CannabisQuantityView.swift
//  WellPath
//
//  Line chart showing cannabis usage over time with type filter dropdown.
//

import SwiftUI
import Charts

struct CannabisQuantityView: View {
    let color: Color

    @State private var selectedPeriod: TimePeriod = .week
    @State private var currentDate: Date = Date()
    @State private var selectedType: CannabisType = .flower
    @StateObject private var viewModel = CannabisQuantityViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Type selector dropdown
                HStack {
                    Text("Type")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Menu {
                        ForEach(CannabisType.allCases, id: \.self) { type in
                            Button(action: {
                                selectedType = type
                                Task {
                                    await viewModel.loadData(
                                        type: type,
                                        period: selectedPeriod,
                                        date: currentDate
                                    )
                                }
                            }) {
                                HStack {
                                    Text(type.displayName)
                                    if type == selectedType {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(selectedType.color)
                                .frame(width: 8, height: 8)
                            Text(selectedType.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)

                // Period selector
                Picker("Period", selection: $selectedPeriod) {
                    ForEach([TimePeriod.day, .week], id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: selectedPeriod) { oldValue, newPeriod in
                    Task {
                        await viewModel.loadData(
                            type: selectedType,
                            period: newPeriod,
                            date: currentDate
                        )
                    }
                }

                // Period navigation
                PeriodNavigationView(
                    selectedPeriod: selectedPeriod,
                    currentDate: $currentDate
                )
                .onChange(of: currentDate) { oldValue, newDate in
                    Task {
                        await viewModel.loadData(
                            type: selectedType,
                            period: selectedPeriod,
                            date: newDate
                        )
                    }
                }

                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else {
                    // Summary card
                    summaryCard

                    // Chart
                    if !viewModel.chartData.isEmpty {
                        chart
                    } else {
                        emptyState
                    }
                }
            }
            .padding(.bottom, 16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Cannabis")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadData(
                type: selectedType,
                period: selectedPeriod,
                date: currentDate
            )
        }
    }

    private var summaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedPeriod == .day ? "Total \(selectedType.unitPlural.capitalized)" : "Avg Daily")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatValue(viewModel.totalValue))
                        .font(.title)
                        .fontWeight(.bold)
                    Text(selectedType.unitPlural)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var chart: some View {
        Chart(viewModel.chartData) { point in
            BarMark(
                x: .value("Date", point.date),
                y: .value(selectedType.unitPlural.capitalized, point.value)
            )
            .foregroundStyle(selectedType.color.gradient)
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisValueLabel(format: selectedPeriod == .day ? .dateTime.hour() : .dateTime.weekday(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 200)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf.fill")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No \(selectedType.displayName.lowercased()) logged for this period")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func formatValue(_ value: Double) -> String {
        if value == 0 {
            return "0"
        } else if value >= 10 {
            return String(format: "%.0f", value)
        } else if value >= 1 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

// MARK: - ViewModel

@MainActor
class CannabisQuantityViewModel: ObservableObject {
    @Published var chartData: [ChartDataPoint] = []
    @Published var totalValue: Double = 0
    @Published var isLoading = false

    let supabase = SupabaseManager.shared.client

    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    /// Loads time series data from patient_quantity_samples
    func loadData(type: CannabisType, period: TimePeriod, date: Date) async {
        isLoading = true
        chartData.removeAll()
        totalValue = 0

        do {
            // Fetch time series using PatientSamplesQueryService
            let timeSeries = try await PatientSamplesQueryService.shared.fetchQuantityTimeSeries(
                quantityType: type.quantityType,
                period: period,
                date: date
            )

            var points: [ChartDataPoint] = []
            var total: Double = 0

            for (pointDate, value) in timeSeries {
                points.append(ChartDataPoint(date: pointDate, value: value))
                total += value
            }

            chartData = points

            // For Day: total sum, For Week: daily average
            if period == .day {
                totalValue = total
            } else {
                let dayCount = max(1, points.count)
                totalValue = total / Double(dayCount)
            }

        } catch {
            print("❌ Error loading cannabis data: \(error)")
        }

        isLoading = false
    }
}


#Preview {
    NavigationStack {
        CannabisQuantityView(color: .green)
    }
}
