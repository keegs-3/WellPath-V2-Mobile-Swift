//
//  NutrientScreen.swift
//  WellPath
//
//  Generic card-based screen for nutrition metrics
//  Reusable for Legumes, Vegetables, Fruits, Whole Grains
//  Shows primary servings chart plus Timing and Type sub-cards
//

import SwiftUI

/// Configuration for a nutrient screen
@MainActor
struct NutrientScreenConfig {
    let title: String
    let metricId: String
    let nutrientType: NutrientTimingType
    let screenIcon: String
    let dataManagementConfigFactory: (Color) -> MetricDataConfig

    static let legumes = NutrientScreenConfig(
        title: "Legume",
        metricId: "DISP_LEGUMES_SERVINGS",
        nutrientType: .legumes,
        screenIcon: MetricsUIConfig.getIcon(for: "Legumes"),
        dataManagementConfigFactory: { MetricDataConfig.legumes(color: $0) }
    )

    static let vegetables = NutrientScreenConfig(
        title: "Vegetable",
        metricId: "DISP_VEGETABLES_SERVINGS",
        nutrientType: .vegetables,
        screenIcon: MetricsUIConfig.getIcon(for: "Vegetables"),
        dataManagementConfigFactory: { MetricDataConfig.vegetables(color: $0) }
    )

    static let fruits = NutrientScreenConfig(
        title: "Fruit",
        metricId: "DISP_FRUITS_SERVINGS",
        nutrientType: .fruits,
        screenIcon: MetricsUIConfig.getIcon(for: "Fruits"),
        dataManagementConfigFactory: { MetricDataConfig.fruits(color: $0) }
    )

    static let wholeGrains = NutrientScreenConfig(
        title: "Whole Grain",
        metricId: "DISP_WHOLE_GRAINS_SERVINGS",
        nutrientType: .wholeGrains,
        screenIcon: MetricsUIConfig.getIcon(for: "Whole Grains"),
        dataManagementConfigFactory: { MetricDataConfig.wholeGrains(color: $0) }
    )
}

struct NutrientScreen: View {
    let config: NutrientScreenConfig
    let pillar: String
    let color: Color

    @StateObject private var viewModel: StandardMetricViewModel
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    init(config: NutrientScreenConfig, pillar: String, color: Color) {
        self.config = config
        self.pillar = pillar
        self.color = color
        _viewModel = StateObject(wrappedValue: StandardMetricViewModel(metricId: config.metricId))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Reusable card components (defined in Cards/NutrientCards.swift)
                NutrientServingsCard(config: config, color: color, pillar: pillar)
                NutrientTimingCard(config: config, color: color, pillar: pillar)
                NutrientTypeCard(config: config, color: color, pillar: pillar)
            }
            .padding()
            .padding(.bottom, 24)
        }
        .metricScreenBackground(color: color)
        .navigationTitle(config.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingDataManagement = true
                } label: {
                    Image(systemName: "list.bullet")
                }
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                FavoriteButton(
                    itemType: .screen,
                    itemId: config.metricId,
                    displayName: config.title,
                    pillar: pillar,
                    cardId: nil,
                    sectionId: "NAV_NUTRITION"
                )

                Button {
                    showingEntryForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEntryForm) {
            entryView
        }
        .sheet(isPresented: $showingDataManagement) {
            MetricDataManagementView(config: config.dataManagementConfigFactory(color))
        }
        .task {
            await viewModel.loadPrimaryScreen()
        }
    }

    @ViewBuilder
    private var entryView: some View {
        switch config.nutrientType {
        case .legumes:
            LegumesEntryView()
        case .vegetables:
            VegetablesEntryView()
        case .fruits:
            FruitsEntryView()
        case .wholeGrains:
            WholeGrainsEntryView()
        default:
            EmptyView()
        }
    }
}

// MARK: - Nutrient Servings Mini Card

struct NutrientServingsMiniCard: View {
    @ObservedObject var viewModel: StandardMetricViewModel
    let color: Color

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
                            Text(viewModel.todayValue.map { String(format: "%.1f", $0) } ?? "--")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Text(viewModel.displayUnit)
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
                            Text(viewModel.weeklyAverageValue.map { String(format: "%.1f", $0) } ?? "--")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(color)
                            Text(viewModel.displayUnit)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                HStack {
                    Text("No data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 60)
            }
        }
    }
}

// MARK: - Nutrient Servings Full View

struct NutrientServingsFullView: View {
    @ObservedObject var viewModel: StandardMetricViewModel
    let color: Color
    let screenIcon: String
    @State private var showAbout = false

    var body: some View {
        ScrollView {
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
        }
        .metricScreenBackground(color: color)
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
        .frame(minHeight: 300)
    }
}

// MARK: - Generic Mini Card Components

/// Generic mini preview for Nutrient Timing
struct NutrientTimingMiniCardGeneric: View {
    let nutrientType: NutrientTimingType
    let color: Color
    @StateObject private var viewModel: NutrientTimingViewModel

    init(nutrientType: NutrientTimingType, color: Color) {
        self.nutrientType = nutrientType
        self.color = color
        _viewModel = StateObject(wrappedValue: NutrientTimingViewModel(nutrientType: nutrientType, baseColor: color))
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Top Meal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(top.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    Spacer()

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

/// Generic mini preview for Nutrient Type
struct NutrientTypeMiniCardGeneric: View {
    let nutrientType: NutrientTimingType
    let color: Color
    @StateObject private var viewModel: NutrientTypeViewModel

    init(nutrientType: NutrientTimingType, color: Color) {
        self.nutrientType = nutrientType
        self.color = color
        _viewModel = StateObject(wrappedValue: NutrientTypeViewModel(nutrientType: nutrientType, baseColor: color))
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
            } else if viewModel.totalServings > 0 {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Variety Score")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(viewModel.calculateVarietyScore().rounded()))")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(varietyColor)
                            Text("/ 100")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(viewModel.typeAggregations.filter { (viewModel.typeData[$0.aggId] ?? 0) > 0 }.count) types")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Text("this week")
                            .font(.caption2)
                            .foregroundColor(.secondary)
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
            await viewModel.discoverTypeAggregations()
            await viewModel.loadDataForPeriod(period: .week, date: Date())
        }
    }

    private var varietyColor: Color {
        let score = viewModel.calculateVarietyScore()
        if score >= 85 { return MetricsUIConfig.tierGood }
        else if score >= 70 { return MetricsUIConfig.tierMedium }
        else { return MetricsUIConfig.tierPoor }
    }
}

// MARK: - Concrete Screen Views
// Note: Screen views moved to their respective metric folders:
// - Legumes/LegumesScreen.swift
// - Vegetables/VegetablesScreen.swift
// - Fruits/FruitsScreen.swift
// - WholeGrains/WholeGrainsScreen.swift

#Preview("NutrientScreen - Legumes") {
    NavigationStack {
        NutrientScreen(config: .legumes, pillar: "Healthful Nutrition", color: .brown)
    }
}
