//
//  BiometricFullView.swift
//  WellPath
//
//  Full detail view for biometric metrics
//  Shows current value, trend chart, and educational content
//

import SwiftUI

struct BiometricFullView: View {
    let metric: DisplayMetric
    let color: Color
    let icon: String

    @StateObject private var dataLoader = BiometricValueLoader()
    @State private var showAboutModal = false
    @State private var showAddEntry = false
    @State private var showDataManagement = false
    @State private var selectedWeightUnit: WeightDisplayUnit = .lb
    @State private var selectedLengthUnit: HeightDisplayUnit2 = .ftIn

    private var isLineChart: Bool {
        metric.chartTypeId == "trend_line"
    }

    // Check if this metric supports manual entry
    private var supportsManualEntry: Bool {
        ["DISP_BODYWEIGHT", "DISP_BLOOD_PRESSURE", "DISP_WAIST_CIRCUMFERENCE", "DISP_HIP_CIRCUMFERENCE", "DISP_WAIST_HIP", "DISP_BODYFAT", "DISP_GRIP_STRENGTH", "DISP_VISCERAL_FAT", "DISP_ASMI", "DISP_BMI", "DISP_HRV", "DISP_VO2_MAX", "DISP_RESTING_HR"].contains(metric.metricId)
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
        case bodyFat
        case gripStrength
        case visceralFat
        case asmi
        case bmi
        case hrv
        case vo2Max
        case restingHR
    }

    private var entryType: BiometricEntryType? {
        switch metric.metricId {
        case "DISP_BODYWEIGHT":
            return .bodyWeight
        case "DISP_BLOOD_PRESSURE":
            return .bloodPressure
        case "DISP_WAIST_CIRCUMFERENCE", "DISP_HIP_CIRCUMFERENCE", "DISP_WAIST_HIP":
            return .waistHip
        case "DISP_BODYFAT":
            return .bodyFat
        case "DISP_GRIP_STRENGTH":
            return .gripStrength
        case "DISP_VISCERAL_FAT":
            return .visceralFat
        case "DISP_ASMI":
            return .asmi
        case "DISP_BMI":
            return .bmi
        case "DISP_HRV":
            return .hrv
        case "DISP_VO2_MAX":
            return .vo2Max
        case "DISP_RESTING_HR":
            return .restingHR
        default:
            return nil
        }
    }

