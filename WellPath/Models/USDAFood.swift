//
//  USDAFood.swift
//  WellPath
//
//  Models for USDA FoodData Central foods and custom foods
//

import Foundation
import SwiftUI

/// Protocol for any food that can be logged
protocol LoggableFood: Identifiable {
    var id: UUID { get }
    var displayName: String { get }
    var displayCategory: String { get }
    var calories: Double? { get }
    var proteinG: Double? { get }
    var fatTotalG: Double? { get }
    var carbsG: Double? { get }
    var fiberG: Double? { get }
    var proteinTier: String? { get }
    var fatTier: String? { get }
    var longevityScore: Int? { get }
    var isCustomFood: Bool { get }

    func nutrients(forGrams grams: Double) -> PortionNutrients
}

/// USDA food item from the database
struct USDAFood: Codable, Identifiable, LoggableFood {
    let id: UUID
    let fdcId: Int
    let description: String
    let category: String
    let displayNameDb: String?  // Clean display name from database

    // Nutrients per 100g
    let calories: Double?
    let proteinG: Double?
    let fatTotalG: Double?
    let fatSaturatedG: Double?
    let fatMonounsaturatedG: Double?
    let fatPolyunsaturatedG: Double?
    let carbsG: Double?
    let fiberG: Double?
    let sugarsG: Double?
    let sodiumMg: Double?
    let potassiumMg: Double?
    let calciumMg: Double?
    let ironMg: Double?
    let vitaminDMcg: Double?
    let vitaminB12Mcg: Double?

    // Longevity tiers
    let proteinTier: String?
    let fatTier: String?
    let longevityScore: Int?

    // Longevity flags
    let isPlantBased: Bool?
    let isOmega3Rich: Bool?
    let isProcessed: Bool?
    let fatQuality: String?

    // WellPath category reference
    let categoryReferenceId: UUID?
    let isWellPathCategory: Bool?

    // WellPath category display info
    let exampleFoods: String?
    let servingSize: String?
    let servingTip: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fdcId = "fdc_id"
        case description
        case category
        case displayNameDb = "display_name"
        case calories
        case proteinG = "protein_g"
        case fatTotalG = "fat_total_g"
        case fatSaturatedG = "fat_saturated_g"
        case fatMonounsaturatedG = "fat_monounsaturated_g"
        case fatPolyunsaturatedG = "fat_polyunsaturated_g"
        case carbsG = "carbs_g"
        case fiberG = "fiber_g"
        case sugarsG = "sugars_g"
        case sodiumMg = "sodium_mg"
        case potassiumMg = "potassium_mg"
        case calciumMg = "calcium_mg"
        case ironMg = "iron_mg"
        case vitaminDMcg = "vitamin_d_mcg"
        case vitaminB12Mcg = "vitamin_b12_mcg"
        case proteinTier = "protein_type"
        case fatTier = "fat_type"
        case longevityScore = "longevity_score"
        case isPlantBased = "is_plant_based"
        case isOmega3Rich = "is_omega_3_rich"
        case isProcessed = "is_processed"
        case fatQuality = "fat_quality"
        case categoryReferenceId = "category_reference_id"
        case isWellPathCategory = "is_wellpath_category"
        case exampleFoods = "example_foods"
        case servingSize = "serving_size"
        case servingTip = "serving_tip"
    }

    // LoggableFood conformance - use clean display name if available
    var displayName: String { displayNameDb ?? description }
    var displayCategory: String { category }
    var isCustomFood: Bool { false }

    /// Calculate nutrients for a given portion size
    func nutrients(forGrams grams: Double) -> PortionNutrients {
        let multiplier = grams / 100.0
        return PortionNutrients(
            calories: (calories ?? 0) * multiplier,
            proteinG: (proteinG ?? 0) * multiplier,
            fatTotalG: (fatTotalG ?? 0) * multiplier,
            fatSaturatedG: (fatSaturatedG ?? 0) * multiplier,
            fatMonoG: (fatMonounsaturatedG ?? 0) * multiplier,
            fatPolyG: (fatPolyunsaturatedG ?? 0) * multiplier,
            carbsG: (carbsG ?? 0) * multiplier,
            fiberG: (fiberG ?? 0) * multiplier,
            sugarsG: (sugarsG ?? 0) * multiplier
        )
    }
}

