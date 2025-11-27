//
//  NutrientTimingTimelineView.swift
//  WellPath
//
//  Generic timeline view for meal timing across all nutrients
//  Shows summary above timeline, with meal cards and connecting dots
//

import SwiftUI

struct NutrientTimingTimelineView: View {
    let nutrientType: NutrientTimingType
    let color: Color
    @Binding var showAbout: Bool

    @State private var selectedPeriod: TimePeriod = .week
    @State private var currentDate: Date = Date()
    @StateObject private var viewModel: NutrientTimingViewModel

    init(nutrientType: NutrientTimingType, color: Color, showAbout: Binding<Bool>) {
        self.nutrientType = nutrientType
        self.color = color
        self._showAbout = showAbout
        _viewModel = StateObject(wrappedValue: NutrientTimingViewModel(nutrientType: nutrientType, baseColor: color))
    }

    private var mealDataForPeriod: [(name: String, value: Double, percentage: Double, color: Color)] {
        var result: [(name: String, value: Double, percentage: Double, color: Color)] = []
        let totalValue = viewModel.periodData.filter { !$0.key.starts(with: "avg_") && !$0.key.starts(with: "entries_") }.values.reduce(0, +)

        for meal in viewModel.mealAggregations {
            let value = viewModel.periodData[meal.aggId] ?? 0

            // Only include meals with data
            if value > 0 {
                let percentage = totalValue > 0 ? (value / totalValue) * 100 : 0
                result.append((name: meal.displayName, value: value, percentage: percentage, color: meal.color))
            }
        }

        return result
    }

    private var hasData: Bool {
        !mealDataForPeriod.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else {
                    // Period selector (exclude 6M for timing view)
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach([TimePeriod.day, .week, .month, .year], id: \.self) { period in
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

                    // Period navigation (centered)
                    PeriodNavigationView(
                        selectedPeriod: selectedPeriod,
                        currentDate: $currentDate
                    )
                    .onChange(of: currentDate) { oldValue, newDate in
                        Task {
                            await viewModel.loadDataForPeriod(period: selectedPeriod, date: newDate)
                        }
                    }

                    // Info button (below picker, right-aligned)
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation {
                                showAbout = true
                            }
                        }) {
                            Image(systemName: "info.circle")
                                .font(.title3)
                                .foregroundColor(color)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                    // Summary ALWAYS shown (with NO DATA state if empty)
                    NutrientTimingStatsView(
                        color: color,
                        mealData: mealDataForPeriod.map { (name: $0.name, value: $0.value, percentage: $0.percentage) },
                        avgPerMeal: viewModel.periodData["avg_per_meal"] ?? 0,
                        entriesCount: Int(viewModel.periodData["entries_count"] ?? 0),
                        unitLabel: nutrientType.unitLabel,
                        hasData: hasData
                    )

                    // Timeline title
                    HStack {
                        Text("Daily Distribution")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Meal timing cards with timeline overlay (or no data message)
                    if hasData {
                        VStack(spacing: 8) {
                            ForEach(Array(mealDataForPeriod.enumerated()), id: \.element.name) { index, meal in
                                NutrientMealCard(
                                    mealName: meal.name,
                                    value: meal.value,
                                    percentage: meal.percentage,
                                    color: meal.color,
                                    unitLabel: nutrientType.unitLabel
                                )
                                .overlay(alignment: .leading) {
                                    GeometryReader { geometry in
                                        ZStack {
                                            // Vertical connecting lines
                                            if mealDataForPeriod.count > 1 {
                                                VStack(spacing: 0) {
                                                    // Line above dot
                                                    Rectangle()
                                                        .fill(Color.secondary.opacity(0.3))
                                                        .frame(width: 2, height: geometry.size.height / 2)
                                                        .opacity(index == 0 ? 0 : 1)

                                                    // Line below dot
                                                    Rectangle()
                                                        .fill(Color.secondary.opacity(0.3))
                                                        .frame(width: 2, height: geometry.size.height / 2)
                                                        .opacity(index == mealDataForPeriod.count - 1 ? 0 : 1)
                                                }
                                            }

                                            // Dot centered vertically on card
                                            Circle()
                                                .fill(meal.color)
                                                .frame(width: 12, height: 12)
                                        }
                                        .frame(width: 12)
                                        .offset(x: -16)
                                    }
                                }
                            }
                        }
                        .padding(.leading, 28)
                        .padding(.trailing, 16)
                    } else {
                        // No data placeholder
                        VStack(spacing: 12) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary.opacity(0.5))

                            Text("No meal data for this period")
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
        }
        // Background provided by parent via metricScreenBackground modifier
        .task {
            await viewModel.discoverMealAggregations()
            await viewModel.loadDataForPeriod(period: selectedPeriod, date: currentDate)
        }
    }
}

// MARK: - Nutrient-aware Meal Card

struct NutrientMealCard: View {
    let mealName: String
    let value: Double
    let percentage: Double
    let color: Color
    let unitLabel: String

    var body: some View {
        HStack(spacing: 12) {
            // Meal name
            Text(mealName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                        .frame(height: 8)

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * min(percentage / 100.0, 1.0), height: 8)
                }
            }
            .frame(height: 8)
            .frame(maxWidth: .infinity)

            // Values
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatValue(value))
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("\(Int(percentage.rounded()))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func formatValue(_ value: Double) -> String {
        if value == 0 {
            return "0\(unitLabel)"
        } else if value >= 100 {
            return String(format: "%.0f\(unitLabel)", value)
        } else if value >= 10 {
            return String(format: "%.1f\(unitLabel)", value)
        } else {
            return String(format: "%.2f\(unitLabel)", value)
        }
    }
}

// MARK: - Nutrient-aware Stats View

struct NutrientTimingStatsView: View {
    let color: Color
    let mealData: [(name: String, value: Double, percentage: Double)]
    let avgPerMeal: Double
    let entriesCount: Int
    let unitLabel: String
    let hasData: Bool

    private var topMeal: String? {
        mealData.max(by: { $0.value < $1.value })?.name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 18))
                    .foregroundColor(color)
                Text("Summary")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }

            // Stats row - fixed width columns
            HStack(spacing: 0) {
                // Average per meal (left column)
                VStack(alignment: .center, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(hasData ? formatValueNumber(avgPerMeal) : "–")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(hasData ? .primary : .secondary)
                        Text(unitLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("avg per meal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 50)

                // Entries (center column)
                VStack(alignment: .center, spacing: 4) {
                    Text(hasData ? "\(entriesCount)" : "–")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(hasData ? .primary : .secondary)
                    Text("entries")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 50)

                // Top meal (right column - allow 2 lines)
                VStack(alignment: .center, spacing: 4) {
                    Text(topMeal ?? "–")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(hasData ? .primary : .secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("top meal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func formatValue(_ value: Double) -> String {
        if value == 0 {
            return "0\(unitLabel)"
        } else if value >= 100 {
            return String(format: "%.0f\(unitLabel)", value)
        } else {
            return String(format: "%.1f\(unitLabel)", value)
        }
    }

    private func formatValueNumber(_ value: Double) -> String {
        if value == 0 {
            return "0"
        } else if value >= 100 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var showAbout = false

        var body: some View {
            NutrientTimingTimelineView(
                nutrientType: .legumes,
                color: MetricsUIConfig.getPillarColor(for: "Healthful Nutrition"),
                showAbout: $showAbout
            )
        }
    }

    return PreviewWrapper()
}
