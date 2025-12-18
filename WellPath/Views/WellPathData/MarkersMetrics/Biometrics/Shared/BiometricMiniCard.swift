//
//  BiometricMiniCard.swift
//  WellPath
//
//  Mini card view for biometric metrics
//  Shows icon, current value, date, and sparkline
//

import SwiftUI

// MARK: - Data Change Notifications

extension Notification.Name {
    /// Posted when biometric data changes (entry added, edited, or deleted)
    static let biometricDataDidChange = Notification.Name("biometricDataDidChange")
}

struct BiometricMiniCard: View {
    let metricId: String
    let color: Color
    let fallbackIcon: String

    @StateObject private var loader = BiometricValueLoader()

    // Metrics that use weight units (lb/kg)
    private static let weightMetrics: Set<String> = ["DISP_BODYWEIGHT", "DISP_GRIP_STRENGTH"]

    // Metrics that use length units (in/cm)
    private static let lengthMetrics: Set<String> = ["DISP_WAIST_CIRCUMFERENCE", "DISP_HIP_CIRCUMFERENCE"]

    /// Display unit based on user preferences for weight/length metrics
    private var displayUnit: String {
        if Self.weightMetrics.contains(metricId) {
            return loader.preferredWeightUnit.rawValue
        }
        if Self.lengthMetrics.contains(metricId) {
            return loader.preferredLengthUnit == .cm ? "cm" : "in"
        }
        return loader.unit ?? ""
    }

    /// Smart date display: Today, Yesterday, day name (if this week), or date
    private var formattedDate: String {
        guard let date = loader.lastUpdated else { return "" }

        let calendar = Calendar.current
        let now = Date()

        // Check if today
        if calendar.isDateInToday(date) {
            return "Today"
        }

        // Check if yesterday
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        // Check if within the current week (Monday to Sunday)
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        if date >= startOfWeek {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"  // Full day name
            return formatter.string(from: date)
        }

        // Otherwise show the date
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    /// Convenience initializer for use with DisplayMetric
    init(metric: DisplayMetric, color: Color, icon: String) {
        self.metricId = metric.metricId
        self.color = color
        self.fallbackIcon = icon
    }

    /// Simple initializer with just metricId
    init(metricId: String, color: Color, fallbackIcon: String = "circle.fill") {
        self.metricId = metricId
        self.color = color
        self.fallbackIcon = fallbackIcon
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: loader.icon ?? fallbackIcon)
                    .font(.title3)
                    .foregroundColor(color)
            }

            // Value and date
            VStack(alignment: .leading, spacing: 4) {
                if loader.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if let value = loader.currentValue {
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
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Sparkline
            BiometricSparkline(dataPoints: loader.sparklinePoints, color: color)
        }
        .onAppear {
            Task { await loader.loadValue(for: metricId) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .biometricDataDidChange)) { _ in
            Task { await loader.loadValue(for: metricId) }
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

#Preview {
    BiometricMiniCard(metricId: "DISP_BODYFAT", color: .purple, fallbackIcon: "percent")
        .padding()
}