/// User-created custom food
struct CustomFood: Codable, Identifiable, LoggableFood {
    let id: UUID
    let patientId: UUID
    let name: String
    let brand: String?

    // Core nutrients per 100g
    let calories: Double?
    let proteinG: Double?
    let fatTotalG: Double?
    let carbsG: Double?
    let fiberG: Double?

    // Extended nutrients per 100g (optional)
    let fatSaturatedG: Double?
    let fatMonounsaturatedG: Double?
    let fatPolyunsaturatedG: Double?
    let sugarsG: Double?
    let sodiumMg: Double?
    let potassiumMg: Double?
    let calciumMg: Double?
    let ironMg: Double?
    let vitaminDMcg: Double?
    let vitaminB12Mcg: Double?

    // User-assigned tiers
    let proteinTier: String?
    let fatTier: String?
    let longevityScore: Int?

    // Serving info
    let defaultServingGrams: Double?
    let servingDescription: String?

    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case name
        case brand
        case calories
        case proteinG = "protein_g"
        case fatTotalG = "fat_total_g"
        case carbsG = "carbs_g"
        case fiberG = "fiber_g"
        case fatSaturatedG = "fat_saturated_g"
        case fatMonounsaturatedG = "fat_monounsaturated_g"
        case fatPolyunsaturatedG = "fat_polyunsaturated_g"
        case sugarsG = "sugars_g"
        case sodiumMg = "sodium_mg"
        case potassiumMg = "potassium_mg"
        case calciumMg = "calcium_mg"
        case ironMg = "iron_mg"
        case vitaminDMcg = "vitamin_d_mcg"
        case vitaminB12Mcg = "vitamin_b12_mcg"
        case proteinTier = "protein_type"
        case fatTier = "fat_type"
        case longevityScore = "longevity_score"
        case defaultServingGrams = "default_serving_grams"
        case servingDescription = "serving_description"
        case createdAt = "created_at"
    }

    // LoggableFood conformance
    var displayName: String {
        if let brand = brand, !brand.isEmpty {
            return "\(brand) - \(name)"
        }
        return name
    }
    var displayCategory: String { "Custom Food" }
    var isCustomFood: Bool { true }

    func nutrients(forGrams grams: Double) -> PortionNutrients {
        let multiplier = grams / 100.0
        return PortionNutrients(
            calories: (calories ?? 0) * multiplier,
            proteinG: (proteinG ?? 0) * multiplier,
            fatTotalG: (fatTotalG ?? 0) * multiplier,
            fatSaturatedG: (fatSaturatedG ?? 0) * multiplier,
            fatMonoG: (fatMonounsaturatedG ?? 0) * multiplier,
            fatPolyG: (fatPolyunsaturatedG ?? 0) * multiplier,
            carbsG: (carbsG ?? 0) * multiplier,
            fiberG: (fiberG ?? 0) * multiplier,
            sugarsG: (sugarsG ?? 0) * multiplier
        )
    }
}

/// Wrapper to hold either USDA or Custom food in search results
enum FoodSearchResult: Identifiable {
    case usda(USDAFood)
    case custom(CustomFood)

    var id: UUID {
        switch self {
        case .usda(let food): return food.id
        case .custom(let food): return food.id
        }
    }

    var displayName: String {
        switch self {
        case .usda(let food): return food.displayName
        case .custom(let food): return food.displayName
        }
    }

    var displayCategory: String {
        switch self {
        case .usda(let food): return food.displayCategory
        case .custom(let food): return food.displayCategory
        }
    }

    var calories: Double? {
        switch self {
        case .usda(let food): return food.calories
        case .custom(let food): return food.calories
        }
    }

