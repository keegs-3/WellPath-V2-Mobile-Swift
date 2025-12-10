//
//  SubstanceTypeView.swift
//  WellPath
//
//  Generic type breakdown view for substances with donut chart.
//  Configurable for any substance type (tobacco, nicotine, OTC, recreational).
//

import SwiftUI
import Charts
import Supabase

struct SubstanceTypeView: View {
    let config: SubstanceTypeConfig

    @State private var selectedPeriod: TimePeriod = .week
    @State private var currentDate: Date = Date()
    @State private var selectedType: String?
    @StateObject private var viewModel: SubstanceTypeViewModel

    init(config: SubstanceTypeConfig) {
        self.config = config
        _viewModel = StateObject(wrappedValue: SubstanceTypeViewModel(config: config))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else {
                    // Period selector (D, W only for substances)
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
                            await viewModel.loadDataForPeriod(period: newPeriod, date: currentDate)
                        }
                    }

                    // Period navigation
                    PeriodNavigationView(
                        selectedPeriod: selectedPeriod,
                        currentDate: $currentDate
                    )
                    .onChange(of: currentDate) { oldValue, newDate in
                        Task {
                            await viewModel.loadDataForPeriod(period: selectedPeriod, date: newDate)
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
        .navigationTitle(config.title)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadDataForPeriod(period: selectedPeriod, date: currentDate)
        }
    }

    private var totalSummaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedPeriod == .day ? "Total \(config.unitPlural.capitalized)" : "Avg Daily \(config.unitPlural.capitalized)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatValue(viewModel.totalUses))
                        .font(.title)
                        .fontWeight(.bold)
                    Text(config.unitPlural)
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
            ForEach(Array(viewModel.typeData.keys.sorted()), id: \.self) { typeId in
                if let value = viewModel.typeData[typeId], value > 0 {
                    let isSelected = selectedType == nil || selectedType == typeId

                    SectorMark(
                        angle: .value(config.unitPlural.capitalized, value),
                        innerRadius: .ratio(0.618),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(
                        viewModel.getColor(for: typeId)
                            .opacity(isSelected ? 1.0 : 0.3)
                    )
                }
            }
        }
        .frame(height: 160)
        .chartAngleSelection(value: $selectedType)
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: config.icon)
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No \(config.unitPlural) logged for this period")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 160)
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var typeBreakdownList: some View {
        VStack(spacing: 8) {
            ForEach(Array(viewModel.typeData.keys.sorted()), id: \.self) { typeId in
                if let value = viewModel.typeData[typeId], value > 0 {
                    typeRow(typeId: typeId, value: value)
                }
            }
        }
        .padding(.horizontal)
    }

    private func typeRow(typeId: String, value: Double) -> some View {
        let percentage = viewModel.totalUses > 0 ? (value / viewModel.totalUses) * 100 : 0
        let isSelected = selectedType == nil || selectedType == typeId

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedType = selectedType == typeId ? nil : typeId
            }
        }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(viewModel.getColor(for: typeId))
                    .frame(width: 10, height: 10)
                    .opacity(isSelected ? 1.0 : 0.3)

                Text(viewModel.getDisplayName(for: typeId))
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .opacity(isSelected ? 1.0 : 0.3)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(formatValue(value)) \(config.unitPlural)")
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
                    .fill(selectedType == typeId ? viewModel.getColor(for: typeId).opacity(0.12) : Color(uiColor: .secondarySystemGroupedBackground))
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

// MARK: - Configuration

struct SubstanceTypeConfig {
    let title: String
    let icon: String
    let baseColor: Color
    let unitPlural: String
    let quantityType: String        // e.g., "tobacco_uses", "nicotine_uses"
    let metadataKey: String         // e.g., "tobacco_type", "nicotine_type"
    let typeValues: [String]        // e.g., ["cigarette", "cigar", "pipe", ...]
    let displayNames: [String: String]
    let typeColors: [String: Color]

    static let tobacco = SubstanceTypeConfig(
        title: "Tobacco Type",
        icon: "smoke",
        baseColor: .brown,
        unitPlural: "uses",
        quantityType: "tobacco_uses",
        metadataKey: "tobacco_type",
        typeValues: ["cigarette", "cigar", "pipe", "chewing", "other"],
        displayNames: [
            "cigarette": "Cigarette",
            "cigar": "Cigar",
            "pipe": "Pipe",
            "chewing": "Chewing Tobacco",
            "other": "Other"
        ],
        typeColors: [
            "cigarette": Color.orange,
            "cigar": Color.brown,
            "pipe": Color(red: 0.6, green: 0.4, blue: 0.2),
            "chewing": Color(red: 0.4, green: 0.3, blue: 0.2),
            "other": Color.gray
        ]
    )