    // Computed display value based on selected unit
    // Uses rawValue + rawUnit and converts based on user's selected toggle
    private var displayValue: Double? {
        guard let rawValue = dataLoader.rawValue else { return nil }
        let rawUnit = (dataLoader.rawUnit ?? "").lowercased()

        if supportsWeightToggle {
            // Check source unit and convert appropriately
            let sourceIsKg = rawUnit.contains("kg") || rawUnit.contains("kilogram")
            let sourceIsLb = rawUnit.contains("lb") || rawUnit.contains("pound")

            switch selectedWeightUnit {
            case .kg:
                if sourceIsKg { return rawValue }
                if sourceIsLb { return rawValue * 0.453592 }  // lb to kg
                return rawValue
            case .lb:
                if sourceIsLb { return rawValue }
                if sourceIsKg { return rawValue * 2.2046 }  // kg to lb
                return rawValue
            }
        } else if supportsLengthToggle {
            // Check source unit and convert appropriately
            let sourceIsCm = rawUnit.contains("cm") || rawUnit.contains("centimeter")
            let sourceIsIn = rawUnit.contains("in") || rawUnit.contains("inch")

            switch selectedLengthUnit {
            case .cm:
                if sourceIsCm { return rawValue }
                if sourceIsIn { return rawValue * 2.54 }  // in to cm
                return rawValue
            case .ftIn:
                if sourceIsIn { return rawValue }
                if sourceIsCm { return rawValue / 2.54 }  // cm to in
                return rawValue
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

    @ViewBuilder
    private var dataManagementView: some View {
        switch metric.metricId {
        case "DISP_BODYWEIGHT":
            // Use dedicated BodyWeightDataManagementView which properly handles unit display
            BodyWeightDataManagementView(color: color)
        case "DISP_BLOOD_PRESSURE":
            SimpleBiometricDataManagementView(
                title: "Blood Pressure",
                biometricName: BiometricDisplayNames.displayName(for: metric.metricId),
                unit: "mmHg",
                color: color
            )
        case "DISP_WAIST_CIRCUMFERENCE":
            SimpleBiometricDataManagementView(
                title: "Waist Circumference",
                biometricName: BiometricDisplayNames.displayName(for: metric.metricId),
                unit: "cm",
                color: color
            )
        case "DISP_HIP_CIRCUMFERENCE":
            SimpleBiometricDataManagementView(
                title: "Hip Circumference",
                biometricName: BiometricDisplayNames.displayName(for: metric.metricId),
                unit: "cm",
                color: color
            )
        case "DISP_WAIST_HIP":
            SimpleBiometricDataManagementView(
                title: "Waist-to-Hip Ratio",
                biometricName: BiometricDisplayNames.displayName(for: metric.metricId),
                unit: "",
                color: color
            )
        case "DISP_BODYFAT":
            SimpleBiometricDataManagementView(
                title: "Body Fat",
                biometricName: BiometricDisplayNames.displayName(for: metric.metricId),
                unit: "%",
                color: color
            )
        case "DISP_GRIP_STRENGTH":
            SimpleBiometricDataManagementView(
                title: "Grip Strength",
                biometricName: BiometricDisplayNames.displayName(for: metric.metricId),
                unit: "kg",
                color: color
            )
        case "DISP_VISCERAL_FAT":
            SimpleBiometricDataManagementView(
                title: "Visceral Fat",
                biometricName: BiometricDisplayNames.displayName(for: metric.metricId),
                unit: "%",
                color: color
            )
        case "DISP_ASMI":
            SimpleBiometricDataManagementView(
                title: "ASMI",
                biometricName: BiometricDisplayNames.displayName(for: metric.metricId),
                unit: "kg/m²",
                color: color
            )
        case "DISP_BMI":
            SimpleBiometricDataManagementView(
                title: "BMI",
                biometricName: BiometricDisplayNames.displayName(for: metric.metricId),
                unit: "kg/m²",
                color: color
            )
        case "DISP_HRV":
            HRVDataManagementView(color: color)
        case "DISP_VO2_MAX":
            SimpleBiometricDataManagementView(
                title: "VO2 Max",
                biometricName: BiometricDisplayNames.displayName(for: metric.metricId),
                unit: "mL/kg/min",
                color: color
            )
        case "DISP_RESTING_HR":
            SimpleBiometricDataManagementView(
                title: "Resting Heart Rate",
                biometricName: BiometricDisplayNames.displayName(for: metric.metricId),
                unit: "bpm",
                color: color
            )
        default:
            SimpleBiometricDataManagementView(
                title: metric.metricName,
                biometricName: BiometricDisplayNames.displayName(for: metric.metricId),
                unit: "",
                color: color
            )
        }
    }

    var body: some View {
        Group {
            if isLineChart {
                lineChartView
            } else {
                currentValueChartView
            }
        }
        .metricScreenBackground(color: color)
        .toolbar {
            if supportsManualEntry {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showDataManagement = true
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                }
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Use .biometric type to match BiometricMetricCard's favorite
                FavoriteButton(
                    itemType: .biometric,
                    itemId: metric.metricId,
                    displayName: metric.metricName,
                    pillar: metric.pillar ?? "Biometrics",
                    cardId: metric.metricId,
                    sectionId: "NAV_BIOMETRICS"
                )

                if supportsManualEntry {
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
            case .bodyFat:
                BodyFatEntryView()
            case .gripStrength:
                GripStrengthEntryView()
            case .visceralFat:
                VisceralFatEntryView()
            case .asmi:
                ASMIEntryView()
            case .bmi:
                BMIEntryView()
            case .hrv:
                HRVEntryView()
            case .vo2Max:
                VO2MaxEntryView()
            case .restingHR:
                RestingHREntryView()
            case .none:
                EmptyView()
            }
        }
        .sheet(isPresented: $showDataManagement) {
            dataManagementView
        }
        .sheet(isPresented: $showAboutModal) {
            MetricEducationModal(
                viewId: metric.metricId,
                metricName: metric.metricName,
                color: color,
                isPresented: $showAboutModal
            )
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
        BiometricLineChart(
            metric: metric,
            color: color,
            showAbout: $showAboutModal
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
                showAboutModal = true
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

// Preview requires real DisplayMetric from database query
#Preview {
    NavigationStack {
        Text("BiometricFullView Preview")
    }
}
