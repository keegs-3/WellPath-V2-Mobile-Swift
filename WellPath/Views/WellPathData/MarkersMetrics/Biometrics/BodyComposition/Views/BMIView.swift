//
//  BMIView.swift
//  WellPath
//
//  Full detail view for BMI (Body Mass Index) biometric
//  BMI is calculated from height and weight, not directly entered
//

import SwiftUI

struct BMIView: View {
    let color: Color

    @StateObject private var dataLoader = BiometricValueLoader()
    @State private var showAboutModal = false
    @State private var showDataManagement = false
    @State private var showAddEntry = false

    private let metricId = "DISP_BMI"
    private let metricName = "BMI"
    private let icon = "figure.stand"

    var body: some View {
        mainContentView
        .background(biometricBackground)
        .navigationTitle("BMI")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
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
        .sheet(isPresented: $showAddEntry) {
            BMIEntryView()
        }
        .sheet(isPresented: $showDataManagement) {
            BMIDataManagementView(color: color)
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
            await dataLoader.loadValue(for: metricId)
        }
    }

    private var biometricBackground: some View {
        Color.clear
            .metricScreenBackground(color: color)
    }

    private var mainContentView: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 24) {
                    currentValueCard
                    classificationCard
                    trendChartCard
                }
                .padding(.vertical)
            }

            Button(action: { showAboutModal = true }) {
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
                } else if let value = dataLoader.currentValue {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.1f", value))
                                .font(.system(size: 44, weight: .bold))
                                .foregroundColor(.primary)
                            Text("kg/m²")
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

            Text("Calculated from your height and weight")
                .font(.caption)
                .foregroundColor(.secondary)

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

            if let value = dataLoader.currentValue {
                let (classification, classificationColor) = classifyBMI(value)
                HStack {
                    Circle()
                        .fill(classificationColor)
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
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .frame(height: 200)
                .overlay(Text("Chart coming soon").foregroundColor(.secondary))
        }
        .padding(.horizontal)
    }

    private func classifyBMI(_ value: Double) -> (String, Color) {
        if value < 18.5 {
            return ("Underweight", .blue)
        } else if value < 25 {
            return ("Normal", .green)
        } else if value < 30 {
            return ("Overweight", .orange)
        } else {
            return ("Obese", .red)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        BMIView(color: .cyan)
    }
}
