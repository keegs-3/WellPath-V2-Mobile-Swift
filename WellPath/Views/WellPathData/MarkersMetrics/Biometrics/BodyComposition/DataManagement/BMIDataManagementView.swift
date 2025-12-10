//
//  BMIDataManagementView.swift
//  WellPath
//
//  Data management view for BMI entries
//  BMI is calculated from height/weight, so entries are read-only
//

import SwiftUI
import Supabase

struct BMIDataManagementView: View {
    let color: Color

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SimpleBiometricDataViewModel(biometricName: "BMI", unit: "kg/m²")
    @State private var expandedDates: Set<Date> = []

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("All BMI Data")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.primary)
                        }
                    }
                }
                .task {
                    await viewModel.loadData()
                    expandedDates = Set(viewModel.sortedDates)
                }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading {
            ProgressView().padding()
        } else if viewModel.sortedDates.isEmpty {
            Text("No BMI data found")
                .foregroundColor(.secondary)
                .padding()
        } else {
            List {
                ForEach(viewModel.sortedDates, id: \.self) { date in
                    Section {
                        if expandedDates.contains(date) {
                            ForEach(viewModel.entriesByDate[date] ?? []) { entry in
                                SimpleBiometricEntryRow(entry: entry, unit: "kg/m²", formatDecimals: 1)
                            }
                        }
                    } header: {
                        sectionHeader(for: date)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func sectionHeader(for date: Date) -> some View {
        Button(action: {
            withAnimation {
                if expandedDates.contains(date) {
                    expandedDates.remove(date)
                } else {
                    expandedDates.insert(date)
                }
            }
        }) {
            HStack {
                Text(formatSectionDate(date))
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: expandedDates.contains(date) ? "chevron.down" : "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .buttonStyle(.plain)
    }

    private func formatSectionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

#Preview {
    BMIDataManagementView(color: .cyan)
}
