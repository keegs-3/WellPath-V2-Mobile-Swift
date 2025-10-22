//
//  DashboardView.swift
//  WellPath
//
//  Created on 2025-10-22
//

import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // WellPath Score - TODO: Fetch from backend
                    WellPathScoreCard(score: 84)

                    // Pillar Chart Section - TODO: Build curved visualization
                    PillarChartCard()

                    // Tracked Metrics Navigation
                    NavigationLink(destination: TrackedMetricsListView()) {
                        TrackedMetricsButton()
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
        }
    }
}

struct TrackedMetricsButton: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tracked Metrics")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("View sleep, activity, nutrition & more")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct WellPathScoreCard: View {
    let score: Int

    var body: some View {
        VStack(spacing: 12) {
            Text("Your WellPath Score")
                .font(.headline)

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 20)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                Text("\(score)")
                    .font(.system(size: 48, weight: .bold))
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    DashboardView()
}
