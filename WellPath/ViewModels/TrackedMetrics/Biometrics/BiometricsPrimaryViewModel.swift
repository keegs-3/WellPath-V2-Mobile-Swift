//
//  BiometricsPrimaryViewModel.swift
//  WellPath
//
//  ViewModel for loading Biometrics primary screen with all biometric display_metrics
//

import Foundation
import Supabase

/// Combined biometric metric data for display
struct BiometricPrimaryMetric: Identifiable {
    let id: String
    let metric: DisplayMetric

    var displayName: String {
        metric.metricName
    }

    var displayDescription: String? {
        metric.description
    }

    var chartType: String? {
        metric.chartTypeId
    }
}

@MainActor
class BiometricsPrimaryViewModel: ObservableObject {
    @Published var biometricMetrics: [BiometricPrimaryMetric] = []
    @Published var isLoading = false
    @Published var error: String?

    // Individual metric references for card titles
    @Published var bmiMetric: DisplayMetric?
    @Published var bodyFatMetric: DisplayMetric?
    @Published var gripStrengthMetric: DisplayMetric?
    @Published var hrvMetric: DisplayMetric?
    @Published var smmFfmMetric: DisplayMetric?
    @Published var restingHrMetric: DisplayMetric?
    @Published var visceralFatMetric: DisplayMetric?
    @Published var vo2MaxMetric: DisplayMetric?
    @Published var waistHipMetric: DisplayMetric?
    @Published var weightMetric: DisplayMetric?
    @Published var bloodPressureMetric: DisplayMetric?
    @Published var waistCircumferenceMetric: DisplayMetric?
    @Published var hipCircumferenceMetric: DisplayMetric?

    private let supabase = SupabaseManager.shared.client

    // Biometric metric IDs we want to display
    private let biometricMetricIds = [
        "DISP_BMI",
        "DISP_BODYFAT",
        "DISP_GRIP_STRENGTH",
        "DISP_HRV",
        "DISP_SMM_FFM",
        "DISP_RESTING_HR",
        "DISP_VISCERAL_FAT",
        "DISP_VO2_MAX",
        "DISP_WAIST_HIP",
        "DISP_BODYWEIGHT",
        "DISP_BLOOD_PRESSURE",
        "DISP_WAIST_CIRCUMFERENCE",
        "DISP_HIP_CIRCUMFERENCE"
    ]

    init() {}

    /// Load all biometric display metrics
    func loadPrimaryScreen() async {
        isLoading = true
        error = nil

        do {
            print("📊 Loading Biometrics primary screen")

            // Query biometric display_metrics
            let results: [DisplayMetric] = try await supabase
                .from("display_metrics")
                .select()
                .in("metric_id", values: biometricMetricIds)
                .eq("is_active", value: true)
                .execute()
                .value

            // Map results to individual metrics
            for metric in results {
                switch metric.metricId {
                case "DISP_BMI":
                    bmiMetric = metric
                case "DISP_BODYFAT":
                    bodyFatMetric = metric
                case "DISP_GRIP_STRENGTH":
                    gripStrengthMetric = metric
                case "DISP_HRV":
                    hrvMetric = metric
                case "DISP_SMM_FFM":
                    smmFfmMetric = metric
                case "DISP_RESTING_HR":
                    restingHrMetric = metric
                case "DISP_VISCERAL_FAT":
                    visceralFatMetric = metric
                case "DISP_VO2_MAX":
                    vo2MaxMetric = metric
                case "DISP_WAIST_HIP":
                    waistHipMetric = metric
                case "DISP_BODYWEIGHT":
                    weightMetric = metric
                case "DISP_BLOOD_PRESSURE":
                    bloodPressureMetric = metric
                case "DISP_WAIST_CIRCUMFERENCE":
                    waistCircumferenceMetric = metric
                case "DISP_HIP_CIRCUMFERENCE":
                    hipCircumferenceMetric = metric
                default:
                    break
                }
            }

            // Create array of metrics for iteration
            biometricMetrics = results.map { BiometricPrimaryMetric(id: $0.metricId, metric: $0) }

            print("✅ Loaded \(biometricMetrics.count) biometric metrics")
            for metric in biometricMetrics {
                print("   - \(metric.displayName)")
            }

        } catch {
            let errorMessage = error.localizedDescription
            self.error = "Failed to load biometrics: \(errorMessage)"
            print("❌ Error loading biometrics: \(error)")
        }

        isLoading = false
    }
}
