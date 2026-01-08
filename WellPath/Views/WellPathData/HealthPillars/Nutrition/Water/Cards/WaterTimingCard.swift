//
//  WaterTimingCard.swift
//  WellPath
//
//  Reusable card for Water Timing metric with mini clock visualization.
//

import SwiftUI
import Supabase

struct WaterTimingCard: View {
    let color: Color
    let pillar: String

    @StateObject private var viewModel = WaterTimingCardViewModel()

    var body: some View {
        MetricCardView(
            title: "Hydration Timing",
            color: color,
            metricId: "DISP_HYDRATION_TIMING",
            pillar: pillar
        ) {
            WaterTimingMiniCard(
                viewModel: viewModel,
                color: color
            )
        } fullScreen: {
            WaterTimingView(color: color)
        }
        .task {
            await viewModel.loadTodayData()
        }
    }
}

// MARK: - ViewModel

@MainActor
class WaterTimingCardViewModel: ObservableObject {
    @Published var hourlyData: [Int: Double] = [:]
    @Published var timingScore: Int? = nil  // Score from database view
    @Published var hasData = false
    @Published var isLoading = true

    private let supabase = SupabaseManager.shared.client

    func loadTodayData() async {
        isLoading = true

        do {
            let userId = try await supabase.auth.session.user.id
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let todayStr = dateFormatter.string(from: today)

            // Load timing score from view (same source as detail view)
            struct DailyScore: Decodable {
                let scoreValue: Double

                enum CodingKeys: String, CodingKey {
                    case scoreValue = "score_value"
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    if let doubleValue = try? container.decode(Double.self, forKey: .scoreValue) {
                        scoreValue = doubleValue
                    } else if let stringValue = try? container.decode(String.self, forKey: .scoreValue),
                              let parsed = Double(stringValue) {
                        scoreValue = parsed
                    } else {
                        scoreValue = 0
                    }
                }
            }

            let scoreResults: [DailyScore] = try await supabase
                .from("behavioral_scores")
                .select("score_value")
                .eq("patient_id", value: userId.uuidString)
                .eq("score_type", value: "hydration_timing_score")
                .eq("score_date", value: todayStr)
                .eq("score_context", value: "daily")
                .execute()
                .value

            if let result = scoreResults.first {
                self.timingScore = Int(result.scoreValue.rounded())
            }

            // Load hourly data for visualization
            struct WaterSample: Codable {
                let startTime: String
                let canonicalValue: Double?
                let quantityValue: Double

                enum CodingKeys: String, CodingKey {
                    case startTime = "start_time"
                    case canonicalValue = "canonical_value"
                    case quantityValue = "quantity_value"
                }
            }

            // Use aggregation_date (local date) not start_time (UTC) for filtering
            let samples: [WaterSample] = try await supabase
                .from("patient_quantity_samples")
                .select("start_time, canonical_value, quantity_value")
                .eq("patient_id", value: userId)
                .eq("quantity_type", value: "water_ml")
                .eq("aggregation_date", value: todayStr)
                .execute()
                .value

            var hourTotals: [Int: Double] = [:]
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            for sample in samples {
                let mlValue = sample.canonicalValue ?? sample.quantityValue
                guard mlValue > 0 else { continue }

                if let date = isoFormatter.date(from: sample.startTime) {
                    let hour = calendar.component(.hour, from: date)
                    hourTotals[hour, default: 0] += mlValue
                }
            }

            self.hourlyData = hourTotals
            self.hasData = !hourTotals.isEmpty || self.timingScore != nil
            self.isLoading = false

        } catch {
            print("Error loading water timing card: \(error)")
            self.isLoading = false
            self.hasData = false
        }
    }
}

// MARK: - Mini Card

struct WaterTimingMiniCard: View {
    @ObservedObject var viewModel: WaterTimingCardViewModel
    let color: Color

    private var displayScore: Int? {
        viewModel.timingScore
    }

    private var scoreColor: Color {
        guard let score = displayScore else { return .secondary }
        if score >= 85 { return .green }
        else if score >= 70 { return .blue }
        else if score >= 55 { return .orange }
        else { return .red }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Score on left (matches Protein Type layout)
            VStack(alignment: .leading, spacing: 4) {
                Text("Timing Score")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if viewModel.isLoading {
                    Text("...")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                } else if let score = displayScore {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(score)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(scoreColor)
                        Text("/ 100")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("--")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }

                Text("Today")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Mini clock visualization on right
            MiniRingClock(
                hourlyData: viewModel.hourlyData,
                color: color,
                size: 54
            )
        }
        .frame(height: 60)
    }
}

// MARK: - Mini Ring Clock

struct MiniRingClock: View {
    let hourlyData: [Int: Double]
    let color: Color
    let size: CGFloat

    private let ringWidth: CGFloat = 4
    private let activeStartHour = 6
    private let activeEndHour = 22

    // The radius for the ring center (stroke is centered on this)
    private var ringRadius: CGFloat {
        (size - ringWidth) / 2
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: ringWidth)
                .frame(width: size - ringWidth, height: size - ringWidth)

            // Hour segments with data
            ForEach(0..<24, id: \.self) { hour in
                if (hourlyData[hour] ?? 0) > 0 {
                    hourSegment(hour: hour)
                }
            }

            // Center icon
            Image(systemName: "drop.fill")
                .font(.system(size: size * 0.28))
                .foregroundColor(hourlyData.isEmpty ? color.opacity(0.3) : color)
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private func hourSegment(hour: Int) -> some View {
        let amount = hourlyData[hour] ?? 0
        let maxHourly = hourlyData.values.max() ?? 1
        let intensity = min(amount / maxHourly, 1.0)
        let isActive = hour >= activeStartHour && hour < activeEndHour

        let degreesPerHour = 360.0 / 24.0
        // Inset slightly so rounded caps don't overlap adjacent segments
        let gapDegrees = 2.0
        let startAngle = Double(hour) * degreesPerHour - 90 + gapDegrees
        let endAngle = Double(hour + 1) * degreesPerHour - 90 - gapDegrees

        Path { path in
            path.addArc(
                center: CGPoint(x: size / 2, y: size / 2),
                radius: ringRadius,
                startAngle: .degrees(startAngle),
                endAngle: .degrees(endAngle),
                clockwise: false
            )
        }
        .stroke(
            isActive ? color.opacity(0.5 + intensity * 0.5) : Color.orange.opacity(0.6),
            style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
        )
    }
}

#Preview {
    WaterTimingCard(color: .cyan, pillar: "Healthful Nutrition")
        .padding()
}
