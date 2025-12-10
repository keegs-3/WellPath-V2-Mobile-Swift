//
//  LegumesEntryView.swift
//  WellPath
//
//  Entry form for logging legumes intake
//

import SwiftUI
import Supabase

struct LegumesEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDateTime = Date()
    @State private var servingsAmount: String = ""
    @State private var selectedType: String = ""
    @State private var selectedTiming: String = ""
    @State private var legumesTypes: [ReferenceOption] = []
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
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: MetricsUIConfig.getIcon(for: "Legumes"))
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                }

                Text("Legumes")
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
                        HStack {
                            TextField("Amount", text: $servingsAmount)
                                .keyboardType(.decimalPad)
                            Text("servings")
                                .foregroundColor(.secondary)
                        }
                    }

                    Section {
                        Picker("Type", selection: $selectedType) {
                            Text("Select Type").tag("")
                            ForEach(legumesTypes, id: \.referenceKey) { option in
                                Text(option.displayName).tag(option.referenceKey)
                            }
                        }

                        Picker("Timing", selection: $selectedTiming) {
                            Text("Select Timing").tag("")
                            ForEach(mealTimings, id: \.referenceKey) { option in
                                Text(option.displayName).tag(option.referenceKey)
                            }
                        }
                    }

                    Section {
                        DatePicker("Date", selection: $selectedDateTime, displayedComponents: [.date])
                        DatePicker("Time", selection: $selectedDateTime, displayedComponents: [.hourAndMinute])
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
                    await saveLegumesEntry()
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
            .background(servingsAmount.isEmpty || isLoading ? Color.gray : Color.green)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
            .disabled(isSaving || servingsAmount.isEmpty || isLoading)
        }
        .task {
            await loadReferenceData()
        }
    }

    private func loadReferenceData() async {
        isLoading = true

        do {
            // Load legumes types from sample_category_types_reference (using reference_key for metadata)
            let typesResponse: [ReferenceOption] = try await supabase
                .from("sample_category_types_reference")
                .select("id, display_name, reference_key")
                .eq("reference_category", value: "legumes_types")
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
                legumesTypes = typesResponse
                mealTimings = timingsResponse

                // Set default selections if available (use reference_key)
                selectedType = legumesTypes.first?.referenceKey ?? ""
                selectedTiming = mealTimings.first?.referenceKey ?? ""

                isLoading = false
            }

        } catch {
            await MainActor.run {
                // Don't show error for missing options - they're optional
                print("⚠️ Could not load reference options: \(error.localizedDescription)")
                isLoading = false
            }
        }
    }

    private func saveLegumesEntry() async {
        guard let amountValue = Double(servingsAmount), amountValue > 0 else {
            errorMessage = "Please enter a valid amount"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            // Get user ID
            guard let userId = UUID(uuidString: try await supabase.auth.session.user.id.uuidString) else {
                errorMessage = "Invalid user ID"
                isSaving = false
                return
            }

            // Get device timezone
            let deviceTimezone = TimeZone.current.identifier

            // Build metadata with type and timing
            var metadata: [String: AnyJSON] = [:]
            if !selectedType.isEmpty {
                metadata["legumes_type"] = .string(selectedType)
            }
            if !selectedTiming.isEmpty {
                metadata["food_timing"] = .string(selectedTiming)
            }

            // Create quantity sample using the proper write model
            let sample = QuantitySampleWrite.create(
                patientId: userId,
                quantityType: QuantityTypes.legumesServings,
                value: amountValue,
                unit: "serving",
                timestamp: selectedDateTime,
                source: .wellpathInput,
                timezone: deviceTimezone,
                metadata: metadata.isEmpty ? nil : metadata,
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

#Preview {
    LegumesEntryView()
}
