//
//  MetricsView.swift
//  WellPath
//
//  Main metrics tab showing Biomarkers and Biometrics cards
//

import SwiftUI

struct MetricsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                // Connected container with both categories
                VStack(spacing: 0) {
                    // Biomarkers Card
                    NavigationLink(destination: BiomarkersList()) {
                        MetricCategoryRow(
                            title: "Biomarkers",
                            subtitle: "Lab test results",
                            icon: "testtube.2",
                            color: Color(red: 0.74, green: 0.56, blue: 0.94) // Purple
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Divider
                    Divider()
                        .background(Color.gray.opacity(0.3))
                        .padding(.horizontal, 16)

                    // Biometrics Card
                    NavigationLink(destination: BiometricsList()) {
                        MetricCategoryRow(
                            title: "Biometrics",
                            subtitle: "Physical measurements",
                            icon: "waveform.path.ecg",
                            color: Color(red: 0.40, green: 0.80, blue: 1.0) // Blue
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .background(
                ZStack {
                    // WellPath gradient background
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [
                                Color(red: 0.56, green: 0.82, blue: 0.31).opacity(0.65),
                                Color(red: 0.56, green: 0.82, blue: 0.31).opacity(0.45),
                                Color(red: 0.56, green: 0.82, blue: 0.31).opacity(0.25),
                                Color(red: 0.56, green: 0.82, blue: 0.31).opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 900)

                        Spacer()
                    }

                    // Large background logo
                    VStack {
                        HStack {
                            Spacer()
                            Image("white_grey")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 180, height: 180)
                                .opacity(0.35)
                                .rotationEffect(.degrees(-15))
                                .offset(x: 40, y: 20)
                        }
                        Spacer()
                    }
                }
                .ignoresSafeArea()
            )
            .navigationTitle("Metrics")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

// Metric category row (matches PillarListRow style)
struct MetricCategoryRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            // Circle filled with lighter category color
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Category-colored chevron
            Image(systemName: "chevron.right")
                .foregroundColor(color)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    MetricsView()
}
