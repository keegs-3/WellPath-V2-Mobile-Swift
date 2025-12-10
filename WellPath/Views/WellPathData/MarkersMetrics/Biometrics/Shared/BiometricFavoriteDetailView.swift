//
//  BiometricFavoriteDetailView.swift
//  WellPath
//
//  Detail view for biometric favorites - loads data by name

import SwiftUI

struct BiometricFavoriteDetailView: View {
    let biometricName: String

    @StateObject private var viewModel = MetricsViewModel()
    @Environment(\.dismiss) private var dismiss

    private var biometricData: BiometricCardData? {
        viewModel.biometricCards.first { $0.name == biometricName }
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                VStack {
                    ProgressView("Loading biometric data...")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let data = biometricData {
                BiometricListDetailView(
                    name: data.name,
                    value: data.value,
                    status: data.status,
                    optimalRange: data.optimalRange,
                    trend: data.trend
                )
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Biometric not found")
                        .font(.headline)
                    Text(biometricName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .task {
            await viewModel.loadBiometrics()
        }
    }
}

#Preview {
    NavigationStack {
        BiometricFavoriteDetailView(biometricName: "Resting Heart Rate")
    }
}
