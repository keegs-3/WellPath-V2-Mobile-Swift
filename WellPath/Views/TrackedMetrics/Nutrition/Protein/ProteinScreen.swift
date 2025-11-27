//
//  ProteinScreen.swift
//  WellPath
//
//  Card-based layout for Protein metric
//  All metrics shown as tappable mini cards that expand to full view
//

import SwiftUI

struct ProteinScreen: View {
    let pillar: String
    let color: Color

    @StateObject private var viewModel = ProteinPrimaryViewModel(metricId: "DISP_PROTEIN_GRAMS")
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Protein Intake")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Protein Amount card
                MetricCardView(
                    title: viewModel.amountTitle,
                    color: color
                ) {
                    ProteinAmountMiniCard(color: color, viewModel: viewModel)
                } fullScreen: {
                    ProteinAmountFullView(color: color, viewModel: viewModel)
                }

                // Timing card
                MetricCardView(
                    title: viewModel.timingTitle,
                    color: color
                ) {
                    ProteinTimingMiniCard(color: color)
                } fullScreen: {
                    ProteinTimingView(color: color)
                }

                // Type card
                MetricCardView(
                    title: viewModel.typeTitle,
                    color: color
                ) {
                    ProteinTypeMiniCard(color: color)
                } fullScreen: {
                    ProteinTiersView(color: color)
                }

                // Ratio card
                MetricCardView(
                    title: viewModel.ratioTitle,
                    color: color
                ) {
                    ProteinRatioMiniCard(color: color)
                } fullScreen: {
                    ProteinPerBodyWeightView(color: color)
                }
            }
            .padding()
            .padding(.bottom, 24)
        }
        .background(
            ZStack {
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [color.opacity(0.65), color.opacity(0.45), color.opacity(0.25), color.opacity(0.1), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 900)
                    Spacer()
                }

                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: screenIcon)
                            .font(.system(size: 200))
                            .foregroundStyle(Color.white.opacity(0.2))
                            .rotationEffect(.degrees(-15))
                            .offset(x: 50, y: -50)
                    }
                    Spacer()
                }
            }
            .ignoresSafeArea()
        )
        .navigationTitle("Protein")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingDataManagement = true
                } label: {
                    Image(systemName: "list.bullet")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingEntryForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEntryForm) {
            ProteinEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            ProteinDataManagementView(color: color)
        }
        .task {
            await viewModel.loadPrimaryScreen()
        }
    }
}

// MARK: - Protein Amount Mini Card

/// Mini preview for Protein Amount - shows today's total and weekly average
struct ProteinAmountMiniCard: View {
    let color: Color
    @ObservedObject var viewModel: ProteinPrimaryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(height: 60)
            } else if viewModel.metrics.first != nil {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(formatValue(viewModel.todayValue))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Text("g")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Weekly Avg")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(formatValue(viewModel.weeklyAverage))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(color)
                            Text("g")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                HStack {
                    Text("No protein data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 60)
            }
        }
    }

    private func formatValue(_ value: Double?) -> String {
        guard let value = value else { return "--" }
        if value >= 100 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}

// MARK: - Protein Amount Full View

struct ProteinAmountFullView: View {
    let color: Color
    @ObservedObject var viewModel: ProteinPrimaryViewModel
    @State private var showAbout = false

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Protein Intake")
    }

    var body: some View {
        VStack(spacing: 0) {
            if showAbout {
                aboutContentView
            } else {
                if let metric = viewModel.metrics.first {
                    ParentMetricBarChart(metric: metric.metric, color: color, showAbout: $showAbout)
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(height: 300)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("No data available")
                        .foregroundColor(.secondary)
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .background(
            ZStack {
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [color.opacity(0.65), color.opacity(0.45), color.opacity(0.25), color.opacity(0.1), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 900)
                    Spacer()
                }

                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: screenIcon)
                            .font(.system(size: 200))
                            .foregroundStyle(Color.white.opacity(0.2))
                            .rotationEffect(.degrees(-15))
                            .offset(x: 50, y: -50)
                    }
                    Spacer()
                }
            }
            .ignoresSafeArea()
        )
    }

    private var aboutContentView: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 24) {
                    if let about = viewModel.aboutContent {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(color)
                                Text("About")
                                    .font(.headline)
                            }
                            Text(about)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let impact = viewModel.longevityImpact {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: "heart.circle.fill")
                                    .foregroundColor(color)
                                Text("Health Impact")
                                    .font(.headline)
                            }
                            Text(impact)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let tips = viewModel.quickTips, !tips.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "lightbulb.circle.fill")
                                    .foregroundColor(color)
                                Text("Quick Tips")
                                    .font(.headline)
                            }

                            ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1).")
                                        .fontWeight(.semibold)
                                        .foregroundColor(color)
                                    Text(tip)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding()
                .padding(.top, 40)
            }

            Button(action: {
                withAnimation {
                    showAbout = false
                }
            }) {
                Image(systemName: "chart.bar")
                    .font(.title3)
                    .foregroundColor(color)
            }
            .padding(.top, 8)
            .padding(.trailing, 16)
        }
    }
}

// MARK: - Mini Card Components

/// Mini preview for Protein Timing - shows top meal summary
struct ProteinTimingMiniCard: View {
    let color: Color
    @StateObject private var viewModel: NutrientTimingViewModel

