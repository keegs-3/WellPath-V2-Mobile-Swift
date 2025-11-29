//
//  BiometricsScreen.swift
//  WellPath
//
//  Card-based layout for Biometrics
//  Shows all biometric metrics as tappable mini cards
//

import SwiftUI

struct BiometricsScreen: View {
    let pillar: String
    let color: Color

    @StateObject private var viewModel = BiometricsPrimaryViewModel()

    private var screenIcon: String {
        MetricsUIConfig.getIcon(for: "Biometrics")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if viewModel.isLoading {
                    ProgressView("Loading biometrics...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if let error = viewModel.error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Unable to load biometrics")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if viewModel.biometricMetrics.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No biometrics configured")
                            .font(.headline)
                        Text("Contact support if this issue persists")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 40)
                } else {
                    // Body Composition Section
                    if hasBodyCompositionMetrics {
                        sectionHeader("Body Composition")

                        if let metric = viewModel.weightMetric {
                            BiometricMetricCard(
                                metric: metric,
                                color: color,
                                pillar: pillar
                            )
                        }

                        if let metric = viewModel.bmiMetric {
                            BiometricMetricCard(
                                metric: metric,
                                color: color,
                                pillar: pillar
                            )
                        }

                        if let metric = viewModel.bodyFatMetric {
                            BiometricMetricCard(
                                metric: metric,
                                color: color,
                                pillar: pillar
                            )
                        }

                        if let metric = viewModel.visceralFatMetric {
                            BiometricMetricCard(
                                metric: metric,
                                color: color,
                                pillar: pillar
                            )
                        }

                        if let metric = viewModel.waistCircumferenceMetric {
                            BiometricMetricCard(
                                metric: metric,
                                color: color,
                                pillar: pillar
                            )
                        }

                        if let metric = viewModel.hipCircumferenceMetric {
                            BiometricMetricCard(
                                metric: metric,
                                color: color,
                                pillar: pillar
                            )
                        }

                        if let metric = viewModel.waistHipMetric {
                            BiometricMetricCard(
                                metric: metric,
                                color: color,
                                pillar: pillar
                            )
                        }

                        if let metric = viewModel.smmFfmMetric {
                            BiometricMetricCard(
                                metric: metric,
                                color: color,
                                pillar: pillar
                            )
                        }
                    }

                    // Cardiovascular Section
                    if hasCardiovascularMetrics {
                        sectionHeader("Cardiovascular")

                        if let metric = viewModel.bloodPressureMetric {
                            BiometricMetricCard(
                                metric: metric,
                                color: color,
                                pillar: pillar
                            )
                        }

                        if let metric = viewModel.restingHrMetric {
                            BiometricMetricCard(
                                metric: metric,
                                color: color,
                                pillar: pillar
                            )
                        }

                        if let metric = viewModel.hrvMetric {
                            BiometricMetricCard(
                                metric: metric,
                                color: color,
                                pillar: pillar
                            )
                        }

                        if let metric = viewModel.vo2MaxMetric {
                            BiometricMetricCard(
                                metric: metric,
                                color: color,
                                pillar: pillar
                            )
                        }
                    }

                    // Strength Section
                    if hasStrengthMetrics {
                        sectionHeader("Strength")

                        if let metric = viewModel.gripStrengthMetric {
                            BiometricMetricCard(
                                metric: metric,
                                color: color,
                                pillar: pillar
                            )
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 24)
        }
        .background(
            ZStack {
                // Base background that extends to bottom
                Color(uiColor: .systemGroupedBackground)

                // Gradient overlay at top
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [color.opacity(0.65), color.opacity(0.45), color.opacity(0.25), color.opacity(0.1), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 900)
                    Spacer()
                }

                // Watermark icon
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: screenIcon)
                            .font(.system(size: 200))
                            .foregroundStyle(Color.white.opacity(0.2))
                            .rotationEffect(.degrees(-15))
                            .offset(x: 50, y: -50)
                    }
                    Spacer()
                }
            }
            .ignoresSafeArea()
        )
        .navigationTitle("Biometrics")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadPrimaryScreen()
        }
    }

    private var hasBodyCompositionMetrics: Bool {
        viewModel.weightMetric != nil ||
        viewModel.bmiMetric != nil ||
        viewModel.bodyFatMetric != nil ||
        viewModel.visceralFatMetric != nil ||
        viewModel.waistCircumferenceMetric != nil ||
        viewModel.hipCircumferenceMetric != nil ||
        viewModel.waistHipMetric != nil ||
        viewModel.smmFfmMetric != nil
    }

    private var hasCardiovascularMetrics: Bool {
        viewModel.bloodPressureMetric != nil ||
        viewModel.restingHrMetric != nil ||
        viewModel.hrvMetric != nil ||
        viewModel.vo2MaxMetric != nil
    }

    private var hasStrengthMetrics: Bool {
        viewModel.gripStrengthMetric != nil
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - Biometric Metric Card

struct BiometricMetricCard: View {
    let metric: DisplayMetric
    let color: Color
    let pillar: String

    private var icon: String {
        MetricsUIConfig.getIcon(for: metric.metricName)
    }

    var body: some View {
        MetricCardView(
            title: metric.metricName,
            color: color,
            metricId: metric.metricId,
            pillar: pillar
        ) {
            BiometricMiniCard(metric: metric, color: color, icon: icon)
        } fullScreen: {
            BiometricFullView(metric: metric, color: color, icon: icon)
        }
    }
}

// MARK: - Biometric Mini Card

struct BiometricMiniCard: View {
    let metric: DisplayMetric
    let color: Color
    let icon: String

    @StateObject private var dataLoader = BiometricValueLoader()

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }

            // Value and description
            VStack(alignment: .leading, spacing: 4) {
                if dataLoader.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if let value = dataLoader.currentValue {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(formatValue(value))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        if let unit = dataLoader.unit {
                            Text(unit)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("No data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let description = metric.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Status indicator if we have a value
            if dataLoader.currentValue != nil {
                statusIndicator
            }
        }
        .task {
            await dataLoader.loadValue(for: metric.metricId)
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if let status = dataLoader.status {
            VStack(alignment: .trailing, spacing: 2) {
                Circle()
                    .fill(statusColor(status))
                    .frame(width: 10, height: 10)
                Text(status)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "optimal", "normal", "good":
            return .green
        case "at risk", "borderline", "elevated":
            return .orange
        case "high risk", "high", "low":
            return .red
        default:
            return .gray
        }
    }

    private func formatValue(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f", value)
        } else if value >= 10 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

// MARK: - Biometric Full View

struct BiometricFullView: View {
    let metric: DisplayMetric
    let color: Color
    let icon: String

    @StateObject private var dataLoader = BiometricValueLoader()
    @State private var showAbout = false
    @State private var showAddEntry = false
    @State private var showDataManagement = false
    @State private var selectedWeightUnit: WeightDisplayUnit = .lb
    @State private var selectedLengthUnit: HeightDisplayUnit2 = .ftIn

    private var isLineChart: Bool {
        metric.chartTypeId == "trend_line"
    }

    // Check if this metric supports manual entry
    private var supportsManualEntry: Bool {
        ["DISP_BODYWEIGHT", "DISP_BLOOD_PRESSURE", "DISP_WAIST_CIRCUMFERENCE", "DISP_HIP_CIRCUMFERENCE", "DISP_WAIST_HIP"].contains(metric.metricId)
    }

    // Check if this metric supports unit toggle
    private var supportsWeightToggle: Bool {
        metric.metricId == "DISP_BODYWEIGHT"
    }

    private var supportsLengthToggle: Bool {
        ["DISP_WAIST_CIRCUMFERENCE", "DISP_HIP_CIRCUMFERENCE"].contains(metric.metricId)
    }

    // Entry type for presenting the correct entry view
    private enum BiometricEntryType {
        case bodyWeight
        case bloodPressure
        case waistHip
    }

    private var entryType: BiometricEntryType? {
        switch metric.metricId {
        case "DISP_BODYWEIGHT":
            return .bodyWeight
        case "DISP_BLOOD_PRESSURE":
            return .bloodPressure
        case "DISP_WAIST_CIRCUMFERENCE", "DISP_HIP_CIRCUMFERENCE", "DISP_WAIST_HIP":
            return .waistHip
        default:
            return nil
        }
    }

    // Computed display value based on selected unit
    private var displayValue: Double? {
        guard let rawValue = dataLoader.rawValue else { return nil }

        if supportsWeightToggle {
            // rawValue is in kg, convert based on selected unit
            switch selectedWeightUnit {
            case .kg:
                return rawValue
            case .lb:
                return rawValue * 2.2046
            }
        } else if supportsLengthToggle {
            // rawValue is in cm, convert based on selected unit
            switch selectedLengthUnit {
            case .cm:
                return rawValue
            case .ftIn:
                return rawValue / 2.54  // to inches
            }
        }
        return rawValue
    }

    private var displayUnit: String {
        if supportsWeightToggle {
            return selectedWeightUnit.rawValue
        } else if supportsLengthToggle {
            return selectedLengthUnit == .cm ? "cm" : "in"
        }
        return dataLoader.unit ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            if showAbout {
                aboutContentView
            } else if isLineChart {
                lineChartView
            } else {
                currentValueChartView
            }
        }
        .background(
            ZStack {
                // Base background that extends to bottom
                Color(uiColor: .systemGroupedBackground)

                // Gradient overlay at top
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [color.opacity(0.65), color.opacity(0.45), color.opacity(0.25), color.opacity(0.1), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 900)
                    Spacer()
                }

                // Watermark icon
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: icon)
                            .font(.system(size: 200))
                            .foregroundStyle(Color.white.opacity(0.2))
                            .rotationEffect(.degrees(-15))
                            .offset(x: 50, y: -50)
                    }
                    Spacer()
                }
            }
            .ignoresSafeArea()
        )
        .toolbar {
            if supportsManualEntry {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showDataManagement = true
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddEntry) {
            switch entryType {
            case .bodyWeight:
                BodyWeightEntryView()
            case .bloodPressure:
                BloodPressureEntryView()
            case .waistHip:
                WaistHipEntryView()
            case .none:
                EmptyView()
            }
        }
        .sheet(isPresented: $showDataManagement) {
            MetricDataManagementView(config: .bodyweight(color: color))
        }
        .task {
            if !isLineChart {
                await dataLoader.loadValue(for: metric.metricId)
                // Initialize selected units from user preferences
                selectedWeightUnit = dataLoader.preferredWeightUnit
                selectedLengthUnit = dataLoader.preferredLengthUnit
            }
        }
    }

    private var lineChartView: some View {
        ParentMetricLineChart(
            metric: metric,
            color: color,
            showAbout: $showAbout
        )
    }

    private var currentValueChartView: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 24) {
                    // Current value card
                    currentValueCard

                    // Trend chart placeholder
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Trend")
                            .font(.headline)

                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            .frame(height: 200)
                            .overlay(
                                Text("Chart coming soon")
                                    .foregroundColor(.secondary)
                            )
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .padding(.top, 20)
            }

            // About button
            Button(action: {
                withAnimation {
                    showAbout = true
                }
            }) {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundColor(color)
            }
            .padding(.top, 8)
            .padding(.trailing, 16)
        }
    }

    private var currentValueCard: some View {
        VStack(spacing: 16) {
            // Large value display
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
                } else if let value = displayValue {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatValue(value))
                                .font(.system(size: 44, weight: .bold))
                                .foregroundColor(.primary)
                            Text(displayUnit)
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        if let status = dataLoader.status {
                            Text(status)
                                .font(.subheadline)
                                .foregroundColor(statusColor(status))
                        }
                    }
                } else {
                    Text("No data")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }

            // Unit toggle picker
            if supportsWeightToggle {
                Picker("Unit", selection: $selectedWeightUnit) {
                    Text("lb").tag(WeightDisplayUnit.lb)
                    Text("kg").tag(WeightDisplayUnit.kg)
                }
                .pickerStyle(.segmented)
            } else if supportsLengthToggle {
                Picker("Unit", selection: $selectedLengthUnit) {
                    Text("in").tag(HeightDisplayUnit2.ftIn)
                    Text("cm").tag(HeightDisplayUnit2.cm)
                }
                .pickerStyle(.segmented)
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

    private var aboutContentView: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 24) {
                    if let about = metric.aboutContent {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(color)
                                Text("About")
                                    .font(.headline)
                            }
                            Text(about)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let impact = metric.longevityImpact {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: "heart.circle.fill")
                                    .foregroundColor(color)
                                Text("Health Impact")
                                    .font(.headline)
                            }
                            Text(impact)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let tips = metric.quickTips, !tips.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "lightbulb.circle.fill")
                                    .foregroundColor(color)
                                Text("Quick Tips")
                                    .font(.headline)
                            }

                            ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1).")
                                        .fontWeight(.semibold)
                                        .foregroundColor(color)
                                    Text(tip)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding()
                .padding(.top, 40)
            }

            Button(action: {
                withAnimation {
                    showAbout = false
                }
            }) {
                Image(systemName: "chart.bar")
                    .font(.title3)
                    .foregroundColor(color)
            }
            .padding(.top, 8)
            .padding(.trailing, 16)
        }
    }

    private func formatValue(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f", value)
        } else if value >= 10 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "optimal", "normal", "good":
            return .green
        case "at risk", "borderline", "elevated":
            return .orange
        case "high risk", "high", "low":
            return .red
        default:
            return .gray
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Biometric Value Loader

