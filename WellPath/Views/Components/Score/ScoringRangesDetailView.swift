//
//  ScoringRangesDetailView.swift
//  WellPath
//
//  Database-driven scoring ranges visualization.
//  Loads ranges from sample_scoring_ranges and highlights patient's value.
//  Used for: amount scores (hydration_amount_score, steps_score, etc.)
//

import SwiftUI
import Supabase

// MARK: - Models

struct ScoringRangeData: Identifiable, Codable {
    let id: UUID
    let rangeName: String
    let rangeLow: Double?
    let rangeHigh: Double?
    let scoreAtLow: Double?
    let scoreAtHigh: Double?
    let frontendDisplay: String?

    enum CodingKeys: String, CodingKey {
        case id
        case rangeName = "range_name"
        case rangeLow = "range_low"
        case rangeHigh = "range_high"
        case scoreAtLow = "score_at_low"
        case scoreAtHigh = "score_at_high"
        case frontendDisplay = "frontend_display"
    }

    // Safe accessors with defaults
    var safeLow: Double { rangeLow ?? 0 }
    var safeHigh: Double { rangeHigh ?? Double.infinity }

    /// Determines if a value falls within this range
    func contains(_ value: Double) -> Bool {
        value >= safeLow && value <= safeHigh
    }

    /// Calculate score for a value in this range (linear interpolation)
    func scoreFor(_ value: Double) -> Double? {
        guard contains(value) else { return nil }
        guard let low = scoreAtLow else { return nil }

        // Handle case where range is a single point
        if safeLow == safeHigh {
            return low
        }

        guard let high = scoreAtHigh else { return low }

        // Linear interpolation
        let ratio = (value - safeLow) / (safeHigh - safeLow)
        return low + (high - low) * ratio
    }
}

// MARK: - ViewModel

@MainActor
class ScoringRangesDetailViewModel: ObservableObject {
    @Published var ranges: [ScoringRangeData] = []
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    /// Load ranges for a specific quantity type from sample_scoring_ranges
    func loadRanges(for quantityType: String) async {
        isLoading = true
        error = nil

        do {
            let results: [ScoringRangeData] = try await supabase
                .from("sample_scoring_ranges")
                .select("id, range_name, range_low, range_high, score_at_low, score_at_high, frontend_display")
                .eq("quantity_type", value: quantityType)
                .order("range_low", ascending: true)
                .execute()
                .value

            ranges = results
        } catch {
            self.error = error.localizedDescription
            print("Error loading scoring ranges: \(error)")
        }

        isLoading = false
    }

    /// Load ranges by range_key (for variety scores, etc.)
    func loadRangesByKey(_ rangeKey: String) async {
        isLoading = true
        error = nil

        do {
            let results: [ScoringRangeData] = try await supabase
                .from("sample_scoring_ranges")
                .select("id, range_name, range_low, range_high, score_at_low, score_at_high, frontend_display")
                .eq("range_key", value: rangeKey)
                .order("range_low", ascending: true)
                .execute()
                .value

            ranges = results
        } catch {
            self.error = error.localizedDescription
            print("Error loading scoring ranges by key: \(error)")
        }

        isLoading = false
    }

    /// Find which range contains the given value
    func activeRange(for value: Double) -> ScoringRangeData? {
        ranges.first { $0.contains(value) }
    }

    /// Calculate score for a given value
    func calculateScore(for value: Double) -> Double? {
        activeRange(for: value)?.scoreFor(value)
    }
}

// MARK: - View

struct ScoringRangesDetailView: View {
    let title: String
    let value: Double
    let unit: String
    let quantityType: String?
    let rangeKey: String?
    let score: Int?
    let color: Color

    @StateObject private var viewModel = ScoringRangesDetailViewModel()

    /// Initialize with quantity_type lookup (standard for amount scores)
    init(
        title: String,
        value: Double,
        unit: String,
        quantityType: String,
        score: Int? = nil,
        color: Color = .blue
    ) {
        self.title = title
        self.value = value
        self.unit = unit
        self.quantityType = quantityType
        self.rangeKey = nil
        self.score = score
        self.color = color
    }

    /// Initialize with range_key lookup (for variety scores, etc.)
    init(
        title: String,
        value: Double,
        unit: String,
        rangeKey: String,
        score: Int? = nil,
        color: Color = .blue
    ) {
        self.title = title
        self.value = value
        self.unit = unit
        self.quantityType = nil
        self.rangeKey = rangeKey
        self.score = score
        self.color = color
    }

    private func isActive(_ range: ScoringRangeData) -> Bool {
        range.contains(value)
    }

