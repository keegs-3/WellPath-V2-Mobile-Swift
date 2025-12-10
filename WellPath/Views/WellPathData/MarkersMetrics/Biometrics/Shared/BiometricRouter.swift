//
//  BiometricRouter.swift
//  WellPath
//
//  Routes to specific biometric views by name
//  Looks up view_id from display_views then routes appropriately
//

import SwiftUI

struct BiometricRouter: View {
    let biometricName: String
    let color: Color

    @State private var viewId: String?
    @State private var displayMetric: DisplayMetric?
    @State private var isLoading = true

    private let supabase = SupabaseManager.shared.client

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let metric = displayMetric {
                routedView(for: metric)
            } else {
                // Fallback if not found
                Text("Biometric not found: \(biometricName)")
                    .foregroundColor(.secondary)
            }
        }
        .task {
            await loadViewId()
        }
    }

    private func loadViewId() async {
        do {
            // Query display_views by name
            let results: [DisplayMetric] = try await supabase
                .from("display_views")
                .select()
                .eq("view_name", value: biometricName)
                .limit(1)
                .execute()
                .value

            await MainActor.run {
                displayMetric = results.first
                viewId = results.first?.metricId
                isLoading = false
            }
        } catch {
            print("❌ BiometricRouter: Error loading view for \(biometricName): \(error)")
            await MainActor.run { isLoading = false }
        }
    }

    @ViewBuilder
    private func routedView(for metric: DisplayMetric) -> some View {
        switch metric.metricId {
        // Body Composition
        case "DISP_BODYFAT":
            BodyFatView(color: color)
        case "DISP_BODYWEIGHT":
            BodyWeightView(color: color)
        case "DISP_BMI":
            BMIView(color: color)
        case "DISP_VISCERAL_FAT":
            VisceralFatView(color: color)
        case "DISP_WAIST_CIRCUMFERENCE":
            WaistCircumferenceView(color: color)
        case "DISP_HIP_CIRCUMFERENCE":
            HipCircumferenceView(color: color)
        case "DISP_WAIST_HIP":
            WaistHipRatioView(color: color)
        case "DISP_ASMI":
            ASMIView(color: color)
        // Vitals
        case "DISP_BLOOD_PRESSURE", "DISP_SYSTOLIC_BP":
            BloodPressureView(color: color)
        case "DISP_HRV":
            HRVView(color: color)
        // Fitness
        case "DISP_RESTING_HR":
            RestingHRView(metric: metric, color: color)
        case "DISP_VO2_MAX":
            VO2MaxView(metric: metric, color: color)
        // Strength
        case "DISP_GRIP_STRENGTH":
            GripStrengthView(color: color)
        default:
            Text("View not implemented: \(metric.metricId)")
                .foregroundColor(.secondary)
        }
    }
}
