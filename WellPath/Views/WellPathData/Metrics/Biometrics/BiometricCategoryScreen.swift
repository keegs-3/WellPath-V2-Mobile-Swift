//
//  BiometricCategoryScreen.swift
//  WellPath
//
//  Shows biometric metrics for a specific category
//

import SwiftUI

enum BiometricCategory: String {
    case bodyComposition = "body_composition"
    case cardiovascular = "cardiovascular"
    case strength = "strength"

    var title: String {
        switch self {
        case .bodyComposition: return "Body Composition"
        case .cardiovascular: return "Cardiovascular"
        case .strength: return "Strength"
        }
    }

    var icon: String {
        switch self {
        case .bodyComposition: return "figure.stand"
        case .cardiovascular: return "heart.fill"
        case .strength: return "dumbbell.fill"
        }
    }

    var metricIds: [String] {
        switch self {
        case .bodyComposition:
            return ["DISP_BODYWEIGHT", "DISP_BMI", "DISP_BODYFAT", "DISP_VISCERAL_FAT",
                    "DISP_WAIST_CIRCUMFERENCE", "DISP_HIP_CIRCUMFERENCE", "DISP_WAIST_HIP", "DISP_SMM_FFM"]
        case .cardiovascular:
            return ["DISP_BLOOD_PRESSURE", "DISP_RESTING_HR", "DISP_HRV", "DISP_VO2_MAX"]
        case .strength:
            return ["DISP_GRIP_STRENGTH"]
        }
    }
}

struct BiometricCategoryScreen: View {
    let category: BiometricCategory
    let pillar: String
    let color: Color

    @StateObject private var viewModel = BiometricsPrimaryViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if viewModel.biometricMetrics.isEmpty {
                    emptyState
                } else {
                    metricsGrid
                }
            }
            .padding()
            .padding(.bottom, 24)
        }
        .background(
            ZStack {
                Color(uiColor: .systemGroupedBackground)

                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [color.opacity(0.65), color.opacity(0.45), color.opacity(0.25), color.opacity(0.1), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 900)
                    Spacer()
                }

                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: category.icon)
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
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadPrimaryScreen()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: category.icon)
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No \(category.title.lowercased()) data")
                .font(.headline)
            Text("Add measurements to see them here")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 40)
    }

    @ViewBuilder
    private var metricsGrid: some View {
        let categoryMetrics = viewModel.biometricMetrics.filter { biometric in
            category.metricIds.contains(biometric.id)
        }

        if categoryMetrics.isEmpty {
            emptyState
        } else {
            ForEach(categoryMetrics) { biometric in
                BiometricMetricCard(metric: biometric.metric, color: color, pillar: pillar)
            }
        }
    }
}

#Preview {
    NavigationStack {
        BiometricCategoryScreen(
            category: .bodyComposition,
            pillar: "Biometrics",
            color: Color(hex: "#66CCFF") ?? .cyan
        )
    }
}
