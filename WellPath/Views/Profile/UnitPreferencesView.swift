//
//  UnitPreferencesView.swift
//  WellPath
//
//  User settings for display unit preferences
//

import SwiftUI

struct UnitPreferencesView: View {
    @StateObject private var viewModel = UnitPreferencesViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showSaveConfirmation = false

    var body: some View {
        Form {
            Section {
                Picker("Weight", selection: $viewModel.weightUnit) {
                    ForEach(WeightDisplayUnit.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }

                Picker("Height", selection: $viewModel.heightUnit) {
                    ForEach(HeightDisplayUnit2.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
            } header: {
                Text("Body Measurements")
            }

            Section {
                Picker("Distance", selection: $viewModel.distanceUnit) {
                    ForEach(DistanceDisplayUnit.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
            } header: {
                Text("Distance")
            }

            Section {
                Picker("Temperature", selection: $viewModel.temperatureUnit) {
                    ForEach(TemperatureDisplayUnit.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
            } header: {
                Text("Temperature")
            }

            Section {
                Picker("Liquids", selection: $viewModel.liquidUnit) {
                    ForEach(LiquidDisplayUnit.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
            } header: {
                Text("Liquids & Hydration")
            }
        }
        .navigationTitle("Unit Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    Task {
                        let success = await viewModel.savePreferences()
                        if success {
                            showSaveConfirmation = true
                        }
                    }
                }
                .disabled(viewModel.isSaving)
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(uiColor: .systemBackground).opacity(0.8))
            }
        }
        .alert("Saved", isPresented: $showSaveConfirmation) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your unit preferences have been updated.")
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK") { }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
        .task {
            await viewModel.loadPreferences()
        }
    }
}

#Preview {
    NavigationStack {
        UnitPreferencesView()
    }
}
