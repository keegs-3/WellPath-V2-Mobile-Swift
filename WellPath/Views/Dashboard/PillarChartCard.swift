//
//  PillarChartCard.swift
//  WellPath
//
//  Created on 2025-10-22
//

import SwiftUI

struct PillarChartCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("WellPath Score")
                .font(.headline)

            // TODO: Implement layered radial chart
            // For now, show placeholder
            ZStack {
                Circle()
                    .stroke(Color.purple.opacity(0.3), lineWidth: 20)
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.purple, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))

                VStack {
                    Text("75%")
                        .font(.system(size: 48, weight: .bold))
                    Text("Overall Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()

            // Pillar breakdown
            VStack(alignment: .leading, spacing: 8) {
                PillarRow(name: "Restorative Sleep", score: 80, color: .purple)
                PillarRow(name: "Movement + Exercise", score: 70, color: .red)
                PillarRow(name: "Healthful Nutrition", score: 75, color: .green)
                PillarRow(name: "Social Connection", score: 65, color: .blue)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct PillarRow: View {
    let name: String
    let score: Int
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            Text(name)
                .font(.subheadline)

            Spacer()

            Text("\\(score)%")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    PillarChartCard()
        .padding()
}
