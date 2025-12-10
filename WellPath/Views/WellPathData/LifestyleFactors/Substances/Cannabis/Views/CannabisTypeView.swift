//
//  CannabisTypeView.swift
//  WellPath
//
//  Donut chart showing cannabis consumption breakdown by type.
//

import SwiftUI
import Charts

struct CannabisTypeView: View {
    let color: Color

    @State private var selectedPeriod: TimePeriod = .week
    @State private var currentDate: Date = Date()
    @State private var selectedType: CannabisType?
    @StateObject private var viewModel = CannabisTypeViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else {
                    // Period selector
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach([TimePeriod.day, .week], id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .onChange(of: selectedPeriod) { oldValue, newPeriod in
                        Task {
                            await viewModel.loadData(period: newPeriod, date: currentDate)
                        }
                    }

                    // Period navigation
                    PeriodNavigationView(
                        selectedPeriod: selectedPeriod,
                        currentDate: $currentDate
                    )
                    .onChange(of: currentDate) { oldValue, newDate in
                        Task {
                            await viewModel.loadData(period: selectedPeriod, date: newDate)
                        }
                    }

                    // Total summary
                    if viewModel.totalUses > 0 {
                        totalSummaryCard
                    }

                    // Donut chart
                    if !viewModel.typeData.isEmpty && viewModel.totalUses > 0 {
                        donutChart
                    } else {
                        emptyState
                    }

                    // Type breakdown list
                    if viewModel.totalUses > 0 {
                        typeBreakdownList
                    }
                }
            }
            .padding(.bottom, 16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Cannabis Type")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadData(period: selectedPeriod, date: currentDate)
        }
    }

    private var totalSummaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedPeriod == .day ? "Total Uses" : "Avg Daily Uses")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatValue(viewModel.totalUses))
                        .font(.title)
                        .fontWeight(.bold)
                    Text("uses")
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

    private var donutChart: some View {
        Chart {
            ForEach(CannabisType.allCases, id: \.self) { type in
                if let value = viewModel.typeData[type], value > 0 {
                    let isSelected = selectedType == nil || selectedType == type

                    SectorMark(
                        angle: .value("Uses", value),
                        innerRadius: .ratio(0.618),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(type.color.opacity(isSelected ? 1.0 : 0.3))
                }
            }
        }
        .frame(height: 160)
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf.fill")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No cannabis logged for this period")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 160)
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var typeBreakdownList: some View {
        VStack(spacing: 8) {
            ForEach(CannabisType.allCases, id: \.self) { type in
                if let value = viewModel.typeData[type], value > 0 {
                    typeRow(type: type, value: value)
                }
            }
        }
        .padding(.horizontal)
    }

    private func typeRow(type: CannabisType, value: Double) -> some View {
        let percentage = viewModel.totalUses > 0 ? (value / viewModel.totalUses) * 100 : 0
        let isSelected = selectedType == nil || selectedType == type

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedType = selectedType == type ? nil : type
            }
        }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(type.color)
                    .frame(width: 10, height: 10)
                    .opacity(isSelected ? 1.0 : 0.3)

                Text(type.displayName)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .opacity(isSelected ? 1.0 : 0.3)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(formatValue(value)) \(type.unitPlural)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .opacity(isSelected ? 1.0 : 0.3)
                    Text("(\(Int(percentage.rounded()))%)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .opacity(isSelected ? 1.0 : 0.3)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedType == type ? type.color.opacity(0.12) : Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
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
class CannabisTypeViewModel: ObservableObject {
    @Published var typeData: [CannabisType: Double] = [:]
    @Published var isLoading = false

    let supabase = SupabaseManager.shared.client

    var totalUses: Double {
        typeData.values.reduce(0, +)
    }

    // MARK: - Mini Card Computed Properties

    /// The top consumed cannabis type (for mini card display)
    var topType: CannabisType? {
        typeData
            .filter { $0.value > 0 }
            .max(by: { $0.value < $1.value })?
            .key
    }

    /// Percentage of the top type (for mini card display)
    var topTypePercentage: Int {
        guard let top = topType, totalUses > 0 else { return 0 }
        let value = typeData[top] ?? 0
        return Int((value / totalUses * 100).rounded())
    }

    /// Count of uses for the top type (for mini card display)
    var topTypeCount: Int {
        guard let top = topType else { return 0 }
        return Int((typeData[top] ?? 0).rounded())
    }

    /// Loads data using AggregationQueryService (hourly for D, daily for W/M/6M/Y)
    func loadData(period: TimePeriod, date: Date) async {
        isLoading = true
        typeData.removeAll()

        do {
            let aggIds = CannabisType.allCases.map { $0.aggId }

            for aggId in aggIds {
                let value = try await PatientSamplesQueryService.shared.fetchQuantityValue(
                    quantityType: aggId,
                    period: period,
                    date: date
                ) ?? 0.0
                if let type = CannabisType.allCases.first(where: { $0.aggId == aggId }) {
                    typeData[type] = value
                }
            }

        } catch {
            print("❌ Error loading cannabis type data: \(error)")
        }

        isLoading = false
    }
}


#Preview {
    NavigationStack {
        CannabisTypeView(color: .green)
    }
}
