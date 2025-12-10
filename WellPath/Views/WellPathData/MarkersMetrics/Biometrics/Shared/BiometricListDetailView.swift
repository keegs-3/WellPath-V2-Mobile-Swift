//
//  BiometricListDetailView.swift
//  WellPath
//
//  Detail view for biometrics from the biometrics list

import SwiftUI
import Charts

struct BiometricListDetailView: View {
    let name: String
    let value: String
    let status: String
    let optimalRange: String
    let trend: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Current value card
                VStack(spacing: 8) {
                    Text("Current Value")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(value)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 10, height: 10)
                        Text(status)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(16)

                // Range info
                if !optimalRange.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Reference Range")
                            .font(.headline)

                        HStack {
                            Text("Optimal Range")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(optimalRange)
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(16)
                }

                // Trend info
                if !trend.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Trend")
                            .font(.headline)

                        HStack {
                            Image(systemName: trendIcon)
                                .foregroundColor(trendColor)
                            Text(trend)
                                .foregroundColor(.secondary)
                        }
                        .font(.subheadline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(16)
                }

                Spacer()
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.large)
    }

    private var statusColor: Color {
        switch status.lowercased() {
        case "optimal", "normal", "good", "in-range":
            return .green
        case "at risk", "borderline", "elevated":
            return .orange
        case "high risk", "high", "low", "out-of-range":
            return .red
        default:
            return .gray
        }
    }

    private var trendIcon: String {
        switch trend.lowercased() {
        case let t where t.contains("up") || t.contains("increasing"):
            return "arrow.up.right"
        case let t where t.contains("down") || t.contains("decreasing"):
            return "arrow.down.right"
        default:
            return "arrow.right"
        }
    }

    private var trendColor: Color {
        switch trend.lowercased() {
        case let t where t.contains("up") || t.contains("increasing"):
            return .green
        case let t where t.contains("down") || t.contains("decreasing"):
            return .red
        default:
            return .secondary
        }
    }
}

#Preview {
    NavigationStack {
        BiometricListDetailView(
            name: "Resting Heart Rate",
            value: "62 bpm",
            status: "Optimal",
            optimalRange: "60-70 bpm",
            trend: "Stable"
        )
    }
}
