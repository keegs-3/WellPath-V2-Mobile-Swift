//
//  MetricsView.swift
//  WellPath
//
//  Created on 2025-10-22
//

import SwiftUI

struct MetricsView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: SleepDetailView()) {
                    MetricRow(title: "Sleep", icon: "bed.double.fill", color: .purple)
                }

                NavigationLink(destination: Text("Cardio Detail")) {
                    MetricRow(title: "Cardio", icon: "figure.run", color: .red)
                }

                NavigationLink(destination: Text("Nutrition Detail")) {
                    MetricRow(title: "Nutrition", icon: "leaf.fill", color: .green)
                }
            }
            .navigationTitle("Metrics")
        }
    }
}

struct MetricRow: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
                .frame(width: 40)

            Text(title)
                .font(.headline)

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    MetricsView()
}
