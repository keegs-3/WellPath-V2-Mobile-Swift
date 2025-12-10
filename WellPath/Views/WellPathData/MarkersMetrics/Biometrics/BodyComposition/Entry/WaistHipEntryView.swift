//
//  WaistHipEntryView.swift
//  WellPath
//
//  Entry form for logging waist and hip measurements to patient_samples
//  These trigger automatic WHR calculation via database trigger
//

import SwiftUI
import Supabase

struct WaistHipEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDateTime = Date()
    @State private var waistValue: String = ""
    @State private var hipValue: String = ""
    @State private var selectedUnit: LengthUnit = .inches
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let supabase = SupabaseManager.shared.client

    enum LengthUnit: String, CaseIterable {
        case inches = "in"
        case centimeters = "cm"

        var displayName: String {
            switch self {
            case .inches: return "in"
            case .centimeters: return "cm"
            }
        }

        var databaseUnit: String {
            switch self {
            case .inches: return "inch"
            case .centimeters: return "centimeter"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with X button
            HStack {
                Button(action: { dismiss() }) {
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
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: "ruler")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                }

                Text("Waist & Hip")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Enter both to calculate Waist-to-Hip Ratio")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                        Text("Unit")
                        Spacer()
                        Picker("Unit", selection: $selectedUnit) {
                            ForEach(LengthUnit.allCases, id: \.self) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 100)
                    }
                }

                Section("Measurements") {
                    HStack {
                        Text("Waist")
                        Spacer()
                        TextField("0", text: $waistValue)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text(selectedUnit.displayName)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Hip")
                        Spacer()
                        TextField("0", text: $hipValue)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text(selectedUnit.displayName)
                            .foregroundColor(.secondary)
                    }
                }

                // Preview WHR if both values entered
                if let waist = Double(waistValue), let hip = Double(hipValue), hip > 0 {
                    Section("Calculated") {
                        HStack {
                            Text("Waist-to-Hip Ratio")
                            Spacer()
                            Text(String(format: "%.2f", waist / hip))
                                .foregroundColor(.secondary)
                        }
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
                Task { await saveEntries() }
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
            .background(isValid ? Color.orange : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
            .disabled(isSaving || !isValid)
        }
    }

    private var isValid: Bool {
        !waistValue.isEmpty || !hipValue.isEmpty
    }

    private func saveEntries() async {
        isSaving = true
        errorMessage = nil

        do {
            let userId = try await supabase.auth.session.user.id
            let deviceTimezone = TimeZone.current.identifier

            // Save waist if entered
            if let waist = Double(waistValue), waist > 0 {
                let waistSample = QuantitySampleWrite.create(
                    patientId: userId,
                    quantityType: QuantityTypes.waistCircumference,
                    value: waist,
                    unit: selectedUnit.databaseUnit,
                    timestamp: selectedDateTime,
                    source: .wellpathInput,
                    timezone: deviceTimezone,
                    eventInstanceId: UUID()
                )

                try await supabase
                    .from("patient_quantity_samples")
                    .insert(waistSample)
                    .execute()
            }

            // Save hip if entered
            if let hip = Double(hipValue), hip > 0 {
                let hipSample = QuantitySampleWrite.create(
                    patientId: userId,
                    quantityType: QuantityTypes.hipCircumference,
                    value: hip,
                    unit: selectedUnit.databaseUnit,
                    timestamp: selectedDateTime,
                    source: .wellpathInput,
                    timezone: deviceTimezone,
                    eventInstanceId: UUID()
                )

                try await supabase
                    .from("patient_quantity_samples")
                    .insert(hipSample)
                    .execute()
            }

            await MainActor.run { dismiss() }

        } catch {
            await MainActor.run {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }
}

#Preview {
    WaistHipEntryView()
}
