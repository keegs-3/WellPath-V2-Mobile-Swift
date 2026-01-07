//
//  TierBreakdownView.swift
//  WellPath
//
//  Database-driven tier breakdown visualization.
//  Loads tiers from scoring_thresholds and type mappings from sample_category_types_reference.
//  Used for: type scores (protein_type_score, fat_type_score, caffeine_type_score)
//

import SwiftUI
import Supabase

// MARK: - Models

struct TierThresholdData: Identifiable, Codable {
    let id: UUID
    let thresholdKey: String
    let displayName: String?
    let displayDescription: String?
    let targetValue: Double
    let weight: Double
    let displayOrder: Int?
    let colorHex: String?

    enum CodingKeys: String, CodingKey {
        case id
        case thresholdKey = "threshold_key"
        case displayName = "display_name"
        case displayDescription = "display_description"
        case targetValue = "target_value"
        case weight
        case displayOrder = "display_order"
        case colorHex = "color_hex"
    }

    var tierName: String {
        displayName ?? thresholdKey.replacingOccurrences(of: "_", with: " ").capitalized
    }

    /// Parse color from hex string
    var tierColor: Color? {
        guard let hex = colorHex else { return nil }
        return Color(hex: hex)
    }
}

struct TypeTierMapping: Codable {
    let referenceKey: String
    let displayName: String
    let tierKey: String?

    enum CodingKeys: String, CodingKey {
        case referenceKey = "reference_key"
        case displayName = "display_name"
        case tierKey = "tier_key"
    }
}

/// Data for displaying a tier with its actual values
struct TierDisplayData: Identifiable {
    let id: String
    let tier: TierThresholdData
    let types: [TypeTierMapping]
    let actualValue: Double  // grams, mg, etc.
    let actualPercentage: Double
    let totalValue: Double

    var isOverTarget: Bool {
        actualPercentage > tier.targetValue
    }

    var isUnderTarget: Bool {
        actualPercentage < tier.targetValue
    }
}

// MARK: - ViewModel

@MainActor
class TierBreakdownViewModel: ObservableObject {
    @Published var tiers: [TierThresholdData] = []
    @Published var typeMapping: [TypeTierMapping] = []
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseManager.shared.client

    /// Load tier configuration for a score type
    func loadTiers(scoreType: String, referenceCategory: String) async {
        isLoading = true
        error = nil

        do {
            // Load tier thresholds
            let tierResults: [TierThresholdData] = try await supabase
                .from("scoring_thresholds")
                .select("id, threshold_key, display_name, display_description, target_value, weight, display_order, color_hex")
                .eq("score_type", value: scoreType)
                .eq("threshold_type", value: "tier")
                .eq("is_active", value: true)
                .order("display_order", ascending: true)
                .execute()
                .value

            // Load type-to-tier mapping
            let mappingResults: [TypeTierMapping] = try await supabase
                .from("sample_category_types_reference")
                .select("reference_key, display_name, tier_key")
                .eq("reference_category", value: referenceCategory)
                .eq("is_active", value: true)
                .execute()
                .value

            tiers = tierResults
            typeMapping = mappingResults
        } catch {
            self.error = error.localizedDescription
            print("Error loading tier config: \(error)")
        }

        isLoading = false
    }

    /// Get types belonging to a specific tier
    func typesForTier(_ tierId: String) -> [TypeTierMapping] {
        typeMapping.filter { $0.tierKey == tierId }
    }

    /// Build display data combining tiers with actual values
    func buildDisplayData(typeValues: [String: Double]) -> [TierDisplayData] {
        let totalValue = typeValues.values.reduce(0, +)
        guard totalValue > 0 else { return [] }

        return tiers.compactMap { tier in
            let tierTypes = typesForTier(tier.thresholdKey)
            let actualValue = tierTypes.reduce(0.0) { sum, type in
                sum + (typeValues[type.referenceKey] ?? 0)
            }
            let percentage = (actualValue / totalValue) * 100

            return TierDisplayData(
                id: tier.thresholdKey,
                tier: tier,
                types: tierTypes,
                actualValue: actualValue,
                actualPercentage: percentage,
                totalValue: totalValue
            )
        }
    }
}

// MARK: - View

struct TierBreakdownView: View {
    let title: String
    let scoreType: String
    let referenceCategory: String
    let typeValues: [String: Double]  // type_key -> value (grams, mg, etc.)
    let unit: String
    let score: Int?
    let baseColor: Color

    @StateObject private var viewModel = TierBreakdownViewModel()

