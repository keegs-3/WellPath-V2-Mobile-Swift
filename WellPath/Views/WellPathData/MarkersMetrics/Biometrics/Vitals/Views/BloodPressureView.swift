//
//  BloodPressureView.swift
//  WellPath
//
//  Full detail view for Blood Pressure biometric
//  Shows systolic/diastolic values, classification, trend chart, and educational content
//  Loads title, subtitle, and unit from database
//

import SwiftUI

struct BloodPressureView: View {
    let color: Color

    @StateObject private var dataLoader = BloodPressureDataLoader()
    @State private var showAboutModal = false
    @State private var showAddEntry = false
    @State private var showDataManagement = false
    @State private var metadata: ViewMetadata?

    private let metricId = "DISP_BLOOD_PRESSURE"
    private let icon = "heart.fill"

    // Computed from metadata with fallbacks
    private var metricName: String { metadata?.title ?? "Blood Pressure" }
    private var metricNameLong: String? { metadata?.subtitle }
    private var unitDisplay: String { metadata?.unit ?? "mmHg" }

    var body: some View {
        mainContentView
            .metricScreenBackground(color: color)
            .navigationTitle(metricName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showDataManagement = true
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    FavoriteButton(
                        itemType: .biometric,
                        itemId: metricId,
                        displayName: metricName,
                        pillar: "Biometrics",
                        cardId: metricId,
                        sectionId: "NAV_BIOMETRICS"
                    )
                    Button {
                        showAddEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddEntry) {
                BloodPressureEntryView()
            }
            .sheet(isPresented: $showDataManagement) {
                BloodPressureDataManagementView(color: color)
            }
            .sheet(isPresented: $showAboutModal) {
                MetricEducationModal(
                    viewId: metricId,
                    metricName: metricName,
                    color: color,
                    isPresented: $showAboutModal
                )
            }
            .task {
                await dataLoader.loadLatestReading()
                metadata = await ViewMetadataService.shared.loadMetadata(for: metricId)
            }
    }

    private var mainContentView: some View {
        // Simplified view - just the chart with integrated header
        BloodPressureRangeChart(color: color, showAbout: $showAboutModal)
    }

    private var currentValueCard: some View {
        VStack(spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 60, height: 60)

                    Image(systemName: icon)
                        .font(.title)
                        .foregroundColor(color)
                }

                Spacer()

                if dataLoader.isLoading {
                    ProgressView()
                } else if let systolic = dataLoader.systolicValue, let diastolic = dataLoader.diastolicValue {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(systolic))/\(Int(diastolic))")
                                .font(.system(size: 44, weight: .bold))
                                .foregroundColor(.primary)
                            Text(unitDisplay)
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("No data")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }

            // Last updated
            if let date = dataLoader.lastUpdated {
                HStack {
                    Spacer()
                    Text("Last updated: \(formatDate(date))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private var classificationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Classification")
                .font(.headline)

            if let systolic = dataLoader.systolicValue, let diastolic = dataLoader.diastolicValue {
                let classification = classifyBloodPressure(systolic: Int(systolic), diastolic: Int(diastolic))
                HStack {
                    Circle()
                        .fill(classificationColor(systolic: Int(systolic), diastolic: Int(diastolic)))
                        .frame(width: 12, height: 12)
                    Text(classification)
                        .font(.body)
                        .fontWeight(.medium)
                    Spacer()
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }

    private var trendChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trend")
                .font(.headline)
                .padding(.horizontal)

            BloodPressureRangeChart(color: color)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
        }
    }

    private func classifyBloodPressure(systolic: Int, diastolic: Int) -> String {
        if systolic < 120 && diastolic < 80 {
            return "Normal"
        } else if systolic < 130 && diastolic < 80 {
            return "Elevated"
        } else if systolic < 140 || diastolic < 90 {
            return "High (Stage 1)"
        } else if systolic >= 140 || diastolic >= 90 {
            return "High (Stage 2)"
        } else if systolic > 180 || diastolic > 120 {
            return "Hypertensive Crisis"
        }
        return "Unknown"
    }

    private func classificationColor(systolic: Int, diastolic: Int) -> Color {
        if systolic < 120 && diastolic < 80 {
            return .green
        } else if systolic < 130 && diastolic < 80 {
            return .yellow
        } else {
            return .red
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Blood Pressure Data Loader

@MainActor
class BloodPressureDataLoader: ObservableObject {
    @Published var systolicValue: Double?
    @Published var diastolicValue: Double?
    @Published var lastUpdated: Date?
    @Published var isLoading = false

    private let supabase = SupabaseManager.shared.client

    func loadLatestReading() async {
        isLoading = true

        do {
            let patientId = try await supabase.auth.session.user.id

            // Load latest blood pressure from patient_correlation_samples
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
                systolicValue = reading.systolic
                diastolicValue = reading.diastolic
                lastUpdated = reading.sampleTime
            }

        } catch {
            print("Error loading blood pressure: \(error)")
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        BloodPressureView(color: .red)
    }
}
