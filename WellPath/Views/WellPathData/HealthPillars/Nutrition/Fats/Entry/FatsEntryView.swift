//
//  FatsEntryView.swift
//  WellPath
//
//  Entry form for logging fat intake to patient_quantity_samples
//

import SwiftUI
import Supabase

struct FatsEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDateTime = Date()
    @State private var fatAmount: String = ""
    @State private var selectedType: String = ""
    @State private var selectedTiming: String = ""
    @State private var fatTypes: [ReferenceOption] = []
    @State private var mealTimings: [ReferenceOption] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let supabase = SupabaseManager.shared.client

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
                        .fill(Color(red: 0.9, green: 0.7, blue: 0.2).opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: "drop.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.2))
                }

                Text("Fats")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.top, 8)
            .padding(.bottom, 24)

            Form {
                if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else {
                    Section {
                        DatePicker("Date", selection: $selectedDateTime, displayedComponents: [.date])
                        DatePicker("Time", selection: $selectedDateTime, displayedComponents: [.hourAndMinute])
                    }

                    Section {
                        HStack {
                            TextField("Amount", text: $fatAmount)
                                .keyboardType(.decimalPad)
                            Text("grams")
                                .foregroundColor(.secondary)
                        }
                    }

                    Section {
                        Picker("Type", selection: $selectedType) {
                            Text("Select Type").tag("")
                            ForEach(fatTypes, id: \.id) { option in
                                Text(option.displayName).tag(option.referenceKey)
                            }
                        }

                        Picker("Timing", selection: $selectedTiming) {
                            Text("Select Timing").tag("")
                            ForEach(mealTimings, id: \.id) { option in
                                Text(option.displayName).tag(option.referenceKey)
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
            }

            // Save button at bottom
            Button(action: {
                Task {
                    await saveFatEntry()
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
            .background(fatAmount.isEmpty || isLoading ? Color.gray : Color(red: 0.9, green: 0.7, blue: 0.2))
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
            .disabled(isSaving || fatAmount.isEmpty || isLoading)
        }
        .task {
            await loadReferenceData()
        }
    }

    private func loadReferenceData() async {
        isLoading = true

        do {
            // Load fat types
            let typesResponse: [ReferenceOption] = try await supabase
                .from("sample_category_types_reference")
                .select("id, display_name, reference_key")
                .eq("reference_category", value: "fat_types")
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            // Load meal timings
            let timingsResponse: [ReferenceOption] = try await supabase
                .from("sample_category_types_reference")
                .select("id, display_name, reference_key")
                .eq("reference_category", value: "food_timing")
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            await MainActor.run {
                fatTypes = typesResponse
                mealTimings = timingsResponse
                selectedType = fatTypes.first?.referenceKey ?? ""
                selectedTiming = mealTimings.first?.referenceKey ?? ""
                isLoading = false
            }

        } catch {
            await MainActor.run {
                errorMessage = "Failed to load options: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    private func saveFatEntry() async {
        guard let amountValue = Double(fatAmount), amountValue > 0 else {
            errorMessage = "Please enter a valid amount"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            let userId = try await supabase.auth.session.user.id
            let deviceTimezone = TimeZone.current.identifier

            var metadata: [String: AnyJSON] = [:]
            if !selectedType.isEmpty {
                metadata["fat_type"] = .string(selectedType)
            }
            if !selectedTiming.isEmpty {
                metadata["food_timing"] = .string(selectedTiming)
            }

            let sample = QuantitySampleWrite.create(
                patientId: userId,
                quantityType: QuantityTypes.fatGrams,
                value: amountValue,
                unit: "gram",
                timestamp: selectedDateTime,
                source: .wellpathInput,
                timezone: deviceTimezone,
                metadata: metadata,
                eventInstanceId: UUID()
            )

            try await supabase
                .from("patient_quantity_samples")
                .insert(sample)
                .execute()

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
    FatsEntryView()
}
