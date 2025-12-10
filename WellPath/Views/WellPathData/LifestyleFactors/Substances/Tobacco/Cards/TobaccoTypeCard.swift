//
//  TobaccoTypeCard.swift
//  WellPath
//
//  Card view for Tobacco Type breakdown - shows top type with percentage
//

import SwiftUI

struct TobaccoTypeCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Tobacco Type",
            color: color,
            metricId: "DISP_TOBACCO_TYPE",
            pillar: pillar
        ) {
            TobaccoTypeMiniCard(color: color)
        } fullScreen: {
            TobaccoTypeView(color: color)
        }
    }
}

// MARK: - Mini Card (Data-Driven)

struct TobaccoTypeMiniCard: View {
    let color: Color
    @StateObject private var viewModel: SubstanceTypeViewModel

    init(color: Color) {
        self.color = color
        _viewModel = StateObject(wrappedValue: SubstanceTypeViewModel(config: .tobacco))
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
            } else if viewModel.topTypeId != nil {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Top Type")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(viewModel.topTypeDisplayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(viewModel.topTypePercentage)%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(color)
                        Text("\(viewModel.topTypeCount) uses")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                HStack {
                    Text("No tobacco data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 50)
            }
        }
        .task {
            await viewModel.loadDataForPeriod(period: .week, date: Date())
        }
    }
}

#Preview {
    TobaccoTypeCard(color: .brown, pillar: "Lifestyle")
        .padding()
}
