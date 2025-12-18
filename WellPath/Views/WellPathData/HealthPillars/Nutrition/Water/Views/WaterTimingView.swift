//
//  WaterTimingView.swift
//  WellPath
//
//  Full view for Water Timing metric (DISP_WATER_TIMING).
//  Shows hydration distribution throughout the day based on actual water intake data.
//

import SwiftUI
import Supabase
import Charts

/// Time window for water intake categorization
enum WaterTimeWindow: String, CaseIterable {
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"

    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        }
    }

    var description: String {
        switch self {
        case .morning: return "6 AM - 12 PM"
        case .afternoon: return "12 PM - 6 PM"
        case .evening: return "6 PM - 10 PM"
        }
    }

    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset.fill"
        }
    }

    var targetPercentage: Double {
        switch self {
        case .morning: return 40
        case .afternoon: return 40
        case .evening: return 20
        }
    }

    /// Determines time window from hour of day
    static func from(hour: Int) -> WaterTimeWindow {
        switch hour {
        case 6..<12: return .morning
        case 12..<18: return .afternoon
        case 18..<22: return .evening
        default:
            // Before 6am or after 10pm -> closest window
            if hour < 6 { return .morning }
            return .evening
        }
    }
}

/// ViewModel for water timing analysis
@MainActor
class WaterTimingViewModel: ObservableObject {
    @Published var timingData: [WaterTimeWindow: Double] = [:]
    @Published var totalIntake: Double = 0
    @Published var isLoading = false
    @Published var hasData = false

    private let supabase = SupabaseManager.shared.client
    let baseColor: Color

    init(color: Color) {
        self.baseColor = color
    }

    func loadData() async {
        isLoading = true

        do {
            let userId = try await supabase.auth.session.user.id

            // Get water samples from the past week
            let calendar = Calendar.current
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let startStr = dateFormatter.string(from: weekAgo)

            struct WaterSample: Codable {
                let startTime: String
                let canonicalValue: Double?

                enum CodingKeys: String, CodingKey {
                    case startTime = "start_time"
                    case canonicalValue = "canonical_value"
                }
            }

            let samples: [WaterSample] = try await supabase
                .from("patient_quantity_samples")
                .select("start_time, canonical_value")
                .eq("patient_id", value: userId)
                .eq("quantity_type", value: "water_ml")
                .gte("start_time", value: startStr)
                .order("start_time", ascending: false)
                .execute()
                .value

            // Group by time window
            var windowTotals: [WaterTimeWindow: Double] = [
                .morning: 0,
                .afternoon: 0,
                .evening: 0
            ]

            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            for sample in samples {
                guard let value = sample.canonicalValue, value > 0 else { continue }

                // Parse the timestamp
                if let date = isoFormatter.date(from: sample.startTime) {
                    let hour = calendar.component(.hour, from: date)
                    let window = WaterTimeWindow.from(hour: hour)
                    windowTotals[window, default: 0] += value
                }
            }

            let total = windowTotals.values.reduce(0, +)

            await MainActor.run {
                self.timingData = windowTotals
                self.totalIntake = total
                self.hasData = total > 0
                self.isLoading = false
            }

        } catch {
            print("Error loading water timing: \(error)")
            await MainActor.run {
                self.isLoading = false
                self.hasData = false
            }
        }
    }

    func percentage(for window: WaterTimeWindow) -> Double {
        guard totalIntake > 0 else { return 0 }
        return ((timingData[window] ?? 0) / totalIntake) * 100
    }

    func color(for window: WaterTimeWindow) -> Color {
        let index = WaterTimeWindow.allCases.firstIndex(of: window) ?? 0
        let opacity = 0.5 + (Double(index) * 0.25)
        return baseColor.opacity(opacity)
    }
}

struct WaterTimingView: View {
    let color: Color

    @StateObject private var viewModel: WaterTimingViewModel
    @StateObject private var unitPrefs = UnitPreferencesViewModel()
    @State private var showAboutModal = false
    @State private var showingEntryForm = false
    @State private var showingDataManagement = false

    private let metricId = "DISP_WATER_TIMING"
    private let metricName = "Hydration Timing"