    static let nicotine = SubstanceTypeConfig(
        title: "Nicotine Type",
        icon: "cloud",
        baseColor: .cyan,
        unitPlural: "uses",
        quantityType: "nicotine_uses",
        metadataKey: "nicotine_type",
        typeValues: ["vape", "patch", "gum", "lozenge", "pouch", "other"],
        displayNames: [
            "vape": "Vape",
            "patch": "Patch",
            "gum": "Gum",
            "lozenge": "Lozenge",
            "pouch": "Pouch",
            "other": "Other"
        ],
        typeColors: [
            "vape": Color.cyan,
            "patch": Color.blue,
            "gum": Color.mint,
            "lozenge": Color.teal,
            "pouch": Color.indigo,
            "other": Color.gray
        ]
    )

}

// MARK: - ViewModel

@MainActor
class SubstanceTypeViewModel: ObservableObject {
    @Published var typeData: [String: Double] = [:]
    @Published var isLoading = false

    let supabase = SupabaseManager.shared.client
    private let config: SubstanceTypeConfig

    init(config: SubstanceTypeConfig) {
        self.config = config
    }

    var totalUses: Double {
        typeData.values.reduce(0, +)
    }

    // MARK: - Mini Card Computed Properties

    /// The top consumed type (for mini card display)
    var topTypeId: String? {
        typeData
            .filter { $0.value > 0 }
            .max(by: { $0.value < $1.value })?
            .key
    }

    /// Display name of the top type (for mini card display)
    var topTypeDisplayName: String {
        guard let topId = topTypeId else { return "—" }
        return getDisplayName(for: topId)
    }

    /// Percentage of the top type (for mini card display)
    var topTypePercentage: Int {
        guard let topId = topTypeId, totalUses > 0 else { return 0 }
        let value = typeData[topId] ?? 0
        return Int((value / totalUses * 100).rounded())
    }

    /// Count of uses for the top type (for mini card display)
    var topTypeCount: Int {
        guard let topId = topTypeId else { return 0 }
        return Int((typeData[topId] ?? 0).rounded())
    }

    func getDisplayName(for aggId: String) -> String {
        config.displayNames[aggId] ?? aggId
    }

    func getColor(for aggId: String) -> Color {
        config.typeColors[aggId] ?? config.baseColor
    }

    /// Loads data from patient_quantity_samples with metadata filtering
    func loadDataForPeriod(period: TimePeriod, date: Date) async {
        isLoading = true
        typeData.removeAll()

        do {
            let userId = try await supabase.auth.session.user.id
            let (startDate, endDate) = PatientSamplesQueryService.shared.getDateRange(for: period, date: date)

            // Format dates for query
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            let startStr = formatter.string(from: startDate)
            let endStr = formatter.string(from: endDate)

            // Query patient_quantity_samples for this substance type
            let samples: [SubstanceSampleResult] = try await supabase
                .from("patient_quantity_samples")
                .select("id, aggregation_date, quantity_value, metadata")
                .eq("patient_id", value: userId)
                .eq("quantity_type", value: config.quantityType)
                .eq("is_primary", value: true)  // Only use primary samples for analysis
                .gte("aggregation_date", value: startStr)
                .lte("aggregation_date", value: endStr)
                .execute()
                .value

            // Group by metadata type value
            var typeSums: [String: Double] = [:]
            var dailyByType: [String: [Date: Double]] = [:]

            for sample in samples {
                guard let value = sample.quantityValue,
                      let aggDate = sample.aggregationDate else { continue }

                // Extract type from metadata
                let typeValue = sample.metadata?[config.metadataKey]?.stringValue ?? "other"

                if period == .day {
                    typeSums[typeValue, default: 0] += value
                } else {
                    dailyByType[typeValue, default: [:]][aggDate, default: 0] += value
                }
            }

            if period == .day {
                typeData = typeSums
            } else {
                // Calculate average of daily totals
                for (typeValue, dailyValues) in dailyByType {
                    guard !dailyValues.isEmpty else { continue }
                    let total = dailyValues.values.reduce(0, +)
                    typeData[typeValue] = total / Double(dailyValues.count)
                }
            }

        } catch {
            print("❌ Error loading substance type data: \(error)")
        }

        isLoading = false
    }
}

// Model for patient_quantity_samples query
private struct SubstanceSampleResult: Codable {
    let id: UUID
    let aggregationDateString: String?
    let quantityValue: Double?
    let metadata: [String: AnyJSON]?

    enum CodingKeys: String, CodingKey {
        case id
        case aggregationDateString = "aggregation_date"
        case quantityValue = "quantity_value"
        case metadata
    }

    /// Parse aggregation_date as a local date (noon to avoid DST issues)
    /// The database DATE represents a calendar day, not a UTC timestamp
    var aggregationDate: Date? {
        guard let dateString = aggregationDateString else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone.current  // Parse as local time, not UTC
        return formatter.date(from: dateString + " 12:00")  // Noon local to avoid DST edge cases
    }
}


#Preview {
    NavigationStack {
        SubstanceTypeView(config: .tobacco)
    }
}