@MainActor
class BiometricValueLoader: ObservableObject {
    @Published var currentValue: Double?  // Converted to user preference
    @Published var rawValue: Double?       // Raw canonical value (kg, cm)
    @Published var rawUnit: String?        // Canonical unit from DB
    @Published var unit: String?           // Display unit (converted)
    @Published var status: String?
    @Published var lastUpdated: Date?
    @Published var isLoading = false
    @Published var preferredWeightUnit: WeightDisplayUnit = .lb
    @Published var preferredLengthUnit: HeightDisplayUnit2 = .ftIn

    private let supabase = SupabaseManager.shared.client
    private let unitService = UnitConversionService.shared

    // Map display metric IDs to biometric names in patient_biometric_readings
    private let metricToBiometricName: [String: String] = [
        "DISP_BMI": "BMI",
        "DISP_BODYFAT": "Bodyfat (%)",
        "DISP_BODYWEIGHT": "Bodyweight",
        "DISP_GRIP_STRENGTH": "Grip Strength",
        "DISP_HRV": "HRV",
        "DISP_SMM_FFM": "SMM/FFM Ratio",
        "DISP_RESTING_HR": "Resting Heart Rate",
        "DISP_VISCERAL_FAT": "Visceral Fat",
        "DISP_VO2_MAX": "VO2 Max",
        "DISP_WAIST_HIP": "Waist-to-Hip Ratio",
        "DISP_BLOOD_PRESSURE": "Systolic Blood Pressure",
        "DISP_WAIST_CIRCUMFERENCE": "Waist Circumference",
        "DISP_HIP_CIRCUMFERENCE": "Hip Circumference"
    ]

