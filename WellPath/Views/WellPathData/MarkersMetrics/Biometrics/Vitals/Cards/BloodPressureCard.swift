//
//  BloodPressureCard.swift
//  WellPath
//
//  Individual card for Blood Pressure
//

import SwiftUI

struct BloodPressureCard: View {
    let color: Color
    let pillar: String

    var body: some View {
        MetricCardView(
            title: "Blood Pressure",
            color: color,
            metricId: "DISP_BLOOD_PRESSURE",
            pillar: pillar,
            cardId: "DISP_BLOOD_PRESSURE",
            sectionId: "NAV_BIOMETRICS",
            itemType: .biometric
        ) {
            BloodPressureMiniCard(color: color)
        } fullScreen: {
            BloodPressureFullView(color: color)
        }
    }
}

struct BloodPressureMiniCard: View {
    let color: Color
    @StateObject private var loader = BPCardLoader()

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
                } else if let systolic = loader.systolic, let diastolic = loader.diastolic {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(systolic))/\(Int(diastolic))")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    if let date = loader.lastDate {
                        Text(formatDate(date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .task {
            await loader.loadLatest()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

/// Loads latest blood pressure from patient_correlation_samples
@MainActor
class BPCardLoader: ObservableObject {
    @Published var systolic: Double?
    @Published var diastolic: Double?
    @Published var lastDate: Date?
    @Published var isLoading = false

    private let supabase = SupabaseManager.shared.client

    func loadLatest() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let patientId = try await supabase.auth.session.user.id

            let results: [CorrelationSampleRead] = try await supabase
                .from("patient_correlation_samples")
                .select("id, patient_id, correlation_type, components, sample_time, source, user_timezone")
                .eq("patient_id", value: patientId)
                .eq("correlation_type", value: CorrelationTypes.bloodPressure)
                .order("sample_time", ascending: false)
                .limit(1)
                .execute()
                .value

            if let reading = results.first {
                systolic = reading.systolic
                diastolic = reading.diastolic
                lastDate = reading.sampleTime
            }
        } catch {
            print("❌ BPCardLoader error: \(error)")
        }
    }
}

/// Wrapper to route to BloodPressureView
struct BloodPressureFullView: View {
    let color: Color

    var body: some View {
        BloodPressureView(color: color)
    }
}

#Preview {
    BloodPressureCard(color: .red, pillar: "Core Care")
        .padding()
}