    var isCustomFood: Bool {
        switch self {
        case .usda: return false
        case .custom: return true
        }
    }

    func nutrients(forGrams grams: Double) -> PortionNutrients {
        switch self {
        case .usda(let food): return food.nutrients(forGrams: grams)
        case .custom(let food): return food.nutrients(forGrams: grams)
        }
    }

    var proteinTier: String? {
        switch self {
        case .usda(let food): return food.proteinTier
        case .custom(let food): return food.proteinTier
        }
    }

    var longevityScore: Int? {
        switch self {
        case .usda(let food): return food.longevityScore
        case .custom(let food): return food.longevityScore
        }
    }

    var categoryReferenceId: UUID? {
        switch self {
        case .usda(let food): return food.categoryReferenceId
        case .custom: return nil
        }
    }

    var isWellPathCategory: Bool {
        switch self {
        case .usda(let food): return food.isWellPathCategory ?? false
        case .custom: return false
        }
    }

    var exampleFoods: String? {
        switch self {
        case .usda(let food): return food.exampleFoods
        case .custom: return nil
        }
    }

    var servingSize: String? {
        switch self {
        case .usda(let food): return food.servingSize
        case .custom: return nil
        }
    }

    var servingTip: String? {
        switch self {
        case .usda(let food): return food.servingTip
        case .custom: return nil
        }
    }
}

/// Calculated nutrients for a portion
struct PortionNutrients {
    let calories: Double
    let proteinG: Double
    let fatTotalG: Double
    let fatSaturatedG: Double
    let fatMonoG: Double
    let fatPolyG: Double
    let carbsG: Double
    let fiberG: Double
    let sugarsG: Double
}

/// USDA food portion sizes
struct USDAFoodPortion: Codable, Identifiable {
    let id: UUID
    let foodId: UUID
    let fdcId: Int
    let amount: Double
    let unit: String
    let gramWeight: Double
    let sequenceNumber: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case foodId = "food_id"
        case fdcId = "fdc_id"
        case amount
        case unit
        case gramWeight = "gram_weight"
        case sequenceNumber = "sequence_number"
    }

    /// Display string - uses clean unit label from database
    var displayString: String {
        // Database now has clean labels like "1 serving (4oz)", "1 oz", "100g"
        return unit
    }
}

/// Recent food entry from patient_recent_foods table
struct RecentFood: Codable, Identifiable {
    let id: UUID
    let patientId: UUID
    let usdaFoodId: UUID?
    let customFoodId: UUID?
    let lastLoggedAt: Date
    let logCount: Int
    let defaultPortionGrams: Double?

    // Joined food data
    let usdaFood: USDAFood?
    let customFood: CustomFood?

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case usdaFoodId = "usda_food_id"
        case customFoodId = "custom_food_id"
        case lastLoggedAt = "last_logged_at"
        case logCount = "log_count"
        case defaultPortionGrams = "default_portion_grams"
        case usdaFood = "usda_foods"
        case customFood = "patient_custom_foods"
    }

    /// Convert to FoodSearchResult for display
    var asFoodSearchResult: FoodSearchResult? {
        if let usda = usdaFood {
            return .usda(usda)
        } else if let custom = customFood {
            return .custom(custom)
        }
        return nil
    }
}

/// Meal type for food logging
enum MealType: String, CaseIterable, Identifiable {
    case breakfast = "breakfast"
    case lunch = "lunch"
    case dinner = "dinner"
    case snack = "snack"

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.fill"
        case .snack: return "cup.and.saucer.fill"
        }
    }

    var color: Color {
        switch self {
        case .breakfast: return .orange
        case .lunch: return .yellow
        case .dinner: return .indigo
        case .snack: return .green
        }
    }

    /// Auto-detect meal type based on current hour
    static func suggestedForTime(_ date: Date) -> MealType {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11: return .breakfast
        case 11..<15: return .lunch
        case 15..<17: return .snack
        case 17..<22: return .dinner
        default: return .snack
        }
    }
}
