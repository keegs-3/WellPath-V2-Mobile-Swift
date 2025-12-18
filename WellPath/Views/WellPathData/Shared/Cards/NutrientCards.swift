//
//  NutrientCards.swift
//  WellPath
//
//  Reusable card components for nutrient metrics.
//  Used by NutrientScreen and Favorites.
//  Supports: Vegetables, Legumes, Fruits, Whole Grains
//

import SwiftUI

// MARK: - Servings Card

struct NutrientServingsCard: View {
    let config: NutrientScreenConfig
    let color: Color
    let pillar: String

    @StateObject private var viewModel: StandardMetricViewModel

    init(config: NutrientScreenConfig, color: Color, pillar: String) {
        self.config = config
        self.color = color
        self.pillar = pillar
        _viewModel = StateObject(wrappedValue: StandardMetricViewModel(metricId: config.metricId))
    }

    var body: some View {
        MetricCardView(
            title: "\(config.title) Servings",
            color: color,
            metricId: config.metricId,
            pillar: pillar
        ) {
            NutrientServingsMiniCard(viewModel: viewModel, color: color)
        } fullScreen: {
            // Route to proper view with toolbar components
            servingsView
        }
        .task {
            await viewModel.loadPrimaryScreen()
        }
    }

    @ViewBuilder
    private var servingsView: some View {
        switch config.nutrientType {
        case .legumes:
            LegumesServingsView(color: color)
        case .vegetables:
            VegetablesServingsView(color: color)
        case .fruits:
            FruitsServingsView(color: color)
        case .wholeGrains:
            WholeGrainsServingsView(color: color)
        default:
            NutrientServingsFullView(viewModel: viewModel, color: color, screenIcon: config.screenIcon)
        }
    }
}

// MARK: - Type Card

struct NutrientTypeCard: View {
    let config: NutrientScreenConfig
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "\(config.title) Type",
            color: color,
            metricId: config.metricId.replacingOccurrences(of: "SERVINGS", with: "TYPE"),
            pillar: pillar
        ) {
            NutrientTypeMiniCardGeneric(nutrientType: config.nutrientType, color: color)
        } fullScreen: {
            // Route to proper view with toolbar components
            typeView
        }
    }

    @ViewBuilder
    private var typeView: some View {
        switch config.nutrientType {
        case .legumes:
            LegumesTypeView(color: color)
        case .vegetables:
            VegetablesTypeView(color: color)
        case .fruits:
            FruitsTypeView(color: color)
        case .wholeGrains:
            WholeGrainsTypeView(color: color)
        default:
            NutrientTypeView(nutrientType: config.nutrientType, color: color, showAbout: .constant(false))
                .metricScreenBackground(color: color)
        }
    }
}

// Note: Individual nutrient cards (VegetablesServingsCard, LegumesTimingCard, etc.)
// are now in their respective category folders:
// - Vegetables/Cards/VegetablesServingsCard.swift, etc.
// - Legumes/Cards/LegumesServingsCard.swift, etc.
// - Fruits/Cards/FruitsServingsCard.swift, etc.
// - WholeGrains/Cards/WholeGrainsServingsCard.swift, etc.

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            NutrientServingsCard(config: .vegetables, color: .green, pillar: "Healthful Nutrition")
            NutrientTypeCard(config: .vegetables, color: .green, pillar: "Healthful Nutrition")
        }
        .padding()
    }
}