    init(color: Color) {
        self.color = color
        _viewModel = StateObject(wrappedValue: NutrientTimingViewModel(nutrientType: .protein, baseColor: color))
    }

    private var topMeal: (name: String, percentage: Double)? {
        var totalValue: Double = 0
        var topMealInfo: (name: String, value: Double)?

        for meal in viewModel.mealAggregations {
            let value = viewModel.periodData[meal.aggId] ?? 0
            if value > 0 {
                totalValue += value
                if topMealInfo == nil || value > topMealInfo!.value {
                    topMealInfo = (meal.displayName, value)
                }
            }
        }

        guard let top = topMealInfo, totalValue > 0 else { return nil }
        return (top.name, (top.value / totalValue) * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(height: 60)
            } else if let top = topMeal {
                HStack(spacing: 16) {
                    // Top meal indicator
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Top Meal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(top.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    // Percentage
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(top.percentage.rounded()))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(color)
                        Text("of daily intake")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                HStack {
                    Text("No timing data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 60)
            }
        }
        .task {
            await viewModel.discoverMealAggregations()
            await viewModel.loadDataForPeriod(period: .week, date: Date())
        }
    }
}

/// Mini preview for Protein Type - shows tier distribution
struct ProteinTypeMiniCard: View {
    let color: Color
    @StateObject private var viewModel: ProteinTypeDonutViewModel

    init(color: Color) {
        self.color = color
        _viewModel = StateObject(wrappedValue: ProteinTypeDonutViewModel(baseColor: color))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(height: 60)
            } else if viewModel.totalProtein > 0 {
                HStack(spacing: 16) {
                    // Quality score
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quality Score")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(viewModel.calculateTypeScore().rounded()))")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(scoreColor)
                            Text("/ 100")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Mini tier bars
                    VStack(alignment: .trailing, spacing: 4) {
                        tierIndicator(label: "T1", percentage: tier1Percentage, color: MetricsUIConfig.tierGood)
                        tierIndicator(label: "T2", percentage: tier2Percentage, color: MetricsUIConfig.tierMedium)
                        tierIndicator(label: "T3", percentage: tier3Percentage, color: MetricsUIConfig.tierPoor)
                    }
                }
            } else {
                HStack {
                    Text("No type data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 60)
            }
        }
        .task {
            await viewModel.loadTierConfig()
            await viewModel.loadDataForPeriod(period: .week, date: Date())
        }
    }

    private var scoreColor: Color {
        let score = viewModel.calculateTypeScore()
        if score >= 85 { return MetricsUIConfig.tierGood }
        else if score >= 70 { return MetricsUIConfig.tierMedium }
        else { return MetricsUIConfig.tierPoor }
    }

    private var tier1Percentage: Double {
        tierPercentage(for: "PROTEIN_TIER_1")
    }

    private var tier2Percentage: Double {
        tierPercentage(for: "PROTEIN_TIER_2")
    }

    private var tier3Percentage: Double {
        tierPercentage(for: "PROTEIN_TIER_3")
    }

    private func tierPercentage(for tierId: String) -> Double {
        guard let tierConfig = viewModel.tierConfig,
              let tier = tierConfig.tiers.first(where: { $0.tierId == tierId }),
              viewModel.totalProtein > 0 else { return 0 }

        let tierGrams = tier.proteinTypes.reduce(0.0) { sum, typeId in
            sum + (viewModel.typeData[typeId] ?? 0)
        }
        return (tierGrams / viewModel.totalProtein) * 100
    }

    @ViewBuilder
    private func tierIndicator(label: String, percentage: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .trailing)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                    .frame(width: 50, height: 6)

                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 50 * min(percentage / 100, 1.0), height: 6)
            }

            Text("\(Int(percentage.rounded()))%")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)
        }
    }
}

/// Mini preview for Protein Ratio - shows current g/kg value
struct ProteinRatioMiniCard: View {
    let color: Color
    @StateObject private var viewModel = ProteinPerBodyWeightViewModel()

    // Optimal range
    private let optimalRange: ClosedRange<Double> = 1.2...1.6

    private var currentRatio: Double {
        // Get latest non-zero value
        viewModel.chartData.filter { $0.perKg > 0 }.last?.perKg ?? 0
    }

    private var ratioStatus: (text: String, color: Color) {
        guard currentRatio > 0 else { return ("No data", .secondary) }

        if optimalRange.contains(currentRatio) {
            return ("Optimal", MetricsUIConfig.tierGood)
        } else if currentRatio < optimalRange.lowerBound {
            return ("Below target", MetricsUIConfig.tierMedium)
        } else {
            return ("Above target", MetricsUIConfig.tierMedium)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(height: 60)
            } else if currentRatio > 0 {
                HStack(spacing: 16) {
                    // Current ratio
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weekly Avg")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.2f", currentRatio))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(color)
                            Text("g/kg")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Status badge
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(ratioStatus.text)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ratioStatus.color)
                        Text("Target: \(String(format: "%.1f", optimalRange.lowerBound))-\(String(format: "%.1f", optimalRange.upperBound))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                HStack {
                    Text("No ratio data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 60)
            }
        }
        .task {
            await viewModel.loadData(for: .week)
        }
    }
}

#Preview {
    NavigationStack {
        ProteinScreen(pillar: "Healthful Nutrition", color: .green)
    }
}
