//
//  WholeGrainsEntryView.swift
//  WellPath
//
//  Entry form for logging whole grains intake
//

import SwiftUI

struct WholeGrainsEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDateTime = Date()
    @State private var servingsAmount: String = ""
    @State private var selectedType: String = ""
    @State private var selectedTiming: String = ""
    @State private var wholeGrainsTypes: [ReferenceOption] = []
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
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: MetricsUIConfig.getIcon(for: "Whole Grains"))
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                }

                Text("Whole Grains")
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
                            ForEach(wholeGrainsTypes, id: \.id) { option in
                                Text(option.displayName).tag(option.id)
                            }
                        }

                        Picker("Timing", selection: $selectedTiming) {
                            Text("Select Timing").tag("")
                            ForEach(mealTimings, id: \.id) { option in
                                Text(option.displayName).tag(option.id)
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
                    await saveWholeGrainsEntry()
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
            .background(servingsAmount.isEmpty || isLoading ? Color.gray : Color.orange)
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
            // Load whole grains types from data_entry_fields_reference
            let typesResponse: [ReferenceOption] = try await supabase
                .from("data_entry_fields_reference")
                .select("id, display_name")
                .eq("reference_category", value: "whole_grains_types")
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            // Load meal timings from data_entry_fields_reference
            let timingsResponse: [ReferenceOption] = try await supabase
                .from("data_entry_fields_reference")
                .select("id, display_name")
                .eq("reference_category", value: "protein_timing")
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            await MainActor.run {
                wholeGrainsTypes = typesResponse
                mealTimings = timingsResponse

                // Set default selections if available
                selectedType = wholeGrainsTypes.first?.id ?? ""
                selectedTiming = mealTimings.first?.id ?? ""

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

    private func saveWholeGrainsEntry() async {
        guard let amountValue = Double(servingsAmount), amountValue > 0 else {
            errorMessage = "Please enter a valid amount"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            // Get user ID
            let userId = try await supabase.auth.session.user.id.uuidString

            // Generate event instance ID to link all fields together
            let eventInstanceId = UUID().uuidString

            // Format dates
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let timestampString = dateFormatter.string(from: selectedDateTime)

            // Extract just the date (YYYY-MM-DD)
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day], from: selectedDateTime)
            let dateString = String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)

            // Insert whole grains servings entry
            try await supabase
                .from("patient_data_entries")
                .insert([
                    "patient_id": userId,
                    "field_id": "DEF_WHOLE_GRAINS_SERVINGS",
                    "entry_date": dateString,
                    "entry_timestamp": timestampString,
                    "value_quantity": "\(amountValue)",
                    "source": "wellpath_input",
                    "event_instance_id": eventInstanceId
                ])
                .execute()

            // Optional: Insert whole grains type
            if !selectedType.isEmpty {
                try await supabase
                    .from("patient_data_entries")
                    .insert([
                        "patient_id": userId,
                        "field_id": "DEF_WHOLE_GRAINS_TYPE",
                        "entry_date": dateString,
                        "entry_timestamp": timestampString,
                        "value_reference": selectedType,
                        "source": "wellpath_input",
                        "event_instance_id": eventInstanceId
                    ])
                    .execute()
            }

            // Optional: Insert meal timing
            if !selectedTiming.isEmpty {
                try await supabase
                    .from("patient_data_entries")
                    .insert([
                        "patient_id": userId,
                        "field_id": "DEF_WHOLE_GRAINS_TIMING",
                        "entry_date": dateString,
                        "entry_timestamp": timestampString,
                        "value_reference": selectedTiming,
                        "source": "wellpath_input",
                        "event_instance_id": eventInstanceId
                    ])
                    .execute()
            }

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
    WholeGrainsEntryView()
}
