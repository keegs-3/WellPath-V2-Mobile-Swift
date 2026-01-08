//
//  CaffeineTypeCard.swift
//  WellPath
//
//  Reusable card for Caffeine Type metric showing quality score and tier breakdown.
//

import SwiftUI
import Supabase

struct CaffeineTypeCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Caffeine Types",
            color: color,
            metricId: "DISP_CAFFEINE_TYPE",
            pillar: pillar
        ) {
            CaffeineTypeMiniCard(color: color)
        } fullScreen: {
            CaffeineTypeView(color: color)
        }
    }
}

// MARK: - Mini Card

struct CaffeineTypeMiniCard: View {
    let color: Color
    @StateObject private var viewModel: CaffeineTypeDonutViewModel
    @State private var isLoading = true
    @State private var latestDate: Date?
    @State private var latestScore: Double?
    @State private var tier1Pct: Double = 0  // Quality Sources
    @State private var tier2Pct: Double = 0  // Limit Sources

    init(color: Color) {
        self.color = color
        _viewModel = StateObject(wrappedValue: CaffeineTypeDonutViewModel(baseColor: color))
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

                    // Right: Tier breakdown
                    VStack(alignment: .trailing, spacing: 4) {
                        tierIndicator(
                            label: "Tier 1",
                            percentage: tier1Pct,
                            color: MetricsUIConfig.tierGood
                        )
                        tierIndicator(
                            label: "Tier 2",
                            percentage: tier2Pct,
                            color: MetricsUIConfig.tierPoor
                        )
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 24))
                        .foregroundColor(color.opacity(0.6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Source Quality")
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
            await viewModel.loadCaffeineTypeDisplayNames()
            await loadLatestData()
        }
    }

    private func loadLatestData() async {
        do {
            let client = SupabaseManager.shared.client
            let userId = try await client.auth.session.user.id

            // Get last 14 days of caffeine data to find most recent day
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            guard let startDate = calendar.date(byAdding: .day, value: -14, to: today) else {
                isLoading = false
                return
            }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let startDateString = dateFormatter.string(from: startDate)

            struct CaffeineSample: Decodable {
                let quantityValue: Double
                let aggregationDate: String
                let caffeineType: String?

                enum CodingKeys: String, CodingKey {
                    case quantityValue = "quantity_value"
                    case aggregationDate = "aggregation_date"
                    case metadata
                }

                enum MetadataKeys: String, CodingKey {
                    case caffeineType = "caffeine_type"
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    quantityValue = try container.decode(Double.self, forKey: .quantityValue)
                    aggregationDate = try container.decode(String.self, forKey: .aggregationDate)

                    if let metadataContainer = try? container.nestedContainer(keyedBy: MetadataKeys.self, forKey: .metadata) {
                        caffeineType = try? metadataContainer.decode(String.self, forKey: .caffeineType)
                    } else {
                        caffeineType = nil
                    }
                }
            }

            let results: [CaffeineSample] = try await client
                .from("patient_quantity_samples")
                .select("quantity_value, aggregation_date, metadata")
                .eq("patient_id", value: userId.uuidString)
                .eq("quantity_type", value: "caffeine_mg")
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
            var totalMg: Double = 0
            var tier1Mg: Double = 0
            var tier2Mg: Double = 0

            for sample in samplesForDate {
                totalMg += sample.quantityValue

                // Look up tier from viewModel config
                if let caffeineType = sample.caffeineType,
                   let tierConfig = viewModel.tierConfig {
                    for tier in tierConfig.tiers {
                        if tier.caffeineTypes.contains(caffeineType) {
                            switch tier.tierId {
                            case "CAFFEINE_TIER_1": tier1Mg += sample.quantityValue
                            case "CAFFEINE_TIER_2": tier2Mg += sample.quantityValue
                            default: break
                            }
                            break
                        }
                    }
                }
            }

            // Calculate percentages
            if totalMg > 0 {
                tier1Pct = (tier1Mg / totalMg) * 100
                tier2Pct = (tier2Mg / totalMg) * 100

                // Calculate quality score: 100% Tier 1 = 100, 100% Tier 2 = 0
                latestScore = tier1Pct
            }

            // Parse date
            if let date = dateFormatter.date(from: mostRecentDateString) {
                latestDate = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)
            }

            isLoading = false

        } catch {
            print("Error loading caffeine type data: \(error)")
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
    CaffeineTypeCard(color: .brown, pillar: "Healthful Nutrition")
        .padding()
}
