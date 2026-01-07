//
//  TimingDistributionDetailView.swift
//  WellPath
//
//  Database-driven timing distribution visualization.
//  Loads timing windows from scoring_thresholds with threshold_type='timing'.
//  Used for: timing scores (hydration_timing_score, protein_timing_score, etc.)
//

import SwiftUI
import Supabase

// MARK: - Models

struct TimingThresholdData: Identifiable, Codable {
    let id: UUID
    let thresholdKey: String
    let displayName: String?
    let targetValue: Double  // Target percentage
    let windowStartHour: Int?
    let windowEndHour: Int?
    let iconName: String?
    let displayOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case thresholdKey = "threshold_key"
        case displayName = "display_name"
        case targetValue = "target_value"
        case windowStartHour = "window_start_hour"
        case windowEndHour = "window_end_hour"
        case iconName = "icon_name"
        case displayOrder = "display_order"
    }

    var windowName: String {
        displayName ?? thresholdKey.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var windowTimeRange: String {
        guard let start = windowStartHour, let end = windowEndHour else {
            return ""
        }
        return "\(formatHour(start)) - \(formatHour(end))"
    }

    private func formatHour(_ hour: Int) -> String {
        if hour == 0 { return "12am" }
        if hour == 12 { return "12pm" }
        if hour < 12 { return "\(hour)am" }
        return "\(hour - 12)pm"
    }

    var icon: String {
        iconName ?? defaultIcon
    }

    private var defaultIcon: String {
        guard let start = windowStartHour else { return "clock" }
        switch start {
        case 0..<6: return "moon.fill"
        case 6..<12: return "sunrise.fill"
        case 12..<18: return "sun.max.fill"
        default: return "sunset.fill"
        }
    }
}

/// Data for displaying a timing window with actual values
struct TimingWindowDisplayData: Identifiable {
    let id: String
    let threshold: TimingThresholdData
    let actualValue: Double      // Amount in this window (ml, grams, etc.)
    let actualPercentage: Double // Percentage of total
    let totalValue: Double

    var deviation: Double {
        actualPercentage - threshold.targetValue
    }

    var isOnTarget: Bool {
        abs(deviation) <= 10
    }

    var isAboveTarget: Bool {
        deviation > 10
    }

    var isBelowTarget: Bool {
        deviation < -10
    }
}

// MARK: - ViewModel

@MainActor
class TimingDistributionViewModel: ObservableObject {
    @Published var thresholds: [TimingThresholdData] = []
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    /// Load timing thresholds for a score type
    func loadTimingConfig(scoreType: String) async {
        isLoading = true
        error = nil

        do {
            let results: [TimingThresholdData] = try await supabase
                .from("scoring_thresholds")
                .select("id, threshold_key, display_name, target_value, window_start_hour, window_end_hour, icon_name, display_order")
                .eq("score_type", value: scoreType)
                .eq("threshold_type", value: "timing")
                .eq("is_active", value: true)
                .order("display_order", ascending: true)
                .execute()
                .value

            thresholds = results
        } catch {
            self.error = error.localizedDescription
            print("Error loading timing config: \(error)")
        }

        isLoading = false
    }

    /// Build display data from timing window values
    /// windowValues: [threshold_key: value] e.g., ["MORNING": 1500, "AFTERNOON": 800]
    func buildDisplayData(windowValues: [String: Double]) -> [TimingWindowDisplayData] {
        let totalValue = windowValues.values.reduce(0, +)
        guard totalValue > 0 else { return [] }

        return thresholds.map { threshold in
            let actualValue = windowValues[threshold.thresholdKey] ?? 0
            let percentage = (actualValue / totalValue) * 100

            return TimingWindowDisplayData(
                id: threshold.thresholdKey,
                threshold: threshold,
                actualValue: actualValue,
                actualPercentage: percentage,
                totalValue: totalValue
            )
        }
    }
}

// MARK: - View

struct TimingDistributionDetailView: View {
    let title: String
    let scoreType: String
    let windowValues: [String: Double]  // threshold_key -> value
    let unit: String
    let score: Int?
    let color: Color

    @StateObject private var viewModel = TimingDistributionViewModel()

    init(
        title: String,
        scoreType: String,
        windowValues: [String: Double],
        unit: String = "ml",
        score: Int? = nil,
        color: Color = .cyan
    ) {
        self.title = title
        self.scoreType = scoreType
        self.windowValues = windowValues
        self.unit = unit
        self.score = score
        self.color = color
    }

