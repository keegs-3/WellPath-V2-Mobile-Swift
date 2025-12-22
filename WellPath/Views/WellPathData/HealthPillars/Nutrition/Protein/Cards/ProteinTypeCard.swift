//
//  ProteinTypeCard.swift
//  WellPath
//
//  Reusable card for Protein Type metric.
//  Shows today's (or most recent) type score on left, tier breakdown on right.
//

import SwiftUI
import Supabase

struct ProteinTypeCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Protein Type",
            color: color,
            metricId: "DISP_PROTEIN_TYPE",
            pillar: pillar
        ) {
            ProteinTypeMiniCard(color: color)
        } fullScreen: {
            ProteinTypeView(color: color)
        }
    }
}

// MARK: - Mini Card

struct ProteinTypeMiniCard: View {
    let color: Color
    @StateObject private var viewModel: ProteinTypeDonutViewModel
    @State private var isLoading = true
    @State private var latestDate: Date?
    @State private var latestScore: Double?
    @State private var latestTier1Pct: Double = 0
    @State private var latestTier2Pct: Double = 0
    @State private var latestTier3Pct: Double = 0

    init(color: Color) {
        self.color = color
        _viewModel = StateObject(wrappedValue: ProteinTypeDonutViewModel(baseColor: color))
    }

    private var scoreColor: Color {
        guard let score = latestScore else { return .secondary }
        if score >= 80 { return .green }
        else if score >= 60 { return .yellow }
        else if score >= 40 { return .orange }
        else { return .red }
    }

    private var scoreStatus: (text: String, color: Color) {
        guard let score = latestScore else { return ("No data", .secondary) }
        if score >= 80 { return ("Excellent", MetricsUIConfig.tierGood) }
        else if score >= 60 { return ("Good", MetricsUIConfig.tierMedium) }
        else if score >= 40 { return ("Fair", .orange) }
        else { return ("Needs work", MetricsUIConfig.tierPoor) }
    }

    private var formattedDate: String {
        guard let date = latestDate else { return "" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func tierName(for tierId: String) -> String {
        guard let tierConfig = viewModel.tierConfig,
              let tier = tierConfig.tiers.first(where: { $0.tierId == tierId }) else {
            switch tierId {
            case "PROTEIN_TIER_1": return "Tier 1"
            case "PROTEIN_TIER_2": return "Tier 2"
            case "PROTEIN_TIER_3": return "Tier 3"
            default: return "?"
            }
        }
        return tier.tierName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(height: 60)
            } else if latestScore != nil {
                HStack(spacing: 16) {
                    // Left: Latest score with date
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formattedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(latestScore!.rounded()))")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(scoreColor)
                            Text("/ 100")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(scoreStatus.text)
                            .font(.caption)
                            .foregroundColor(scoreStatus.color)
                    }

                    Spacer()

                    // Right: Tier breakdown (same day)
                    VStack(alignment: .trailing, spacing: 4) {
                        tierIndicator(
                            label: tierName(for: "PROTEIN_TIER_1"),
                            percentage: latestTier1Pct,
                            color: MetricsUIConfig.tierGood
                        )
                        tierIndicator(
                            label: tierName(for: "PROTEIN_TIER_2"),
                            percentage: latestTier2Pct,
                            color: MetricsUIConfig.tierMedium
                        )
                        tierIndicator(
                            label: tierName(for: "PROTEIN_TIER_3"),
                            percentage: latestTier3Pct,
                            color: MetricsUIConfig.tierPoor
                        )
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 24))
                        .foregroundColor(color.opacity(0.6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Protein Type")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("No data yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(height: 60)
            }
        }
        .task {
            await viewModel.loadTierConfig()
            await loadLatestData()
        }
    }

    private func loadLatestData() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            // Get last 14 days of protein data to find most recent day
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            guard let startDate = calendar.date(byAdding: .day, value: -14, to: today) else {
                isLoading = false
                return
            }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let startDateString = dateFormatter.string(from: startDate)

