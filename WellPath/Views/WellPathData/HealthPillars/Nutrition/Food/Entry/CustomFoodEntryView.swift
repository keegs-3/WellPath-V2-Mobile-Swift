//
//  CustomFoodEntryView.swift
//  WellPath
//
//  Form for creating custom foods with user-assigned longevity tiers
//

import SwiftUI
import Supabase

// MARK: - Type Reference Model

struct CategoryTypeRef: Identifiable, Codable {
    let id: UUID
    let referenceKey: String
    let displayName: String
    let displayOrder: Int
    let metadata: TypeRefMetadata?

    enum CodingKeys: String, CodingKey {
        case id
        case referenceKey = "reference_key"
        case displayName = "display_name"
        case displayOrder = "display_order"
        case metadata
    }
}

struct TypeRefMetadata: Codable {
    let tier: Int?
    let tierName: String?

    enum CodingKeys: String, CodingKey {
        case tier
        case tierName = "tier_name"
    }
}

struct CustomFoodEntryView: View {
    @Environment(\.dismiss) var dismiss

    // Callback when food is created
    let onFoodCreated: (CustomFood) -> Void

    @State private var name = ""
    @State private var brand = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var fiber = ""
    @State private var servingGrams = "100"
    @State private var servingDescription = ""
    @State private var selectedProteinType: String = "protein_types_other"
    @State private var selectedFatType: String = "fat_types_other"
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var isLoadingTypes = true
    @State private var proteinTypes: [CategoryTypeRef] = []
    @State private var fatTypes: [CategoryTypeRef] = []

    // Optional extended nutrition fields
    @State private var showExtendedNutrition = false
    @State private var satFat = ""
    @State private var monoFat = ""
    @State private var polyFat = ""
    @State private var sugars = ""
    @State private var sodium = ""
    @State private var potassium = ""
    @State private var calcium = ""
    @State private var iron = ""
    @State private var vitaminD = ""
    @State private var vitaminB12 = ""

    private let supabase = SupabaseManager.shared.client

