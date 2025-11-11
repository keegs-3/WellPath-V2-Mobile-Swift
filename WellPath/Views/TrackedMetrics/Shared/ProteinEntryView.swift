//
//  ProteinEntryView.swift
//  WellPath
//
//  Entry form for logging protein intake
//

import SwiftUI

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
            // Load protein types from data_entry_fields_reference
            let typesResponse: [ReferenceOption] = try await supabase
                .from("data_entry_fields_reference")
                .select("id, display_name")
                .eq("reference_category", value: "protein_types")
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
                proteinTypes = typesResponse
                mealTimings = timingsResponse

                // Set default selections if available
                selectedType = proteinTypes.first?.id ?? ""
                selectedTiming = mealTimings.first?.id ?? ""

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

            // Insert protein grams entry
            try await supabase
                .from("patient_data_entries")
                .insert([
                    "patient_id": userId,
                    "field_id": "DEF_PROTEIN_GRAMS",
                    "entry_date": dateString,
                    "entry_timestamp": timestampString,
                    "value_quantity": "\(amountValue)",
                    "source": "wellpath_input",
                    "event_instance_id": eventInstanceId
                ])
                .execute()

            // Optional: Insert protein type
            if !selectedType.isEmpty {
                try await supabase
                    .from("patient_data_entries")
                    .insert([
                        "patient_id": userId,
                        "field_id": "DEF_PROTEIN_TYPE",
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
                        "field_id": "DEF_PROTEIN_TIMING",
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

// MARK: - Supporting Models

struct ReferenceOption: Codable, Identifiable {
    let id: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case id = "id"  // Changed to use UUID id column
        case displayName = "display_name"
    }
}

#Preview {
    ProteinEntryView()
}
