//
//  NicotineTypeCard.swift
//  WellPath
//
//  Card view for Nicotine Type breakdown - shows top type with percentage
//

import SwiftUI

struct NicotineTypeCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Nicotine Types",
            color: color,
            metricId: "DISP_NICOTINE_TYPE",
            pillar: pillar
        ) {
            NicotineTypeMiniCard(color: color)
        } fullScreen: {
            NicotineTypeView(color: color)
        }
    }
}

// MARK: - Mini Card (Data-Driven)

struct NicotineTypeMiniCard: View {
    let color: Color
    @StateObject private var viewModel: SubstanceTypeViewModel

    init(color: Color) {
        self.color = color
        _viewModel = StateObject(wrappedValue: SubstanceTypeViewModel(config: .nicotine))
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
                    Text("No nicotine data")
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
    NicotineTypeCard(color: .indigo, pillar: "Lifestyle")
        .padding()
}
