//
//  CannabisTypeCard.swift
//  WellPath
//
//  Card view for Cannabis Type breakdown - shows top type with percentage
//

import SwiftUI

struct CannabisTypeCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Cannabis Type",
            color: color,
            metricId: "DISP_CANNABIS_TYPE",
            pillar: pillar
        ) {
            CannabisTypeMiniCard(color: color)
        } fullScreen: {
            CannabisTypeView(color: color)
        }
    }
}

// MARK: - Mini Card (Data-Driven)

struct CannabisTypeMiniCard: View {
    let color: Color
    @StateObject private var viewModel = CannabisTypeViewModel()

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
                        Text("\(viewModel.topTypeCount) uses")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                HStack {
                    Text("No cannabis data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 50)
            }
        }
        .task {
            await viewModel.loadData(period: .week, date: Date())
        }
    }
}

#Preview {
    CannabisTypeCard(color: .green, pillar: "Lifestyle")
        .padding()
}