    init(color: Color) {
        self.color = color
        _viewModel = StateObject(wrappedValue: WaterTimingViewModel(color: color))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(height: 200)
                } else if viewModel.hasData {
                    // Distribution Chart Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Daily Distribution")
                                .font(.headline)
                            Spacer()
                            Button(action: {
                                showAboutModal = true
                            }) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(color)
                            }
                        }

                        Text("Your hydration patterns over the past week")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        // Donut chart
                        Chart {
                            ForEach(WaterTimeWindow.allCases, id: \.self) { window in
                                SectorMark(
                                    angle: .value("Amount", viewModel.timingData[window] ?? 0),
                                    innerRadius: .ratio(0.6),
                                    angularInset: 2
                                )
                                .foregroundStyle(viewModel.color(for: window))
                                .cornerRadius(4)
                            }
                        }
                        .frame(height: 180)
                        .chartBackground { _ in
                            VStack {
                                Text(formatTotal())
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("this week")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Legend with actual percentages
                        VStack(spacing: 12) {
                            ForEach(WaterTimeWindow.allCases, id: \.self) { window in
                                timingRow(
                                    window: window,
                                    actual: viewModel.percentage(for: window),
                                    target: window.targetPercentage
                                )
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    )
                    .padding(.horizontal)

                } else {
                    // No data state
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Daily Distribution")
                                .font(.headline)
                            Spacer()
                            Button(action: {
                                showAboutModal = true
                            }) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(color)
                            }
                        }

                        Text("Track when you drink water to optimize hydration throughout the day.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        // Ideal timing breakdown (static targets)
                        VStack(spacing: 12) {
                            ForEach(WaterTimeWindow.allCases, id: \.self) { window in
                                HStack(alignment: .center, spacing: 12) {
                                    Image(systemName: window.icon)
                                        .font(.system(size: 20))
                                        .foregroundColor(color)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(window.displayName)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Text(window.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Text("Target: \(Int(window.targetPercentage))%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                                )
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    )
                    .padding(.horizontal)

                    // Log water button
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 48))
                            .foregroundColor(color.opacity(0.3))

                        Text("Track water intake to see your hydration patterns")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button(action: {
                            showingEntryForm = true
                        }) {
                            Label("Log Water", systemImage: "plus")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(color)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.vertical, 40)
                }
            }
            .padding(.top)
        }
        .metricScreenBackground(color: color)
        .navigationTitle("Hydration Timing")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingDataManagement = true
                } label: {
                    Image(systemName: "list.bullet")
                }
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                FavoriteButton(
                    itemType: .metric,
                    itemId: "DISP_WATER_TIMING",
                    displayName: "Hydration Timing",
                    pillar: "Healthful Nutrition",
                    cardId: "CARD_WATER_TIMING",
                    sectionId: "NAV_NUTRITION"
                )

                Button {
                    showingEntryForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEntryForm) {
            WaterEntryView()
        }
        .sheet(isPresented: $showingDataManagement) {
            NutritionDataManagementView(color: color, initialCategory: .water)
        }
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(viewId: metricId, metricName: metricName, color: color, isPresented: $showAboutModal)
        }
        .task {
            await unitPrefs.loadPreferences()
            await viewModel.loadData()
        }
    }

    private func formatTotal() -> String {
        let ml = viewModel.totalIntake
        let unit = unitPrefs.liquidUnit
        let value = ml / unit.mlPerUnit

        // Use appropriate decimal places based on value size
        if value >= 100 {
            return String(format: "%.0f %@", value, unit.shortLabel)
        } else if value >= 10 {
            return String(format: "%.1f %@", value, unit.shortLabel)
        } else {
            return String(format: "%.2f %@", value, unit.shortLabel)
        }
    }

    @ViewBuilder
    private func timingRow(window: WaterTimeWindow, actual: Double, target: Double) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(viewModel.color(for: window))
                .frame(width: 12, height: 12)

            Image(systemName: window.icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(window.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(window.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f%%", actual))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(actualVsTargetColor(actual: actual, target: target))
                Text("Target: \(Int(target))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
    }

    private func actualVsTargetColor(actual: Double, target: Double) -> Color {
        let diff = abs(actual - target)
        if diff <= 10 {
            return MetricsUIConfig.tierGood
        } else if diff <= 20 {
            return MetricsUIConfig.tierMedium
        } else {
            return MetricsUIConfig.tierPoor
        }
    }
}

#Preview {
    NavigationStack {
        WaterTimingView(color: .cyan)
    }
}
