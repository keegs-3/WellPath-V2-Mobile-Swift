//
//  WaterEntryView.swift
//  WellPath
//
//  Entry form for logging water intake to patient_quantity_samples
//

import SwiftUI
import Supabase

struct WaterEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDateTime = Date()
    @State private var waterAmount: String = ""
    @State private var selectedUnit: WaterUnit = .fluidOunce
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingUnitInfo = false

    private let supabase = SupabaseManager.shared.client

    enum WaterUnit: String, CaseIterable {
        case fluidOunce = "fluid_ounce"
        case milliliter = "milliliter"
        case cup = "cup"
        case glass = "glass"
        case liter = "liter"
        case gallon = "gallon_us"

        var displayName: String {
            switch self {
            case .fluidOunce: return "fl oz"
            case .milliliter: return "mL"
            case .cup: return "cups"
            case .glass: return "glasses"
            case .liter: return "L"
            case .gallon: return "gal"
            }
        }

        // Unit ID for database storage (trigger handles conversion to canonical)
        var unitId: String {
            rawValue
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with X button
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .disabled(isSaving)

                Spacer()
            }
            .padding()
            .background(Color(uiColor: .systemBackground))

            // Icon and Title
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.3, green: 0.6, blue: 0.9).opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: "drop.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color(red: 0.3, green: 0.6, blue: 0.9))
                }

                Text("Water")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.top, 8)
            .padding(.bottom, 24)

            Form {
                Section {
                    DatePicker("Date", selection: $selectedDateTime, displayedComponents: [.date])
                    DatePicker("Time", selection: $selectedDateTime, displayedComponents: [.hourAndMinute])
                }

                Section {
                    HStack {
                        TextField("Amount", text: $waterAmount)
                            .keyboardType(.decimalPad)

                        Picker("", selection: $selectedUnit) {
                            ForEach(WaterUnit.allCases, id: \.self) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                    }
                } footer: {
                    Button(action: { showingUnitInfo = true }) {
                        Label("Unit conversions", systemImage: "info.circle")
                            .font(.caption)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }

            // Save button at bottom
            Button(action: {
                Task {
                    await saveWaterEntry()
                }
            }) {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text("Save")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(waterAmount.isEmpty ? Color.gray : Color(red: 0.3, green: 0.6, blue: 0.9))
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
            .disabled(isSaving || waterAmount.isEmpty)
        }
        .sheet(isPresented: $showingUnitInfo) {
            unitInfoSheet
        }
    }

    @ViewBuilder
    private var unitInfoSheet: some View {
        NavigationStack {
            List {
                Section("Common Serving Sizes") {
                    unitRow(icon: "drop.fill", name: "1 glass", detail: "8 fl oz (237 mL)")
                    unitRow(icon: "cup.and.saucer.fill", name: "1 cup", detail: "8 fl oz (237 mL)")
                    unitRow(icon: "waterbottle.fill", name: "Standard bottle", detail: "16.9 fl oz (500 mL)")
                    unitRow(icon: "waterbottle.fill", name: "Large bottle", detail: "33.8 fl oz (1 L)")
                }

                Section("Unit Conversions") {
                    unitRow(icon: "arrow.left.arrow.right", name: "1 fl oz", detail: "29.6 mL")
                    unitRow(icon: "arrow.left.arrow.right", name: "1 cup", detail: "237 mL")
                    unitRow(icon: "arrow.left.arrow.right", name: "1 liter", detail: "33.8 fl oz")
                    unitRow(icon: "arrow.left.arrow.right", name: "1 gallon", detail: "3.79 L / 128 fl oz")
                }

                Section("Daily Hydration Goal") {
                    unitRow(icon: "target", name: "Recommended", detail: "8 glasses (64 fl oz / ~2 L)")
                }
            }
            .navigationTitle("Water Units")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingUnitInfo = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private func unitRow(icon: String, name: String, detail: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color(red: 0.3, green: 0.6, blue: 0.9))
                .frame(width: 24)
            Text(name)
            Spacer()
            Text(detail)
                .foregroundColor(.secondary)
        }
    }

    private func saveWaterEntry() async {
        guard let amountValue = Double(waterAmount), amountValue > 0 else {
            errorMessage = "Please enter a valid amount"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            let userId = try await supabase.auth.session.user.id
            let deviceTimezone = TimeZone.current.identifier

            let sample = QuantitySampleWrite.create(
                patientId: userId,
                quantityType: QuantityTypes.waterMl,
                value: amountValue,
                unit: selectedUnit.unitId,
                timestamp: selectedDateTime,
                source: .wellpathInput,
                timezone: deviceTimezone,
                metadata: [:],
                eventInstanceId: UUID()
            )

            try await supabase
                .from("patient_quantity_samples")
                .insert(sample)
                .execute()

            // Note: Hydration scores now calculate on-the-fly via behavioral_scores VIEW
            // No need to call update_behavioral_score - scores are computed when queried

            await MainActor.run {
                dismiss()
            }

        } catch {
            await MainActor.run {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }
}

#Preview {
    WaterEntryView()
}
