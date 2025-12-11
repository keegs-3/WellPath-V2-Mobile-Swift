//
//  BiometricMiniCard.swift
//  WellPath
//
//  Mini card view for biometric metrics
//  Shows current value, status indicator, and description
//

import SwiftUI

struct BiometricMiniCard: View {
    let metric: DisplayMetric
    let color: Color
    let icon: String

    @StateObject private var dataLoader = BiometricValueLoader()

    // Metrics that use weight units (lb/kg)
    private let weightMetrics: Set<String> = ["DISP_BODYWEIGHT"]

    // Metrics that use length units (in/cm)
    private let lengthMetrics: Set<String> = ["DISP_WAIST_CIRCUMFERENCE", "DISP_HIP_CIRCUMFERENCE"]

    /// Display unit based on user preferences for weight/length metrics
    private var displayUnit: String {
        if weightMetrics.contains(metric.metricId) {
            return dataLoader.preferredWeightUnit.rawValue
        }
        if lengthMetrics.contains(metric.metricId) {
            return dataLoader.preferredLengthUnit == .cm ? "cm" : "in"
        }
        return dataLoader.unit ?? ""
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }

            // Value and description
            VStack(alignment: .leading, spacing: 4) {
                if dataLoader.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if let value = dataLoader.currentValue {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(formatValue(value))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        if !displayUnit.isEmpty {
                            Text(displayUnit)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("No data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let description = metric.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Status indicator if we have a value
            if dataLoader.currentValue != nil {
                statusIndicator
            }
        }
        .task {
            await dataLoader.loadValue(for: metric.metricId)
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if let status = dataLoader.status {
            VStack(alignment: .trailing, spacing: 2) {
                Circle()
                    .fill(statusColor(status))
                    .frame(width: 10, height: 10)
                Text(status)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "optimal", "normal", "good":
            return .green
        case "at risk", "borderline", "elevated":
            return .orange
        case "high risk", "high", "low":
            return .red
        default:
            return .gray
        }
    }

    private func formatValue(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f", value)
        } else if value >= 10 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

// Preview requires real DisplayMetric from database query
#Preview {
    Text("BiometricMiniCard Preview")
}
