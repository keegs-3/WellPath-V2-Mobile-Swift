//
//  EditCustomFoodView.swift
//  WellPath
//
//  Form for editing existing custom foods
//

import SwiftUI
import Supabase

struct EditCustomFoodView: View {
    @Environment(\.dismiss) var dismiss

    let food: CustomFood
    let onFoodUpdated: (CustomFood) -> Void

    @State private var name: String
    @State private var brand: String
    @State private var calories: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
    @State private var fiber: String
    @State private var servingGrams: String
    @State private var servingDescription: String
    @State private var selectedProteinType: String
    @State private var selectedFatType: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var isLoadingTypes = true
    @State private var proteinTypes: [CategoryTypeRef] = []
    @State private var fatTypes: [CategoryTypeRef] = []

    // Extended nutrition fields
    @State private var showExtendedNutrition: Bool
    @State private var satFat: String
    @State private var monoFat: String
    @State private var polyFat: String
    @State private var sugars: String
    @State private var sodium: String
    @State private var potassium: String
    @State private var calcium: String
    @State private var iron: String
    @State private var vitaminD: String
    @State private var vitaminB12: String

    private let supabase = SupabaseManager.shared.client

    init(food: CustomFood, onFoodUpdated: @escaping (CustomFood) -> Void) {
        self.food = food
        self.onFoodUpdated = onFoodUpdated

        // Initialize state from existing food
        // Convert per-100g values back to per-serving for display
        let servingSize = food.defaultServingGrams ?? 100
        let divider = servingSize / 100.0

        _name = State(initialValue: food.name)
        _brand = State(initialValue: food.brand ?? "")
        _calories = State(initialValue: food.calories.map { String(Int($0 * divider)) } ?? "")
        _protein = State(initialValue: food.proteinG.map { String(format: "%.1f", $0 * divider) } ?? "")
        _carbs = State(initialValue: food.carbsG.map { String(format: "%.1f", $0 * divider) } ?? "")
        _fat = State(initialValue: food.fatTotalG.map { String(format: "%.1f", $0 * divider) } ?? "")
        _fiber = State(initialValue: food.fiberG.map { String(format: "%.1f", $0 * divider) } ?? "")
        _servingGrams = State(initialValue: String(Int(servingSize)))
        _servingDescription = State(initialValue: food.servingDescription ?? "")
        // Use stored type or default to "other"
        _selectedProteinType = State(initialValue: food.proteinTier ?? "protein_types_other")
        _selectedFatType = State(initialValue: food.fatTier ?? "fat_types_other")

        // Initialize extended nutrition (convert from per-100g to per-serving)
        let hasExtendedData = food.fatSaturatedG != nil || food.sugarsG != nil || food.sodiumMg != nil
        _showExtendedNutrition = State(initialValue: hasExtendedData)
        _satFat = State(initialValue: food.fatSaturatedG.map { String(format: "%.1f", $0 * divider) } ?? "")
        _monoFat = State(initialValue: food.fatMonounsaturatedG.map { String(format: "%.1f", $0 * divider) } ?? "")
        _polyFat = State(initialValue: food.fatPolyunsaturatedG.map { String(format: "%.1f", $0 * divider) } ?? "")
        _sugars = State(initialValue: food.sugarsG.map { String(format: "%.1f", $0 * divider) } ?? "")
        _sodium = State(initialValue: food.sodiumMg.map { String(format: "%.1f", $0 * divider) } ?? "")
        _potassium = State(initialValue: food.potassiumMg.map { String(format: "%.1f", $0 * divider) } ?? "")
        _calcium = State(initialValue: food.calciumMg.map { String(format: "%.1f", $0 * divider) } ?? "")
        _iron = State(initialValue: food.ironMg.map { String(format: "%.1f", $0 * divider) } ?? "")
        _vitaminD = State(initialValue: food.vitaminDMcg.map { String(format: "%.1f", $0 * divider) } ?? "")
        _vitaminB12 = State(initialValue: food.vitaminB12Mcg.map { String(format: "%.1f", $0 * divider) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                // Basic info
                Section("Food Details") {
                    TextField("Food Name *", text: $name)
                    TextField("Brand (optional)", text: $brand)
                }

                // Serving info
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

                // Macros per serving
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
            .navigationTitle("Edit Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await updateCustomFood() }
                    }
                    .disabled(name.isEmpty || isSaving || isLoadingTypes)
                }
            }
            .task {
                await loadTypes()
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

    private func updateCustomFood() async {
        guard !name.isEmpty else {
            errorMessage = "Please enter a food name"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            let userId = try await supabase.auth.session.user.id

            // Verify this is the user's food
            guard food.patientId == userId else {
                errorMessage = "You can only edit your own foods"
                isSaving = false
                return
            }

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

            var updateData: [String: AnyJSON] = [
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
            updateData["fat_saturated_g"] = satFat.isEmpty ? .null : .double(satFatPer100g)
            updateData["fat_monounsaturated_g"] = monoFat.isEmpty ? .null : .double(monoFatPer100g)
            updateData["fat_polyunsaturated_g"] = polyFat.isEmpty ? .null : .double(polyFatPer100g)
            updateData["sugars_g"] = sugars.isEmpty ? .null : .double(sugarsPer100g)
            updateData["sodium_mg"] = sodium.isEmpty ? .null : .double(sodiumPer100g)
            updateData["potassium_mg"] = potassium.isEmpty ? .null : .double(potassiumPer100g)
            updateData["calcium_mg"] = calcium.isEmpty ? .null : .double(calciumPer100g)
            updateData["iron_mg"] = iron.isEmpty ? .null : .double(ironPer100g)
            updateData["vitamin_d_mcg"] = vitaminD.isEmpty ? .null : .double(vitaminDPer100g)
            updateData["vitamin_b12_mcg"] = vitaminB12.isEmpty ? .null : .double(vitaminB12Per100g)

            let result: CustomFood = try await supabase
                .from("patient_custom_foods")
                .update(updateData)
                .eq("id", value: food.id.uuidString)
                .eq("patient_id", value: userId.uuidString)
                .select()
                .single()
                .execute()
                .value

            await MainActor.run {
                onFoodUpdated(result)
                dismiss()
            }

        } catch {
            await MainActor.run {
                errorMessage = "Failed to update: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }
}

#Preview {
    EditCustomFoodView(
        food: CustomFood(
            id: UUID(),
            patientId: UUID(),
            name: "Test Food",
            brand: "Test Brand",
            calories: 200,
            proteinG: 20,
            fatTotalG: 10,
            carbsG: 15,
            fiberG: 3,
            fatSaturatedG: 3,
            fatMonounsaturatedG: 4,
            fatPolyunsaturatedG: 2,
            sugarsG: 5,
            sodiumMg: 150,
            potassiumMg: 200,
            calciumMg: 50,
            ironMg: 2,
            vitaminDMcg: 1,
            vitaminB12Mcg: 0.5,
            proteinTier: "protein_types_fish",
            fatTier: "fat_types_olive_oil",
            longevityScore: 4,
            defaultServingGrams: 100,
            servingDescription: "1 serving",
            createdAt: Date()
        ),
        onFoodUpdated: { _ in }
    )
}
