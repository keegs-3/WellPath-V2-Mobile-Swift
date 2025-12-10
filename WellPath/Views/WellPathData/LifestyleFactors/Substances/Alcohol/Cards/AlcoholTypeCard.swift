//
//  AlcoholTypeCard.swift
//  WellPath
//
//  Card view for Alcohol Type breakdown - shows top drink type with percentage
//

import SwiftUI

struct AlcoholTypeCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Drink Type",
            color: color,
            metricId: "DISP_ALCOHOL_TYPE",
            pillar: pillar
        ) {
            AlcoholTypeMiniCard(color: color)
        } fullScreen: {
            AlcoholTypeView(color: color)
        }
    }
}

// MARK: - Mini Card (Data-Driven)

struct AlcoholTypeMiniCard: View {
    let color: Color
    @StateObject private var viewModel: AlcoholTypeViewModel

    init(color: Color) {
        self.color = color
        _viewModel = StateObject(wrappedValue: AlcoholTypeViewModel(baseColor: color))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(height: 50)
            } else if let topType = viewModel.topType {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Top Type")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(topType.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(viewModel.topTypePercentage)%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(color)
                        Text("\(viewModel.topTypeDrinks) drinks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                HStack {
                    Text("No drink data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 50)
            }
        }
        .task {
            await viewModel.discoverTypeAggregations()
            await viewModel.loadDataForPeriod(period: .week, date: Date())
        }
    }
}

#Preview {
    AlcoholTypeCard(color: .orange, pillar: "Lifestyle")
        .padding()
}
