//
//  CaffeineEntryView.swift
//  WellPath
//
//  Entry form for logging caffeine intake to patient_quantity_samples
//  Also writes calories sample based on beverage type's typical_calories
//

import SwiftUI
import Supabase

// MARK: - Reference Option with Metadata

/// Extended reference option that includes metadata for calorie info
struct CaffeineReferenceOption: Codable, Identifiable {
    let id: UUID
    let displayName: String
    let referenceKey: String
    let metadata: CaffeineTypeMetadata?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case referenceKey = "reference_key"
        case metadata
    }
}

struct CaffeineTypeMetadata: Codable {
    let typicalCalories: String?

    enum CodingKeys: String, CodingKey {
        case typicalCalories = "typical_calories"
    }

    /// Get calories as Double, defaulting to 0 if not available
    var caloriesValue: Double {
        guard let caloriesStr = typicalCalories,
              let calories = Double(caloriesStr) else {
            return 0
        }
        return calories
    }
}

struct CaffeineEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDateTime = Date()
    @State private var caffeineAmount: String = ""
    @State private var selectedType: String = ""
    @State private var caffeineTypes: [CaffeineReferenceOption] = []
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
                        .fill(Color(red: 0.5, green: 0.3, blue: 0.2).opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.2))
                }

                Text("Caffeine")
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
                            TextField("Amount", text: $caffeineAmount)
                                .keyboardType(.decimalPad)
                            Text("mg")
                                .foregroundColor(.secondary)
                        }
                    }

                    Section {
                        Picker("Type", selection: $selectedType) {
                            Text("Select Type").tag("")
                            ForEach(caffeineTypes) { option in
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
                    await saveCaffeineEntry()
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
            .background(caffeineAmount.isEmpty || isLoading ? Color.gray : Color(red: 0.5, green: 0.3, blue: 0.2))
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
            .disabled(isSaving || caffeineAmount.isEmpty || isLoading)
        }
        .task {
            await loadReferenceData()
        }
    }

    private func loadReferenceData() async {
        isLoading = true

        do {
            // Load caffeine types with metadata (includes typical_calories)
            let typesResponse: [CaffeineReferenceOption] = try await supabase
                .from("sample_category_types_reference")
                .select("id, display_name, reference_key, metadata")
                .eq("reference_category", value: "caffeine_types")
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            await MainActor.run {
                caffeineTypes = typesResponse
                selectedType = caffeineTypes.first?.referenceKey ?? ""
                isLoading = false
            }

        } catch {
            await MainActor.run {
                errorMessage = "Failed to load options: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    private func saveCaffeineEntry() async {
        guard let amountValue = Double(caffeineAmount), amountValue > 0 else {
            errorMessage = "Please enter a valid amount"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            let userId = try await supabase.auth.session.user.id
            let deviceTimezone = TimeZone.current.identifier
            let eventId = UUID()  // Shared event instance for both samples

            var metadata: [String: AnyJSON] = [:]
            if !selectedType.isEmpty {
                metadata["caffeine_type"] = .string(selectedType)
            }

            // Create caffeine sample
            let caffeineSample = QuantitySampleWrite.create(
                patientId: userId,
                quantityType: QuantityTypes.caffeineMg,
                value: amountValue,
                unit: "milligram",
                timestamp: selectedDateTime,
                source: .wellpathInput,
                timezone: deviceTimezone,
                metadata: metadata,
                eventInstanceId: eventId
            )

            // Insert caffeine sample
            try await supabase
                .from("patient_quantity_samples")
                .insert(caffeineSample)
                .execute()

            // Also write calories sample if the selected type has typical_calories
            if let selectedOption = caffeineTypes.first(where: { $0.referenceKey == selectedType }),
               let caloriesValue = selectedOption.metadata?.caloriesValue,
               caloriesValue > 0 {
                // Add source info to calories metadata
                let caloriesMetadata: [String: AnyJSON] = [
                    "source_type": .string("caffeine"),
                    "caffeine_type": .string(selectedType)
                ]

                let calorieSample = QuantitySampleWrite.create(
                    patientId: userId,
                    quantityType: QuantityTypes.calorieIntake,
                    value: caloriesValue,
                    unit: "kilocalorie",
                    timestamp: selectedDateTime,
                    source: .wellpathInput,
                    timezone: deviceTimezone,
                    metadata: caloriesMetadata,
                    eventInstanceId: eventId
                )

                try await supabase
                    .from("patient_quantity_samples")
                    .insert(calorieSample)
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
    CaffeineEntryView()
}
