//
//  AlcoholTypeView.swift
//  WellPath
//
//  Shows alcohol consumption breakdown by type (beer, wine, spirits, etc.)
//  Dynamically discovers types from database like NutrientTypeView.
//

import SwiftUI
import Charts

struct AlcoholTypeView: View {
    let color: Color

    @State private var selectedPeriod: TimePeriod = .week
    @State private var currentDate: Date = Date()
    @State private var selectedType: String?
    @StateObject private var viewModel: AlcoholTypeViewModel

    private let screenIcon = "chart.pie"

    init(color: Color) {
        self.color = color
        _viewModel = StateObject(wrappedValue: AlcoholTypeViewModel(baseColor: color))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading && viewModel.typeAggregations.isEmpty {
                    ProgressView()
                        .padding()
                } else {
                    // Period selector (D, W, M, Y)
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach([TimePeriod.day, .week, .month, .year], id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .onChange(of: selectedPeriod) { _, newPeriod in
                        Task {
                            await viewModel.loadDataForPeriod(period: newPeriod, date: currentDate)
                        }
                    }

                    // Period navigation
                    PeriodNavigationView(
                        selectedPeriod: selectedPeriod,
                        currentDate: $currentDate
                    )
                    .onChange(of: currentDate) { _, newDate in
                        Task {
                            await viewModel.loadDataForPeriod(period: selectedPeriod, date: newDate)
                        }
                    }

                    // Type Distribution card with donut chart
                    VStack(spacing: 0) {
                        // Card header
                        HStack(alignment: .top, spacing: 12) {
                            Text("Type Distribution")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Spacer()

                            // Total or Daily Avg
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(selectedPeriod == .day ? "Total" : "Daily Avg")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(formatTotalDrinks())
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                        // Donut chart
                        if viewModel.hasData {
                            Chart {
                                ForEach(viewModel.getTypesWithData()) { type in
                                    let drinks = viewModel.typeData[type.aggId] ?? 0
                                    let isSelected = selectedType == nil || selectedType == type.aggId

                                    SectorMark(
                                        angle: .value("Drinks", drinks),
                                        innerRadius: .ratio(0.618),
                                        angularInset: 1.5
                                    )
                                    .cornerRadius(4)
                                    .foregroundStyle(type.color.opacity(isSelected ? 1.0 : 0.3))
                                }
                            }
                            .frame(height: 140)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        } else {
                            // Empty state
                            VStack(spacing: 8) {
                                Image(systemName: "chart.pie")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary.opacity(0.5))

                                Text("No drinks logged")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(height: 140)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    )
                    .padding(.horizontal)

                    // Type list
                    if viewModel.hasData {
                        VStack(spacing: 8) {
                            ForEach(viewModel.getTypesWithData()) { type in
                                AlcoholTypeRow(
                                    type: type,
                                    drinks: viewModel.typeData[type.aggId] ?? 0,
                                    totalDrinks: viewModel.totalDrinks,
                                    isSelected: selectedType == type.aggId,
                                    onTap: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if selectedType == type.aggId {
                                                selectedType = nil
                                            } else {
                                                selectedType = type.aggId
                                            }
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        // No data placeholder
                        VStack(spacing: 12) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary.opacity(0.5))

                            Text("No type breakdown available")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 16)
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .metricScreenBackground(color: color)
        .task {
            await viewModel.discoverTypeAggregations()
            await viewModel.loadDataForPeriod(period: selectedPeriod, date: currentDate)
        }
    }

    private func formatTotalDrinks() -> String {
        let total = viewModel.totalDrinks
        if total == 0 {
            return "—"
        } else if total >= 10 {
            return String(format: "%.0f drinks", total)
        } else {
            return String(format: "%.1f drinks", total)
        }
    }
}

// MARK: - Alcohol Type Row

struct AlcoholTypeRow: View {
    let type: AlcoholTypeAggregation
    let drinks: Double
    let totalDrinks: Double
    let isSelected: Bool
    let onTap: () -> Void

    private var percentage: Double {
        guard totalDrinks > 0 else { return 0 }
        return (drinks / totalDrinks) * 100
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Color indicator
                Circle()
                    .fill(type.color)
                    .frame(width: 12, height: 12)

                // Type name and drinks
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text("Drinks: \(formatDrinks(drinks))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Percentage
                Text("\(Int(percentage.rounded()))%")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? type.color.opacity(0.15) : Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? type.color : Color.clear, lineWidth: 2)
        )
    }

    private func formatDrinks(_ value: Double) -> String {
        if value == 0 {
            return "0"
        } else if value >= 10 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}

// MARK: - Type Aggregation Model

struct AlcoholTypeAggregation: Identifiable {
    let aggId: String
    let displayName: String
    var color: Color

    var id: String { aggId }
}

// MARK: - ViewModel

@MainActor
class AlcoholTypeViewModel: ObservableObject {
    @Published var typeAggregations: [AlcoholTypeAggregation] = []
    @Published var typeData: [String: Double] = [:]  // agg_id -> drinks
    @Published var isLoading = false

    let supabase = SupabaseManager.shared.client
    private let baseColor: Color

    init(baseColor: Color) {
        self.baseColor = baseColor
    }

    var totalDrinks: Double {
        typeData.values.reduce(0, +)
    }

    var hasData: Bool {
        totalDrinks > 0
    }

    // MARK: - Mini Card Computed Properties

    /// The top consumed alcohol type (for mini card display)
    var topType: AlcoholTypeAggregation? {
        getTypesWithData().first
    }

    /// Percentage of the top type (for mini card display)
    var topTypePercentage: Int {
        guard let top = topType, totalDrinks > 0 else { return 0 }
        let drinks = typeData[top.aggId] ?? 0
        return Int((drinks / totalDrinks * 100).rounded())
    }

    /// Count of drinks for the top type (for mini card display)
    var topTypeDrinks: Int {
        guard let top = topType else { return 0 }
        return Int((typeData[top.aggId] ?? 0).rounded())
    }

    /// Discovers type aggregations from the database
    /// Queries sample_category_types_reference for alcohol type options
    func discoverTypeAggregations() async {
        do {
            struct TypeReference: Codable {
                let referenceKey: String
                let displayName: String
                let displayOrder: Int?

                enum CodingKeys: String, CodingKey {
                    case referenceKey = "reference_key"
                    case displayName = "display_name"
                    case displayOrder = "display_order"
                }
            }

            // Query sample_category_types_reference for alcohol type options
            let results: [TypeReference] = try await supabase
                .from("sample_category_types_reference")
                .select("reference_key, display_name, display_order")
                .eq("reference_category", value: "alcohol_types")
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            print("🍷 Discovered \(results.count) alcohol type options from sample_category_types_reference")

            // Sort by display order, but put "Other" last
            let sortedResults = results.sorted { a, b in
                let aIsOther = a.referenceKey.lowercased() == "other"
                let bIsOther = b.referenceKey.lowercased() == "other"

                if aIsOther && !bIsOther { return false }
                if !aIsOther && bIsOther { return true }
                return (a.displayOrder ?? 99) < (b.displayOrder ?? 99)
            }

            // Assign gradient colors based on position
            let colorCount = Double(sortedResults.count)
            typeAggregations = sortedResults.enumerated().map { index, ref in
                let isOther = ref.referenceKey.lowercased() == "other"

                let color: Color
                if isOther {
                    color = Color(red: 0.56, green: 0.56, blue: 0.58) // System gray
                } else {
                    // Gradient from dark to light based on position
                    let progress = colorCount > 1 ? Double(index) / (colorCount - 1) : 0
                    let opacity = 1.0 - (progress * 0.5) // Range from 1.0 to 0.5
                    color = baseColor.opacity(opacity)
                }

                // Construct aggId for compatibility with existing display logic
                let aggId = "AGG_ALCOHOL_TYPE_\(ref.referenceKey.uppercased())"

                return AlcoholTypeAggregation(
                    aggId: aggId,
                    displayName: ref.displayName,
                    color: color
                )
            }

        } catch {
            print("❌ Error discovering alcohol type aggregations: \(error)")
        }
    }

    /// Loads data for a specific period and date
    /// Uses AggregationQueryService which queries hourly (for D) or daily (for W/M/6M/Y)
    func loadDataForPeriod(period: TimePeriod, date: Date) async {
        isLoading = true
        typeData.removeAll()

        do {
            let aggIds = typeAggregations.map { $0.aggId }
            guard !aggIds.isEmpty else {
                isLoading = false
                return
            }

            print("🍷 Querying alcohol types for period: \(period.rawValue)")
            print("🍷   Date: \(date)")

            // Fetch raw values for each aggId using PatientSamplesQueryService
            for aggId in aggIds {
                let value = try await PatientSamplesQueryService.shared.fetchQuantityValue(
                    quantityType: aggId,
                    period: period,
                    date: date
                ) ?? 0.0
                typeData[aggId] = value
            }
        } catch {
            print("❌ Error loading alcohol type data: \(error)")
        }

        isLoading = false
    }

    // MARK: - Helper Methods

    func getDisplayName(for aggId: String) -> String {
        typeAggregations.first { $0.aggId == aggId }?.displayName ?? aggId
    }

    func getColor(for aggId: String) -> Color {
        typeAggregations.first { $0.aggId == aggId }?.color ?? .gray
    }

    /// Get types sorted by consumption amount (highest first)
    func getSortedTypesByConsumption() -> [AlcoholTypeAggregation] {
        typeAggregations.sorted {
            let value1 = typeData[$0.aggId] ?? 0
            let value2 = typeData[$1.aggId] ?? 0

            // "Other" always goes last
            if $0.aggId.contains("OTHER") && !$1.aggId.contains("OTHER") { return false }
            if !$0.aggId.contains("OTHER") && $1.aggId.contains("OTHER") { return true }

            return value1 > value2
        }
    }

    /// Get types with data only, sorted by consumption
    func getTypesWithData() -> [AlcoholTypeAggregation] {
        getSortedTypesByConsumption().filter { (typeData[$0.aggId] ?? 0) > 0 }
    }

    // MARK: - Period Calculation Helpers

    private func getPeriodStart(for period: TimePeriod, date: Date) -> Date {
        let calendar = Calendar.current
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        switch period {
        case .day:
            let localComponents = calendar.dateComponents([.year, .month, .day], from: date)
            var utcComponents = DateComponents()
            utcComponents.year = localComponents.year
            utcComponents.month = localComponents.month
            utcComponents.day = localComponents.day
            utcComponents.hour = 0
            utcComponents.minute = 0
            utcComponents.second = 0
            utcComponents.timeZone = TimeZone(identifier: "UTC")
            return utcCalendar.date(from: utcComponents)!

        case .week:
            let localComponents = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
            let weekday = localComponents.weekday!
            let daysFromMonday = (weekday == 1) ? -6 : (2 - weekday)
            let localMonday = calendar.date(byAdding: .day, value: daysFromMonday, to: date)!
            let mondayComponents = calendar.dateComponents([.year, .month, .day], from: localMonday)

            var utcComponents = DateComponents()
            utcComponents.year = mondayComponents.year
            utcComponents.month = mondayComponents.month
            utcComponents.day = mondayComponents.day
            utcComponents.hour = 0
            utcComponents.minute = 0
            utcComponents.second = 0
            utcComponents.timeZone = TimeZone(identifier: "UTC")
            return utcCalendar.date(from: utcComponents)!

        case .month:
            let localComponents = calendar.dateComponents([.year, .month], from: date)
            var utcComponents = DateComponents()
            utcComponents.year = localComponents.year
            utcComponents.month = localComponents.month
            utcComponents.day = 1
            utcComponents.hour = 0
            utcComponents.minute = 0
            utcComponents.second = 0
            utcComponents.timeZone = TimeZone(identifier: "UTC")
            return utcCalendar.date(from: utcComponents)!

        case .sixMonth:
            let localComponents = calendar.dateComponents([.year, .month], from: date)
            let year = localComponents.year!
            let month = localComponents.month!
            let startMonth = month <= 6 ? 1 : 7

            var utcComponents = DateComponents()
            utcComponents.year = year
            utcComponents.month = startMonth
            utcComponents.day = 1
            utcComponents.hour = 0
            utcComponents.minute = 0
            utcComponents.second = 0
            utcComponents.timeZone = TimeZone(identifier: "UTC")
            return utcCalendar.date(from: utcComponents)!

        case .year:
            let localComponents = calendar.dateComponents([.year], from: date)
            var utcComponents = DateComponents()
            utcComponents.year = localComponents.year
            utcComponents.month = 1
            utcComponents.day = 1
            utcComponents.hour = 0
            utcComponents.minute = 0
            utcComponents.second = 0
            utcComponents.timeZone = TimeZone(identifier: "UTC")
            return utcCalendar.date(from: utcComponents)!
        }
    }
}

#Preview {
    NavigationStack {
        AlcoholTypeView(color: .orange)
    }
}
