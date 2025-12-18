//
//  BiometricMetricCard.swift
//  WellPath
//
//  Reusable metric card wrapper for biometrics
//  Uses MetricCardView with BiometricMiniCard and routes to custom views where needed
//

import SwiftUI

struct BiometricMetricCard: View {
    let metric: DisplayMetric
    let color: Color
    let pillar: String

    private var icon: String {
        MetricsUIConfig.getIcon(for: metric.metricName, viewId: metric.metricId)
    }

    var body: some View {
        MetricCardView(
            title: metric.metricName,
            color: color,
            metricId: metric.metricId,
            pillar: pillar,
            cardId: metric.metricId,
            sectionId: "NAV_BIOMETRICS",
            itemType: .biometric
        ) {
            miniCardView
        } fullScreen: {
            fullScreenView
        }
    }

    /// Routes to custom mini cards for metrics with special display (e.g., blood pressure shows sys/dia)
    @ViewBuilder
    private var miniCardView: some View {
        switch metric.metricId {
        case "DISP_BLOOD_PRESSURE":
            BloodPressureMiniCard(color: color)
        case "DISP_HEART_RATE":
            HeartRateMiniCard(color: color)
        default:
            BiometricMiniCard(metric: metric, color: color, icon: icon)
        }
    }

    /// Routes to specific views for each biometric - unified with ViewRouter
    @ViewBuilder
    private var fullScreenView: some View {
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
            WaistHipView(color: color)
        case "DISP_ASMI":
            ASMIView(color: color)
        // Vitals
        case "DISP_BLOOD_PRESSURE", "DISP_SYSTOLIC_BP":
            BloodPressureView(color: color)
        case "DISP_HEART_RATE":
            HeartRateView(color: color)
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
            // Fallback for any new biometrics not yet mapped
            Text("View not implemented: \(metric.metricId)")
                .foregroundColor(.secondary)
        }
    }
}

// Preview requires real DisplayMetric from database query
#Preview {
    Text("BiometricMetricCard Preview")
}
