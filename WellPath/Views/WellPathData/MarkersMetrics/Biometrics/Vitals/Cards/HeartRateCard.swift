//
//  HeartRateCard.swift
//  WellPath
//
//  Individual card for Heart Rate (time series data)
//

import SwiftUI

struct HeartRateCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Heart Rate",
            color: color,
            metricId: "DISP_HEART_RATE",
            pillar: pillar,
            cardId: "DISP_HEART_RATE",
            sectionId: "NAV_BIOMETRICS",
            itemType: .biometric
        ) {
            HeartRateMiniCard(color: color)
        } fullScreen: {
            HeartRateFullView(color: color)
        }
    }
}

struct HeartRateMiniCard: View {
    let color: Color
    @StateObject private var loader = HRCardLoader()

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                if loader.isLoading {
                    ProgressView().scaleEffect(0.8)
                } else if loader.hasData {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(loader.rangeDisplay)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("BPM")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("Today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .task {
            await loader.loadTodayRange()
        }
    }
}

/// Loads today's heart rate range from patient_series_samples (heart_rate_series)
@MainActor
class HRCardLoader: ObservableObject {
    @Published var minValue: Double?
    @Published var maxValue: Double?
    @Published var isLoading = false

    private let supabase = SupabaseManager.shared.client

    var hasData: Bool {
        maxValue != nil && maxValue! > 0
    }

    var rangeDisplay: String {
        guard let max = maxValue else { return "--" }
        guard let min = minValue, min > 0, min != max else {
            return "\(Int(max))"
        }
        return "\(Int(min))-\(Int(max))"
    }

    func loadTodayRange() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let patientId = try await supabase.auth.session.user.id

            // Get start of today
            let startOfToday = Calendar.current.startOfDay(for: Date())
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            struct SeriesResult: Codable {
                let value: Double
                let timestamp: Date

                enum CodingKeys: String, CodingKey {
                    case value
                    case timestamp
                }
            }

            // Custom decoder for Supabase timestamps
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)

                let iso8601 = ISO8601DateFormatter()
                iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = iso8601.date(from: dateString) {
                    return date
                }

                iso8601.formatOptions = [.withInternetDateTime]
                if let date = iso8601.date(from: dateString) {
                    return date
                }

                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
            }

            let data = try await supabase
                .from("patient_series_samples")
                .select("value, timestamp")
                .eq("patient_id", value: patientId)
                .eq("series_type", value: "heart_rate_series")
                .gte("timestamp", value: formatter.string(from: startOfToday))
                .order("timestamp", ascending: false)
                .execute()
                .data

            let results = try decoder.decode([SeriesResult].self, from: data)

            if !results.isEmpty {
                let values = results.map { $0.value }
                minValue = values.min()
                maxValue = values.max()
            }
        } catch {
            print("❌ HRCardLoader error: \(error)")
        }
    }
}

/// Wrapper to route to HeartRateView
struct HeartRateFullView: View {
    let color: Color

    var body: some View {
        HeartRateView(color: color)
    }
}

#Preview {
    HeartRateCard(color: .red, pillar: "Core Care")
        .padding()
}
