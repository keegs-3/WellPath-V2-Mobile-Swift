//
//  FiberEntryView.swift
//  WellPath
//
//  Entry form for logging fiber intake to patient_quantity_samples
//

import SwiftUI
import Supabase

struct FiberEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDateTime = Date()
    @State private var fiberAmount: String = ""
    @State private var selectedSource: String = ""
    @State private var selectedTiming: String = ""
    @State private var fiberSources: [ReferenceOption] = []
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
                        .fill(Color(red: 0.4, green: 0.6, blue: 0.3).opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color(red: 0.4, green: 0.6, blue: 0.3))
                }

                Text("Fiber")
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
                            TextField("Amount", text: $fiberAmount)
                                .keyboardType(.decimalPad)
                            Text("grams")
                                .foregroundColor(.secondary)
                        }
                    }

                    Section {
                        Picker("Source", selection: $selectedSource) {
                            Text("Select Source").tag("")
                            ForEach(fiberSources, id: \.id) { option in
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
                    await saveFiberEntry()
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
            .background(fiberAmount.isEmpty || isLoading ? Color.gray : Color(red: 0.4, green: 0.6, blue: 0.3))
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
            .disabled(isSaving || fiberAmount.isEmpty || isLoading)
        }
        .task {
            await loadReferenceData()
        }
    }

    private func loadReferenceData() async {
        isLoading = true

        do {
            // Load fiber sources
            let sourcesResponse: [ReferenceOption] = try await supabase
                .from("sample_category_types_reference")
                .select("id, display_name, reference_key")
                .eq("reference_category", value: "fiber_sources")
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
                fiberSources = sourcesResponse
                mealTimings = timingsResponse
                selectedSource = fiberSources.first?.referenceKey ?? ""
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

    private func saveFiberEntry() async {
        guard let amountValue = Double(fiberAmount), amountValue > 0 else {
            errorMessage = "Please enter a valid amount"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            let userId = try await supabase.auth.session.user.id
            let deviceTimezone = TimeZone.current.identifier

            var metadata: [String: AnyJSON] = [:]
            if !selectedSource.isEmpty {
                metadata["fiber_source"] = .string(selectedSource)
            }
            if !selectedTiming.isEmpty {
                metadata["food_timing"] = .string(selectedTiming)
            }

            let sample = QuantitySampleWrite.create(
                patientId: userId,
                quantityType: QuantityTypes.fiberGrams,
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
    FiberEntryView()
}