            struct ProteinSample: Decodable {
                let canonicalValue: Double
                let aggregationDate: String
                let proteinType: String?

                enum CodingKeys: String, CodingKey {
                    case canonicalValue = "canonical_value"
                    case aggregationDate = "aggregation_date"
                    case metadata
                }

                enum MetadataKeys: String, CodingKey {
                    case proteinTypes = "protein_types"
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    canonicalValue = try container.decode(Double.self, forKey: .canonicalValue)
                    aggregationDate = try container.decode(String.self, forKey: .aggregationDate)

                    if let metadataContainer = try? container.nestedContainer(keyedBy: MetadataKeys.self, forKey: .metadata) {
                        proteinType = try? metadataContainer.decode(String.self, forKey: .proteinTypes)
                    } else {
                        proteinType = nil
                    }
                }
            }

            let results: [ProteinSample] = try await client
                .from("patient_quantity_samples")
                .select("canonical_value, aggregation_date, metadata")
                .eq("patient_id", value: userId.uuidString)
                .eq("quantity_type", value: "protein_grams")
                .in("source", values: ["wellpath_input", "healthkit"])
                .gte("aggregation_date", value: startDateString)
                .order("aggregation_date", ascending: false)
                .execute()
                .value

            guard !results.isEmpty else {
                isLoading = false
                return
            }

            // Find most recent date with data
            let mostRecentDateString = results.first!.aggregationDate
            let samplesForDate = results.filter { $0.aggregationDate == mostRecentDateString }

            // Calculate totals by tier for that day
            var totalGrams: Double = 0
            var tier1Grams: Double = 0
            var tier2Grams: Double = 0
            var tier3Grams: Double = 0

            for sample in samplesForDate {
                totalGrams += sample.canonicalValue

                // Look up tier from viewModel config
                if let proteinType = sample.proteinType,
                   let tierConfig = viewModel.tierConfig {
                    for tier in tierConfig.tiers {
                        if tier.proteinTypes.contains(proteinType) {
                            switch tier.tierId {
                            case "PROTEIN_TIER_1": tier1Grams += sample.canonicalValue
                            case "PROTEIN_TIER_2": tier2Grams += sample.canonicalValue
                            case "PROTEIN_TIER_3": tier3Grams += sample.canonicalValue
                            default: break
                            }
                            break
                        }
                    }
                }
            }

            // Calculate percentages
            if totalGrams > 0 {
                latestTier1Pct = (tier1Grams / totalGrams) * 100
                latestTier2Pct = (tier2Grams / totalGrams) * 100
                latestTier3Pct = (tier3Grams / totalGrams) * 100

                // Calculate type score using tier multipliers
                var typeScore: Double = 0
                if let tierConfig = viewModel.tierConfig {
                    for tier in tierConfig.tiers {
                        let pct: Double
                        switch tier.tierId {
                        case "PROTEIN_TIER_1": pct = latestTier1Pct
                        case "PROTEIN_TIER_2": pct = latestTier2Pct
                        case "PROTEIN_TIER_3":
                            pct = max(0, latestTier3Pct - Double(tier.targetPercentage))
                        default: continue
                        }
                        typeScore += pct * tier.multiplier
                    }
                }
                latestScore = min(100, max(0, typeScore))
            }

            // Parse date
            if let date = dateFormatter.date(from: mostRecentDateString) {
                latestDate = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)
            }

            isLoading = false

        } catch {
            print("Error loading protein type data: \(error)")
            isLoading = false
        }
    }

    @ViewBuilder
    private func tierIndicator(label: String, percentage: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 32, alignment: .trailing)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                    .frame(width: 50, height: 6)

                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 50 * min(percentage / 100, 1.0), height: 6)
            }

            Text("\(Int(percentage.rounded()))%")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)
        }
    }
}

#Preview {
    ProteinTypeCard(color: .blue, pillar: "Healthful Nutrition")
        .padding()
}