    private var displayData: [TimingWindowDisplayData] {
        viewModel.buildDisplayData(windowValues: windowValues)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text(title)
                .font(.headline)

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if displayData.isEmpty {
                Text("No timing data available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                // Timing window rows
                ForEach(displayData) { data in
                    timingWindowRow(data)
                }

                // Score display
                if let score = score {
                    HStack {
                        Spacer()
                        Text("Timing Score: \(score)/100")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(scoreColor(for: score))
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .task {
            await viewModel.loadTimingConfig(scoreType: scoreType)
        }
    }

    @ViewBuilder
    private func timingWindowRow(_ data: TimingWindowDisplayData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Window name with icon and time range
            HStack {
                Image(systemName: data.threshold.icon)
                    .foregroundColor(color)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(data.threshold.windowName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if !data.threshold.windowTimeRange.isEmpty {
                        Text(data.threshold.windowTimeRange)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text("Target: \(Int(data.threshold.targetValue))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    // Actual fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor(for: data))
                        .frame(width: geometry.size.width * min(1.0, data.actualPercentage / 100), height: 8)

                    // Target marker
                    let targetPosition = min(1.0, data.threshold.targetValue / 100)
                    VStack(spacing: 0) {
                        Triangle()
                            .fill(Color.primary)
                            .frame(width: 6, height: 3)
                        Rectangle()
                            .fill(Color.primary)
                            .frame(width: 1.5, height: 12)
                    }
                    .offset(x: geometry.size.width * targetPosition - 3, y: -3)
                }
            }
            .frame(height: 16)

            // Values and status row
            HStack {
                // Percentage and absolute value
                HStack(spacing: 4) {
                    Text("\(Int(data.actualPercentage))%")
                        .fontWeight(.semibold)
                        .foregroundColor(barColor(for: data))
                    Text("|")
                        .foregroundColor(.secondary)
                    Text(formatValue(data.actualValue))
                        .foregroundColor(.secondary)
                }
                .font(.caption)

                Spacer()

                // Status indicator
                statusIndicator(for: data)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func statusIndicator(for data: TimingWindowDisplayData) -> some View {
        HStack(spacing: 4) {
            if data.isOnTarget {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("On target")
            } else if data.isAboveTarget {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.yellow)
                Text("Above target")
            } else {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.orange)
                Text("Below target")
            }
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }

    private func barColor(for data: TimingWindowDisplayData) -> Color {
        if data.isOnTarget {
            return .green
        } else if data.isAboveTarget {
            return .yellow
        } else {
            return .orange
        }
    }

    private func formatValue(_ val: Double) -> String {
        switch unit.lowercased() {
        case "ml", "milliliter", "milliliters":
            if val >= 1000 {
                return String(format: "%.1fL", val / 1000)
            }
            return "\(Int(val))ml"
        case "l", "liter", "liters":
            return String(format: "%.1fL", val)
        case "g", "gram", "grams":
            return "\(Int(val))g"
        case "oz", "ounce", "ounces":
            return String(format: "%.1foz", val)
        default:
            return "\(Int(val))\(unit.isEmpty ? "" : " \(unit)")"
        }
    }

    private func scoreColor(for score: Int) -> Color {
        if score >= 80 { return .green }
        else if score >= 60 { return .yellow }
        else if score >= 40 { return .orange }
        else { return .red }
    }
}

// MARK: - Compact Variant

/// Compact timing distribution for summary views
struct TimingDistributionCompactView: View {
    let displayData: [TimingWindowDisplayData]
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(displayData) { data in
                VStack(spacing: 2) {
                    Image(systemName: data.threshold.icon)
                        .font(.caption2)
                        .foregroundColor(color)

                    Text("\(Int(data.actualPercentage))%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(barColor(for: data))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func barColor(for data: TimingWindowDisplayData) -> Color {
        if data.isOnTarget { return .green }
        else if data.isAboveTarget { return .yellow }
        else { return .orange }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            TimingDistributionDetailView(
                title: "Hydration Timing",
                scoreType: "hydration_timing_score",
                windowValues: [
                    "HYDRATION_MORNING": 1500,
                    "HYDRATION_AFTERNOON": 800,
                    "HYDRATION_EVENING": 300,
                    "HYDRATION_NIGHT": 100
                ],
                unit: "ml",
                score: 65,
                color: .cyan
            )
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