    var body: some View {
        NavigationStack {
            Form {
                // Basic info
                Section("Food Details") {
                    TextField("Food Name *", text: $name)
                    TextField("Brand (optional)", text: $brand)
                }

                // Serving info first (so user enters serving size before nutrition)
                Section {
                    HStack {
                        Text("Serving size")
                        Spacer()
                        TextField("100", text: $servingGrams)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                    TextField("Description (e.g., '1 bar', '1 scoop')", text: $servingDescription)
                } header: {
                    Text("Serving Size")
                } footer: {
                    Text("Enter the serving size from the nutrition label")
                }

                // Macros per serving (will convert to per-100g when saving)
                Section {
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("0", text: $calories)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("kcal")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Protein")
                        Spacer()
                        TextField("0", text: $protein)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Carbs")
                        Spacer()
                        TextField("0", text: $carbs)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Fat")
                        Spacer()
                        TextField("0", text: $fat)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Fiber")
                        Spacer()
                        TextField("0", text: $fiber)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Nutrition (per serving)")
                } footer: {
                    Text("Enter values from the nutrition label for one serving")
                }

                // Extended nutrition (collapsible)
                Section {
                    DisclosureGroup("More Nutrition Details", isExpanded: $showExtendedNutrition) {
                        // Fat breakdown
                        Group {
                            HStack {
                                Text("Saturated Fat")
                                Spacer()
                                TextField("", text: $satFat)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                Text("g")
                                    .foregroundColor(.secondary)
                            }
                            HStack {
                                Text("Monounsaturated Fat")
                                Spacer()
                                TextField("", text: $monoFat)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                Text("g")
                                    .foregroundColor(.secondary)
                            }
                            HStack {
                                Text("Polyunsaturated Fat")
                                Spacer()
                                TextField("", text: $polyFat)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                Text("g")
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Sugars
                        HStack {
                            Text("Sugars")
                            Spacer()
                            TextField("", text: $sugars)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text("g")
                                .foregroundColor(.secondary)
                        }

                        // Minerals
                        Group {
                            HStack {
                                Text("Sodium")
                                Spacer()
                                TextField("", text: $sodium)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                Text("mg")
                                    .foregroundColor(.secondary)
                            }
                            HStack {
                                Text("Potassium")
                                Spacer()
                                TextField("", text: $potassium)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                Text("mg")
                                    .foregroundColor(.secondary)
                            }
                            HStack {
                                Text("Calcium")
                                Spacer()
                                TextField("", text: $calcium)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                Text("mg")
                                    .foregroundColor(.secondary)
                            }
                            HStack {
                                Text("Iron")
                                Spacer()
                                TextField("", text: $iron)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                Text("mg")
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Vitamins
                        Group {
                            HStack {
                                Text("Vitamin D")
                                Spacer()
                                TextField("", text: $vitaminD)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                Text("mcg")
                                    .foregroundColor(.secondary)
                            }
                            HStack {
                                Text("Vitamin B12")
                                Spacer()
                                TextField("", text: $vitaminB12)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                Text("mcg")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } footer: {
                    Text("Optional - add more details from the nutrition label")
                }

                // Longevity classification
                Section {
                    if isLoadingTypes {
                        HStack {
                            Text("Loading types...")
                                .foregroundColor(.secondary)
                            Spacer()
                            ProgressView()
                        }
                    } else {
                        Picker("Protein Source", selection: $selectedProteinType) {
                            ForEach(proteinTypes) { type in
                                Text(type.displayName).tag(type.referenceKey)
                            }
                        }

                        Picker("Fat Source", selection: $selectedFatType) {
                            ForEach(fatTypes) { type in
                                Text(type.displayName).tag(type.referenceKey)
                            }
                        }
                    }
                } header: {
                    Text("Longevity Classification")
                } footer: {
                    Text("This helps us provide accurate longevity insights for your diet.")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Add Custom Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveCustomFood() }
                    }
                    .disabled(name.isEmpty || isSaving || isLoadingTypes)
                }
            }
            .task {
                await loadTypes()
            }
        }
    }

    private func saveCustomFood() async {
        guard !name.isEmpty else {
            errorMessage = "Please enter a food name"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            let userId = try await supabase.auth.session.user.id

            // Convert per-serving values to per-100g
            let servingSize = Double(servingGrams) ?? 100
            let multiplier = 100.0 / servingSize

            let caloriesPer100g = (Double(calories) ?? 0) * multiplier
            let proteinPer100g = (Double(protein) ?? 0) * multiplier
            let fatPer100g = (Double(fat) ?? 0) * multiplier
            let carbsPer100g = (Double(carbs) ?? 0) * multiplier
            let fiberPer100g = (Double(fiber) ?? 0) * multiplier

            // Extended nutrition (converted to per-100g)
            let satFatPer100g = (Double(satFat) ?? 0) * multiplier
            let monoFatPer100g = (Double(monoFat) ?? 0) * multiplier
            let polyFatPer100g = (Double(polyFat) ?? 0) * multiplier
            let sugarsPer100g = (Double(sugars) ?? 0) * multiplier
            let sodiumPer100g = (Double(sodium) ?? 0) * multiplier
            let potassiumPer100g = (Double(potassium) ?? 0) * multiplier
            let calciumPer100g = (Double(calcium) ?? 0) * multiplier
            let ironPer100g = (Double(iron) ?? 0) * multiplier
            let vitaminDPer100g = (Double(vitaminD) ?? 0) * multiplier
            let vitaminB12Per100g = (Double(vitaminB12) ?? 0) * multiplier

            var customFood: [String: AnyJSON] = [
                "patient_id": .string(userId.uuidString),
                "name": .string(name),
                "brand": brand.isEmpty ? .null : .string(brand),
                "calories": calories.isEmpty ? .null : .double(caloriesPer100g),
                "protein_g": protein.isEmpty ? .null : .double(proteinPer100g),
                "fat_total_g": fat.isEmpty ? .null : .double(fatPer100g),
                "carbs_g": carbs.isEmpty ? .null : .double(carbsPer100g),
                "fiber_g": fiber.isEmpty ? .null : .double(fiberPer100g),
                "protein_type": selectedProteinType == "protein_types_other" ? .null : .string(selectedProteinType),
                "fat_type": .string(selectedFatType),
                "default_serving_grams": .double(servingSize),
                "serving_description": servingDescription.isEmpty ? .null : .string(servingDescription)
            ]

            // Add extended nutrition if provided
            if !satFat.isEmpty { customFood["fat_saturated_g"] = .double(satFatPer100g) }
            if !monoFat.isEmpty { customFood["fat_monounsaturated_g"] = .double(monoFatPer100g) }
            if !polyFat.isEmpty { customFood["fat_polyunsaturated_g"] = .double(polyFatPer100g) }
            if !sugars.isEmpty { customFood["sugars_g"] = .double(sugarsPer100g) }
            if !sodium.isEmpty { customFood["sodium_mg"] = .double(sodiumPer100g) }
            if !potassium.isEmpty { customFood["potassium_mg"] = .double(potassiumPer100g) }
            if !calcium.isEmpty { customFood["calcium_mg"] = .double(calciumPer100g) }
            if !iron.isEmpty { customFood["iron_mg"] = .double(ironPer100g) }
            if !vitaminD.isEmpty { customFood["vitamin_d_mcg"] = .double(vitaminDPer100g) }
            if !vitaminB12.isEmpty { customFood["vitamin_b12_mcg"] = .double(vitaminB12Per100g) }

            let result: CustomFood = try await supabase
                .from("patient_custom_foods")
                .insert(customFood)
                .select()
                .single()
                .execute()
                .value

            await MainActor.run {
                onFoodCreated(result)
                dismiss()
            }

        } catch {
            await MainActor.run {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }

    private func loadTypes() async {
        isLoadingTypes = true

        do {
            // Load protein types
            let proteinResult: [CategoryTypeRef] = try await supabase
                .from("sample_category_types_reference")
                .select("id, reference_key, display_name, display_order, metadata")
                .eq("reference_category", value: "protein_types")
                .order("display_order", ascending: true)
                .execute()
                .value

            // Load fat types
            let fatResult: [CategoryTypeRef] = try await supabase
                .from("sample_category_types_reference")
                .select("id, reference_key, display_name, display_order, metadata")
                .eq("reference_category", value: "fat_types")
                .order("display_order", ascending: true)
                .execute()
                .value

            await MainActor.run {
                self.proteinTypes = proteinResult
                self.fatTypes = fatResult
                self.isLoadingTypes = false
            }
        } catch {
            print("Error loading types: \(error)")
            await MainActor.run {
                self.isLoadingTypes = false
            }
        }
    }
}

#Preview {
    CustomFoodEntryView { _ in }
}
