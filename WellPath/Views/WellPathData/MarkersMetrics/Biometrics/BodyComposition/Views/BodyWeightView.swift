//
//  BodyWeightView.swift
//  WellPath
//
//  Full detail view for Body Weight biometric
//  Shows current value with unit toggle, trend chart, and educational content
//

import SwiftUI

struct BodyWeightView: View {
    let color: Color

    @StateObject private var dataLoader = BiometricValueLoader()
    @State private var showAboutModal = false
    @State private var showAddEntry = false
    @State private var showDataManagement = false
    @State private var selectedUnit: WeightDisplayUnit = .lb

    private let metricId = "DISP_BODYWEIGHT"
    private let metricName = "Body Weight"
    private let icon = "scalemass"

    // Computed display value based on selected unit
    private var displayValue: Double? {
        guard let rawValue = dataLoader.rawValue else { return nil }

        // rawValue is in kg, convert based on selected unit
        switch selectedUnit {
        case .kg:
            return rawValue
        case .lb:
            return rawValue * 2.2046
        }
    }

    private var displayUnit: String {
        selectedUnit.rawValue
    }

    var body: some View {
        mainContentView
            .metricScreenBackground(color: color)
        .navigationTitle("Body Weight")
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
            BodyWeightEntryView()
        }
        .sheet(isPresented: $showDataManagement) {
            BodyWeightDataManagementView(color: color)
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
            selectedUnit = dataLoader.preferredWeightUnit
        }
    }

    private var mainContentView: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 24) {
                    currentValueCard
                    trendChartCard
                }
                .padding(.vertical)
            }

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
                    }
                } else {
                    Text("No data")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }

            // Unit toggle picker - aligned right
            HStack {
                Spacer()
                Picker("Unit", selection: $selectedUnit) {
                    Text("lb").tag(WeightDisplayUnit.lb)
                    Text("kg").tag(WeightDisplayUnit.kg)
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
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

    private var trendChartCard: some View {
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

    private func formatValue(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f", value)
        } else if value >= 10 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
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
        BodyWeightView(color: .cyan)
    }
}
