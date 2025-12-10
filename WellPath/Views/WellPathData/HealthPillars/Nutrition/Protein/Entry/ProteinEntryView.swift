//
//  ProteinEntryView.swift
//  WellPath
//
//  Entry form for logging protein intake to patient_quantity_samples
//

import SwiftUI
import Supabase

struct ProteinEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDateTime = Date()
    @State private var proteinAmount: String = ""
    @State private var selectedType: String = ""
    @State private var selectedTiming: String = ""
    @State private var proteinTypes: [ReferenceOption] = []
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
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: "fish.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                }

                Text("Protein")
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
                            TextField("Amount", text: $proteinAmount)
                                .keyboardType(.decimalPad)
                            Text("grams")
                                .foregroundColor(.secondary)
                        }
                    }

                    Section {
                        Picker("Type", selection: $selectedType) {
                            Text("Select Type").tag("")
                            ForEach(proteinTypes, id: \.id) { option in
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
                    await saveProteinEntry()
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
            .background(proteinAmount.isEmpty || isLoading ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
            .disabled(isSaving || proteinAmount.isEmpty || isLoading)
        }
        .task {
            await loadReferenceData()
        }
    }

    private func loadReferenceData() async {
        isLoading = true

        do {
            // Load protein types from sample_category_types_reference
            let typesResponse: [ReferenceOption] = try await supabase
                .from("sample_category_types_reference")
                .select("id, display_name, reference_key")
                .eq("reference_category", value: "protein_types")
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            // Load meal timings from sample_category_types_reference
            let timingsResponse: [ReferenceOption] = try await supabase
                .from("sample_category_types_reference")
                .select("id, display_name, reference_key")
                .eq("reference_category", value: "food_timing")
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            await MainActor.run {
                proteinTypes = typesResponse
                mealTimings = timingsResponse

                // Set default selections if available
                selectedType = proteinTypes.first?.referenceKey ?? ""
                selectedTiming = mealTimings.first?.referenceKey ?? ""

                isLoading = false
            }

        } catch {
            await MainActor.run {
                print("⚠️ Could not load reference options: \(error.localizedDescription)")
                print("⚠️ Full error: \(error)")
                errorMessage = "Failed to load options: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    private func saveProteinEntry() async {
        guard let amountValue = Double(proteinAmount), amountValue > 0 else {
            errorMessage = "Please enter a valid amount"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            // Get user ID
            let userId = try await supabase.auth.session.user.id

            // Get device timezone
            let deviceTimezone = TimeZone.current.identifier

            // Build metadata with protein type and timing
            var metadata: [String: AnyJSON] = [:]
            if !selectedType.isEmpty {
                metadata[ProteinMetadataKeys.proteinType] = .string(selectedType)
            }
            if !selectedTiming.isEmpty {
                metadata["food_timing"] = .string(selectedTiming)
            }

            // Create quantity sample using the proper write model
            let sample = QuantitySampleWrite.create(
                patientId: userId,
                quantityType: QuantityTypes.proteinGrams,
                value: amountValue,
                unit: "gram",
                timestamp: selectedDateTime,
                source: .wellpathInput,
                timezone: deviceTimezone,
                metadata: metadata,
                eventInstanceId: UUID()
            )

            // Insert into patient_quantity_samples (the correct specialized table)
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

// MARK: - Supporting Models

struct ReferenceOption: Codable, Identifiable {
    let id: UUID
    let displayName: String
    let referenceKey: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case referenceKey = "reference_key"
    }
}

#Preview {
    ProteinEntryView()
}