    private func rangeStyle(_ range: ScoringRangeData) -> (bg: Color, text: Color, ring: Color?) {
        let active = isActive(range)

        if !active {
            return (Color(.secondarySystemGroupedBackground), .secondary, nil)
        }

        // Color based on range name (standard naming convention)
        switch range.rangeName.uppercased() {
        case "OPTIMAL", "EXCELLENT", "PERFECT":
            return (Color.green.opacity(0.15), .green, .green)
        case "GOOD", "IN RANGE", "ABOVE TARGET", "TARGET":
            return (Color.yellow.opacity(0.15), .primary, .yellow)
        case "FAIR", "MODERATE", "BELOW TARGET":
            return (Color.orange.opacity(0.15), .orange, .orange)
        case "POOR", "OUT OF RANGE", "LOW", "HIGH":
            return (Color.red.opacity(0.15), .red, .red)
        default:
            return (color.opacity(0.15), .primary, color)
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
        case "%", "percent":
            return "\(Int(val))%"
        case "g", "gram", "grams":
            return "\(Int(val))g"
        case "steps":
            if val >= 1000 {
                return String(format: "%.1fk", val / 1000)
            }
            return "\(Int(val))"
        default:
            if val >= 1000 {
                return String(format: "%.1f", val)
            }
            return "\(Int(val))\(unit.isEmpty ? "" : " \(unit)")"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with title and current value
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("Your value: \(formatValue(value))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if viewModel.ranges.isEmpty {
                Text("No scoring ranges available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                // Range rows
                ForEach(viewModel.ranges) { range in
                    rangeRow(range)
                }

                // Score display
                if let score = score {
                    HStack {
                        Spacer()
                        Text("Score: \(score)/100")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(scoreColor(for: score))
                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .task {
            if let rangeKey = rangeKey {
                await viewModel.loadRangesByKey(rangeKey)
            } else if let quantityType = quantityType {
                await viewModel.loadRanges(for: quantityType)
            }
        }
    }

    @ViewBuilder
    private func rangeRow(_ range: ScoringRangeData) -> some View {
        let styles = rangeStyle(range)
        let active = isActive(range)

        HStack {
            HStack(spacing: 8) {
                Image(systemName: active ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundColor(active ? styles.text : .secondary)

                Text(range.rangeName)
                    .fontWeight(active ? .semibold : .regular)
            }

            Spacer()

            Text(range.frontendDisplay ?? formatRangeDisplay(range))
                .font(.subheadline)
        }
        .foregroundColor(styles.text)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(styles.bg)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(styles.ring ?? .clear, lineWidth: active ? 2 : 0)
        )
    }

    private func formatRangeDisplay(_ range: ScoringRangeData) -> String {
        let lowStr = formatValue(range.safeLow)
        let highStr = formatValue(range.safeHigh)

        // Handle unbounded ranges
        if range.safeLow <= 0 {
            return "< \(highStr)"
        }
        if range.safeHigh >= 999999 {
            return "> \(lowStr)"
        }

        return "\(lowStr) - \(highStr)"
    }

    private func scoreColor(for score: Int) -> Color {
        if score >= 80 { return .green }
        else if score >= 60 { return .yellow }
        else if score >= 40 { return .orange }
        else { return .red }
    }
}

// MARK: - Compact Variant

/// A more compact version for use in component breakdowns
struct ScoringRangesCompactView: View {
    let value: Double
    let ranges: [ScoringRangeData]
    let unit: String

    private func isActive(_ range: ScoringRangeData) -> Bool {
        range.contains(value)
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ranges) { range in
                let active = isActive(range)

                VStack(spacing: 2) {
                    Text(range.rangeName.prefix(3).uppercased())
                        .font(.system(size: 8, weight: .medium))

                    Rectangle()
                        .fill(active ? rangeColor(range) : Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)
                }
                .opacity(active ? 1.0 : 0.5)
            }
        }
    }

    private func rangeColor(_ range: ScoringRangeData) -> Color {
        switch range.rangeName.uppercased() {
        case "OPTIMAL", "EXCELLENT", "PERFECT":
            return .green
        case "GOOD", "IN RANGE", "ABOVE TARGET", "TARGET":
            return .yellow
        case "FAIR", "MODERATE", "BELOW TARGET":
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            ScoringRangesDetailView(
                title: "Daily Water Intake",
                value: 2500,
                unit: "ml",
                quantityType: "water_ml",
                score: 85,
                color: .cyan
            )

            ScoringRangesDetailView(
                title: "Daily Steps",
                value: 8500,
                unit: "steps",
                quantityType: "steps",
                score: 72,
                color: .green
            )
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
