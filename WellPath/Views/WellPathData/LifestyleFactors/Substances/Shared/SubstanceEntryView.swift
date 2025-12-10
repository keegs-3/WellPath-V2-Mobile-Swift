//
//  SubstanceEntryView.swift
//  WellPath
//
//  Generic entry form for logging substance use to patient_samples.
//  Configurable for any substance type (tobacco, nicotine, etc.).
//

import SwiftUI
import Supabase

struct SubstanceEntryView: View {
    @Environment(\.dismiss) var dismiss

    let config: SubstanceConfig

    @State private var selectedDateTime = Date()
    @State private var useCount: Int = 1
    @State private var useCountText: String = "1"
    @State private var selectedType: String = ""
    @State private var substanceTypes: [ReferenceOption] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isTextFieldFocused: Bool

    private let supabase = SupabaseManager.shared.client

    // Dynamic unit based on selected type
    private var currentUnit: (singular: String, plural: String) {
        config.unitForType?(selectedType) ?? (config.unitSingular, config.unitPlural)
    }

    // Dynamic count label based on selected type
    private var currentCountLabel: String {
        if let selectedOption = substanceTypes.first(where: { $0.referenceKey == selectedType }) {
            return "Number of \(selectedOption.displayName.lowercased())s"
        }
        return config.countLabel
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
                        .fill(config.color.opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: config.icon)
                        .font(.system(size: 32))
                        .foregroundColor(config.color)
                }

                Text(config.entryTitle)
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
                            value: $useCount,
                            textValue: $useCountText,
                            unit: useCount == 1 ? currentUnit.singular : currentUnit.plural,
                            color: config.color,
                            range: 1...999,
                            isFocused: $isTextFieldFocused
                        )
                    }

                    Section {
                        Picker("Type", selection: $selectedType) {
                            Text("Select Type").tag("")
                            ForEach(substanceTypes, id: \.id) { option in
                                Text(option.displayName).tag(option.referenceKey)
                            }
                        }
                    }

                    if let helpText = config.helpText {
                        Section {
                            Text(helpText)
                                .font(.caption)
                                .foregroundColor(.secondary)
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
                Task { await saveEntry() }
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
            .background(isLoading || selectedType.isEmpty ? Color.gray : config.color)
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
            let typesResponse: [ReferenceOption] = try await supabase
                .from("sample_category_types_reference")
                .select("id, display_name, reference_key")
                .eq("reference_category", value: config.referenceCategory)
                .eq("is_active", value: true)
                .order("display_order")
                .execute()
                .value

            await MainActor.run {
                substanceTypes = typesResponse
                selectedType = substanceTypes.first?.referenceKey ?? ""
                isLoading = false
            }

        } catch {
            await MainActor.run {
                print("Could not load \(config.referenceCategory): \(error.localizedDescription)")
                errorMessage = "Failed to load options: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    private func saveEntry() async {
        isSaving = true
        errorMessage = nil

        do {
            let userId = try await supabase.auth.session.user.id
            let deviceTimezone = TimeZone.current.identifier

            var metadata: [String: AnyJSON] = [:]
            if !selectedType.isEmpty {
                metadata[config.metadataKey] = .string(selectedType)
            }

            let sample = QuantitySampleWrite.create(
                patientId: userId,
                quantityType: config.quantityType,
                value: Double(useCount),
                unit: config.unit,
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

// MARK: - Hybrid Number Input (Text field + Stepper)

struct HybridNumberInput: View {
    @Binding var value: Int
    @Binding var textValue: String
    let unit: String
    let color: Color
    let range: ClosedRange<Int>
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 16) {
            // Minus button
            Button(action: {
                if value > range.lowerBound {
                    value -= 1
                    textValue = "\(value)"
                }
            }) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(value > range.lowerBound ? color : .gray.opacity(0.4))
            }
            .buttonStyle(.plain)
            .disabled(value <= range.lowerBound)

            // Text field with unit
            HStack(spacing: 4) {
                TextField("", text: $textValue)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 24, weight: .semibold))
                    .frame(width: 60)
                    .focused(isFocused)
                    .onChange(of: textValue) { _, newValue in
                        // Filter to only digits
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered != newValue {
                            textValue = filtered
                        }
                        // Update numeric value
                        if let newInt = Int(filtered), range.contains(newInt) {
                            value = newInt
                        }
                    }
                    .onChange(of: isFocused.wrappedValue) { _, focused in
                        if !focused {
                            // Validate on blur
                            if let newInt = Int(textValue), range.contains(newInt) {
                                value = newInt
                            } else {
                                textValue = "\(value)"
                            }
                        }
                    }

                Text(unit)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Plus button
            Button(action: {
                if value < range.upperBound {
                    value += 1
                    textValue = "\(value)"
                }
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(value < range.upperBound ? color : .gray.opacity(0.4))
            }
            .buttonStyle(.plain)
            .disabled(value >= range.upperBound)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Configuration

struct SubstanceConfig {
    let entryTitle: String
    let icon: String
    let color: Color
    let referenceCategory: String
    let quantityType: String
    let metadataKey: String
    let unit: String
    let unitSingular: String
    let unitPlural: String
    let countLabel: String
    let helpText: String?
    /// Optional: returns (singular, plural) unit based on selected type key
    let unitForType: ((String) -> (String, String))?

    static let tobacco = SubstanceConfig(
        entryTitle: "Log Tobacco",
        icon: "smoke",
        color: .brown,
        referenceCategory: "tobacco_types",
        quantityType: QuantityTypes.tobaccoUses,
        metadataKey: TobaccoMetadataKeys.tobaccoType,
        unit: "uses",
        unitSingular: "use",
        unitPlural: "uses",
        countLabel: "Number of Uses",
        helpText: nil,
        unitForType: { typeKey in
            switch typeKey {
            case "cigarette": return ("cigarette", "cigarettes")
            case "cigar": return ("cigar", "cigars")
            case "pipe": return ("bowl", "bowls")
            case "chewing": return ("pinch", "pinches")
            case "hookah": return ("session", "sessions")
            default: return ("use", "uses")
            }
        }
    )

    static let nicotine = SubstanceConfig(
        entryTitle: "Log Nicotine",
        icon: "cloud",
        color: .cyan,
        referenceCategory: "nicotine_types",
        quantityType: QuantityTypes.nicotineUses,
        metadataKey: NicotineMetadataKeys.nicotineType,
        unit: "uses",
        unitSingular: "use",
        unitPlural: "uses",
        countLabel: "Number of Uses",
        helpText: nil,
        unitForType: { typeKey in
            switch typeKey {
            case "vape": return ("puff", "puffs")
            case "pouch": return ("pouch", "pouches")
            case "gum": return ("piece", "pieces")
            case "lozenge": return ("lozenge", "lozenges")
            case "patch": return ("patch", "patches")
            default: return ("use", "uses")
            }
        }
    )
}

#Preview {
    SubstanceEntryView(config: .tobacco)
}
