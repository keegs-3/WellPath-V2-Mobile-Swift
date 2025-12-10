//
//  AlcoholEntryView.swift
//  WellPath
//
//  Entry form for logging alcohol consumption to patient_samples
//

import SwiftUI
import Supabase

struct AlcoholEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDateTime = Date()
    @State private var drinkCount: Int = 1
    @State private var drinkCountText: String = "1"
    @State private var selectedType: String = ""
    @State private var alcoholTypes: [ReferenceOption] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isTextFieldFocused: Bool

    private let supabase = SupabaseManager.shared.client
    private let color = Color.orange

    // Dynamic unit based on selected type
    private var currentUnit: (singular: String, plural: String) {
        switch selectedType {
        case "beer": return ("beer", "beers")
        case "wine": return ("glass", "glasses")
        case "spirits": return ("shot", "shots")
        case "cocktail": return ("cocktail", "cocktails")
        default: return ("drink", "drinks")
        }
    }

    // Dynamic count label
    private var currentCountLabel: String {
        if let selectedOption = alcoholTypes.first(where: { $0.referenceKey == selectedType }) {
            let typeName = selectedOption.displayName.lowercased()
            if typeName == "wine" {
                return "Number of glasses"
            } else if typeName == "spirits" {
                return "Number of shots"
            }
            return "Number of \(typeName)s"
        }
        return "Number of Drinks"
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
                        .fill(color.opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: "wineglass")
                        .font(.system(size: 32))
                        .foregroundColor(color)
                }

                Text("Log Drinks")
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

                    Section(currentCountLabel) {
                        HybridNumberInput(
                            value: $drinkCount,
                            textValue: $drinkCountText,
                            unit: drinkCount == 1 ? currentUnit.singular : currentUnit.plural,
                            color: color,
                            range: 1...99,
                            isFocused: $isTextFieldFocused
                        )
                    }

                    Section {
                        Picker("Type", selection: $selectedType) {
                            Text("Select Type").tag("")
                            ForEach(alcoholTypes, id: \.id) { option in
                                Text(option.displayName).tag(option.referenceKey)
                            }
                        }
                    }

                    Section {
                        Text("A standard drink is ~14g of alcohol: 12oz beer, 5oz wine, or 1.5oz spirits")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                Task { await saveDrinkEntry() }
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
            .background(isLoading || selectedType.isEmpty ? Color.gray : color)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
            .disabled(isSaving || isLoading || selectedType.isEmpty)
        }
        .task {
            await loadReferenceData()
        }
    }

    private func loadReferenceData() async {
        isLoading = true

        do {
            // Load alcohol types from sample_category_types_reference
            let typesResponse: [ReferenceOption] = try await supabase
                .from("sample_category_types_reference")
                .select("id, display_name, reference_key")
                .eq("reference_category", value: "alcohol_types")
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            await MainActor.run {
                alcoholTypes = typesResponse
                selectedType = alcoholTypes.first?.referenceKey ?? ""
                isLoading = false
            }

        } catch {
            await MainActor.run {
                print("Could not load alcohol types: \(error.localizedDescription)")
                errorMessage = "Failed to load options: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    private func saveDrinkEntry() async {
        isSaving = true
        errorMessage = nil

        do {
            let userId = try await supabase.auth.session.user.id
            let deviceTimezone = TimeZone.current.identifier

            // Build metadata with alcohol type
            var metadata: [String: AnyJSON] = [:]
            if !selectedType.isEmpty {
                metadata[AlcoholMetadataKeys.alcoholType] = .string(selectedType)
            }

            // Create quantity sample using the proper write model
            let sample = QuantitySampleWrite.create(
                patientId: userId,
                quantityType: QuantityTypes.alcoholDrinks,
                value: Double(drinkCount),
                unit: "drink",
                timestamp: selectedDateTime,
                source: .wellpathInput,
                timezone: deviceTimezone,
                metadata: metadata.isEmpty ? nil : metadata,
                eventInstanceId: UUID()
            )

            try await supabase
                .from("patient_quantity_samples")
                .insert(sample)
                .execute()

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
    AlcoholEntryView()
}