    // Metrics that use weight units
    private let weightMetrics: Set<String> = ["DISP_BODYWEIGHT"]

    // Metrics that use length units
    private let lengthMetrics: Set<String> = ["DISP_WAIST_CIRCUMFERENCE", "DISP_HIP_CIRCUMFERENCE"]

    func loadValue(for metricId: String) async {
        guard let biometricName = metricToBiometricName[metricId] else {
            print("⚠️ No biometric mapping for \(metricId)")
            return
        }

        isLoading = true

        // Load user preferences first
        await unitService.loadUserPreferences()

        do {
            let patientId = try await supabase.auth.session.user.id

            struct BiometricReading: Codable {
                let value: Double
                let unit: String?
                let recordedAt: Date

                enum CodingKeys: String, CodingKey {
                    case value
                    case unit
                    case recordedAt = "recorded_at"
                }
            }

            let results: [BiometricReading] = try await supabase
                .from("patient_biometric_readings")
                .select("value, unit, recorded_at")
                .eq("patient_id", value: patientId)
                .eq("biometric_name", value: biometricName)
                .order("recorded_at", ascending: false)
                .limit(1)
                .execute()
                .value

            if let reading = results.first {
                // Store raw canonical value
                rawValue = reading.value
                rawUnit = reading.unit

                // Store user's preferred units
                preferredWeightUnit = unitService.preferredWeightUnit
                preferredLengthUnit = unitService.preferredHeightUnit

                // Convert to user's preferred unit for default display
                if weightMetrics.contains(metricId) {
                    let converted = unitService.convertWeightToPreferred(value: reading.value, fromUnit: reading.unit)
                    currentValue = converted.value
                    unit = converted.unit
                } else if lengthMetrics.contains(metricId) {
                    let converted = unitService.convertLengthToPreferred(value: reading.value, fromUnit: reading.unit)
                    currentValue = converted.value
                    unit = converted.unit
                } else {
                    currentValue = reading.value
                    unit = reading.unit
                }

                status = nil  // Status is computed from ranges, not stored
                lastUpdated = reading.recordedAt
            }

        } catch {
            print("❌ Error loading biometric value: \(error)")
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        BiometricsScreen(pillar: "Core Care", color: .cyan)
    }
}