    init(
        title: String,
        scoreType: String,
        referenceCategory: String,
        typeValues: [String: Double],
        unit: String = "g",
        score: Int? = nil,
        baseColor: Color = .blue
    ) {
        self.title = title
        self.scoreType = scoreType
        self.referenceCategory = referenceCategory
        self.typeValues = typeValues
        self.unit = unit
        self.score = score
        self.baseColor = baseColor
    }

    private var displayData: [TierDisplayData] {
        viewModel.buildDisplayData(typeValues: typeValues)
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
                Text("No type data available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                // Tier rows
                ForEach(displayData) { data in
                    tierRow(data)
                }

                // Score display
                if let score = score {
                    HStack {
                        Spacer()
                        Text("Type Score: \(score)/100")
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
            await viewModel.loadTiers(scoreType: scoreType, referenceCategory: referenceCategory)
        }
    }

    @ViewBuilder
    private func tierRow(_ data: TierDisplayData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Tier name and target
            HStack {
                Text(data.tier.tierName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("Target: \(Int(data.tier.targetValue))%")
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
                        .fill(tierColor(for: data))
                        .frame(width: geometry.size.width * min(1.0, data.actualPercentage / 100), height: 8)

                    // Target marker
                    let targetPosition = min(1.0, data.tier.targetValue / 100)
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

            // Values row
            HStack {
                // Percentage and absolute value
                HStack(spacing: 4) {
                    Text("\(Int(data.actualPercentage))%")
                        .fontWeight(.semibold)
                        .foregroundColor(tierColor(for: data))
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

            // Type list (collapsible or abbreviated)
            if !data.types.isEmpty {
                Text(data.types.map { $0.displayName }.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func statusIndicator(for data: TierDisplayData) -> some View {
        let deviation = abs(data.actualPercentage - data.tier.targetValue)

        HStack(spacing: 4) {
            if deviation <= 5 {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("On target")
            } else if data.isOverTarget {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(data.tier.weight > 0.5 ? .green : .orange)
                Text("Above target")
            } else {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(data.tier.weight > 0.5 ? .orange : .green)
                Text("Below target")
            }
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }

    private func tierColor(for data: TierDisplayData) -> Color {
        // Use database color if available
        if let color = data.tier.tierColor {
            return color
        }

        // Default colors based on tier order/multiplier
        if data.tier.weight >= 0.9 {
            return .green  // Tier 1 - Best
        } else if data.tier.weight >= 0.5 {
            return .blue   // Tier 2 - Good
        } else {
            return .orange // Tier 3 - Limit
        }
    }

    private func formatValue(_ val: Double) -> String {
        if val >= 1000 {
            return String(format: "%.1fk%@", val / 1000, unit)
        }
        return "\(Int(val))\(unit)"
    }

    private func scoreColor(for score: Int) -> Color {
        if score >= 80 { return .green }
        else if score >= 60 { return .yellow }
        else if score >= 40 { return .orange }
        else { return .red }
    }
}

// MARK: - Compact Variant

/// Compact tier breakdown for summary views
struct TierBreakdownCompactView: View {
    let displayData: [TierDisplayData]
    let baseColor: Color

    var body: some View {
        HStack(spacing: 8) {
            ForEach(displayData) { data in
                VStack(spacing: 4) {
                    Text("T\(tierNumber(data.tier.thresholdKey))")
                        .font(.caption2)
                        .fontWeight(.medium)

                    Text("\(Int(data.actualPercentage))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(tierColor(for: data))
                }
            }
        }
    }

    private func tierNumber(_ key: String) -> String {
        // Extract number from tier key like "PROTEIN_TIER_1"
        if let match = key.range(of: #"\d+"#, options: .regularExpression) {
            return String(key[match])
        }
        return "?"
    }

    private func tierColor(for data: TierDisplayData) -> Color {
        if data.tier.weight >= 0.9 {
            return .green
        } else if data.tier.weight >= 0.5 {
            return .blue
        } else {
            return .orange
        }
    }
}

// MARK: - Preview
// Note: Uses Color(hex:) from existing extensions

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            TierBreakdownView(
                title: "Protein Type Breakdown",
                scoreType: "protein_type_score",
                referenceCategory: "protein_types",
                typeValues: [
                    "plant_based": 30,
                    "fatty_fish": 15,
                    "eggs": 20,
                    "lean_protein": 25,
                    "dairy": 5,
                    "red_meat": 5
                ],
                unit: "g",
                score: 78,
                baseColor: .blue
            )
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
