//
//  TrackedMetricsListView.swift
//  WellPath
//
//  Created on 2025-10-22
//

import SwiftUI

struct TrackedMetricsListView: View {
    var body: some View {
        List {
            // Restorative Sleep
            Section("Restorative Sleep") {
                NavigationLink(destination: SleepDetailView()) {
                    MetricListRow(
                        title: "Sleep Duration",
                        icon: "bed.double.fill",
                        color: .purple,
                        value: "7.5 hrs",
                        subtitle: "Avg this week"
                    )
                }
            }

            // Movement + Exercise
            Section("Movement + Exercise") {
                NavigationLink(destination: Text("Steps Detail")) {
                    MetricListRow(
                        title: "Steps",
                        icon: "figure.walk",
                        color: .orange,
                        value: "6,800",
                        subtitle: "Today"
                    )
                }

                NavigationLink(destination: Text("Cardio Detail")) {
                    MetricListRow(
                        title: "Cardio Sessions",
                        icon: "figure.run",
                        color: .red,
                        value: "3",
                        subtitle: "This week"
                    )
                }

                NavigationLink(destination: Text("Strength Detail")) {
                    MetricListRow(
                        title: "Strength Sessions",
                        icon: "dumbbell.fill",
                        color: .blue,
                        value: "2",
                        subtitle: "This week"
                    )
                }
            }

            // Healthful Nutrition
            Section("Healthful Nutrition") {
                NavigationLink(destination: Text("Water Detail")) {
                    MetricListRow(
                        title: "Water Intake",
                        icon: "drop.fill",
                        color: .cyan,
                        value: "64 oz",
                        subtitle: "Today"
                    )
                }

                NavigationLink(destination: Text("Vegetables Detail")) {
                    MetricListRow(
                        title: "Vegetable Servings",
                        icon: "leaf.fill",
                        color: .green,
                        value: "5",
                        subtitle: "Today"
                    )
                }

                NavigationLink(destination: Text("Fruits Detail")) {
                    MetricListRow(
                        title: "Fruit Servings",
                        icon: "apple.logo",
                        color: .pink,
                        value: "3",
                        subtitle: "Today"
                    )
                }
            }

            // Stress Management
            Section("Stress Management") {
                NavigationLink(destination: Text("Meditation Detail")) {
                    MetricListRow(
                        title: "Meditation",
                        icon: "brain.head.profile",
                        color: .indigo,
                        value: "10 min",
                        subtitle: "Today"
                    )
                }
            }
        }
        .navigationTitle("Tracked Metrics")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct MetricListRow: View {
    let title: String
    let icon: String
    let color: Color
    let value: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        TrackedMetricsListView()
    }
}
